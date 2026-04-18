// ─────────────────────────────────────────────────────────────
// GRID — Terminal / industrial.
// Near-black background, phosphor-green accents, JetBrains Mono
// everywhere, status-line / ascii-table copy. Orange alert channel.
// Dotted grid overlay, numeric coordinate labels in margins.
// ─────────────────────────────────────────────────────────────

const gridTokens = {
  page:   "#0d0f0c",
  panel:  "#15180f",
  ink:    "#d7ddc7",          // off-white
  dim:    "#7a8070",
  rule:   "#2a2e22",
  green:  "#b8ff5c",          // phosphor
  amber:  "#ffb347",
  red:    "#ff5c5c",
  frame:  "#000",
  dark: true,
};
const gt = gridTokens;

function TLine({ color = gt.rule, heavy = false, style }) {
  return <div style={{ height: heavy ? 2 : 1, background: color, width: "100%", ...style }}/>;
}
function TLabel({ children, style, color = gt.dim }) {
  return <div style={{
    fontFamily: "'JetBrains Mono', monospace", fontSize: 10, fontWeight: 500,
    color, letterSpacing: 1, textTransform: "uppercase", ...style,
  }}>{children}</div>;
}
function TDots() {
  return <div style={{
    position: "absolute", inset: 0, pointerEvents: "none", opacity: 0.5,
    backgroundImage: `radial-gradient(${gt.rule} 0.8px, transparent 0.8px)`,
    backgroundSize: "12px 12px", backgroundPosition: "6px 6px",
  }}/>;
}

// ─── Splash ────────────────────────────────────────────────
function GridSplash() {
  const lines = [
    "[boot] initializing registry.................ok",
    "[boot] mounting homekit......................ok",
    "[boot] mounting smartthings..................ok",
    "[boot] mounting sonos........................ok",
    "[boot] mounting nest.........................ok",
    "[boot] resolving 17 accessories..............ok",
    "[boot] cross-provider room merge.............ok",
    "[boot] weather @ open-meteo..................ok",
    "[ready] operator panel online",
  ];
  return (
    <div style={{ background: gt.page, color: gt.ink, height: "100%", padding: "20px 22px 60px",
      position: "relative", overflow: "hidden",
      fontFamily: "'JetBrains Mono', monospace" }}>
      <TDots/>
      <div style={{ position: "relative", display: "flex", justifyContent: "space-between" }}>
        <TLabel color={gt.green}>HC/OS · V1.0.0</TLabel>
        <TLabel>◼ 09:41:06</TLabel>
      </div>
      <TLine style={{ margin: "10px 0 22px" }} color={gt.rule}/>

      <div style={{ position: "relative",
        fontFamily: "'JetBrains Mono', monospace", fontSize: 44, fontWeight: 700,
        color: gt.ink, lineHeight: 0.95, letterSpacing: -1 }}>
        HOUSE_<br/>CONNECT<span style={{ color: gt.green }}>.</span>
      </div>
      <div style={{ marginTop: 14, position: "relative", fontSize: 11, color: gt.dim, lineHeight: 1.8 }}>
        {lines.map((l, i) => (
          <div key={i} style={{ color: l.includes("[ready]") ? gt.green : gt.dim }}>
            <span style={{ color: gt.amber }}>{String(i).padStart(2, "0")}</span>  {l}
          </div>
        ))}
      </div>

      <div style={{ position: "absolute", bottom: 40, left: 22, right: 22 }}>
        <TLine/>
        <div style={{ display: "flex", justifyContent: "space-between", padding: "8px 0", fontSize: 10, color: gt.dim, textTransform: "uppercase", letterSpacing: 1 }}>
          <span style={{ color: gt.green }}>● CONNECTED</span>
          <span>NODES 17/17</span>
          <span>UPTIME 00:00:01</span>
        </div>
      </div>
    </div>
  );
}

