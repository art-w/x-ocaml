// <x-mermaid>: draws the Mermaid diagram that OCaml sends it, with Mermaid,
// which it loads from a CDN the first time.
const mermaidLoaded = new Promise((resolve) => {
  const js = document.createElement('script');
  js.src = 'https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js';
  js.onload = () => { mermaid.initialize({ startOnLoad: false, theme: 'neutral' }); resolve(); };
  document.head.append(js);
});
let mermaidCount = 0;
customElements.define('x-mermaid', class extends HTMLElement {
  set data(source) {
    mermaidLoaded
      .then(() => mermaid.render('x-mermaid-' + ++mermaidCount, source))
      .then(({ svg }) => { this.innerHTML = svg; })
      .catch((e) => { this.textContent = String(e.message || e); });
  }
});
