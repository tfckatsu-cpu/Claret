# FAF 3840 UI engine facts

> **Answers:** when mod code runs, how to read blueprints and issue orders, profiles, key mapper, templates, timing. **Read when:** an order is missing or hits the wrong unit, keys rebuild, a profile path is unclear, an engine signature is needed. **Next:** `architecture.md` for Claret wrappers; `hotbuild.md` for dispatch rules.

Target snapshot: `C:/ProgramData/FAForever/gamedata/lua.nx2` (read as a ZIP in memory; `lua/version.lua` reports 3840, commit `d0f37b8a19aa1e6986edbe009a43652a25b37ab6`). Neighbouring `lua.nx4` is **Beta 3839** and is not the target. Facts below marked **(verified)** were checked against that archive or a live FAF session.

## Mod loading and UI lifecycle

A mod is a folder with `mod_info.lua`:

```lua
name = 'Claret Core (Test)'
uid = 'claret-core-001'
version = 46                       -- integer, +1 on every shipped change
description = '...'
author = 'Claret Project'
selectable = true
enabled = true
exclusive = false
ui_only = true                     -- client UI only
ReUI = 'ClaretCore=0.10.27'        -- module version ReUI uses for dependency checks
```

- `Options.lua` runs at mod load and registers option tables before the UI exists.
- `Main.lua` defines `Main(isReplay)`; it runs once per session before game UI creation.
- `ReUI.Require{ 'ReUI.Core >= 1.7.0', ..., version = 3816, enabled = true }` at the top of `Main.lua` declares library and game-version requirements.
- UI controls may only be created after the game interface exists. ReUI phases: register hooks before UI creation, `OnPreCreateUI`, original `CreateUI`, post-create callbacks. Hook registration after UI creation is prohibited by ReUI.
- Everything a feature creates must be destroyed and unsubscribed on disable/session end. Core's `scope` exists for this (`architecture.md`).

## Globals and helpers

- `import(path)` — module loader, see `luaplus.md`.
- `LOG(msg)`, `WARN(msg)` — prefixed from `Main.lua` (`LOG('[Claret][build] core='..Version..' stamp='..BuildStamp)`).
- `GetSystemTimeSeconds()` — float seconds, UI-safe. No `GetSystemTimeSecondsOnlyForProfileUse` in UI.
- `ForkThread(fn)`, `WaitFrames(n)`, `WaitSeconds(n)` — coroutine helpers for deferred work (used to switch language one frame later).
- `IsDestroyed(control)` — guard before touching controls from deferred callbacks.
- `DiskGetFileInfo(path)` — existence check in the virtual filesystem (used by `lua/ui/uiutil.lua` and `lua/userInit.lua` caching).

## Blueprints, categories and buildability

- Blueprint table: global `__blueprints` in UI. Key by blueprint id; read `General.UnitName`, `General.Description`, `Interface.HelpText`, `Physics.SkirtSizeX/Z`, `Physics.SkirtOffsetX/Z`, `CategoriesHash`/categories as needed.
- `GetUnitCommandData(selection)` returns three values; the **third** is the available-blueprint category hash for that selection.
- `EntityCategoryGetUnitList(hash)` converts it to a list of blueprint ids.
- Placement rule used by Hotbuild: a unit can place structures only if the blueprint id is in `EntityCategoryGetUnitList(GetUnitCommandData({unit})[3])` **and** the unit is `COMMAND` / `SUBCOMMANDER` / `ENGINEER`. 104 units carry those categories and cover every structure placer; the only `CONSTRUCTION` unit outside the list is the Megalith (`XRL0403`), whose targets are `CRABEGG` structures without `BUILTBY*` categories.
- `GetUnitCommandDataOfUnit(unit)` — per-unit variant with a one-entry cache, does not change selection.
- `GetCurrentTechTab()` — current construction tech tab, used to filter the build grid.
- Unit categories used in tests and code: `ENGINEER`, `MOBILE`, `FACTORY`, `STRUCTURE`, `COMMAND`, `SUBCOMMANDER`, `BUILTBY...FACTORY`.
- Missing categories in fixtures are the most common stale-test cause.

## Issuing orders

- Production: `IssueBlueprintCommand('UNITCOMMAND_BuildFactory', blueprintId, count)` against the current selection.
- `IssueBlueprintCommandToUnits` is **not** an engine primitive: it is a Lua helper that temporarily changes selection, caches command mode and restores it. An exception between the steps can skip restoration — no guard inside. Prefer direct `IssueBlueprintCommand` for the current selection; introduce extra targets deliberately.
- Attached factories (`EXTERNALFACTORY`: carriers, air staging, Fatboy): the order goes to `GetCreator()`, as native `TranslateExFacUnits` does. Claret additionally requires the attachment to be finished (`GetFractionComplete() == 1`) and the creator alive and in category `FACTORY`.
- Building placement is a **command mode**, not an order: clear any active build template, then enable build mode with `name = blueprintId`. The order is issued by the player's click, not by the mod.
- `SetActiveBuildTemplate` takes a **copy** of the geometry; the selected engineer must be able to build the whole composition. Factories and replays never execute build templates.
- After a factory order, native UI calls `construction.RefreshUI`.
- Replays and observers: selection and order APIs exist but must not issue orders; guard every dispatch with `isReplay`.

