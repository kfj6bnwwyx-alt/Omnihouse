// App shell — three phones side by side, each running its own theme with
// independent screen state. Cross-column sync on the tab chip row so you
// can watch the same screen across all three treatments at once.

function Phone({ theme, screen, setScreen }) {
  const go = setScreen;
  const T = theme;
  let content;
  if (screen === "splash") content = <T.Splash/>;
  else if (screen === "home") content = <T.Home go={go}/>;
  else if (screen === "room") content = <T.Room go={go}/>;
  else if (screen === "thermo") content = <T.Thermo go={go}/>;
  // Persistent tab bar on non-splash screens
  const showTabs = screen !== "splash";
  return (
    <HCPhone dark={T.tokens.dark} bg={T.tokens.page} frameBg={T.tokens.frame}>
      {content}
      {showTabs && <T.Tabs current={screen} go={go}/>}
    </HCPhone>
  );
}

function App() {
  // Synced screen across all three phones — easier to compare.
  const [screen, setScreen] = React.useState("home");

  const columns = [
    { id: "paper", theme: PaperTheme, kicker: "DIRECTION 01",        title: "PAPER",
      lede: "EDITORIAL BRUTALIST · SERIF + MONO · CREAM + INK + OXBLOOD · HAIRLINES · NO SHADOWS" },
    { id: "block", theme: BlockTheme, kicker: "DIRECTION 02",        title: "BLOCK",
      lede: "NEO-BRUTALIST · ARCHIVO BLACK · 2PX INK BORDERS · OFFSET HARD SHADOWS · YELLOW + TOMATO" },
    { id: "grid",  theme: GridTheme,  kicker: "DIRECTION 03",        title: "GRID",
      lede: "TERMINAL / INDUSTRIAL · ALL-MONO · PHOSPHOR GREEN ON NEAR-BLACK · ASCII TABLES · STATUS LINES" },
  ];

  const screens = [
    { id: "splash", label: "Splash" },
    { id: "home",   label: "Home" },
    { id: "room",   label: "Room" },
    { id: "thermo", label: "Thermo" },
  ];

  return (
    <div style={{ minHeight: "100vh", background: "#e9e7e1", padding: "40px 32px 80px" }}>
      {/* Page header */}
      <div style={{ maxWidth: 1320, margin: "0 auto 40px" }}>
        <div style={{
          fontFamily: "'JetBrains Mono', monospace", fontSize: 11, fontWeight: 600,
          letterSpacing: 2.4, textTransform: "uppercase", color: "#7a1f1a",
          borderTop: "2px solid #111", paddingTop: 10, marginBottom: 8,
        }}>
          HOUSE CONNECT / IOS / DESIGN REVIEW № 01
        </div>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-end", gap: 40 }}>
          <div>
            <div style={{
              fontFamily: "'Archivo Black', sans-serif", fontSize: 64,
              letterSpacing: -2, textTransform: "uppercase", lineHeight: 0.9, color: "#111",
            }}>THREE WAYS TO<br/>GO BRUTALIST.</div>
          </div>
          <div style={{ maxWidth: 420,
            fontFamily: "'JetBrains Mono', monospace", fontSize: 11, lineHeight: 1.6,
            color: "#444", textTransform: "uppercase", letterSpacing: 0.8 }}>
            Current app is friendly + lavender. Below: three divergent brutalist
            treatments of splash → home → room → thermostat. Tap a screen chip under
            any phone to switch all three columns in lockstep. Glyphs are hand-built
            1.5px outlines. All copy rewritten factual / status-line.
          </div>
        </div>
      </div>

      {/* Columns */}
      <div style={{ display: "flex", gap: 40, justifyContent: "center", flexWrap: "wrap", alignItems: "flex-start" }}>
        {columns.map(c => (
          <HCColumn key={c.id}>
            <HCCaption kicker={c.kicker} title={c.title} lede={c.lede} accent={c.theme.tokens.accent || "#111"}/>
            <Phone theme={c.theme} screen={screen} setScreen={setScreen}/>
            <HCNavBar screens={screens} current={screen} setScreen={setScreen}
              accent={c.theme.tokens.accent || "#111"} ink="#111"/>
          </HCColumn>
        ))}
      </div>

      {/* Footer */}
      <div style={{ maxWidth: 1320, margin: "60px auto 0", borderTop: "2px solid #111", paddingTop: 12,
        display: "flex", justifyContent: "space-between",
        fontFamily: "'JetBrains Mono', monospace", fontSize: 10, letterSpacing: 1.6, textTransform: "uppercase", color: "#555" }}>
        <span>END OF REVIEW</span>
        <span>V1.0</span>
        <span>HOUSE CONNECT · 2026</span>
      </div>
    </div>
  );
}

ReactDOM.createRoot(document.getElementById("root")).render(<App/>);
