# Claret Cinema 0.1.10

Claret Cinema is a UI-only mod for footage capture. It requires Claret Core and ReUI, not Claret Hotbuild.

Click the white **movie camera** icon at the left edge of the game screen to open or fold the shooting drawer. The drawer can be used without entering the isolated key mode, except that hiding the HUD requires that mode so its exit shortcut can restore the UI.

| Tab | Controls |
|---|---|
| General | Near/far FOV and pitch, shadow distance and resolution, free camera, easing, HUD, selection boxes, decal distance, camera reset and visual defaults. |
| Move To | Capture and visit a start and end pose, choose whether to use the saved start, set duration, preview or play. |
| Pan | Optional saved start, X/Z speed and timed movement. |
| Spin | Optional saved start, rotation/zoom rates, a five-second preview or continuous spin. |

Completed previews return to the previous view. **Stop** keeps the current view and cancels that return. Drawer settings and captured poses are session-local. The original tab set and docking interaction are based on **Cinematics v7** and **Dear Windowing v9**, by Jip (Willem Wijnia); no dependency on either mod is required. `Cinematics test` adds experimental keyframes, effects and negative-angle controls that are not part of this drawer.

Move To interpolates camera poses with smooth acceleration and deceleration using per-frame `SnapTo`, without toggling free camera. Its easing is independent of the native FAF easing toggle. With free camera disabled, normal engine camera constraints may still affect the view. Timing uses UI system time; paused-session behaviour remains unverified.

**F10 → Claret → Cinema → Keyboard** shows the Cinema layout in the Hotbuild keyboard style. Click a key to assign the mode switch or a technical command: HUD, free camera, camera reset, easing, decal distance, and selection boxes. Right-click to clear a command or return the mode switch to automatic selection. Use physical or on-screen Ctrl, Shift and Alt to display combinations. Cinema must be off while editing.

The Move To, Pan and Spin picker tabs contain shortcuts to capture their start, play, and stop motion; Move To also has capture end and jump to either pose. On first initialization of a fresh profile, Move To defaults are Ctrl-Q / Ctrl-W to capture, Ctrl-A / Ctrl-S to jump, and Ctrl-Z to play. Existing profiles are not filled in again; an explicitly cleared binding stays cleared. Stop is one shared binding shown in all three tabs. Assigned chords appear on the corresponding drawer buttons; hover for the full chord and any menu conflict. Shortcuts work only in Cinema mode. Move To requires an end; each saved start is used according to its drawer switch. Poses remain session-local.

The picker also includes a deduplicated set of native FAF actions for camera, picture and HUD, game and replay controls, and visual debugging. Search spans all groups. Stock actions do not receive default Cinema chords. Pause and game-speed bindings are assignable in games and replays; they follow FAF's normal rules when invoked. Skeletons, bone names, wireframe, and the profiler are restricted to replays and offline games. Collision and navigation views and other `dbg` visualizations require an offline game with FAF debug facilities already enabled; engine acceptance may vary. Cinema does not enable debug facilities or alter the ordinary key preferences.

The mode button and the same shortcut switch between layouts. The shortcut must be free in the normal layout. If an ordinary action later claims it (or no preference was set), Cinema uses the first free chord from `Ctrl-Alt-F9`, `Ctrl-Alt-F8`, and `Ctrl-Alt-F7`. The actual chord is shown on the mode button. The default HUD chord is `H`; other technical commands start unassigned. Cinema saves its own bindings without editing the ordinary map in the profile.

While Cinema is on, writes through the Lua key-map functions go to the ordinary layout and are replayed on exit. Cinema refuses activation before observing a clear followed by a map registration. Engine-internal input and mods using cached native functions are outside the intercepted path.

The current Claret menu shortcut is the only ordinary shortcut preserved in Cinema mode. Its actual chord is tracked, not hardcoded. The Cinema exit chord retains priority if the Claret menu is moved onto it during an active Cinema session.

On exit, Cinema undoes only its own custom toggles. Native FAF actions behave as they do normally and may leave camera or diagnostic displays enabled until manually changed. Cinema cannot observe visual state changes made by another mod or the console in the meantime. Camera reset is an immediate command, not a toggle.

Free camera uses FAF's native `cam_Free` transition. Cinema does not reapply a saved pose when toggling it.
