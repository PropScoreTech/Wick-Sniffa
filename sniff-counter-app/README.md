# Sir Darb's Sniff Counter

A tiny always-on-top, frameless, draggable overlay window for counting sniffed wicks live on stream. Sits directly over your chart — not just a browser tab.

## What it does
- Click the number (or press Space / `+`) to add a sniff
- `−1` button or `-` key to correct a misclick
- `Reset` button (with confirm) or `R` key to zero it out
- `BG` button or `B` key toggles a transparent vs. solid charcoal background
- Drag anywhere on the card to move it around your screen
- Closes with the small ✕ in the corner (there's no title bar, so this is the only close button)
- Count **and** window position are saved automatically and restored next time you open it

## Step 1: Run it on Windows (today)

You'll need [Node.js](https://nodejs.org) installed (the LTS version is fine) — that's the only prerequisite.

1. Unzip this folder somewhere, e.g. `C:\Apps\sniff-counter-app`
2. Open a terminal (PowerShell or Command Prompt) in that folder
3. Install dependencies:
   ```
   npm install
   ```
4. Try it out live first:
   ```
   npm start
   ```
   You should see the floating counter appear. Drag it over your chart, click to test, close with the ✕.
5. Once you're happy, build a standalone `.exe` you can just double-click (no terminal needed after this):
   ```
   npm run dist
   ```
   This creates a `dist` folder — inside it you'll find something like
   `Sir Darb's Sniff Counter 1.0.0.exe`. That single file is portable — you can pin it to your taskbar, put it on your desktop, whatever's convenient.

## Step 2: Get a Mac build — without owning a Mac

Building a real `.dmg`/`.app` requires actual macOS (Apple's code-signing tools don't run on Windows, so there's no cross-compiling shortcut here). But you don't need to buy a Mac — GitHub will build it for you for free on their own Mac hardware. This project already includes the workflow file to do that (`.github/workflows/build-mac.yml`).

**One-time setup:**
1. Create a free account at [github.com](https://github.com) if you don't have one
2. Create a new repository (public or private, doesn't matter) — e.g. `sniff-counter`
3. Upload this whole project folder to it. Easiest way if you don't use git: on the repo page, click **"uploading an existing file"** and drag in everything (`main.js`, `preload.js`, `index.html`, `package.json`, the `.github` folder, this README)

**Every time you want a Mac build:**
1. Go to the **Actions** tab of your repo
2. Click **"Build Mac App"** in the sidebar, then the **"Run workflow"** button
3. Wait ~2-3 minutes for it to finish (green checkmark)
4. Click into the finished run, scroll down to **Artifacts**, and download `sir-darbs-sniff-counter-mac` — that's a zip containing the `.dmg`
5. Send that `.dmg` to your streamer

**What your streamer does with it:**
1. Open the `.dmg`, drag "Sir Darb's Sniff Counter" into Applications
2. First launch: macOS will likely say it's "from an unidentified developer" and block it — this is normal for an unsigned app (avoiding that warning entirely requires a paid $99/year Apple Developer account to sign and notarize it, which probably isn't worth it for a personal streaming tool)
3. To get past it: right-click the app → **Open** → **Open** again in the confirmation dialog. Only needed the first time — after that it opens normally, including via double-click.

If down the road you decide it's worth signing/notarizing (e.g. distributing more broadly), let me know and I can walk you through adding that to the workflow too.

## Notes
- Your count is saved in a small JSON file in the app's own data folder (not inside this project folder), so it survives updates and rebuilds.
- If it ever stops appearing on top of a fullscreen chart app, try switching that app to windowed/borderless mode — some apps' true fullscreen mode can override every other window regardless of "always on top."
- Want it bigger/smaller, a different accent color, or a "sniffs today" counter that resets daily? Just ask and I'll adjust the code.
