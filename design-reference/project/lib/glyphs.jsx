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

// ── extended set for detail / network / multi-room screens ─────────────────
Gly.zap       = G(<path d="M13 3L4 14h7l-1 7 9-11h-7l1-7z"/>);
Gly.triangle  = G(<g><path d="M12 3L2 20h20L12 3z"/><path d="M12 10v4M12 17v.01"/></g>);
Gly.siren     = G(<g><path d="M7 18V10a5 5 0 0 1 10 0v8"/><rect x="5" y="18" width="14" height="3"/><path d="M12 3v2M4 8l1.5 1M20 8l-1.5 1"/></g>);
Gly.bluetooth = G(<path d="M7 7l10 10-5 5V2l5 5L7 17"/>);
Gly.disc      = G(<g><circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="3"/><circle cx="12" cy="12" r="0.8" fill="currentColor" stroke="none"/></g>);
Gly.tv        = G(<g><rect x="2" y="5" width="20" height="13"/><path d="M8 21h8M12 18v3"/></g>);
Gly.radar     = G(<g><circle cx="12" cy="12" r="3"/><circle cx="12" cy="12" r="7"/><circle cx="12" cy="12" r="10"/><line x1="12" y1="12" x2="19" y2="7"/></g>);
Gly.mic       = G(<g><rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5 12a7 7 0 0 0 14 0M12 19v3"/></g>);
Gly.skipBack  = G(<g><path d="M18 5L9 12l9 7V5z"/><path d="M7 5v14"/></g>);
Gly.shuffle   = G(<g><path d="M16 3h5v5M21 3l-8 8M4 21l8-8M16 21h5v-5M4 3l6 6"/></g>);
Gly.repeat    = G(<g><path d="M17 1l4 4-4 4M3 11v-2a4 4 0 0 1 4-4h14M7 23l-4-4 4-4M21 13v2a4 4 0 0 1-4 4H3"/></g>);
Gly.xCircle   = G(<g><circle cx="12" cy="12" r="9"/><path d="M9 9l6 6M15 9l-6 6"/></g>);
Gly.power     = G(<g><path d="M12 3v9"/><path d="M5.6 8A8 8 0 1 0 18.4 8"/></g>);
Gly.refresh   = G(<g><path d="M20 8a8 8 0 1 0 1 8"/><path d="M20 3v5h-5"/></g>);
Gly.ping      = G(<g><circle cx="12" cy="12" r="2" fill="currentColor" stroke="none"/><circle cx="12" cy="12" r="6"/><circle cx="12" cy="12" r="10"/></g>);
Gly.restart   = G(<g><path d="M3 12a9 9 0 1 0 3-6.7"/><path d="M3 3v6h6"/></g>);
Gly.trash     = G(<g><path d="M3 6h18M8 6V4h8v2M6 6l1 15h10l1-15"/></g>);
Gly.crown     = G(<path d="M3 18l2-10 5 5 2-8 2 8 5-5 2 10z"/>);
Gly.hub       = G(<g><circle cx="12" cy="12" r="3"/><circle cx="3"  cy="6"  r="2"/><circle cx="21" cy="6"  r="2"/><circle cx="3"  cy="18" r="2"/><circle cx="21" cy="18" r="2"/><path d="M5 7l5 4M19 7l-5 4M5 17l5-3M19 17l-5-3"/></g>);
Gly.key       = G(<g><circle cx="8" cy="15" r="4"/><path d="M11 12l10-10M17 6l3 3M14 9l3 3"/></g>);
Gly.globe     = G(<g><circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3a14 14 0 0 1 0 18M12 3a14 14 0 0 0 0 18"/></g>);
Gly.snow      = G(<path d="M12 2v20M4 6l16 12M4 18l16-12M2 12h20M5 8l2-1-1-2M19 16l-2 1 1 2M19 8l-2-1 1-2M5 16l2 1-1 2"/>);
Gly.rain      = G(<g><path d="M7 14h11a4 4 0 0 0 .6-7.95A6 6 0 0 0 7 6.5 4 4 0 0 0 7 14z"/><path d="M8 18v3M12 18v3M16 18v3"/></g>);
Gly.lightning = G(<g><path d="M7 14h11a4 4 0 0 0 .6-7.95A6 6 0 0 0 7 6.5 4 4 0 0 0 7 14z"/><path d="M13 14l-2 4h3l-2 4"/></g>);
Gly.fog       = G(<g><path d="M3 15h18M3 19h14M7 11h13M9 7h12"/></g>);
Gly.warn      = G(<g><circle cx="12" cy="12" r="9"/><path d="M12 7v6M12 16v.01"/></g>);
Gly.info      = G(<g><circle cx="12" cy="12" r="9"/><path d="M12 8v.01M12 11v5"/></g>);
Gly.group     = G(<g><circle cx="8" cy="9" r="3"/><circle cx="16" cy="9" r="3"/><path d="M2 19c0-3 3-5 6-5M22 19c0-3-3-5-6-5"/></g>);
Gly.shield    = G(<g><path d="M12 3l8 3v6c0 5-4 8-8 9-4-1-8-4-8-9V6l8-3z"/></g>);
Gly.node      = G(<g><circle cx="12" cy="12" r="3"/><circle cx="12" cy="3"  r="1.5" fill="currentColor" stroke="none"/><circle cx="12" cy="21" r="1.5" fill="currentColor" stroke="none"/><circle cx="3"  cy="12" r="1.5" fill="currentColor" stroke="none"/><circle cx="21" cy="12" r="1.5" fill="currentColor" stroke="none"/><path d="M12 5v4M12 15v4M5 12h4M15 12h4"/></g>);
Gly.layers    = G(<g><path d="M12 2L2 7l10 5 10-5-10-5z"/><path d="M2 12l10 5 10-5M2 17l10 5 10-5"/></g>);
Gly.volUp     = G(<g><path d="M3 9v6h4l5 4V5L7 9H3z"/><path d="M16 8a6 6 0 0 1 0 8M19 5a10 10 0 0 1 0 14"/></g>);
Gly.volDn     = G(<g><path d="M3 9v6h4l5 4V5L7 9H3z"/><path d="M16 10a3 3 0 0 1 0 4"/></g>);
Gly.volMute   = G(<g><path d="M3 9v6h4l5 4V5L7 9H3z"/><path d="M16 9l5 6M21 9l-5 6"/></g>);
Gly.music     = G(<g><path d="M9 18V5l12-2v13"/><circle cx="6" cy="18" r="3"/><circle cx="18" cy="16" r="3"/></g>);
Gly.house     = G(<path d="M3 11l9-7 9 7v9h-6v-6h-6v6H3v-9z"/>);
Gly.zoneMap   = G(<g><path d="M3 6l6-3 6 3 6-3v15l-6 3-6-3-6 3V6z"/><path d="M9 3v15M15 6v15"/></g>);
Gly.art       = G(<g><rect x="3" y="3" width="18" height="14"/><path d="M3 12l5-5 4 4 3-3 6 6M3 21h18"/></g>);

// Helper: render a glyph by key. JSX can't do <Gly[key]/> directly.
function GlyBy({ name, ...rest }) {
  const C = Gly[name] || Gly.dot;
  return <C {...rest} />;
}

window.Gly = Gly;
window.GlyBy = GlyBy;
