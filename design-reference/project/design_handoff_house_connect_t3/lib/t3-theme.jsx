// ─────────────────────────────────────────────────────────────
// T3 — Braun T3 pocket radio meets Dieter Rams.
// Off-white/cream, jet black text, ONE orange dot as accent.
// Pure grid, tiny all-caps mono labels, generous whitespace,
// functional iconography, numerals in Inter Tight tabular.
// Status bar chrome: light.
// ─────────────────────────────────────────────────────────────

const t3Tokens = {
  page:   "#f2f1ed",  // warm cream
  panel:  "#ffffff",
  ink:    "#0e0e0d",
  sub:    "#86847e",
  rule:   "#d9d7d0",
  accent: "#e7591a",  // Braun orange
  frame:  "#1a1a1a",
  dark:   false,
};
const t = t3Tokens;

function TLabel({ children, style, color }) {
  return <div style={{
    fontFamily: "'IBM Plex Mono', monospace", fontSize: 10, fontWeight: 400,
    color: color || t.sub, letterSpacing: 1.6, textTransform: "uppercase", ...style,
  }}>{children}</div>;
}
function TRule({ style }) { return <div style={{ height: 1, background: t.rule, ...style }}/>; }
function TDot({ size = 8, color = t.accent, style }) {
  return <span style={{ display: "inline-block", width: size, height: size, borderRadius: "50%", background: color, ...style }}/>;
}

// ─── Splash ────────────────────────────────────────────────
function T3Splash() {
  return (
    <div style={{ background: t.page, height: "100%", minHeight: "100%",
      padding: "22px 28px 46px", color: t.ink, display: "flex", flexDirection: "column",
      justifyContent: "space-between" }}>
      {/* Top meta */}
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <TLabel>House Connect</TLabel>
        <TLabel>V 1.0</TLabel>
      </div>

      {/* Centerpiece: single orange dot over tight logotype — like the T3 power dot */}
      <div style={{ display: "flex", flexDirection: "column", alignItems: "flex-start" }}>
        <TDot size={16}/>
        <div style={{
          fontFamily: "'Inter Tight', sans-serif", fontSize: 44, fontWeight: 500,
          color: t.ink, letterSpacing: -1.4, lineHeight: 1, marginTop: 22,
        }}>
          house<br/>connect.
        </div>
        <div style={{ marginTop: 14, fontSize: 13, color: t.sub, lineHeight: 1.5, maxWidth: 240 }}>
          A calm controller for everything at home. Seventeen devices, six rooms.
        </div>
      </div>

      {/* Bottom progress — minimal */}
      <div>
        <TRule style={{ marginBottom: 10 }}/>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
          <TLabel>Loading</TLabel>
          <div style={{ display: "flex", gap: 3 }}>
            {Array.from({ length: 10 }).map((_, i) => (
              <div key={i} style={{ width: 6, height: 2, background: i < 7 ? t.ink : t.rule }}/>
            ))}
          </div>
          <TLabel style={{ fontVariantNumeric: "tabular-nums" }}>07 / 10</TLabel>
        </div>
      </div>
    </div>
  );
}

// ─── Scene renderers — T3 default, Gridstand alt ──────────
function T3ScenesChipRow({ scenes }) {
  return (
    <>
      <div style={{ padding: "18px 24px 8px", display: "flex", justifyContent: "space-between", alignItems: "baseline" }}>
        <div style={{ fontFamily: "'Inter Tight', sans-serif", fontSize: 17, fontWeight: 500 }}>Scenes</div>
        <TLabel>05</TLabel>
      </div>
      <div style={{ padding: "0 24px 18px", display: "flex", gap: 8, overflowX: "auto" }}>
        {scenes.map((s, i) => (
          <button key={s.id} style={{
            all: "unset", cursor: "pointer", flexShrink: 0,
            display: "flex", alignItems: "center", gap: 8,
            padding: "8px 14px", border: `1px solid ${t.rule}`,
            background: i === 0 ? t.ink : t.panel,
            color: i === 0 ? t.page : t.ink, borderRadius: 999,
          }}>
            <GlyBy name={s.glyph} size={14} stroke={i === 0 ? t.page : t.ink} sw={1.4}/>
            <span style={{ fontSize: 13, fontWeight: 500, letterSpacing: -0.2 }}>{s.name}</span>
          </button>
        ))}
      </div>
    </>
  );
}

