# Reference mods: versions, UIDs, licences

> **Answers:** which mod does what, versions/UIDs, licences, dependency constraints, where sources live. **Read when:** looking for a reference implementation, checking a licence, choosing a source to study. **Next:** `native-key-actions.md` for action ids; `reui.md` for the library.

Claret mods (checked 2026-11-21):

| Mod | Version | Mod version | UID |
|---|---|---|---|
| Claret Core | 0.10.37 | 56 | `claret-core-001` |
| Claret UI | 0.2.123 | 125 | `claret-ui-001` |
| Claret Hotbuild | 0.10.61 | 86 | `claret-hotbuild-001` |

All three are `ui_only = true` and require ReUI. ReUI installed: Main 1.3.2, Core 1.7.0, Options 1.2.0. Readable reference sources are Main 1.4.0 — a newer version; never assume identical behaviour.

## What each mod provides (finding reference code)

One line per mod, from manifests and installed code. Behaviour is not verified in game unless stated elsewhere.

| Mod | Purpose |
|---|---|
| ACUEnhancements | ACU/SACU enhancement UI |
| AKA | composite keybind actions: transport/overcharge/pause, missile, nearest engineer |
| AOE | additional orders, selection + action combos, QoL toggles |
| ASE | selection filtering: assisting units, domains, unit lock |
| ASI Medium | Redux ACU strategic icons (default size) |
| Beer | sound when an extractor starts/finishes upgrading |
| Bi4UI.StrategicRings | radius rings by hotkey, merged outlines, eraser support |
| BindStorage | saved bind storage |
| BuilderAltSelect | Shift+Alt selects engineers only, Shift+Ctrl factories only |
| cinematics | cinematic camera/visual tools |
| CinematicsMod | max video quality; `ui_only = false`, simulation-side |
| Ctrl | Ctrl-move locks move order; Ctrl-copy building |
| dear-windowing | immediate-mode UI helpers for mods and debugging |
| DelisRedundantEcoHelp | idle engineer and extractor tech markers |
| DynamicSelectionInfo | selection totals HUD (mass/energy/BP/cost) |
| EconomyMiddle | layout for ReUI.Economy in the top middle |
| EUT | eco overlays, auto extractor upgrade, unpause thresholds |
| Extra mini map | borderless minimap look |
| FactoryTemplates | factory template actions for the actions grid |
| GS | group scatter with cycling through selected units |
| InstantAssist | instant assist action |
| Mouse | ally mouse cursors |
| Music_PhilCrofts | custom music tracks |
| Regen Aura Range | Seraphim ACU restoration-field circle |
| ReUI | core library (loader, hooks, options, UI, units) |
| ReUI.ActionsPanel | actions grid panel |
| ReUI.Construction | construction UI replacement |
| ReUI.Construction.Templates | construction templates for the replacement HUD |
| ReUI.Economy | economy panel |
| ReUI.Hotbuild | hotbuild implementation — research source for Claret Hotbuild |
| ReUI.MissilePanel | TML/nuke launcher panel |
| ReUI.Reclaim | reclaim UI |
| ReUI.Score | score panel |
| Reveal positions | start positions with faction icons |
| RFA | rings for selected/hovered units and build range |
| SplitGroupScatter | fork of group scatter with UI Party split groups |
| STP | target-specific priorities by unit category |
| TeamMouse | teammate cursor, order and drag-selection sharing |
| TIS | team sharing of nukes, SMDs and experimental completions |
| UMT | UI mod tools; shared unit cache |

## Installed reference mods (2026-11-10, versions from manifests)

| Folder | Ver | UID | Bytecode/Lua | Licence |
|---|---|---|---|---|
| ACUEnhancements | 4 | `acu-enhancements-v1.0.3` | 0/2 | none stated |
| AKA | 5 | `advanced-key-actions-1.2.2` | 0/2 | none stated (manifest says MIT) |
| AOE | 5 | `additional-orders-extension-v05` | 0/5 | none stated |
| ASE | 3 | `advanced-selection-extension-v03` | 0/8 | none stated |
| ASI Medium (Redux ACU Icons) | 1 | `redux-acu-icons-01` | 0/2 | author permits icon reuse with credit (macdeffy) |
| Beer | 1 | `beer-beer-beer-v01` | 0/4 | none stated |
| Bi4UI.StrategicRings | 20 | `bi4ui-strategic-Rings-v15` | 0/15 | none stated |
| BindStorage | 1 | `04323AB2-1C12-5ED7-9876-2111D3100005` | 0/3 | none stated |
| BuilderAltSelect | 3 | `builder-alt-select-v3` | 0/3 | none stated |
| cinematics | 7 | `cinematics-07` | 0/8 | none stated |
| CinematicsMod | 1 | `0ad0e447-5c65-468a-84c9-af62859453e3` | 0/3 | none stated; **only `ui_only = false`** |
| Ctrl | 2 | `ctrl-v02` | 0/3 | none stated |
| dear-windowing | 9 | `dear-windowing-09` | 0/7 | none stated |
| DelisRedundantEcoHelp | 3 | `delis-redundant-eco-help-v3` | 0/5 | none stated |
| DynamicSelectionInfo | 3 | `dynamic-selection-info-v03` | 0/3 | none stated |
| EconomyMiddle | 2 | `EconomyMiddle-1.1.0` | 1/3 | none stated |
| EUT | 11 | `eco-ui-tools-4z0t-v11` | 0/8 | none stated |
| Extra mini map | 3 | `b0d9ac94-cetet-11e5-9912-ba1s3e4` | 0/2 | none stated |
| FactoryTemplates | 2 | `factory-templates-1.0.0` | 1/2 | none stated |
| GS | 7 | `group-scatter-v07` | 0/2 | none stated |
| InstantAssist | 3 | `instant-assist-1.1.1` | 2/3 | none stated |
| Mouse | 3 | `mouse-1-0-2` | 0/10 | none stated |
| Music_PhilCrofts | 5 | `8ecaa312-…` | 0/2 | none stated |
| Regen Aura Range | 1 | `5e7a9c31-…` | 0/5 | none stated |
| ReUI | 7 | `reui-1.3.2` | 53/75 | root MIT 2022 4z0t |
| ReUI.ActionsPanel | 4 | `reui-actionspanel-1.1.3` | 4/6 | none stated |
| ReUI.Construction | 7 | `ReUI.Construction-1.3.0` | 0/21 | none stated |
| ReUI.Construction.Templates | 1 | `ReUI.Construction.Templates-1.0.0` | 4/6 | none stated |
| ReUI.Economy | 2 | `reui-economy-1.2.0` | 4/6 | none stated |
| ReUI.Hotbuild | 1 | `reui-Hotbuild-1.1.0` | 0/10 | none stated |
| ReUI.MissilePanel | 3 | `missile-panel-v3` | 0/3 | none stated |
| ReUI.Reclaim | 7 | `reui-reclaim-1.2.1` | 0/3 | none stated |
| ReUI.Score | 5 | `reui-score-1.2.4` | 27/30 | none stated |
| Reveal positions | 4 | `128a0b16-…` | 0/2 | none stated |
| RFA | 7 | `rings-for-all-v1.0.0` | 2/3 | none stated |
| SplitGroupScatter | 2 | `split-group-scatter-v02` | 0/2 | none stated |
| STP | 3 | `Specific-Target-Priorities-v03` | 0/3 | none stated |
| TeamMouse | 6 | `team-mouse-v6` | 0/23 | MIT 2026 Lightningbulb2 |
| TIS | 11 | `teaminfo-share-v11` | 0/8 | none stated |
| UMT | 13 | `ui-mod-tools-4z0t-v13` | 0/45 | none stated |