// ─── Home ──────────────────────────────────────────────────
function GridHome({ go }) {
  const { counts, scenes, rooms, home } = HOUSE_DATA;
  return (
    <div style={{ background: gt.page, color: gt.ink, padding: "4px 16px 130px",
      fontFamily: "'JetBrains Mono', monospace", position: "relative", minHeight: "100%" }}>
      <TDots/>

      {/* Top status line */}
      <div style={{ position: "relative", display: "flex", justifyContent: "space-between", padding: "4px 0 8px" }}>
        <TLabel color={gt.green}>● {home}</TLabel>
        <TLabel>09:41:06 PDT</TLabel>
      </div>
      <TLine/>

      {/* Greeting block */}
      <div style={{ position: "relative", padding: "14px 0 12px" }}>
        <TLabel>/home/alex $</TLabel>
        <div style={{ fontSize: 28, fontWeight: 700, color: gt.ink, lineHeight: 1.05, marginTop: 4, letterSpacing: -0.8 }}>
          GOOD MORNING<span style={{ color: gt.green }}>_</span>
        </div>
        <div style={{ fontSize: 11, color: gt.dim, marginTop: 6, lineHeight: 1.6 }}>
          17 NODES · 6 ROOMS · <span style={{ color: gt.amber }}>1 OFFLINE</span> · <span style={{ color: gt.green }}>9 ACTIVE</span>
        </div>
      </div>
      <TLine/>

      {/* Counters table */}
      <div style={{ position: "relative", display: "grid", gridTemplateColumns: "repeat(4, 1fr)",
        borderBottom: `1px solid ${gt.rule}` }}>
        {[
          ["NODES",    counts.devices, gt.ink],
          ["ACTIVE",   counts.active,  gt.green],
          ["ROOMS",    counts.rooms,   gt.ink],
          ["OFFLINE",  counts.offline, gt.amber],
        ].map(([l, n, c], i) => (
          <div key={l} style={{ padding: "10px 8px",
            borderLeft: i === 0 ? "none" : `1px solid ${gt.rule}` }}>
            <TLabel>{l}</TLabel>
            <div className="tnum" style={{ fontSize: 26, fontWeight: 700, color: c, lineHeight: 1, marginTop: 3 }}>
              {String(n).padStart(2, "0")}
            </div>
          </div>
        ))}
      </div>

      {/* Weather block */}
      <div style={{ position: "relative", padding: "12px 0", display: "flex", gap: 10, alignItems: "center" }}>
        <div style={{ width: 40, height: 40, border: `1px solid ${gt.rule}`,
          display: "flex", alignItems: "center", justifyContent: "center" }}>
          <Gly.cloud size={22} stroke={gt.amber} sw={1.5}/>
        </div>
        <div style={{ flex: 1 }}>
          <div className="tnum" style={{ fontSize: 15, fontWeight: 600, color: gt.ink }}>
            wx: 51°F · overcast
          </div>
          <TLabel style={{ marginTop: 2 }}>// LIGHT JACKET ADVISED</TLabel>
        </div>
        <div style={{ fontSize: 10, color: gt.green, letterSpacing: 1 }}>↻ 00:14</div>
      </div>
      <TLine/>

      {/* Scenes — ascii table header */}
      <div style={{ position: "relative", padding: "14px 0 4px", display: "flex", justifyContent: "space-between" }}>
        <div style={{ color: gt.green, fontSize: 13, letterSpacing: 1, fontWeight: 700 }}>└─ SCENES.TBL</div>
        <TLabel>05 ROWS</TLabel>
      </div>
      <div style={{ position: "relative", borderTop: `1px solid ${gt.rule}`, borderBottom: `1px solid ${gt.rule}` }}>
        {scenes.map((s, i) => (
          <div key={s.id} style={{
            display: "grid", gridTemplateColumns: "36px 22px 1fr auto 16px",
            gap: 10, alignItems: "center", padding: "10px 2px", fontSize: 12,
            borderBottom: i < scenes.length - 1 ? `1px solid ${gt.rule}` : "none",
          }}>
            <span className="tnum" style={{ color: gt.amber }}>[{String(i + 1).padStart(2, "0")}]</span>
            <GlyBy name={s.glyph} size={16} stroke={gt.green} sw={1.5}/>
            <div style={{ color: gt.ink }}>{s.name.toUpperCase()}</div>
            <TLabel style={{ fontSize: 10 }}>{s.desc.toUpperCase()}</TLabel>
            <Gly.chevR size={12} stroke={gt.dim} sw={1.5}/>
          </div>
        ))}
      </div>

      {/* Rooms — list with index */}
      <div style={{ position: "relative", padding: "14px 0 4px", display: "flex", justifyContent: "space-between" }}>
        <div style={{ color: gt.green, fontSize: 13, letterSpacing: 1, fontWeight: 700 }}>└─ ROOMS.TBL</div>
        <TLabel>06 ROWS</TLabel>
      </div>
      <div style={{ position: "relative", borderTop: `1px solid ${gt.rule}` }}>
        {rooms.map((r, i) => (
          <div key={r.id} onClick={() => go("room")} style={{
            display: "grid", gridTemplateColumns: "36px 22px 1fr 80px 16px",
            gap: 10, alignItems: "center", padding: "10px 2px", fontSize: 12, cursor: "pointer",
            borderBottom: `1px solid ${gt.rule}`,
          }}>
            <span className="tnum" style={{ color: gt.amber }}>[{String(i + 1).padStart(2, "0")}]</span>
            <GlyBy name={r.glyph} size={16} stroke={gt.ink} sw={1.5}/>
            <div style={{ color: gt.ink, textTransform: "uppercase", letterSpacing: 0.4 }}>{r.name}</div>
            <div className="tnum" style={{ fontSize: 11, color: r.active ? gt.green : gt.dim }}>
              {String(r.active).padStart(2, "0")}/{String(r.total).padStart(2, "0")} ON
            </div>
            <Gly.chevR size={12} stroke={gt.dim} sw={1.5}/>
          </div>
        ))}
      </div>
    </div>
  );
}

