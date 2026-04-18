# T3 Icon Set — Gap Analysis

The T3 design handoff includes **40+ custom outlined glyphs** (1.4px stroke, square linecap, miter join) in `design-reference/project/lib/glyphs.jsx`. These are NOT SF Symbols — they're hand-built SVGs with a distinct Braun/Dieter Rams aesthetic.

## Current State
The iOS app uses **SF Symbols** as placeholders. They work but don't match the T3 handoff's precise geometric style. SF Symbols are rounded/humanist; T3 glyphs are angular/miter-joined/mechanical.

## T3 Glyphs Available (from glyphs.jsx)

### Navigation & Chrome
| Glyph | SVG Path | SF Symbol Fallback | Status |
|-------|----------|-------------------|--------|
| `back` | chevron left | `chevron.left` | Needs SVG |
| `chevR` | chevron right | `chevron.right` | Needs SVG |
| `chevD` | chevron down | `chevron.down` | Needs SVG |
| `close` | X cross | `xmark` | Needs SVG |
| `check` | checkmark | `checkmark` | Needs SVG |
| `plus` | plus | `plus` | Needs SVG |
| `minus` | minus | `minus` | Needs SVG |
| `more` | three dots | `ellipsis` | Needs SVG |
| `search` | magnifier | `magnifyingglass` | Needs SVG |

### Tabs
| Glyph | Description | SF Symbol Fallback | Status |
|-------|------------|-------------------|--------|
| `home` | house outline | `house` | Needs SVG |
| `rooms` | 4 squares grid | `square.grid.2x2` | Needs SVG |
| `devices` | monitor/screen | `rectangle.on.rectangle` | Needs SVG |
| `settings` | gear/sun with rays | `gearshape` | Needs SVG |

### Device Categories
| Glyph | Description | SF Symbol Fallback | Status |
|-------|------------|-------------------|--------|
| `lightbulb` | bulb with filament | `lightbulb` | Needs SVG |
| `thermo` | thermometer tube | `thermometer.medium` | Needs SVG |
| `lock` | padlock | `lock` | Needs SVG |
| `speaker` | rectangular speaker | `hifispeaker` | Needs SVG |
| `camera` | video camera | `video` | Needs SVG |
| `fan` | propeller/blades | `fan` | Needs SVG |
| `door` | door with handle | `door.left.hand.open` | Needs SVG |

### Room Icons
| Glyph | Description | SF Symbol Fallback | Status |
|-------|------------|-------------------|--------|
| `sofa` | couch outline | `sofa` | Needs SVG |
| `bed` | bed with pillow | `bed.double` | Needs SVG |
| `kitchen` | fork/spoon utensils | `fork.knife` | Needs SVG |

### Weather & Environment
| Glyph | Description | SF Symbol Fallback | Status |
|-------|------------|-------------------|--------|
| `sun` | sun with rays | `sun.max` | Needs SVG |
| `cloud` | cloud | `cloud` | Needs SVG |
| `moon` | crescent moon | `moon` | Needs SVG |
| `drop` | water drop | `drop` | Needs SVG |
| `wind` | wind curves | `wind` | Needs SVG |

### HVAC Modes
| Glyph | Description | SF Symbol Fallback | Status |
|-------|------------|-------------------|--------|
| `heat` | flame/fire | `flame` | Needs SVG |
| `cool` | snowflake star | `snowflake` | Needs SVG |
| `auto` | A letter | `arrow.2.squarepath` | Needs SVG |
| `off` | power button | `power` | Needs SVG |

### Media Transport
| Glyph | Description | SF Symbol Fallback | Status |
|-------|------------|-------------------|--------|
| `play` | triangle | `play.fill` | Needs SVG |
| `pause` | two bars | `pause.fill` | Needs SVG |
| `next` | triangle + bar | `forward.fill` | Needs SVG |

### Miscellaneous
| Glyph | Description | SF Symbol Fallback | Status |
|-------|------------|-------------------|--------|
| `bell` | notification bell | `bell` | Needs SVG |
| `bolt` | lightning bolt | `bolt` | Needs SVG |
| `dot` | filled circle | TDot component | ✅ Done |
| `wifi` | signal arcs | `wifi` | Needs SVG |
| `wifiSlash` | wifi with slash | `wifi.slash` | Needs SVG |
| `user` | person silhouette | `person` | Needs SVG |
| `target` | concentric circles | `target` | Needs SVG |
| `arrowUp` | arrow up | `arrow.up` | Needs SVG |
| `arrowDn` | arrow down | `arrow.down` | Needs SVG |
| `arrowR` | arrow right | `arrow.right` | Needs SVG |
| `grid` | 4 squares | `square.grid.2x2` | Needs SVG |
| `scenes` | star | `star` | Needs SVG |

## What to Feed Back to Claude Design

Ask Claude Design to:
1. Export the glyphs from `glyphs.jsx` as individual SVG files (24x24 viewBox)
2. Ensure 1.4px stroke, `stroke-linecap="square"`, `stroke-linejoin="miter"`
3. Provide as an SVG asset catalog that can be imported into Xcode as Custom Symbol Images
4. Or: provide as a single Swift file with `Shape` conformances for each glyph

## Temporary Solution
Using SF Symbols with `.fontWeight(.light)` and consistent 18-20px sizing across all T3 views. This approximates the thin-stroke aesthetic until custom glyphs are available.
