# Decisions (ADR log)

> **Answers:** what was decided, when and why; what must not be undone silently. **Read when:** changing a public surface, profile format, registration contract or architecture. **Next:** the owner doc named in the row.

Short records. Evidence lives in the linked documents; do not duplicate detail here.

| ID | Date | Decision | Why | Consequences |
|---|---|---|---|---|
| ADR-001 | 2026-11-10 | One shared Core plus separate feature mods; everything `ui_only`. | Fragmented mods conflicted and cost performance. | Core owns registry, menu, theme, localization; no simulation changes. Superseded in part by ADR-013. |
| ADR-002 | 2026-11-11 | Flat dark visual language; colours and metrics only from `Theme`. | Consistent look, one place to change. | No per-module palettes. |
| ADR-003 | 2026-11-13 | All Claret settings in F10 → Claret via `RegisterSettingsSection`; no ReUI Options tabs. | ReUI tabs are shared and crowded; Claret needs its own shell. | `inline(parent, layout)`, `CanLeave`; no `Builder.AddOptions` for Claret. |
| ADR-004 | 2026-11-13 | Bindings are per-chord pairs (`ClaretHotbuildKeyboard`); preset `key`/`grid.context` become historical metadata. | One key can carry a preset, a context and an action. | Pairs are the source of truth; FAF maps are the mirror; old fields are read-only fallback. |
| ADR-005 | 2026-11-14 | Context priority: units → empty → ACU/SACU/engineer → factory → silos → transport/mex/scout/other; "under cursor" first. | Mixed selections must resolve deterministically. | Removed actions stay in saved rows marked obsolete; chains reserve resulting contexts. |
| ADR-006 | 2026-11-15 | Template conversion only for complete, unambiguous cross-faction matches. | Guessing prefixes produced wrong buildings. | Geometry/order preserved; ambiguous templates are not converted; source unchanged. |
| ADR-007 | 2026-11-18 | Malformed saved records are quarantined per record, never fatal. | One bad record used to disable all keys and saves. | Raw records and FAF assignments preserved; unknown version blocks only its profile. |
| ADR-008 | 2026-11-18 | Hotbuild is always active; the QuickRepeat window, its setting and gear are removed. | The window was unreachable; a saved disable left dead keys. | No toggle; `row.quickRepeat` remains legacy data; double-press 0.5 s, quick repeat 1.5 s, both one-shot. |
| ADR-009 | 2026-11-18 | Legacy preset `key` values are metadata; duplicates allowed. | Keys are not authoritative; the duplicate check caused false damage warnings. | `Model:Put` does not reject duplicates. |
| ADR-010 | 2026-11-18 | Construction/Orders/Multifunction/SelectionIgnore stay as deferred replacement for the ReUI HUD. | Written ahead of integration, not abandoned. | Preserved with tests, never loaded, no refactor, wiring is a separate step. |
| ADR-011 | 2026-11-18 | Tests auto-discover, enforce static rules, must be green. | 14 red tests hid a broken module load; a hand-kept list lost three files. | `#`/`continue`/boundary/version checks; failures are stale expectations or real defects. |
| ADR-012 | 2026-11-18 | Knowledge base in English; chat in Russian; Stage notes in Russian. | One language for agents and docs; the user reads Russian. | `Context/`, `Skills/`, READMEs, this folder in English; Stage and historical CHANGELOG Russian. |
| ADR-013 | 2026-11-19 | A separate child mod `ClaretUI` owns game-interface overlays; it fills the `ui` placeholder section Core reserves. | Core's scope grew past the menu; overlays need their own toggle set and release rhythm. | Supersedes ADR-001's "no separate Claret UI mod". ClaretUI depends on Core and ReUI, is a leaf, stays `ui_only`. |
| ADR-014 | 2026-11-19 | Port features of existing FAF UI mods by copying and adapting their code, not rewriting behaviour. | Owner decision; rewriting ~6k lines would cost more and drift. | Sources: installed mods, `Context/sources/`, `Context/.local/reui-decompiled/`, `.tools/unluac`. Copied files keep their MIT notice (4z0t / FAF-UI-Mods, TeamMouse), authors credited; adaptation means Claret Theme, EN/RU localization, per-feature option, scale-aware persistence, no stock-file replacement hooks. Original mod disabled while the Claret equivalent is on. |

## Standing consequences

- Public surface changes (a new Core API, a new profile key, a changed registration contract) require an ADR entry plus a knowledge-base update in the same task.
- Reversing an ADR is a new ADR that names the superseded one; do not silently edit history.
- ADR-014 is the later owner decision: for ports of existing mods it wins over the earlier "write code from scratch" rule. New code is still written from scratch, and other mods are studied as reference only.
