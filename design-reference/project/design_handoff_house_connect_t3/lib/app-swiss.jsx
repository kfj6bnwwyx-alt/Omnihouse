// T3 review app — showcases all screens, navigable via bottom nav and on-phone tabs.

function Phone({ route, nav }) {
  const T = T3Theme, { screen, params } = route;
  let content;
  if (screen === "splash")     content = <T3Loader/>;
  else if (screen === "home")  content = <T.Home go={nav} scenesStyle="t3"/>;
  else if (screen === "rooms") content = <T.Rooms go={nav}/>;
  else if (screen === "room")  content = <T.Room go={nav} roomId={params.roomId}/>;
  else if (screen === "devices") content = <T.Devices go={nav}/>;
  else if (screen === "device")  content = <T.Device go={nav} deviceId={params.deviceId}/>;
  else if (screen === "thermo")  content = <T.Thermo go={nav}/>;
  else if (screen === "settings")content = <T.Settings go={nav}/>;
  else if (screen === "activity")content = <T.Activity go={nav}/>;
  else if (screen === "energy") content = <T.Energy go={nav}/>;
  else if (screen === "addDevice") content = <T.AddDevice go={nav}/>;
  else if (screen === "scene") content = <T.SceneEdit go={nav} sceneId={params.sceneId}/>;
  const showTabs = screen !== "splash";
  return (
    <HCPhone dark={T.tokens.dark} bg={T.tokens.page} frameBg={T.tokens.frame}>
      {content}
      {showTabs && <T.Tabs current={screen} go={nav}/>}
    </HCPhone>
  );
}

function Caption({ label, title, desc }) {
  return (
    <div style={{ maxWidth: 390, marginBottom: 18 }}>
      <div style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 10, fontWeight: 500,
        color: "#e7591a", letterSpacing: 2, textTransform: "uppercase",
        borderTop: "1px solid #111", paddingTop: 8, marginBottom: 6 }}>{label}</div>
      <div style={{ fontFamily: "'Inter Tight', sans-serif", fontSize: 22, fontWeight: 600,
        letterSpacing: -0.6, lineHeight: 1.05, marginBottom: 6 }}>{title}</div>
      <div style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 10, lineHeight: 1.6,
        color: "#5a5a55", textTransform: "uppercase", letterSpacing: 0.6 }}>{desc}</div>
    </div>
  );
}

function Cell({ label, title, desc, initialRoute }) {
  const [route, setRoute] = React.useState(initialRoute);
  const nav = (screen, params = {}) => setRoute({ screen, params });
  return (
    <div style={{ display: "flex", flexDirection: "column", alignItems: "flex-start" }}>
      <Caption label={label} title={title} desc={desc}/>
      <Phone route={route} nav={nav}/>
    </div>
  );
}

// Groups of phones laid out in rows.
const GROUPS = [
  {
    heading: "01 · Core flow",
    kicker: "SPLASH → HOME → ROOM → DEVICE",
    cells: [
      ["Splash · loader","First-launch loading",     "Pulsing orange dot, fade-up wordmark, looping 10-bar.", { screen: "splash", params: {} }],
      ["Home",         "Greeting + scenes + rooms",  "Weather / inside / energy, chip scenes, room list.", { screen: "home",   params: {} }],
      ["Rooms tab",    "Every room at a glance",      "2-col grid, hairline dividers, numeric index.",       { screen: "rooms",  params: {} }],
      ["Living Room",  "Room detail + devices",       "Pill toggles, provider caption, tap to open device.", { screen: "room",   params: { roomId: "r1" } }],
    ],
  },
  {
    heading: "02 · Device detail",
    kicker: "THERMOSTAT · LIGHT · LOCK · SPEAKER",
    cells: [
      ["Thermostat",   "Climate control",            "168px number, tick scale, mode segmented, schedule.", { screen: "thermo", params: {} }],
      ["Light",        "Dimmable bulb",              "Brightness scale, color temp segmented.",             { screen: "device", params: { deviceId: "d1" } }],
      ["Lock",         "Entry door",                 "Tap-to-toggle round, battery, recent access log.",    { screen: "device", params: { deviceId: "d19" } }],
      ["Speaker",      "Sonos transport",            "Now-playing card, volume scale, group-with rooms.",   { screen: "device", params: { deviceId: "d4" } }],
    ],
  },
  {
    heading: "03 · Everything else",
    kicker: "DEVICES · SETTINGS · SCENE · ACTIVITY · ENERGY · ADD",
    cells: [
      ["Devices tab",  "All devices, filterable",    "Chip filter, provider label at right, inline pill.",  { screen: "devices", params: {} }],
      ["Settings tab", "Account + connections",      "Grouped list · hairlines · tiny version line.",        { screen: "settings", params: {} }],
      ["Scene edit",   "Morning scene",              "Trigger segmented, time, 7 actions, add.",             { screen: "scene",   params: { sceneId: "s1" } }],
      ["Activity",     "Today's events",             "Mono time gutter, icon, label, sub.",                  { screen: "activity",params: {} }],
      ["Energy",       "Daily usage",                "Giant kWh, hourly bars, category bars.",               { screen: "energy",  params: {} }],
      ["Add device",   "Pair flow",                  "Provider list, discovered-nearby with Pair.",          { screen: "addDevice", params: {} }],
    ],
  },
];

