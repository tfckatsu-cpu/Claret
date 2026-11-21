# Cheat sheet

> **Answers:** the 80% facts — syntax bans, skeletons, scale/depth, dispatch, commands. **Read when:** the task is routine or you need a rule, identifier or number fast. **Next:** the owning doc named at the end of the block.

The facts that answer most tasks. Derived from the owning docs — if they disagree, the owning doc wins.

## Language (LuaPlus)

```lua
-- banned: #, continue, goto, //, varargs in expression position
local n = table.getn(list)          -- not #list
local m = math.mod(a, b)            -- not %
local M = import('/mods/Mod/modules/M.lua')   -- not require
```

- Export through module globals: `function Create() end`. `return { ... }` is ignored by `import`; the module table stays empty and the caller raises `access to nonexistent global variable`.
- `local function X` + `X = X` exports nothing (assignment hits the local).
- Module tables are strict: reading an unassigned field raises an error.
- ≤ 32 upvalues per function. `math.huge` may be absent. No `os`. `GetSystemTimeSeconds()` exists; the `...OnlyForProfileUse` variant does not.
- Maui classes are callable tables, not functions — do not test with `type(x) ~= 'function'`.
- `pcall` only at boundaries, never per frame or per item. No `error()` inside UI callbacks.
- A normal Lua compiler does not prove FAF compatibility → `luaplus.md`

## Mod skeleton

```lua
-- Main.lua
Version = '0.1.0'
local BuildStamp = 'YYYYMMDD-1'
ReUI.Require { 'ClaretCore >= 0.10.27', 'ReUI.Core >= 1.7.0', 'ReUI.UI >= 1.0.0', 'ReUI.Options >= 1.2.0', enabled = true, version = 3816 }

function Main(isReplay)
    local Localization = ReUI.ClaretCore.Localization
    local ok, err = Localization.Register('modid', import('/mods/Mod/modules/LocalizationStrings.lua').Strings)
    if not ok then error(err) end
    local options = ReUI.Options.Mods['Mod']
    local featureOk, featureError = ReUI.ClaretCore.RegisterFeature('modid', function(scope)
        import('/mods/Mod/modules/Runtime.lua').Create(isReplay, options):Start(scope)
    end, options.enabled)
    if not featureOk then error(featureError) end
end
```

```lua
-- Options.lua
ReUI.Options.Mods['Mod'] = { enabled = ReUI.Options.OptionValue(true) }
function Main() end
```

- `mod_info.lua`: `uid`, integer `version` (+1 per release), `ui_only = true`, `ReUI = 'Mod=<Version>'`.
- Version identity: `Main.lua Version` = `mod_info.lua ReUI` = README heading; `BuildStamp` = newest CHANGELOG build.
- → `architecture.md`

## Feature and section registration

```lua
ReUI.ClaretCore.RegisterFeature(id, function(scope) ... end, option)   -- returns ok, err
ReUI.ClaretCore.RegisterSettingsSection { id = 'x', title = 'X', titleKey = '...', descriptionKey = '...',
    inline = function(parent, layout) return editor end }             -- returns ok, err
```

- `scope`: `Own(control)`, `Defer(fn)`, `Bind(event, fn)`, `Guard(fn)`, `Every(control, seconds, fn)`.
- `inline` may return `CanLeave(intent, continuation)`; cancel calls `continuation(false)` and destroys nothing.
- Build remembered pages in `AfterParentShow`, not inside `inline`.
- → `architecture.md` § Feature registration, Settings section contract, Scope lifecycle

## Scale, geometry, depth

- Sizes from `Theme.Metrics`; layouter `FloorLayouter(scale)`; text size `scale / GetPixelScaleFactor()`.
- Apply UI scale exactly once. `layout.Scale` is a callable `LazyVar` — never multiply by it directly.
- Never persist screen coordinates; store logical values or nothing.
- Depths are live closures: `Depth:Set(function() return parent.Depth() + 80 end)`.
- Bands: content 0…+10, tooltips +60, overlays +80, dialogs +90…+100. Panel raise shifts depth ±1000.
- Verify at 0.75–1.5 UI scale, 1920×1080 and 2560×1440.
- → `ui-code.md`

## Theme quick reference

| Token | Value | Token | Value |
|---|---|---|---|
| `canvas` | `ff080c0a` | `accent` | `ff7a1f30` |
| `surface` | `ff141416` | `selected` | `ff32171f` |
| `raised` | `ff1b1b20` | `text` | `ffe8e8e6` |
| `border` | `ff343638` | `muted` | `ff929394` |
| `danger` | `fff06b7a` | `warning` | `fff0b64d` |

- Metrics: panel 1128×1110, compact Core 552×408, launcher 248 wide, padding 24, gap 16, rows 40, buttons 36, radius 8.
- Type: title 22, heading 18, body 16, button 15, secondary 14, label 13, caption 12, glyph 20.
- Binary settings always `Theme.SettingsSwitch`; panels `Theme.RoundedPanel` (returns `Resize(w, h)`).
- → `ui-visual.md`

