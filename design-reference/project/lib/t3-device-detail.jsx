// Batch A — Device detail screens: Sonos, Smoke, Frame TV, Camera, Device Group.
// Follows the same T3 vocabulary as t3-screens-extra.jsx.

const A = window.T3Ext;
const aT = A.tokens;
const { TLabel: ATLabel, TRule: ATRule, TDot: ATDot,
  Header: AHeader, Title: ATitle, SectionHead: ASection,
  Pill: APill, Row: ARow, Metric: AMetric, GhostBtn: AGhost,
  CTA: ACTA, Outline: AOutline, Segmented: ASeg, TickScale: ATick,
  Chip: AChip, Provider: AProv } = A;

// ════════════════════════════════════════════════════════════════════════════
// SONOS PLAYER DETAIL
// ════════════════════════════════════════════════════════════════════════════
function T3SonosDetail({ go }) {
  const [playing, setPlaying] = React.useState(true);
  const [shuf, setShuf] = React.useState(false);
  const [rep, setRep] = React.useState(false);
  const [progress, setProgress] = React.useState(0.42);
  const group = [
    { name: "Living Room",  model: "Sonos Beam",  vol: 38, primary: true },
    { name: "Kitchen",      model: "Sonos One",   vol: 22, primary: false },
    { name: "Family Room",  model: "Sonos Arc",   vol: 45, primary: false },
  ];
  return (
    <div style={{ background: aT.page, color: aT.ink, paddingBottom: 110 }}>
      <AHeader left="Living Room" right="SONOS" onBack={() => go("room", { roomId: "r1" })}/>

      <div style={{ padding: "22px 24px 8px" }}>
        <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
          {playing && <ATDot size={8}/>}
          <ATLabel>{playing ? "Playing · 3 rooms" : "Paused"}</ATLabel>
        </div>
        <div style={{ fontFamily: "'Inter Tight', sans-serif", fontSize: 42, fontWeight: 500,
          letterSpacing: -1.4, lineHeight: 1, marginTop: 8 }}>
          Sonos Beam
        </div>
      </div>

      {/* Album-art placeholder + track */}
      <div style={{ margin: "8px 24px 0", border: `1px solid ${aT.rule}`,
        background: aT.panel, padding: 18, display: "grid",
        gridTemplateColumns: "80px 1fr", gap: 16, alignItems: "center" }}>
        <div style={{
          width: 80, height: 80, background: aT.ink,
          display: "flex", alignItems: "center", justifyContent: "center",
          position: "relative",
        }}>
          <div style={{ width: 14, height: 14, borderRadius: "50%", background: aT.accent }}/>
          <div style={{ position: "absolute", inset: 8, border: `1px solid ${aT.accent}`, opacity: 0.25 }}/>
        </div>
        <div style={{ minWidth: 0 }}>
          <ATLabel>Now playing</ATLabel>
          <div style={{ fontFamily: "'Inter Tight', sans-serif", fontSize: 18, fontWeight: 500,
            marginTop: 2, letterSpacing: -0.3, whiteSpace: "nowrap",
            overflow: "hidden", textOverflow: "ellipsis" }}>
            Tell 'Em
          </div>
          <div style={{ fontSize: 12, color: aT.sub, marginTop: 2 }}>Sleigh Bells · Treats · 2010</div>
        </div>
      </div>

      {/* Progress */}
      <div style={{ padding: "16px 24px 4px" }}>
        <div style={{ position: "relative", height: 3, background: aT.rule }}>
          <div style={{ position: "absolute", inset: 0, width: `${progress * 100}%`, background: aT.ink }}/>
        </div>
        <div style={{ display: "flex", justifyContent: "space-between", marginTop: 6 }}>
          <ATLabel className="tnum">1 : 34</ATLabel>
          <ATLabel className="tnum">3 : 42</ATLabel>
        </div>
      </div>

      {/* Transport */}
      <div style={{ padding: "16px 24px 22px", display: "flex",
        justifyContent: "space-between", alignItems: "center" }}>
        <button onClick={() => setShuf(v => !v)} style={{ all: "unset", cursor: "pointer" }}>
          <GlyBy name="shuffle" size={18} stroke={shuf ? aT.accent : aT.sub} sw={1.5}/>
        </button>
        <button style={{ all: "unset", cursor: "pointer",
          width: 52, height: 52, border: `1px solid ${aT.rule}`, borderRadius: "50%",
          display: "flex", alignItems: "center", justifyContent: "center" }}>
          <GlyBy name="skipBack" size={18} stroke={aT.ink} sw={1.5} fill={aT.ink}/>
        </button>
        <button onClick={() => setPlaying(v => !v)} style={{ all: "unset", cursor: "pointer",
          width: 72, height: 72, borderRadius: "50%", background: aT.accent,
          display: "flex", alignItems: "center", justifyContent: "center" }}>
          <GlyBy name={playing ? "pause" : "play"} size={24} stroke="#fff" sw={1.6} fill="#fff"/>
        </button>
        <button style={{ all: "unset", cursor: "pointer",
          width: 52, height: 52, border: `1px solid ${aT.rule}`, borderRadius: "50%",
          display: "flex", alignItems: "center", justifyContent: "center" }}>
          <GlyBy name="next" size={18} stroke={aT.ink} sw={1.5} fill={aT.ink}/>
        </button>
        <button onClick={() => setRep(v => !v)} style={{ all: "unset", cursor: "pointer" }}>
          <GlyBy name="repeat" size={18} stroke={rep ? aT.accent : aT.sub} sw={1.5}/>
        </button>
      </div>

      <ATRule/>
      <ASection title="Grouped rooms" trailing={`${String(group.length).padStart(2, "0")} · TAP TO UNGROUP`}/>

      {group.map((g, i) => (
        <div key={g.name} style={{
          display: "grid", gridTemplateColumns: "28px 1fr auto",
          gap: 12, padding: "14px 24px", alignItems: "center",
          borderTop: `1px solid ${aT.rule}`,
          borderBottom: i === group.length - 1 ? `1px solid ${aT.rule}` : "none",
        }}>
          <GlyBy name="speaker" size={18} stroke={aT.ink} sw={1.4}/>
          <div>
            <div style={{ fontSize: 14, fontWeight: 500, display: "flex", alignItems: "center", gap: 8 }}>
              {g.name}
              {g.primary && <GlyBy name="crown" size={12} stroke={aT.accent} sw={1.6}/>}
            </div>
            <div style={{ fontSize: 11, color: aT.sub, marginTop: 2,
              fontFamily: "'IBM Plex Mono', monospace", letterSpacing: 0.8 }}>
              {g.model.toUpperCase()} · VOL {g.vol}
            </div>
          </div>
          <div style={{ width: 70 }}>
            <div style={{ position: "relative", height: 2, background: aT.rule }}>
              <div style={{ position: "absolute", inset: 0,
                width: `${g.vol}%`, background: aT.ink }}/>
            </div>
          </div>
        </div>
      ))}

      <div style={{ padding: "20px 24px", display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10 }}>
        <AOutline label="Group more" icon="plus"/>
        <AOutline label="Sources" icon="music"/>
      </div>
    </div>
  );
}

