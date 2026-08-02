const { app, BrowserWindow, ipcMain, screen, shell } = require('electron');
const path = require('path');
const fs = require('fs');

// Data is saved next to the app's user-data folder, so it survives
// closing the app and reopening it later - on Windows this is typically
// C:\Users\<you>\AppData\Roaming\Sir Darb's Sniff Counter\sniff-data.json
const dataFile = path.join(app.getPath('userData'), 'sniff-data.json');
const errorLogFile = path.join(app.getPath('userData'), 'error-log.txt');

// Drop your own .mp3/.wav/.ogg sound clips in this folder (use the
// "Open Sounds Folder" button in the app) and the app will play a random
// one each time the count goes up, instead of the built-in synth sniff.
const soundsDir = path.join(app.getPath('userData'), 'sounds');
try {
  fs.mkdirSync(soundsDir, { recursive: true });
} catch (e) {
  logError('Could not create sounds folder', e);
}

const DEFAULT_DATA = { count: 0, bg: 'transparent', x: null, y: null, muted: false, volume: 0.8 };

// Write crash/error info to a plain text file the user can send us,
// instead of relying on macOS's opaque "quit unexpectedly" crash reporter.
function logError(context, err) {
  try {
    const line = `[${new Date().toISOString()}] ${context}: ${err && err.stack ? err.stack : err}\n`;
    fs.appendFileSync(errorLogFile, line);
  } catch (e) {
    // If we can't even write the log, there's nothing more we can do here.
  }
  console.error(context, err);
}

function loadData() {
  try {
    const raw = fs.readFileSync(dataFile, 'utf-8');
    const parsed = JSON.parse(raw);
    if (typeof parsed !== 'object' || parsed === null) throw new Error('Data file did not contain an object');
    return { ...DEFAULT_DATA, ...parsed };
  } catch (e) {
    // If the file is missing, that's normal (first run) - no need to log.
    if (e.code !== 'ENOENT') {
      logError('Corrupt sniff-data.json, resetting to defaults', e);
      // Preserve the bad file for inspection instead of silently losing it
      try {
        fs.renameSync(dataFile, dataFile + '.broken-' + Date.now());
      } catch (renameErr) {
        // best effort only
      }
    }
    return { ...DEFAULT_DATA };
  }
}

function saveData(data) {
  try {
    fs.writeFileSync(dataFile, JSON.stringify(data));
  } catch (e) {
    logError('Failed to save sniff data', e);
  }
}

// Make sure a saved window position is actually still on a connected
// screen. If the user unplugged a monitor or changed resolution since
// last run, an invalid saved position can otherwise misbehave.
function getSafeWindowPosition(saved) {
  const width = 380;
  const height = 300;
  const displays = screen.getAllDisplays();
  const primary = screen.getPrimaryDisplay().workAreaSize;
  const fallback = {
    x: Math.round((primary.width - width) / 2),
    y: 60,
  };

  if (typeof saved.x !== 'number' || typeof saved.y !== 'number') {
    return fallback;
  }

  const fitsOnAnyDisplay = displays.some((d) => {
    const b = d.bounds;
    return (
      saved.x >= b.x - width + 40 &&
      saved.x <= b.x + b.width - 40 &&
      saved.y >= b.y &&
      saved.y <= b.y + b.height - 40
    );
  });

  return fitsOnAnyDisplay ? { x: saved.x, y: saved.y } : fallback;
}

let win;

function createWindow() {
  const saved = loadData();
  const pos = getSafeWindowPosition(saved);

  win = new BrowserWindow({
    width: 380,
    height: 300,
    x: pos.x,
    y: pos.y,
    frame: false,
    transparent: true,
    alwaysOnTop: true,
    resizable: true,
    hasShadow: false,
    skipTaskbar: false,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });

  win.setAlwaysOnTop(true, 'screen-saver');
  win.loadFile('index.html').catch((e) => logError('Failed to load index.html', e));

  win.webContents.on('render-process-gone', (event, details) => {
    logError('Renderer process gone', details.reason);
    if (!win.isDestroyed()) win.close();
    setTimeout(() => {
      try {
        createWindow();
      } catch (e) {
        logError('Failed to recreate window after renderer crash', e);
      }
    }, 500);
  });

  win.on('unresponsive', () => {
    logError('Window became unresponsive', 'no error object');
  });

  let moveTimeout;
  win.on('move', () => {
    clearTimeout(moveTimeout);
    moveTimeout = setTimeout(() => {
      try {
        const [x, y] = win.getPosition();
        const data = loadData();
        data.x = x;
        data.y = y;
        saveData(data);
      } catch (e) {
        logError('Failed to save window position', e);
      }
    }, 300);
  });
}

app.whenReady().then(() => {
  try {
    createWindow();
  } catch (e) {
    logError('Failed to create window on startup', e);
  }
});

app.on('window-all-closed', () => {
  app.quit();
});

app.on('activate', () => {
  if (BrowserWindow.getAllWindows().length === 0) createWindow();
});

process.on('uncaughtException', (err) => {
  logError('Uncaught exception in main process', err);
});
process.on('unhandledRejection', (reason) => {
  logError('Unhandled promise rejection in main process', reason);
});

function safeHandle(channel, fn) {
  ipcMain.handle(channel, async (event, ...args) => {
    try {
      return await fn(event, ...args);
    } catch (e) {
      logError(`IPC handler failed: ${channel}`, e);
      return null;
    }
  });
}

safeHandle('load-count', () => {
  const data = loadData();
  return data.count || 0;
});

safeHandle('save-count', (event, n) => {
  const data = loadData();
  data.count = n;
  saveData(data);
});

safeHandle('load-bg', () => {
  const data = loadData();
  return data.bg || 'transparent';
});

safeHandle('save-bg', (event, mode) => {
  const data = loadData();
  data.bg = mode;
  saveData(data);
});

ipcMain.on('close-app', () => {
  app.quit();
});

safeHandle('load-audio-settings', () => {
  const data = loadData();
  return { muted: !!data.muted, volume: typeof data.volume === 'number' ? data.volume : 0.8 };
});

safeHandle('save-audio-settings', (event, settings) => {
  const data = loadData();
  data.muted = !!settings.muted;
  data.volume = settings.volume;
  saveData(data);
});

safeHandle('list-sounds', () => {
  try {
    const exts = ['.mp3', '.wav', '.ogg', '.m4a'];
    return fs
      .readdirSync(soundsDir)
      .filter((f) => exts.includes(path.extname(f).toLowerCase()))
      .map((f) => path.join(soundsDir, f));
  } catch (e) {
    return [];
  }
});

ipcMain.on('open-sounds-folder', () => {
  try {
    shell.openPath(soundsDir);
  } catch (e) {
    logError('Failed to open sounds folder', e);
  }
});
