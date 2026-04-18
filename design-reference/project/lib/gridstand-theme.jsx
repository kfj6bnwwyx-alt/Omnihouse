// ─────────────────────────────────────────────────────────────
// GRIDSTAND — Swiss International Style / Müller-Brockmann.
// Strict asymmetric grid, big Inter Tight display, red accent on
// white, black rules, numbered indexing, mono captions. No
// rounded corners. Typographic hierarchy carries everything.
// ─────────────────────────────────────────────────────────────

const gsTokens = {
  page:   "#ffffff",
  panel:  "#f7f7f5",
  ink:    "#111111",
  sub:    "#6b6b68",
  rule:   "#111111",
  hair:   "#dcdcd6",
  accent: "#d6210e",   // Swiss red
  frame:  "#1a1a1a",
  dark:   false,
};
const g = gsTokens;

function GCap({ children, style, color }) {
  return <div style={{
    fontFamily: "'JetBrains Mono', monospace", fontSize: 10, fontWeight: 500,
    color: color || g.sub, letterSpacing: 1, textTransform: "uppercase", ...style,
  }}>{children}</div>;
}
function GHair({ style }) { return <div style={{ height: 1, background: g.hair, ...style }}/>; }
function GRuleH({ style }) { return <div style={{ height: 1, background: g.rule, ...style }}/>; }

// ─── Splash ────────────────────────────────────────────────
function GSSplash() {
  return (
    <div style={{ background: g.page, height: "100%", padding: "18px 24px 40px",
      color: g.ink, display: "flex", flexDirection: "column", justifyContent: "space-between" }}>
      {/* 12-col grid markers */}
      <div style={{ display: "flex", justifyContent: "space-between" }}>
        <GCap>01 / House Connect</GCap>
        <GCap>V 1.0</GCap>
      </div>
      <GRuleH style={{ marginTop: 8 }}/>

      <div>
        <div style={{
          fontFamily: "'Inter Tight', sans-serif", fontSize: 92, fontWeight: 700,
          lineHeight: 0.86, letterSpacing: -3.5, color: g.ink,
        }}>
          House<br/>Connect<span style={{ color: g.accent }}>.</span>
        </div>
        <div style={{ marginTop: 20, display: "grid", gridTemplateColumns: "1fr 1fr", gap: 16 }}>
          <div>
            <GCap>Abstract</GCap>
            <div style={{ fontSize: 13, color: g.ink, marginTop: 4, lineHeight: 1.45 }}>
              A single controller for the domestic network.
            </div>
          </div>
          <div>
            <GCap>Inventory</GCap>
            <div className="tnum" style={{ fontFamily: "'Inter Tight', sans-serif",
              fontSize: 22, fontWeight: 600, color: g.ink, marginTop: 2, letterSpacing: -0.5 }}>
              17 / 6
            </div>
            <div style={{ fontSize: 11, color: g.sub, marginTop: 2 }}>Devices / Rooms</div>
          </div>
        </div>
      </div>

      <div>
        <GRuleH style={{ marginBottom: 10 }}/>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
          <GCap>Loading registry</GCap>
          <div className="tnum" style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 11, color: g.ink }}>
            014 / 017
          </div>
        </div>
        <div style={{ marginTop: 8, height: 4, background: g.hair, position: "relative" }}>
          <div style={{ position: "absolute", inset: 0, width: "82%", background: g.accent }}/>
        </div>
      </div>
    </div>
  );
}