// ════════════════════════════════════════════════════════════════════════════
// SMOKE ALARM DETAIL  (all-clear state; alert variant is a separate full-screen)
// ════════════════════════════════════════════════════════════════════════════
function T3SmokeDetail({ go }) {
  const events = [
    { time: "06 : 12", date: "TODAY",     label: "Self-test passed", sub: "Auto · nightly routine" },
    { time: "14 : 04", date: "MON 14 APR", label: "Battery ok",       sub: "96% · no action" },
    { time: "03 : 44", date: "FRI 11 APR", label: "Smoke cleared",     sub: "Cooking · 4min event" },
    { time: "09 : 02", date: "WED 09 APR", label: "Firmware 3.2.1",    sub: "Installed successfully" },
  ];
  return (
    <div style={{ background: aT.page, color: aT.ink, paddingBottom: 110 }}>
      <AHeader left="Living Room" right="NEST PROTECT" onBack={() => go("room", { roomId: "r1" })}/>

      {/* Shield card — all clear */}
      <div style={{ padding: "22px 24px 8px" }}>
        <ATitle
          eyebrow="Secured" dot
          title="Nest Protect"
          sub="All systems nominal. Next self-test tonight at 03:00."
        />
      </div>

      {/* Large status panel */}
      <div style={{ margin: "0 24px 22px", padding: "28px 20px",
        border: `1px solid ${aT.rule}`, background: aT.panel,
        display: "grid", gridTemplateColumns: "72px 1fr", gap: 20, alignItems: "center" }}>
        <div style={{ width: 72, height: 72, border: `1.5px solid ${aT.ink}`, borderRadius: "50%",
          display: "flex", alignItems: "center", justifyContent: "center" }}>
          <GlyBy name="shield" size={36} stroke={aT.ink} sw={1.4}/>
        </div>
        <div>
          <div style={{ fontFamily: "'Inter Tight', sans-serif", fontSize: 26,
            fontWeight: 500, letterSpacing: -0.6 }}>All clear</div>
          <div style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 10,
            letterSpacing: 1.4, textTransform: "uppercase", color: aT.sub, marginTop: 6 }}>
            14 DAYS · ZERO EVENTS
          </div>
        </div>
      </div>

      <ATRule/>

      {/* Readings */}
      <div style={{ padding: "18px 24px", display: "grid",
        gridTemplateColumns: "1fr 1fr 1fr 1fr", gap: 14 }}>
        <AMetric label="Smoke" value="0" />
        <AMetric label="CO" value="0" />
        <AMetric label="Battery" value="96%" />
        <AMetric label="Humid." value="44%" />
      </div>

      <ATRule/>

      {/* Actions */}
      <div style={{ padding: "18px 24px 22px", display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10 }}>
        <AOutline label="Self-test" icon="check"/>
        <AOutline label="Simulate" icon="triangle" color={aT.sub} textColor={aT.sub}/>
      </div>

      <ATRule/>
      <ASection title="Event log" trailing="LAST 30 DAYS"/>
      {events.map((e, i) => (
        <div key={i} style={{
          display: "grid", gridTemplateColumns: "72px 1fr",
          gap: 14, padding: "14px 24px", alignItems: "start",
          borderTop: `1px solid ${aT.rule}`,
          borderBottom: i === events.length - 1 ? `1px solid ${aT.rule}` : "none",
        }}>
          <div>
            <span className="tnum" style={{ fontFamily: "'IBM Plex Mono', monospace",
              fontSize: 11, color: aT.ink, letterSpacing: 1, fontWeight: 500 }}>{e.time}</span>
            <div style={{ fontFamily: "'IBM Plex Mono', monospace",
              fontSize: 9, color: aT.sub, letterSpacing: 1, marginTop: 2 }}>{e.date}</div>
          </div>
          <div>
            <div style={{ fontSize: 14, fontWeight: 500, letterSpacing: -0.2 }}>{e.label}</div>
            <div style={{ fontSize: 11, color: aT.sub, marginTop: 2 }}>{e.sub}</div>
          </div>
        </div>
      ))}
    </div>
  );
}

