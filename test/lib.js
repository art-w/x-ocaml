// What a test page needs: check(name, ok) records a check, done() says the
// page is finished; run_tests.js reads window.testResults.
window.testResults = { total: 0, passed: 0, failed: 0, done: false, details: [] };

function check(name, ok) {
  ok = !!ok;
  const r = window.testResults;
  r.total++;
  if (ok) r.passed++; else r.failed++;
  r.details.push({ name, ok });
  const li = document.createElement('li');
  li.textContent = (ok ? 'PASS ' : 'FAIL ') + name;
  li.style.color = ok ? 'green' : 'crimson';
  let list = document.getElementById('results');
  if (!list) {
    list = document.createElement('ul');
    list.id = 'results';
    document.body.prepend(list);
  }
  list.appendChild(li);
}

// Errors thrown on the page are failures too.
window.pageErrors = [];
window.addEventListener('error', (e) => window.pageErrors.push(String(e.message)));

function done() {
  check('no errors on the page', window.pageErrors.length === 0);
  window.testResults.done = true;
}

function waitFor(pred, ms) {
  return new Promise((resolve) => {
    const start = Date.now();
    (function poll() {
      let ok = false;
      try { ok = pred(); } catch (e) {}
      if (ok || Date.now() - start > ms) resolve(ok);
      else setTimeout(poll, 100);
    })();
  });
}

const shadow = (id) => document.getElementById(id).shadowRoot;
const output = (id) =>
  [...shadow(id).querySelectorAll('.caml_stdout, .caml_stderr, .caml_meta')]
    .map((e) => e.textContent).join('\n');
