// ─────────────────────────────────────────────────────────────
// BLOCK — Neo-brutalist.
// Flat high-contrast colors, chunky 2px black borders, offset hard
// shadows (4px, no blur), heavy Archivo Black headings, mono labels.
// Blocky rectangles, zero rounding except for the occasional 2px.
// Accent: electric yellow #f5e23a + tomato #ff5a1f on near-black ink.
// ─────────────────────────────────────────────────────────────

const blockTokens = {
  page:   "#eae4d3",        // warm off-white
  paper:  "#ffffff",
  ink:    "#0a0a0a",
  subtle: "#4a4a4a",
  accent: "#f5e23a",         // electric yellow
  alert:  "#ff5a1f",         // tomato
  cool:   "#2d7dff",
  frame:  "#0a0a0a",
  border: 2,
  shadow: 4,
  dark: false,
};

const bt = blockTokens;

function BCard({ children, bg = bt.paper, style, onClick }) {
  return (
    <div onClick={onClick} style={{
      background: bg, border: `${bt.border}px solid ${bt.ink}`,
      boxShadow: `${bt.shadow}px ${bt.shadow}px 0 0 ${bt.ink}`,
      cursor: onClick ? "pointer" : "default",
      ...style,
    }}>{children}</div>
  );
}
function BLabel({ children, style }) {
  return <div style={{
    fontFamily: "'JetBrains Mono', monospace", fontSize: 10, fontWeight: 700,
    letterSpacing: 1.6, textTransform: "uppercase", color: bt.ink, ...style,
  }}>{children}</div>;
}
function BTag({ children, bg = bt.accent, style }) {
  return <span style={{
    background: bg, border: `1.5px solid ${bt.ink}`, padding: "2px 6px",
    fontFamily: "'JetBrains Mono', monospace", fontSize: 9, fontWeight: 700,
    letterSpacing: 1.2, textTransform: "uppercase", ...style,
  }}>{children}</span>;
}

// ─── Splash ────────────────────────────────────────────────
function BlockSplash() {
  return (
    <div style={{ background: bt.accent, minHeight: "100%", height: "100%",
      position: "relative", overflow: "hidden", color: bt.ink, padding: "24px 24px 44px",
      display: "flex", flexDirection: "column", justifyContent: "space-between" }}>
      {/* Corner marker */}
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start" }}>
        <BTag bg={bt.paper}>V 1.0.0</BTag>
        <BTag bg={bt.ink} style={{ color: bt.accent }}>● LIVE</BTag>
      </div>

      {/* Big wordmark */}
      <div>
        <div style={{
          fontFamily: "'Archivo Black', sans-serif", fontSize: 84, lineHeight: 0.84,
          letterSpacing: -3.5, textTransform: "uppercase", color: bt.ink,
        }}>HOUSE<br/>CONN—<br/>ECT.</div>
        <div style={{ marginTop: 18, borderTop: `2px solid ${bt.ink}`, paddingTop: 8 }}>
          <BLabel>A BLUNT CONTROLLER FOR YOUR ENTIRE HOUSE.</BLabel>
        </div>
      </div>

      {/* Loader */}
      <div>
        <BCard bg={bt.paper} style={{ padding: "10px 12px" }}>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
            <BLabel>BOOT SEQUENCE</BLabel>
            <BLabel style={{ color: bt.alert }}>86%</BLabel>
          </div>
          <div style={{ marginTop: 8, height: 10, border: `1.5px solid ${bt.ink}`, display: "flex" }}>
            {Array.from({ length: 20 }).map((_, i) => (
              <div key={i} style={{ flex: 1, background: i < 17 ? bt.ink : "transparent",
                borderRight: i < 19 ? `1.5px solid ${bt.ink}` : "none" }}/>
            ))}
          </div>
        </BCard>
      </div>
    </div>
  );
}

