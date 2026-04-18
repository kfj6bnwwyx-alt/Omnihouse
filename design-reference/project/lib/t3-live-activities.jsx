// Live Activities + alternative app icons for T3.
// Live Activities use a darker palette than the in-app design — iOS lock
// screen and dynamic island sit on black; we keep Braun orange as "normal"
// accent and introduce a single red for emergencies only.

const LA_TOKENS = {
  bg:      "#000000",
  panel:   "#1c1c1e",
  ink:     "#ffffff",
  sub:     "#8e8e93",
  rule:    "#2c2c2e",
  orange:  "#e7591a",  // Braun orange — info / normal
  red:     "#ff453a",  // iOS system red — emergency only
  green:   "#30d158",
};

// ── Helper: phone frame approximation for Lock Screen / Island ───────────
function DeviceTop({ children, showNotch = true, clockTime = "9:41" }) {
  return (
    <div style={{
      position: "relative", width: 390, height: 360,
      borderRadius: 42, background: "#000",
      padding: 14, overflow: "hidden",
      boxShadow: "0 1px 0 rgba(255,255,255,0.08) inset, 0 30px 50px rgba(0,0,0,0.35)",
    }}>
      {/* Dynamic Island */}
      {showNotch && (
        <div style={{
          position: "absolute", top: 12, left: "50%", transform: "translateX(-50%)",
          zIndex: 50,
        }}>{children.island}</div>
      )}
      {/* Lock screen clock */}
      <div style={{ position: "absolute", top: 66, left: 0, right: 0, textAlign: "center",
        fontFamily: '-apple-system, "SF Pro", system-ui', color: "#fff",
        fontWeight: 200, fontSize: 78, letterSpacing: -3, lineHeight: 1 }}>
        {clockTime}
      </div>
      <div style={{ position: "absolute", top: 52, left: 0, right: 0, textAlign: "center",
        fontFamily: '-apple-system, "SF Pro", system-ui', color: "#fff",
        fontSize: 13, fontWeight: 500, letterSpacing: 0.5 }}>
        Friday, April 17
      </div>
      {/* Banner slot */}
      <div style={{ position: "absolute", left: 14, right: 14, bottom: 18 }}>
        {children.banner}
      </div>
    </div>
  );
}

// ── Dynamic Island: compact (emergency) ──────────────────────────────────
function IslandCompactEmergency() {
  return (
    <div style={{
      background: "#000", border: `1px solid ${LA_TOKENS.red}`,
      borderRadius: 999, height: 38, padding: "0 8px 0 12px",
      display: "flex", alignItems: "center", gap: 10,
      fontFamily: '-apple-system, "SF Pro", system-ui',
    }}>
      <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke={LA_TOKENS.red}
        strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
        <path d="M12 3L2 20h20L12 3z"/><path d="M12 10v4M12 17h.01" stroke={LA_TOKENS.red}/>
      </svg>
      <span style={{ color: "#fff", fontSize: 14, fontWeight: 600 }}>Smoke</span>
      <div style={{ width: 1, height: 16, background: "#333" }}/>
      <span style={{ color: LA_TOKENS.sub, fontSize: 12 }}>Living Rm</span>
      {/* pulsing status dot */}
      <span style={{
        marginLeft: "auto", width: 10, height: 10, borderRadius: "50%",
        background: LA_TOKENS.red, boxShadow: `0 0 0 3px rgba(255,69,58,0.25)`,
        animation: "la-pulse 1s ease-in-out infinite",
      }}/>
    </div>
  );
}

// ── Dynamic Island: compact (normal — scene running) ─────────────────────
function IslandCompactNormal() {
  return (
    <div style={{
      background: "#000", borderRadius: 999, height: 38, padding: "0 12px",
      display: "flex", alignItems: "center", gap: 10,
      fontFamily: '-apple-system, "SF Pro", system-ui',
    }}>
      <span style={{ width: 8, height: 8, borderRadius: "50%", background: LA_TOKENS.orange }}/>
      <span style={{ color: "#fff", fontSize: 14, fontWeight: 500 }}>Morning</span>
      <span style={{ color: LA_TOKENS.sub, fontSize: 12 }}>4 / 7</span>
    </div>
  );
}