## Selection

- `GetSelectedUnits()` — current selection array.
- `SelectUnits(list)` — replaces selection; always restore afterwards when used as a transaction.
- `ObserveSelection(callback)` (Core wraps it as `UseSelectionHud`) — FAF's selection feed; only one replacement HUD may own it.
- Hidden `ALLUNITS` selection is how UMT builds a shared unit cache (`MainMods/UMT/modules/units.lua`): it swaps selection, restores command mode, updates every `GameTick`, removes dead units, resets on army change. Bounded staleness, not a live event stream. EUT (`modules/mexmanager.lua`) and Beer (`modules/mexes.lua`) consume `UMT.Units.Get`; they are not independent full scans.
- Do not generalise data about own units to enemies. Intelligence limits are engine-side and unverified as a general rule.

## Templates

- Construction templates: profile key `build_templates`, read through `lua/ui/templates_factory.lua` (`GetTemplates`). Records are data only.
- Unit (factory queue) templates: profile key `build_templates_factory`, records `{name, icon, templateData = {{id, count}, ...}}`. Creation and renaming stay in the game (construction panel Templates tab or FAF's `create_template_factory`); a mod never writes this profile.
- Preview maths for construction templates matches `lua/ui/templateUtils.lua` and ReUI `BuildTemplatePreview`: one scale for the whole composition, every building centred on its anchor and sized by `Physics.SkirtSizeX/Z` with `SkirtOffsetX/Z`, so multi-cell structures draw proportionally larger and flush.

## Profiles and preferences

- `Prefs.GetFromCurrentProfile(path)` / `Prefs.SetPreference(path, value)`, then `SavePreferences()`. Composite paths with dots.
- ReUI option values live under `UIModsOptions`; Claret mod keys: `ClaretHotbuild` (presets v1), `ClaretHotbuildContexts` (v1–3), `ClaretHotbuildKeyboard` (v1–2, pairs).
- FAF key data: `UserKeyMap`, `UserKeyDebugKeyMap`, `UserKeyActions`, `keyDescriptions`.
- Reading a profile must never write it. Saving is explicit, atomic in intent (candidate + rollback), and only when a value actually changed.
- Malformed records are quarantined per record: raw data preserved, valid records keep working, unknown version blocks only its own profile.

## Key mapper

API in `lua/keymap/keymapper.lua` (verified in the snapshot):

| Call | Contract |
|---|---|
| `SetUserKeyAction(id, table)` | register an action; `nil` removes it |
| `SetUserKeyMapping(key, oldKey, actionID)` | assign a combination; `oldKey` may be `nil` |
| `ClearUserKeyMapping(key)` | clear one combination |
| `GetCurrentKeyMap()` | key → actionID |
| `GetKeyMappingDetails(id)` | id, name, category, action table |
| `GetKeyMappings()` | key → action table (new map) |
| `NormalizeKeyBinding(key)` | canonical modifier order |

- Action ids must be stable and unique. `GetKeyActions` **drops ids containing a hyphen** — use `ClaretCore_OpenMenu` style underscores.
- Ownership is checked by action id, never by table reference equality.
- F1 dialog: `lua/ui/dialogs/keybindings.lua` — `CloseUI` is public; `OnClosed` calls the local `ConfirmNewKeyMap`, which rebuilds runtime bindings. `lua/ui/controls/popups/popup.lua` `Close` calls `OnClosed` synchronously before `Destroy`. A hook after `CloseUI` can therefore reapply a temporary overlay without a timer.
- Runtime map helpers used by other mods: `IN_ClearKeyMap`, `IN_AddKeyMapTable`, `IN_RemoveKeyMapTable`, `hotbuild.addModifiers`. Removing a key with `IN_RemoveKeyMapTable` is temporary: F1 or any rebuild restores the saved assignment.
- Do not reset the global key map and do not overwrite another mod's assignment. Reject a conflicting capture and show the owner.

## Minimap and HUD hooks

- Manual minimap visibility is FAF's `stratview` preference. Core's auto-hide changes temporary visibility only and never saves over the preference.
- Hooks used by Core on `/lua/ui/game/minimap.lua`: `ToggleMinimap`, `SetLayout`. `import('/lua/ui/game/gamemain.lua').gameUIHidden` guards hiding during full-UI-hide.
- Eraser integration: `lua/ui/game/painting/PaintingBrush.lua` `DeletePaintingAtBrush` is subclassed to delete ring groups at the same brush stroke.

## Simulation bridge

`SimCallback` reaches the simulation from a `ui_only` mod. `RingWithFabricators` and `RingWithStorages` live in `lua/SimCallbacks.lua` and are callable (verified). The earlier "sim callbacks unavailable to UI mods" note was wrong.

## Out of scope

- `CinematicsMod` v1 is the only manifest with `ui_only = false`: it hooks `simInit.lua` and `system/Blueprints.lua` to raise LOD cutoff. Not a client UI pattern; any FPS claim is unmeasured.
- 14 mods shadow `hook/lua/ui/game/gamemain.lua`. The count alone proves nothing; check which functions they wrap, whether they call the previous handler, what they return and what they clean up.
