# UI implementation rules

> **Answers:** scale, depth, lifecycle, input, dialogs, data safety, error handling, snippets. **Read when:** layout shifts, a control leaks, clicks fall through, a dialog hides, a tooltip sticks, scale is applied twice. **Next:** `ui-visual.md` for tokens; `menu.md` for menu behaviour.

Distilled from real Claret bugs. Visual tokens are in `ui-visual.md`; menu behaviour in `menu.md`. Code wins over this file — then fix one of them.

## Coordinates and scale

- Take every size from `Theme.Metrics`; do not invent numbers.
- Position through `FloorLayouter(scale)`; pass text size as `scale / GetPixelScaleFactor()`.
- An explicitly scaled ReUI layouter exposes `Scale` as a **callable `LazyVar`**. Use the layouter's sizing methods or `ScaleNumber`. Multiplying by `layout.Scale` directly crashed the mex panel in Claret UI 0.2.50 (FAF3840 log).
- Apply UI scale exactly once. If a value is already multiplied by the group scale, never multiply by UI scale again.
- Never persist screen coordinates. Store logical values or nothing; recompute on open.
- Verify at 0.75–1.5 UI scale and at 1920×1080 and 2560×1440. A layout that works at one scale is a bug.
- Sliders, panels and HUDs that the user may resize must save scale and position separately, both logical.

## Depth and stacking

- Always set depth as a live closure, never a frozen number:

```lua
frame.Depth:Set(function() return parent.Depth() + 80 end)
```

- A frozen depth breaks as soon as the panel is raised (menu drag shifts depth by ±1000).
- Bands: content `0…+10`, overlays `+80`, dialogs `+90…+100`, tooltips `+60`, popups `+100`. New controls stay inside their band.
- Tooltips stay above their owner and above nothing else; destroy them with the owner.
- If a control caches another control's depth, update it when the owner moves.

## Controls and lifecycle

- Create controls inside the feature scope (`scope:Own`) or destroy them explicitly.
- Every `OnDestroy` chains to the previous handler:

```lua
local previousDestroy = control.OnDestroy
control.OnDestroy = function(self)
    cleanup()
    if previousDestroy then previousDestroy(self) end
end
```

- Replacing `OnFrame`, `OnHide`, `OnTextChanged`, `OnClick` follows the same rule: save and call the previous handler, or restore it. Otherwise menu focus, hover and animations break.
- Remove subscriptions (`event:Remove`, `Localization.Unsubscribe`) and stop `SetNeedsFrameUpdate(true)` when the control closes or hides.
- Call `DestroyMouseoverDisplay` / tooltip cleanup on close: a tooltip holding a destroyed control crashes on hover.
- Overlays that only dim or catch clicks use `DisableHitTest()` unless they must intercept; otherwise the map loses clicks.
- Hit areas must stay inside the visible window. When a panel shrinks (collapsed section, inline editor), resize the scroll viewport with it: a container taller than the panel keeps its rect, bubbles the press to the panel and swallows clicks in the empty band below the window.
- Do not assume clipping. Child Maui controls can draw outside a smaller parent; verify or clip manually.
- Decorative controls (panel fills, shadows, masks) always `DisableHitTest()`.

## Input and focus

- Panels never take game keyboard focus and never install global key handlers.
- Hotbuild keys live in the FAF key map, not in a Claret hook.
- Key capture only through `MenuKey` / `IsKeyCaptureActive`; Escape through the FAF escape stack, innermost first.
- Text fields keep native MAUI `Edit` behaviour; do not intercept typing. Verify that game hotkeys do not fire while a field is focused.
- Drag only by the header. The drag offset survives reopening within a match and must not move other panels.
- Menus do not handle Tab/Shift+Tab or Enter/Space navigation; the game's own focus system does (except inside capture mode).

## Dialogs and drafts