// ── Dynamic Island: expanded (emergency) ─────────────────────────────────
function IslandExpandedEmergency() {
  return (
    <div style={{
      background: "#000", borderRadius: 36, padding: "18px 20px",
      width: 360,
      fontFamily: '-apple-system, "SF Pro", system-ui', color: "#fff",
    }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start" }}>
        <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
          <div style={{
            width: 40, height: 40, borderRadius: "50%",
            background: "rgba(255,69,58,0.15)",
            display: "flex", alignItems: "center", justifyContent: "center",
          }}>
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke={LA_TOKENS.red}
              strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <path d="M12 3L2 20h20L12 3z"/><path d="M12 10v4M12 17h.01"/>
            </svg>
          </div>
          <div>
            <div style={{ color: LA_TOKENS.red, fontSize: 16, fontWeight: 700 }}>Smoke Detected</div>
            <div style={{ color: LA_TOKENS.sub, fontSize: 13 }}>Living Room · Nest Protect</div>
          </div>
        </div>
        <span style={{ color: LA_TOKENS.sub, fontSize: 12 }}>2m ago</span>
      </div>

      <div style={{ marginTop: 14, display: "flex", alignItems: "center", gap: 8,
        fontSize: 14, color: "#fff" }}>
        <span style={{ fontSize: 14 }}>🔥</span>
        <span>Get everyone out immediately</span>
      </div>

      <div style={{ marginTop: 14, display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10 }}>
        <button style={{
          all: "unset", cursor: "pointer", background: LA_TOKENS.red,
          borderRadius: 999, padding: "12px 0", textAlign: "center",
          fontSize: 15, fontWeight: 600, display: "flex",
          alignItems: "center", justifyContent: "center", gap: 8,
        }}>
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#fff"
            strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <path d="M22 16.9v3a2 2 0 0 1-2.2 2 19.8 19.8 0 0 1-8.6-3.1 19.5 19.5 0 0 1-6-6A19.8 19.8 0 0 1 2 4.2 2 2 0 0 1 4 2h3a2 2 0 0 1 2 1.7c.1.9.3 1.8.6 2.7a2 2 0 0 1-.5 2.1l-1.3 1.3a16 16 0 0 0 6 6l1.3-1.3a2 2 0 0 1 2.1-.5c.9.3 1.8.5 2.7.6a2 2 0 0 1 1.7 2z"/>
          </svg>
          Call 911
        </button>
        <button style={{
          all: "unset", cursor: "pointer", background: LA_TOKENS.panel,
          borderRadius: 999, padding: "12px 0", textAlign: "center",
          fontSize: 15, fontWeight: 600, display: "flex",
          alignItems: "center", justifyContent: "center", gap: 8,
        }}>
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#fff"
            strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <path d="M13.73 21a2 2 0 0 1-3.46 0M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9M3 3l18 18"/>
          </svg>
          Silence
        </button>
      </div>
    </div>
  );
}

// ── Dynamic Island: expanded (normal — scene) ────────────────────────────
function IslandExpandedNormal() {
  return (
    <div style={{
      background: "#000", borderRadius: 36, padding: "18px 20px", width: 360,
      fontFamily: '-apple-system, "SF Pro", system-ui', color: "#fff",
    }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start" }}>
        <div>
          <div style={{ color: LA_TOKENS.sub, fontSize: 11, fontWeight: 500,
            letterSpacing: 1, textTransform: "uppercase" }}>House Connect</div>
          <div style={{ fontSize: 18, fontWeight: 600, marginTop: 2 }}>Morning scene</div>
        </div>
        <span style={{ color: LA_TOKENS.orange, fontSize: 13, fontWeight: 500 }}>Running</span>
      </div>
      <div style={{ marginTop: 12, display: "flex", alignItems: "center", gap: 10 }}>
        <div style={{ flex: 1, height: 4, background: LA_TOKENS.rule, borderRadius: 2, overflow: "hidden" }}>
          <div style={{ width: "58%", height: "100%", background: LA_TOKENS.orange }}/>
        </div>
        <span style={{ color: LA_TOKENS.sub, fontSize: 12, fontVariantNumeric: "tabular-nums" }}>4 / 7</span>
      </div>
      <div style={{ marginTop: 12, color: LA_TOKENS.sub, fontSize: 13 }}>
        Ceiling Lights → 80% · Thermostat → 71°
      </div>
    </div>
  );
}

// ── Standalone notification banner ───────────────────────────────────────
function NotifBanner({ emergency }) {
  if (emergency) {
    return (
      <div style={{
        background: "#1c1c1e", borderRadius: 20, padding: "14px 16px",
        fontFamily: '-apple-system, "SF Pro", system-ui', color: "#fff",
      }}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", gap: 12 }}>
          <div style={{ display: "flex", gap: 12, alignItems: "flex-start" }}>
            <div style={{ width: 32, height: 32, borderRadius: 8, background: "rgba(255,69,58,0.15)",
              display: "flex", alignItems: "center", justifyContent: "center" }}>
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke={LA_TOKENS.red}
                strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <path d="M12 3L2 20h20L12 3z"/><path d="M12 10v4M12 17h.01"/>
              </svg>
            </div>
            <div>
              <div style={{ color: LA_TOKENS.red, fontSize: 15, fontWeight: 700 }}>Smoke Detected</div>
              <div style={{ color: LA_TOKENS.sub, fontSize: 13 }}>Living Room · Nest Protect</div>
            </div>
          </div>
          <span style={{ color: LA_TOKENS.sub, fontSize: 12 }}>now</span>
        </div>
        <div style={{ marginTop: 10, fontSize: 13, color: "#fff" }}>
          🔥 Get everyone out immediately
        </div>
      </div>
    );
  }
  return (
    <div style={{
      background: "#1c1c1e", borderRadius: 20, padding: "14px 16px",
      fontFamily: '-apple-system, "SF Pro", system-ui', color: "#fff",
    }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start" }}>
        <div>
          <div style={{ color: LA_TOKENS.sub, fontSize: 11, letterSpacing: 1,
            textTransform: "uppercase", fontWeight: 500 }}>House Connect</div>
          <div style={{ fontSize: 15, fontWeight: 600, marginTop: 4 }}>Front Door unlocked</div>
          <div style={{ color: LA_TOKENS.sub, fontSize: 13, marginTop: 2 }}>
            Alex · Face ID · Entryway
          </div>
        </div>
        <span style={{ color: LA_TOKENS.sub, fontSize: 12 }}>now</span>
      </div>
    </div>
  );
}

// ── Lock Screen Live Activity ────────────────────────────────────────────
function LockLiveActivity({ emergency }) {
  if (emergency) {
    return (
      <div style={{
        background: "#1c1c1e", borderRadius: 24, padding: "18px 20px",
        fontFamily: '-apple-system, "SF Pro", system-ui', color: "#fff",
      }}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start" }}>
          <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
            <div style={{ width: 34, height: 34, borderRadius: "50%",
              background: "rgba(255,69,58,0.15)", display: "flex",
              alignItems: "center", justifyContent: "center" }}>
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke={LA_TOKENS.red}
                strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
                <path d="M12 3L2 20h20L12 3z"/><path d="M12 10v4M12 17h.01"/>
              </svg>
            </div>
            <div>
              <div style={{ color: LA_TOKENS.red, fontSize: 16, fontWeight: 700 }}>Smoke Detected</div>
              <div style={{ color: LA_TOKENS.sub, fontSize: 12 }}>Living Room · Nest Protect</div>
            </div>
          </div>
          <span style={{ color: LA_TOKENS.sub, fontSize: 11 }}>2m ago</span>
        </div>
        <div style={{ marginTop: 10, fontSize: 13, display: "flex", alignItems: "center", gap: 6 }}>
          🔥 <span>Get everyone out immediately</span>
        </div>
        <div style={{ marginTop: 12, display: "grid", gridTemplateColumns: "1fr 1fr", gap: 8 }}>
          <button style={{
            all: "unset", cursor: "pointer", background: LA_TOKENS.red,
            borderRadius: 999, padding: "10px 0", textAlign: "center",
            fontSize: 14, fontWeight: 600,
          }}>📞 Call 911</button>
          <button style={{
            all: "unset", cursor: "pointer", background: "#2c2c2e",
            borderRadius: 999, padding: "10px 0", textAlign: "center",
            fontSize: 14, fontWeight: 600,
          }}>🔕 Silence</button>
        </div>
      </div>
    );
  }
  // Scene running — calm variant
  return (
    <div style={{
      background: "#1c1c1e", borderRadius: 24, padding: "18px 20px",
      fontFamily: '-apple-system, "SF Pro", system-ui', color: "#fff",
    }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start" }}>
        <div>
          <div style={{ color: LA_TOKENS.sub, fontSize: 11, letterSpacing: 1,
            textTransform: "uppercase", fontWeight: 500 }}>Scene running</div>
          <div style={{ fontSize: 22, fontWeight: 600, marginTop: 2, letterSpacing: -0.4 }}>
            Morning
          </div>
        </div>
        <span style={{ width: 8, height: 8, borderRadius: "50%", background: LA_TOKENS.orange,
          marginTop: 6 }}/>
      </div>
      <div style={{ marginTop: 14, display: "flex", alignItems: "center", gap: 10 }}>
        <div style={{ flex: 1, height: 4, background: "#2c2c2e", borderRadius: 2, overflow: "hidden" }}>
          <div style={{ width: "58%", height: "100%", background: LA_TOKENS.orange }}/>
        </div>
        <span style={{ color: LA_TOKENS.sub, fontSize: 12, fontVariantNumeric: "tabular-nums" }}>4 / 7</span>
      </div>
      <div style={{ marginTop: 10, color: LA_TOKENS.sub, fontSize: 13 }}>
        Now: Thermostat → 71°
      </div>
    </div>
  );
}

// ── Alternative iOS app icons ────────────────────────────────────────────
function IconA({ size = 180 }) {
  // "Hearth" — signal arcs on cream (the established one, for comparison)
  const r = Math.round(size * 0.225);
  return (
    <div style={{ width: size, height: size, borderRadius: r, overflow: "hidden",
      background: "#f2f1ed", position: "relative",
      boxShadow: "0 24px 40px -12px rgba(0,0,0,0.24), 0 0 0 1px rgba(0,0,0,0.08)" }}>
      <svg viewBox="0 0 200 200" width={size} height={size}>
        <g stroke="#d9d7d0" strokeWidth="0.5">
          <line x1="0" y1="50" x2="200" y2="50"/><line x1="0" y1="100" x2="200" y2="100"/>
          <line x1="0" y1="150" x2="200" y2="150"/><line x1="50" y1="0" x2="50" y2="200"/>
          <line x1="100" y1="0" x2="100" y2="200"/><line x1="150" y1="0" x2="150" y2="200"/>
        </g>
        <g fill="none" stroke="#0e0e0d" strokeWidth="6" strokeLinecap="square">
          <path d="M 40 160 A 40 40 0 0 1 80 120"/>
          <path d="M 40 160 A 70 70 0 0 1 110 90"/>
          <path d="M 40 160 A 100 100 0 0 1 140 60"/>
        </g>
        <line x1="40" y1="160" x2="160" y2="160" stroke="#0e0e0d" strokeWidth="6"/>
        <circle cx="40" cy="160" r="8" fill="#e7591a"/>
      </svg>
    </div>
  );
}

function IconB({ size = 180 }) {
  // Monogram — lowercase h + c ligature, orange dot as counter
  const r = Math.round(size * 0.225);
  return (
    <div style={{ width: size, height: size, borderRadius: r, overflow: "hidden",
      background: "#0e0e0d", position: "relative",
      boxShadow: "0 24px 40px -12px rgba(0,0,0,0.24), 0 0 0 1px rgba(0,0,0,0.08)" }}>
      <svg viewBox="0 0 200 200" width={size} height={size}>
        <text x="100" y="142" textAnchor="middle"
          fill="#f2f1ed"
          fontFamily="Inter Tight, -apple-system, system-ui"
          fontSize="150" fontWeight="500" letterSpacing="-8">
          hc
        </text>
        {/* replace the dot on the 'i'-style or add a mark — use it as a period */}
        <circle cx="158" cy="138" r="9" fill="#e7591a"/>
      </svg>
    </div>
  );
}

function IconC({ size = 180 }) {
  // House-plan — floor plan rectangle divided into 4 rooms, one lit orange
  const r = Math.round(size * 0.225);
  return (
    <div style={{ width: size, height: size, borderRadius: r, overflow: "hidden",
      background: "#f2f1ed", position: "relative",
      boxShadow: "0 24px 40px -12px rgba(0,0,0,0.24), 0 0 0 1px rgba(0,0,0,0.08)" }}>
      <svg viewBox="0 0 200 200" width={size} height={size}>
        {/* outer house */}
        <rect x="36" y="52" width="128" height="112" fill="none" stroke="#0e0e0d" strokeWidth="8"/>
        {/* interior walls */}
        <line x1="100" y1="52" x2="100" y2="120" stroke="#0e0e0d" strokeWidth="6"/>
        <line x1="36"  y1="120" x2="164" y2="120" stroke="#0e0e0d" strokeWidth="6"/>
        <line x1="130" y1="120" x2="130" y2="164" stroke="#0e0e0d" strokeWidth="6"/>
        {/* lit room — orange fill */}
        <rect x="40" y="56" width="58" height="60" fill="#e7591a" opacity="0.9"/>
        {/* door notch */}
        <rect x="94" y="160" width="12" height="8" fill="#f2f1ed"/>
      </svg>
    </div>
  );
}

function IconD({ size = 180 }) {
  // Dial — Braun T3 power dial, big orange notch on black
  const r = Math.round(size * 0.225);
  return (
    <div style={{ width: size, height: size, borderRadius: r, overflow: "hidden",
      background: "#f2f1ed", position: "relative",
      boxShadow: "0 24px 40px -12px rgba(0,0,0,0.24), 0 0 0 1px rgba(0,0,0,0.08)" }}>
      <svg viewBox="0 0 200 200" width={size} height={size}>
        {/* outer dial */}
        <circle cx="100" cy="100" r="72" fill="#0e0e0d"/>
        {/* tick marks */}
        <g stroke="#f2f1ed" strokeWidth="3" strokeLinecap="square">
          {Array.from({ length: 12 }).map((_, i) => {
            const ang = (i / 12) * Math.PI * 2 - Math.PI / 2;
            const x1 = 100 + Math.cos(ang) * 64;
            const y1 = 100 + Math.sin(ang) * 64;
            const x2 = 100 + Math.cos(ang) * 70;
            const y2 = 100 + Math.sin(ang) * 70;
            return <line key={i} x1={x1} y1={y1} x2={x2} y2={y2}/>;
          })}
        </g>
        {/* indicator line pointing to 2 o'clock */}
        <line x1="100" y1="100" x2="140" y2="72" stroke="#f2f1ed" strokeWidth="5" strokeLinecap="round"/>
        {/* orange center cap */}
        <circle cx="100" cy="100" r="14" fill="#e7591a"/>
      </svg>
    </div>
  );
}

window.LiveActivities = {
  DeviceTop,
  IslandCompactEmergency, IslandCompactNormal,
  IslandExpandedEmergency, IslandExpandedNormal,
  NotifBanner, LockLiveActivity,
};
window.IconA = IconA; window.IconB = IconB; window.IconC = IconC; window.IconD = IconD;