## Menu

- All Claret settings: **F10 → Claret**, registered through `RegisterSettingsSection`; no ReUI Options tabs.
- Launcher 248 wide + standard panel; sections up to 1128×1110; compact Core 552×408.
- Menu key: action id `ClaretCore_OpenMenu`, default Ctrl+Alt+C assigned once if free; saved in the FAF key profile, never in a second option.
- Escape goes through the FAF stack (innermost first). Panels never take game keyboard focus; no global key handlers.
- → `menu.md`

## Hotbuild

- Profile keys: `ClaretHotbuildKeyboard` (pairs, source of truth), `ClaretHotbuildContexts` (v1–3), `ClaretHotbuild` (presets v1). FAF key maps are the mirror.
- Context order: units → empty → ACU/SACU/engineer → factory → silos → transport/mex/scout/other; "under cursor" first.
- Single dispatch choke point: `Adapter:CanBuild`; never issue build orders outside `Model:Execute -> Adapter:Build`.
- Placement: blueprint in `EntityCategoryGetUnitList(GetUnitCommandData({unit})[3])` **and** unit `COMMAND`/`SUBCOMMANDER`/`ENGINEER`.
- Factory queues only `record.kind ~= 'STRUCTURE'`; `EXTERNALFACTORY` goes to `GetCreator()`.
- Double press 0.5 s, one-shot; quick repeat 1.5 s, one-shot, legacy data.
- Template ids: `claret_template_<hash>` (composition/order/geometry), `claret_unit_template_<hash>` (members/order/counts). Never substitute another template.
- Malformed records are quarantined per record, never deleted.
- → `hotbuild.md`

## Orders and engine calls

- Production: `IssueBlueprintCommand('UNITCOMMAND_BuildFactory', id, count)`.
- `IssueBlueprintCommandToUnits` is a Lua helper with a hidden selection transaction — prefer `IssueBlueprintCommand`.
- Building placement is build **command mode** (`name = blueprintId`), not an order.
- After a factory order: `construction.RefreshUI`.
- Profiles: `Prefs.GetFromCurrentProfile(path)`, `SavePreferences()`; never write on open.
- → `engine.md`

## Localization and text

- `ReUI.ClaretCore.Localization.Text(key)`; every key in both `en` and `ru`; identical key sets.
- Game names from blueprints/`LOC`; pass the full blueprint, not a category table.
- Never `rawget(_G, 'ReUI')`. Logs in English.
- State never by colour alone. Long UTF-8 labels truncated safely with a full-text tooltip.
- → `glossary.md`, `ui-code.md` § Text

## Tests and shipping

```
node Tests/check-core.cjs --quiet          # full run, must be 0 failed
node Tests/check-core.cjs --only <name>    # focused
node .tools/faf-log.cjs                    # read the game log
```

- Static checks: `#`, `continue`, localization parity, Core must not import Hotbuild, version identity.
- Tests auto-discover `Tests/*.lua`; `-helper.lua` files are skipped.
- Ship only after the user confirms in game:
  `powershell -NoProfile -File .\Tools\Sync-ClaretMods.ps1 -Mod <ClaretCore|ClaretUI|ClaretHotbuild> -Paths '<path>'`
  then `git diff`, one commit, `git push origin dev`.
- → `testing.md`, `release.md`

## Top traps

1. `#` in Lua → empty module, misleading "nonexistent global variable".
2. Frozen depth → dialogs behind a raised panel.
3. Building UI inside `inline` before show → circular `Left`/`Top` chain.
4. Tooltip outliving its control → crash on hover.
5. `CanLeave` cancel that destroys state → lost draft.
6. Container taller than a shrunken panel → clicks swallowed below the window.
7. `layout.Scale` multiplied directly → panel fails to start.
8. `rawget(_G, 'ReUI')` → labels and registration break.
9. Passing a category table instead of a blueprint → wrong localized names.
10. Tests green ≠ UI works; rendering, input and orders need a real match.
- → `pitfalls.md`

## Reuse and licences

- MIT: 4z0t / FAF-UI-Mods (2022), TeamMouse (2026) — keep the notice.
- Everything else has no stated licence; owner decision allows reuse with credit, no assets. Original mods are disabled while the Claret equivalent is on.
- → `reference-mods.md`

## Where to go next

| Need | File |
|---|---|
| Exact API signature | `engine.md`, `reui.md` |
| How to wire a feature | `architecture.md` |
| Why a layout is wrong | `ui-code.md` |
| Exact colour/size | `ui-visual.md` |
| Menu behaviour | `menu.md` |
| Hotbuild rules | `hotbuild.md` |
| Prove it | `testing.md` |
| Ship it | `release.md` |
| Find a reference implementation | `reference-mods.md` |
| Native action id | `native-key-actions.md` |
| Known breakage | `pitfalls.md` |