- Confirmation dialogs live **inside** the owner frame (overlay + panel), use live depths, and add/remove an Escape handler.
- `CanLeave(intent, continuation)` must call `continuation(false)` on cancel and must not destroy anything on cancel. A close-cancel that destroyed the editor is a past bug.
- Destructive actions need explicit confirmation; the confirm state resets when its list or dialog closes.
- Preserve unsaved drafts when switching sections; never silently discard.

## Text and states

- Every user-visible string goes through `ReUI.ClaretCore.Localization.Text`; keys in both `en` and `ru`. Never `rawget(_G, 'ReUI')`.
- Game names come from blueprints/`LOC`, not from Claret tables. Logs stay English.
- Truncate long UTF-8 labels safely and expose the full text in a tooltip; never cut bytes.
- State must be readable without colour alone (symbol or text), including toggles and selected rows.
- Status line: each editor's local `Status(message, isError)` helper; errors short and actionable.
- "Saved" confirmations appear next to the row and disappear after 1.5 s without a fade.

## Data safety

- Opening a window must not write the profile.
- Save only through the existing option value / `Commit` path (candidate + rollback) and only when something changed.
- Never delete or rewrite quarantined or invalid records silently: show the problem and let the user act.
- Do not reset other mods' key assignments; own only Claret ids.

## Errors and performance

- No `error()` inside UI callbacks: a thrown handler leaves half-applied state. Return `false, message` and show it.
- `pcall` only at boundaries (engine calls, profile access). Never per frame, per item or per dispatch loop iteration.
- No background polling: react to events; refresh on open, selection change or key press.
- Cache per press, not per frame; avoid allocations in `OnFrame` and key dispatch.
- Stop frame updates when an animation or transition ends.

## Recipes

### Rounded panel

```lua
local Theme = import('/mods/ClaretCore/modules/Theme.lua')
local panel = Group(root)
local layout = FloorLayouter(scale)
layout(panel):AtLeftTopIn(root, x, y):Width(w):Height(h)
local resize = Theme.RoundedPanel(panel, layout, w, h, Theme.Colors.surface, Theme.Colors.border, true)
-- later, when the panel changes size:
resize(newWidth, newHeight)
```

The control keeps its size and hit area; fills, corner masks, a 1 px ring and an optional 16 px shadow draw the surface. The shadow lies outside the panel bounds — do not clip the panel.

### Binary setting row

```lua
local paint = Theme.SettingsSwitch(row, layout, rowWidth, rowHeight, scale, compact)
paint(option:Get())
local previous = row.OnClick
row.OnClick = function(self, modifiers)
    local value = not option:Get()
    option:Set(value); option:Save(); SavePreferences()
    paint(value)
    if previous then previous(self, modifiers) end
end
```

The host row owns input and persistence; `SettingsSwitch` only paints. The whole row is clickable.

### Header drag

Maui drags go through `lua/maui/dragger.lua`, not through mouse coordinates:

```lua
header.HandleEvent = function(self, event)
    if event.Type ~= 'ButtonPress' or (event.Modifiers and event.Modifiers.Right) then return true end
    local Dragger = import('/lua/maui/dragger.lua').Dragger
    local drag = Dragger()
    local startX, startY = event.MouseX, event.MouseY
    local initialX, initialY = position.x, position.y
    drag.OnMove = function(_, x, y)
        position.x, position.y = initialX + x - startX, initialY + y - startY
        ClampPosition(position)
        PlacePanel(owner, position)
    end
    drag.OnRelease = function(self) self:Destroy() end
    drag.OnCancel = function(self) self:Destroy() end
    PostDragger(self:GetRootFrame(), event.KeyCode, drag)
    return true
end
```

Clamp to screen bounds in unscaled coordinates, keep the offset per panel, and never write the position to the profile.

## Before calling it done

1. `node Tests/check-core.cjs --quiet` is green.
2. Open/close, section switch, drag, Escape, key capture, language switch, draft cancel/save/delete.
3. At least one real in-game check: rendering, clicks, scale, focus. Stubs and Lua parsing do not prove UI works.
