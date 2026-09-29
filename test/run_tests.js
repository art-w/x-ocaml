#!/usr/bin/env node
// Serves the test pages next to the built x-ocaml scripts and runs each in
// Chromium; a page reports through window.testResults (see lib.js).
//   node run_tests.js [--headed] [--transcript]
// Every test_*.html under this directory is a test page. With --transcript
// it prints what each check found, and fails only if it cannot run the
// pages: dune compares that with browser.expected (see dune).

// The full package when installed here; otherwise any playwright-core
// on NODE_PATH.
const { chromium } = (() => {
  try { return require('playwright'); } catch (e) { return require('playwright-core'); }
})();
const http = require('http');
const fs = require('fs');
const path = require('path');

const TIMEOUT = 60000;

const testDir = __dirname;
const rootDir = path.resolve(testDir, '..');
const types = { '.html': 'text/html', '.js': 'application/javascript', '.css': 'text/css' };

function pages(dir) {
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap((e) => {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) return e.name === 'node_modules' ? [] : pages(p);
    return /^test_.*\.html$/.test(e.name) ? ['/' + path.relative(testDir, p)] : [];
  }).sort();
}

// Chromium: $XOCAML_CHROMIUM if set, else Playwright's own (npm install
// fetches it), else an installed Google Chrome.
async function launch() {
  const headless = !process.argv.includes('--headed');
  const tries = process.env.XOCAML_CHROMIUM
    ? [{ executablePath: process.env.XOCAML_CHROMIUM }]
    : [{}, { channel: 'chrome' }];
  for (const t of tries) {
    try { return await chromium.launch({ headless, ...t }); } catch (e) {}
  }
  console.error('No Chromium to run the tests in: in test/, run\n' +
    '  npx playwright install chromium\n' +
    'or set XOCAML_CHROMIUM to a Chromium or Chrome executable.');
  process.exit(2);
}

function serve() {
  const server = http.createServer((req, res) => {
    const url = req.url.split('?')[0];
    const file = [path.join(testDir, url), path.join(rootDir, url)]
      .find((f) => f.startsWith(rootDir) && fs.existsSync(f) && fs.statSync(f).isFile());
    if (!file) { res.writeHead(404); res.end(); return; }
    res.writeHead(200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream' });
    fs.createReadStream(file).pipe(res);
  });
  // Any free port, so that runs side by side do not collide.
  return new Promise((resolve) => server.listen(0, '127.0.0.1', () => resolve(server)));
}

const transcript = process.argv.includes('--transcript');

(async () => {
  const server = await serve();
  const port = server.address().port;
  const browser = await launch();
  let failed = 0;
  try {
    for (const p of pages(testDir)) {
      const page = await browser.newPage();
      // A page's own errors are among its checks; say what they were
      // only when not recording a transcript, where they may be expected.
      if (!transcript) page.on('pageerror', (e) => console.error(`[page error] ${e.message}`));
      await page.goto(`http://127.0.0.1:${port}${p}`);
      const finished = await page
        .waitForFunction(() => window.testResults && window.testResults.done, null, { timeout: TIMEOUT })
        .then(() => true, () => false);
      const r = await page.evaluate(() => window.testResults);
      if (transcript) console.log(p + (finished ? '' : ' (did not finish)'));
      else console.log(`${p}: ${r.passed}/${r.total} passed${finished ? '' : ' (did not finish)'}`);
      for (const d of r.details) console.log(`  [${d.ok ? 'PASS' : 'FAIL'}] ${d.name}`);
      if (!transcript) failed += r.failed + (finished ? 0 : 1);
      await page.close();
    }
  } catch (e) {
    console.error(e.message);
    failed++;
  } finally {
    await browser.close();
    server.close();
  }
  process.exit(failed ? 1 : 0);
})();
