# Claret menu, settings, and keybind rules

- Read `Context/ui-style.md` first. Reference image: `Context/claret-ui-reference.png`.
- All settings live in **F10 → Claret**, registered via `RegisterSettingsSection`; do not use `Builder.AddOptions` tabs. Implementation: Core `modules/Menu.lua`; example: Hotbuild `Main.lua`; contract: Core README.
- The menu is a launcher panel plus a separate settings panel. Geometry and scale are in `Context/ui-style.md` and `Theme.Metrics`. The Hotbuild keyboard fits its controls and dialogs. Claret UI fits its navigation and selected settings.
- Do not dim the map or intercept mouse input outside the menu panels. Close the menu via a button or Escape, with draft protection.
- The welcome window appears when the game starts until the user enables “Do not show again”; the checkbox can be toggled before closing. The choice is saved through a ReUI option in Core. The window can also be restored using “Hide welcome on startup” in F10 → Claret. It does not take keyboard focus or dim the map; its transparent outer area closes it on `ButtonPress` and passes the event to the parent. Escape uses the FAF handler stack. Keep the copy current and concise; show Nunito setup and Game.prefs recovery in separate compact cards. Always show the Nunito setup section, even when both files are installed. Describe clearing Game.prefs only as a recommendation and explain which settings it resets.
- Since Core 0.10.40 the welcome window uses a screen-fitted rounded panel. The header pairs the Claret wordmark and welcome text with a DPG card containing GitHub and Discord buttons. A single row shows the menu shortcut and language selector. Setup cards sit above a footer with the shared dismissal switch and Close button.
- The welcome link buttons use FAF's confirmed `OpenURL` dialog with the welcome window as its parent and follow the game's HTTP opener convention. A right-click copies the HTTPS address to the clipboard.
- Hotbuild is always active, with no feature toggle. It is embedded in a menu section via `inline(parent, layout)`; use the supplied `layout.scale`.
- `CanLeave(intent)` lets an editor request confirmation when closing or switching sections with an unsaved draft.
- Separate windows connect through actions; respect `RequestClose()`/`OnDestroy` and restore focus.
- Simple settings save immediately through the existing OptionValue and profile; there is no “Apply” button.
- Core's settings size offers 100%, 125%, and 150%. The original fitted size is 125%. The launcher and its settings sections use the saved value on reopen and fit the available screen. The option is local to the settings shell and its embedded pages.
- Launcher and section panels never capture keyboard focus: game hotkeys remain available. They do not handle Tab/Shift+Tab or Enter/Space navigation. FAF’s Escape stack closes the menu, with nested dialogs and active key capture handled first.
- Key-assignment capture temporarily takes keyboard focus and releases it on save, cancellation, or teardown. Text fields take focus only while focused. The Hotbuild keyboard reads physical Ctrl, Shift, and Alt while the page is visible, including when the pointer is over the map, without keyboard focus or consuming game input; on-screen modifier controls remain available.
- Menu bind: stable ID `ClaretCore_OpenMenu`, category Claret; default Ctrl-Alt-C is assigned once, only if free.
- The only source of the assignment is the standard UserKeyMap/UserDebugKeyMap; change or remove it via the menu, with no second OptionValue.
- Keyboard capture is temporary; reject conflicts with other binds; never reset the global key map.
- User decision (2026-11-13): Hotbuild key assignments belong only on the keyboard page, with separate “Build” and “Actions” slots; content editors show usage as read-only. The old composite-bind selector and confirmation were removed from presets; historical data is preserved.

## Current shell (verified 0.10.38, 2026-11-18)
- Hotbuild has three pages: Keyboard, Hotbuild, Contexts. There is no repeat page.
- Cinema registers its own Keyboard page with modifier layers and a collapsible NumPad. Its picker groups stock camera, presentation, game and replay, and visual debug actions, plus Cinema controls. Pause and speed are assignable in matches and replays. Search spans all groups. Only Cinema's assignments are editable. The entry/exit chord must be free in the ordinary layout and is reserved in Cinema. The current Claret menu shortcut remains available in both modes.
- Cinema's shooting drawer is separate from settings. The white movie-camera icon at the left edge opens or folds it. It creates its content on first open and fits its height to the active tab. Folding does not cancel a run; the Stop button or leaving Cinema key mode cancels a pending preview restore.
- Cinema's keyboard has separate Move To, Pan and Spin picker tabs for capture-start and play actions, plus capture-end and jump actions for Move To. The shared stop action appears on all three tabs. Configured chords appear on the corresponding drawer buttons with full details on hover; shortcuts work only in Cinema mode and use existing session-local poses and settings.
- A fresh Cinema profile initializes Move To to Ctrl-Q/W for capture start/end, Ctrl-A/S for jumping to start/end, and Ctrl-Z for play once. Existing or legacy Cinema preferences are not filled in again; explicitly cleared assignments do not regain defaults.
- Cinema Move To uses frame-driven `SnapTo` with smoothstep easing, independently of the native easing toggle, without changing free-camera mode. Stop holds the last requested pose; a completed preview requests the target and restores the previous pose on the following UI frame. The user confirmed ordinary flight in FAF for Cinema 0.1.10 on 2026-11-27; separate Stop/preview results, paused sessions and engine constraints outside free camera remain unverified.
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
