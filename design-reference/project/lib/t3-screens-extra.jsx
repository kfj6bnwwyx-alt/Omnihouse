// Additional T3 screens: Rooms index, Devices index, Settings, Device detail
// (light / lock / speaker), Activity, Energy, Add Device, Scene editor.
// Shares primitives from t3-theme.jsx via window.T3Primitives.

const { TLabel: XTLabel, TRule: XTRule, TDot: XTDot, tokens: xt } = window.T3Primitives;

// ── tiny shared building blocks ─────────────────────────────────────────────
function XHeader({ left, right, onBack }) {
  return (
    <div style={{ padding: "8px 24px 0", display: "flex", justifyContent: "space-between", alignItems: "center" }}>
      {onBack ? (
        <button onClick={onBack} style={{ all: "unset", cursor: "pointer",
          display: "flex", alignItems: "center", gap: 6 }}>
          <GlyBy name="back" size={14} stroke={xt.ink} sw={1.4}/>
          <XTLabel color={xt.ink}>{left}</XTLabel>
        </button>
      ) : <XTLabel>{left}</XTLabel>}
      <XTLabel>{right}</XTLabel>
    </div>
  );
}

function XTitle({ eyebrow, dot, title, sub }) {
  return (
    <div style={{ padding: "22px 24px 18px" }}>
      {eyebrow && (
        <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
          {dot && <XTDot size={8}/>}
          <XTLabel>{eyebrow}</XTLabel>
        </div>
      )}
      <div style={{ fontFamily: "'Inter Tight', sans-serif", fontSize: 42, fontWeight: 500,
        letterSpacing: -1.4, lineHeight: 1, marginTop: eyebrow ? 8 : 0 }}>
        {title}
      </div>
      {sub && <div style={{ marginTop: 10, fontSize: 13, color: xt.sub }}>{sub}</div>}
    </div>
  );
}

function XSectionHead({ title, trailing, size = 15 }) {
  return (
    <div style={{ padding: "18px 24px 8px", display: "flex", justifyContent: "space-between", alignItems: "baseline" }}>
      <div style={{ fontFamily: "'Inter Tight', sans-serif", fontSize: size, fontWeight: 500 }}>{title}</div>
      {trailing && <XTLabel>{trailing}</XTLabel>}
    </div>
  );
}

function XPill({ on, size = "sm" }) {
  const w = size === "sm" ? 40 : 48, h = size === "sm" ? 22 : 26, k = size === "sm" ? 18 : 22;
  return (
    <div style={{
      width: w, height: h, borderRadius: 999,
      background: on ? xt.ink : xt.rule, position: "relative", transition: "background 150ms",
    }}>
      <div style={{
        position: "absolute", top: 2, left: on ? w - k - 2 : 2,
        width: k, height: k, borderRadius: "50%",
        background: on ? xt.accent : "#fff",
        transition: "left 150ms",
      }}/>
    </div>
  );
}

// ════════════════════════════════════════════════════════════════════════════
// ROOMS (tab) — index grid of all rooms
// ════════════════════════════════════════════════════════════════════════════
function T3Rooms({ go }) {
  const { rooms } = HOUSE_DATA;
  return (
    <div style={{ background: xt.page, color: xt.ink, paddingBottom: 110 }}>
      <XHeader left="Your Home" right="06 rooms"/>
      <XTitle title="Rooms." sub={`${rooms.reduce((a, r) => a + r.active, 0)} devices active across the house`}/>
      <XTRule/>
      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr" }}>
        {rooms.map((r, i) => (
          <div key={r.id} onClick={() => go("room", { roomId: r.id })} style={{
            padding: "22px 20px", cursor: "pointer",
            borderBottom: `1px solid ${xt.rule}`,
            borderRight: i % 2 === 0 ? `1px solid ${xt.rule}` : "none",
            minHeight: 150,
            display: "flex", flexDirection: "column", justifyContent: "space-between",
          }}>
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start" }}>
              <GlyBy name={r.glyph} size={22} stroke={xt.ink} sw={1.4}/>
              <XTLabel className="tnum">{String(i + 1).padStart(2, "0")}</XTLabel>
            </div>
            <div>
              <div style={{ fontFamily: "'Inter Tight', sans-serif", fontSize: 18,
                fontWeight: 500, letterSpacing: -0.3 }}>{r.name}</div>
              <div style={{ display: "flex", alignItems: "center", gap: 8, marginTop: 6 }}>
                {r.active > 0 && <XTDot size={5}/>}
                <span className="tnum" style={{ fontFamily: "'IBM Plex Mono', monospace",
                  fontSize: 11, color: xt.sub, letterSpacing: 1 }}>
                  {r.active}/{r.total} on
                </span>
              </div>
            </div>
          </div>
        ))}
      </div>
      <XSectionHead title="Add room" trailing="+"/>
      <div style={{ padding: "0 24px 20px" }}>
        <button style={{ all: "unset", cursor: "pointer", display: "flex",
          alignItems: "center", justifyContent: "center", gap: 8, width: "100%",
          padding: "14px", border: `1px dashed ${xt.sub}`, color: xt.sub, fontSize: 13 }}>
          <GlyBy name="plus" size={14} stroke={xt.sub} sw={1.4}/>
          <span>New room</span>
        </button>
      </div>
    </div>
  );
}

