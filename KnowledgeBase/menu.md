# Claret menu: launcher, sections, keybind

> **Answers:** launcher/panel geometry, section registration, key capture, Escape, drag, welcome window. **Read when:** the menu will not open or close, a section is missing, a draft is lost, input is captured wrongly. **Next:** `architecture.md` for the contract; `ui-code.md` for depth and input.

All Claret settings live in **F10 → Claret**. There are no ReUI Options tabs for Claret UI. Implementation: `ClaretCore/modules/Menu.lua`, keybind in `modules/MenuKey.lua`, F10 entry registered through `import('/lua/ui/game/tabs.lua').AddToMenu`.

## Shell

- Two panels: a compact **launcher** (248 wide, up to 400 high) and a **settings panel** to its right (`panelWidth` 1128, `panelHeight` 1110) separated by `panelGap` 16.
- First open in a match shows the launcher. Selecting a section opens settings. Reopening in the same match restores the open section or the launcher.
- Settings close button returns to the launcher; launcher close button closes everything.
- Before closing or switching sections Core calls `CanLeave` on the active section; the editor survives a cancel.
- The whole group is scaled to fit the screen and the UI scale; scale is applied once. On small screens the group shrinks — check readability.
- Panels are dragged independently by their headers and keep positions **within the match** when reopened. Positions are not written to the profile.
- Raising a panel shifts its depth by ±1000, so every overlay, dialog and tooltip uses a live depth closure (`ui-code.md`).
- Opening motion: 160 ms position shift, launcher fades in, group fades out on full close. Frame updates stop when the transition ends. Do not animate opacity of nested controls during normal use (it would overwrite per-control alpha states).

## Sections

```lua
ReUI.ClaretCore.RegisterSettingsSection {
    id = 'hotbuild', title = 'Hotbuild',
    titleKey = 'hotbuild.section.title', descriptionKey = 'hotbuild.section.description',
    inline = function(parent, layout) return editor end,
}
```

- Section list on the left, scrolls above six sections. New sections appear the next time the menu opens.
- `inline(parent, layout)` builds content inside the shared window; `layout.scale` is the shared scale.
- Master-detail pages: `layout.setSize(w, h, {split, left, right})`; Core adds 48 horizontally and 124 vertically; the empty part of the bounding rectangle passes pointer input through.
- Inline-only pages: `layout.setSize(w, h)`. Width-only change: `layout.setWidth(innerWidth)` (Core adds 48 for insets). All size changes go through `SetPanelSize` so shell, close button, drag header and scroll viewport follow.
- Core calls `editor:OnResize(innerWidth, innerHeight)` when it resizes the panel.
- Build remembered pages in `AfterParentShow`, not inside `inline(...)`; building while the panel is hidden leaves size-only Maui controls with a circular `Left`/`Top` chain (game-log error).
- The unused "accessory" hook is not used; do not resurrect it.

## Keybind

- Stable action id `ClaretCore_OpenMenu`, category `Claret`, shown in F1.
- Default **Ctrl+Alt+C**, assigned once and only if free. If occupied, no automatic assignment.
- The binding is stored in the standard FAF key profile (`UserKeyMap`/`UserKeyDebugKeyMap`) through the keymapper; there is no second `OptionValue` copy.
- Change: F10 → Claret → Core → **Change**, then press a combination; saved immediately. Escape cancels. **Clear binding** removes the assignment; the F10 entry stays available, and the default is not re-assigned in a later match.
- Conflicts are rejected with the owner's name; never reset the global key map, never overwrite another action.
- Pressing the binding while the menu is open does not create a second window and does not discard the Hotbuild draft.

## Input

- Panels never take game keyboard focus; game hotkeys stay available.
- Menus do not handle Tab/Shift+Tab or Enter/Space navigation.
- Escape goes through the FAF escape stack: innermost dialog and active key capture first, then the menu.
- Key capture is temporary: takes input on start, releases on save, cancel or teardown; stops when the menu closes or changes sections.
- Text fields take focus only while focused; `Edit` keeps native behaviour.
- Claret Hotbuild reads physical Ctrl/Shift/Alt while its page is visible, including with the pointer over the map, without focus and without consuming game input. On-screen modifier controls remain available.
- Do not dim the map and do not intercept mouse input outside the panels. The transparent area of the welcome window is the one exception: it closes the window on `ButtonPress` and passes the event to the parent.

## Welcome window

- Appears at game start until the user enables "Do not show again"; the checkbox can be toggled before closing. Stored as a Core ReUI option.
- Restorable from F10 → Claret (row "Hide welcome on startup").
- No keyboard focus, no map dim, Escape via FAF stack.
- The Nunito setup section is always shown, even when both fonts are installed; clearing `Game.prefs` is described as a recommendation, including which settings it resets.

## Closing

- Closing removes subscriptions, Escape handlers and temporary key capture.
- `CanLeave` protects drafts on both close and section switch; `continuation(false)` cancels without destroying the editor.
- A separate window opened through `actions[].open(parent)` returns a window with `RequestClose()` and `OnDestroy`, owned by the passed parent; restore focus on close.
