# Browser tests

x-ocaml runs in a browser, so its tests are pages: each `test_*.html` under
this directory loads x-ocaml, checks what it does on the page, and reports
what it found. `run_tests.js` serves the pages next to the built scripts
and runs each in Chromium, with Playwright.

## Running them

Once, in this directory:

    npm install

Then, from anywhere in the project:

    dune build @runbrowser

The pages are not part of `dune build` or `dune test`. They are worth
running on a release build too, `dune build --profile=release @runbrowser`:
js_of_ocaml compiles a dev build a library at a time and a release build as
a whole program, and the two can differ.

Everything runs in `_build`: dune copies this directory there, with its
`node_modules`, and runs the pages against the scripts it has just built
there. The copies of `x-ocaml.js` and `x-ocaml.worker.js` that `dune build`
also puts at the root of the project play no part.

## When the results change

`dune build @runbrowser` compares what the checks found with
`browser.expected`, as a cram test's output is compared: a change shows as
a diff, and fails the build. If the change is what you meant, a new test
or a check that now passes, `dune promote` accepts it into
`browser.expected`.

## Writing a test

A page loads `lib.js`, then x-ocaml, and ends with `done()`:

```html
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>x-ocaml: what this page tries</title>
  <script src="lib.js"></script>
</head>
<body>
  <x-ocaml id="cell">let answer = 6 * 7</x-ocaml>
  <script src="x-ocaml.js" src-worker="x-ocaml.worker.js"></script>
  <script>
    (async () => {
      check('the cell answers',
        await waitFor(() => output('cell').includes('val answer : int = 42'), 30000));
      done();
    })();
  </script>
</body>
</html>
```

The runner's server looks for each URL first in this directory, then at the
root of the project, where the built scripts are. So a page here loads them
as if they were beside it, as above; a page in a subdirectory names them
`../x-ocaml.js`.

From `lib.js`:

- `check(name, ok)` records a check.
- `done()` says the page has finished, after one last check: that nothing
  on the page threw.
- `waitFor(pred, ms)` resolves to whether `pred()` became true within `ms`.
- `output(id)` is the text of what the cell `id` answered, and `shadow(id)`
  its shadow root.

A page that does not call `done()` within a minute is reported as not
finished.

## More

### Recording a bug before fixing it

A test can record a bug as it stands. The commit that adds the test
promotes its checks as `[FAIL]`; the commit that fixes the bug promotes
them as `[PASS]`. The history then shows the bug, and that the fix is what
made the difference.

### Watching the pages run

The runner can be run by hand, on the copy in `_build`, once a
`dune build @runbrowser` has put it there:

    node _build/default/test/run_tests.js            # the checks, and what the pages threw
    node _build/default/test/run_tests.js --headed   # in a window

It fails if any check does, rather than comparing with `browser.expected`.

`node test/run_tests.js` runs the pages in this directory as they are, with
no build, against the scripts at the root of the project. That saves a
build while working on a page, but the scripts are only as new as the last
`dune build`.

### Another Chromium

Without Playwright's own Chromium, the runner tries an installed Google
Chrome. `XOCAML_CHROMIUM=/path/to/chrome` names any other.

## CI

The workflow runs the tests in a job of their own, beside the build, with
Playwright's Chromium and the system libraries it needs, on both a dev and a
release build.
