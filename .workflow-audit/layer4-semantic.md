# Layer 4: Semantic Evaluation

User goals and how the T3 surface serves them.

## Persona A: "I just want to check what's on"
- Home tab gives an active/offline/standby count + per-room card.
- Rating: Excellent. Tap a room → see only that room's devices.

## Persona B: "Something broke, fix it"
- HAConnectionBanner is globally overlaid at the top. Good.
- A smoke alarm going off: promised in code (SmokeAlertController, simulate button) but the UI doesn't exist (falls to generic accessory view). **Broken promise.**

## Persona C: "Automate something"
- Settings → Automations lists HA automations, can enable/trigger.
- Trigger always toasts success even on failure → erodes trust the first time HA is down. High impact once it happens; medium UX.

## Persona D: "Configure providers"
- Settings → Connections → provider row → T3ProviderDetailView → Nest OAuth sheet if Nest. Clean.
- Devices tab empty state also routes here correctly.

## Persona E: "Monitor energy"
- Home weather strip + Explore both lead to T3EnergyView.
- Duplicate entries are cosmetic; bigger issue is the silent mock fallback on failure.

## Persona F: "Merge duplicate devices across providers"
- Settings → Linked Devices (new, uncommitted per brief).
- Scenario-A bug acknowledged. Room merging is a known orphan (planned feature).

## Overall T3 navigation quality
- Honors the skill's "Honor the Promise" principle in most places — CTAs match destinations, destinations match scope.
- Primary gaps are at the **data-integrity and feedback** layer, not navigation topology.
- No classic dead-ends (no entry points pointing to non-existent views — except smoke alarm, which falls through to a generic view that partially works).

## Rating matrix
| Workflow            | Discovery | Efficiency | Feedback | Recovery | Overall |
|---------------------|-----------|------------|----------|----------|---------|
| Run a scene         | ★★★★★     | ★★★★★      | ★★★★★    | ★★★★     | Excellent |
| Tap a device        | ★★★★★     | ★★★★★      | ★★★★★    | ★★★★     | Excellent |
| Trigger automation  | ★★★★      | ★★★★       | ★★       | ★★       | Fair (silent errors) |
| Smoke alarm history | ★★        | ★★         | N/A      | N/A      | **Broken** |
| Energy dashboard    | ★★★★★     | ★★★★★      | ★★★      | ★★★      | Good (fallback confuses) |
| Merge rooms         | ★         | ★          | ★        | ★        | Not implemented (planned) |
| Link devices        | ★★★★      | ★★★        | ★★★      | ★★★      | Good (WIP; scenario-A known) |