// ─── Home ──────────────────────────────────────────────────
function GSHome({ go }) {
  const { counts, scenes, rooms, home } = HOUSE_DATA;
  return (
    <div style={{ background: g.page, color: g.ink, paddingBottom: 110 }}>
      <div style={{ padding: "8px 20px 0", display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <GCap>{home} · Index</GCap>
        <GCap>Fri 17.04 / 09:41</GCap>
      </div>
      <GRuleH style={{ margin: "8px 0 0" }}/>

      {/* 12-column asymmetric hero */}
      <div style={{ padding: "18px 20px 22px", display: "grid", gridTemplateColumns: "7fr 5fr", gap: 12, alignItems: "flex-end" }}>
        <div>
          <GCap>No. 01</GCap>
          <div style={{
            fontFamily: "'Inter Tight', sans-serif", fontSize: 54, fontWeight: 700,
            letterSpacing: -1.8, lineHeight: 0.92, marginTop: 4,
          }}>
            Good<br/>morning<span style={{ color: g.accent }}>.</span>
          </div>
        </div>
        <div>
          <GCap>Status</GCap>
          <div className="tnum" style={{ fontFamily: "'Inter Tight', sans-serif",
            fontSize: 38, fontWeight: 600, letterSpacing: -1, lineHeight: 1, marginTop: 4 }}>
            {counts.active}<span style={{ color: g.sub, fontWeight: 400 }}>/{counts.devices}</span>
          </div>
          <div style={{ fontSize: 11, color: g.sub, marginTop: 4 }}>On · Today</div>
        </div>
      </div>

      <GRuleH/>

      {/* Three-column data header */}
      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr" }}>
        {[
          ["Outside", "51°", "Overcast"],
          ["Inside",  "68°", "42% humidity"],
          ["Energy",  "1.4kW", "Today"],
        ].map(([l, v, s], i) => (
          <div key={l} style={{ padding: "16px 16px",
            borderLeft: i === 0 ? "none" : `1px solid ${g.hair}` }}>
            <GCap>{l}</GCap>
            <div className="tnum" style={{ fontFamily: "'Inter Tight', sans-serif",
              fontSize: 26, fontWeight: 600, letterSpacing: -0.8, marginTop: 4 }}>{v}</div>
            <div style={{ fontSize: 10, color: g.sub, marginTop: 2 }}>{s}</div>
          </div>
        ))}
      </div>
      <GRuleH/>

      {/* Scenes */}
      <div style={{ padding: "18px 20px 8px", display: "flex", justifyContent: "space-between", alignItems: "baseline" }}>
        <div>
          <GCap>Fig. 01</GCap>
          <div style={{ fontFamily: "'Inter Tight', sans-serif", fontSize: 22, fontWeight: 600, letterSpacing: -0.6, marginTop: 2 }}>
            Scenes
          </div>
        </div>
        <GCap>05 stored</GCap>
      </div>
      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr" }}>
        {scenes.slice(0, 4).map((s, i) => (
          <div key={s.id} style={{ padding: "14px 16px",
            borderTop: `1px solid ${g.hair}`,
            borderLeft: i % 2 === 1 ? `1px solid ${g.hair}` : "none",
            display: "flex", gap: 12, alignItems: "center" }}>
            <GlyBy name={s.glyph} size={22} stroke={g.ink} sw={1.4}/>
            <div>
              <div style={{ fontFamily: "'Inter Tight', sans-serif", fontSize: 15, fontWeight: 600, letterSpacing: -0.2 }}>{s.name}</div>
              <div style={{ fontSize: 10, color: g.sub, fontFamily: "'JetBrains Mono', monospace",
                letterSpacing: 0.6, marginTop: 2, textTransform: "uppercase" }}>{s.desc}</div>
            </div>
          </div>
        ))}
      </div>
      <GRuleH/>

      {/* Rooms — big typographic list */}
      <div style={{ padding: "18px 20px 8px", display: "flex", justifyContent: "space-between", alignItems: "baseline" }}>
        <div>
          <GCap>Fig. 02</GCap>
          <div style={{ fontFamily: "'Inter Tight', sans-serif", fontSize: 22, fontWeight: 600, letterSpacing: -0.6, marginTop: 2 }}>
            Rooms
          </div>
        </div>
        <GCap>{rooms.length} total</GCap>
      </div>
      <div>
        {rooms.map((r, i) => (
          <div key={r.id} onClick={() => go("room")} style={{
            display: "grid", gridTemplateColumns: "36px 1fr 24px 72px 14px",
            gap: 10, alignItems: "center", padding: "14px 20px",
            borderTop: `1px solid ${g.hair}`,
            borderBottom: i === rooms.length - 1 ? `1px solid ${g.hair}` : "none",
            cursor: "pointer",
          }}>
            <GCap className="tnum" color={g.accent}>{String(i + 1).padStart(2, "0")}</GCap>
            <div style={{ fontFamily: "'Inter Tight', sans-serif", fontSize: 22, fontWeight: 500, letterSpacing: -0.6 }}>{r.name}</div>
            <GlyBy name={r.glyph} size={18} stroke={g.ink} sw={1.4}/>
            <span className="tnum" style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 11, color: g.sub, textAlign: "right" }}>
              {r.active}/{r.total} on
            </span>
            <GlyBy name="chevR" size={12} stroke={g.sub} sw={1.4}/>
          </div>
        ))}
      </div>
    </div>
  );
}

