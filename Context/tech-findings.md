# Technical Findings: Initial Pass

Review date: 2026-11-10. Local mod versions are in `mod-inventory.md`. Official documentation below describes the published website, not a snapshot of FAF 3840. Engine facts verified against FAF3840 on 2026-11-18 are marked **verified**.

## LuaPlus dialect (verified 2026-11-18)

- **`#` is not a length operator.** The official syntax page treats it as a comment marker, and a real crash confirmed it: `ContextModel.lua` with `result[#result+1]` failed to load, the module table stayed empty, and `Runtime.Create` died with `access to nonexistent global variable "Create"`. Use `table.getn` / `table.insert`. The test runner rejects `#` statically.
- `continue` is banned by the project and the runner, even though the syntax page lists it; do not rely on it.
- No `goto`, no `//`; Lua 5.0-style `math.mod`.
- Upvalue limit per function: **32** (enforced by the KeyboardEditor test; Fengari adds `_ENV`, which does not exist in LuaPlus).
- Module tables are strict: reading a missing field raises `access to nonexistent global variable <name>`. Export every public function explicitly.
- `math.huge` may be absent (the menu test stub documents this) — use large literals or `1/0`.
- `import` returns the module environment; lazily load heavy modules, but keep `Runtime` imports at file scope where the hooks need them. A file-level `return { ... }` is therefore ignored (verified 2026-11-19: Claret UI `UiSection.lua`/`AcuHealth.lua` shipped with `local` + `return` and loaded as empty tables; the caller failed with `nonexistent global variable Create/Start`). Export through module globals: `function Create(...)`. `local function X` + `X = X` does nothing, because the assignment binds to the local.

## Confirmed