// ════════════════════════════════════════════════════════════════════════════
// DEVICES (tab) — flat list + filter
// ════════════════════════════════════════════════════════════════════════════
function T3Devices({ go }) {
  const [filter, setFilter] = React.useState("all");
  const filters = [
    ["all",    "All"],
    ["on",     "On"],
    ["light",  "Lights"],
    ["climate","Climate"],
    ["media",  "Media"],
  ];
  const matches = (d) => {
    if (filter === "all") return true;
    if (filter === "on") return d.on;
    if (filter === "light") return d.cat === "light";
    if (filter === "climate") return d.cat === "thermo" || d.cat === "fan";
    if (filter === "media") return d.cat === "speaker" || d.cat === "media";
    return true;
  };
  const list = ALL_DEVICES.filter(matches);
  return (
    <div style={{ background: xt.page, color: xt.ink, paddingBottom: 110 }}>
      <XHeader left="All devices" right={`${ALL_DEVICES.length} total`}/>
      <XTitle title="Devices." sub={`${ALL_DEVICES.filter(d => d.on).length} on now · across 6 rooms`}/>
      <XTRule/>
      {/* Filter row */}
      <div style={{ padding: "14px 24px 10px", display: "flex", gap: 8, overflowX: "auto" }}>
        {filters.map(([k, l]) => {
          const a = filter === k;
          return (
            <button key={k} onClick={() => setFilter(k)} style={{
              all: "unset", cursor: "pointer", flexShrink: 0,
              padding: "7px 14px", borderRadius: 999,
              border: `1px solid ${xt.rule}`,
              background: a ? xt.ink : xt.panel,
              color: a ? xt.page : xt.ink,
              fontSize: 12, fontWeight: 500, letterSpacing: -0.1,
            }}>{l}</button>
          );
        })}
      </div>
      <div>
        {list.map((d, i) => (
          <div key={d.id} onClick={() => {
            if (d.cat === "thermo") go("thermo");
            else if (["light","lock","speaker"].includes(d.cat)) go("device", { deviceId: d.id });
          }} style={{
            display: "grid", gridTemplateColumns: "28px 1fr auto auto",
            gap: 12, alignItems: "center", padding: "14px 24px",
            borderTop: `1px solid ${xt.rule}`,
            borderBottom: i === list.length - 1 ? `1px solid ${xt.rule}` : "none",
            cursor: "pointer",
          }}>
            <GlyBy name={d.glyph} size={18} stroke={xt.ink} sw={1.4}/>
            <div>
              <div style={{ fontSize: 14, fontWeight: 500, letterSpacing: -0.2 }}>{d.name}</div>
              <div style={{ fontSize: 11, color: xt.sub, marginTop: 2,
                display: "flex", alignItems: "center", gap: 8 }}>
                <span style={{ fontFamily: "'IBM Plex Mono', monospace", letterSpacing: 1 }}>
                  {d.room.toUpperCase()}
                </span>
                <span>·</span>
                <span>{d.state}</span>
              </div>
            </div>
            <span style={{ fontFamily: "'IBM Plex Mono', monospace",
              fontSize: 10, color: xt.sub, letterSpacing: 1 }}>{d.provider}</span>
            <XPill on={d.on}/>
          </div>
        ))}
      </div>
      <div style={{ padding: "24px" }}>
        <button onClick={() => go("addDevice")} style={{ all: "unset", cursor: "pointer",
          display: "flex", alignItems: "center", justifyContent: "center", gap: 8,
          width: "100%", padding: "14px", border: `1px dashed ${xt.sub}`, color: xt.sub, fontSize: 13 }}>
          <GlyBy name="plus" size={14} stroke={xt.sub} sw={1.4}/>
          <span>Add device</span>
        </button>
      </div>
    </div>
  );
}

