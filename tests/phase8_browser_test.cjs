// Run against a locally served production build. No live HAL/API requests.
// PLAYWRIGHT_MODULE and CHROMIUM_EXECUTABLE allow an existing QA installation.
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const assert = require('node:assert/strict');
const path = require('node:path');
const site = (process.env.ASTRA_SITE_URL || 'http://127.0.0.1:4018').replace(/\/$/, '');
const normalize = value => value.toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '');
(async () => {
  const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_EXECUTABLE, headless: true, args: ['--no-sandbox'] });
  const page = await browser.newPage();
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  for (const width of [1440, 390, 320]) {
    await page.setViewportSize({ width, height: 1000 });
    await page.goto(site + '/publications/', { waitUntil: 'networkidle' });
    const data = await page.locator('.publication-record').evaluateAll(rows => rows.map(row => ({
      key: row.dataset.key, year: row.dataset.year, type: row.dataset.type,
      title: row.querySelector('.publication-title').textContent,
      text: row.querySelector('.publication-main').textContent + ' ' + row.dataset.keywords,
    })));
    assert.equal(data.length, 259);
    assert.equal(await page.locator('#publication-count').textContent(), '259 publications');
    assert.equal(await page.locator('.publication-controls').isVisible(), true);
    async function noOverflow() {
      assert.equal(await page.evaluate(() => document.documentElement.scrollWidth > innerWidth), false);
    }
    async function screenshot(label) {
      if (process.env.PHASE8_SCREENSHOTS) await page.screenshot({ path: path.join(process.env.PHASE8_SCREENSHOTS, label + '-' + width + '.png') });
    }
    await noOverflow();
    await screenshot('publications-initial');
    async function check(search = '', year = '', type = '') {
      const start = Date.now();
      await page.locator('#publication-year').selectOption(year);
      await page.locator('#publication-type').selectOption(type);
      await page.locator('#bibsearch').fill(search);
      const words = normalize(search).trim().split(/\s+/).filter(Boolean);
      const expected = data.filter(r => (!year || r.year === year) && (!type || r.type === type) && words.every(w => normalize(r.text).includes(w))).map(r => r.key);
      await page.waitForFunction(keys => JSON.stringify([...document.querySelectorAll('.publication-record')].filter(r => !r.closest('li').hidden).map(r => r.dataset.key)) === JSON.stringify(keys), expected);
      const actual = await page.locator('.publication-record').evaluateAll(rows => rows.filter(r => !r.closest('li').hidden).map(r => r.dataset.key));
      assert.deepEqual(actual, expected);
      assert.equal(await page.locator('#publication-count').textContent(), search || year || type ? expected.length + ' of 259 publications' : '259 publications');
      assert.equal(await page.locator('#publication-empty').isVisible(), expected.length === 0);
      const groups = await page.locator('.publication-year').evaluateAll(sections => sections.map(s => ({
        hidden: s.hidden, all: s.querySelectorAll('.publication-record').length,
        shown: [...s.querySelectorAll('.publication-record')].filter(r => !r.closest('li').hidden).length,
        count: s.querySelector('.publication-year-count').textContent,
      })));
      groups.forEach(g => {
        assert.equal(g.hidden, g.shown === 0);
        assert.equal(g.count, g.shown === g.all ? `${g.shown} ${g.shown === 1 ? 'publication' : 'publications'}` : `${g.shown} of ${g.all} publications`);
      });
      await noOverflow();
      console.log(JSON.stringify({ width, search, year, type, matches: expected.length, elapsedMs: Date.now() - start }));
      return expected.length;
    }
    assert.ok(await check(data[0].title.trim().split(/\s+/).slice(0, 5).join(' ')) > 0); // title
    assert.ok(await check('Fawzi Nashashibi') > 0); // author
    assert.ok(await check('IEEE Transactions') > 0); // venue
    assert.equal(await check('', '2025'), 5);
    assert.equal(await check('', '', 'Thesis'), 21);
    assert.ok(await check('Nashashibi', '2024', 'Conference') > 0);
    await screenshot('publications-filtered');
    assert.equal(await check('no-publication-can-match-this-sentinel'), 0);
    await screenshot('publications-empty');
    await check();
    assert.equal(await page.locator('.publication-bibtex[open]').count(), 0);
    const toggle = page.locator('.publication-bibtex summary').first();
    await toggle.focus();
    await page.keyboard.press('Enter');
    assert.equal(await page.locator('.publication-bibtex[open]').count(), 1);
    assert.ok((await page.locator('.publication-bibtex[open] code').textContent()).startsWith('@'));
    await noOverflow();
    await page.locator('.publication-bibtex[open] pre').scrollIntoViewIfNeeded();
    await screenshot('publications-bibtex');
    await toggle.press('Enter');
    assert.equal(await page.locator('.publication-bibtex[open]').count(), 0);
    const authors = page.locator('.publication-more-authors summary').first();
    await authors.focus();
    await authors.press('Enter');
    assert.equal(await page.locator('.publication-more-authors[open]').count(), 1);
    await noOverflow();
    assert.equal(await page.locator('.publication-hal').count(), 259);
    assert.equal(await page.locator('.publication-pdf').count(), 209);
    assert.equal(await page.locator('.publication-doi').count(), 88);
    for (const cls of ['hal', 'pdf', 'doi']) {
      const link = page.locator('.publication-' + cls).first();
      assert.match(await link.getAttribute('href'), /^https?:\/\//);
      await link.focus();
      assert.equal(await link.evaluate(el => el === document.activeElement), true);
    }
    await page.evaluate(() => { location.hash = 'Fawzi%20Nashashibi'; });
    await page.waitForFunction(() => document.querySelector('#bibsearch').value === 'Fawzi Nashashibi');
    assert.match(await page.locator('#publication-count').textContent(), /of 259/);
    await page.evaluate(key => { location.hash = encodeURIComponent(key); }, data[0].key);
    await page.waitForFunction(() => document.querySelector('#bibsearch').value === '');
    assert.equal(await page.locator('#publication-count').textContent(), '259 publications');
    await page.evaluate(() => { location.hash = '%invalid'; });
    await page.waitForTimeout(150);
    assert.equal(errors.length, 0, errors.join('\n'));
  }
  const noJS = await browser.newContext({ javaScriptEnabled: false });
  const staticPage = await noJS.newPage();
  await staticPage.goto(site + '/publications/');
  assert.equal(await staticPage.locator('.publication-record').count(), 259);
  assert.equal(await staticPage.locator('#publication-count').textContent(), '259 publications');
  assert.equal(await staticPage.locator('.publication-controls').isVisible(), false);
  await noJS.close();
  await browser.close();
  console.log('PASS: browser search/filter/actions/responsiveness and no-JS archive');
})().catch(error => { console.error(error); process.exit(1); });
