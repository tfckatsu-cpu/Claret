# Performance: Candidates and Method

Date: 2026-11-10. This is a code-structure review priority, not a ranking of measured impact.

| Priority | Candidate and version | Confirmed observation / source | Measurement hypothesis |
|---|---|---|---|
| 1 | DelisRedundantEcoHelp v3 | modules/markers.lua:350–368: engineer timer 0.5 s, extractor timer 1 s; UpdatePositions every frame; IsAlive uses pcall | Cost may grow with marker count; measure projection and Refresh separately |
| 1 | Mouse v3, TeamMouse v6 | modules/Mouse.lua:777 and modules/teammouse.lua:4065: frameDriver.OnFrame; an interpolation and positioning pass is described | Load may grow with participant/visual-object count; check both enabled together |
| 2 | EUT v11 | modules/mexoverlay.lua:50,105 — OnFrame; modules/mexmanager.lua:145,162 — GetUnits for extractors/engineers | Separate the cost of UMT's shared cache from its own overlay |
| 2 | TIS v11 | modules/exp.lua:180,206 and modules/nuke.lua:208,234 — OnFrame overlays | Check simultaneously active overlay count, message sending, and cleanup |
| 2 | Reveal positions v4 | hook/lua/ui/game/gamemain.lua:5,7 — 5 s wait and 0.1 s loop; :123 marker OnFrame | Check when the loop stops and what changes in each pass |
| 3 | ReUI.MissilePanel v3 | Main.lua:819 — OnFrame; RefreshPanel runs once per second based on accumulated delta | OnFrame alone does not mean a full recalculation every frame; measure RefreshPanel separately |
| Not assessed | ReUI v7, ReUI.Score v5, and other binary components | compiled-lua.txt: implementations not readable as ordinary text | Measure the installed version; a newer source version is not its proven equivalent |

## Reproducible User Check
1. FAF 3840, replay 28072660. First check that it plays on this version. Fix the map, camera, resolution, UI scale, graphics, and speed at 1x; turn VSync off.
2. Choose one interval, e.g. 05:00–10:00 game time, if present in the replay. Warm up each run the same way before the interval. Record the actual interval used.
3. Baseline A: target feature off, required libraries remain enabled. Variant B: only the target feature is on. Add clean UI as a separate baseline if library cost also needs assessment. Save the mod list and UIDs.
4. Run A and B three times each with restarts, alternating A/B. Keep the camera fixed; movement and zoom materially change overlay cost.
5. Save raw frame times using the same capture tool. Average FPS = frame count / duration; define 1% low as 1000 / average time of the slowest 1% of frames (ms); record average frame time separately. Do not mix definitions from different tools.
6. Record process memory at the start and end of the interval, noting working set/private bytes and units separately. This is not Lua-only memory and does not prove a leak without longer observation.
7. Save each run's game.log; count warnings/errors and group repeated stacks. Do not count repeated lines from one stack as independent errors. Compare the median and spread of three runs; treat small effects within the spread as inconclusive.

No measurements have been made yet. FPS and percentage values in friend-notes refer to another mod and experiment; do not attribute them to Claret or ReUI.

## Claret candidates (not measured)

Engineer Indicators in Claret UI 0.2.108 (FAF3840, 2026-11-21): the user observed reduced FPS around 600 engineers with early builds, including the build that limited markers to 128 while still projecting every engineer every frame. With Optimize display enabled, shown markers update every frame and other engineers are scanned in batches. The local 600-engineer model verifies at most 188 position queries in stable frames and 212 when markers are reassigned. Fully faded markers at far zoom require no unit-position queries. Idle engineers only skips positions for busy engineers after their markers fade. The user confirmed 0.2.108 overall. Quantitative FPS improvement and individual scenarios were not reported.

| Candidate | Observation | Hypothesis |
|---|---|---|
| KeyboardBindings:Refresh | Clears and rebuilds the whole engine key map on every change; OwnIds scans models and maps | Cost grows with bindings and foreign keys; measure with probeEnabled |
| GetAssignments snapshot | Builds rows for all maps on each call; labels cached per snapshot only | Called by the keyboard editor on refresh and hover updates |
| BuildKeyLabels hook | Runs inside hotkeylabels.getKeyTables; resolves every preset via model:Get (cached per call) | Called on construction panel refresh, not per frame |
| TemplateCatalog:RefreshTemplates | Rebuilds template rows from the profile | Large template sets on every catalog refresh |
| Menu content render | Re-renders the content group on each scroll notch | Visible only with long lists; virtualized rows limit it |
| OpenPerf | Instrumentation itself allocates and logs when probeEnabled is on | Keep disabled for normal play; use for measurements |

No Claret measurements have been made. Use the method above with the same replay, camera and mod list; report median of three runs.