function App() {
  return (
    <div style={{ minHeight: "100vh", background: "#ededea", padding: "44px 40px 80px" }}>
      <div style={{ maxWidth: 1400, margin: "0 auto 48px" }}>
        <div style={{
          fontFamily: "'IBM Plex Mono', monospace", fontSize: 11, fontWeight: 500,
          letterSpacing: 2, textTransform: "uppercase", color: "#e7591a",
          borderTop: "1px solid #111", paddingTop: 10, marginBottom: 10,
        }}>
          House Connect · T3 direction · Handoff v1.0
        </div>
        <div style={{ display: "grid", gridTemplateColumns: "1.2fr 1fr", gap: 40, alignItems: "flex-end" }}>
          <div style={{ fontFamily: "'Inter Tight', sans-serif", fontSize: 64, fontWeight: 600,
            letterSpacing: -2.6, lineHeight: 0.95, color: "#111" }}>
            Fourteen screens,<br/>one quiet system<span style={{ color: "#e7591a" }}>.</span>
          </div>
          <div style={{ maxWidth: 440,
            fontFamily: "'IBM Plex Mono', monospace", fontSize: 11, lineHeight: 1.7,
            color: "#5a5a55", textTransform: "uppercase", letterSpacing: 0.7 }}>
            Every phone is interactive — tap the home-indicator tab bar and
            list rows to navigate within its flow. Hand this bundle to Claude
            Code along with the README in <span style={{ color: "#111" }}>design_handoff_house_connect_t3/</span>
            to rebuild in SwiftUI or the target stack.
          </div>
        </div>
      </div>

      {/* App icon section */}
      <div style={{ maxWidth: 1400, margin: "0 auto 56px" }}>
        <div style={{
          borderTop: "1px solid #111", paddingTop: 10, marginBottom: 24,
          display: "flex", justifyContent: "space-between", alignItems: "baseline",
        }}>
          <div style={{ fontFamily: "'Inter Tight', sans-serif", fontSize: 28,
            fontWeight: 600, letterSpacing: -0.8 }}>00 · App icon</div>
          <div style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 11,
            letterSpacing: 2, textTransform: "uppercase", color: "#5a5a55" }}>
            IOS · 1024 MASTER · SQUIRCLE 22.5%
          </div>
        </div>
        <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(180px, max-content))",
          gap: 36, alignItems: "end" }}>
          {[180, 120, 80, 60, 40].map(s => (
            <div key={s} style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 10 }}>
              <T3AppIcon size={s}/>
              <div style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 10,
                letterSpacing: 1.4, textTransform: "uppercase", color: "#86847e" }}>
                {s}pt
              </div>
            </div>
          ))}
          <div style={{ maxWidth: 320, marginLeft: 24,
            fontFamily: "'IBM Plex Mono', monospace", fontSize: 11, lineHeight: 1.7,
            color: "#5a5a55", textTransform: "uppercase", letterSpacing: 0.7 }}>
            Concentric signal arcs radiating from a Braun-orange source —
            reads as a radio dial, a room plan, and a hearth. Hairline grid
            stays faint at small sizes; the dot carries recognition down to
            40pt.
          </div>
        </div>
      </div>

      {GROUPS.map((g, gi) => (
        <div key={g.heading} style={{ maxWidth: 1400, margin: "0 auto 56px" }}>
          <div style={{
            borderTop: "1px solid #111", paddingTop: 10, marginBottom: 24,
            display: "flex", justifyContent: "space-between", alignItems: "baseline",
          }}>
            <div style={{ fontFamily: "'Inter Tight', sans-serif", fontSize: 28,
              fontWeight: 600, letterSpacing: -0.8 }}>{g.heading}</div>
            <div style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 11,
              letterSpacing: 2, textTransform: "uppercase", color: "#5a5a55" }}>
              {g.kicker}
            </div>
          </div>
          <div style={{
            display: "grid",
            gridTemplateColumns: "repeat(auto-fit, minmax(390px, 1fr))",
            gap: 40, justifyContent: "start",
          }}>
            {g.cells.map(([label, title, desc, initial]) => (
              <Cell key={label} label={label} title={title} desc={desc} initialRoute={initial}/>
            ))}
          </div>
        </div>
      ))}

      <div style={{ maxWidth: 1400, margin: "0 auto", paddingTop: 24, borderTop: "1px solid #d9d7d0" }}>
        <div style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 10,
          letterSpacing: 1.6, textTransform: "uppercase", color: "#86847e" }}>
          End of handoff · House Connect · T3 · {new Date().getFullYear()}
        </div>
      </div>
    </div>
  );
}

ReactDOM.createRoot(document.getElementById("root")).render(<App/>);