// ════════════════════════════════════════════════════════════════════════════
// SETTINGS (tab)
// ════════════════════════════════════════════════════════════════════════════
function T3Settings({ go }) {
  const groups = [
    { title: "Account", rows: [
      ["user",     "Alex Ritter",      "alex@maplest.co",     "account"],
      ["home",     "Maple Street",     "Portland, OR · owner", null],
    ]},
    { title: "Connections", rows: [
      ["wifi",     "HomeKit",          "14 devices · paired",  "integrations"],
      ["wifi",     "SmartThings",      "2 devices · paired",   "integrations"],
      ["wifi",     "Sonos",            "2 devices · paired",   "integrations"],
      ["wifi",     "Nest",             "1 device · paired",    "integrations"],
    ]},
    { title: "Preferences", rows: [
      ["bell",     "Notifications",    "Important only",       null],
      ["moon",     "Appearance",       "Auto (system)",        null],
      ["thermo",   "Units",            "Fahrenheit · imperial",null],
      ["lock",     "Privacy & access", "Face ID required",     null],
    ]},
    { title: "Automation", rows: [
      ["scenes",   "Scenes",           "05 configured",        "scene"],
      ["auto",     "Routines",         "03 active",            null],
      ["bolt",     "Energy goals",     "Off",                  "energy"],
    ]},
    { title: "System", rows: [
      ["settings", "Advanced",         "Registry · logs",      null],
      ["off",      "Sign out",         null,                   null],
    ]},
  ];
  return (
    <div style={{ background: xt.page, color: xt.ink, paddingBottom: 110 }}>
      <XHeader left="Settings" right="V 1.0"/>
      <XTitle title="Settings." sub="Account, connections, and automation."/>
      <XTRule/>
      {groups.map((g, gi) => (
        <div key={g.title}>
          <XSectionHead title={g.title} trailing={`${String(g.rows.length).padStart(2, "0")}`}/>
          <div>
            {g.rows.map(([icon, label, sub, target], i) => (
              <div key={label} onClick={() => target && go(target)} style={{
                display: "grid", gridTemplateColumns: "28px 1fr 14px",
                gap: 14, alignItems: "center", padding: "14px 24px",
                borderTop: `1px solid ${xt.rule}`,
                borderBottom: i === g.rows.length - 1 ? `1px solid ${xt.rule}` : "none",
                cursor: target ? "pointer" : "default",
              }}>
                <GlyBy name={icon} size={18} stroke={xt.ink} sw={1.4}/>
                <div>
                  <div style={{ fontSize: 14, fontWeight: 500, letterSpacing: -0.2 }}>{label}</div>
                  {sub && <div style={{ fontSize: 11, color: xt.sub, marginTop: 2 }}>{sub}</div>}
                </div>
                {target && <GlyBy name="chevR" size={12} stroke={xt.sub} sw={1.4}/>}
              </div>
            ))}
          </div>
        </div>
      ))}
      <div style={{ padding: "24px", textAlign: "center" }}>
        <XTLabel>House Connect · 1.0.0 · Build 214</XTLabel>
      </div>
    </div>
  );
}

// ════════════════════════════════════════════════════════════════════════════
// DEVICE DETAIL — routes by device.cat
// ════════════════════════════════════════════════════════════════════════════
function T3Device({ go, deviceId }) {
  const d = ALL_DEVICES.find(x => x.id === deviceId) || ALL_DEVICES[0];
  if (d.cat === "light")   return <T3LightDetail go={go} d={d}/>;
  if (d.cat === "lock")    return <T3LockDetail go={go} d={d}/>;
  if (d.cat === "speaker") return <T3SpeakerDetail go={go} d={d}/>;
  return <T3LightDetail go={go} d={d}/>;
}