// ─── Room ──────────────────────────────────────────────────
function GSRoom({ go }) {
  const devices = DEVICES.r1;
  return (
    <div style={{ background: g.page, color: g.ink, paddingBottom: 110 }}>
      <div style={{ padding: "8px 20px 0", display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <button onClick={() => go("home")} style={{ all: "unset", cursor: "pointer",
          display: "flex", alignItems: "center", gap: 6 }}>
          <GlyBy name="back" size={12} stroke={g.ink} sw={1.5}/>
          <GCap color={g.ink}>Index</GCap>
        </button>
        <GCap>Room / 01</GCap>
      </div>
      <GRuleH style={{ margin: "8px 0 0" }}/>

      <div style={{ padding: "22px 20px 20px", display: "grid", gridTemplateColumns: "8fr 4fr", gap: 12, alignItems: "flex-end" }}>
        <div>
          <GCap color={g.accent}>No. 01</GCap>
          <div style={{
            fontFamily: "'Inter Tight', sans-serif", fontSize: 54, fontWeight: 700,
            letterSpacing: -1.8, lineHeight: 0.9, marginTop: 4,
          }}>
            Living<br/>Room<span style={{ color: g.accent }}>.</span>
          </div>
        </div>
        <div>
          <GCap>Active</GCap>
          <div className="tnum" style={{ fontFamily: "'Inter Tight', sans-serif",
            fontSize: 36, fontWeight: 700, letterSpacing: -1, marginTop: 4 }}>
            3<span style={{ color: g.sub, fontWeight: 400 }}>/5</span>
          </div>
          <div style={{ fontSize: 10, color: g.sub, marginTop: 4, fontFamily: "'JetBrains Mono', monospace", letterSpacing: 0.5, textTransform: "uppercase" }}>
            HomeKit + Sonos
          </div>
        </div>
      </div>
      <GRuleH/>

      <div style={{ padding: "16px 20px 6px", display: "flex", justifyContent: "space-between", alignItems: "baseline" }}>
        <div>
          <GCap>Fig. 03</GCap>
          <div style={{ fontFamily: "'Inter Tight', sans-serif", fontSize: 18, fontWeight: 600, letterSpacing: -0.4, marginTop: 2 }}>
            Devices
          </div>
        </div>
        <GCap>{devices.length} total</GCap>
      </div>

      <div>
        {devices.map((d, i) => (
          <div key={d.id} onClick={() => d.cat === "thermo" && go("thermo")}
            style={{ display: "grid", gridTemplateColumns: "36px 26px 1fr auto",
              gap: 12, alignItems: "center", padding: "16px 20px",
              borderTop: `1px solid ${g.hair}`,
              borderBottom: i === devices.length - 1 ? `1px solid ${g.hair}` : "none",
              cursor: d.cat === "thermo" ? "pointer" : "default" }}>
            <GCap className="tnum" color={d.on ? g.accent : g.sub}>{String(i + 1).padStart(2, "0")}</GCap>
            <GlyBy name={d.glyph} size={18} stroke={g.ink} sw={1.4}/>
            <div>
              <div style={{ fontFamily: "'Inter Tight', sans-serif", fontSize: 16, fontWeight: 500, letterSpacing: -0.2 }}>{d.name}</div>
              <div style={{ fontSize: 10, color: g.sub, fontFamily: "'JetBrains Mono', monospace",
                letterSpacing: 0.5, marginTop: 2, textTransform: "uppercase" }}>
                {d.state} · {d.provider}
              </div>
            </div>
            {/* Switch: flat square */}
            <div style={{
              width: 42, height: 22, background: d.on ? g.accent : g.hair,
              position: "relative",
            }}>
              <div style={{
                position: "absolute", top: 2, left: d.on ? 22 : 2, width: 18, height: 18,
                background: "#fff",
              }}/>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

// ─── Thermostat ────────────────────────────────────────────
function GSThermo({ go }) {
  const [tgt, setTgt] = React.useState(THERM.target);
  const [m, setM] = React.useState(THERM.mode);
  const { current, humidity, outdoor, outdoorHumidity, schedule, range } = THERM;
  const modes = [["heat", "Heat", "heat"], ["cool", "Cool", "cool"], ["auto", "Auto", "auto"], ["off", "Off", "off"]];
  const pct = (tgt - range[0]) / (range[1] - range[0]);

  return (
    <div style={{ background: g.page, color: g.ink, paddingBottom: 110 }}>
      <div style={{ padding: "8px 20px 0", display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <button onClick={() => go("room")} style={{ all: "unset", cursor: "pointer",
          display: "flex", alignItems: "center", gap: 6 }}>
          <GlyBy name="back" size={12} stroke={g.ink} sw={1.5}/>
          <GCap color={g.ink}>Living Room</GCap>
        </button>
        <GCap color={g.accent}>● Heating</GCap>
      </div>
      <GRuleH style={{ margin: "8px 0 0" }}/>

      {/* Hero temperature */}
      <div style={{ padding: "22px 20px 8px", display: "grid", gridTemplateColumns: "1fr auto", alignItems: "flex-end" }}>
        <div>
          <GCap>Interior</GCap>
          <div className="tnum" style={{
            fontFamily: "'Inter Tight', sans-serif", fontSize: 180, fontWeight: 700,
            letterSpacing: -10, lineHeight: 0.82, marginTop: 2,
          }}>
            {current}<span style={{ fontSize: 72, color: g.accent, letterSpacing: 0 }}>°</span>
          </div>
        </div>
      </div>
      <div style={{ padding: "0 20px 18px", display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <div>
          <GCap>Target</GCap>
          <div className="tnum" style={{ fontFamily: "'Inter Tight', sans-serif",
            fontSize: 26, fontWeight: 600, letterSpacing: -0.6, marginTop: 2 }}>
            {tgt}°
          </div>
        </div>
        <div style={{ display: "flex", gap: 8 }}>
          <button onClick={() => setTgt(v => v - 1)} style={{
            all: "unset", cursor: "pointer", width: 52, height: 52,
            border: `1px solid ${g.ink}`, display: "flex", alignItems: "center", justifyContent: "center",
            background: g.page,
          }}><GlyBy name="minus" size={16} stroke={g.ink} sw={1.6}/></button>
          <button onClick={() => setTgt(v => v + 1)} style={{
            all: "unset", cursor: "pointer", width: 52, height: 52, background: g.accent,
            display: "flex", alignItems: "center", justifyContent: "center",
          }}><GlyBy name="plus" size={18} stroke="#fff" sw={1.8}/></button>
        </div>
      </div>

      {/* Scale */}
      <div style={{ padding: "0 20px 22px" }}>
        <div style={{ position: "relative", height: 32,
          borderTop: `1px solid ${g.rule}`, borderBottom: `1px solid ${g.hair}` }}>
          {Array.from({ length: 31 }).map((_, i) => {
            const f = i / 30;
            const major = i % 5 === 0;
            return <div key={i} style={{
              position: "absolute", left: `${f * 100}%`, top: 0,
              width: 1, height: major ? 10 : 5, background: g.ink,
            }}/>;
          })}
          <div style={{ position: "absolute", left: `${pct * 100}%`, top: 0, bottom: 0,
            width: 2, background: g.accent, transform: "translateX(-1px)" }}/>
        </div>
        <div className="tnum" style={{ display: "flex", justifyContent: "space-between", marginTop: 4,
          fontFamily: "'JetBrains Mono', monospace", fontSize: 10, color: g.sub, letterSpacing: 0.5, textTransform: "uppercase" }}>
          <span>{range[0]}°F</span><span>75°F</span><span>{range[1]}°F</span>
        </div>
      </div>
      <GRuleH/>

      {/* Mode — flat segmented */}
      <div style={{ padding: "16px 20px 8px" }}>
        <GCap>Mode</GCap>
      </div>
      <div style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)",
        borderTop: `1px solid ${g.hair}`, borderBottom: `1px solid ${g.hair}` }}>
        {modes.map(([k, l, gl], i) => {
          const a = m === k;
          return (
            <button key={k} onClick={() => setM(k)} style={{
              all: "unset", cursor: "pointer", padding: "14px 4px", textAlign: "center",
              background: a ? g.ink : "transparent", color: a ? g.page : g.ink,
              borderLeft: i === 0 ? "none" : `1px solid ${g.hair}`,
              display: "flex", flexDirection: "column", alignItems: "center", gap: 5,
            }}>
              <GlyBy name={gl} size={16} stroke={a ? g.page : g.ink} sw={1.4}/>
              <span style={{ fontSize: 12, fontWeight: 500, letterSpacing: -0.1 }}>{l}</span>
            </button>
          );
        })}
      </div>

      {/* Conditions */}
      <div style={{ padding: "16px 20px 8px" }}>
        <GCap>Conditions</GCap>
      </div>
      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr",
        borderTop: `1px solid ${g.hair}`, borderBottom: `1px solid ${g.hair}` }}>
        {[
          ["Int Hum", `${humidity}%`],
          ["Out Temp", `${outdoor}°`],
          ["Out Hum", `${outdoorHumidity}%`],
        ].map(([l, v], i) => (
          <div key={l} style={{ padding: "14px 12px",
            borderLeft: i === 0 ? "none" : `1px solid ${g.hair}` }}>
            <GCap>{l}</GCap>
            <div className="tnum" style={{ fontFamily: "'Inter Tight', sans-serif",
              fontSize: 26, fontWeight: 600, letterSpacing: -0.6, marginTop: 4 }}>{v}</div>
          </div>
        ))}
      </div>

      {/* Schedule */}
      <div style={{ padding: "16px 20px 8px", display: "flex", justifyContent: "space-between", alignItems: "baseline" }}>
        <div>
          <GCap>Fig. 04</GCap>
          <div style={{ fontFamily: "'Inter Tight', sans-serif", fontSize: 18, fontWeight: 600, letterSpacing: -0.4, marginTop: 2 }}>
            Schedule
          </div>
        </div>
        <GCap>Weekday</GCap>
      </div>
      {schedule.map((s, i) => (
        <div key={s.label} style={{
          display: "grid", gridTemplateColumns: "36px 90px 1fr auto",
          gap: 10, padding: "12px 20px", alignItems: "center",
          borderTop: `1px solid ${g.hair}`,
          borderBottom: i === schedule.length - 1 ? `1px solid ${g.hair}` : "none",
        }}>
          <GCap className="tnum" color={g.accent}>{String(i + 1).padStart(2, "0")}</GCap>
          <GCap color={g.ink}>{s.label}</GCap>
          <span className="tnum" style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 11, color: g.sub }}>{s.time}</span>
          <span className="tnum" style={{ fontFamily: "'Inter Tight', sans-serif", fontSize: 20, fontWeight: 600 }}>{s.temp}°</span>
        </div>
      ))}
    </div>
  );
}

// ─── Tabs ──────────────────────────────────────────────────
function GSTabs({ current, go }) {
  const tabs = [
    ["home",  "Home",    "home",    "home"],
    ["rooms", "Rooms",   "rooms",   "room"],
    ["dev",   "Devices", "devices", "home"],
    ["set",   "Settings","settings","home"],
  ];
  const cur = current === "room" || current === "thermo" ? "rooms" : "home";
  return (
    <div style={{
      position: "absolute", bottom: 0, left: 0, right: 0, zIndex: 60,
      paddingBottom: 30, background: g.page, borderTop: `1px solid ${g.rule}`,
    }}>
      <div style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", padding: "10px 0 6px" }}>
        {tabs.map(([k, l, gl, target], i) => {
          const a = cur === k;
          return (
            <button key={k} onClick={() => go(target)} style={{
              all: "unset", cursor: "pointer", padding: "4px 4px",
              display: "flex", flexDirection: "column", alignItems: "center", gap: 3,
              color: a ? g.accent : g.sub, position: "relative",
            }}>
              <GlyBy name={gl} size={20} stroke={a ? g.accent : g.sub} sw={a ? 1.7 : 1.4}/>
              <span style={{ fontSize: 10, fontWeight: 500, letterSpacing: 0 }}>{l}</span>
              {a && <div style={{ position: "absolute", top: -11, width: 22, height: 2, background: g.accent }}/>}
            </button>
          );
        })}
      </div>
    </div>
  );
}

window.GridstandTheme = { tokens: g, Splash: GSSplash, Home: GSHome, Room: GSRoom, Thermo: GSThermo, Tabs: GSTabs };
