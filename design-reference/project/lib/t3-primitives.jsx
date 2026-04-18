// Shared T3 primitives for all extended screens.
// Re-exports the pieces defined in t3-theme.jsx via window.T3Primitives
// so any .jsx file loaded AFTER t3-theme can import them by destructuring.
//
// Usage inside a screen file:
//   const { TLabel, TRule, TDot, Header, Title, SectionHead, Pill, tokens } = window.T3Ext;

const _t = window.T3Primitives.tokens;
const _TLabel = window.T3Primitives.TLabel;
const _TRule  = window.T3Primitives.TRule;
const _TDot   = window.T3Primitives.TDot;

function Header({ left, right, onBack, rightNode }) {
  return (
    <div style={{ padding: "8px 24px 0", display: "flex", justifyContent: "space-between", alignItems: "center" }}>
      {onBack ? (
        <button onClick={onBack} style={{ all: "unset", cursor: "pointer",
          display: "flex", alignItems: "center", gap: 6 }}>
          <GlyBy name="back" size={14} stroke={_t.ink} sw={1.4}/>
          <_TLabel color={_t.ink}>{left}</_TLabel>
        </button>
      ) : <_TLabel>{left}</_TLabel>}
      {rightNode || <_TLabel>{right}</_TLabel>}
    </div>
  );
}

function Title({ eyebrow, dot, title, sub, dotColor }) {
  return (
    <div style={{ padding: "22px 24px 18px" }}>
      {eyebrow && (
        <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
          {dot && <_TDot size={8} color={dotColor}/>}
          <_TLabel>{eyebrow}</_TLabel>
        </div>
      )}
      <div style={{ fontFamily: "'Inter Tight', sans-serif", fontSize: 42, fontWeight: 500,
        letterSpacing: -1.4, lineHeight: 1, marginTop: eyebrow ? 8 : 0 }}>
        {title}
      </div>
      {sub && <div style={{ marginTop: 10, fontSize: 13, color: _t.sub }}>{sub}</div>}
    </div>
  );
}

function SectionHead({ title, trailing, size = 15 }) {
  return (
    <div style={{ padding: "18px 24px 8px", display: "flex", justifyContent: "space-between", alignItems: "baseline" }}>
      <div style={{ fontFamily: "'Inter Tight', sans-serif", fontSize: size, fontWeight: 500 }}>{title}</div>
      {trailing && <_TLabel>{trailing}</_TLabel>}
    </div>
  );
}

function Pill({ on, size = "sm", onClick, disabled }) {
  const w = size === "sm" ? 40 : 48, h = size === "sm" ? 22 : 26, k = size === "sm" ? 18 : 22;
  return (
    <div onClick={disabled ? undefined : onClick} style={{
      width: w, height: h, borderRadius: 999,
      background: disabled ? "#ebe9e3" : (on ? _t.ink : _t.rule),
      position: "relative", transition: "background 150ms",
      cursor: disabled ? "not-allowed" : (onClick ? "pointer" : "default"),
      opacity: disabled ? 0.6 : 1,
    }}>
      <div style={{
        position: "absolute", top: 2, left: on ? w - k - 2 : 2,
        width: k, height: k, borderRadius: "50%",
        background: on ? _t.accent : "#fff",
        transition: "left 150ms",
      }}/>
    </div>
  );
}

// Row — grid row used in lists.  children is <Gly/><Main/><Trailing/>.
function Row({ cols = "28px 1fr auto", last, onClick, children, padY = 14 }) {
  return (
    <div onClick={onClick} style={{
      display: "grid", gridTemplateColumns: cols, gap: 12,
      padding: `${padY}px 24px`, alignItems: "center",
      borderTop: `1px solid ${_t.rule}`,
      borderBottom: last ? `1px solid ${_t.rule}` : "none",
      cursor: onClick ? "pointer" : "default",
    }}>
      {children}
    </div>
  );
}

// Tiny two-line label/value cell for metric grids.
function Metric({ label, value, valueColor, mono }) {
  return (
    <div>
      <_TLabel>{label}</_TLabel>
      <div className="tnum" style={{
        fontFamily: mono ? "'IBM Plex Mono', monospace" : "'Inter Tight', sans-serif",
        fontSize: mono ? 16 : 22, fontWeight: mono ? 500 : 400,
        letterSpacing: mono ? 0 : -0.6, marginTop: 4,
        color: valueColor || _t.ink,
      }}>
        {value}
      </div>
    </div>
  );
}

// Ghost button — dashed border, tap to call an action.
function GhostBtn({ label, icon = "plus", onClick }) {
  return (
    <button onClick={onClick} style={{ all: "unset", cursor: "pointer",
      display: "flex", alignItems: "center", justifyContent: "center", gap: 8,
      width: "100%", padding: "14px", border: `1px dashed ${_t.sub}`,
      color: _t.sub, fontSize: 13 }}>
      {icon && <GlyBy name={icon} size={14} stroke={_t.sub} sw={1.4}/>}
      <span>{label}</span>
    </button>
  );
}

