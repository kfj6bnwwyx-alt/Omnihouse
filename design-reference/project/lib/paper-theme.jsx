// ─────────────────────────────────────────────────────────────
// PAPER — Editorial brutalist.
// Cream page, ink black, single oxblood accent. Serif display
// ("Instrument Serif") paired with mono labels (IBM Plex Mono).
// Strict 8-col grid. Tiny all-caps micro-labels. Big numerics.
// Hairlines, not borders. Zero shadows. Frame bg: warm ivory.
// ─────────────────────────────────────────────────────────────

const paperTokens = {
  page: "#ece7dc",
  paper: "#f4efe5",
  ink: "#141210",
  subtle: "#6b655a",
  rule: "#1a1815",
  accent: "#7a1f1a",
  frame: "#1a1815",
  dark: false,
};

function PaperLabel({ children, style }) {
  return <div style={{
    fontFamily: "'IBM Plex Mono', monospace", fontSize: 10, fontWeight: 500,
    color: paperTokens.subtle, letterSpacing: 1.8, textTransform: "uppercase",
    ...style,
  }}>{children}</div>;
}
function PaperRule({ heavy = false }) {
  return <div style={{ height: heavy ? 2 : 1, background: paperTokens.rule, width: "100%" }} />;
}
function PaperCell({ children, style, onClick }) {
  return <div onClick={onClick} style={{
    padding: "14px 16px", background: paperTokens.paper,
    borderBottom: `1px solid ${paperTokens.rule}`, cursor: onClick ? "pointer" : "default",
    ...style,
  }}>{children}</div>;
}

// ─── Splash ────────────────────────────────────────────────
function PaperSplash() {
  return (
    <div style={{ background: paperTokens.page, minHeight: "100%", padding: "30px 22px 80px", color: paperTokens.ink,
      display: "flex", flexDirection: "column", justifyContent: "space-between", height: "100%" }}>
      <div>
        <PaperLabel style={{ marginBottom: 4 }}>ISSUE № 01 · APR 2026</PaperLabel>
        <PaperRule heavy />
      </div>

      <div>
        <div style={{
          fontFamily: "'Instrument Serif', serif", fontSize: 104, lineHeight: 0.85,
          color: paperTokens.ink, letterSpacing: -3,
        }}>House<br/><span style={{ fontStyle: "italic", color: paperTokens.accent }}>Connect</span></div>
        <div style={{ marginTop: 28, fontFamily: "'IBM Plex Mono', monospace", fontSize: 11,
          color: paperTokens.subtle, letterSpacing: 1, lineHeight: 1.6, textTransform: "uppercase" }}>
          A home / seventeen devices /<br/>six rooms / one controller.
        </div>
      </div>

      <div>
        <PaperRule />
        <div style={{ display: "flex", justifyContent: "space-between", padding: "10px 0",
          fontFamily: "'IBM Plex Mono', monospace", fontSize: 10, color: paperTokens.subtle, letterSpacing: 1.5 }}>
          <span>V 1.0.0</span>
          <span>EST. 2025</span>
          <span>LOADING ██████░░</span>
        </div>
      </div>
    </div>
  );
}

