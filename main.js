const { app, BrowserWindow, ipcMain, screen } = require('electron');
const path = require('path');
const fs = require('fs');

// Data is saved next to the app's user-data folder, so it survives
// closing the app and reopening it later - on Windows this is typically
// C:\Users\<you>\AppData\Roaming\Sir Darb's Sniff Counter\sniff-data.json
const dataFile = path.join(app.getPath('userData'), 'sniff-data.json');

function loadData() {
  try {
    const raw = fs.readFileSync(dataFile, 'utf-8');
    return JSON.parse(raw);
  } catch (e) {
    return { count: 0, bg: 'transparent', x: null, y: null };
  }
}

function saveData(data) {
  try {
    fs.writeFileSync(dataFile, JSON.stringify(data));
  } catch (e) {
    console.error('Failed to save sniff data:', e);
  }
}

let win;

function createWindow() {
  const saved = loadData();
  const displays = screen.getPrimaryDisplay().workAreaSize;

  win = new BrowserWindow({
    width: 380,
    height: 300,
    x: typeof saved.x === 'number' ? saved.x : Math.round((displays.width - 380) / 2),
    y: typeof saved.y === 'number' ? saved.y : 60,
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

  // 'screen-saver' level keeps it floating above most other app windows,
  // including many fullscreen charting apps.
  win.setAlwaysOnTop(true, 'screen-saver');
  win.loadFile('index.html');

  // Remember window position between sessions
  let moveTimeout;
  win.on('move', () => {
    clearTimeout(moveTimeout);
    moveTimeout = setTimeout(() => {
      const [x, y] = win.getPosition();
      const data = loadData();
      data.x = x;
      data.y = y;
      saveData(data);
    }, 300);
  });
}

app.whenReady().then(createWindow);

app.on('window-all-closed', () => {
  app.quit();
});

app.on('activate', () => {
  if (BrowserWindow.getAllWindows().length === 0) createWindow();
});

// --- IPC handlers used by the renderer (index.html via preload.js) ---

ipcMain.handle('load-count', () => {
  const data = loadData();
  return data.count || 0;
});

ipcMain.handle('save-count', (event, n) => {
  const data = loadData();
  data.count = n;
  saveData(data);
});

ipcMain.handle('load-bg', () => {
  const data = loadData();
  return data.bg || 'transparent';
});

ipcMain.handle('save-bg', (event, mode) => {
  const data = loadData();
  data.bg = mode;
  saveData(data);
});

ipcMain.on('close-app', () => {
  app.quit();
});
