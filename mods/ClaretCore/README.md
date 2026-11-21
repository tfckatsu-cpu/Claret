# Claret Core — test build 0.10.37

**Settings size** offers 100%, 125%, and 150% in the Core section. The default 125% keeps the original size. The saved size applies when the settings menu next opens and is capped to fit the screen.

Shared foundation for Claret, UID `claret-core-001`. Requires ReUI. Core works on its own and does not depend on Claret Hotbuild.

Claret UI exposes the minimap options under F10 → Claret → UI → Minimap. Manual minimap visibility remains under FAF control; automatic hiding does not save over that preference. The user confirmed the features and manual closing in game on 2026-11-20; compatibility with other minimap mods was not specified.

Provides a feature registry, lifecycle and resource management (`Own`, `Bind`, `Every`, `Guard`, `Defer`), and a selection composition diagnostics panel. The `probeEnabled` setting controls diagnostic log entries and is available under F10 → Claret → Core when ReUI developer mode is enabled; its previously saved value is preserved. The UI counter panel has been removed.

Text sizes and states come from `Theme.Metrics` (`text`, `secondaryText`, `buttonText`, `launcherText`, `title`, `heading`, `label`, `caption`, `glyph`) and `Theme.Colors.disabledText` / `accentPressed`; do not hardcode point sizes or state colours in screens. Shell panels use `Theme.RoundedPanel(control, layout, width, height, fill, border, shadow)` with `Metrics.panelRadius`; the corner, ring and shadow masks live in `textures/ui/`, carry baked canvas/border colours, and must be regenerated if the radius or those colours change.

The Claret interface follows the game language by default. To override it, choose **English** or **Russian** under F10 → Claret → Core → **Interface language**. The preference is saved, and open Claret windows update immediately without restarting the game.

## Experimental / deferred features (not wired)

`modules/Construction*.lua`, `modules/Orders*.lua`, `modules/Multifunction*.lua`, `modules/SelectionIgnore*.lua` and `modules/CargoSelection.lua` are an experimental, deliberately deferred implementation of a planned replacement for the ReUI construction, orders and multi-function HUD. They are not abandoned or broken code: the modules are preserved and covered by the local checks, and their tests stay in place.

No shipped session imports or registers them, so they never load in game (`import` is lazy). Wiring them — including an explicit ownership decision against `ReUI.Construction` — is outside the current scope and is a separate future step. Do not delete them as dead code.

## Connecting other mods

A separate mod declares a `ReUI.Require` dependency on `ClaretCore >= 0.10.0` and registers a feature with `ReUI.ClaretCore.RegisterFeature(id, start, option)`.

- `id` is unique for the session. Duplicate registrations are rejected.
- `start(scope)` is called after the UI is created when the feature is enabled.
- `option` is a reactive ReUI setting with a Boolean value. Core subscribes to it for the session and removes the subscription at the end of the session.
- Registration is allowed before the UI is created and is deferred. Registration after UI creation is applied immediately.
- Startup resources belong to `scope`; it is cleaned up when the feature is disabled, a handler fails, or the session ends.
- `GetFeatureState(id)` returns the registered feature's state, and also returns an error message on failure.

`ReUI.ClaretCore.UseSelectionHud(scope, refresh)` supplies the current selection and subscribes a HUD to FAF's `ObserveSelection` through Core. One HUD can use the feed at a time.

## Hotbuild is a separate mod

The editor, catalog, bindings, their profile, keyboard hooks, and actions are in the separate `ClaretHotbuild` mod. To use them, enable **ReUI**, **Claret Core (Test)**, and **Claret Hotbuild (Test)**, then start a new match. Hotbuild is always active; there is no menu toggle. Its editor is integrated into the main menu at F10 → Claret → Hotbuild. Documentation and test scenarios are in the ClaretHotbuild README.

## Separate menu — 0.6.0