// ─── Home ──────────────────────────────────────────────────
function PaperHome({ go }) {
  const { counts, weather, scenes, rooms, home } = HOUSE_DATA;
  return (
    <div style={{ background: paperTokens.page, color: paperTokens.ink, paddingBottom: 40 }}>
      {/* Masthead */}
      <div style={{ padding: "6px 22px 0" }}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
          <PaperLabel>FRI / 17 APR / 09:41</PaperLabel>
          <PaperLabel>EDITION VII</PaperLabel>
        </div>
        <PaperRule heavy />
        <div style={{
          fontFamily: "'Instrument Serif', serif", fontSize: 64, lineHeight: 0.9,
          letterSpacing: -1.8, padding: "10px 0 2px",
        }}>
          Good <span style={{ fontStyle: "italic", color: paperTokens.accent }}>Morning</span>,<br/>Alex.
        </div>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline", paddingBottom: 10 }}>
          <PaperLabel>{home}</PaperLabel>
          <PaperLabel>PORTLAND · 51°F</PaperLabel>
        </div>
        <PaperRule />
      </div>

      {/* Dashboard counters */}
      <div style={{ display: "grid", gridTemplateColumns: "repeat(3, 1fr)", borderBottom: `1px solid ${paperTokens.rule}` }}>
        {[
          ["DEVICES", counts.devices],
          ["ACTIVE",  counts.active],
          ["OFFLINE", counts.offline],
        ].map(([l, n], i) => (
          <div key={l} style={{
            padding: "14px 14px", borderLeft: i === 0 ? "none" : `1px solid ${paperTokens.rule}`,
            display: "flex", flexDirection: "column", gap: 4,
          }}>
            <PaperLabel>{l}</PaperLabel>
            <div className="tnum" style={{ fontFamily: "'Instrument Serif', serif", fontSize: 42, lineHeight: 1, color: i === 2 && counts.offline ? paperTokens.accent : paperTokens.ink }}>
              {String(n).padStart(2, "0")}
            </div>
          </div>
        ))}
      </div>

      {/* Weather column */}
      <div style={{ padding: "14px 22px", borderBottom: `1px solid ${paperTokens.rule}`, display: "flex", gap: 14, alignItems: "flex-start" }}>
        <div style={{ width: 40, height: 40, border: `1px solid ${paperTokens.rule}`, display: "flex", alignItems: "center", justifyContent: "center" }}>
          <Gly.cloud size={22} stroke={paperTokens.ink} sw={1.5}/>
        </div>
        <div style={{ flex: 1 }}>
          <div style={{ fontFamily: "'Instrument Serif', serif", fontSize: 22, lineHeight: 1.1 }}>
            51°F <span style={{ fontStyle: "italic", color: paperTokens.subtle }}>overcast.</span>
          </div>
          <PaperLabel style={{ marginTop: 3 }}>{weather.suggestion}</PaperLabel>
        </div>
      </div>

      {/* Scenes — editorial list */}
      <div style={{ padding: "16px 22px 6px", display: "flex", justifyContent: "space-between" }}>
        <div style={{ fontFamily: "'Instrument Serif', serif", fontSize: 28, fontStyle: "italic" }}>Scenes.</div>
        <PaperLabel>05 / STORED</PaperLabel>
      </div>
      <div style={{ borderTop: `1px solid ${paperTokens.rule}`, borderBottom: `1px solid ${paperTokens.rule}` }}>
        {scenes.slice(0, 4).map((s, i) => (
          <div key={s.id} style={{
            display: "flex", alignItems: "center", gap: 14, padding: "12px 22px",
            borderBottom: i < 3 ? `1px solid ${paperTokens.rule}` : "none",
          }}>
            <span className="tnum" style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 10,
              color: paperTokens.subtle, width: 22 }}>0{i + 1}</span>
            <div style={{ width: 28, height: 28, display: "flex", alignItems: "center", justifyContent: "center" }}>
              <GlyBy name={s.glyph} size={20} stroke={paperTokens.ink} sw={1.5} />
            </div>
            <div style={{ flex: 1, fontFamily: "'Instrument Serif', serif", fontSize: 20 }}>{s.name}</div>
            <PaperLabel>{s.desc.toUpperCase()}</PaperLabel>
            <Gly.chevR size={14} stroke={paperTokens.subtle}/>
          </div>
        ))}
      </div>

      {/* Rooms — index card grid */}
      <div style={{ padding: "16px 22px 6px", display: "flex", justifyContent: "space-between" }}>
        <div style={{ fontFamily: "'Instrument Serif', serif", fontSize: 28, fontStyle: "italic" }}>Rooms.</div>
        <PaperLabel>06 / CATALOGUED</PaperLabel>
      </div>
      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", borderTop: `1px solid ${paperTokens.rule}` }}>
        {rooms.map((r, i) => (
          <div key={r.id} onClick={() => go("room")} style={{
            padding: "14px 16px",
            borderRight: i % 2 === 0 ? `1px solid ${paperTokens.rule}` : "none",
            borderBottom: `1px solid ${paperTokens.rule}`, cursor: "pointer",
            display: "flex", flexDirection: "column", gap: 8, minHeight: 110, justifyContent: "space-between",
          }}>
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start" }}>
              <GlyBy name={r.glyph} size={22} stroke={paperTokens.ink} sw={1.5}/>
              <PaperLabel style={{ color: r.active ? paperTokens.accent : paperTokens.subtle }}>
                {r.active}/{r.total}
              </PaperLabel>
            </div>
            <div>
              <div style={{ fontFamily: "'Instrument Serif', serif", fontSize: 24, lineHeight: 1, letterSpacing: -0.4 }}>{r.name}</div>
              <PaperLabel style={{ marginTop: 2 }}>No. 0{i + 1}</PaperLabel>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

// ─── Room detail ───────────────────────────────────────────
function PaperRoom({ go }) {
  const devices = DEVICES.r1;
  return (
    <div style={{ background: paperTokens.page, color: paperTokens.ink, paddingBottom: 60 }}>
      <div style={{ padding: "6px 22px 0", display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <button onClick={() => go("home")} style={{ all: "unset", cursor: "pointer", display: "flex", alignItems: "center", gap: 8 }}>
          <Gly.back size={14} stroke={paperTokens.ink} sw={1.8}/>
          <PaperLabel>INDEX</PaperLabel>
        </button>
        <PaperLabel>ROOM · NO. 01</PaperLabel>
      </div>
      <PaperRule heavy />

      <div style={{ padding: "16px 22px 18px" }}>
        <div style={{ fontFamily: "'Instrument Serif', serif", fontSize: 72, lineHeight: 0.85, letterSpacing: -2 }}>
          Living<br/><span style={{ fontStyle: "italic", color: paperTokens.accent }}>Room</span>.
        </div>
        <div style={{ marginTop: 14, display: "flex", gap: 24 }}>
          <div><PaperLabel>ACTIVE</PaperLabel>
            <div className="tnum" style={{ fontFamily: "'Instrument Serif', serif", fontSize: 28 }}>03/05</div></div>
          <div><PaperLabel>PROVIDER</PaperLabel>
            <div style={{ fontFamily: "'Instrument Serif', serif", fontSize: 20, fontStyle: "italic" }}>HomeKit + Nest</div></div>
        </div>
      </div>
      <PaperRule />

      <div style={{ padding: "16px 22px 8px", display: "flex", justifyContent: "space-between" }}>
        <div style={{ fontFamily: "'Instrument Serif', serif", fontSize: 24, fontStyle: "italic" }}>Devices.</div>
        <PaperLabel>{devices.length} CATALOGUED</PaperLabel>
      </div>

      <div style={{ borderTop: `1px solid ${paperTokens.rule}` }}>
        {devices.map((d, i) => (
          <div key={d.id} onClick={() => d.cat === "thermo" && go("thermo")} style={{
            display: "grid", gridTemplateColumns: "32px 32px 1fr auto",
            gap: 14, padding: "14px 22px", alignItems: "center",
            borderBottom: `1px solid ${paperTokens.rule}`,
            cursor: d.cat === "thermo" ? "pointer" : "default",
          }}>
            <span className="tnum" style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 10, color: paperTokens.subtle }}>
              {String(i + 1).padStart(2, "0")}
            </span>
            <GlyBy name={d.glyph} size={22} stroke={paperTokens.ink} sw={1.5}/>
            <div>
              <div style={{ fontFamily: "'Instrument Serif', serif", fontSize: 19, lineHeight: 1.1 }}>{d.name}</div>
              <PaperLabel style={{ marginTop: 2, color: d.on ? paperTokens.accent : paperTokens.subtle }}>
                {d.state} · {d.provider}
              </PaperLabel>
            </div>
            {/* Toggle */}
            <div style={{
              width: 42, height: 22, border: `1px solid ${paperTokens.rule}`,
              background: d.on ? paperTokens.ink : "transparent", position: "relative",
            }}>
              <div style={{
                position: "absolute", top: 2, left: d.on ? 22 : 2, width: 16, height: 16,
                background: d.on ? paperTokens.page : paperTokens.ink,
              }} />
            </div>
          </div>
        ))}
      </div>

      <div style={{ padding: "20px 22px" }}>
        <PaperLabel style={{ color: paperTokens.accent }}>→ TAP THERMOSTAT FOR DETAIL</PaperLabel>
      </div>
    </div>
  );
}

// ─── Thermostat ────────────────────────────────────────────
function PaperThermo({ go }) {
  const [tgt, setTgt] = React.useState(THERM.target);
  const { current, mode, humidity, outdoor, outdoorHumidity, schedule, range } = THERM;
  const modes = [["heat", "Heat"], ["cool", "Cool"], ["auto", "Auto"], ["off", "Off"]];
  const [m, setM] = React.useState(mode);
  const pct = (tgt - range[0]) / (range[1] - range[0]);

  return (
    <div style={{ background: paperTokens.page, color: paperTokens.ink, paddingBottom: 40 }}>
      <div style={{ padding: "6px 22px 0", display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <button onClick={() => go("room")} style={{ all: "unset", cursor: "pointer", display: "flex", alignItems: "center", gap: 8 }}>
          <Gly.back size={14} stroke={paperTokens.ink} sw={1.8}/>
          <PaperLabel>ROOM</PaperLabel>
        </button>
        <PaperLabel>NEST · LIVE</PaperLabel>
      </div>
      <PaperRule heavy />

      {/* Header */}
      <div style={{ padding: "14px 22px" }}>
        <PaperLabel>LIVING ROOM THERMOSTAT</PaperLabel>
        <div style={{ fontFamily: "'Instrument Serif', serif", fontSize: 30, fontStyle: "italic", marginTop: 2 }}>Climate.</div>
      </div>
      <PaperRule />

      {/* Huge temperature */}
      <div style={{ padding: "24px 22px 18px", position: "relative" }}>
        <div style={{ display: "flex", alignItems: "flex-start", justifyContent: "space-between" }}>
          <div>
            <PaperLabel>INTERIOR</PaperLabel>
            <div className="tnum" style={{
              fontFamily: "'Instrument Serif', serif", fontSize: 160, lineHeight: 0.8,
              letterSpacing: -6, color: paperTokens.ink,
            }}>
              {current}<span style={{ fontSize: 60, color: paperTokens.accent, verticalAlign: "top" }}>°</span>
            </div>
          </div>
          <div style={{ display: "flex", flexDirection: "column", gap: 8, alignItems: "flex-end", paddingTop: 28 }}>
            <button onClick={() => setTgt(t => t + 1)} style={{ all: "unset", cursor: "pointer", width: 44, height: 44,
              border: `1px solid ${paperTokens.rule}`, display: "flex", alignItems: "center", justifyContent: "center" }}>
              <Gly.plus size={18} stroke={paperTokens.ink} sw={1.8}/>
            </button>
            <button onClick={() => setTgt(t => t - 1)} style={{ all: "unset", cursor: "pointer", width: 44, height: 44,
              border: `1px solid ${paperTokens.rule}`, display: "flex", alignItems: "center", justifyContent: "center" }}>
              <Gly.minus size={18} stroke={paperTokens.ink} sw={1.8}/>
            </button>
          </div>
        </div>
        <div style={{ marginTop: 6, display: "flex", gap: 16, alignItems: "baseline" }}>
          <PaperLabel>TARGET</PaperLabel>
          <div className="tnum" style={{ fontFamily: "'Instrument Serif', serif", fontSize: 28, fontStyle: "italic" }}>
            {tgt}°F
          </div>
          <div style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 10, color: paperTokens.subtle, letterSpacing: 1.5 }}>
            · HEATING TO TARGET
          </div>
        </div>

        {/* Range bar */}
        <div style={{ marginTop: 14, position: "relative", height: 18, borderTop: `1px solid ${paperTokens.rule}`, borderBottom: `1px solid ${paperTokens.rule}` }}>
          <div style={{ position: "absolute", inset: 0, background: `repeating-linear-gradient(90deg, ${paperTokens.rule} 0, ${paperTokens.rule} 1px, transparent 1px, transparent 12px)`, opacity: 0.35 }}/>
          <div style={{ position: "absolute", left: `${pct * 100}%`, top: -6, width: 2, height: 30, background: paperTokens.accent, transform: "translateX(-1px)" }}/>
        </div>
        <div style={{ display: "flex", justifyContent: "space-between", marginTop: 4 }}>
          <PaperLabel>{range[0]}°</PaperLabel>
          <PaperLabel>{range[1]}°</PaperLabel>
        </div>
      </div>
      <PaperRule />

      {/* Mode row */}
      <div style={{ padding: "14px 22px 6px" }}>
        <PaperLabel>MODE</PaperLabel>
      </div>
      <div style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)",
        borderTop: `1px solid ${paperTokens.rule}`, borderBottom: `1px solid ${paperTokens.rule}` }}>
        {modes.map(([k, l], i) => {
          const a = m === k;
          return (
            <button key={k} onClick={() => setM(k)} style={{
              all: "unset", cursor: "pointer", padding: "16px 8px", textAlign: "center",
              background: a ? paperTokens.ink : "transparent", color: a ? paperTokens.page : paperTokens.ink,
              borderLeft: i === 0 ? "none" : `1px solid ${paperTokens.rule}`,
            }}>
              <div style={{ fontFamily: "'Instrument Serif', serif", fontSize: 20, fontStyle: a ? "italic" : "normal" }}>{l}</div>
              <div style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 9, letterSpacing: 1.5,
                marginTop: 2, opacity: a ? 0.7 : 0.5 }}>{a ? "ACTIVE" : "—"}</div>
            </button>
          );
        })}
      </div>

      {/* Stats card */}
      <div style={{ padding: "16px 22px 6px" }}>
        <PaperLabel>CONDITIONS</PaperLabel>
      </div>
      <div style={{ display: "grid", gridTemplateColumns: "repeat(3, 1fr)",
        borderTop: `1px solid ${paperTokens.rule}`, borderBottom: `1px solid ${paperTokens.rule}` }}>
        {[
          ["INT HUM", `${humidity}%`],
          ["OUT TEMP", `${outdoor}°`],
          ["OUT HUM", `${outdoorHumidity}%`],
        ].map(([l, v], i) => (
          <div key={l} style={{ padding: "14px 12px", borderLeft: i === 0 ? "none" : `1px solid ${paperTokens.rule}` }}>
            <PaperLabel>{l}</PaperLabel>
            <div className="tnum" style={{ fontFamily: "'Instrument Serif', serif", fontSize: 32, lineHeight: 1, marginTop: 2 }}>{v}</div>
          </div>
        ))}
      </div>

      {/* Schedule */}
      <div style={{ padding: "16px 22px 6px", display: "flex", justifyContent: "space-between" }}>
        <div style={{ fontFamily: "'Instrument Serif', serif", fontSize: 22, fontStyle: "italic" }}>Schedule.</div>
        <PaperLabel>WEEKDAY</PaperLabel>
      </div>
      <div style={{ borderTop: `1px solid ${paperTokens.rule}` }}>
        {schedule.map((s, i) => (
          <div key={s.label} style={{ display: "grid", gridTemplateColumns: "100px 1fr auto",
            gap: 12, padding: "10px 22px", alignItems: "center",
            borderBottom: `1px solid ${paperTokens.rule}` }}>
            <PaperLabel>{s.label}</PaperLabel>
            <div className="tnum" style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 13, color: paperTokens.subtle }}>{s.time}</div>
            <div className="tnum" style={{ fontFamily: "'Instrument Serif', serif", fontSize: 22 }}>{s.temp}°</div>
          </div>
        ))}
      </div>
    </div>
  );
}

