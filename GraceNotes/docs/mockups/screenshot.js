const puppeteer = require('puppeteer');
const path = require('path');
const fs = require('fs');

const mockups = ['design-mockup.html'];

async function main() {
  const outDir = path.join(__dirname, 'screenshots');
  fs.mkdirSync(outDir, { recursive: true });

  const browser = await puppeteer.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox'],
  });

  try {
    for (const file of mockups) {
      const htmlPath = path.join(__dirname, file);
      const url = `file://${htmlPath}`;
      const name = path.basename(file, '.html');
      const outPath = path.join(outDir, `${name}.png`);

      const page = await browser.newPage();
      await page.setViewport({ width: 430, height: 932, deviceScaleFactor: 2 });
      await page.goto(url, { waitUntil: 'networkidle0' });
      await page.screenshot({ path: outPath, fullPage: true });
      await page.close();

      console.log(`Saved: ${outPath}`);
    }
  } finally {
    await browser.close();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
