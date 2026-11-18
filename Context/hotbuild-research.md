# ReUI.Hotbuild Research for the Claret Prototype

Review date: 2026-11-10. Source inspection only; not tested in FAF. No original code was copied.

## Scope and versions

Fact: the supplied `sources/MainMods/ReUI.Hotbuild/mod_info.lua` has manifest version 1, UID `reui-Hotbuild-1.1.0`, ReUI tag `ReUI.Hotbuild=1.1.0`, author 4z0t. Main implementation is readable in `Hotbuild.lua`, not `Main.lua`. Requirements include Core >=1.2.0, Actions >=1.3.0, LINQ >=1.4.0, UI >=1.4.0, Options >=1.0.0, and additional UI modules (`Hotbuild.lua:1–14`).

## Execution

Confirmed from `Hotbuild.lua`:

- `:105–172`: production gets the third result of `GetUnitCommandData(selection)` as the available-blueprint category; it converts this using `EntityCategoryGetUnitList` and checks the exact ID. It always chooses the first applicable entry. Ordinary press issues count=1; the original uses count=5 with Shift. The Claret requirement is one unit per press, so do not copy the multiplier automatically.
- `:144–165`: normal production uses `IssueBlueprintCommand` with `UNITCOMMAND_BuildFactory`, blueprint ID, and count. External factories need special handling: the original replaces EXTERNALFACTORY with `GetCreator()`, removes duplicates, and uses `IssueBlueprintCommandToUnits`. Do not treat this edge case as verified for a prototype until implemented/tested.
- `:169`: after issuing an order, it calls `construction.RefreshUI`.
- `:178–220`: building placement checks available blueprints, clears active build templates, then enables build command mode with `name=blueprint ID`. This enters placement mode; it does not issue an order to build at an arbitrary point.
- `:223–248`: selection context is chosen by whether suitable mobile engineers are present; if so, use building actions, otherwise production actions. This is the original's rule, not a required Claret rule.
- `Modules/CycleMap.lua:168–201`: the original cycles building entries; Alt reverses the direction. `Hotbuild.lua:132–139` sets production `maxPos=1`. Claret's user-approved design uses top-to-bottom order and the first applicable action, so cycling is not needed unless separately agreed.

Unknown: what the engine considers available for mixed selections and how an order is distributed across several factories. A specific factory can be checked for buildability using a one-unit list, but do not secretly change selection to do it. In-game checks proposed: UEF T1 air scout, unsuitable factory, mixed factories, and external factories.

## Catalog and list behavior

Fact: `Modules/model.lua:43–52,104–151` limits the catalog to BUILTBY categories for engineers/factories/commander/gate, grouped as Construction/Land/Air/Naval/Gate and four factions. Blueprint IDs are sorted by substring starting at the fourth character (`:137`), not by display name or role.

Fact: `Modules/views/BlueprintItem.lua:49–60` includes an image, blueprint ID, and localized `Interface.HelpText`; therefore the claim that source has no labels at all is incorrect. However, the user found the labels inconvenient or hard to see, which is a valid requirement for a new interface. In the original, ID and HelpText use small 10 pt text on a 192×64 item (`:7–8,30–37`).

Fact: `Modules/views/view.lua:242–316` shows only seven selector rows by default and uses a prebuilt array. No search by name/ID or explicit role/tech sorting was found in this selector.

Recommendation: build a new catalog from `__blueprints`; read ID from the key/BlueprintId; handle missing General.UnitName/Description/Interface.HelpText; show icon + name + role + ID; sort consistently, with ID as the final key. Store only IDs, not localized labels or row indices.

## Context actions

Fact: `sources/ReUI/Actions/Actions.lua` (Version 1.3.0) has a separate `CategoryMatcher`/`CategoryAction` mechanism. `:148–154` stops after the first successfully handled item; `:192–202` default matcher requires a category match across the whole selection and also supports a custom predicate. `:216–239` a matched item can run one or more commands/functions. This documents behavior; Claret uses its own registry with stable action IDs rather than copying ReUI classes.

Recommendation: separate the future action catalog from bind lists: ID, display label, context applicability, and executor. Preserve unknown action IDs as unavailable; do not replace them with another action or delete them without user request.

## Keyboard: API review

