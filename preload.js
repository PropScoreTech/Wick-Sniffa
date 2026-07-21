const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('sniffAPI', {
  loadCount: () => ipcRenderer.invoke('load-count'),
  saveCount: (n) => ipcRenderer.invoke('save-count', n),
  loadBg: () => ipcRenderer.invoke('load-bg'),
  saveBg: (mode) => ipcRenderer.invoke('save-bg', mode),
  closeApp: () => ipcRenderer.send('close-app'),
});