// ─── Home ──────────────────────────────────────────────────
function BlockHome({ go }) {
  const { counts, weather, scenes, rooms, home } = HOUSE_DATA;
  return (
    <div style={{ background: bt.page, color: bt.ink, padding: "4px 18px 120px" }}>
      {/* Header block */}
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", padding: "6px 0" }}>
        <BLabel>FRI 17 APR · 09:41</BLabel>
        <BLabel>{home}</BLabel>
      </div>

      <div style={{ display: "grid", gridTemplateColumns: "1fr 56px", gap: 10, marginTop: 4 }}>
        <BCard bg={bt.accent} style={{ padding: "14px 16px" }}>
          <BLabel>GOOD MORNING, ALEX</BLabel>
          <div style={{
            fontFamily: "'Archivo Black', sans-serif", fontSize: 44, lineHeight: 0.9,
            marginTop: 4, textTransform: "uppercase", letterSpacing: -1.4,
          }}>17 / LIVE.</div>
          <div style={{ display: "flex", gap: 6, marginTop: 10 }}>
            <BTag bg={bt.paper}>{counts.active} ACTIVE</BTag>
            <BTag bg={bt.alert} style={{ color: bt.paper }}>{counts.offline} OFFLINE</BTag>
            <BTag bg={bt.paper}>{counts.rooms} ROOMS</BTag>
          </div>
        </BCard>
        <BCard bg={bt.paper} style={{ display: "flex", alignItems: "center", justifyContent: "center" }}>
          <Gly.bell size={22} stroke={bt.ink} sw={2}/>
        </BCard>
      </div>

      {/* Weather row */}
      <BCard bg={bt.paper} style={{ padding: "14px 16px", marginTop: 14, display: "flex", gap: 12, alignItems: "center" }}>
        <div style={{ width: 48, height: 48, background: bt.cool, border: `${bt.border}px solid ${bt.ink}`,
          display: "flex", alignItems: "center", justifyContent: "center" }}>
          <Gly.cloud size={26} stroke={bt.paper} sw={2}/>
        </div>
        <div style={{ flex: 1 }}>
          <div style={{ fontFamily: "'Archivo Black', sans-serif", fontSize: 28, lineHeight: 1, letterSpacing: -1 }} className="tnum">
            51°F / OVERCAST
          </div>
          <BLabel style={{ marginTop: 3, color: bt.subtle }}>LIGHT JACKET WEATHER</BLabel>
        </div>
      </BCard>

      {/* Scenes strip */}
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline", marginTop: 20, marginBottom: 8 }}>
        <div style={{ fontFamily: "'Archivo Black', sans-serif", fontSize: 22, letterSpacing: -0.8, textTransform: "uppercase" }}>SCENES</div>
        <BLabel>05 STORED →</BLabel>
      </div>
      <div style={{ display: "flex", gap: 10, overflowX: "auto", paddingBottom: 8 }}>
        {scenes.map((s, i) => (
          <BCard key={s.id} bg={i === 0 ? bt.accent : bt.paper} style={{ padding: 12, minWidth: 112, flexShrink: 0 }}>
            <GlyBy name={s.glyph} size={24} stroke={bt.ink} sw={2}/>
            <div style={{ marginTop: 14, fontFamily: "'Archivo Black', sans-serif", fontSize: 15, lineHeight: 1,
              textTransform: "uppercase", letterSpacing: -0.4 }}>{s.name}</div>
            <BLabel style={{ marginTop: 4, color: bt.subtle }}>{s.desc.toUpperCase()}</BLabel>
          </BCard>
        ))}
      </div>

      {/* Rooms grid */}
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline", marginTop: 20, marginBottom: 8 }}>
        <div style={{ fontFamily: "'Archivo Black', sans-serif", fontSize: 22, letterSpacing: -0.8, textTransform: "uppercase" }}>ROOMS</div>
        <BLabel>{rooms.length} TOTAL</BLabel>
      </div>
      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12 }}>
        {rooms.map((r, i) => {
          const hot = r.active > 0;
          return (
            <BCard key={r.id} onClick={() => go("room")}
              bg={i === 0 ? bt.ink : bt.paper}
              style={{ padding: 14, minHeight: 128 }}>
              <div style={{ display: "flex", justifyContent: "space-between" }}>
                <GlyBy name={r.glyph} size={24} stroke={i === 0 ? bt.accent : bt.ink} sw={2}/>
                <BTag bg={i === 0 ? bt.accent : (hot ? bt.accent : bt.paper)}>
                  {r.active}/{r.total}
                </BTag>
              </div>
              <div style={{ marginTop: 30, fontFamily: "'Archivo Black', sans-serif",
                fontSize: 20, lineHeight: 0.95, letterSpacing: -0.6,
                textTransform: "uppercase",
                color: i === 0 ? bt.paper : bt.ink }}>
                {r.name}
              </div>
              <BLabel style={{ marginTop: 6, color: i === 0 ? "#999" : bt.subtle }}>TAP →</BLabel>
            </BCard>
          );
        })}
      </div>
    </div>
  );
}

