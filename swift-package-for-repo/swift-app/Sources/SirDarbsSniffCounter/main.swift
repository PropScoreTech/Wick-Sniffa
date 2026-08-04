import Cocoa
import AVFoundation

// MARK: - Persistence (UserDefaults - no files to corrupt, survives updates)

enum Store {
    static let defaults = UserDefaults.standard

    static var count: Int {
        get { defaults.integer(forKey: "count") }
        set { defaults.set(newValue, forKey: "count") }
    }
    static var muted: Bool {
        get { defaults.bool(forKey: "muted") }
        set { defaults.set(newValue, forKey: "muted") }
    }
    static var windowX: Double? {
        get { defaults.object(forKey: "windowX") as? Double }
        set { defaults.set(newValue, forKey: "windowX") }
    }
    static var windowY: Double? {
        get { defaults.object(forKey: "windowY") as? Double }
        set { defaults.set(newValue, forKey: "windowY") }
    }
}

// MARK: - Custom sniff sounds folder

let soundsDir: URL = {
    let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    let dir = appSupport.appendingPathComponent("Sir Darb's Sniff Counter/Sounds")
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}()

func listCustomSounds() -> [URL] {
    let exts = ["mp3", "wav", "m4a", "aiff", "caf"]
    guard let files = try? FileManager.default.contentsOfDirectory(
        at: soundsDir, includingPropertiesForKeys: nil
    ) else { return [] }
    return files.filter { exts.contains($0.pathExtension.lowercased()) }
}

// MARK: - A label that responds to clicks, used for the big count number

final class ClickableLabel: NSTextField {
    var onClick: (() -> Void)?
    override func mouseUp(with event: NSEvent) {
        onClick?()
    }
}

// MARK: - Borderless floating window

