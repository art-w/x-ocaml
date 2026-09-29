// <x-canvas>: draws what OCaml sends it, and asks for the next frame.
// data: {"width", "height", "background", "circles": [[x, y, r, colour]...],
//        "frame": token or null, "click": token or null}
// With a frame token it calls back once per animation frame, but only after
// new data has come: a slow worker slows the animation, it never queues up.
customElements.define('x-canvas', class extends HTMLElement {
  set data(s) {
    const d = JSON.parse(s);
    if (!this.canvas) {
      this.canvas = document.createElement('canvas');
      this.canvas.style.cssText = 'width:100%;border-radius:8px;cursor:crosshair';
      this.canvas.onclick = (ev) => {
        if (this.d.click == null) return;
        const r = this.canvas.getBoundingClientRect();
        const x = (ev.clientX - r.left) / r.width * this.d.width, y = (ev.clientY - r.top) / r.height * this.d.height;
        this.call(this.d.click, x.toFixed(1) + ' ' + y.toFixed(1));
      };
      this.appendChild(this.canvas);
    }
    this.d = d;
    const c = this.canvas, g = c.getContext('2d');
    c.width = d.width; c.height = d.height;
    g.fillStyle = d.background || '#141925'; g.fillRect(0, 0, d.width, d.height);
    for (const [x, y, r, colour] of d.circles || []) {
      g.beginPath(); g.arc(x, y, r, 0, 2 * Math.PI); g.fillStyle = colour; g.fill();
    }
    if (d.frame != null) requestAnimationFrame(() => this.isConnected && this.call(d.frame, ''));
  }
  call(token, payload) {
    this.dispatchEvent(new CustomEvent('x-ocaml-callback', { bubbles: true, detail: { token, payload } }));
  }
});
