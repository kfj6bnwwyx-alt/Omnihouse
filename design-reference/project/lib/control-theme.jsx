// ─────────────────────────────────────────────────────────────
// CONTROL — Braun ET66 calc / Vitsoe 606 shelving.
// Warm paper-grey + bone-white, softer functional modernism.
// Round dial for temperature, yellow-green accent for the primary
// action (ET66 "C" button), muted sage for secondary. Rounded rects
// (4-6px) allowed. Mono captions stay small + precise.
// ─────────────────────────────────────────────────────────────

const cTokens = {
  page:   "#e6e3dc",   // paper grey
  panel:  "#f6f4ee",   // bone
  ink:    "#1c1c1a",
  sub:    "#74716a",
  rule:   "#cbc7be",
  accent: "#c6d94c",   // ET66 yellow-green
  warn:   "#d96a2c",   // warm orange — thermo heat
  cool:   "#7aa3c9",
  frame:  "#2b2b29",
  dark:   false,
};
const c = cTokens;

function CCap({ children, style, color }) {
  return <div style={{
    fontFamily: "'IBM Plex Mono', monospace", fontSize: 10, fontWeight: 400,
    color: color || c.sub, letterSpacing: 1.2, textTransform: "uppercase", ...style,
  }}>{children}</div>;
}
function CRail({ children, style, onClick }) {
  return <div onClick={onClick} style={{
    background: c.panel, border: `1px solid ${c.rule}`, borderRadius: 6,
    cursor: onClick ? "pointer" : "default", ...style,
  }}>{children}</div>;
}

// ─── Splash ────────────────────────────────────────────────
function CSplash() {
  return (
    <div style={{ background: c.page, height: "100%", padding: "22px 24px 40px",
      color: c.ink, display: "flex", flexDirection: "column", justifyContent: "space-between" }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <CCap>House Connect</CCap>
        <CCap>1.0.0</CCap>
      </div>

      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 22 }}>
        {/* Concentric dial motif */}
        <div style={{ width: 180, height: 180, borderRadius: "50%",
          background: c.panel, border: `1px solid ${c.rule}`,
          display: "flex", alignItems: "center", justifyContent: "center", position: "relative" }}>
          <div style={{ width: 120, height: 120, borderRadius: "50%", background: c.accent,
            display: "flex", alignItems: "center", justifyContent: "center" }}>
            <div style={{ width: 48, height: 48, borderRadius: "50%", background: c.ink }}/>
          </div>
          {/* tick marks */}
          {Array.from({ length: 24 }).map((_, i) => {
            const a = (i / 24) * Math.PI * 2;
            const r = 86;
            return <div key={i} style={{
              position: "absolute", left: `calc(50% + ${Math.cos(a) * r}px)`,
              top: `calc(50% + ${Math.sin(a) * r}px)`,
              width: 2, height: i % 6 === 0 ? 8 : 4, background: c.sub,
              transform: `translate(-1px, -2px) rotate(${a + Math.PI / 2}rad)`,
              transformOrigin: "center",
            }}/>;
          })}
        </div>
        <div style={{ textAlign: "center" }}>
          <div style={{ fontFamily: "'Inter Tight', sans-serif", fontSize: 30, fontWeight: 500,
            letterSpacing: -0.8, lineHeight: 1 }}>
            House Connect
          </div>
          <div style={{ marginTop: 8, fontSize: 13, color: c.sub, maxWidth: 260, lineHeight: 1.5 }}>
            Controls for the house, shaped like the things they control.
          </div>
        </div>
      </div>

      <div>
        <div style={{ height: 1, background: c.rule, marginBottom: 10 }}/>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
          <CCap>Connecting</CCap>
          <div style={{ display: "flex", gap: 5, alignItems: "center" }}>
            {Array.from({ length: 3 }).map((_, i) => (
              <div key={i} style={{ width: 6, height: 6, borderRadius: "50%",
                background: i < 2 ? c.accent : c.rule }}/>
            ))}
          </div>
          <CCap>Homekit · Nest · Sonos</CCap>
        </div>
      </div>
    </div>
  );
}