// ─── Room ──────────────────────────────────────────────────
function GridRoom({ go }) {
  const devices = DEVICES.r1;
  return (
    <div style={{ background: gt.page, color: gt.ink, padding: "4px 16px 130px",
      fontFamily: "'JetBrains Mono', monospace", position: "relative", minHeight: "100%" }}>
      <TDots/>
      <div style={{ position: "relative", display: "flex", justifyContent: "space-between", padding: "4px 0 8px" }}>
        <button onClick={() => go("home")} style={{
          all: "unset", cursor: "pointer", display: "flex", gap: 6, alignItems: "center",
          color: gt.green, fontSize: 11, letterSpacing: 1 }}>
          <Gly.back size={12} stroke={gt.green} sw={1.8}/>
          cd ..
        </button>
        <TLabel color={gt.green}>● LIVE</TLabel>
      </div>
      <TLine/>

      <div style={{ position: "relative", padding: "14px 0 8px" }}>
        <TLabel>/rooms/01 $</TLabel>
        <div style={{ fontSize: 34, fontWeight: 700, color: gt.ink, lineHeight: 1, marginTop: 4, letterSpacing: -0.8 }}>
          LIVING_ROOM<span style={{ color: gt.green }}>_</span>
        </div>
        <div style={{ fontSize: 11, color: gt.dim, marginTop: 6, lineHeight: 1.6 }}>
          HOMEKIT + SONOS · <span style={{ color: gt.green }}>03/05 ACTIVE</span>
        </div>
      </div>
      <TLine/>

      {/* Device table header */}
      <div style={{ position: "relative", display: "grid", gridTemplateColumns: "22px 22px 1fr 72px 44px",
        gap: 8, padding: "8px 0", fontSize: 9, color: gt.dim, letterSpacing: 1, textTransform: "uppercase",
        borderBottom: `1px solid ${gt.rule}` }}>
        <span>ID</span><span></span><span>NAME · STATE</span><span>PROV</span><span style={{ textAlign: "right" }}>PWR</span>
      </div>
      <div style={{ position: "relative" }}>
        {devices.map((d, i) => (
          <div key={d.id} onClick={() => d.cat === "thermo" && go("thermo")}
            style={{ display: "grid", gridTemplateColumns: "22px 22px 1fr 72px 44px",
              gap: 8, padding: "12px 0", alignItems: "center", fontSize: 12,
              borderBottom: `1px solid ${gt.rule}`, cursor: d.cat === "thermo" ? "pointer" : "default" }}>
            <span className="tnum" style={{ color: gt.amber, fontSize: 10 }}>{String(i + 1).padStart(2, "0")}</span>
            <GlyBy name={d.glyph} size={16} stroke={d.on ? gt.green : gt.dim} sw={1.5}/>
            <div>
              <div style={{ color: gt.ink, textTransform: "uppercase", letterSpacing: 0.4 }}>{d.name}</div>
              <div style={{ color: d.on ? gt.green : gt.dim, fontSize: 10, letterSpacing: 0.6, marginTop: 2 }}>
                {d.state}
              </div>
            </div>
            <span style={{ fontSize: 9, color: gt.dim, letterSpacing: 1 }}>{d.provider}</span>
            {/* Terminal toggle: [ ON]  [OFF] */}
            <div style={{ textAlign: "right",
              fontFamily: "'JetBrains Mono', monospace", fontSize: 10, fontWeight: 700,
              color: d.on ? gt.green : gt.red, letterSpacing: 1 }}>
              [{d.on ? " ON " : " OFF"}]
            </div>
          </div>
        ))}
      </div>

      <div style={{ position: "relative", padding: "14px 0 4px", color: gt.amber, fontSize: 11, letterSpacing: 1 }}>
        → tap thermostat for detail
      </div>
    </div>
  );
}