Claret has its own entry in the in-game menu; its tabs have been removed from ReUI Options. The ReUI library dependency remains. Toggles apply and save immediately through the existing `OptionValue` objects, with no change to settings paths. The embedded Hotbuild editor occupies the Hotbuild section of the shared Claret menu; its draft is protected when changing sections or closing the menu. Closing the menu removes subscriptions and the Escape handler.

`ReUI.ClaretCore.RegisterSettingsSection(definition)` registers a section for a separate mod. Fields: a unique `id`, `title`, a short single-line `description`, `toggles = {{label, description, option}}`, `actions = {{label, open(parent)}}`, and/or `inline(parent, layout)`. `inline` creates the section content inside the shared window and returns a control with an optional `CanLeave(intent, continuation)` method. Before closing or changing sections, Core calls this method. It can return `true` to allow the transition immediately, or call `continuation(true)` after confirmation; `continuation(false)` cancels the operation. When opening a confirmation, the method can return `nil` to defer the decision. `intent` is the string `close` or `section`. Use `layout.scale` for geometry. The launcher and the separate settings panel use default dimensions from `Theme.Metrics` and share a scale that fits the screen. Inline-only pages can call `layout.setSize(width, height)` with logical content dimensions after the host is shown. Ordinary long settings lists are virtualized; embedded editors handle their own scrolling. In a mixed section, simple rows are virtualized while the embedded editor remains fully visible and stays in place when scrolling. For child windows registered through `actions`, `open(parent)` returns a window with `RequestClose()` and `OnDestroy`, owned by the passed `parent`. The section list on the left scrolls when there are more than six sections. Registration does not create UI; duplicate IDs and registration after the session ends are rejected. A new section appears the next time the menu is opened.

Test the editor under F10 → Claret → Hotbuild. Hotbuild is always active; a previously saved disabled value is ignored. Change a binding without saving and check draft protection on Escape/close, return to Claret, and reopen the editor. Check scaling, layers, mouse capture, the absence of Claret sections in ReUI Options, and Core running without Hotbuild installed. The user performs in-game checks in a new match.

## Verification status

Version 0.7.0: the menu opens with **Ctrl+Alt+C** if that combination is free on first launch. If it is occupied, automatic assignment is skipped. To change it, use F10 → Claret → Claret Core → **Change**, then press a combination; it is saved immediately. Escape cancels input; **Clear binding** removes the assignment while the F10 entry remains available. Occupied combinations are rejected without reassigning another action. The combination is saved in the standard FAF key profile; the **Open Claret Menu** action is also available in F1 under the Claret category. Pressing the binding while the menu is open does not create a second window or discard the Hotbuild draft.

The binding is implemented in `modules/MenuKey.lua` with the stable ID `ClaretCore_OpenMenu`. Profile assignments are changed through the keymapper, and active keys are updated only for this action. The shared key map is not reset. After a binding is cleared, its default is not assigned again in the next match. Keyboard capture ends when the menu closes or changes sections.

New local checks for the binding and its menu field passed, including conflicts with ordinary/debug keys and Hotbuild modifiers, cancel/change/clear flows, repeated initialization, preservation of other assignments, and recovery after save/update errors. The full suite still reports two previously known mismatches between the legacy `hotbuild-keys`/`hotbuild-runtime` checks and the current `Keys.lua`. In game, check opening from a match and replay, changing/clearing the binding, preventing game commands during capture, keyboard recovery after Escape and closing, persistence into a new match, changing it through F1, and preservation of other assignments.

The user confirmed the UI counter and the corrected selection panel in 0.2.1. The split into two mods and the extension API in 0.4.0 were checked locally; they still require a new match for verification in FAF.

From Claret Project, `node Tests/check-core.cjs` checks both mods: syntax and logic scenarios, including Core without Hotbuild, early/late feature registration, the separate Hotbuild entry point, and option persistence/migration. These are simulations, not engine runs.