// ─── Home ──────────────────────────────────────────────────
function CHome({ go }) {
  const { counts, scenes, rooms, home } = HOUSE_DATA;
  return (
    <div style={{ background: c.page, color: c.ink, paddingBottom: 110 }}>
      <div style={{ padding: "8px 18px 0", display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <CCap>{home}</CCap>
        <CCap>Fri 09:41</CCap>
      </div>

      {/* Greeting */}
      <div style={{ padding: "18px 18px 14px" }}>
        <div style={{ fontFamily: "'Inter Tight', sans-serif", fontSize: 30, fontWeight: 500,
          letterSpacing: -0.8, lineHeight: 1.05 }}>
          Good morning, Alex.
        </div>
        <div style={{ marginTop: 4, fontSize: 13, color: c.sub }}>
          Nine devices running quietly in the background.
        </div>
      </div>

      {/* Primary tile: climate with dial — hero element */}
      <div style={{ padding: "0 16px" }}>
        <CRail style={{ padding: 18, background: c.panel, display: "grid",
          gridTemplateColumns: "1fr auto", gap: 12, alignItems: "center" }}>
          <div>
            <CCap>Living Room · Climate</CCap>
            <div className="tnum" style={{ fontFamily: "'Inter Tight', sans-serif",
              fontSize: 54, fontWeight: 400, letterSpacing: -2, lineHeight: 0.9, marginTop: 6 }}>
              68<span style={{ fontSize: 26, color: c.warn }}>°</span>
            </div>
            <div style={{ fontSize: 12, color: c.sub, marginTop: 4 }}>Target 71° · Heating</div>
          </div>
          {/* Mini dial */}
          <div onClick={() => go("thermo")} style={{
            width: 82, height: 82, borderRadius: "50%", background: c.page,
            border: `1px solid ${c.rule}`, position: "relative", cursor: "pointer",
            display: "flex", alignItems: "center", justifyContent: "center",
          }}>
            <div style={{ width: 56, height: 56, borderRadius: "50%", background: c.warn,
              display: "flex", alignItems: "center", justifyContent: "center" }}>
              <div className="tnum" style={{ fontFamily: "'Inter Tight', sans-serif",
                fontSize: 18, fontWeight: 600, color: "#fff" }}>71°</div>
            </div>
            {/* notch indicator */}
            <div style={{ position: "absolute", top: 4, left: "50%", width: 2, height: 8,
              background: c.warn, transform: "translateX(-1px)" }}/>
          </div>
        </CRail>
      </div>

      {/* Stat strip */}
      <div style={{ padding: "14px 16px 0", display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: 8 }}>
        {[
          ["Outside", "51°",  "Overcast", c.cool],
          ["Energy",  "1.4k", "Watts now", c.accent],
          ["Status",  `${counts.active}/${counts.devices}`, "On", c.ink],
        ].map(([l, v, s, col]) => (
          <CRail key={l} style={{ padding: "12px 10px" }}>
            <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
              <div style={{ width: 6, height: 6, borderRadius: "50%", background: col }}/>
              <CCap>{l}</CCap>
            </div>
            <div className="tnum" style={{ fontFamily: "'Inter Tight', sans-serif",
              fontSize: 22, fontWeight: 500, letterSpacing: -0.6, marginTop: 4 }}>{v}</div>
            <div style={{ fontSize: 10, color: c.sub, marginTop: 2 }}>{s}</div>
          </CRail>
        ))}
      </div>

      {/* Scenes — button-panel feel */}
      <div style={{ padding: "20px 18px 6px", display: "flex", justifyContent: "space-between", alignItems: "baseline" }}>
        <div style={{ fontFamily: "'Inter Tight', sans-serif", fontSize: 18, fontWeight: 500, letterSpacing: -0.4 }}>Scenes</div>
        <CCap>05</CCap>
      </div>
      <div style={{ padding: "0 16px", display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: 6 }}>
        {scenes.slice(0, 4).map((s, i) => (
          <button key={s.id} style={{
            all: "unset", cursor: "pointer", aspectRatio: "1 / 1",
            background: i === 0 ? c.accent : c.panel,
            border: `1px solid ${c.rule}`, borderRadius: 6,
            display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center",
            gap: 6, color: c.ink,
          }}>
            <GlyBy name={s.glyph} size={22} stroke={c.ink} sw={1.4}/>
            <span style={{ fontSize: 10, fontWeight: 600, letterSpacing: 0 }}>{s.name}</span>
          </button>
        ))}
      </div>

      {/* Rooms — two-col grid */}
      <div style={{ padding: "20px 18px 6px", display: "flex", justifyContent: "space-between", alignItems: "baseline" }}>
        <div style={{ fontFamily: "'Inter Tight', sans-serif", fontSize: 18, fontWeight: 500, letterSpacing: -0.4 }}>Rooms</div>
        <CCap>{rooms.length}</CCap>
      </div>
      <div style={{ padding: "0 16px", display: "grid", gridTemplateColumns: "1fr 1fr", gap: 8 }}>
        {rooms.map(r => (
          <CRail key={r.id} onClick={() => go("room")} style={{ padding: 14, minHeight: 108 }}>
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start" }}>
              <GlyBy name={r.glyph} size={20} stroke={c.ink} sw={1.4}/>
              <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
                {r.active > 0 && <div style={{ width: 6, height: 6, borderRadius: "50%", background: c.accent }}/>}
                <span className="tnum" style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 10, color: c.sub }}>
                  {r.active}/{r.total}
                </span>
              </div>
            </div>
            <div style={{ marginTop: 24 }}>
              <div style={{ fontFamily: "'Inter Tight', sans-serif", fontSize: 16, fontWeight: 500, letterSpacing: -0.2 }}>
                {r.name}
              </div>
            </div>
          </CRail>
        ))}
      </div>
    </div>
  );
}

