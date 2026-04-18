// Custom 1.5px-stroke outline glyphs. No SF Symbols — everything hand-built.
// Every glyph takes { size, stroke } so themes can retune weight + color.

const Gly = {};

const G = (d, vb = "0 0 24 24") => ({ size = 20, stroke = "currentColor", sw = 1.5, fill = "none" }) => (
  <svg width={size} height={size} viewBox={vb} fill={fill} stroke={stroke} strokeWidth={sw}
       strokeLinecap="square" strokeLinejoin="miter" style={{ display: "block" }}>
    {d}
  </svg>
);

// ── icon set ────────────────────────────────────────────────────────────────
Gly.sun       = G(<g><circle cx="12" cy="12" r="4"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3M5 5l2 2M17 17l2 2M19 5l-2 2M7 17l-2 2"/></g>);
Gly.cloud     = G(<path d="M7 18h11a4 4 0 0 0 .6-7.95A6 6 0 0 0 7 10.5 4 4 0 0 0 7 18z"/>);
Gly.moon      = G(<path d="M20 14.5A8 8 0 0 1 9.5 4a8 8 0 1 0 10.5 10.5z"/>);
Gly.bell      = G(<g><path d="M6 16V11a6 6 0 0 1 12 0v5l2 2H4l2-2z"/><path d="M10 20a2 2 0 0 0 4 0"/></g>);
Gly.plus      = G(<path d="M12 5v14M5 12h14"/>);
Gly.minus     = G(<path d="M5 12h14"/>);
Gly.back      = G(<path d="M15 5l-7 7 7 7"/>);
Gly.chevR     = G(<path d="M9 5l7 7-7 7"/>);
Gly.chevD     = G(<path d="M5 9l7 7 7-7"/>);
Gly.more      = G(<g><circle cx="5" cy="12" r="1.2" fill="currentColor" stroke="none"/><circle cx="12" cy="12" r="1.2" fill="currentColor" stroke="none"/><circle cx="19" cy="12" r="1.2" fill="currentColor" stroke="none"/></g>);
Gly.close     = G(<path d="M5 5l14 14M19 5L5 19"/>);
Gly.check     = G(<path d="M4 12l5 5 11-11"/>);
Gly.home      = G(<path d="M3 11l9-7 9 7v9H3v-9z"/>);
Gly.rooms     = G(<g><rect x="3" y="3" width="8" height="8"/><rect x="13" y="3" width="8" height="8"/><rect x="3" y="13" width="8" height="8"/><rect x="13" y="13" width="8" height="8"/></g>);
Gly.devices   = G(<g><rect x="3" y="4" width="18" height="13"/><path d="M8 21h8M12 17v4"/></g>);
Gly.settings  = G(<g><circle cx="12" cy="12" r="3"/><path d="M12 2v2.5M12 19.5V22M4.2 4.2l1.8 1.8M18 18l1.8 1.8M2 12h2.5M19.5 12H22M4.2 19.8L6 18M18 6l1.8-1.8"/></g>);
Gly.scenes    = G(<path d="M12 2l2.6 6.6L22 10l-5.5 4.6L18 22l-6-3.8L6 22l1.5-7.4L2 10l7.4-1.4L12 2z"/>);
Gly.lightbulb = G(<g><path d="M9 18h6M10 21h4"/><path d="M7 10a5 5 0 1 1 10 0c0 3-2 4-2 7H9c0-3-2-4-2-7z"/></g>);
Gly.thermo    = G(<g><path d="M10 3h4v12a4 4 0 1 1-4 0V3z"/><circle cx="12" cy="17" r="2" fill="currentColor" stroke="none"/><path d="M12 5v10"/></g>);
Gly.lock      = G(<g><rect x="4" y="11" width="16" height="10"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/></g>);
Gly.speaker   = G(<g><rect x="6" y="3" width="12" height="18"/><circle cx="12" cy="15" r="3"/><circle cx="12" cy="7" r="1" fill="currentColor" stroke="none"/></g>);
Gly.camera    = G(<g><rect x="2" y="6" width="14" height="12"/><path d="M16 10l6-3v10l-6-3z"/></g>);
Gly.fan       = G(<g><circle cx="12" cy="12" r="2"/><path d="M12 10c0-5 3-8 6-6-2 3-5 4-6 6zM14 12c5 0 8 3 6 6-3-2-4-5-6-6zM12 14c0 5-3 8-6 6 2-3 5-4 6-6zM10 12c-5 0-8-3-6-6 3 2 4 5 6 6z"/></g>);
Gly.door      = G(<g><rect x="5" y="3" width="14" height="18"/><circle cx="15" cy="12" r="0.8" fill="currentColor" stroke="none"/></g>);
Gly.sofa      = G(<g><path d="M3 14v4M21 14v4M5 14h14M5 14v-3a3 3 0 0 1 3-3h8a3 3 0 0 1 3 3v3M3 14a2 2 0 0 1 2-2M21 14a2 2 0 0 0-2-2"/></g>);
Gly.bed       = G(<g><path d="M3 19v-8h18v8M3 15h18M3 19v2M21 19v2"/><rect x="6" y="8" width="5" height="3"/></g>);
Gly.kitchen   = G(<g><path d="M8 2v7M10 2v7c0 1-1 2-2 2s-2-1-2-2V2M8 11v11M16 2c-2 0-3 2-3 4s1 4 3 4v12"/></g>);
Gly.play      = G(<path d="M7 5l12 7-12 7V5z"/>);
Gly.pause     = G(<g><rect x="7" y="5" width="3" height="14"/><rect x="14" y="5" width="3" height="14"/></g>);
Gly.next      = G(<g><path d="M6 5l9 7-9 7V5z"/><path d="M17 5v14"/></g>);
Gly.heat      = G(<path d="M12 3s-4 5-4 8a4 4 0 0 0 8 0c0-3-4-8-4-8z"/>);
Gly.cool      = G(<g><path d="M12 2v20M2 12h20M4.5 4.5l15 15M19.5 4.5l-15 15"/></g>);
Gly.auto      = G(<g><path d="M7 18L12 6l5 12M9 14h6"/></g>);
Gly.off       = G(<g><path d="M12 3v10"/><path d="M5.6 8A8 8 0 1 0 18.4 8"/></g>);
Gly.drop      = G(<path d="M12 3s-6 7-6 12a6 6 0 0 0 12 0c0-5-6-12-6-12z"/>);
Gly.wind      = G(<g><path d="M3 8h11a2.5 2.5 0 1 0-2.5-2.5M3 16h16a2.5 2.5 0 1 1-2.5 2.5M3 12h9"/></g>);
Gly.wifi      = G(<g><path d="M2 8.5a16 16 0 0 1 20 0M5 12a12 12 0 0 1 14 0M8 15.5a8 8 0 0 1 8 0"/><circle cx="12" cy="19" r="1" fill="currentColor" stroke="none"/></g>);
Gly.wifiSlash = G(<g><path d="M2 8.5a16 16 0 0 1 20 0M5 12a12 12 0 0 1 14 0"/><path d="M3 3l18 18"/></g>);
Gly.bolt      = G(<path d="M13 3L4 14h7l-1 7 9-11h-7l1-7z"/>);
Gly.dot       = G(<circle cx="12" cy="12" r="4" fill="currentColor" stroke="none"/>);
Gly.arrowUp   = G(<path d="M12 19V5M5 12l7-7 7 7"/>);
Gly.arrowDn   = G(<path d="M12 5v14M5 12l7 7 7-7"/>);
Gly.arrowR    = G(<path d="M5 12h14M12 5l7 7-7 7"/>);
Gly.target    = G(<g><circle cx="12" cy="12" r="8"/><circle cx="12" cy="12" r="4"/><circle cx="12" cy="12" r="1" fill="currentColor" stroke="none"/></g>);
Gly.search    = G(<g><circle cx="11" cy="11" r="7"/><path d="M16 16l5 5"/></g>);
Gly.user      = G(<g><circle cx="12" cy="8" r="4"/><path d="M4 21c0-4 4-7 8-7s8 3 8 7"/></g>);
Gly.grid     = G(<g><rect x="3" y="3" width="7" height="7"/><rect x="14" y="3" width="7" height="7"/><rect x="3" y="14" width="7" height="7"/><rect x="14" y="14" width="7" height="7"/></g>);

// Helper: render a glyph by key. JSX can't do <Gly[key]/> directly.
function GlyBy({ name, ...rest }) {
  const C = Gly[name] || Gly.dot;
  return <C {...rest} />;
}

window.Gly = Gly;
window.GlyBy = GlyBy;
