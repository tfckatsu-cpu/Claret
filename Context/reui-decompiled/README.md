# ReUI: Bytecode Recovery and Implementation Map

Reviewed 2026-11-13. Per user clarification, scope is limited to the installed `ReUI` / `ReUI.*` family. These are reference materials for study; they are not imported by Claret and do not replace mod files. Claret HUD replacement work was not part of this task.

## Snapshot and Results

Nine family mods and 160 Lua files were found in the adjacent `mods/` directory: 92 compiled and 68 text files. Original sizes, SHA-256, manifests, and per-file recovery results are in [manifest.json](manifest.json). Readable sources are not duplicated; their current originals remain in `../../../mods/`.

| Installed mod | Manifest / Main version | Bytecode | Text Lua | Contents |
|---|---|---:|---:|---|
| ReUI | Main 1.3.2; Core 1.7.0; Options 1.2.0 | 53 | 22 | Loader, hooks, classes, events, settings, UI, grids, units |
| ReUI.ActionsPanel | 1.1.3 | 4 | 2 | Context action grid and extension registration |
| ReUI.Construction | 1.3.0 | 0 | 21 | Construction panel replacement, tabs, queues, cargo |
| ReUI.Construction.Templates | 1.0.0 | 4 | 2 | Build/factory template integration and previews |
| ReUI.Economy | 1.2.0 | 4 | 2 | Economy panel and resource indicators |
| ReUI.Hotbuild | 1.1.0 | 0 | 10 | Build hotkeys; source is already readable |
| ReUI.MissilePanel | 1.0.0 | 0 | 3 | Missile panel; source is already readable |
| ReUI.Reclaim | 1.2.1 | 0 | 3 | Reclaim UI; source is already readable |
| ReUI.Score | 1.2.4 | 27 | 3 | Scoreboard, resources, sharing, observer/replay views |

Result: **92/92 files decompiled**, **92/92 disassemblies matched byte-for-byte after round-trip assembly**, **0 unknown instructions**, **0 processing errors**. All 92 Lua outputs also passed luaparse syntax parsing in 5.1 mode; a repeat SHA-256/size check found no change to the 160 source files. `sourceStatus=success` means the decompiler exited successfully; it does not prove Lua execution equivalence.

## How to Read the Results

- `ReUI/.../*.lua` and similar folders for other mods contain automatically recovered Lua without original comments/formatting. The original SHA-256 is recorded at the top.
- Adjacent `*.disasm` files list functions, constants, locals, upvalues, and instructions with source-build line numbers. Use them as the verifiable lower-level view when decompiler output is ambiguous.
- `*.error.txt`, if present, records why recovery was incomplete; it is not a recovered source file.
- [index.md](index.md) lists each file. Full machine results are in the manifest.

## Inside ReUI

### Loading, lifecycle, classes, and events

`ReUI/Core/Modules/Loader.lua` parses module names and semantic versions, dependencies, and version limits; it manages loading and callbacks before/after UI creation. This is ReUI infrastructure, not code for one HUD.

`ReUI/Core/Core.lua` provides `Hook`, `HookModule`, `OnPreCreateUI`, `OnPostCreateUI`, weak tables, `Class`, `Property`, and string utilities. Hooks are collected and then installed through a callback before UI creation. At installation it reads the current module function and passes that function and the module to the callback. After UI creation, `Hook` is replaced with an erroring function for late registration. A future Claret replacement should register before UI creation, while controls themselves are created during normal UI construction.

`Core/Modules/Class.lua` implements classes/properties with metatables; `Core/Modules/String.lua` provides string operations. `Core/Events.lua` contains events and handler management, separate from FAF's native `ObserveSelection`.

### Containers, iteration, and selection

`ECS/ECS.lua`, `ECS/Modules/ComponentContainer.lua`, and `ALazyComponentContainer.lua` provide component containers, including lazy creation. `LINQ.lua` contains collection enumeration, filtering, transformation, and result chains. Grids/context handlers use these modules; there is no need to port all of LINQ into Claret for one marker.

`Selection/Selection.lua` contains a selection-change handler manager (`Process`, `Get`, `Add`, `Remove`, `GetHandlers`); `Selection/Options.lua` contains its settings. This is not a visual replacement for the bottom panel.

### Settings

`Options/Options.lua` creates module settings, connects them to the profile, and handles old storage paths. `OptionRef.lua` addresses profile values; `ReactiveOption.lua` provides reactive values and change events. `OptionsWindow.lua`, `OptionsMenu.lua`, `OptionControl.lua`, `Selector.lua`, `StringSelector.lua`, and `TextEdit.lua` implement the window and editors. This is ReUI's mechanism; under current rules, Claret keeps its own menu.

### UI, scaling, and grids

`UI/UI.lua` and `UI/Controls/Controls.lua` assemble the control API. `UI/Modules/Layoutable.lua`, `Layouter.lua`, and `LayoutFunctions.lua` handle layout. `UI/Animation/Animation.lua` and `UI/Color/Color.lua` provide animation and color operations; `UI/QoL/Options.lua` defines auxiliary UI settings.