// ─── Thermostat ────────────────────────────────────────────
function GridThermo({ go }) {
  const [tgt, setTgt] = React.useState(THERM.target);
  const [m, setM] = React.useState(THERM.mode);
  const { current, humidity, outdoor, outdoorHumidity, schedule, range } = THERM;
  const pct = (tgt - range[0]) / (range[1] - range[0]);
  const modes = [["heat", "HEAT", "heat"], ["cool", "COOL", "cool"], ["auto", "AUTO", "auto"], ["off", "OFF", "off"]];

  return (
    <div style={{ background: gt.page, color: gt.ink, padding: "4px 16px 130px",
      fontFamily: "'JetBrains Mono', monospace", position: "relative", minHeight: "100%" }}>
      <TDots/>
      <div style={{ position: "relative", display: "flex", justifyContent: "space-between", padding: "4px 0 8px" }}>
        <button onClick={() => go("room")} style={{
          all: "unset", cursor: "pointer", display: "flex", gap: 6, alignItems: "center",
          color: gt.green, fontSize: 11, letterSpacing: 1 }}>
          <Gly.back size={12} stroke={gt.green} sw={1.8}/>
          cd ../living_room
        </button>
        <TLabel color={gt.red}>▲ HEATING</TLabel>
      </div>
      <TLine/>

      {/* Temperature panel */}
      <div style={{ position: "relative", padding: "14px 0 10px" }}>
        <TLabel>/thermo/01 $ READ</TLabel>
        <div className="tnum" style={{
          fontSize: 140, fontWeight: 700, color: gt.green, lineHeight: 0.85,
          letterSpacing: -6, marginTop: 4, marginLeft: -4,
        }}>
          {current}°
        </div>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginTop: 8 }}>
          <div>
            <TLabel>TARGET</TLabel>
            <div className="tnum" style={{ fontSize: 22, fontWeight: 700, color: gt.ink, marginTop: 2 }}>
              {tgt}°F
            </div>
          </div>
          <div style={{ display: "flex", gap: 8 }}>
            <button onClick={() => setTgt(t => t - 1)} style={{
              all: "unset", cursor: "pointer", width: 48, height: 48,
              border: `1.5px solid ${gt.rule}`, background: gt.panel,
              display: "flex", alignItems: "center", justifyContent: "center",
              color: gt.ink, fontSize: 18, fontWeight: 700 }}>—</button>
            <button onClick={() => setTgt(t => t + 1)} style={{
              all: "unset", cursor: "pointer", width: 48, height: 48,
              border: `1.5px solid ${gt.green}`, background: gt.green,
              display: "flex", alignItems: "center", justifyContent: "center",
              color: gt.page, fontSize: 22, fontWeight: 700 }}>+</button>
          </div>
        </div>

        {/* Scale */}
        <div style={{ marginTop: 14, position: "relative" }}>
          <div style={{ display: "flex", gap: 2, height: 22 }}>
            {Array.from({ length: 30 }).map((_, i) => {
              const f = i / 29;
              return <div key={i} style={{ flex: 1,
                background: f <= pct ? gt.green : gt.rule,
                height: i % 5 === 0 ? 22 : 14, alignSelf: "flex-end" }}/>;
            })}
          </div>
          <div className="tnum" style={{ display: "flex", justifyContent: "space-between", marginTop: 4,
            fontSize: 9, color: gt.dim, letterSpacing: 1 }}>
            <span>{range[0]}°F</span><span>75°F</span><span>{range[1]}°F</span>
          </div>
        </div>
      </div>
      <TLine/>

      {/* Mode */}
      <div style={{ position: "relative", padding: "12px 0 6px" }}>
        <div style={{ color: gt.green, fontSize: 12, letterSpacing: 1, fontWeight: 700 }}>└─ MODE.ENUM</div>
      </div>
      <div style={{ position: "relative", display: "grid", gridTemplateColumns: "repeat(4, 1fr)",
        border: `1px solid ${gt.rule}` }}>
        {modes.map(([k, l, g], i) => {
          const a = m === k;
          return (
            <button key={k} onClick={() => setM(k)} style={{
              all: "unset", cursor: "pointer", padding: "12px 4px", textAlign: "center",
              background: a ? gt.green : "transparent",
              color: a ? gt.page : gt.ink,
              borderLeft: i === 0 ? "none" : `1px solid ${gt.rule}`,
            }}>
              <GlyBy name={g} size={18} stroke={a ? gt.page : gt.ink} sw={1.5}
                style={{ margin: "0 auto" }}/>
              <div style={{ marginTop: 4, fontSize: 10, fontWeight: 700, letterSpacing: 1 }}>
                {a ? `[${l}]` : l}
              </div>
            </button>
          );
        })}
      </div>

      {/* Stats */}
      <div style={{ position: "relative", padding: "14px 0 6px" }}>
        <div style={{ color: gt.green, fontSize: 12, letterSpacing: 1, fontWeight: 700 }}>└─ CONDITIONS</div>
      </div>
      <div style={{ position: "relative", border: `1px solid ${gt.rule}` }}>
        {[
          ["INT HUM",  `${humidity}%`,         "drop"],
          ["OUT TEMP", `${outdoor}°F`,         "cloud"],
          ["OUT HUM",  `${outdoorHumidity}%`,  "drop"],
        ].map(([l, v, g], i) => (
          <div key={l} style={{ display: "grid", gridTemplateColumns: "24px 120px 1fr",
            gap: 10, alignItems: "center", padding: "10px 10px", fontSize: 12,
            borderBottom: i < 2 ? `1px solid ${gt.rule}` : "none" }}>
            <GlyBy name={g} size={14} stroke={gt.dim} sw={1.5}/>
            <TLabel>{l}</TLabel>
            <div className="tnum" style={{ color: gt.ink, fontSize: 16, fontWeight: 700, textAlign: "right" }}>{v}</div>
          </div>
        ))}
      </div>

      {/* Schedule */}
      <div style={{ position: "relative", padding: "14px 0 6px", display: "flex", justifyContent: "space-between" }}>
        <div style={{ color: gt.green, fontSize: 12, letterSpacing: 1, fontWeight: 700 }}>└─ SCHEDULE.TBL</div>
        <TLabel>WEEKDAY</TLabel>
      </div>
      <div style={{ position: "relative", border: `1px solid ${gt.rule}` }}>
        {schedule.map((s, i) => (
          <div key={s.label} style={{ display: "grid", gridTemplateColumns: "90px 1fr auto",
            gap: 10, alignItems: "center", padding: "10px 10px", fontSize: 12,
            borderBottom: i < schedule.length - 1 ? `1px solid ${gt.rule}` : "none" }}>
            <TLabel color={gt.ink}>{s.label}</TLabel>
            <div className="tnum" style={{ color: gt.dim, fontSize: 11 }}>{s.time}</div>
            <div className="tnum" style={{ color: gt.green, fontSize: 16, fontWeight: 700 }}>{s.temp}°</div>
          </div>
        ))}
      </div>
    </div>
  );
}