function GridstandScenesBlock({ scenes }) {
  // Adapted from Gridstand — typographic 2-col index, Swiss red mono caption.
  // Kept on T3's cream so it doesn't clash; accent borrowed from Gridstand red.
  const red = "#d6210e";
  return (
    <>
      <div style={{ padding: "18px 24px 8px", display: "flex", justifyContent: "space-between", alignItems: "baseline" }}>
        <div>
          <div style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 10, color: red,
            letterSpacing: 1, textTransform: "uppercase" }}>Fig. 01</div>
          <div style={{ fontFamily: "'Inter Tight', sans-serif", fontSize: 22, fontWeight: 600,
            letterSpacing: -0.6, marginTop: 2 }}>Scenes</div>
        </div>
        <TLabel>05 stored</TLabel>
      </div>
      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr" }}>
        {scenes.slice(0, 4).map((s, i) => (
          <div key={s.id} style={{
            padding: "14px 20px",
            borderTop: `1px solid ${t.rule}`,
            borderLeft: i % 2 === 1 ? `1px solid ${t.rule}` : "none",
            display: "grid", gridTemplateColumns: "22px 1fr", gap: 10, alignItems: "center",
          }}>
            <div style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 10,
              color: red, letterSpacing: 1 }} className="tnum">{String(i + 1).padStart(2, "0")}</div>
            <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
              <GlyBy name={s.glyph} size={20} stroke={t.ink} sw={1.4}/>
              <div>
                <div style={{ fontFamily: "'Inter Tight', sans-serif", fontSize: 15, fontWeight: 600,
                  letterSpacing: -0.2 }}>{s.name}</div>
                <div style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 10,
                  color: t.sub, letterSpacing: 0.6, textTransform: "uppercase", marginTop: 2 }}>
                  {s.desc}
                </div>
              </div>
            </div>
          </div>
        ))}
      </div>
    </>
  );
}