final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// MARK: - App Delegate: builds the UI and wires up all behavior

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window: OverlayWindow!
    var countLabel: ClickableLabel!
    var muteButton: NSButton!
    var audioPlayer: AVAudioPlayer?
    var moveSaveWorkItem: DispatchWorkItem?

    let width: CGFloat = 340
    let height: CGFloat = 260

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // no Dock icon - behaves like a utility overlay

        let origin = startingOrigin()
        let frame = NSRect(origin: origin, size: NSSize(width: width, height: height))

        window = OverlayWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .floating
        window.isMovableByWindowBackground = true
        window.delegate = self
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        window.contentView = buildContentView()
        window.makeKeyAndOrderFront(nil)

        updateCountDisplay()
        updateMuteIcon()
    }

    func startingOrigin() -> NSPoint {
        let mainFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let defaultOrigin = NSPoint(x: (mainFrame.width - width) / 2, y: mainFrame.height - height - 100)

        guard let sx = Store.windowX, let sy = Store.windowY else { return defaultOrigin }
        let candidate = NSPoint(x: sx, y: sy)
        return isOnAnyScreen(candidate) ? candidate : defaultOrigin
    }

    func isOnAnyScreen(_ point: NSPoint) -> Bool {
        for screen in NSScreen.screens {
            let f = screen.frame
            if point.x >= f.minX - width + 40 && point.x <= f.maxX - 40 &&
                point.y >= f.minY && point.y <= f.maxY - 40 {
                return true
            }
        }
        return false
    }

    func buildContentView() -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor(srgbRed: 20/255, green: 17/255, blue: 13/255, alpha: 0.92).cgColor
        container.layer?.cornerRadius = 18
        container.layer?.borderWidth = 1
        container.layer?.borderColor = NSColor(srgbRed: 59/255, green: 52/255, blue: 42/255, alpha: 1).cgColor

        let wax = NSColor(srgbRed: 241/255, green: 231/255, blue: 210/255, alpha: 1)
        let taupe = NSColor(srgbRed: 122/255, green: 110/255, blue: 90/255, alpha: 1)

        let closeButton = NSButton(frame: NSRect(x: width - 30, y: height - 30, width: 20, height: 20))
        closeButton.title = "\u{2715}"
        closeButton.isBordered = false
        closeButton.font = NSFont.systemFont(ofSize: 12)
        closeButton.contentTintColor = taupe
        closeButton.target = self
        closeButton.action = #selector(closeApp)
        container.addSubview(closeButton)

        let titleLabel = NSTextField.labelWithString("Sir Darb's Sniff Counter")
        titleLabel.font = NSFont.systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = wax
        titleLabel.alignment = .center
        titleLabel.frame = NSRect(x: 10, y: height - 45, width: width - 20, height: 24)
        container.addSubview(titleLabel)

        countLabel = ClickableLabel.labelWithString("0")
        countLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 72, weight: .heavy)
        countLabel.textColor = wax
        countLabel.alignment = .center
        countLabel.isEditable = false
        countLabel.isSelectable = false
        countLabel.isBordered = false
        countLabel.backgroundColor = .clear
        countLabel.frame = NSRect(x: 10, y: height - 145, width: width - 20, height: 90)
        countLabel.onClick = { [weak self] in self?.increment() }
        container.addSubview(countLabel)

        let subLabel = NSTextField.labelWithString("WICKS SNIFFED")
        subLabel.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        subLabel.textColor = taupe
        subLabel.alignment = .center
        subLabel.frame = NSRect(x: 10, y: height - 162, width: width - 20, height: 16)
        container.addSubview(subLabel)

        let minusButton = makeControlButton(title: "\u{2212} 1", x: 20, action: #selector(decrement))
        let resetButton = makeControlButton(title: "Reset", x: 100, action: #selector(resetCount))
        muteButton = makeControlButton(title: "\u{1F50A}", x: 190, action: #selector(toggleMute))
        let soundsButton = makeControlButton(title: "\u{1F399}", x: 260, action: #selector(openSoundsFolder))

        container.addSubview(minusButton)
        container.addSubview(resetButton)
        container.addSubview(muteButton)
        container.addSubview(soundsButton)

        let hint = NSTextField.labelWithString("click number to sniff \u{00B7} drag card to move")
        hint.font = NSFont.systemFont(ofSize: 9)
        hint.textColor = NSColor(srgbRed: 154/255, green: 139/255, blue: 114/255, alpha: 0.5)
        hint.alignment = .center
        hint.frame = NSRect(x: 10, y: 10, width: width - 20, height: 14)
        container.addSubview(hint)

        return container
    }

    func makeControlButton(title: String, x: CGFloat, action: Selector) -> NSButton {
        let button = NSButton(frame: NSRect(x: x, y: 40, width: 60, height: 26))
        button.title = title
        button.bezelStyle = .rounded
        button.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        button.target = self
        button.action = action
        return button
    }

    // MARK: - Actions

    @objc func increment() {
        Store.count += 1
        updateCountDisplay()
        playSniff()
    }

    @objc func decrement() {
        Store.count = max(0, Store.count - 1)
        updateCountDisplay()
    }

    @objc func resetCount() {
        let alert = NSAlert()
        alert.messageText = "Reset Sir Darb's Sniff Counter to 0?"
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            Store.count = 0
            updateCountDisplay()
        }
    }

    @objc func toggleMute() {
        Store.muted.toggle()
        updateMuteIcon()
    }

    @objc func openSoundsFolder() {
        NSWorkspace.shared.open(soundsDir)
    }

    @objc func closeApp() {
        NSApp.terminate(nil)
    }

    func updateCountDisplay() {
        countLabel.stringValue = "\(Store.count)"
    }

    func updateMuteIcon() {
        muteButton.title = Store.muted ? "\u{1F507}" : "\u{1F50A}"
    }

    // MARK: - Sound: plays a random custom clip if present, else a system sound

    func playSniff() {
        if Store.muted { return }
        let sounds = listCustomSounds()
        if let pick = sounds.randomElement() {
            audioPlayer = try? AVAudioPlayer(contentsOf: pick)
            audioPlayer?.play()
        } else {
            NSSound(named: "Pop")?.play()
        }
    }

    // MARK: - Remember window position between launches

    func windowDidMove(_ notification: Notification) {
        moveSaveWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self = self, let win = self.window else { return }
            Store.windowX = Double(win.frame.origin.x)
            Store.windowY = Double(win.frame.origin.y)
        }
        moveSaveWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: item)
    }
}

// MARK: - Entry point

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