// ─── Tabs ──────────────────────────────────────────────────
function GridTabs({ current, go }) {
  const tabs = [
    ["home",  "HOME",    "home",     "home"],
    ["rooms", "ROOMS",   "rooms",    "room"],
    ["dev",   "NODES",   "devices",  "home"],
    ["set",   "CFG",     "settings", "home"],
  ];
  const cur = current === "room" || current === "thermo" ? "rooms" : "home";
  return (
    <div style={{
      position: "absolute", bottom: 24, left: 14, right: 14, zIndex: 60,
      background: gt.panel, border: `1px solid ${gt.rule}`,
      display: "grid", gridTemplateColumns: "repeat(4, 1fr)",
      fontFamily: "'JetBrains Mono', monospace",
    }}>
      {tabs.map(([k, l, g, target], i) => {
        const a = cur === k;
        return (
          <button key={k} onClick={() => go(target)} style={{
            all: "unset", cursor: "pointer", padding: "9px 4px",
            borderLeft: i === 0 ? "none" : `1px solid ${gt.rule}`,
            display: "flex", flexDirection: "column", alignItems: "center", gap: 3,
            background: a ? gt.green : "transparent",
            color: a ? gt.page : gt.ink,
          }}>
            <GlyBy name={g} size={16} stroke={a ? gt.page : gt.ink} sw={1.5}/>
            <span style={{ fontSize: 9, fontWeight: 700, letterSpacing: 1 }}>
              {a ? `[${l}]` : l}
            </span>
          </button>
        );
      })}
    </div>
  );
}

window.GridTheme = { tokens: gt, Splash: GridSplash, Home: GridHome, Room: GridRoom, Thermo: GridThermo, Tabs: GridTabs };