// ─── Home ──────────────────────────────────────────────────
function T3Home({ go, scenesStyle = "t3" }) {
  const { counts, scenes, rooms, home } = HOUSE_DATA;
  return (
    <div style={{ background: t.page, color: t.ink, paddingBottom: 110 }}>
      {/* Masthead */}
      <div style={{ padding: "8px 24px 0", display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <TLabel>{home}</TLabel>
        <TLabel>Fri 17 Apr · 09:41</TLabel>
      </div>

      <div style={{ padding: "20px 24px 10px" }}>
        <div style={{ fontFamily: "'Inter Tight', sans-serif", fontSize: 36, fontWeight: 500,
          letterSpacing: -1, lineHeight: 1.05 }}>
          Good morning, <span style={{ color: t.sub }}>Alex.</span>
        </div>
        <div style={{ marginTop: 6, display: "flex", alignItems: "center", gap: 10 }}>
          <TDot size={8}/>
          <TLabel>9 active · 1 offline · 7 standby</TLabel>
        </div>
      </div>

      <TRule/>

      {/* Weather strip — honest data readout */}
      <div style={{ padding: "18px 24px", display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: 18 }}>
        <div>
          <TLabel>Outside</TLabel>
          <div className="tnum" style={{ fontFamily: "'Inter Tight', sans-serif", fontSize: 38, fontWeight: 400,
            letterSpacing: -1.4, lineHeight: 1, marginTop: 4 }}>
            51°
          </div>
          <div style={{ fontSize: 11, color: t.sub, marginTop: 4 }}>Overcast</div>
        </div>
        <div>
          <TLabel>Inside</TLabel>
          <div className="tnum" style={{ fontFamily: "'Inter Tight', sans-serif", fontSize: 38, fontWeight: 400,
            letterSpacing: -1.4, lineHeight: 1, marginTop: 4 }}>
            68°
          </div>
          <div style={{ fontSize: 11, color: t.sub, marginTop: 4 }}>42% RH</div>
        </div>
        <div>
          <TLabel>Energy</TLabel>
          <div className="tnum" style={{ fontFamily: "'Inter Tight', sans-serif", fontSize: 38, fontWeight: 400,
            letterSpacing: -1.4, lineHeight: 1, marginTop: 4 }}>
            1.4<span style={{ fontSize: 15, color: t.sub, fontWeight: 400, marginLeft: 3 }}>kW</span>
          </div>
          <div style={{ fontSize: 11, color: t.sub, marginTop: 4 }}>Today</div>
        </div>
      </div>

      <TRule/>

      {scenesStyle === "gridstand"
        ? <GridstandScenesBlock scenes={scenes}/>
        : <T3ScenesChipRow scenes={scenes}/>}

      <TRule/>

      {/* Rooms — list, Braun-clean */}
      <div style={{ padding: "18px 24px 8px", display: "flex", justifyContent: "space-between", alignItems: "baseline" }}>
        <div style={{ fontFamily: "'Inter Tight', sans-serif", fontSize: 17, fontWeight: 500 }}>Rooms</div>
        <TLabel>{rooms.length}</TLabel>
      </div>
      <div>
        {rooms.map((r, i) => (
          <div key={r.id} onClick={() => go("room", { roomId: r.id })} style={{
            display: "grid", gridTemplateColumns: "28px 28px 1fr auto 14px",
            gap: 14, alignItems: "center", padding: "14px 24px",
            borderTop: `1px solid ${t.rule}`,
            borderBottom: i === rooms.length - 1 ? `1px solid ${t.rule}` : "none",
            cursor: "pointer",
          }}>
            <TLabel className="tnum">{String(i + 1).padStart(2, "0")}</TLabel>
            <GlyBy name={r.glyph} size={18} stroke={t.ink} sw={1.4}/>
            <div style={{ fontSize: 15, fontWeight: 500, letterSpacing: -0.2 }}>{r.name}</div>
            <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
              {r.active > 0 && <TDot size={6}/>}
              <span className="tnum" style={{ fontSize: 12, color: t.sub,
                fontFamily: "'IBM Plex Mono', monospace" }}>
                {r.active}/{r.total}
              </span>
            </div>
            <GlyBy name="chevR" size={12} stroke={t.sub} sw={1.4}/>
          </div>
        ))}
      </div>
    </div>
  );
}

// ─── Room ──────────────────────────────────────────────────
function T3Room({ go, roomId = "r1" }) {
  const room = HOUSE_DATA.rooms.find(r => r.id === roomId) || HOUSE_DATA.rooms[0];
  const devices = DEVICES[roomId] || [];
  const roomIdx = HOUSE_DATA.rooms.findIndex(r => r.id === roomId);
  const active = devices.filter(d => d.on).length;
  const providers = [...new Set(devices.map(d => d.provider))];
  return (
    <div style={{ background: t.page, color: t.ink, paddingBottom: 110 }}>
      <div style={{ padding: "8px 24px 0", display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <button onClick={() => go("rooms")} style={{ all: "unset", cursor: "pointer",
          display: "flex", alignItems: "center", gap: 6 }}>
          <GlyBy name="back" size={14} stroke={t.ink} sw={1.4}/>
          <TLabel color={t.ink}>Rooms</TLabel>
        </button>
        <TLabel>Room {String(roomIdx + 1).padStart(2, "0")}</TLabel>
      </div>

      <div style={{ padding: "22px 24px 18px" }}>
        <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
          {active > 0 && <TDot size={8}/>}
          <TLabel>{active > 0 ? "Active" : "Idle"}</TLabel>
        </div>
        <div style={{ fontFamily: "'Inter Tight', sans-serif", fontSize: 42, fontWeight: 500,
          letterSpacing: -1.4, lineHeight: 1, marginTop: 8 }}>
          {room.name}
        </div>
        <div style={{ marginTop: 10, fontSize: 13, color: t.sub }}>
          {active} of {devices.length} devices on · {providers.join(" + ")}
        </div>
      </div>

      <TRule/>

      <div style={{ padding: "16px 24px 6px", display: "flex", justifyContent: "space-between", alignItems: "baseline" }}>
        <div style={{ fontFamily: "'Inter Tight', sans-serif", fontSize: 15, fontWeight: 500 }}>Devices</div>
        <TLabel>{devices.length}</TLabel>
      </div>

      <div>
        {devices.map((d, i) => (
          <div key={d.id} onClick={() => {
            if (d.cat === "thermo") go("thermo");
            else if (d.cat === "light")  go("device", { deviceId: d.id });
            else if (d.cat === "lock")   go("device", { deviceId: d.id });
            else if (d.cat === "speaker") go("device", { deviceId: d.id });
          }}
            style={{ display: "grid", gridTemplateColumns: "28px 28px 1fr auto",
              gap: 14, alignItems: "center", padding: "16px 24px",
              borderTop: `1px solid ${t.rule}`,
              borderBottom: i === devices.length - 1 ? `1px solid ${t.rule}` : "none",
              cursor: ["thermo","light","lock","speaker"].includes(d.cat) ? "pointer" : "default",
            }}>
            <TLabel className="tnum">{String(i + 1).padStart(2, "0")}</TLabel>
            <GlyBy name={d.glyph} size={18} stroke={t.ink} sw={1.4}/>
            <div>
              <div style={{ fontSize: 15, fontWeight: 500, letterSpacing: -0.2 }}>{d.name}</div>
              <div style={{ fontSize: 11, color: t.sub, marginTop: 2, display: "flex", alignItems: "center", gap: 8 }}>
                {d.on && <TDot size={5}/>}
                <span>{d.state}</span>
                <span>·</span>
                <span style={{ fontFamily: "'IBM Plex Mono', monospace", letterSpacing: 1 }}>{d.provider}</span>
              </div>
            </div>
            {/* Pill switch */}
            <div style={{
              width: 40, height: 22, borderRadius: 999,
              background: d.on ? t.ink : t.rule,
              position: "relative", transition: "background 150ms",
            }}>
              <div style={{
                position: "absolute", top: 2, left: d.on ? 20 : 2,
                width: 18, height: 18, borderRadius: "50%",
                background: d.on ? t.accent : "#fff",
                transition: "left 150ms",
              }}/>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

// ─── Thermostat ────────────────────────────────────────────
function T3Thermo({ go }) {
  const [tgt, setTgt] = React.useState(THERM.target);
  const [m, setM] = React.useState(THERM.mode);
  const { current, humidity, outdoor, outdoorHumidity, schedule, range } = THERM;
  const modes = [["heat", "Heat", "heat"], ["cool", "Cool", "cool"], ["auto", "Auto", "auto"], ["off", "Off", "off"]];
  const pct = (tgt - range[0]) / (range[1] - range[0]);

  return (
    <div style={{ background: t.page, color: t.ink, paddingBottom: 110 }}>
      <div style={{ padding: "8px 24px 0", display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <button onClick={() => go("room")} style={{ all: "unset", cursor: "pointer",
          display: "flex", alignItems: "center", gap: 6 }}>
          <GlyBy name="back" size={14} stroke={t.ink} sw={1.4}/>
          <TLabel color={t.ink}>Living Room</TLabel>
        </button>
        <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
          <TDot size={6}/>
          <TLabel>Heating</TLabel>
        </div>
      </div>

      {/* Huge number */}
      <div style={{ padding: "28px 24px 8px" }}>
        <TLabel>Interior</TLabel>
        <div className="tnum" style={{
          fontFamily: "'Inter Tight', sans-serif", fontSize: 168, fontWeight: 300,
          letterSpacing: -8, lineHeight: 0.85, color: t.ink, marginTop: 2,
        }}>
          {current}<span style={{ fontSize: 64, color: t.accent, letterSpacing: 0, fontWeight: 400 }}>°</span>
        </div>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginTop: 8 }}>
          <div>
            <TLabel>Target</TLabel>
            <div className="tnum" style={{ fontFamily: "'Inter Tight', sans-serif", fontSize: 22, fontWeight: 500, marginTop: 2 }}>
              {tgt}°
            </div>
          </div>
          <div style={{ display: "flex", gap: 10 }}>
            <button onClick={() => setTgt(v => v - 1)} style={{ all: "unset", cursor: "pointer",
              width: 52, height: 52, borderRadius: "50%", border: `1px solid ${t.rule}`,
              display: "flex", alignItems: "center", justifyContent: "center", background: t.panel }}>
              <GlyBy name="minus" size={16} stroke={t.ink} sw={1.5}/>
            </button>
            <button onClick={() => setTgt(v => v + 1)} style={{ all: "unset", cursor: "pointer",
              width: 52, height: 52, borderRadius: "50%",
              background: t.accent, display: "flex", alignItems: "center", justifyContent: "center" }}>
              <GlyBy name="plus" size={18} stroke="#fff" sw={1.8}/>
            </button>
          </div>
        </div>
      </div>

      {/* Range scale — precise tick marks */}
      <div style={{ padding: "20px 24px 20px" }}>
        <div style={{ position: "relative", height: 28 }}>
          {Array.from({ length: 31 }).map((_, i) => {
            const f = i / 30;
            const major = i % 5 === 0;
            const on = f <= pct;
            return <div key={i} style={{
              position: "absolute", left: `${f * 100}%`, top: 0,
              width: 1, height: major ? 14 : 7, background: on ? t.ink : t.rule,
              transform: "translateX(-0.5px)",
            }}/>;
          })}
          <div style={{ position: "absolute", left: `${pct * 100}%`, top: 16,
            transform: "translateX(-50%)" }}>
            <TDot size={10}/>
          </div>
        </div>
        <div style={{ display: "flex", justifyContent: "space-between", marginTop: 6 }}>
          <TLabel className="tnum">{range[0]}°</TLabel>
          <TLabel className="tnum">75°</TLabel>
          <TLabel className="tnum">{range[1]}°</TLabel>
        </div>
      </div>

      <TRule/>

      {/* Mode selector — understated segmented */}
      <div style={{ padding: "18px 24px 10px" }}>
        <TLabel>Mode</TLabel>
      </div>
      <div style={{ padding: "0 24px 20px" }}>
        <div style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: 6,
          border: `1px solid ${t.rule}`, borderRadius: 8, padding: 3, background: t.panel }}>
          {modes.map(([k, l, g]) => {
            const a = m === k;
            return (
              <button key={k} onClick={() => setM(k)} style={{
                all: "unset", cursor: "pointer", padding: "10px 4px", textAlign: "center",
                background: a ? t.ink : "transparent", color: a ? t.page : t.ink, borderRadius: 6,
                display: "flex", flexDirection: "column", alignItems: "center", gap: 4,
              }}>
                <GlyBy name={g} size={14} stroke={a ? t.page : t.ink} sw={1.4}/>
                <span style={{ fontSize: 11, fontWeight: 500, letterSpacing: -0.1 }}>{l}</span>
              </button>
            );
          })}
        </div>
      </div>

      <TRule/>

      {/* Conditions grid */}
      <div style={{ padding: "18px 24px", display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: 18 }}>
        {[
          ["Int Hum", `${humidity}%`],
          ["Out Temp", `${outdoor}°`],
          ["Out Hum", `${outdoorHumidity}%`],
        ].map(([l, v]) => (
          <div key={l}>
            <TLabel>{l}</TLabel>
            <div className="tnum" style={{ fontFamily: "'Inter Tight', sans-serif",
              fontSize: 26, fontWeight: 400, letterSpacing: -0.8, marginTop: 4 }}>{v}</div>
          </div>
        ))}
      </div>

      <TRule/>

      {/* Schedule — tidy list */}
      <div style={{ padding: "18px 24px 8px", display: "flex", justifyContent: "space-between", alignItems: "baseline" }}>
        <div style={{ fontFamily: "'Inter Tight', sans-serif", fontSize: 15, fontWeight: 500 }}>Schedule</div>
        <TLabel>Weekday</TLabel>
      </div>
      {schedule.map((s, i) => (
        <div key={s.label} style={{
          display: "grid", gridTemplateColumns: "100px 1fr auto",
          gap: 12, padding: "12px 24px", alignItems: "center",
          borderTop: `1px solid ${t.rule}`,
          borderBottom: i === schedule.length - 1 ? `1px solid ${t.rule}` : "none",
        }}>
          <TLabel color={t.ink}>{s.label}</TLabel>
          <span className="tnum" style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 12, color: t.sub }}>{s.time}</span>
          <span className="tnum" style={{ fontFamily: "'Inter Tight', sans-serif", fontSize: 18, fontWeight: 500 }}>{s.temp}°</span>
        </div>
      ))}
    </div>
  );
}

// ─── Tabs ──────────────────────────────────────────────────
function T3Tabs({ current, go }) {
  const tabs = [
    ["home",    "Home",    "home",     "home"],
    ["rooms",   "Rooms",   "rooms",    "rooms"],
    ["devices", "Devices", "devices",  "devices"],
    ["settings","Settings","settings", "settings"],
  ];
  let cur = current;
  if (current === "room" || current === "thermo" || current === "device") cur = "rooms";
  if (current === "activity" || current === "energy" || current === "addDevice" || current === "scene") cur = "home";
  if (current === "account" || current === "integrations") cur = "settings";
  return (
    <div style={{
      position: "absolute", bottom: 22, left: 20, right: 20, zIndex: 60,
      background: t.panel, border: `1px solid ${t.rule}`, borderRadius: 14,
      display: "grid", gridTemplateColumns: "repeat(4, 1fr)", padding: 4,
      boxShadow: "0 1px 2px rgba(0,0,0,0.03)",
    }}>
      {tabs.map(([k, l, g, target]) => {
        const a = cur === k;
        return (
          <button key={k} onClick={() => go(target)} style={{
            all: "unset", cursor: "pointer", padding: "9px 4px", borderRadius: 10,
            display: "flex", flexDirection: "column", alignItems: "center", gap: 3,
            color: a ? t.ink : t.sub,
            background: "transparent",
          }}>
            <div style={{ position: "relative" }}>
              <GlyBy name={g} size={20} stroke={a ? t.ink : t.sub} sw={a ? 1.7 : 1.4}/>
              {a && <TDot size={5} style={{ position: "absolute", top: -2, right: -4 }}/>}
            </div>
            <span style={{ fontSize: 10, fontWeight: 500, letterSpacing: 0 }}>{l}</span>
          </button>
        );
      })}
    </div>
  );
}

window.T3Theme = { tokens: t, Splash: T3Splash, Home: T3Home, Room: T3Room, Thermo: T3Thermo, Tabs: T3Tabs };
window.T3Primitives = { TLabel, TRule, TDot, tokens: t };
