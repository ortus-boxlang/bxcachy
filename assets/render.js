// Renders every SVG in assets/ to PNG (wallpapers at 2560x1440, icon 256, logo 720x200). Usage: node assets/render.js
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path');
(async () => {
  const b = await chromium.launch();
  const jobs = [['wallpapers/box', 2560, 1440], ['wallpapers/grid', 2560, 1440], ['wallpapers/aurora', 2560, 1440], ['wallpapers/minimal', 2560, 1440], ['icon', 256, 256], ['logo', 720, 200]];
  for (const [name, w, h] of jobs) {
    const p = await b.newPage({ viewport: { width: w, height: h } });
    await p.goto('file://' + path.resolve(__dirname, name + '.svg'));
    const jpg = ['wallpapers/box', 'wallpapers/grid', 'wallpapers/aurora'].includes(name);
    await p.screenshot(jpg ? { path: path.resolve(__dirname, name + '.jpg'), type: 'jpeg', quality: 92 } : { path: path.resolve(__dirname, name + '.png'), omitBackground: !name.startsWith('wallpapers') });
    await p.close();
  }
  await b.close();
})();