// ─── Light detail ──────────────────────────────────────────────────────────
function T3LightDetail({ go, d }) {
  const [on, setOn] = React.useState(d.on);
  const [brightness, setBrightness] = React.useState(() => {
    const m = /(\d+)%/.exec(d.state); return m ? parseInt(m[1], 10) : 60;
  });
  const [temp, setTemp] = React.useState(2);
  const temps = [
    ["1", "Warm",  "2700K"],
    ["2", "Neutral","3500K"],
    ["3", "Cool",  "5000K"],
    ["4", "Day",   "6500K"],
  ];
  return (
    <div style={{ background: xt.page, color: xt.ink, paddingBottom: 110 }}>
      <XHeader left={d.room} right={d.provider} onBack={() => go("room", { roomId: d.roomId })}/>
      <div style={{ padding: "22px 24px 8px" }}>
        <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
          {on && <XTDot size={8}/>}
          <XTLabel>{on ? "On" : "Off"}</XTLabel>
        </div>
        <div style={{ fontFamily: "'Inter Tight', sans-serif", fontSize: 42, fontWeight: 500,
          letterSpacing: -1.4, lineHeight: 1, marginTop: 8 }}>
          {d.name}
        </div>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginTop: 16 }}>
          <div className="tnum" style={{ fontFamily: "'Inter Tight', sans-serif", fontSize: 96,
            fontWeight: 300, letterSpacing: -4, lineHeight: 0.85 }}>
            {on ? brightness : 0}<span style={{ fontSize: 40, color: xt.sub }}>%</span>
          </div>
          <button onClick={() => setOn(v => !v)} style={{ all: "unset", cursor: "pointer" }}>
            <XPill on={on} size="lg"/>
          </button>
        </div>
      </div>

      {/* Brightness slider */}
      <div style={{ padding: "18px 24px 22px" }}>
        <XTLabel>Brightness</XTLabel>
        <div style={{ position: "relative", height: 28, marginTop: 10 }}>
          {Array.from({ length: 41 }).map((_, i) => {
            const f = i / 40, major = i % 5 === 0, active = f * 100 <= brightness && on;
            return <div key={i} style={{
              position: "absolute", left: `${f * 100}%`, top: 0,
              width: 1, height: major ? 14 : 7,
              background: active ? xt.ink : xt.rule, transform: "translateX(-0.5px)",
            }}/>;
          })}
          <div style={{ position: "absolute", left: `${brightness}%`, top: 16,
            transform: "translateX(-50%)" }}><XTDot size={10}/></div>
        </div>
        <div style={{ display: "flex", justifyContent: "space-between", marginTop: 6 }}>
          <XTLabel>0%</XTLabel>
          <XTLabel>50%</XTLabel>
          <XTLabel>100%</XTLabel>
        </div>
        <div style={{ display: "flex", gap: 8, marginTop: 14 }}>
          {[25, 50, 75, 100].map(v => (
            <button key={v} onClick={() => { setBrightness(v); setOn(true); }} style={{
              all: "unset", cursor: "pointer", flex: 1, textAlign: "center",
              padding: "10px 0", border: `1px solid ${xt.rule}`,
              background: brightness === v ? xt.ink : xt.panel,
              color: brightness === v ? xt.page : xt.ink,
              fontSize: 12, fontWeight: 500, fontFamily: "'IBM Plex Mono', monospace",
            }}>{v}%</button>
          ))}
        </div>
      </div>

      <XTRule/>

      {/* Color temp */}
      <div style={{ padding: "18px 24px 10px" }}>
        <XTLabel>Temperature</XTLabel>
      </div>
      <div style={{ padding: "0 24px 20px" }}>
        <div style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: 6,
          border: `1px solid ${xt.rule}`, borderRadius: 8, padding: 3, background: xt.panel }}>
          {temps.map(([k, label, kelvin], i) => {
            const a = temp === i + 1;
            return (
              <button key={k} onClick={() => setTemp(i + 1)} style={{
                all: "unset", cursor: "pointer", padding: "10px 4px", textAlign: "center",
                background: a ? xt.ink : "transparent", color: a ? xt.page : xt.ink,
                borderRadius: 6, display: "flex", flexDirection: "column", gap: 3,
              }}>
                <span style={{ fontSize: 12, fontWeight: 500 }}>{label}</span>
                <span style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 9,
                  color: a ? xt.page : xt.sub, letterSpacing: 1 }}>{kelvin}</span>
              </button>
            );
          })}
        </div>
      </div>

      <XTRule/>
      <div style={{ padding: "18px 24px", display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: 18 }}>
        {[["Power", "9W"], ["Uptime", "4h 12m"], ["Since", "Morning"]].map(([l, v]) => (
          <div key={l}>
            <XTLabel>{l}</XTLabel>
            <div className="tnum" style={{ fontFamily: "'Inter Tight', sans-serif",
              fontSize: 22, fontWeight: 400, letterSpacing: -0.6, marginTop: 4 }}>{v}</div>
          </div>
        ))}
      </div>
    </div>
  );
}

// ─── Lock detail ──────────────────────────────────────────────────────────
function T3LockDetail({ go, d }) {
  const [locked, setLocked] = React.useState(!d.on);
  const events = [
    { time: "08:14", who: "Alex",       action: "Unlocked",  method: "Face ID" },
    { time: "07:58", who: "Auto-lock",  action: "Locked",    method: "Routine" },
    { time: "22:31", who: "Sam",        action: "Unlocked",  method: "Code · 4821" },
    { time: "22:30", who: "Alex",       action: "Locked",    method: "App" },
  ];
  return (
    <div style={{ background: xt.page, color: xt.ink, paddingBottom: 110 }}>
      <XHeader left={d.room} right={d.provider} onBack={() => go("room", { roomId: d.roomId })}/>
      <div style={{ padding: "22px 24px 8px" }}>
        <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
          {!locked && <XTDot size={8}/>}
          <XTLabel>{locked ? "Secured" : "Unlocked"}</XTLabel>
        </div>
        <div style={{ fontFamily: "'Inter Tight', sans-serif", fontSize: 42, fontWeight: 500,
          letterSpacing: -1.4, lineHeight: 1, marginTop: 8 }}>
          {d.name}
        </div>
      </div>
      <div style={{ padding: "24px", display: "flex", justifyContent: "center" }}>
        <button onClick={() => setLocked(v => !v)} style={{
          all: "unset", cursor: "pointer",
          width: 220, height: 220, borderRadius: "50%",
          background: locked ? xt.panel : xt.ink,
          border: `1px solid ${locked ? xt.rule : xt.ink}`,
          display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 14,
        }}>
          <GlyBy name="lock" size={54} stroke={locked ? xt.ink : xt.accent} sw={1.2}/>
          <div style={{ fontFamily: "'Inter Tight', sans-serif", fontSize: 18, fontWeight: 500,
            color: locked ? xt.ink : xt.page, letterSpacing: -0.2 }}>
            {locked ? "Tap to unlock" : "Tap to lock"}
          </div>
        </button>
      </div>
      <XTRule/>
      <div style={{ padding: "18px 24px", display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: 18 }}>
        {[["Battery", "74%"], ["Signal", "Strong"], ["Firmware", "2.4.1"]].map(([l, v]) => (
          <div key={l}>
            <XTLabel>{l}</XTLabel>
            <div className="tnum" style={{ fontFamily: "'Inter Tight', sans-serif",
              fontSize: 22, fontWeight: 400, letterSpacing: -0.6, marginTop: 4 }}>{v}</div>
          </div>
        ))}
      </div>
      <XTRule/>
      <XSectionHead title="Recent access" trailing="TODAY"/>
      {events.map((e, i) => (
        <div key={i} style={{
          display: "grid", gridTemplateColumns: "60px 1fr auto", gap: 12,
          padding: "14px 24px", alignItems: "center",
          borderTop: `1px solid ${xt.rule}`,
          borderBottom: i === events.length - 1 ? `1px solid ${xt.rule}` : "none",
        }}>
          <span className="tnum" style={{ fontFamily: "'IBM Plex Mono', monospace",
            fontSize: 11, color: xt.sub, letterSpacing: 1 }}>{e.time}</span>
          <div>
            <div style={{ fontSize: 14, fontWeight: 500 }}>{e.action}<span style={{ color: xt.sub }}> · {e.who}</span></div>
            <div style={{ fontSize: 11, color: xt.sub, marginTop: 2,
              fontFamily: "'IBM Plex Mono', monospace", letterSpacing: 0.8 }}>
              {e.method.toUpperCase()}
            </div>
          </div>
          <GlyBy name={e.action === "Locked" ? "lock" : "check"} size={14} stroke={xt.sub} sw={1.4}/>
        </div>
      ))}
    </div>
  );
}