"Bytecode/Lua" = number of files with ESC Lua header vs plain text in the installed copy. Bytecode is readable only through `.tools/unluac`; do not treat a newer sources copy as the installed behaviour.

## Licence rules

- `Context/sources/LICENSE`: MIT, copyright 2022 4z0t — covers the 4z0t mod family only as far as that file states.
- `TeamMouse/LICENSE`: MIT, copyright 2026 Lightningbulb2.
- Every other mod above has **no separate LICENSE file**; manifest `author`/`copyright` fields are claims, not grants. Assets are not covered by code licences.
- The FAF Vault rules require the FAF vault licence or something more permissive, and the backend applies a default licence id when none is supplied. The text of the FAF vault licence is **not published**; `api.faforever.com` answers 401 anonymously.
- Project decision (ADR-014, 2026-11-19): reuse of old mods without a licence line is accepted by the owner. Copied files keep their original MIT notice, authors are credited in `Credits and more/CREDITS.md`, and the original mod must be disabled while the Claret equivalent is enabled. Mods with no stated licence are reused by name/credit, **without shipping their assets** unless a licence allows it.
- Check each mod separately. ReUI's MIT does not extend to neighbouring mods.

## Dependency constraints that matter

- ReUI Main 1.3.2 requires `ReUI.Core >= 1.7.0` and `ReUI.UI.QoL >= 1.0.0`; the 1.4.0 source copy requires `>= 1.1.0`. Enabling ReUI always loads the QoL branch (Options, UI, LINQ).
- Claret Core requires `ReUI.Core >= 1.7.0`, `ReUI.Core.Events >= 1.0.0`, `ReUI.UI >= 1.0.0`, `ReUI.Options >= 1.2.0`, FAF >= 3816.
- Claret Hotbuild requires `ClaretCore >= 0.10.15` plus the same ReUI set, FAF >= 3816.
- Claret UI requires `ClaretCore >= 0.10.27`, `ReUI.Core >= 1.7.0`, `ReUI.UI >= 1.0.0`, `ReUI.Options >= 1.2.0`.
- ReUI.Construction requires Core >= 1.5.0, Actions >= 1.3.0, UI >= 1.4.0, Views >= 1.2.0, Units.Enhancements >= 1.2.0; the full table lives in `Context/dependency-map.md`.
- UMT provides the shared unit cache (`MainMods/UMT/modules/units.lua`); EUT and Beer consume `UMT.Units.Get`. They are not independent scans.

## Interaction surface with other mods

- 14 mods shadow `hook/lua/ui/game/gamemain.lua`: ASE, Beer, Bi4UI.StrategicRings, BindStorage, BuilderAltSelect, cinematics, dear-windowing, DelisRedundantEcoHelp, Mouse, Regen Aura Range, ReUI, Reveal positions, TeamMouse, UMT. The count proves no conflict by itself; check which functions they wrap and whether they chain.
- Overlapping purposes (not identical algorithms): AOE/AKA composite actions; GS/SplitGroupScatter group cycling; EUT/DelisRedundantEcoHelp extractor markers; Mouse/TeamMouse ally cursors; EconomyMiddle lays out ReUI.Economy.
- Features ported from other mods must not run alongside the original: the original mod is disabled while the Claret equivalent is on.

## Sources on disk

- `Context/sources/` — read-only copies, git-ignored. Start at `Context/sources/SOURCES.md`, then `rg --no-ignore <pattern> Context/sources/<Mod>`.
- `Context/.local/compiled-lua.txt` — decompiled reference dump.
- `Context/.local/reui-decompiled/` — 92 decompiled ReUI files from 9 installed mods, manifest with SHA-256; syntax-parsed, not execution-verified.
- Game snapshot `C:/ProgramData/FAForever/gamedata/lua.nx2` — read-only, never extract into the mod folders.
