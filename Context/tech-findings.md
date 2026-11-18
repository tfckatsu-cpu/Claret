# Technical Findings: Initial Pass

Review date: 2026-11-10. Local mod versions are in `mod-inventory.md`. Official documentation below describes the published website, not a snapshot of FAF 3840. Engine facts verified against FAF3840 on 2026-11-18 are marked **verified**.

## LuaPlus dialect (verified 2026-11-18)

- **`#` is not a length operator.** The official syntax page treats it as a comment marker, and a real crash confirmed it: `ContextModel.lua` with `result[#result+1]` failed to load, the module table stayed empty, and `Runtime.Create` died with `access to nonexistent global variable "Create"`. Use `table.getn` / `table.insert`. The test runner rejects `#` statically.
- `continue` is banned by the project and the runner, even though the syntax page lists it; do not rely on it.
- No `goto`, no `//`; Lua 5.0-style `math.mod`.
- Upvalue limit per function: **32** (enforced by the KeyboardEditor test; Fengari adds `_ENV`, which does not exist in LuaPlus).
- Module tables are strict: reading a missing field raises `access to nonexistent global variable <name>`. Export every public function explicitly.
- `math.huge` may be absent (the menu test stub documents this) — use large literals or `1/0`.
- `import` returns the module environment; lazily load heavy modules, but keep `Runtime` imports at file scope where the hooks need them.

## Confirmed

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
