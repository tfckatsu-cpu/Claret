# Claret menu, settings, and keybind rules

- Read `Context/ui-style.md` first. Reference image: `Context/claret-ui-reference.png`.
- All settings live in **F10 → Claret**, registered via `RegisterSettingsSection`; do not use `Builder.AddOptions` tabs. Implementation: Core `modules/Menu.lua`; example: Hotbuild `Main.lua`; contract: Core README.
- The menu is a launcher panel plus a separate settings panel. Geometry and scale are in `Context/ui-style.md` and `Theme.Metrics`. The Hotbuild keyboard fits its controls and dialogs. Claret UI fits its navigation and selected settings.
- Do not dim the map or intercept mouse input outside the menu panels. Close the menu via a button or Escape, with draft protection.
- The welcome window appears when the game starts until the user enables “Do not show again”; the checkbox can be toggled before closing. The choice is saved through a ReUI option in Core. The window can also be restored using “Hide welcome on startup” in F10 → Claret. It does not take keyboard focus or dim the map; its transparent outer area closes it on `ButtonPress` and passes the event to the parent. Escape uses the FAF handler stack. Always show the Nunito setup section, even when both files are installed. Describe clearing Game.prefs only as a recommendation and explain which settings it resets.
- Hotbuild is always active, with no feature toggle. It is embedded in a menu section via `inline(parent, layout)`; use the supplied `layout.scale`.
- `CanLeave(intent)` lets an editor request confirmation when closing or switching sections with an unsaved draft.
- Separate windows connect through actions; respect `RequestClose()`/`OnDestroy` and restore focus.
- Simple settings save immediately through the existing OptionValue and profile; there is no “Apply” button.
- Launcher and section panels never capture keyboard focus: game hotkeys remain available. They do not handle Tab/Shift+Tab or Enter/Space navigation. FAF’s Escape stack closes the menu, with nested dialogs and active key capture handled first.
- Key-assignment capture temporarily takes keyboard focus and releases it on save, cancellation, or teardown. Text fields take focus only while focused. The Hotbuild keyboard reads physical Ctrl, Shift, and Alt while the page is visible, including when the pointer is over the map, without keyboard focus or consuming game input; on-screen modifier controls remain available.
- Menu bind: stable ID `ClaretCore_OpenMenu`, category Claret; default Ctrl-Alt-C is assigned once, only if free.
- The only source of the assignment is the standard UserKeyMap/UserDebugKeyMap; change or remove it via the menu, with no second OptionValue.
- Keyboard capture is temporary; reject conflicts with other binds; never reset the global key map.
- User decision (2026-11-13): Hotbuild key assignments belong only on the keyboard page, with separate “Build” and “Actions” slots; content editors show usage as read-only. The old composite-bind selector and confirmation were removed from presets; historical data is preserved.

## Current shell (verified 0.10.38, 2026-11-18)
- Hotbuild has three pages: Keyboard, Hotbuild, Contexts. There is no repeat page.
- Geometry: compact Core section 552×408; standard panel 1128×1110; panel drag header width-72 × 72; binding name field 656×36; picker search 300×36; navigation row 40.
- Dragging a panel shifts its depth by ±1000. Every overlay, dialog and tooltip must use live depth closures (see ui-rules.md), never a frozen number.
- Sections register through ReUI.ClaretCore.RegisterSettingsSection; inline(parent, layout) receives layout.scale and may return CanLeave(intent, continuation). A remembered page is created on the first AfterParentShow, never inside inline(...): building an embedded editor while the panel is hidden leaves size-only Maui controls with a circular Left/Top chain (circular dependency in lazy evaluation in the game log). Do not use the unused ccessory hook.
- Key capture is temporary; Escape goes through the FAF stack; panels never take game keyboard focus and never install global key handlers.
- The quick-repeat settings window and its gear were removed in 0.10.38; there is no menu path for them.

## Master-detail sections (0.10.18, 2026-11-19)

- `layout.setWidth(innerWidth)` takes the inline content width. Core adds 48 logical units for the panel insets. Both width and height changes go through `SetPanelSize` so the shell, close button, drag header and scroll viewport follow the resize.
- Core calls the optional `editor:OnResize(innerWidth, innerHeight)` for an installed editor when it resizes the panel. An editor can also anchor its controls directly to the host bounds. Use `AfterParentShow` to request the initial size once the host is shown.
- Core 0.10.19 adds `layout.setSize(innerWidth, innerHeight)` for an inline-only page. Core adds 48 units horizontally and 124 vertically, and resizes the inline host with the panel.
- Core 0.10.20 accepts an optional third argument to `layout.setSize`: `{ split, left, right }`. The split is relative to the inline content origin. The two heights set where each body ends under the common header. The empty portion of the bounding rectangle passes pointer input through to the game.
- Claret UI 0.2.7 uses a 224-unit navigation column and a 384-unit detail column separated by 16 units. Each column ends below its content. Each setting declares its control height. Clicking the selected group again collapses the detail column.
- Core 0.10.21 draws each expanded column with the shared rounded frame and shadow. Decorative controls pass pointer input through.