- **Cinema free-camera flight investigation (2026-11-27):** Before Cinema 0.1.10, Move To started a timed `WorldCamera:MoveTo` even when the saved origin was disabled. The public reverse-engineered [CameraImpl.cpp at `39b95aaf`](https://github.com/Draiget/faf-re/blob/39b95aafda6b4f50597be1569a8de1fea5685162/src/moho/render/camera/CameraImpl.cpp#L1989-L1998) dispatches timed frames to `InterpolateBasis`; [its terrain intersection](https://github.com/Draiget/faf-re/blob/39b95aafda6b4f50597be1569a8de1fea5685162/src/moho/render/camera/CameraImpl.cpp#L2188-L2206) overwrites the interpolated focus on a hit without testing `cam_Free`. [UpdateCoords](https://github.com/Draiget/faf-re/blob/39b95aafda6b4f50597be1569a8de1fea5685162/src/moho/render/camera/CameraImpl.cpp#L2468-L2478) derives eye distance from zoom/FOV, and [uses the focus in the eye position](https://github.com/Draiget/faf-re/blob/39b95aafda6b4f50597be1569a8de1fea5685162/src/moho/render/camera/CameraImpl.cpp#L2521-L2531). By contrast, FAF Binary Patches [`TrueFreeCam` at `b8f962b`](https://github.com/FAForever/FA-Binary-Patches/blob/b8f962b56d62271301041801eb7390f1fd582135/section/TrueFreeCam.cpp) bypasses `ClampFocusPos` only.
  - Static comparison with installed `C:/ProgramData/FAForever/bin/ForgedAlliance.exe`, SHA-256 `DFF5E25EA82053DBBACF27ED20542FEC3693B48006377581DCF7FAF4EA9EC286`: PE image base `0x400000`; `0x7a90c1` calls `0x7a9ba0`, and `0x7aa2bc` calls `0x577bc0`, followed by a conditional write to three camera fields at offsets `0x360/364/368`. The `ClampFocusPos` entry `0x7a9470` jumps to `0x128f83b`, whose first instruction compares the `cam_Free` byte at `0x010a645f`. These observations match the reconstructed paths; they do not prove runtime execution or the user's exact cause.
  - The reconstructed [`SnapTo` path](https://github.com/Draiget/faf-re/blob/39b95aafda6b4f50597be1569a8de1fea5685162/src/moho/render/camera/CameraImpl.cpp#L2991-L3020) calls [`TargetManual` with duration zero](https://github.com/Draiget/faf-re/blob/39b95aafda6b4f50597be1569a8de1fea5685162/src/moho/render/camera/CameraImpl.cpp#L2849-L2879), unlike timed `MoveTo`. In the same installed exe `TargetManual` at `0x7a8d40` contains a direct call at `0x7a8e56` to the patched `ClampFocusPos` entry `0x7a9470`, consistent with that zero-duration path. The user tested Cinema moving probes in FAF on 2026-11-27: the linear, frame-driven `SnapTo` flight had no jump but lacked easing; native `MoveTo` jumped and its final view changed around terrain. Cinema 0.1.10 now uses eased frame-driven `SnapTo` for Move To, and the user confirmed that flight works in FAF. This supports the suspected terrain re-anchor, not the exact native instruction as the confirmed cause. Stop, preview, paused sessions and all camera angles remain unverified in game.
- One MainMods manifest has `ui_only=false`: CinematicsMod v1. `hook/lua/simInit.lua` wraps BeginSession and calls SimConExecute; `hook/lua/system/Blueprints.lua` changes LODCutoff for props and units. This needs separate consideration outside the client Core. Its stated purpose is increased detail distance; actual FPS impact has not been measured.
- It is possible to create a settings window and an in-game menu item using an existing example: ReUI/Options/Options.lua uses tabs.AddToMenu; ReUI/Options/Modules/OptionControls/OptionsWindow.lua implements the window. This proves the capability in the corresponding ReUI version, not that future Claret behavior works in-game. For a Claret menu item, inspect FAF 3840's own tabs.lua and do not replace the entire menu.
- UMT v13 already provides a shared unit cache: MainMods/UMT/modules/units.lua. It temporarily changes selection to ALLUNITS, saves/restores command mode and selection, updates the cache on GameTick, and resets on army change. This does not grant access to arbitrary hidden enemy data.
- EUT/modules/mexmanager.lua uses UMT.Units.Get, and Beer/modules/mexes.lua imports the same service. These consumers share a mechanism; they are not two independent full scans.
- Fourteen `hook/lua/ui/game/gamemain.lua` files were found; see `dependency-map.md`. File count does not determine order or prove conflict. Check the specific functions, calls to previous handlers, return values, and cleanup.

Fact: FAF3840, `C:/ProgramData/FAForever/gamedata/lua.nx2` (checked 2026-11-14), uses `DiskGetFileInfo(path)` to check whether a file exists in the virtual filesystem: see `lua/ui/uiutil.lua` (`UIFile`) and result caching in `lua/userInit.lua`. The Nunito installer copies `Nunito-Regular.ttf` and `Nunito-SemiBold.ttf` to the game's `fonts` directory; the UI checks both `/fonts/...` paths and shows a notice if either is missing. Availability of the two files is checked when the window is created after `OnPostCreateUI`; actual rendering in FAF is not yet checked.

## Corrections to Reference Claims

Fact: the official [FAF syntax documentation](https://faforever.github.io/fa/development/start-here/lua-syntax) describes LuaPlus 5.01, `continue`, `!=`, bitwise `&`, `|`, and shifts; `^` means XOR, and exponentiation uses `math.pow`. Therefore the ban on bitwise operators in sources/AGENTS.md is incorrect as a description of the engine. Avoiding special syntax for external tools is a separate concern. `#` is described as the start of a comment, not a length operator.

Source on available library differences: the [official documentation](https://faforever.github.io/fa/development), section “Specifics to the Lua environment.” `io`/`os` are restricted to initialization; do not design ordinary UI file configuration as in desktop Lua.

## Community Claims: Current Status

| Claim | Status | Why |
|---|---|---|
| Orders can only be appended to the end of the queue | Unknown | Reading GetCommandQueue and factory-queue actions does not prove limits on a unit's order queue; need the engine API for the specific version |
| UI cannot issue reclaim orders on props/buildings | Unknown | AOE can enter reclaim mode, but that does not prove programmatic issuance of an object-targeted order |
| Enemy information is available only on hover | Unknown in this absolute form | Need to check API, Sync, and visibility rules; do not generalize data about own units to enemies |
| Allied information requires an exe patch | Unknown | Capabilities depend on data type and engine version; Mouse/TeamMouse transmit some information themselves |
| Icons cannot be changed after loading | Unknown | Distinguish strategic icons, UI button images, and 3D unit textures; this claim has not been verified |
| nil is safe, the upvalue limit is 32, and GetFrame(1) crashes | Unknown for FAF 3840 | A friend's report does not replace documentation/source for the specific engine or verification |

## Shared-Scan Recommendations

A shared cache is justified only for the same data scope and acceptable staleness. Track consumers, stop scanning when none need it, reset on army change, bound per-frame work, and remove dead objects. Measure list retrieval separately from each consumer's work. Do not combine network cursors, hovered unit, and the full list of own units into one frequent poll.

## Further Research

Review the FAF 3840 loader and hooks, Prefs/menu/Sync/keymapper, order-issuance API, intelligence restrictions, icons, and compatibility history. Game source is not available in the supplied folder; online review began with official documentation. Do not consider these topics resolved.

- FAF UI Lua (FAF3840, checked 2026-11-13): `GetSystemTimeSeconds()` is available for timing; `GetSystemTimeSecondsOnlyForProfileUse` does not exist in UI context (strict-globals error); `os` is unavailable. In Claret modules, `rawget(_G, ...)` may not see engine globals — use normal access guarded by `pcall`. Performance probes: `ClaretHotbuild/modules/OpenPerf.lua`, gated by `probeEnabled`.
- `SimCallback` reaches the simulation: `RingWithFabricators` and `RingWithStorages` are implemented in `lua/SimCallbacks.lua` (verified 2026-11-18). A `ui_only` mod may call them; the earlier "missing sim callbacks" finding was wrong.
- Profile data lives under `UIModsOptions` (ReUI options) and the mod keys (`ClaretHotbuild`, `ClaretHotbuildContexts`, `ClaretHotbuildKeyboard`); FAF key tables are `UserKeyMap`, `UserKeyDebugKeyMap`, `UserKeyActions`, `keyDescriptions`.
