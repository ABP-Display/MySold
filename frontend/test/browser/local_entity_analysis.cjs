const { chromium } = require('playwright');
const assert = require('node:assert/strict');
const path = require('node:path');
const BASE = 'http://localhost:28086';
const output = path.resolve(__dirname, '../../../test-results');

(async () => {
  const browser = await chromium.connectOverCDP('http://127.0.0.1:9237');
  const context = await browser.newContext({ viewport: { width: 390, height: 900 }, hasTouch: true, isMobile: true });
  const page = await context.newPage();
  const errors = [], annualReads = [];
  let financialWrites = 0, theme = 'Sombre';
  const now = new Date(), currentYear = now.getUTCFullYear();
  const category = { name: 'Alimentation', description: 'Achats du quotidien', type: 'expense', color: 0xff4caf50, icon: 0xef37 };
  page.on('pageerror', error => errors.push(error.message));
  page.on('request', request => {
    if (request.url().endsWith('/api/documents/commit')) financialWrites++;
  });
  // Fictional annual figures and one category are read-only browser responses.
  await page.route('**/api/documents/get', async route => {
    const { path: document } = route.request().postDataJSON();
    if (document.endsWith('/categories/food')) return route.fulfill({ json: { data: category } });
    const response = await route.fetch();
    if (/^users\/[^/]+$/.test(document)) {
      const json = await response.json();
      return route.fulfill({ response, json: { ...json, data: { ...json.data, theme } } });
    }
    return route.fulfill({ response });
  });
  await page.route('**/api/documents/query', async route => {
    const query = route.request().postDataJSON();
    if (query.path.endsWith('/categories')) return route.fulfill({ json: {
      documents: [{ path: query.path + '/food', data: category }], cursor: null,
    } });
    return route.continue();
  });
  await page.route('**/api/analysis/annual', async route => {
    const { year } = route.request().postDataJSON();
    annualReads.push(year);
    const months = year < currentYear ? 12 : now.getUTCMonth() + 1;
    const data = [
      ['accounts/cash', 'Compte de test', 900, 975],
      ['accounts/bank', 'Banque', 100, 110],
      ['accounts/holding', 'Titres', 120, 165],
      ['investments/gold', 'Or personnalise', 40, 65],
      ['investments/etf', 'ETF Monde', 80, 100],
      ['categories/food', 'Alimentation', 0, months * 25],
    ];
    const entities = data.map(([path, name, opening, current]) => {
      const kind = path.split('/')[0], isCategory = kind === 'categories';
      return { path, name, kind, opening: isCategory ? null : opening, current,
        previous: isCategory ? 200 : null, delta: current - opening, percent: 10,
        estimated: !isCategory, unexplained: 0, netFlows: 15, valuationChange: 10,
        monthly: Array.from({ length: 12 }, (_, m) => m < months ? 25 : 0),
        counts: Array.from({ length: 12 }, (_, m) => m < months ? 2 : 0),
        closing: Array.from({ length: 12 }, (_, m) => m < months
          ? opening + (current - opening) * (m + 1) / months + (m === 3 ? -20 : 0) : null),
      };
    });
    await route.fulfill({ json: { year, asOf: now.toISOString(), entities } });
  });
  const reveal = async locator => {
    for (let i = 0; i < 15; i++) {
      const box = await locator.count() ? await locator.boundingBox() : null;
      if (box && box.y >= 70 && box.y + box.height < 790) return box;
      await page.mouse.move((await page.viewportSize()).width / 2, 440);
      await page.mouse.wheel(0, box && box.y < 70 ? -220 : 220);
      await page.waitForTimeout(250);
    }
    throw Error('Could not reveal ' + locator);
  };
  const back = async () => {
    await page.getByRole('button', { name: 'Retour', exact: true }).tap();
    await page.waitForTimeout(350);
  };
  try {
    const auth = await context.request.post(BASE + '/api/auth/login', {
      headers: { Origin: BASE, 'X-MySold-Request': '1' },
      data: { email: 'asset-style-c625ba128d4b@mysold.local', password: 'Local-test-asset-style-2026!' },
    });
    assert.equal(auth.status(), 200, await auth.text());
    for (const [width, style] of [[320, 'Sombre'], [390, 'Sombre'], [1440, 'Sombre'], [390, 'Clair']]) {
      theme = style;
      await page.setViewportSize({ width, height: 900 });
      await page.goto(BASE);
      await page.locator('flt-semantics-placeholder').waitFor({ state: 'attached' });
      await page.locator('flt-semantics-placeholder').evaluate(e => e.click());
      await page.getByRole('button', { name: '', exact: true }).tap();
      await page.waitForTimeout(250);
      await page.keyboard.type('123456', { delay: 65 });
      await page.getByRole('button', { name: 'Profil', exact: true }).waitFor({ timeout: 45000 });
      await page.waitForTimeout(500);
      await page.getByRole('button', { name: 'Profil', exact: true }).tap();
      await page.waitForTimeout(400);
      for (const [kind, menu, name] of [
        ['accounts', /^Comptes /, /Compte courant/],
        ['categories', /^Cat[eé]gories /, /Alimentation/],
        ['investments', /^Investissements /, /Or personnalisé/],
      ]) {
        const management = page.getByRole('button', { name: menu });
        await reveal(management); await management.tap(); await page.waitForTimeout(450);
        const row = page.getByRole('button', { name }).last();
        await reveal(row);
        const before = annualReads.length;
        await row.tap();
        const plot = page.locator('[flt-semantics-identifier="entity-annual-plot"]');
        await plot.waitFor({ state: 'attached' }); await page.waitForTimeout(350);
        assert.equal(annualReads.length, before, 'Detail must reuse the management annual summary');
        assert.equal(await page.getByRole('group', { name: /^Informations / }).count(), 1);
        assert.equal(await page.getByRole('group', { name: /^Analyse annuelle / }).count(), 1);
        let snapshot = await page.locator('body').ariaSnapshot();
        assert.ok(!snapshot.includes('Référence annuelle') && !snapshot.includes('Renseigner la référence'));
        await page.screenshot({ path: path.join(output, `entity-${kind}-${style}-${width}-top.png`) });
        const chart = await reveal(plot);
        await page.mouse.move(chart.x + chart.width * .3, chart.y + 100);
        await page.mouse.down(); await page.mouse.move(chart.x + chart.width * .6, chart.y + 100, { steps: 8 });
        await page.mouse.up(); await page.waitForTimeout(200);
        snapshot = await page.locator('body').ariaSnapshot();
        assert.ok(snapshot.includes('Variation depuis le 1er janvier'));
        assert.ok(snapshot.includes(kind === 'categories' ? 'Montant cumulé' : 'Solde'));
        assert.equal(annualReads.length, before, 'Graph interaction must stay local');
        await page.screenshot({ path: path.join(output, `entity-${kind}-${style}-${width}-analysis.png`) });
        const previous = page.getByRole('button', { name: 'Année précédente', exact: true });
        await reveal(previous); await previous.tap(); await page.waitForTimeout(450);
        const afterPrevious = annualReads.length;
        assert.ok(annualReads.includes(currentYear - 1));
        const next = page.getByRole('button', { name: 'Année suivante', exact: true });
        await next.tap(); await page.waitForTimeout(350);
        assert.equal(annualReads.length, afterPrevious, 'Returning to a loaded year must reuse cache');
        const edit = page.getByRole('button', { name: 'Modifier', exact: true });
        await reveal(edit); await edit.tap(); await page.waitForTimeout(350);
        assert.ok((await page.getByRole('textbox').count()) > 0, 'Original form must still open');
        await back(); await back(); await back();
        console.log(`${kind}/${style}/${width}: sections, January baseline, interaction, year cache and edit form passed`);
      }
    }
    assert.deepEqual(errors, []);
    assert.equal(financialWrites, 0, 'Viewing and cancelling forms must never change financial data');
    console.log('No financial writes or browser errors');
  } catch (error) {
    await page.screenshot({ path: path.join(output, 'entity-analysis-error.png') });
    console.error((await page.locator('body').ariaSnapshot()).slice(0, 14000)); throw error;
  } finally { await context.close(); await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
