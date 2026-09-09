// Run against either production build, using the same QA dependencies as Phase 8.
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const assert = require('node:assert/strict');
const path = require('node:path');
const site = (process.env.ASTRA_SITE_URL || 'http://127.0.0.1:4019').replace(/\/$/, '');
(async () => {
  const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_EXECUTABLE, headless: true, args: ['--no-sandbox'] });
  try {
    const page = await browser.newPage();
    for (const width of [1440, 390, 320]) {
      await page.setViewportSize({ width, height: 1000 });
      for (const id of ['perception', 'mapping', 'decision', '', 'cooperative', 'cross-cutting']) {
        const route = '/research/' + (id ? id + '/' : '');
        await page.goto(site + route, { waitUntil: 'networkidle' });
        const approved = ['perception', 'mapping', 'decision'].includes(id);
        assert.equal(await page.locator('.astra-axis-illustration').count(), approved ? 1 : 0);
        if (approved) {
          await page.locator('.astra-axis-illustration').scrollIntoViewIfNeeded();
          await page.waitForFunction(() => { const i = document.querySelector('.astra-axis-illustration img'); return i.complete && i.naturalWidth > 0; });
          const image = await page.locator('.astra-axis-illustration img').evaluate(i => {
            const r = i.getBoundingClientRect();
            return { width: r.width, height: r.height, naturalWidth: i.naturalWidth, naturalHeight: i.naturalHeight, alt: i.alt, fit: getComputedStyle(i).objectFit };
          });
          assert.ok(image.alt.trim());
          assert.ok(image.width <= image.naturalWidth + 1, 'No upscaling');
          assert.ok(Math.abs(image.width / image.height - image.naturalWidth / image.naturalHeight) < 0.01, 'Intrinsic aspect ratio');
          assert.notEqual(image.fit, 'cover');
          assert.ok(image.width <= 608);
          assert.equal(await page.locator('.astra-axis-illustration figcaption').isVisible(), true);
        }
        assert.equal(await page.evaluate(() => document.documentElement.scrollWidth > innerWidth), false, route + ' at ' + width);
        await page.evaluate(() => scrollTo(0, 0));
        if (process.env.PHASE9_SCREENSHOTS) await page.screenshot({ path: path.join(process.env.PHASE9_SCREENSHOTS, (id || 'research') + '-' + width + '.png'), fullPage: true });
        console.log('PASS ' + route + ' at ' + width + 'px');
      }
    }
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exit(1); });
