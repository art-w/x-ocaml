// <x-tone>: a Play button for the notes OCaml sends it,
// data: {"label", "notes": [[frequency in Hz or 0 for a rest, seconds]...]}.
customElements.define('x-tone', class extends HTMLElement {
  set data(s) {
    this.d = JSON.parse(s);
    if (!this.button) {
      this.button = document.createElement('button');
      this.button.onclick = () => this.play();
      this.appendChild(this.button);
    }
    this.button.textContent = '▶ ' + this.d.label;
  }
  play() {
    const audio = this.audio || (this.audio = new AudioContext());
    let t = audio.currentTime + 0.05;
    for (const [freq, secs] of this.d.notes) {
      if (freq > 0) {
        const osc = audio.createOscillator(), gain = audio.createGain();
        osc.type = 'triangle'; osc.frequency.value = freq;
        gain.gain.setValueAtTime(0.25, t);
        gain.gain.exponentialRampToValueAtTime(0.001, t + secs * 0.95);
        osc.connect(gain).connect(audio.destination);
        osc.start(t); osc.stop(t + secs);
      }
      t += secs;
    }
  }
});
