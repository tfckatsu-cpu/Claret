# Claret architecture and extension contracts

> **Answers:** which mod owns what, how to register a feature/section, scope cleanup, cross-mod APIs, working skeletons. **Read when:** adding a mod, feature, option or section; deciding where code belongs; cleaning up on disable. **Next:** `ui-code.md` for patterns; `menu.md` for the shell; `testing.md` to prove it.

## Mod split

| Mod | UID | Role | Depends on |
|---|---|---|---|
| Claret Core | `claret-core-001` | feature registry, lifecycle/scope, menu shell and keybind, theme tokens, localization service, diagnostics, selection feed, strategic rings, transport-cargo helper, minimap options | ReUI (Core, Events, UI, Options) |
| Claret UI | `claret-ui-001` | game-interface features: notifications, ACU health, selection HUD, unit rings preview, mex panel, reveal positions, InfoShare, engineer indicators | ClaretCore, ReUI |
| Claret Hotbuild | `claret-hotbuild-001` | hotbuild presets, contexts, keyboard pairs, dispatch, editors | ClaretCore >= 0.10.15, ReUI |

Dependency direction is one-way: **Core never imports Hotbuild or Claret UI**; Hotbuild and Claret UI never import each other. The test runner fails the build if Core imports Hotbuild. Claret UI fills the `ui` placeholder section Core reserves in the launcher.

Version identity (enforced): `Version` in `Main.lua` = `ReUI` value in `mod_info.lua` = README heading; `BuildStamp` = newest CHANGELOG build.

## Session flow

1. `Options.lua` registers `ReUI.Options.Mods['<Mod>']` values (defaults only, no UI).
2. `Main.lua` declares `ReUI.Require{...}`, defines `Main(isReplay)`.
3. `Main` imports modules, registers localization tables, installs hooks, registers features and settings sections.
4. Core initialises the keybind and registers the F10 entry inside `ReUI.Core.OnPreCreateUI`, so both exist when the interface appears; the menu object itself is created earlier.
5. Features start when their option is true, receive a `scope`, and are torn down when disabled or when the session ends.

## Feature registration

```lua
local featureOk, featureError = ReUI.ClaretCore.RegisterFeature('claretui', function(scope)
    service:Start(scope)
end, options.enabled)
if not featureOk then error(featureError) end
```

- `id` is unique for the session; duplicates are rejected.
- `start(scope)` runs after UI creation when the feature is enabled.
- `option` is a reactive ReUI Boolean `OptionValue`; Core subscribes for the session and unsubscribes at the end.
- Registration before UI creation is deferred; after UI creation it applies immediately.
- Resources created in `start` must be registered on `scope`.
- `ReUI.ClaretCore.GetFeatureState(id)` returns state and an error message on failure. States: `disabled`, `running`, `error`, `disposed`.

## Scope lifecycle

`scope` is created fresh per start; callbacks from older runs cannot leak in.

| Method | Purpose |
|---|---|
| `scope:Own(control)` | destroy the control on cleanup; returns it |
| `scope:Defer(fn)` | run `fn` on cleanup (reverse order) |
| `scope:Bind(event, fn)` | `event:Add` a guarded handler and `event:Remove` it on cleanup |
| `scope:Guard(fn)` | wrap a callback so `pcall` failures disable the feature instead of throwing into the engine |
| `scope:Every(control, interval, fn)` | accumulator on `control.OnFrame`; runs at most every `interval` seconds, no catch-up after a long frame; stops frame updates on cleanup |

Rules:
- Never keep a reference to a scope after cleanup; assert `not self.closed` in `Defer`.
- `Every` exists for throttled work, not polling. Prefer events (`OnChanged`, selection feed, key press, open).
- A failing guarded callback disables the whole feature and reports `feature failed: ...`. That is intended: half-dead features are worse than a clean stop.

## Settings section contract

```lua
local ok, err = ReUI.ClaretCore.RegisterSettingsSection {
    id = 'ui',
    title = 'UI',
    titleKey = 'claretui.section.title',
    descriptionKey = 'claretui.section.description',
    toggles = {{label = '...', description = '...', option = options.someBool}},
    actions = {{label = 'Open', open = function(parent) return window end}},
    inline = function(parent, layout) return UiSection.Create(parent, layout, options, coreOptions) end,
}
```

- `id` unique; registration does not create UI; duplicates and late registration (after session end) are rejected. A new section appears the next time the menu opens.
- `inline(parent, layout)` returns a control with optional `CanLeave(intent, continuation)`:
  - return `true` → allow immediately;
  - return `nil` → decision deferred, call `continuation(true|false)` later;
  - `continuation(false)` must cancel without destroying anything.
  - `intent` is `'close'` or `'section'`.