// ─── Room ──────────────────────────────────────────────────
function BlockRoom({ go }) {
  const devices = DEVICES.r1;
  return (
    <div style={{ background: bt.page, color: bt.ink, padding: "4px 18px 120px" }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", padding: "6px 0" }}>
        <button onClick={() => go("home")} style={{
          all: "unset", cursor: "pointer", display: "flex", alignItems: "center", gap: 6,
          border: `1.5px solid ${bt.ink}`, padding: "4px 10px", background: bt.paper,
        }}>
          <Gly.back size={12} stroke={bt.ink} sw={2}/>
          <BLabel>BACK</BLabel>
        </button>
        <BTag bg={bt.accent}>03/05 ACTIVE</BTag>
      </div>

      <BCard bg={bt.ink} style={{ padding: 18, marginTop: 10 }}>
        <BLabel style={{ color: bt.accent }}>ROOM 01 · HOMEKIT + SONOS</BLabel>
        <div style={{
          fontFamily: "'Archivo Black', sans-serif", fontSize: 52, lineHeight: 0.85,
          letterSpacing: -2, marginTop: 6, color: bt.paper, textTransform: "uppercase",
        }}>LIVING<br/>ROOM.</div>
      </BCard>

      <div style={{ marginTop: 20, marginBottom: 8, display: "flex", justifyContent: "space-between" }}>
        <div style={{ fontFamily: "'Archivo Black', sans-serif", fontSize: 22, letterSpacing: -0.8, textTransform: "uppercase" }}>DEVICES</div>
        <BLabel>{devices.length} TOTAL</BLabel>
      </div>

      <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
        {devices.map(d => (
          <BCard key={d.id} onClick={() => d.cat === "thermo" && go("thermo")}
            bg={bt.paper} style={{ padding: 14, display: "flex", gap: 12, alignItems: "center" }}>
            <div style={{ width: 44, height: 44, background: d.on ? bt.accent : bt.paper,
              border: `${bt.border}px solid ${bt.ink}`, display: "flex",
              alignItems: "center", justifyContent: "center" }}>
              <GlyBy name={d.glyph} size={22} stroke={bt.ink} sw={2}/>
            </div>
            <div style={{ flex: 1 }}>
              <div style={{ fontFamily: "'Archivo Black', sans-serif", fontSize: 16,
                textTransform: "uppercase", letterSpacing: -0.4 }}>{d.name}</div>
              <div style={{ display: "flex", gap: 6, marginTop: 4 }}>
                <BTag bg={d.on ? bt.accent : bt.paper}>{d.state}</BTag>
                <BTag bg={bt.paper}>{d.provider}</BTag>
              </div>
            </div>
            {/* Hard switch */}
            <div style={{
              width: 52, height: 28, border: `${bt.border}px solid ${bt.ink}`,
              background: d.on ? bt.ink : bt.paper, position: "relative",
              boxShadow: `2px 2px 0 0 ${bt.ink}`,
            }}>
              <div style={{
                position: "absolute", top: 2, left: d.on ? 26 : 2, width: 20, height: 20,
                background: d.on ? bt.accent : bt.ink,
              }} />
            </div>
          </BCard>
        ))}
      </div>

      <BCard bg={bt.accent} style={{ padding: 14, marginTop: 18, display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <BLabel>→ TAP THERMOSTAT FOR DETAIL</BLabel>
        <Gly.arrowR size={18} stroke={bt.ink} sw={2}/>
      </BCard>
    </div>
  );
}

// ─── Thermostat ────────────────────────────────────────────
function BlockThermo({ go }) {
  const [tgt, setTgt] = React.useState(THERM.target);
  const [m, setM] = React.useState(THERM.mode);
  const { current, humidity, outdoor, outdoorHumidity, schedule, range } = THERM;
  const modes = [["heat", "HEAT", "heat"], ["cool", "COOL", "cool"], ["auto", "AUTO", "auto"], ["off", "OFF", "off"]];
  const pct = (tgt - range[0]) / (range[1] - range[0]);

  return (
    <div style={{ background: bt.page, color: bt.ink, padding: "4px 18px 120px" }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", padding: "6px 0" }}>
        <button onClick={() => go("room")} style={{
          all: "unset", cursor: "pointer", display: "flex", alignItems: "center", gap: 6,
          border: `1.5px solid ${bt.ink}`, padding: "4px 10px", background: bt.paper,
        }}>
          <Gly.back size={12} stroke={bt.ink} sw={2}/>
          <BLabel>LIVING ROOM</BLabel>
        </button>
        <BTag bg={bt.alert} style={{ color: bt.paper }}>● HEATING</BTag>
      </div>

      {/* Giant temp card */}
      <BCard bg={bt.accent} style={{ marginTop: 10, padding: 18, position: "relative" }}>
        <div style={{ display: "flex", justifyContent: "space-between" }}>
          <BLabel>INTERIOR</BLabel>
          <BLabel>NEST · LIVE</BLabel>
        </div>
        <div className="tnum" style={{
          fontFamily: "'Archivo Black', sans-serif", fontSize: 160, lineHeight: 0.82,
          letterSpacing: -7, marginTop: -6, textTransform: "uppercase",
        }}>
          {current}°
        </div>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginTop: 2 }}>
          <div>
            <BLabel>TARGET</BLabel>
            <div className="tnum" style={{ fontFamily: "'Archivo Black', sans-serif", fontSize: 32, lineHeight: 1 }}>
              {tgt}°
            </div>
          </div>
          <div style={{ display: "flex", gap: 8 }}>
            <button onClick={() => setTgt(t => t - 1)} style={{
              all: "unset", cursor: "pointer", width: 48, height: 48,
              background: bt.paper, border: `${bt.border}px solid ${bt.ink}`,
              boxShadow: `3px 3px 0 0 ${bt.ink}`,
              display: "flex", alignItems: "center", justifyContent: "center",
            }}><Gly.minus size={20} stroke={bt.ink} sw={2.5}/></button>
            <button onClick={() => setTgt(t => t + 1)} style={{
              all: "unset", cursor: "pointer", width: 48, height: 48,
              background: bt.ink, border: `${bt.border}px solid ${bt.ink}`,
              boxShadow: `3px 3px 0 0 ${bt.alert}`,
              display: "flex", alignItems: "center", justifyContent: "center",
            }}><Gly.plus size={20} stroke={bt.accent} sw={2.5}/></button>
          </div>
        </div>

        {/* Hard bar */}
        <div style={{ marginTop: 16, border: `${bt.border}px solid ${bt.ink}`, background: bt.paper,
          position: "relative", height: 22, display: "flex" }}>
          {Array.from({ length: 30 }).map((_, i) => {
            const on = i / 29 <= pct;
            return <div key={i} style={{ flex: 1, background: on ? bt.ink : "transparent",
              borderRight: i < 29 ? `1.5px solid ${bt.ink}` : "none" }}/>;
          })}
        </div>
        <div style={{ display: "flex", justifyContent: "space-between", marginTop: 4 }}>
          <BLabel>{range[0]}°</BLabel>
          <BLabel>{range[1]}°</BLabel>
        </div>
      </BCard>

      {/* Mode grid */}
      <div style={{ marginTop: 18, marginBottom: 8 }}>
        <div style={{ fontFamily: "'Archivo Black', sans-serif", fontSize: 18,
          textTransform: "uppercase", letterSpacing: -0.6 }}>MODE</div>
      </div>
      <div style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: 8 }}>
        {modes.map(([k, l, g]) => {
          const a = m === k;
          return (
            <BCard key={k} onClick={() => setM(k)}
              bg={a ? bt.ink : bt.paper}
              style={{ padding: "12px 4px", textAlign: "center" }}>
              <GlyBy name={g} size={22} stroke={a ? bt.accent : bt.ink} sw={2}
                style={{ margin: "0 auto" }}/>
              <div style={{
                marginTop: 6, fontFamily: "'Archivo Black', sans-serif", fontSize: 12,
                letterSpacing: 1, color: a ? bt.accent : bt.ink,
              }}>{l}</div>
            </BCard>
          );
        })}
      </div>

      {/* Stats row */}
      <div style={{ marginTop: 18, marginBottom: 8, fontFamily: "'Archivo Black', sans-serif", fontSize: 18,
        textTransform: "uppercase", letterSpacing: -0.6 }}>CONDITIONS</div>
      <div style={{ display: "grid", gridTemplateColumns: "repeat(3, 1fr)", gap: 8 }}>
        {[
          ["INT HUM", `${humidity}%`, "drop"],
          ["OUT",      `${outdoor}°`, "cloud"],
          ["OUT HUM",  `${outdoorHumidity}%`, "drop"],
        ].map(([l, v, g]) => (
          <BCard key={l} bg={bt.paper} style={{ padding: 10 }}>
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start" }}>
              <BLabel>{l}</BLabel>
              <GlyBy name={g} size={14} stroke={bt.ink} sw={2}/>
            </div>
            <div className="tnum" style={{ fontFamily: "'Archivo Black', sans-serif", fontSize: 26,
              lineHeight: 1, marginTop: 6 }}>{v}</div>
          </BCard>
        ))}
      </div>

      {/* Schedule */}
      <div style={{ marginTop: 18, marginBottom: 8, display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <div style={{ fontFamily: "'Archivo Black', sans-serif", fontSize: 18,
          textTransform: "uppercase", letterSpacing: -0.6 }}>SCHEDULE</div>
        <BTag bg={bt.paper}>WEEKDAY</BTag>
      </div>
      <BCard bg={bt.paper} style={{ padding: 0 }}>
        {schedule.map((s, i) => (
          <div key={s.label} style={{
            display: "grid", gridTemplateColumns: "90px 1fr auto", gap: 10, alignItems: "center",
            padding: "12px 14px",
            borderBottom: i < schedule.length - 1 ? `1.5px solid ${bt.ink}` : "none",
          }}>
            <BLabel>{s.label}</BLabel>
            <div className="tnum" style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 13, color: bt.subtle }}>{s.time}</div>
            <div className="tnum" style={{ fontFamily: "'Archivo Black', sans-serif", fontSize: 20 }}>{s.temp}°</div>
          </div>
        ))}
      </BCard>
    </div>
  );
}