// ─── Tab bar ───────────────────────────────────────────────
function PaperTabs({ current, go }) {
  const tabs = [
    ["home",   "Home",    "home"],
    ["rooms",  "Rooms",   "rooms"],
    ["dev",    "Devices", "devices"],
    ["set",    "Settings","settings"],
  ];
  const cur = current === "room" || current === "thermo" ? "rooms" : "home";
  return (
    <div style={{
      position: "absolute", bottom: 24, left: 12, right: 12, zIndex: 60,
      display: "grid", gridTemplateColumns: "repeat(4, 1fr)",
      background: paperTokens.page, border: `1px solid ${paperTokens.rule}`,
    }}>
      {tabs.map(([k, l, g], i) => {
        const a = cur === k;
        return (
          <button key={k} onClick={() => go(k === "rooms" ? "room" : "home")} style={{
            all: "unset", cursor: "pointer", padding: "10px 4px",
            borderLeft: i === 0 ? "none" : `1px solid ${paperTokens.rule}`,
            display: "flex", flexDirection: "column", alignItems: "center", gap: 4,
            background: a ? paperTokens.ink : "transparent",
            color: a ? paperTokens.page : paperTokens.ink,
          }}>
            <GlyBy name={g} size={16} stroke={a ? paperTokens.page : paperTokens.ink} sw={1.4}/>
            <span style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 9, letterSpacing: 1, textTransform: "uppercase" }}>{l}</span>
          </button>
        );
      })}
    </div>
  );
}

window.PaperTheme = { tokens: paperTokens, Splash: PaperSplash, Home: PaperHome, Room: PaperRoom, Thermo: PaperThermo, Tabs: PaperTabs };
