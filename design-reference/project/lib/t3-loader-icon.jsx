// T3 animated loader — replaces the static splash.
// - 16px orange dot pulses (scale + opacity)
// - "house connect." wordmark fades + subtly slides up on mount
// - 10-bar progress fills left-to-right continuously (loops)
// - Tiny numeric counter (00 / 10 → 10 / 10) driven by the same clock
// All motion is deterministic — no requestAnimationFrame jitter.

function T3Loader() {
  const [step, setStep] = React.useState(0);      // 0..10 progress bars
  const [mounted, setMounted] = React.useState(false);

  React.useEffect(() => {
    setMounted(true);
    const id = setInterval(() => {
      setStep(s => (s + 1) % 11);
    }, 260);
    return () => clearInterval(id);
  }, []);

  const tt = window.T3Primitives.tokens;
  const XTLabel = window.T3Primitives.TLabel;
  const XTRule  = window.T3Primitives.TRule;

  return (
    <div style={{
      background: tt.page, height: "100%", minHeight: "100%",
      padding: "22px 28px 46px", color: tt.ink,
      display: "flex", flexDirection: "column", justifyContent: "space-between",
    }}>
      {/* animation keyframes */}
      <style>{`
        @keyframes t3pulse {
          0%,100% { transform: scale(1);   opacity: 1; }
          50%     { transform: scale(1.35); opacity: 0.55; }
        }
        @keyframes t3fadeup {
          from { opacity: 0; transform: translateY(10px); }
          to   { opacity: 1; transform: translateY(0); }
        }
        @keyframes t3tagline {
          from { opacity: 0; }
          to   { opacity: 1; }
        }
        @keyframes t3barfill {
          from { transform: scaleX(0); }
          to   { transform: scaleX(1); }
        }
        .t3-dot { animation: t3pulse 1.4s ease-in-out infinite; transform-origin: center; }
        .t3-word { animation: t3fadeup 680ms cubic-bezier(.2,.7,.2,1) both; }
        .t3-word-2 { animation-delay: 140ms; }
        .t3-tagline { animation: t3tagline 900ms ease-out 420ms both; }
        .t3-bar-on { position: relative; overflow: hidden; }
        .t3-bar-on::after {
          content: ""; position: absolute; inset: 0; background: currentColor;
          transform-origin: left center; animation: t3barfill 240ms ease-out both;
        }
      `}</style>

      {/* Top meta */}
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <XTLabel>House Connect</XTLabel>
        <XTLabel>V 1.0</XTLabel>
      </div>

      {/* Centerpiece */}
      <div style={{ display: "flex", flexDirection: "column", alignItems: "flex-start" }}>
        <span className="t3-dot" style={{
          display: "inline-block", width: 16, height: 16, borderRadius: "50%",
          background: tt.accent,
        }}/>
        <div style={{
          fontFamily: "'Inter Tight', sans-serif", fontSize: 44, fontWeight: 500,
          color: tt.ink, letterSpacing: -1.4, lineHeight: 1, marginTop: 22,
          display: "flex", flexDirection: "column",
        }}>
          <span className="t3-word">house</span>
          <span className="t3-word t3-word-2">connect.</span>
        </div>
        <div className="t3-tagline" style={{ marginTop: 14, fontSize: 13,
          color: tt.sub, lineHeight: 1.5, maxWidth: 240 }}>
          A calm controller for everything at home. Seventeen devices, six rooms.
        </div>
      </div>

      {/* Bottom progress */}
      <div>
        <XTRule style={{ marginBottom: 10 }}/>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
          <XTLabel>Loading</XTLabel>
          <div style={{ display: "flex", gap: 3 }}>
            {Array.from({ length: 10 }).map((_, i) => {
              const on = i < step;
              return (
                <div key={i} className={on ? "t3-bar-on" : ""}
                  style={{ width: 6, height: 2, color: tt.ink,
                    background: on ? "transparent" : tt.rule }}/>
              );
            })}
          </div>
          <XTLabel style={{ fontVariantNumeric: "tabular-nums" }}>
            {String(step).padStart(2, "0")} / 10
          </XTLabel>
        </div>
      </div>
    </div>
  );
}

// iOS app icon — 1024×1024 safe area, matches T3 DNA.
// Cream field, dispersing 3-bar "signal" mark in ink, single orange dot.
// Rendered as an SVG that scales perfectly.
function T3AppIcon({ size = 180, radius }) {
  const r = radius ?? Math.round(size * 0.225); // ~ iOS 22.5% squircle
  return (
    <div style={{
      width: size, height: size, borderRadius: r, overflow: "hidden",
      position: "relative",
      boxShadow: "0 24px 40px -12px rgba(0,0,0,0.24), 0 0 0 1px rgba(0,0,0,0.08)",
      background: "#f2f1ed",
    }}>
      <svg viewBox="0 0 200 200" width={size} height={size}
        style={{ position: "absolute", inset: 0 }}>
        {/* faint hairline grid to telegraph "Swiss precision" */}
        <g stroke="#d9d7d0" strokeWidth="0.5">
          <line x1="0"   y1="50"  x2="200" y2="50" />
          <line x1="0"   y1="100" x2="200" y2="100"/>
          <line x1="0"   y1="150" x2="200" y2="150"/>
          <line x1="50"  y1="0"   x2="50"  y2="200"/>
          <line x1="100" y1="0"   x2="100" y2="200"/>
          <line x1="150" y1="0"   x2="150" y2="200"/>
        </g>

        {/* signal / hearth mark — concentric arcs radiating from bottom-left,
            evoking a radio dial, a room plan, and a hearth all at once */}
        <g fill="none" stroke="#0e0e0d" strokeWidth="6" strokeLinecap="square">
          <path d="M 40 160 A 40 40 0 0 1 80 120"/>
          <path d="M 40 160 A 70 70 0 0 1 110 90"/>
          <path d="M 40 160 A 100 100 0 0 1 140 60"/>
        </g>

        {/* base tick */}
        <line x1="40" y1="160" x2="160" y2="160" stroke="#0e0e0d" strokeWidth="6"/>

        {/* Braun orange dot — the source/power */}
        <circle cx="40" cy="160" r="8" fill="#e7591a"/>
      </svg>
    </div>
  );
}

window.T3Loader = T3Loader;
window.T3AppIcon = T3AppIcon;