// ─── Tab bar ───────────────────────────────────────────────
function BlockTabs({ current, go }) {
  const tabs = [
    ["home",   "HOME",    "home",    "home"],
    ["rooms",  "ROOMS",   "rooms",   "room"],
    ["dev",    "DEVICES", "devices", "home"],
    ["set",    "SET",     "settings","home"],
  ];
  const cur = current === "room" || current === "thermo" ? "rooms" : "home";
  return (
    <div style={{
      position: "absolute", bottom: 24, left: 14, right: 14, zIndex: 60,
      display: "grid", gridTemplateColumns: "repeat(4, 1fr)",
      background: bt.paper, border: `${bt.border}px solid ${bt.ink}`,
      boxShadow: `${bt.shadow}px ${bt.shadow}px 0 0 ${bt.ink}`,
    }}>
      {tabs.map(([k, l, g, target], i) => {
        const a = cur === k;
        return (
          <button key={k} onClick={() => go(target)} style={{
            all: "unset", cursor: "pointer", padding: "10px 4px",
            borderLeft: i === 0 ? "none" : `1.5px solid ${bt.ink}`,
            display: "flex", flexDirection: "column", alignItems: "center", gap: 4,
            background: a ? bt.accent : "transparent", color: bt.ink,
          }}>
            <GlyBy name={g} size={18} stroke={bt.ink} sw={a ? 2.2 : 1.8}/>
            <span style={{ fontFamily: "'Archivo Black', sans-serif", fontSize: 10, letterSpacing: 0.5 }}>{l}</span>
          </button>
        );
      })}
    </div>
  );
}

window.BlockTheme = { tokens: bt, Splash: BlockSplash, Home: BlockHome, Room: BlockRoom, Thermo: BlockThermo, Tabs: BlockTabs };
