// An element a library would ship, loaded by X_ocaml_lib.require from the
// test page: it shows its data, and counts how often it was loaded.
window.toyLoads = (window.toyLoads || 0) + 1;
customElements.define('toy-required', class extends HTMLElement {
  set data(s) { this.textContent = 'required: ' + s; }
});
