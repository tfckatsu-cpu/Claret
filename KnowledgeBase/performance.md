# Performance: method and candidates

> **Answers:** measurement protocol, candidate hotspots, instrumentation. **Read when:** someone claims a feature costs FPS, or two runs must be compared. **Next:** `pitfalls.md` — most of this is still unmeasured.

No quantitative Claret frame-time results have been recorded. FPS numbers quoted in community notes belong to other mods and other experiments.

Engineer Indicators in Claret UI 0.2.108 uses one frame handler, a marker pool, and an optional 128-marker limit. Shown markers follow the camera every frame, while other engineers are scanned in batches. The 600-engineer local model verifies at most 188 position queries per stable frame and 212 during reassignment. Position queries stop when far-zoom fading completes. Idle engineers only also skips positions for busy engineers after their red markers have faded. The user confirmed the build overall in FAF3840 on 2026-11-21. Earlier builds showed an FPS drop at 600 engineers; the improvement was not quantified.

Claret UI 0.2.120 defers background engineer and mex selection scans for the first 15 game seconds and while command mode or input capture is active. Local UI tests cover the guard. In-game preservation of the initial commander selection still needs confirmation.

## Method (user-run, reproducible)

1. Choose a replay that plays on the FAF build under test. Fix map, camera, resolution, UI scale, graphics, speed 1x, VSync off.
2. Choose one interval (e.g. 05:00–10:00 game time) and warm up every run the same way. Record the interval actually used.
3. Baseline A: target feature off, required libraries still enabled. Variant B: only the target feature on. Add a clean-UI baseline if library cost also matters. Save the mod list with UIDs.
4. Three runs each, alternating A/B, with restarts. Camera fixed — movement and zoom change overlay cost.
5. Same capture tool for raw frame times. Average FPS = frames / duration. 1% low = `1000 / average time of the slowest 1% of frames (ms)`. Record average frame time separately; never mix definitions from different tools.
6. Record process memory at interval start and end (working set and private bytes separately). This is not Lua-only memory and does not prove a leak without longer observation.
7. Save each run's `game.log`; count warnings/errors, group repeated stacks (one stack with repeated lines is one error). Compare median and spread of three runs; effects inside the spread are inconclusive.

## Reference-mod hotspots (priority by code structure, not measured impact)

| Priority | Mod | Observation | Hypothesis |
|---|---|---|---|
| 1 | DelisRedundantEcoHelp v3 | `modules/markers.lua:350–368` engineer timer 0.5 s, extractor 1 s; `UpdatePositions` every frame; `IsAlive` uses `pcall` | cost grows with marker count |
| 1 | Mouse v3 / TeamMouse v6 | `Mouse.lua:777`, `teammouse.lua:4065` `frameDriver.OnFrame` with interpolation/positioning | grows with participants and visual objects |
| 2 | EUT v11 | `mexoverlay.lua:50,105` OnFrame; `mexmanager.lua:145,162` GetUnits | separate UMT cache cost from overlay cost |
| 2 | TIS v11 | `exp.lua:180,206`, `nuke.lua:208,234` frame overlays | count simultaneous overlays, messages, cleanup |
| 2 | Reveal positions v4 | `hook/lua/ui/game/gamemain.lua:5,7` 5 s wait + 0.1 s loop; `:123` marker OnFrame | when does the loop stop |
| 3 | ReUI.MissilePanel v3 | `Main.lua:819` OnFrame; `RefreshPanel` once per 1 s from accumulated delta | frame callback is not a full recompute |
| — | ReUI v7, ReUI.Score v5 and other bytecode | not readable as text | measure the installed build, not a newer source |

## Claret candidates (not measured)

| Candidate | Observation | Hypothesis |
|---|---|---|
| `KeyboardBindings:Refresh` | rebuilds the whole engine key map on every change; `OwnIds` scans models and maps | grows with bindings and foreign keys |
| `GetAssignments` snapshot | builds rows for all maps per call; labels cached per snapshot | called by the editor on refresh and hover updates |
| `BuildKeyLabels` hook | runs inside `hotkeylabels.getKeyTables`; resolves every preset through `model:Get` (cached per call) | construction-panel refresh, not per frame |
| `TemplateCatalog:RefreshTemplates` | rebuilds template rows from the profile | large template sets on every refresh |
| Menu content render | re-renders the content group per scroll notch | only with long lists; virtualization limits it |
| `OpenPerf` instrumentation | allocates and logs when `probeEnabled` is on | keep off in normal play |

`ClaretHotbuild/modules/OpenPerf.lua`, gated by `probeEnabled` (F10 → Claret → Core, visible with ReUI developer mode), exists to measure the hotbuild open path.

## Rules

- Event-driven, not polling. Refresh on open, selection change, key press.
- `scope:Every(control, interval, fn)` for throttled work; no catch-up after a slow frame.
- Work per frame must be bounded by visible objects, not by all objects.
- Shared caches only for the same data scope and acceptable staleness; stop scanning when no consumer needs it; reset on army change.
- `pcall` in a loop is a cost multiplier — boundaries only.
- A hypothesis about ReUI cost is not a result. Do not rewrite a library layer before a comparable A/B run.