// ─── Speaker detail ───────────────────────────────────────────────────────
function T3SpeakerDetail({ go, d }) {
  const [playing, setPlaying] = React.useState(d.state.startsWith("PLAYING"));
  const [vol, setVol] = React.useState(38);
  return (
    <div style={{ background: xt.page, color: xt.ink, paddingBottom: 110 }}>
      <XHeader left={d.room} right={d.provider} onBack={() => go("room", { roomId: d.roomId })}/>
      <div style={{ padding: "22px 24px 8px" }}>
        <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
          {playing && <XTDot size={8}/>}
          <XTLabel>{playing ? "Playing" : "Idle"}</XTLabel>
        </div>
        <div style={{ fontFamily: "'Inter Tight', sans-serif", fontSize: 42, fontWeight: 500,
          letterSpacing: -1.4, lineHeight: 1, marginTop: 8 }}>
          {d.name}
        </div>
      </div>

      {/* Now playing card */}
      <div style={{ margin: "8px 24px 18px", border: `1px solid ${xt.rule}`,
        background: xt.panel, padding: 18, display: "grid", gridTemplateColumns: "64px 1fr", gap: 16 }}>
        <div style={{ width: 64, height: 64, background: xt.ink,
          display: "flex", alignItems: "center", justifyContent: "center" }}>
          <XTDot size={10} color={xt.accent}/>
        </div>
        <div style={{ minWidth: 0 }}>
          <XTLabel>Now playing</XTLabel>
          <div style={{ fontFamily: "'Inter Tight', sans-serif", fontSize: 16, fontWeight: 500,
            marginTop: 4, letterSpacing: -0.2, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>
            Treats
          </div>
          <div style={{ fontSize: 12, color: xt.sub, marginTop: 2 }}>Sleigh Bells · 2010</div>
        </div>
      </div>

      {/* Transport */}
      <div style={{ padding: "0 24px 22px", display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <button style={{ all: "unset", cursor: "pointer",
          width: 52, height: 52, border: `1px solid ${xt.rule}`, borderRadius: "50%",
          display: "flex", alignItems: "center", justifyContent: "center" }}>
          <GlyBy name="back" size={16} stroke={xt.ink} sw={1.5}/>
        </button>
        <button onClick={() => setPlaying(v => !v)} style={{ all: "unset", cursor: "pointer",
          width: 72, height: 72, borderRadius: "50%", background: xt.accent,
          display: "flex", alignItems: "center", justifyContent: "center" }}>
          <GlyBy name={playing ? "pause" : "play"} size={24} stroke="#fff" sw={1.6} fill="#fff"/>
        </button>
        <button style={{ all: "unset", cursor: "pointer",
          width: 52, height: 52, border: `1px solid ${xt.rule}`, borderRadius: "50%",
          display: "flex", alignItems: "center", justifyContent: "center" }}>
          <GlyBy name="next" size={16} stroke={xt.ink} sw={1.5} fill={xt.ink}/>
        </button>
      </div>

      <XTRule/>

      {/* Volume */}
      <div style={{ padding: "18px 24px 22px" }}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline" }}>
          <XTLabel>Volume</XTLabel>
          <span className="tnum" style={{ fontFamily: "'Inter Tight', sans-serif", fontSize: 22,
            fontWeight: 500, letterSpacing: -0.4 }}>{vol}</span>
        </div>
        <div style={{ position: "relative", height: 28, marginTop: 10 }}>
          {Array.from({ length: 41 }).map((_, i) => {
            const f = i / 40, major = i % 5 === 0, active = f * 100 <= vol;
            return <div key={i} style={{
              position: "absolute", left: `${f * 100}%`, top: 0,
              width: 1, height: major ? 14 : 7,
              background: active ? xt.ink : xt.rule, transform: "translateX(-0.5px)",
            }}/>;
          })}
          <div style={{ position: "absolute", left: `${vol}%`, top: 16,
            transform: "translateX(-50%)" }}><XTDot size={10}/></div>
        </div>
      </div>

      <XTRule/>
      <XSectionHead title="Group with" trailing="04 ROOMS"/>
      <div>
        {["Living Room", "Kitchen", "Family Room", "Den"].map((r, i) => (
          <div key={r} style={{
            display: "grid", gridTemplateColumns: "28px 1fr auto",
            gap: 12, padding: "14px 24px", alignItems: "center",
            borderTop: `1px solid ${xt.rule}`,
            borderBottom: i === 3 ? `1px solid ${xt.rule}` : "none",
          }}>
            <GlyBy name="speaker" size={18} stroke={xt.ink} sw={1.4}/>
            <div style={{ fontSize: 14, fontWeight: 500 }}>{r}</div>
            <XPill on={i === 0}/>
          </div>
        ))}
      </div>
    </div>
  );
}

// ════════════════════════════════════════════════════════════════════════════
// ACTIVITY
// ════════════════════════════════════════════════════════════════════════════
function T3Activity({ go }) {
  return (
    <div style={{ background: xt.page, color: xt.ink, paddingBottom: 110 }}>
      <XHeader left="Today" right="07 events" onBack={() => go("home")}/>
      <XTitle title="Activity." sub="Everything that happened in the house today."/>
      <XTRule/>
      {ACTIVITY.map((e, i) => (
        <div key={e.id} style={{
          display: "grid", gridTemplateColumns: "56px 28px 1fr",
          gap: 12, padding: "16px 24px", alignItems: "center",
          borderTop: `1px solid ${xt.rule}`,
          borderBottom: i === ACTIVITY.length - 1 ? `1px solid ${xt.rule}` : "none",
        }}>
          <span className="tnum" style={{ fontFamily: "'IBM Plex Mono', monospace",
            fontSize: 11, color: xt.sub, letterSpacing: 1 }}>{e.time}</span>
          <GlyBy name={e.glyph} size={18} stroke={xt.ink} sw={1.4}/>
          <div>
            <div style={{ fontSize: 14, fontWeight: 500, letterSpacing: -0.2 }}>{e.label}</div>
            <div style={{ fontSize: 11, color: xt.sub, marginTop: 2 }}>{e.sub}</div>
          </div>
        </div>
      ))}
    </div>
  );
}

// ════════════════════════════════════════════════════════════════════════════
// ENERGY
// ════════════════════════════════════════════════════════════════════════════
function T3Energy({ go }) {
  const { today, yesterday, month, hourly, byCategory } = ENERGY;
  const max = Math.max(...hourly);
  return (
    <div style={{ background: xt.page, color: xt.ink, paddingBottom: 110 }}>
      <XHeader left="Today" right="kWh" onBack={() => go("home")}/>

      <div style={{ padding: "22px 24px 8px" }}>
        <XTLabel>Total today</XTLabel>
        <div className="tnum" style={{ fontFamily: "'Inter Tight', sans-serif", fontSize: 120,
          fontWeight: 300, letterSpacing: -5, lineHeight: 0.85, marginTop: 4 }}>
          {today}<span style={{ fontSize: 36, color: xt.accent, letterSpacing: 0 }}> kWh</span>
        </div>
        <div style={{ fontSize: 13, color: xt.sub, marginTop: 8 }}>
          <span style={{ color: xt.ink }}>↓ 15%</span> vs. yesterday ({yesterday} kWh)
        </div>
      </div>

      {/* Hourly bars */}
      <div style={{ padding: "18px 24px 4px" }}>
        <XTLabel>Hourly draw</XTLabel>
        <div style={{ height: 120, marginTop: 14, display: "flex",
          alignItems: "flex-end", gap: 2, borderBottom: `1px solid ${xt.rule}` }}>
          {hourly.map((v, i) => (
            <div key={i} style={{
              flex: 1,
              height: `${(v / max) * 100}%`,
              background: i === 18 ? xt.accent : xt.ink,
              minHeight: 2,
            }}/>
          ))}
        </div>
        <div style={{ display: "flex", justifyContent: "space-between", marginTop: 6 }}>
          {["00","06","12","18","24"].map(h => <XTLabel key={h} className="tnum">{h}</XTLabel>)}
        </div>
      </div>

      <XTRule style={{ marginTop: 18 }}/>

      <XSectionHead title="By category" trailing={`${today} KWH`}/>
      {byCategory.map((c, i) => (
        <div key={c.label} style={{
          padding: "14px 24px",
          borderTop: `1px solid ${xt.rule}`,
          borderBottom: i === byCategory.length - 1 ? `1px solid ${xt.rule}` : "none",
        }}>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline" }}>
            <div style={{ fontSize: 14, fontWeight: 500 }}>{c.label}</div>
            <div style={{ display: "flex", gap: 12, alignItems: "baseline" }}>
              <span className="tnum" style={{ fontFamily: "'IBM Plex Mono', monospace",
                fontSize: 11, color: xt.sub }}>{Math.round(c.pct * 100)}%</span>
              <span className="tnum" style={{ fontFamily: "'Inter Tight', sans-serif",
                fontSize: 16, fontWeight: 500 }}>{c.kwh}</span>
            </div>
          </div>
          <div style={{ height: 3, background: xt.rule, marginTop: 10, position: "relative" }}>
            <div style={{ position: "absolute", inset: 0, width: `${c.pct * 100}%`,
              background: i === 0 ? xt.accent : xt.ink }}/>
          </div>
        </div>
      ))}

      <div style={{ padding: "18px 24px", display: "grid", gridTemplateColumns: "1fr 1fr", gap: 18 }}>
        <div>
          <XTLabel>This month</XTLabel>
          <div className="tnum" style={{ fontFamily: "'Inter Tight', sans-serif",
            fontSize: 28, fontWeight: 400, letterSpacing: -0.8, marginTop: 4 }}>{month} kWh</div>
        </div>
        <div>
          <XTLabel>Est. cost</XTLabel>
          <div className="tnum" style={{ fontFamily: "'Inter Tight', sans-serif",
            fontSize: 28, fontWeight: 400, letterSpacing: -0.8, marginTop: 4 }}>$42.10</div>
        </div>
      </div>
    </div>
  );
}

// ════════════════════════════════════════════════════════════════════════════
// ADD DEVICE
// ════════════════════════════════════════════════════════════════════════════
function T3AddDevice({ go }) {
  const providers = [
    ["HomeKit",     "Apple · 14 paired"],
    ["SmartThings", "Samsung · 2 paired"],
    ["Sonos",       "Sonos · 2 paired"],
    ["Nest",        "Google · 1 paired"],
    ["Matter",      "Discover nearby"],
  ];
  const discovered = [
    { name: "Hue bulb", loc: "Nearby · Bluetooth" },
    { name: "Aqara sensor", loc: "Nearby · Thread" },
    { name: "Sonos One (kitchen)", loc: "Nearby · Wi-Fi" },
  ];
  return (
    <div style={{ background: xt.page, color: xt.ink, paddingBottom: 110 }}>
      <XHeader left="Cancel" right="Add" onBack={() => go("devices")}/>
      <XTitle title="Add a device." sub="Pick a provider, or pair something new over Matter."/>
      <XTRule/>

      <XSectionHead title="Providers" trailing="05"/>
      {providers.map(([p, sub], i) => (
        <div key={p} style={{
          display: "grid", gridTemplateColumns: "28px 1fr 14px", gap: 14,
          padding: "14px 24px", alignItems: "center",
          borderTop: `1px solid ${xt.rule}`,
          borderBottom: i === providers.length - 1 ? `1px solid ${xt.rule}` : "none",
          cursor: "pointer",
        }}>
          <GlyBy name="wifi" size={18} stroke={xt.ink} sw={1.4}/>
          <div>
            <div style={{ fontSize: 14, fontWeight: 500 }}>{p}</div>
            <div style={{ fontSize: 11, color: xt.sub, marginTop: 2 }}>{sub}</div>
          </div>
          <GlyBy name="chevR" size={12} stroke={xt.sub} sw={1.4}/>
        </div>
      ))}

      <XSectionHead title="Discovered nearby" trailing="03"/>
      {discovered.map((d, i) => (
        <div key={d.name} style={{
          display: "grid", gridTemplateColumns: "28px 1fr auto", gap: 14,
          padding: "14px 24px", alignItems: "center",
          borderTop: `1px solid ${xt.rule}`,
          borderBottom: i === discovered.length - 1 ? `1px solid ${xt.rule}` : "none",
        }}>
          <XTDot size={8}/>
          <div>
            <div style={{ fontSize: 14, fontWeight: 500 }}>{d.name}</div>
            <div style={{ fontSize: 11, color: xt.sub, marginTop: 2,
              fontFamily: "'IBM Plex Mono', monospace", letterSpacing: 0.8 }}>
              {d.loc.toUpperCase()}
            </div>
          </div>
          <button style={{ all: "unset", cursor: "pointer",
            padding: "8px 14px", border: `1px solid ${xt.ink}`, color: xt.ink,
            fontSize: 11, fontWeight: 600, letterSpacing: 1, textTransform: "uppercase",
            fontFamily: "'IBM Plex Mono', monospace" }}>Pair</button>
        </div>
      ))}
    </div>
  );
}

// ════════════════════════════════════════════════════════════════════════════
// SCENE EDITOR
// ════════════════════════════════════════════════════════════════════════════
function T3SceneEdit({ go, sceneId = "s1" }) {
  const scene = HOUSE_DATA.scenes.find(s => s.id === sceneId) || HOUSE_DATA.scenes[0];
  const sceneActions = [
    { room: "Living Room", device: "Ceiling Lights", action: "ON · 80%", glyph: "lightbulb" },
    { room: "Living Room", device: "Thermostat",     action: "71°",       glyph: "thermo" },
    { room: "Kitchen",     device: "Kitchen Lights", action: "ON · 70%",  glyph: "lightbulb" },
    { room: "Kitchen",     device: "Under-Cabinet",  action: "ON · 30%",  glyph: "lightbulb" },
    { room: "Entryway",    device: "Front Door",     action: "LOCKED",    glyph: "lock" },
    { room: "Bedroom",     device: "Blinds",         action: "OPEN · 100%", glyph: "door" },
    { room: "Family Room", device: "Sonos Arc",      action: "LOW · MORNING", glyph: "speaker" },
  ];
  return (
    <div style={{ background: xt.page, color: xt.ink, paddingBottom: 110 }}>
      <XHeader left="Scenes" right="Save" onBack={() => go("home")}/>
      <div style={{ padding: "22px 24px 18px" }}>
        <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
          <GlyBy name={scene.glyph} size={16} stroke={xt.ink} sw={1.4}/>
          <XTLabel>Scene · 07 actions</XTLabel>
        </div>
        <div style={{ fontFamily: "'Inter Tight', sans-serif", fontSize: 42, fontWeight: 500,
          letterSpacing: -1.4, lineHeight: 1, marginTop: 10 }}>
          {scene.name}.
        </div>
        <div style={{ marginTop: 10, fontSize: 13, color: xt.sub }}>
          Runs weekdays at 07:00 · manually from Home
        </div>
      </div>
      <XTRule/>

      <XSectionHead title="When to run" trailing="TRIGGER"/>
      <div style={{ padding: "0 24px 18px" }}>
        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: 6,
          border: `1px solid ${xt.rule}`, borderRadius: 8, padding: 3, background: xt.panel }}>
          {[["time", "Schedule"], ["loc", "Arrive"], ["manual", "Manual"]].map(([k, l], i) => {
            const a = i === 0;
            return (
              <button key={k} style={{
                all: "unset", cursor: "pointer", padding: "10px 4px", textAlign: "center",
                background: a ? xt.ink : "transparent", color: a ? xt.page : xt.ink,
                borderRadius: 6, fontSize: 12, fontWeight: 500,
              }}>{l}</button>
            );
          })}
        </div>
        <div style={{ marginTop: 12, padding: "12px 14px", border: `1px solid ${xt.rule}`,
          display: "flex", justifyContent: "space-between", alignItems: "center" }}>
          <XTLabel>Weekdays at</XTLabel>
          <span className="tnum" style={{ fontFamily: "'Inter Tight', sans-serif", fontSize: 22,
            fontWeight: 500, letterSpacing: -0.4 }}>07:00</span>
        </div>
      </div>
      <XTRule/>

      <XSectionHead title="Actions" trailing={`${String(sceneActions.length).padStart(2, "0")}`}/>
      {sceneActions.map((a, i) => (
        <div key={i} style={{
          display: "grid", gridTemplateColumns: "28px 1fr auto 14px",
          gap: 12, padding: "14px 24px", alignItems: "center",
          borderTop: `1px solid ${xt.rule}`,
          borderBottom: i === sceneActions.length - 1 ? `1px solid ${xt.rule}` : "none",
        }}>
          <GlyBy name={a.glyph} size={18} stroke={xt.ink} sw={1.4}/>
          <div>
            <div style={{ fontSize: 14, fontWeight: 500 }}>{a.device}</div>
            <div style={{ fontSize: 11, color: xt.sub, marginTop: 2,
              fontFamily: "'IBM Plex Mono', monospace", letterSpacing: 0.8 }}>
              {a.room.toUpperCase()}
            </div>
          </div>
          <span className="tnum" style={{ fontFamily: "'IBM Plex Mono', monospace",
            fontSize: 11, color: xt.ink, letterSpacing: 1 }}>{a.action}</span>
          <GlyBy name="chevR" size={12} stroke={xt.sub} sw={1.4}/>
        </div>
      ))}

      <div style={{ padding: "24px" }}>
        <button style={{ all: "unset", cursor: "pointer",
          display: "flex", alignItems: "center", justifyContent: "center", gap: 8,
          width: "100%", padding: "14px", border: `1px dashed ${xt.sub}`, color: xt.sub, fontSize: 13 }}>
          <GlyBy name="plus" size={14} stroke={xt.sub} sw={1.4}/>
          <span>Add action</span>
        </button>
      </div>
    </div>
  );
}

Object.assign(window.T3Theme, {
  Rooms: T3Rooms,
  Devices: T3Devices,
  Settings: T3Settings,
  Device: T3Device,
  Activity: T3Activity,
  Energy: T3Energy,
  AddDevice: T3AddDevice,
  SceneEdit: T3SceneEdit,
});
