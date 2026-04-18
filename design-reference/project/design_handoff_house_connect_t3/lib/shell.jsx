// Brutalist iOS-ish frame. Keeps the phone silhouette, dynamic island, home
// indicator — but strips the iOS-26 glass chrome so each theme owns its look.
// Screen is a simple clipped rect; status bar + home indicator color adapts
// to dark={true|false}.

function HCStatusBar({ dark = false, time = "9:41" }) {
  const c = dark ? "#fff" : "#000";
  return (
    <div style={{
      display: "flex", alignItems: "center", justifyContent: "space-between",
      padding: "18px 32px 8px", position: "relative", zIndex: 20,
      fontFamily: '-apple-system, "SF Pro", system-ui',
    }}>
      <div style={{ fontWeight: 600, fontSize: 15, color: c, letterSpacing: -0.2 }}>{time}</div>
      <div style={{ width: 120 }} />
      <div style={{ display: "flex", gap: 6, alignItems: "center" }}>
        <svg width="16" height="10" viewBox="0 0 16 10">
          <rect x="0" y="6" width="2.5" height="4" rx="0.5" fill={c}/>
          <rect x="4" y="4" width="2.5" height="6" rx="0.5" fill={c}/>
          <rect x="8" y="2" width="2.5" height="8" rx="0.5" fill={c}/>
          <rect x="12" y="0" width="2.5" height="10" rx="0.5" fill={c}/>
        </svg>
        <svg width="22" height="10" viewBox="0 0 22 10">
          <rect x="0.5" y="0.5" width="19" height="9" rx="2" stroke={c} fill="none" strokeOpacity="0.4"/>
          <rect x="2" y="2" width="16" height="6" rx="1" fill={c}/>
          <rect x="20" y="3.5" width="1.5" height="3" rx="0.5" fill={c} opacity="0.4"/>
        </svg>
      </div>
    </div>
  );
}

function HCPhone({ children, dark = false, bg = "#fff", frameBg }) {
  const W = 390, H = 844;
  return (
    <div style={{
      width: W, height: H, position: "relative", borderRadius: 42,
      background: frameBg || "#0a0a0a",
      padding: 4,
      boxShadow: "0 1px 0 rgba(255,255,255,0.08) inset, 0 40px 70px rgba(0,0,0,0.22), 0 0 0 1px rgba(0,0,0,0.35)",
    }}>
      <div style={{
        width: "100%", height: "100%", borderRadius: 38, overflow: "hidden",
        background: bg, position: "relative",
      }}>
        {/* dynamic island */}
        <div style={{
          position: "absolute", top: 10, left: "50%", transform: "translateX(-50%)",
          width: 118, height: 34, borderRadius: 22, background: "#000", zIndex: 50,
        }} />
        {/* status bar */}
        <div style={{ position: "absolute", top: 0, left: 0, right: 0, zIndex: 10 }}>
          <HCStatusBar dark={dark} />
        </div>
        {/* content */}
        <div className="frame-scroll" style={{
          position: "absolute", inset: 0, overflowY: "auto",
          paddingTop: 52,
        }}>
          {children}
        </div>
        {/* home indicator */}
        <div style={{
          position: "absolute", bottom: 7, left: "50%", transform: "translateX(-50%)",
          width: 132, height: 5, borderRadius: 3, zIndex: 70,
          background: dark ? "rgba(255,255,255,0.75)" : "rgba(0,0,0,0.35)",
          pointerEvents: "none",
        }} />
      </div>
    </div>
  );
}

// Caption block above each phone in the canvas.
function HCCaption({ kicker, title, lede, accent = "#000" }) {
  return (
    <div style={{ width: 390, marginBottom: 20 }}>
      <div style={{
        fontFamily: "'JetBrains Mono', monospace", fontSize: 11, fontWeight: 600,
        color: accent, letterSpacing: 2, textTransform: "uppercase",
        borderTop: `2px solid ${accent}`, paddingTop: 8, marginBottom: 6,
      }}>
        {kicker}
      </div>
      <div style={{
        fontFamily: "'Archivo', sans-serif", fontSize: 28, fontWeight: 800,
        color: "#111", letterSpacing: -0.6, lineHeight: 1, marginBottom: 8,
      }}>
        {title}
      </div>
      <div style={{
        fontFamily: "'JetBrains Mono', monospace", fontSize: 11, lineHeight: 1.5,
        color: "#555", textTransform: "uppercase", letterSpacing: 0.5,
      }}>
        {lede}
      </div>
    </div>
  );
}

// Column wrapper — caption + phone + nav buttons for that phone
function HCColumn({ children }) {
  return (
    <div style={{ display: "flex", flexDirection: "column", alignItems: "flex-start" }}>
      {children}
    </div>
  );
}

// Screen nav chip row (sits below each phone)
function HCNavBar({ screens, current, setScreen, accent = "#000", ink = "#000" }) {
  return (
    <div style={{
      display: "flex", gap: 0, marginTop: 16, width: 390,
      border: `1.5px solid ${ink}`, background: "#fff",
    }}>
      {screens.map((s, i) => {
        const active = current === s.id;
        return (
          <button key={s.id}
            onClick={() => setScreen(s.id)}
            style={{
              flex: 1, padding: "10px 6px",
              borderLeft: i === 0 ? "none" : `1.5px solid ${ink}`,
              background: active ? accent : "transparent",
              color: active ? "#fff" : ink,
              fontFamily: "'JetBrains Mono', monospace", fontSize: 10, fontWeight: 700,
              letterSpacing: 1, textTransform: "uppercase", cursor: "pointer",
            }}>
            {s.label}
          </button>
        );
      })}
    </div>
  );
}

Object.assign(window, { HCPhone, HCStatusBar, HCCaption, HCColumn, HCNavBar });