// ════════════════════════════════════════════════════════════════════════════
// SAMSUNG FRAME TV DETAIL
// ════════════════════════════════════════════════════════════════════════════
function T3FrameTvDetail({ go }) {
  const [src, setSrc] = React.useState("art");
  const [bright, setBright] = React.useState(72);
  const [warm, setWarm] = React.useState(2);
  const sources = [
    ["art",   "Art Mode", "ON"],
    ["hdmi1", "HDMI 1",   "Xbox"],
    ["hdmi2", "HDMI 2",   "Apple TV"],
    ["air",   "AirPlay",  "Ready"],
  ];
  return (
    <div style={{ background: aT.page, color: aT.ink, paddingBottom: 110 }}>
      <AHeader left="Family Room" right="SAMSUNG" onBack={() => go("room", { roomId: "r5" })}/>

      <div style={{ padding: "22px 24px 8px" }}>
        <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
          <ATDot size={8}/>
          <ATLabel>Art mode · "Piet Mondrian — 1921"</ATLabel>
        </div>
        <div style={{ fontFamily: "'Inter Tight', sans-serif", fontSize: 42, fontWeight: 500,
          letterSpacing: -1.4, lineHeight: 1, marginTop: 8 }}>
          The Frame
        </div>
      </div>

      {/* TV viewport placeholder — 16 : 9, art piece composed from primitives */}
      <div style={{ margin: "6px 24px 18px", aspectRatio: "16 / 9",
        background: aT.panel, border: `1px solid ${aT.ink}`,
        position: "relative", overflow: "hidden", padding: 4 }}>
        <div style={{ width: "100%", height: "100%", background: "#e8e5dc",
          border: `1px solid ${aT.ink}`, position: "relative" }}>
          {/* Mondrian-ish composition rendered w/ CSS */}
          <div style={{ position: "absolute", left: 0, top: 0, width: "28%", height: "58%", background: "#e7591a" }}/>
          <div style={{ position: "absolute", left: 0, top: "58%", width: "28%", height: "42%", background: "#f2f1ed", borderTop: `3px solid ${aT.ink}`}}/>
          <div style={{ position: "absolute", left: "28%", top: 0, width: "44%", height: "38%", background: "#f2f1ed", borderLeft: `3px solid ${aT.ink}`, borderBottom: `3px solid ${aT.ink}` }}/>
          <div style={{ position: "absolute", left: "28%", top: "38%", width: "44%", height: "62%", background: "#f5d300", borderLeft: `3px solid ${aT.ink}` }}/>
          <div style={{ position: "absolute", left: "72%", top: 0, width: "28%", height: "100%", background: "#1a3aa8", borderLeft: `3px solid ${aT.ink}` }}/>
          {/* status overlay */}
          <div style={{ position: "absolute", bottom: 10, left: 10, right: 10,
            display: "flex", justifyContent: "space-between", fontFamily: "'IBM Plex Mono', monospace",
            fontSize: 9, color: aT.page, letterSpacing: 1.2, textTransform: "uppercase",
            textShadow: "0 1px 2px rgba(0,0,0,.35)" }}>
            <span>ART · 4K · AMBIENT</span>
            <span>FRAME 2022 · 55"</span>
          </div>
        </div>
      </div>

      {/* Sources */}
      <ASection title="Source" trailing="04 AVAILABLE"/>
      <div style={{ padding: "0 24px 16px", display: "grid",
        gridTemplateColumns: "1fr 1fr", gap: 6 }}>
        {sources.map(([k, label, sub]) => {
          const a = src === k;
          return (
            <button key={k} onClick={() => setSrc(k)} style={{
              all: "unset", cursor: "pointer", padding: "14px 16px",
              border: `1px solid ${a ? aT.ink : aT.rule}`,
              background: a ? aT.ink : aT.panel,
              color: a ? aT.page : aT.ink,
              display: "flex", flexDirection: "column", gap: 4,
            }}>
              <div style={{ fontSize: 14, fontWeight: 500, letterSpacing: -0.2 }}>{label}</div>
              <div style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 9,
                letterSpacing: 1, color: a ? "rgba(255,255,255,0.7)" : aT.sub }}>
                {sub.toUpperCase()}
              </div>
            </button>
          );
        })}
      </div>

      <ATRule/>

      {/* Remote — big circular buttons */}
      <ASection title="Remote"/>
      <div style={{ padding: "0 24px 18px", display: "grid",
        gridTemplateColumns: "repeat(4, 1fr)", gap: 10 }}>
        {[
          ["power",  "power",  aT.accent, true],
          ["volDn",  "vol −",  aT.ink,    false],
          ["volUp",  "vol +",  aT.ink,    false],
          ["volMute","mute",   aT.sub,    false],
        ].map(([gl, label, color, filled]) => (
          <button key={label} style={{ all: "unset", cursor: "pointer",
            display: "flex", flexDirection: "column", alignItems: "center", gap: 6 }}>
            <div style={{ width: 54, height: 54, borderRadius: "50%",
              background: filled ? color : aT.panel,
              border: `1px solid ${filled ? color : aT.rule}`,
              display: "flex", alignItems: "center", justifyContent: "center" }}>
              <GlyBy name={gl} size={18} stroke={filled ? "#fff" : color} sw={1.5}/>
            </div>
            <div style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 9,
              color: aT.sub, letterSpacing: 1, textTransform: "uppercase" }}>{label}</div>
          </button>
        ))}
      </div>

      <ATRule/>

      {/* Brightness + tone */}
      <ASection title="Picture" trailing="ART MODE"/>
      <div style={{ padding: "0 24px 18px" }}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline" }}>
          <ATLabel>Brightness</ATLabel>
          <span className="tnum" style={{ fontFamily: "'Inter Tight', sans-serif",
            fontSize: 18, fontWeight: 500 }}>{bright}</span>
        </div>
        <div style={{ marginTop: 10 }}><ATick value={bright}/></div>
      </div>
      <div style={{ padding: "0 24px 22px" }}>
        <div style={{ marginBottom: 10 }}><ATLabel>Color tone</ATLabel></div>
        <ASeg value={warm}
          options={[[0, "Cool", "5500K"], [1, "Neutral", "4000K"], [2, "Warm", "3000K"], [3, "Warmer", "2700K"]]}
          onChange={setWarm}/>
      </div>
    </div>
  );
}