`UI/Views/Views.lua` exports `WindowFrame`, `GlowBorder`, `Button`, `Brackets`, `CollapseArrow`, `EscapeCover`, `StaticScrollable`, and `DynamicScrollable`. `UI/Widget/Widget.lua` is a separate widget wrapper.

`UI/Views/Grid/Grid.lua` assembles the grid API. Its `Modules/` include abstractions `AGridItem`, `AItemComponent`, `ASelectionHandler`, `HandlerTemplate`, and base implementations `BaseGridItem`, `BaseGridPanel`, and `Grid`. The panel design separates the visible cell, action handler, and component that renders data and receives events. ActionsPanel and Construction use the shared foundation but are separate panels.

### Actions, units, and world view

`Actions/Actions.lua` connects named actions to FAF's keymapper and handles actions on selection. It registers and executes actions; it is not the visual ActionsPanel.

`Units/Units.lua`, `Units/Enhancements/Enhancements.lua`, and `Units/Modules/Overlay.lua` provide unit operations, upgrade chains, and overlays. Units includes a cache with 10/50 GameTick intervals and `HiddenSelect`, which temporarily saves command mode/selection, ignores selection events, performs an operation, and restores state. Full collection uses `UISelectionByCategory("ALLUNITS", ...)`; this does not prove access to hidden enemy data. Performance was not measured.

`WorldView/WorldView.lua` wraps `/lua/ui/controls/worldview.lua` and routes `HandleEvent`, `OnFrame`, `OnUpdateCursor`, and destruction to components. `Modules/WorldViewComponent.lua` and `WorldView/Options.lua` provide component foundations/settings. This API's existence does not prove a future Claret overlay is compatible with other mods; check the specific lifecycle.

## Separate Family Panels

### ReUI.ActionsPanel

`Main.lua` registers extensions through `AddExtension`, saves active state in `ReUIActionsPanel_extensions`, creates `ActionsGrid` after UI creation, and subscribes it to `gamemain.ObserveSelection`. It recalculates panel position after native `gamemain.SetLayout` and places it by `construction.controls.constructionGroup`.

`Modules/ActionsGrid.lua` loads extension handlers, gets actions for current selection, sorts them, assigns cell components, updates the grid, and handles scrolling. `Modules/Selector.lua` and `Options.lua` handle extension selection and grid settings. ActionsPanel does not restore Construction tabs or queues.

### ReUI.Construction.Templates

`Templates.lua` integrates templates with Construction; `BuildTemplatePreview.lua` and `FactoryTemplatePreview.lua` render previews; `Options.lua` contains settings. Investigate this mod separately if preserving templates in a custom panel: supporting BuildOptions alone is insufficient to claim a complete replacement of native functions.

### ReUI.Economy

`Main.lua` replaces `economy.CreateEconomyBar`, creates EconomyPanel, stores it in `module.GUI.bg` and `ReUI.UI.Global.EconomyPanel`, and updates through `gamemain.AddBeatFunction`. Hooks for ToggleEconPanel, InitialAnimation, and SetLayout manage the panel. `Modules/Panel.lua` implements the economy UI; `Modules/StatusBar.lua` is a resource indicator; `Options.lua` holds settings. This is a separate HUD area, not part of the cargo grid.

### ReUI.Score

`Main.lua` loads the mod; `Modules/ScoreBoard.lua` is the main scoreboard. `ArmyView.lua`, `ArmyViewsContainer.lua`, and `TeamViewsContainer.lua` assemble army/team views. `ResourceDisplay.lua`, `InfoPanel.lua`, `TitlePanel.lua`, `ObserverPanel.lua`, `ReplayDataPanel.lua`, and `DataPanelConfig.lua` handle resources, titles, info, observers, and replay data. `ShareManager.lua` handles sharing; `Utils.lua` and `Animations.lua` provide helpers.

`Modules/Layouts/` contains separate game/replay frames. `Modules/Views/` contains Border, BorderedButton, BorderedCheckBox, BorderedText, ColoredSlider, ExpandableGroup, ExpandableSelectionGroup, and PingAnimation. `Options.lua` holds mod settings. These files were documented for the requested family, but are not automatically relevant to construction HUD replacement.

## Native Construction Panel and Cargo Marker Mechanism

This section uses readable installed `mods/ReUI.Construction`, not decompiler output.

