# UI implementation rules

Checklist distilled from real Claret bugs. Read together with `ui-style.md` (visual language) and `menu-rules.md` (menu behaviour). When code and this file disagree, the code is the current truth — then fix one of them.

## Coordinates, scale, geometry

- Take sizes from `Theme.Metrics`; do not invent numbers. Current shell: launcher 248 wide, standard panel 1128×1110, compact Core panel 552×408, panel drag header `width-72` × 72, name field 656×36, picker search 300×36, navigation row 40.
- Position everything through `FloorLayouter(scale)`; pass text size as `scale / GetPixelScaleFactor()`.
- An explicitly scaled ReUI layouter exposes `Scale` as a callable `LazyVar`. Use the layouter's sizing methods or `ScaleNumber` for numeric geometry. Claret UI 0.2.50 failed to start the mex panel when it multiplied by `layout.Scale` directly (FAF3840 log, 2026-11-20).
- Apply UI scale exactly once. If a value is already multiplied by the group scale, never multiply it by UI scale again.
- Never persist screen coordinates. Store logical values or nothing; recompute on open.
- Verify at 0.75–1.5 UI scale and at 1920×1080 / 2560×1440. A layout that only works at one scale is a bug.

## Depth and stacking

- Always set depth as a live closure: `Depth:Set(function() return frame.Depth()+80 end)`. A frozen number breaks as soon as the panel is raised (menu drag shifts depth by ±1000).
- Bands in use: content 0…+10, overlays +80, dialogs +90…+100, tooltips +60, popups +100. Keep new controls inside their band.
- Tooltips must stay above their owner and below nothing else; destroy them with the owner.
- If a control caches another control's depth, update it when the owner moves.

## Controls and lifecycle

- Core's optional minimap auto-hide changes the window's temporary visibility without changing FAF's `stratview` preference. A manual minimap toggle remains authoritative. The independent border option hides window and minimap decoration controls and restores them when disabled. Both options are off by default and appear under UI → Minimap; their saved values remain in Core. The user confirmed the features and checked manual closing in FAF for Core 0.10.25 / Claret UI 0.2.33 on 2026-11-20. Compatibility with other minimap mods was not specified.

- Create controls inside the feature scope (`scope:Own`) or destroy them explicitly; every `OnDestroy` must chain to the previous handler.
- When replacing `OnFrame`, `OnHide`, `OnTextChanged`, `OnClick`, save the previous handler and call it (or restore it) — otherwise menu focus, hover and animations break.
- Remove subscriptions (`OnChanged:Remove`, `Localization.Unsubscribe`) and stop `SetNeedsFrameUpdate(true)` when the control closes or hides.
- `DestroyMouseoverDisplay` / tooltip cleanup on close; a tooltip holding a destroyed control crashes on hover.
- Overlays that only dim or catch clicks: `DisableHitTest()` unless they must intercept; otherwise the map loses clicks.
- Hit areas must stay inside the visible window. When a panel shrinks (collapsed section, inline editor), resize the scroll viewport with it: a container taller than the panel keeps its rect, bubbles the press to the panel and swallows clicks in the empty band below the window.
- Do not assume clipping. Child controls can draw outside a smaller parent; verify or clip manually.

## Input and focus

- Panels never take game keyboard focus and never install global key handlers; Hotbuild keys live in the FAF key map.
- Key capture only through `MenuKey`/`IsKeyCaptureActive`; Escape through the FAF escape stack, innermost first.
- Text fields: MAUI `Edit` keeps its native behaviour; do not intercept typing. Verify that game hotkeys do not fire while a field is focused.
- Drag only by the header; the drag offset must survive reopening within a match and must not move other panels.

## Dialogs and drafts

- Confirmation dialogs live inside the owner frame (overlay + panel), use live depths, and add/remove an Escape handler.
- `CanLeave(intent, continuation)` must call `continuation(false)` when the user cancels and must not destroy anything on cancel. A close-cancel that destroys the editor is a known past bug.
- Destructive actions need explicit confirmation; the confirm state resets when its list/dialog closes.
- Preserve unsaved drafts when switching sections; never silently discard.

## Text, localization, states

- Every user-visible string goes through `ReUI.ClaretCore.Localization.Text`; add keys to both `en` and `ru` tables. Never `rawget(_G, 'ReUI')`.
- Game names come from blueprints/`LOC`, not from Claret tables; logs stay English.
- Truncate long UTF-8 labels safely and expose the full text in a tooltip; do not cut bytes.
- State must be readable without colour alone (symbol/text), including toggles and selected rows.
- Status line: `Status(message, true)` for errors; messages are short and actionable.

## Data safety

- Opening a window must not write the profile. Save only through `Runtime:Commit` / `CommitContext` (candidate + rollback) and only when something changed.
- Never delete or rewrite quarantined/invalid records silently; show the problem and let the user act.
- Do not reset other mods' key assignments; own only Claret ids.

## Errors and performance

- No `error()` inside UI callbacks: a thrown handler leaves half-applied state. Return `false, message` and show it.
- `pcall` only at boundaries (engine calls, profile access). Do not wrap per-frame or per-item work.
- No background polling: react to events; refresh on open, selection change or key press.
- Cache per press, not per frame; avoid allocations in `OnFrame` and in key dispatch.

## LuaPlus dialect

- No `#` (LuaPlus treats it as a comment marker; a module with `#` fails to load), no `continue`, no `goto`, no integer division.
- Use `table.getn`, `import`, `math.mod`; keep nested functions under 32 upvalues.
- Module tables are strict: reading a missing field raises `access to nonexistent global variable`. Export every public function explicitly.
- `import` returns the module environment, not the chunk's `return` value. Declare the API as a module global (`function Create(...)`, `Start = function(...) end`); a module that only declares `local` helpers and ends with `return { ... }` loads as an empty table and the caller raises `access to nonexistent global variable <name>`. `local function X` followed by `X = X` is not an export: the assignment hits the local. The runner rejects both forms.
- Maui classes (`Bitmap`, `Group`, classes from `ClassUI`) are callable tables with `__call`, not functions; guards like `type(x) ~= 'function'` reject them. Check `x == nil` or accept `table`.
- Varargs in expression position (`f(x, ...)`, `return ...`) abort the module load in LuaPlus: the module table stays empty and the caller reports a nonexistent global. Declare fixed parameters instead; the runner rejects any varargs in Claret UI by AST.

## Before you call it done

1. `node Tests/check-core.cjs --quiet` is green (auto-discovery, static checks).
2. Open/close, section switch, drag, Escape, key capture, language switch, draft cancel/save/delete.
3. At least one real in-game check: rendering, clicks, scale, focus. Stubs and Lua parsing do not prove UI works.
