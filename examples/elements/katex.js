// <x-katex>: typesets the TeX that OCaml sends it, with KaTeX, which it
// loads from a CDN the first time.
const katexLoaded = new Promise((resolve) => {
  const css = document.createElement('link');
  css.rel = 'stylesheet';
  css.href = 'https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.css';
  const js = document.createElement('script');
  js.src = 'https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.js';
  js.onload = resolve;
  document.head.append(css, js);
});
customElements.define('x-katex', class extends HTMLElement {
  set data(tex) {
    katexLoaded.then(() => katex.render(tex, this, { displayMode: true, throwOnError: false }));
  }
});