// ════════════════════════════════════════════════════════════════════════════
// SECURITY CAMERA DETAIL
// ════════════════════════════════════════════════════════════════════════════
function T3CameraDetail({ go }) {
  const [motion, setMotion] = React.useState(true);
  const [night, setNight]   = React.useState(true);
  const [notif, setNotif]   = React.useState(true);
  const [spkr,  setSpkr]    = React.useState(false);

  const activity = [
    { time: "09 : 12", label: "Motion · Front porch",   dur: "18s", type: "motion"  },
    { time: "08 : 34", label: "Package delivered",       dur: "4s",  type: "package" },
    { time: "07 : 58", label: "Motion · Driveway",       dur: "42s", type: "motion"  },
    { time: "23 : 04", label: "Person detected",         dur: "1m 12s", type: "person" },
    { time: "22 : 11", label: "Motion · Walkway",        dur: "6s",  type: "motion"  },
  ];

  return (
    <div style={{ background: aT.page, color: aT.ink, paddingBottom: 110 }}>
      <AHeader left="Family Room" right="HOMEKIT SEC" onBack={() => go("room", { roomId: "r5" })}/>

      <div style={{ padding: "22px 24px 8px" }}>
        <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
          <ATDot size={8}/>
          <ATLabel>Live · Armed · 1080p</ATLabel>
        </div>
        <div style={{ fontFamily: "'Inter Tight', sans-serif", fontSize: 42, fontWeight: 500,
          letterSpacing: -1.4, lineHeight: 1, marginTop: 8 }}>
          Family Cam
        </div>
      </div>

      {/* Live feed mock — dark panel w/ camera noise, LIVE badge */}
      <div style={{ margin: "6px 24px 18px", aspectRatio: "16/9",
        background: "#0e0e0d", position: "relative", overflow: "hidden" }}>
        {/* "scan lines" to suggest live video */}
        <div style={{ position: "absolute", inset: 0,
          background: "repeating-linear-gradient(0deg, rgba(255,255,255,0.02) 0, rgba(255,255,255,0.02) 2px, transparent 2px, transparent 4px)" }}/>
        {/* vignette of a scene */}
        <div style={{ position: "absolute", inset: 0,
          background: "radial-gradient(ellipse at 50% 80%, rgba(231,89,26,0.08), transparent 60%)" }}/>
        {/* silhouette shapes */}
        <div style={{ position: "absolute", left: "12%", bottom: 0, width: "32%", height: "62%",
          background: "linear-gradient(180deg, transparent, rgba(255,255,255,0.02))",
          borderTop: "1px solid rgba(255,255,255,0.08)" }}/>
        <div style={{ position: "absolute", right: "10%", bottom: 0, width: "22%", height: "40%",
          background: "rgba(255,255,255,0.03)", borderTop: "1px solid rgba(255,255,255,0.08)" }}/>
        {/* HUD */}
        <div style={{ position: "absolute", top: 10, left: 10, display: "flex", gap: 6 }}>
          <div style={{ padding: "3px 8px", background: "#ff3b30", color: "#fff",
            fontFamily: "'IBM Plex Mono', monospace", fontSize: 9, fontWeight: 600,
            letterSpacing: 1.4 }}>
            ● LIVE
          </div>
          <div style={{ padding: "3px 8px", background: "rgba(0,0,0,0.5)", color: "#fff",
            fontFamily: "'IBM Plex Mono', monospace", fontSize: 9, fontWeight: 500,
            letterSpacing: 1.4, border: "1px solid rgba(255,255,255,0.25)" }}>
            1080 P · 24 FPS
          </div>
        </div>
        <div style={{ position: "absolute", bottom: 10, right: 10, fontFamily: "'IBM Plex Mono', monospace",
          fontSize: 9, color: "rgba(255,255,255,0.65)", letterSpacing: 1 }}>
          FRI · 09 : 41 : 08
        </div>
        {/* timeline ticks */}
        <div style={{ position: "absolute", bottom: 0, left: 0, right: 0, height: 3, display: "flex" }}>
          {Array.from({ length: 40 }).map((_, i) => (
            <div key={i} style={{ flex: 1,
              background: i === 28 ? aT.accent : (i % 4 === 0 ? "rgba(255,255,255,0.25)" : "rgba(255,255,255,0.1)") }}/>
          ))}
        </div>
      </div>

      {/* Quick actions */}
      <div style={{ padding: "0 24px 18px", display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: 8 }}>
        {[
          ["camera", "Snap", true],
          ["mic",    "Talk", true],
          ["ping",   "Rec",  false],
          ["siren",  "Siren", false],
        ].map(([gl, l, enabled]) => (
          <button key={l} style={{ all: "unset", cursor: enabled ? "pointer" : "not-allowed",
            padding: "14px 6px", border: `1px solid ${enabled ? aT.ink : aT.rule}`,
            background: aT.panel, opacity: enabled ? 1 : 0.4,
            display: "flex", flexDirection: "column", alignItems: "center", gap: 6 }}>
            <GlyBy name={gl} size={18} stroke={aT.ink} sw={1.4}/>
            <span style={{ fontSize: 11, fontWeight: 500 }}>{l}</span>
          </button>
        ))}
      </div>

      <ATRule/>
      <ASection title="Settings"/>
      {[
        ["Motion detection", motion, setMotion, "Records when triggered"],
        ["Night vision",     night,  setNight,  "Auto, low-light IR"],
        ["Notifications",    notif,  setNotif,  "Person, package, motion"],
        ["Two-way audio",    spkr,   setSpkr,   "Tap-to-talk only"],
      ].map(([label, on, set, sub], i, arr) => (
        <div key={label} style={{
          display: "grid", gridTemplateColumns: "1fr auto", gap: 14,
          padding: "14px 24px", alignItems: "center",
          borderTop: `1px solid ${aT.rule}`,
          borderBottom: i === arr.length - 1 ? `1px solid ${aT.rule}` : "none",
        }}>
          <div>
            <div style={{ fontSize: 14, fontWeight: 500 }}>{label}</div>
            <div style={{ fontSize: 11, color: aT.sub, marginTop: 2 }}>{sub}</div>
          </div>
          <APill on={on} onClick={() => set(v => !v)}/>
        </div>
      ))}

      <ASection title="Recent activity" trailing="LAST 24 HRS"/>
      {activity.map((e, i) => (
        <div key={i} style={{
          display: "grid", gridTemplateColumns: "60px 1fr auto",
          gap: 12, padding: "14px 24px", alignItems: "center",
          borderTop: `1px solid ${aT.rule}`,
          borderBottom: i === activity.length - 1 ? `1px solid ${aT.rule}` : "none",
        }}>
          <span className="tnum" style={{ fontFamily: "'IBM Plex Mono', monospace",
            fontSize: 11, color: aT.sub, letterSpacing: 1 }}>{e.time}</span>
          <div>
            <div style={{ fontSize: 14, fontWeight: 500 }}>{e.label}</div>
            <div style={{ fontSize: 11, color: aT.sub, marginTop: 2,
              fontFamily: "'IBM Plex Mono', monospace", letterSpacing: 0.8 }}>
              {e.type.toUpperCase()} · {e.dur}
            </div>
          </div>
          <GlyBy name="play" size={14} stroke={aT.ink} sw={1.4} fill={aT.ink}/>
        </div>
      ))}
    </div>
  );
}