// ─── Room ──────────────────────────────────────────────────
function CRoom({ go }) {
  const devices = DEVICES.r1;
  return (
    <div style={{ background: c.page, color: c.ink, paddingBottom: 110 }}>
      <div style={{ padding: "8px 18px 0", display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <button onClick={() => go("home")} style={{ all: "unset", cursor: "pointer",
          display: "flex", alignItems: "center", gap: 6 }}>
          <GlyBy name="back" size={14} stroke={c.ink} sw={1.4}/>
          <CCap color={c.ink}>Home</CCap>
        </button>
        <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
          <div style={{ width: 6, height: 6, borderRadius: "50%", background: c.accent }}/>
          <CCap>3 active</CCap>
        </div>
      </div>

      <div style={{ padding: "20px 18px 16px" }}>
        <CCap>Room 01</CCap>
        <div style={{ fontFamily: "'Inter Tight', sans-serif", fontSize: 36, fontWeight: 500,
          letterSpacing: -1.1, lineHeight: 1, marginTop: 6 }}>
          Living Room
        </div>
        <div style={{ marginTop: 6, fontSize: 12, color: c.sub }}>HomeKit · Sonos · 5 devices</div>
      </div>

      <div style={{ padding: "0 16px", display: "flex", flexDirection: "column", gap: 8 }}>
        {devices.map(d => (
          <CRail key={d.id} onClick={() => d.cat === "thermo" && go("thermo")}
            style={{ padding: 14, display: "grid", gridTemplateColumns: "44px 1fr auto",
              gap: 12, alignItems: "center" }}>
            <div style={{ width: 44, height: 44, borderRadius: 8, background: c.page,
              border: `1px solid ${c.rule}`, display: "flex", alignItems: "center", justifyContent: "center" }}>
              <GlyBy name={d.glyph} size={20} stroke={c.ink} sw={1.4}/>
            </div>
            <div>
              <div style={{ fontFamily: "'Inter Tight', sans-serif", fontSize: 15, fontWeight: 500, letterSpacing: -0.2 }}>{d.name}</div>
              <div style={{ fontSize: 11, color: c.sub, marginTop: 2, display: "flex", alignItems: "center", gap: 8 }}>
                <span>{d.state}</span>
                <span>·</span>
                <span style={{ fontFamily: "'IBM Plex Mono', monospace", letterSpacing: 0.8 }}>{d.provider}</span>
              </div>
            </div>
            {/* Round toggle — ET66 button style */}
            <div style={{
              width: 46, height: 26, borderRadius: 999,
              background: d.on ? c.accent : c.rule,
              position: "relative", border: `1px solid ${c.rule}`,
            }}>
              <div style={{
                position: "absolute", top: 2, left: d.on ? 22 : 2,
                width: 20, height: 20, borderRadius: "50%",
                background: c.ink,
              }}/>
            </div>
          </CRail>
        ))}
      </div>
    </div>
  );
}

// ─── Thermostat ────────────────────────────────────────────
function CThermo({ go }) {
  const [tgt, setTgt] = React.useState(THERM.target);
  const [m, setM] = React.useState(THERM.mode);
  const { current, humidity, outdoor, outdoorHumidity, schedule, range } = THERM;
  const modes = [["heat", "Heat", "heat"], ["cool", "Cool", "cool"], ["auto", "Auto", "auto"], ["off", "Off", "off"]];
  const pct = (tgt - range[0]) / (range[1] - range[0]);
  // dial math
  const START = -135, END = 135;                // degrees
  const angle = START + pct * (END - START);

  return (
    <div style={{ background: c.page, color: c.ink, paddingBottom: 110 }}>
      <div style={{ padding: "8px 18px 0", display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <button onClick={() => go("room")} style={{ all: "unset", cursor: "pointer",
          display: "flex", alignItems: "center", gap: 6 }}>
          <GlyBy name="back" size={14} stroke={c.ink} sw={1.4}/>
          <CCap color={c.ink}>Living Room</CCap>
        </button>
        <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
          <div style={{ width: 6, height: 6, borderRadius: "50%", background: c.warn }}/>
          <CCap>Heating</CCap>
        </div>
      </div>

      <div style={{ padding: "14px 18px 4px" }}>
        <CCap>Living Room · Thermostat</CCap>
      </div>

      {/* The dial — primary control */}
      <div style={{ padding: "8px 18px 0", display: "flex", justifyContent: "center" }}>
        <div style={{ position: "relative", width: 300, height: 300 }}>
          {/* outer rim */}
          <div style={{ position: "absolute", inset: 0, borderRadius: "50%",
            background: c.panel, border: `1px solid ${c.rule}` }}/>
          {/* tick marks */}
          {Array.from({ length: 41 }).map((_, i) => {
            const f = i / 40;
            const a = (START + f * (END - START)) * Math.PI / 180;
            const r = 136;
            const x = 150 + Math.sin(a) * r;
            const y = 150 - Math.cos(a) * r;
            const major = i % 5 === 0;
            const on = f <= pct;
            return <div key={i} style={{
              position: "absolute", left: x, top: y,
              width: 2, height: major ? 12 : 6,
              background: on ? c.warn : c.rule,
              transform: `translate(-1px, -${major ? 12 : 6}px) rotate(${a}rad)`,
              transformOrigin: "1px 100%",
            }}/>;
          })}
          {/* inner plate */}
          <div style={{
            position: "absolute", inset: 30, borderRadius: "50%",
            background: c.page, border: `1px solid ${c.rule}`,
            display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center",
          }}>
            <CCap>Interior</CCap>
            <div className="tnum" style={{
              fontFamily: "'Inter Tight', sans-serif", fontSize: 88, fontWeight: 400,
              letterSpacing: -4, lineHeight: 0.9, marginTop: 2,
            }}>
              {current}<span style={{ fontSize: 32, color: c.warn, letterSpacing: 0 }}>°</span>
            </div>
            <CCap style={{ marginTop: 4 }}>Target · {tgt}°</CCap>
          </div>
          {/* needle */}
          <div style={{
            position: "absolute", left: "50%", top: "50%",
            width: 2, height: 118, background: c.warn,
            transformOrigin: "center bottom",
            transform: `translate(-1px, -118px) rotate(${angle}deg)`,
            borderRadius: 1,
          }}/>
          {/* hub */}
          <div style={{
            position: "absolute", left: "50%", top: "50%",
            width: 14, height: 14, borderRadius: "50%", background: c.ink,
            transform: "translate(-50%, -50%)",
          }}/>
        </div>
      </div>

      {/* +/- row — big ET66-style buttons */}
      <div style={{ padding: "14px 18px 20px", display: "flex", justifyContent: "center", gap: 14 }}>
        <button onClick={() => setTgt(v => v - 1)} style={{
          all: "unset", cursor: "pointer", width: 64, height: 64, borderRadius: "50%",
          background: c.panel, border: `1px solid ${c.rule}`,
          display: "flex", alignItems: "center", justifyContent: "center",
        }}><GlyBy name="minus" size={20} stroke={c.ink} sw={1.6}/></button>
        <button onClick={() => setTgt(v => v + 1)} style={{
          all: "unset", cursor: "pointer", width: 76, height: 76, borderRadius: "50%",
          background: c.accent, border: `1px solid ${c.rule}`,
          display: "flex", alignItems: "center", justifyContent: "center",
        }}><GlyBy name="plus" size={26} stroke={c.ink} sw={1.8}/></button>
        <button style={{
          all: "unset", cursor: "pointer", width: 64, height: 64, borderRadius: "50%",
          background: c.panel, border: `1px solid ${c.rule}`,
          display: "flex", alignItems: "center", justifyContent: "center",
        }}><GlyBy name="target" size={20} stroke={c.ink} sw={1.4}/></button>
      </div>

      {/* Mode — horizontal rail */}
      <div style={{ padding: "0 18px 6px" }}>
        <CCap>Mode</CCap>
      </div>
      <div style={{ padding: "0 16px 16px", display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: 6 }}>
        {modes.map(([k, l, gl]) => {
          const a = m === k;
          return (
            <button key={k} onClick={() => setM(k)} style={{
              all: "unset", cursor: "pointer", padding: "12px 4px", borderRadius: 6,
              background: a ? c.ink : c.panel, color: a ? c.page : c.ink,
              border: `1px solid ${c.rule}`,
              display: "flex", flexDirection: "column", alignItems: "center", gap: 6,
            }}>
              <GlyBy name={gl} size={18} stroke={a ? c.page : c.ink} sw={1.4}/>
              <span style={{ fontSize: 11, fontWeight: 600, letterSpacing: -0.1 }}>{l}</span>
            </button>
          );
        })}
      </div>

      {/* Conditions tiles */}
      <div style={{ padding: "0 16px 16px", display: "grid", gridTemplateColumns: "repeat(3, 1fr)", gap: 6 }}>
        {[
          ["Int Hum", `${humidity}%`, "drop", c.cool],
          ["Out Temp", `${outdoor}°`, "cloud", c.cool],
          ["Out Hum", `${outdoorHumidity}%`, "drop", c.cool],
        ].map(([l, v, gl, col]) => (
          <CRail key={l} style={{ padding: 12 }}>
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
              <CCap>{l}</CCap>
              <GlyBy name={gl} size={14} stroke={col} sw={1.4}/>
            </div>
            <div className="tnum" style={{ fontFamily: "'Inter Tight', sans-serif",
              fontSize: 24, fontWeight: 500, letterSpacing: -0.6, marginTop: 4 }}>{v}</div>
          </CRail>
        ))}
      </div>

      {/* Schedule */}
      <div style={{ padding: "8px 18px 6px", display: "flex", justifyContent: "space-between", alignItems: "baseline" }}>
        <div style={{ fontFamily: "'Inter Tight', sans-serif", fontSize: 16, fontWeight: 500, letterSpacing: -0.3 }}>Schedule</div>
        <CCap>Weekday</CCap>
      </div>
      <div style={{ padding: "0 16px 10px" }}>
        <CRail style={{ padding: 0 }}>
          {schedule.map((s, i) => (
            <div key={s.label} style={{
              display: "grid", gridTemplateColumns: "80px 1fr auto",
              gap: 10, alignItems: "center", padding: "12px 14px",
              borderBottom: i < schedule.length - 1 ? `1px solid ${c.rule}` : "none",
            }}>
              <CCap color={c.ink}>{s.label}</CCap>
              <span className="tnum" style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 11, color: c.sub }}>{s.time}</span>
              <span className="tnum" style={{ fontFamily: "'Inter Tight', sans-serif", fontSize: 18, fontWeight: 500 }}>{s.temp}°</span>
            </div>
          ))}
        </CRail>
      </div>
    </div>
  );
}

// ─── Tabs ──────────────────────────────────────────────────
function CTabs({ current, go }) {
  const tabs = [
    ["home",  "Home",    "home",    "home"],
    ["rooms", "Rooms",   "rooms",   "room"],
    ["dev",   "Devices", "devices", "home"],
    ["set",   "Settings","settings","home"],
  ];
  const cur = current === "room" || current === "thermo" ? "rooms" : "home";
  return (
    <div style={{
      position: "absolute", bottom: 20, left: 16, right: 16, zIndex: 60,
      background: c.panel, border: `1px solid ${c.rule}`, borderRadius: 999,
      display: "grid", gridTemplateColumns: "repeat(4, 1fr)", padding: 4,
    }}>
      {tabs.map(([k, l, gl, target]) => {
        const a = cur === k;
        return (
          <button key={k} onClick={() => go(target)} style={{
            all: "unset", cursor: "pointer", padding: "8px 4px", borderRadius: 999,
            display: "flex", flexDirection: "column", alignItems: "center", gap: 3,
            color: a ? c.ink : c.sub,
            background: a ? c.accent : "transparent",
          }}>
            <GlyBy name={gl} size={18} stroke={a ? c.ink : c.sub} sw={a ? 1.7 : 1.4}/>
            <span style={{ fontSize: 10, fontWeight: 600, letterSpacing: 0 }}>{l}</span>
          </button>
        );
      })}
    </div>
  );
}

window.ControlTheme = { tokens: c, Splash: CSplash, Home: CHome, Room: CRoom, Thermo: CThermo, Tabs: CTabs };