- `layout.scale` is the shared scale; use it for every dimension.
- `layout.setWidth(innerWidth)` — inline content width; Core adds 48 logical units of panel insets.
- `layout.setSize(innerWidth, innerHeight)` — inline-only page; Core adds 48 horizontally and 124 vertically.
- `layout.setSize(w, h, {split = n, left = ..., right = ...})` — master-detail columns; the empty part of the bounding rectangle passes pointer input through to the game.
- `editor:OnResize(innerWidth, innerHeight)` — called by Core when the panel resizes.
- Build remembered pages in `AfterParentShow`, **never inside `inline(...)`**: building an embedded editor while the panel is hidden leaves size-only Maui controls with a circular `Left`/`Top` chain (circular lazy-evaluation error in the game log).
- `toggles` rows are fully clickable, save immediately and show "saved" for 1.5 s. Simple lists are virtualized; embedded editors handle their own scrolling.

## Localization

```lua
local Localization = ReUI.ClaretCore.Localization
local ok, err = Localization.Register('claretui', tables)  -- tables = { en = {...}, ru = {...} }
Localization.Text('claretui.section.title')
```

- The service lives in Core; every mod registers its own table under its own prefix.
- Keys must exist in **both** `en` and `ru` with identical key sets; the runner checks this statically.
- The interface language follows the game by default; override in F10 → Claret → Core → Interface language. A change applies to open Claret windows without restart (one-frame defer).
- Game names come from blueprints/`LOC`, never from Claret tables. Never `rawget(_G, 'ReUI')`.
- Logs stay English.

## Cross-mod services in Core

| API | Purpose |
|---|---|
| `RegisterFeature(id, start, option)` | feature with lifecycle |
| `RegisterSettingsSection(definition)` | F10 → Claret section |
| `Localization.Register/Text/SetLanguage/GetLanguage` | strings |
| `IsMenuOpen()` | a Claret panel is open |
| `IsKeyCaptureActive()` | settings are capturing a combination |
| `UseSelectionHud(scope, refresh)` | subscribe to Core's selection feed; one owner at a time |
| `AppendTransportCargo(selection)` | add one loaded mobile unit to FAF's selective-unload list; does not issue the unload |
| `CreateStrategicRing(visionOnly)` | ring group for the object under the cursor; stock eraser removes it |
| Theme (`Theme.Colors`, `Theme.Metrics`, `Theme.Fonts`, `RoundedPanel`, `SettingsSwitch`) | visual tokens and components |

## Data ownership

- Core: `ClaretCore` option keys (ReUI Options), Core menu keybind action `ClaretCore_OpenMenu`.
- Hotbuild: `ClaretHotbuild`, `ClaretHotbuildContexts` (v1–3), `ClaretHotbuildKeyboard` (v1–2). The keyboard pairs are the single source of truth; FAF key maps are its mirror.
- Claret UI: `ClaretUI` option keys only (state, no key bindings of its own except action ids it registers).
- Nobody writes another mod's keys. Nobody rewrites `UserKeyMap` wholesale.

## Recipes

### New leaf mod

```lua
-- Main.lua
Version = '0.1.0'
local BuildStamp = 'YYYYMMDD-1'
LOG('[Claret][build] x='..Version..' stamp='..BuildStamp)
ReUI.Require { 'ClaretCore >= 0.10.27', 'ReUI.Core >= 1.7.0', 'ReUI.UI >= 1.0.0', 'ReUI.Options >= 1.2.0', enabled = true, version = 3816 }

function Main(isReplay)
    local Localization = ReUI.ClaretCore.Localization
    local stringsOk, stringsError = Localization.Register('x', import('/mods/X/modules/LocalizationStrings.lua').Strings)
    if not stringsOk then error(stringsError) end
    local options = ReUI.Options.Mods['X']
    local ok, err = ReUI.ClaretCore.RegisterFeature('x', function(scope)
        import('/mods/X/modules/Runtime.lua').Create(isReplay, options):Start(scope)
    end, options.enabled)
    if not ok then error(err) end
end
```

### Hooking an engine function

```lua
ReUI.Core.Hook('/lua/ui/game/minimap.lua', 'ToggleMinimap', function(original)
    return function()
        if import('/lua/ui/game/gamemain.lua').gameUIHidden then return original() end
        local result = original()
        minimap:ManualToggle()
        return result
    end
end)
```

### Reading a saved option safely

```lua
local ok, value = pcall(function() return options.selectionPosition:Get() end)
if not ok or type(value) ~= 'table' then value = {} end
```

## Adding a feature: checklist

1. Owner document updated first (`Context/` owner, then this file if the rule is new).
2. Option added to `Options.lua` with a safe default; no UI before the interface exists.
3. Feature registered with a stable id; all controls, events and timers on `scope`.
4. Strings registered in `en` and `ru`; numbers from `Theme.Metrics`.
5. Test added or extended (`testing.md`), full run green.
6. Version identity bumped (`release.md`).
7. In-game check by the user; then sync, commit, push.