Source: [official keymapper.lua develop](https://raw.githubusercontent.com/FAForever/fa/develop/lua/keymap/keymapper.lua), reviewed 2026-11-10; this is not a pinned FAF 3840 snapshot.

Fact: `SetUserKeyAction(id, table)` registers an action; nil removes it. `SetUserKeyMapping(key, oldKey, actionID)` assigns a key; `oldKey` may be nil. `ClearUserKeyMapping(key)` clears an assignment. `GetCurrentKeyMap` returns key→actionID; `GetKeyMappingDetails` provides ID, name, category, and actionTable. `NormalizeKeyBinding` normalizes modifier order. `GetKeyMappings` builds a new key→actionTable map. Prefer checking ownership by stable actionID, not table reference equality.

Fact from local examples: `sources/MainMods/Bi4UI.StrategicRings/hook/lua/ui/game/gamemain.lua:24–38` removes the old action and updates runtime through `IN_ClearKeyMap`, `IN_AddKeyMapTable` with current mappings, and `hotbuild.addModifiers`. `sources/MainMods/cinematics/modules/hotkeys.lua:50–77` temporarily removes a key set using `IN_RemoveKeyMapTable` with `key=true` and restores the corresponding bindings.

Lifecycle recommendation: save assignment through the native keymapper and make `Runtime.Execute` check enabled/live session/replay state. When disabled, the action does nothing but the user assignment remains. Temporarily removing the entire key with `IN_RemoveKeyMapTable` is not enough: F1 or another rebuild restores the saved assignment. Do not erase prefs on every disable.

Conflict recommendation: normalize the entered combination and existing assignments; reject saving if another action owns the key and show its name. Do not automatically assign E or silently replace a standard action. Custom action names must be stable and unique, without a hyphen: `GetKeyActions` drops action IDs containing a hyphen.

Unknown: whether a separate API exposes the active engine keymap owner; do not promise there is no race with a mod that changes runtime bindings directly. Check F1, chat, modal windows, and replay mode in-game.

## UI available in the installed version

Confirmed local example: `Hotbuild.lua:251–257` calls `ReUI.Options.Builder.AddOptions` with a callback receiving parent. `Modules/views/view.lua:1–15,39–130` builds an editor using standard Maui Group/Bitmap/Button/Edit, Combo and Popup, LayoutHelpers, and ReUI.UI.FloorLayoutFor. This supports a separate window without requiring ReUI.Options 2.0.0. Installed Options 1.2.0 is binary; do not attribute the newer `Options.Window` API to it.

Fact: `UIUtil.SetupEditStd` is used for standard Edit in `view.lua:108–116`; Combo:AddItems/OnClick at `:119–130`; a standard button sets OnClick. These signatures are observations of local use, not independent guarantees for every new window.

## Persistence

Fact: the original stores profile data under `hotbuildoverhaul`, reads/writes through Prefs, and calls SavePreferences on explicit save (`Modules/model.lua:180–220`). Compilation iterates category/faction tables; for a new priority order, store a dense array of action rows and do not rely on dictionary iteration order.

Suggested user check for Claret: bind E to the exact T1 air scout blueprint with an eligible air factory selected and confirm one order; with an ineligible selection, confirm it does not issue another order. Context actions are tried top-to-bottom until the first applicable one. Invalid/future actions remain visible as unavailable. On key conflict, saving is rejected without replacing the prior owner. Disabling Hotbuild stops execution but does not erase saved assignment.

## Clarification: runtime-only approach

Under the primary agent's direction, the prototype may store assignments only in Claret prefs and apply a temporary runtime map without changing UserKeyMap/UserKeyActions. This is an alternative to the native persistence approach above and better supports fully disabling the feature. On each apply, reject natively occupied keys and automatically generated hotbuild modifiers. When removing the temporary map, restore current native entries only for affected keys. A service action can be provided directly in the `IN_AddKeyMapTable` table; saving through `SetUserKeyAction` is not required.

Fact from [official keybindings.lua develop](https://raw.githubusercontent.com/FAForever/fa/develop/lua/ui/dialogs/keybindings.lua): public `CloseUI` (`:497–503`) closes the popup; `OnClosed` (`:531–533`) calls local `ConfirmNewKeyMap` (`:62–70`), which rebuilds runtime bindings. The button, Escape, shadow, and reopen paths use `CloseUI`. Therefore Claret could reapply temporary assignments after original `CloseUI` and recheck conflicts. `ConfirmNewKeyMap` is local and cannot be hooked as a module field through `Core.Hook`.

Fact from [official Popup](https://raw.githubusercontent.com/FAForever/fa/develop/lua/ui/controls/popups/popup.lua): `Close` (`:51–54`) synchronously calls `OnClosed` before `Destroy`. This supports the sequence “original CloseUI → update Claret” without a timer. Both sources are from develop; equivalence with FAF 3840 is unverified.

Limitation: such a hook does not catch arbitrary runtime keymap rebuilds by other mods. An API for reading the actual runtime owner is unconfirmed; `GetKeyMappings`, which reflects native prefs, cannot reliably identify conflicts with another mod's temporary overlay. This limitation must be stated in game-check instructions.

## Confirmation on Local FAF 3840

After online review, the installed archive `C:/ProgramData/FAForever/gamedata/lua.nx2` was found. It was read as a ZIP in memory, without extraction or modification. `C:/ProgramData/FAForever/.faf_build.json` reports resolvedVersion=3840; internal `lua/version.lua` reports Version 3840, GameType FAF, commit `d0f37b8a19aa1e6986edbe009a43652a25b37ab6`. This updates the earlier “target snapshot not checked” note for the files listed below.

Confirmed in `lua.nx2`:

- `lua/ui/dialogs/keybindings.lua:541–547`: `CloseUI` is public. `:578–580`: `OnClosed` calls `ConfirmNewKeyMap`. `:70–78`: confirmation rebuilds the runtime map and hotbuild modifiers.
- `lua/ui/controls/popups/popup.lua:59–61`: `Close` calls `OnClosed` synchronously, then `Destroy`. A `CloseUI` hook after the original is suitable for reapplying the overlay without a timer in installed FAF 3840.
- `lua/keymap/keymapper.lua`: `GetCurrentKeyMap` (`:91`), `SetUserKeyMapping` (`:134`), `SetUserKeyAction` (`:235`), and `NormalizeKeyBinding` (`:349`) are present with the described contracts.
- `lua/userInit.lua:364–370`: `GetUnitCommandDataOfUnit(unit)` uses a one-entry cache table and `GetUnitCommandData`, without changing selection.
- `lua/userInit.lua:373–390`: `IssueBlueprintCommandToUnits` is not a direct engine call on an arbitrary array. It is a Lua helper with hidden temporary selection changes, command-mode caching, and restoration. An exception between these operations can interrupt restoration; there is no separate guard here. For ordinary production on current selection, use direct `IssueBlueprintCommand`; introduce extra targets deliberately.
- `lua/ui/game/construction.lua:1445–1458`: native UI uses this helper for EXTERNALFACTORY and issues ordinary orders against the current selection.

Important: adjacent `lua.nx4` contains FAF Beta Balance 3839; do not treat it as the target version. This inspection did not establish other mount paths or active runtime overlays from other mods.