The Claret visual style is defined in the project's `Context/ui-style.md`; the shared `Theme.lua` in Core 0.5.0 provides tokens to all modules. Hotbuild 0.10.41 requires Core >= 0.10.15.

Settings presentation (2026-11-10): toggle rows are fully clickable, show On/Off and a description, and display a save confirmation next to the row for 1.5 seconds. Sections use shared components and the theme. A hotkey is saved immediately after successful input; a conflict shows the occupied action and preserves the previous combination. An empty assignment disables the clear button. Tab/Shift+Tab move focus, Enter/Space activate, and Esc cancels capture or closes the menu. Focusing an input field transfers focus to the editor. Hotbuild is always active and cannot be disabled through the menu. The appearance and actual input still need in-game verification in FAF; local checks are not in-game screenshots.

Long messages and multiple assigned combinations may be shortened in a row; the full text is available in the standard tooltip. “Saved” disappears after 1.5 seconds without a fade. Large registered lists of simple settings scroll inside the fixed panel; embedded editors handle their own scrolling.

## History: Core 0.8.0 and Hotbuild 0.7.0

The Hotbuild section shows its editor inside the shared Claret window. The button for opening a separate editor has been removed. The current menu has a fixed large size; closing it or switching sections is protected against losing an unsaved draft.

Integration: `definition.inline(parent, layout)` returns a child control with `CanLeave(intent)`; the shared scale is provided as `layout.scale`. Core calls `CanLeave` before closing or changing sections so an editor can request confirmation when it has a draft. The separate-window mode through `actions` remains available for other sections.

## History: Core 0.9.0 — former large window

The menu is always large: one geometry of 1368×1320 before the shared screen scale, used by every section. Its size does not change when switching between Core and Hotbuild. The interface is then fitted to the screen so the window stays within its bounds. The map is not dimmed behind the menu; the transparent area outside the window captures clicks without closing it or issuing game commands. Close with the **Close** button or Escape, with the existing protection for unsaved drafts.

## Core 0.10.0: selective transport unloading action

Core provides `ReUI.ClaretCore.AppendTransportCargo(selection)` for Hotbuild multifunction bindings. It adds one already-loaded mobile unit at a time to FAF's standard selective-unload list and plays a sound. The action prepares the selection for a later unload command; it does not issue the command itself. The step state resets when the selection or cargo changes. Core does not clear the shared additional selection list, so it does not affect other UI modules' selections. Displaying marked passengers in the bottom HUD has not been implemented. The function does not require ReUI.Construction or ReUI.Actions; Claret Core itself still requires ReUI.

In a new match, test a transport with one or more loaded mobile units: invoke the action repeatedly and confirm that it selects the next unit each time, that the step resets after changing the transport/selection or cargo, and that the standard selective unload uses the prepared selection. Check cargo visibility and highlighting, reuse after unloading, and interaction with other actions that use the additional selection list. Local checks do not confirm the engine's display or behavior.

## Installing Nunito

Copy `Nunito-Regular.ttf` and `Nunito-SemiBold.ttf` from `ClaretCore/fonts/Nunito` to the original Forged Alliance installation's `fonts` folder, beside its `bin` folder. Fully close and restart the game after copying. Nunito is optional and the interface falls back to the default font.

The original TTF files and SIL OFL 1.1 notices remain in `fonts/Nunito`. To uninstall manually, remove only these two files from the game's `fonts` folder.

`ReUI.ClaretCore.IsKeyCaptureActive()` reports whether settings are temporarily capturing a key combination; it returns `false` after saving, cancelling, or destroying the menu.

## Strategic rings

Core draws rings for two Hotbuild keyboard actions. `CreateStrategicRing(false)` creates the available scouting, weapon, shield, stealth and blast radii for the object under the cursor; `CreateStrategicRing(true)` creates its vision radius. Overlapping flat radii of the same kind merge into one outline. FAF stock eraser (Alt+RMB) removes the ring group of an object. The implementation lives in Core and does not require Bi4UI.StrategicRings.
