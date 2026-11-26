const { chromium } = require('playwright');
const fs = require('fs'); const path = require('path');
(async () => {
  const jobs = JSON.parse(fs.readFileSync(process.argv[2]));
  const out = process.argv[3];
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 360, height: 500 }, deviceScaleFactor: 1.75 });
  for (const [id, svg] of jobs) {
    await p.setContent(`<html><body style="margin:0">${fs.readFileSync(svg, 'utf8')}</body></html>`);
    await p.screenshot({ path: path.join(out, id + '.jpg'), type: 'jpeg', quality: 84, clip: { x: 0, y: 0, width: 360, height: 500 } });
  }
  await b.close();
})();