1. `Construction.lua:1391` creates a HookModule for `/lua/ui/game/construction.lua`. The `SetupConstructionControl` hook (around line 1490) creates `ReUI.Construction.Panel(parent)`, stores it in `module.controls.constructionGroup` and `ReUI.UI.Global.Construction`, and returns the panel. This replaces the construction UI creation point.
2. `OnSelection`, `OnQueueChanged`, `RefreshUI`, `Expand`, `Contract`, `SetLayout`, `updateCommandQueue`, and `setIdRelations` are routed to the new panel/handlers. The handler list around lines 879–940 separates BuildOptions, BuildOptionsFactory, UpgradeChain, SelectedUnits, Enhancements, QueueList, BuildQueue, TransportCargo, and CarrierCargo. Tabs/queues are not automatically retained from the old UI; their behavior is in the corresponding components.
3. `Modules/Components/TransportCargo.lua` stores `cargoUnits` and a set of marked units, `units`. `AddUnit` marks the unit and calls `AddToSessionExtraSelectList`. `SetCargo` also checks `HasUnloadCommandQueuedUp`.
4. The cargo component's `Enable` checks `context:Enabled(index)` and calls `item:DisplayBPID(id, "down")` for a marked passenger. `Modules/Views/Item.lua` selects the native `_down.dds` texture. The visible mark is part of the cell itself.
5. The `Append unit for transportation` action at the end of `Construction.lua` gets TransportCargoHandler, adds the passenger, and calls `panel:Refresh()`. This state + redraw link makes the mark visible.
6. `TransportCargoContext:Clear()` calls `ClearSessionExtraSelectList` while cargo context is active. Independent Claret/ReUI implementations could affect the same session list; ownership must be agreed before integration.

Checked against FAF3840 (`C:/ProgramData/FAForever/gamedata/lua.nx2`): native `SetupConstructionControl` calls `CreateUI`, which creates `controls.constructionGroup`; `OnSelection`, `OnQueueChanged`, `RefreshUI`, and `SetLayout` are present. This confirms the replacement point. ReUI.Construction replaces the construction cluster, not the entire bottom HUD including MFD, orders, and economy: `SetLayout` accounts for neighboring `ordersControl`. Do not describe this single mod as an implemented “entire bottom HUD” replacement.

Practical conclusion: the previous pause because construction, queues, and tabs seemed inseparable did not prove replacement impossible; a verified architectural example exists. Claret should write its own implementation and separately define which neighboring clusters it covers and how it works alongside ReUI.Construction.

## Method, Reproduction, and Limitations

Tool: [unluac, Jeong-Min-Cho fork](https://github.com/Jeong-Min-Cho/unluac), commit `744c8149d93f7739f17b7f0f506822fb93ba7193`, CLI version `1.2.3.569`. Built locally from Java source in dev-only `.tools/unluac/`; decompiler source was not changed.

All recovered chunks had header `1b4c75610501010404040608090904`: LuaPlus 5.01, little-endian, four-byte int/size_t/instruction/number, instruction fields of 6/8/9/9 bits. `.tools/luaplus-adapt.cjs` changes only the temporary copy's header to standard Lua 5.0. `.tools/luaplus.opmap` maps opcodes: base operations 0–15, then Lua 5.0 operations shifted by four starting at UNM. Mapping was checked against recovered ActionsPanel and its readable source; this is not an independent engine VM audit.

Unknown operations 16–20 intentionally receive no guessed names: on detection Lua output is skipped and an error recorded. Round-trip checks disassemble every normalized copy and compare every byte. This proves structural reading completeness, not equivalence of recovered high-level conditions/loops. Generated `for ... in table, nil do` should be read as LuaPlus, not copied into standard Lua.

Repeat from the project root:

```sh
node .tools/reui-decompile.cjs             # new snapshot; overwrites manifest
node .tools/reui-decompile.cjs --decompile # recovery and round-trip assembly
node .tools/reui-decompile.cjs --verify    # SHA-256 and source sizes
node .tools/reui-index.cjs                # index and syntax check
```

After a new snapshot, previous run results in the manifest are reset; rerun `--decompile`. To build the tool, run `javac -d ../build unluac/Main.java` from `.tools/unluac/src`. The current runner specifies installed JDK 21. This is a developer tool, not a Claret game dependency.

Compilation removes comments, source formatting, and some high-level structure. Code was not run in-game. Visual appearance, scaling, performance, mod compatibility, and full semantic equivalence are unverified. Do not ship recovered files as a ready-made game replacement.

## Authors and Licenses

Research sources: installed mods from the manifest and local readable reference copies `Context/sources/ReUI` and `Context/sources/ReUI.ActionsPanel`; repository claimed by the authors: [4z0t/FAF-UI-Mods](https://github.com/4z0t/FAF-UI-Mods). Manifests list 4z0t as ReUI author; Construction and Score list 4z0t and HotCheese; MissilePanel lists Nuggets. A local MIT notice (2022, 4z0t) is preserved in `LICENSE.reference.txt`; its scope for specific installed builds/assets is undetermined. This research copy does not grant permission to copy code into Claret.

unluac: MIT, copyright 2011–2020 tehtmi, portions copyright 2014 Thomas Klaeger; notice retained in `.tools/unluac/license.txt`. Attribution is also recorded in `Credits and more/CREDITS.md`.