// ════════════════════════════════════════════════════════════════════════════
// DEVICE GROUP DETAIL  (generic group — bonded speakers, light group, etc.)
// ════════════════════════════════════════════════════════════════════════════
function T3GroupDetail({ go }) {
  const members = [
    { name: "Sonos Beam",   loc: "Living Room", role: "Primary", vol: 38, on: true  },
    { name: "Sonos One · L", loc: "Living Room", role: "Stereo L", vol: 36, on: true  },
    { name: "Sonos One · R", loc: "Living Room", role: "Stereo R", vol: 36, on: true  },
    { name: "Sonos Sub",    loc: "Living Room", role: "Sub",     vol: 48, on: true  },
    { name: "Sonos Arc",    loc: "Family Room", role: "Linked",  vol: 45, on: true  },
    { name: "Sonos One",    loc: "Kitchen",     role: "Linked",  vol: 22, on: false },
  ];
  const [vol, setVol] = React.useState(38);
  return (
    <div style={{ background: aT.page, color: aT.ink, paddingBottom: 110 }}>
      <AHeader left="Devices" right="6 MEMBERS" onBack={() => go("devices")}/>

      <ATitle
        eyebrow="Bonded group · Sonos"
        dot
        title="Whole-home audio"
        sub="One set of controls. Volume, source and mute cascade to all members."
      />

      <ATRule/>

      {/* Group volume — full-width scale */}
      <div style={{ padding: "20px 24px" }}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline" }}>
          <ATLabel>Group volume</ATLabel>
          <span className="tnum" style={{ fontFamily: "'Inter Tight', sans-serif",
            fontSize: 24, fontWeight: 500, letterSpacing: -0.4 }}>{vol}</span>
        </div>
        <div style={{ marginTop: 12 }}><ATick value={vol}/></div>
        <div style={{ display: "flex", justifyContent: "space-between", marginTop: 6 }}>
          <ATLabel>0</ATLabel><ATLabel>50</ATLabel><ATLabel>100</ATLabel>
        </div>
      </div>

      <ATRule/>

      {/* Now playing mini */}
      <div style={{ margin: "16px 24px", border: `1px solid ${aT.rule}`,
        background: aT.panel, padding: 14, display: "grid",
        gridTemplateColumns: "44px 1fr auto", gap: 12, alignItems: "center" }}>
        <div style={{ width: 44, height: 44, background: aT.ink,
          display: "flex", alignItems: "center", justifyContent: "center" }}>
          <ATDot size={8} color={aT.accent}/>
        </div>
        <div style={{ minWidth: 0 }}>
          <div style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 9,
            color: aT.sub, letterSpacing: 1, textTransform: "uppercase" }}>Now playing</div>
          <div style={{ fontSize: 14, fontWeight: 500, marginTop: 2,
            whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>
            Tell 'Em — Sleigh Bells
          </div>
        </div>
        <button style={{ all: "unset", cursor: "pointer",
          width: 40, height: 40, borderRadius: "50%", background: aT.accent,
          display: "flex", alignItems: "center", justifyContent: "center" }}>
          <GlyBy name="pause" size={14} stroke="#fff" sw={1.6}/>
        </button>
      </div>

      <ATRule/>
      <ASection title="Members" trailing={`${String(members.length).padStart(2, "0")}`}/>

      {members.map((m, i) => (
        <div key={m.name} style={{
          display: "grid", gridTemplateColumns: "28px 1fr auto 40px",
          gap: 12, padding: "14px 24px", alignItems: "center",
          borderTop: `1px solid ${aT.rule}`,
          borderBottom: i === members.length - 1 ? `1px solid ${aT.rule}` : "none",
        }}>
          <GlyBy name="speaker" size={18} stroke={aT.ink} sw={1.4}/>
          <div>
            <div style={{ fontSize: 14, fontWeight: 500, display: "flex", alignItems: "center", gap: 8 }}>
              {m.name}
              {m.role === "Primary" && <GlyBy name="crown" size={12} stroke={aT.accent} sw={1.6}/>}
            </div>
            <div style={{ fontSize: 11, color: aT.sub, marginTop: 2,
              fontFamily: "'IBM Plex Mono', monospace", letterSpacing: 0.8 }}>
              {m.loc.toUpperCase()} · {m.role.toUpperCase()}
            </div>
          </div>
          <span className="tnum" style={{ fontFamily: "'IBM Plex Mono', monospace",
            fontSize: 11, color: m.on ? aT.ink : aT.sub, letterSpacing: 1 }}>
            {m.on ? `VOL ${m.vol}` : "OFFLINE"}
          </span>
          <APill on={m.on}/>
        </div>
      ))}

      <div style={{ padding: "20px 24px", display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10 }}>
        <AOutline label="Add member" icon="plus"/>
        <AOutline label="Ungroup" icon="xCircle" color="#b32712" textColor="#b32712"/>
      </div>
    </div>
  );
}

window.T3Batches = window.T3Batches || {};
window.T3Batches.DeviceDetail = {
  Sonos: T3SonosDetail,
  Smoke: T3SmokeDetail,
  FrameTv: T3FrameTvDetail,
  Camera: T3CameraDetail,
  Group: T3GroupDetail,
};
