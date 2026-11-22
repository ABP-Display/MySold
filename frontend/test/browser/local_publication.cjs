const { chromium } = require('playwright');
const { createServer } = require('node:http');
const { readFile } = require('node:fs/promises');
const { once } = require('node:events');
const path = require('node:path');
const assert = require('node:assert/strict');
const ROOT = path.resolve(__dirname, '../../..');
const BASE = 'http://localhost:28086';

(async () => {
  const browser = await chromium.connectOverCDP('http://127.0.0.1:9237');
  const context = await browser.newContext({ viewport: { width: 1200, height: 630 }, hasTouch: true });
  const page = await context.newPage();
  let server;
  try {
    if (process.argv.includes('--preview')) {
      const root = path.join(ROOT, 'docs');
      server = createServer(async (req, res) => {
        const file = path.resolve(root, '.' + new URL(req.url, 'http://localhost').pathname.replace(/\/$/, '/index.html'));
        if (!file.startsWith(root + path.sep)) return res.writeHead(403).end();
        try {
          res.setHeader('Content-Type', ({ '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css',
            '.png': 'image/png', '.ttf': 'font/ttf', '.otf': 'font/otf' })[path.extname(file)] || 'application/octet-stream');
          res.end(await readFile(file));
        } catch { res.writeHead(404).end(); }
      });
      server.listen(0, '127.0.0.1'); await once(server, 'listening');
      await page.goto(`http://127.0.0.1:${server.address().port}/`);
      await page.locator('.month-wrap').waitFor();
      await page.evaluate(() => document.fonts.ready);
      await page.screenshot({ path: path.join(ROOT, 'test-results/public-preview-source.png') });
      console.log('Fictional demo captured at 1200 x 630'); return;
    }
    const errors = [];
    page.on('pageerror', e => errors.push(e.message));
    page.on('console', message => { if (message.type() === 'error') errors.push(message.text()); });
    for (const style of ['dark', 'light']) {
      await page.emulateMedia({ colorScheme: style });
      for (const width of [320, 390, 1440]) {
        await page.setViewportSize({ width, height: 900 });
        for (const route of ['/decouvrir/', '/conditions/', '/confidentialite/', '/mentions-legales/', '/cookies/', '/unknown-test-page']) {
          const requests = [];
          const listener = req => requests.push(req.url());
          page.on('request', listener);
          const response = await page.goto(BASE + route);
          assert.equal(response.status(), route.includes('unknown') ? 404 : 200);
          await page.evaluate(() => document.fonts.ready);
          const data = await page.evaluate(() => ({ width: document.documentElement.scrollWidth, viewport: innerWidth,
            cookies: document.cookie, local: localStorage.length, session: sessionStorage.length,
            headings: document.querySelectorAll('h1').length,
            images: [...document.images].every(i => i.complete && i.naturalWidth > 0 && i.hasAttribute('alt')),
            fonts: [...document.fonts].map(f => f.family),
          }));
          assert.ok(data.width <= data.viewport, route + ': horizontal overflow');
          assert.equal(data.headings, 1); assert.ok(data.images);
          assert.equal(data.cookies, ''); assert.equal(data.local + data.session, 0);
          assert.ok(requests.every(url => url.startsWith(BASE)), 'No automatic third-party requests');
          assert.ok(!requests.some(url => url.includes('/api/')), 'Public pages must not load user data');
          const contrast = await page.evaluate(() => {
            const rgb = color => color.match(/[\d.]+/g).slice(0, 3).map(Number);
            const luminance = values => values.map(v => { v /= 255; return v <= .04045 ? v / 12.92 : ((v + .055) / 1.055) ** 2.4; })
              .reduce((sum, v, i) => sum + v * [.2126, .7152, .0722][i], 0);
            return ['body', '.site-footer p', '.site-footer nav a'].map(selector => {
              const element = document.querySelector(selector), style = getComputedStyle(element);
              const fg = luminance(rgb(style.color)), bg = luminance(rgb(getComputedStyle(document.body).backgroundColor));
              return (Math.max(fg, bg) + .05) / (Math.min(fg, bg) + .05);
            });
          });
          assert.ok(contrast.every(value => value >= 4.5), 'Body and footer text must meet normal-text contrast');
          if (route === '/decouvrir/') {
            await page.getByText('Faut-il installer une application Android ?', { exact: true }).click();
            await page.screenshot({ path: path.join(ROOT, `test-results/public-site-${style}-${width}.png`), fullPage: true });
          }
          page.off('request', listener);
        }
        console.log(`${style}/${width}: public documents, 404, images, no overflow or storage passed`);
      }
    }
    // Public information stays useful when JavaScript is disabled.
    const noJs = await browser.newContext({ javaScriptEnabled: false, viewport: { width: 390, height: 900 } });
    const plain = await noJs.newPage();
    await plain.goto(BASE + '/decouvrir/');
    assert.equal(await plain.getByRole('heading', { name: 'MySold', exact: true }).count(), 1);
    await plain.getByRole('link', { name: 'Confidentialité', exact: true }).click();
    await plain.getByRole('heading', { name: 'Politique de confidentialité', exact: true }).waitFor();
    await noJs.close();
    await page.setViewportSize({ width: 390, height: 900 });
    await page.goto(BASE);
    await page.locator('flt-semantics-placeholder').waitFor({ state: 'attached' });
    await page.locator('flt-semantics-placeholder').evaluate(e => e.click());
    await page.getByRole('button', { name: 'Se connecter', exact: true }).waitFor({ timeout: 45000 });
    const reveal = async locator => {
      for (let i = 0; i < 20; i++) {
        const box = await locator.count() ? await locator.boundingBox() : null;
        if (box && box.y >= 20 && box.y + box.height < 898) return;
        await page.mouse.move(195, 400); await page.mouse.wheel(0, box && box.y < 60 ? -220 : 220);
        await page.waitForTimeout(200);
      }
      throw new Error('Cannot reveal ' + locator);
    };
    const openDocument = async (label, pathname) => {
      const link = page.getByRole('button', { name: label, exact: true });
      await reveal(link);
      const [tab] = await Promise.all([context.waitForEvent('page'), link.tap()]);
      await tab.waitForLoadState('domcontentloaded');
      assert.equal(new URL(tab.url()).pathname, pathname);
      assert.equal(await tab.evaluate(() => window.opener), null);
      await tab.close();
    };
    for (const [label, route] of [['CGU', '/conditions/'], ['Politique de confidentialité', '/confidentialite/'],
      ['Découvrir MySold', '/decouvrir/'], ['Cookies et stockage local', '/cookies/']]) {
      await openDocument(label, route);
    }
    const signup = page.getByRole('button', { name: /Cr[eé]er un compte/, exact: true });
    await reveal(signup); await signup.tap(); await page.waitForTimeout(350);
    await openDocument('CGU', '/conditions/');
    await openDocument('Politique de confidentialité', '/confidentialite/');
    const next = page.getByRole('button', { name: 'Continuer', exact: true });
    await reveal(next); await next.tap(); await page.waitForTimeout(300);
    assert.ok((await page.locator('body').ariaSnapshot()).includes('Ce champ est requis'));
    console.log('Login/register public documents, opener isolation and required-field validation passed');
    assert.deepEqual(errors.filter(e => !e.includes('404 (Not Found)')), []);
    console.log('No-JavaScript navigation and no console exceptions passed');
  } catch (error) {
    await page.screenshot({ path: path.join(ROOT, 'test-results/publication-ui-error.png') });
    console.error((await page.locator('body').ariaSnapshot()).slice(0, 16000));
    throw error;
  } finally { server?.close(); await context.close(); await browser.close(); }
})().catch(e => { console.error(e); process.exitCode = 1; });
