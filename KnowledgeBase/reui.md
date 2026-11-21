# ReUI reference

> **Answers:** what ReUI provides, which versions are installed, how loader/hooks/options/layout behave, licensing. **Read when:** an API is assumed but unverified, a hook does not chain, an option does not save, layout calls behave oddly. **Next:** `engine.md` for the engine side; `architecture.md` for registration.

ReUI is the external UI library Claret builds on. Installed versions (checked 2026-11-20): **Main 1.3.2, Core 1.7.0, Options 1.2.0**. Readable reference sources in `Context/sources/` are **Main 1.4.0 / Options 2.0.0** — a newer version, not proof of the installed behaviour. Installed ReUI UI files are partly bytecode; decompiled reference lives in `Context/reui-decompiled/`.

## Foundation decision

Claret builds **on** ReUI: Core owns feature registry, lifecycle, workload budgets, styling and diagnostics; it does not recreate ReUI's settings, layout or event systems. Reusable parts: hooks/UI phases, UI/Layouter and Controls, Options; WorldView, Grid, Units and Animation only as features need them. A full replacement was considered and rejected — no measured cost justified it, and it would add maintenance for FAF compatibility.

## What Claret uses

| Area | Used for | Module |
|---|---|---|
| Loader | dependency declaration, version constraints, load phases | `ReUI.Require`, `Core/Modules/Loader.lua` |
| Hooks | wrapping engine/module functions before UI creation | `ReUI.Core.Hook` |
| Options | reactive saved settings | `ReUI.Options.OptionValue`, `ReUI.Options.Mods[...]` |
| UI | layout, controls, views | `ReUI.UI` (`Layoutable`, `Layouter`, `FloorLayouter`, `Controls`) |
| Events | session events | `ReUI.Core.Events` |

Claret deliberately does **not** use ReUI Options tabs for its own settings: they live in F10 → Claret (`menu.md`). Option *values* are still ReUI `OptionValue`s.

## Loader

- `ReUI.Require{ 'ReUI.X >= a.b.c', ..., version = <FAF build>, enabled = true }` at the top of `Main.lua`.
- Parses `major.minor.revision` and compares with `>=`, `<=`, `>`, `<`, `=`, `==`.
- Detects a module loaded twice (possible cycle), records errors, checks dependency status. A `Main` error marks the module failed; dependent `Main` code does not run. Mod-type dependencies are matched by UID among active mods.
- `Wrap` loads modules, runs callbacks before `CreateUI`, calls the original, runs callbacks after, disposes. Pre/post callbacks run through `pcall`.
- Disabling a *mod* is not the same as disabling a *feature* in a loaded mod. A feature toggle needs its own lifecycle: stop timers, unsubscribe, destroy UI, clear state. `ReUI.Require` gives none of that — Core's `scope` does.

## Hooks

- `ReUI.Core.Hook(modulePath, field, function(previous) return replacement end)`.
- Accumulates hooks; before UI creation it reads the current member, passes it to the callback and writes back the returned replacement.
- **Registration after UI creation is prohibited.**
- No automatic conflict resolution and no hook removal. A chain works only if every participant calls the previous function and preserves its contract. Another mod can break the chain.
- Use for: engine functions (`/lua/ui/game/minimap.lua#ToggleMinimap`), mod module fields, painting brush subclassing (ReUI passes the previous value, which may be a class — subclass it with `Class(previousBrush){...}`).

## Options

```lua
ReUI.Options.Mods['ClaretCore'] = {
    selectionEnabled = ReUI.Options.OptionValue(true),
    language = ReUI.Options.OptionValue('auto'),
}
function Main() end
```

- `OptionValue(default)` — reactive value: `Get`, `Set`, `Save`, `Restore`, events `OnChanged`, `OnSaved`.
- `OnChanged` is an ordinary `Event`, not a `SafeEvent`: a throwing subscriber interrupts dispatch. Subscribers are responsible for their own cleanup.
- Values are stored under `UIModsOptions` with composite paths; older paths are migrated by reading `Prefs.GetFromCurrentProfile` and writing the new key.
- `OptionsWindow` saves on the Save button and restores on Cancel; a custom window must recreate live preview/cancel itself.
- `OptionControl` unsubscribes itself in `OnDestroy`; `Bind` calls the callback immediately once.

## Layout and controls

- `ReUI.UI` exports `Layoutable`, `BaseLayout`, `Layouter`, rounding variants. Controls extend Maui `Bitmap`/`Group`/`Text`/`Checkbox`; they are still game controls, not a new renderer.
- Layout is applied at creation and on explicit layout changes; there is no per-frame full-panel recalculation loop in the reviewed code.
- `FloorLayoutFor` / `RoundLayoutFor` are **shared instances** that store the current control. Do not retain a partial chain and do not use one instance across a yield.
- `DynamicScrollable.GetDataSize` traverses all data; `CalcVisible` walks from the start to the first visible row. Cost depends on list size and scroll position — relevant for thousands of rows, irrelevant for a settings container.
- An explicitly scaled layouter exposes `Scale` as a callable `LazyVar`. Use the layouter's sizing methods or `ScaleNumber`; multiplying by `layout.Scale` directly crashed the mex panel in Claret UI 0.2.50 (FAF3840 log, 2026-11-20).

## Frame work in ReUI

- `WorldView` wraps the game worldview class, calls `OnFrame` on enabled components, then the original. Frame updates are enabled for the main view.
- `Grid/Modules/AGridItem.lua` routes `OnFrame` to the active component and destroys components in `OnDestroy`.
- `Animation.Animator` enables frame updates on `Add` and disables them when the list empties; frames longer than 0.05 s are split into `ceil(delta/0.05)` substeps with no cap. Measure before blaming it.
- `Animator` is created in Animation's `Main`, i.e. **before** the original `CreateUI` — the project rule "no controls before CreateUI" is Claret's rule, not a universal ReUI property.

## Unit service

`ReUI.Units.Units` fetches a list on `Get`, refreshes on `GameTick` with `updateCacheTicks = 10` and `updateAllTicks = 50`, collects through a hidden `ALLUNITS` selection, removes dead units, adds focus objects, and resets the weak table on army change. It requires `Selection`, which requires `Options`.

Risk: `HiddenSelect` does not protect state restoration from a throwing callback — the remaining restore steps are skipped. Wrap callbacks passed through it.

## LINQ

Lazy iterators, enumeration objects, sorting, `ToArray`. Lazy chains do not always mean extra traversals, and are not proven faster than a specialised loop. A plain loop is acceptable in a Claret hot path.

## Licensing

- `sources/LICENSE`: MIT, copyright 2022 4z0t. Shared with the 4z0t mod family only as far as the file states.
- `LINQ.lua` header says copyright 2025 4z0t, all rights reserved — a mismatch with the root MIT notice. Clarify scope before copying or forking; keeping the notice is mandatory where reuse is allowed.
- A private fork of Core inside Claret would be a fork, not a dependency. Not recommended: shifts update maintenance to Claret and conflicts with the "write code from scratch" rule.

## Practical cautions

- ReUI versions in `Context/sources/` are newer than installed. Check an API against the installed version before relying on it.
- Standard ReUI Main also loads the QoL branch (Options, UI, LINQ). Enabling ReUI is never "only a small Core".
- ReUI does not provide runtime unload, hook priority, or a scheduler for spreading full scans across frames.
