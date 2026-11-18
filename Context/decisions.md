# Decisions (ADR)

Short records of architectural and product decisions. Format: ID, date, decision, why, consequences. Details and evidence live in the linked documents; do not duplicate them here.

| ID | Date | Decision | Why | Consequences |
|---|---|---|---|---|
| ADR-001 | 2026-11-10 | One shared Core plus separate feature mods; everything `ui_only`. | Too many fragmented mods conflicted and hurt performance. | Core owns registry, menu, theme, localization; no simulation changes; no separate Claret UI mod. |
| ADR-002 | 2026-11-11 | Flat dark visual language; colours and metrics only from `Theme`. | Consistent look and one place to change it. | No per-module palettes; UI rules in `ui-rules.md`, tokens in `Theme.lua`. |
| ADR-003 | 2026-11-13 | All Claret settings live in F10 → Claret via `RegisterSettingsSection`; no ReUI Options tabs. | ReUI tabs are shared and crowded; Claret needs its own shell. | Menu sections, `inline(parent, layout)`, `CanLeave`; no `Builder.AddOptions` for Claret. |
| ADR-004 | 2026-11-13 | Bindings are per-chord pairs (`ClaretHotbuildKeyboard`); preset `key`/`grid.context` become historical metadata. | One key can carry a preset, a context and an action; a single preset field cannot express that. | Pairs are the source of truth; FAF maps are the mirror; old fields are read-only fallback. |
| ADR-005 | 2026-11-14 | Context priority: units → empty → ACU/SACU/engineer → factory → silos → transport/mex/scout/other; "under cursor" first. | Mixed selections must resolve deterministically. | Removed actions stay in saved rows marked obsolete; chains reserve resulting contexts. |
| ADR-006 | 2026-11-15 | Template conversion only for complete, unambiguous cross-faction matches. | Guessing prefixes produced wrong buildings. | Geometry/order preserved; ambiguous templates are not converted; source unchanged. |
| ADR-007 | 2026-11-18 | Malformed saved records are quarantined per record, never fatal. | One bad record used to disable all keys and saves. | Raw records and FAF assignments are preserved; editors show a localized problem line; unknown version blocks only its own profile. |
| ADR-008 | 2026-11-18 | Hotbuild is always active; the QuickRepeat window, its setting and the gear are removed. | The window was unreachable garbage; a saved `enabled=false` left dead keys. | No feature toggle; `row.quickRepeat` remains legacy data; double-press 0.5 s, quick repeat 1.5 s, both one-shot. |
| ADR-009 | 2026-11-18 | Legacy preset `key` values are metadata; duplicates are allowed. | Keys are not authoritative and the duplicate check caused false damage warnings. | `Model:Put` does not reject duplicate keys; README documents the saved-data model. |
| ADR-010 | 2026-11-18 | The Construction/Orders/Multifunction/SelectionIgnore families stay as a deferred replacement for the ReUI HUD. | They were written ahead of integration; not abandoned code. | Preserved with tests, documented as deferred, excluded from the current scope; no refactor. |
| ADR-011 | 2026-11-18 | Tests auto-discover, enforce static rules and must be green before a task is done. | 14 red tests hid a broken module load; a hand-kept list lost three files. | `#`/`continue`/boundary/version checks; 66/0 baseline; failures are either stale expectations or real defects. |
| ADR-012 | 2026-11-18 | Knowledge base is English; chat is Russian; Stage notes stay Russian. | Agents and docs need one language; the user reads Russian. | Context, Skills, Credits and READMEs in English; Stage status/archive and historical CHANGELOG stay Russian. |