// Primary CTA — big filled button.
function CTA({ label, onClick, color, textColor = "#fff", icon }) {
  return (
    <button onClick={onClick} style={{ all: "unset", cursor: "pointer",
      display: "flex", alignItems: "center", justifyContent: "center", gap: 10,
      width: "100%", padding: "16px 0", background: color || _t.ink, color: textColor,
      fontSize: 14, fontWeight: 600, fontFamily: "'IBM Plex Mono', monospace",
      letterSpacing: 1.4, textTransform: "uppercase" }}>
      {icon && <GlyBy name={icon} size={14} stroke={textColor} sw={1.6}/>}
      <span>{label}</span>
    </button>
  );
}

// Outline button
function Outline({ label, onClick, color, textColor, icon }) {
  return (
    <button onClick={onClick} style={{ all: "unset", cursor: "pointer",
      display: "flex", alignItems: "center", justifyContent: "center", gap: 10,
      width: "100%", padding: "15px 0",
      border: `1px solid ${color || _t.ink}`, color: textColor || color || _t.ink,
      fontSize: 12, fontWeight: 600, fontFamily: "'IBM Plex Mono', monospace",
      letterSpacing: 1.4, textTransform: "uppercase" }}>
      {icon && <GlyBy name={icon} size={14} stroke={textColor || color || _t.ink} sw={1.6}/>}
      <span>{label}</span>
    </button>
  );
}

// Segmented control — buttons pick one of N.
function Segmented({ options, value, onChange }) {
  return (
    <div style={{ display: "grid", gridTemplateColumns: `repeat(${options.length}, 1fr)`, gap: 6,
      border: `1px solid ${_t.rule}`, borderRadius: 8, padding: 3, background: _t.panel }}>
      {options.map(([k, label, sub]) => {
        const a = value === k;
        return (
          <button key={k} onClick={() => onChange && onChange(k)} style={{
            all: "unset", cursor: "pointer", padding: "10px 4px", textAlign: "center",
            background: a ? _t.ink : "transparent", color: a ? _t.page : _t.ink,
            borderRadius: 6, display: "flex", flexDirection: "column", alignItems: "center", gap: 3,
          }}>
            <span style={{ fontSize: 12, fontWeight: 500, letterSpacing: -0.1 }}>{label}</span>
            {sub && <span style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 9,
              color: a ? _t.page : _t.sub, letterSpacing: 1 }}>{sub}</span>}
          </button>
        );
      })}
    </div>
  );
}

// Tick-mark scale — reused for brightness / volume / temp.
function TickScale({ value, max = 100, height = 28, accentDot = true }) {
  return (
    <div style={{ position: "relative", height }}>
      {Array.from({ length: 41 }).map((_, i) => {
        const f = i / 40, major = i % 5 === 0;
        const active = (f * max) <= value;
        return <div key={i} style={{
          position: "absolute", left: `${f * 100}%`, top: 0,
          width: 1, height: major ? 14 : 7,
          background: active ? _t.ink : _t.rule,
          transform: "translateX(-0.5px)",
        }}/>;
      })}
      {accentDot && (
        <div style={{ position: "absolute", left: `${(value / max) * 100}%`, top: 16,
          transform: "translateX(-50%)" }}>
          <_TDot size={10}/>
        </div>
      )}
    </div>
  );
}

// Status chip — inline badge used on lists and stat rows.
function Chip({ label, color, mono = true, filled }) {
  return (
    <span style={{
      fontFamily: mono ? "'IBM Plex Mono', monospace" : "'Inter Tight', sans-serif",
      fontSize: 10, fontWeight: 500, letterSpacing: 1.2,
      textTransform: "uppercase", padding: "4px 8px",
      border: `1px solid ${color || _t.ink}`,
      background: filled ? (color || _t.ink) : "transparent",
      color: filled ? "#fff" : (color || _t.ink),
      whiteSpace: "nowrap",
    }}>{label}</span>
  );
}

// Provider tag (e.g. "HOMEKIT")
function Provider({ label }) {
  return <span style={{ fontFamily: "'IBM Plex Mono', monospace",
    fontSize: 10, color: _t.sub, letterSpacing: 1 }}>{label}</span>;
}

window.T3Ext = {
  tokens: _t,
  TLabel: _TLabel, TRule: _TRule, TDot: _TDot,
  Header, Title, SectionHead, Pill, Row, Metric,
  GhostBtn, CTA, Outline, Segmented, TickScale, Chip, Provider,
};
