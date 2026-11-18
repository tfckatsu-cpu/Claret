# Friend Notes (Translated)

These notes are a friend's reports from work on another FAF UI mod. They are historical, version-specific, and unverified until checked against FAF 3840 and relevant source. They are not Claret requirements. See `AGENTS.md` and `tech-findings.md` for corrections and current evidence.

## Mod Loading and Hooks

- A file under `hook/lua/ui/game/X.lua` is appended to the original file rather than replacing it. The hook can therefore see original locals and override its functions.
- Hooks do not affect modules loaded in the lobby, such as `layouthelpers`, `Bitmap`, `Text`, and `Grid` from `lua/maui`. Those can only be patched at runtime by replacing functions in an already loaded module table. The friend's mod used a separate `patches.lua`, invoked from a `gamemain.lua` hook before UI creation.
- Entry point: hook `gamemain.lua`; apply patches before `CreateUI`, then run main code (`core.Init`) afterward. Smaller hooks (`tabs.lua`, `score.lua`, `massfabs.lua`, `recall.lua`, `orders.lua`, `unitview.lua`, `keymap/misckeyactions.lua`) were used to reach local objects owned by specific panels.
- Code paths used `/mods/<folder name>/...`; spaces reportedly work. Renaming a mod folder required changing imports, while the author advised leaving `uid` in `mod_info.lua` unchanged because the client identifies the mod by it.
- `ui_only = true` reportedly means other players do not need the mod and it can be used in ranked games.
- The notes describe the FAF dialect as Lua 5.0 with `for k, v in tbl`, `!=`, `math.mod`, and `arg`/`unpack(arg)` instead of `...`. They report strict module tables where missing fields/globals fail and recommend `rawget`/`rawset`. Verify dialect and global access rules against current FAF; see `tech-findings.md`.
- The friend reported a 32-upvalue function limit: a large settings-window function failed in build v217 with “too many upvalues,” so file-level module fields were used instead of locals.
- Updated mod files reportedly require a new match to load. Partial copying of mixed old/new files caused settings-window errors; after releases, the author compared files by size/checksum.

## Settings and Windows

- Settings were stored per player in `Game.prefs` through `Prefs.GetFromCurrentProfile`, `SetToCurrentProfile`, and `SavePreferences`. The mod used several keys, including `UIPanelTuner`, `DNOMOD_*`, and a window key. A position-format version was included, and one panel key was kept unchanged since v54 for compatibility.
- Settings were local to each computer and did not travel with the mod folder.
- A one-time migration flag was recommended when storage format changes (for example, reversing priority-row order), otherwise data could be reversed on every load.
- Store list selections by name/ID rather than index, because indices shift when a list changes.
- `maui/window.lua` reportedly scales the minimum window size itself. Applying additional scaling in mod code caused a 4K minimum larger than the screen and made the window stretch to its limits on resize.
- Scrolling in that window was implemented manually with the wheel, thumb, and track clicks; the friend reported no ready-made arbitrary-content scroll container.
- A missing setting could abort construction of the whole settings window, so construction was split into protected chunks.
- Frequent `SavePreferences` calls had a measurable cost in that mod; save on events, not on a timer.

## UI Behavior

- Positions used `LazyVar`, recalculated when dependencies changed rather than every frame. A unit-info window was an exception because the game moved it every frame; the mod stopped that behavior.
- The game reportedly replaced panel-edge bindings with fixed numbers during its startup animation, causing a filter panel to jump depending on frame rate. The mod removed that animation, saved each edge's original binding, and used `ForceLV` so the game would not overwrite the `LazyVar`.
- Parent alpha was inherited by children, so fading a frame also hid its buttons. Hide the image, not the container.
- Images reportedly could not be rotated; a down arrow used a flipped up-arrow image.
- Tooltips and menus render at a higher Depth than the panel and need exclusion when searching panel contents. Order buttons also use a high layer, so a blanket rule broke them.
- The minimap was described as a separate engine 3D camera whose opacity could not be changed; the UI had no complete unit-position data to build a replacement map.
- The notes state that a UI mod could not replace unit textures/models, while personal 3D objects could be made through WorldMesh. `UserUnit` did not expose unit rotation.
- The game displayed scores on the panel only if Score was enabled in the lobby; otherwise it returned -1.
- Communication between players' UI mods used hidden chat messages (`SessionSendChatMessage` + `RegisterChatFunc` by label), limited to 1024 bytes, outside simulation and absent from replays. The friend reported one handler per label, with the last registration winning; Notify and TIS used this approach.
- Surrender voting exposed only counts to UI; individual votes were known only in simulation. The mod inferred names/counts through messages to allied mods.
- The FAF client passed the game only a map folder name; the game assembled the rest of the path itself.
- The friend did not know exactly which frame applied `LazyVar` changes during animations and had worked around the issue.

## Conflicts and Failures

- The notes report a FAF fallback bug where hiding panels referenced a missing variable, leaving filters/pings visible; the mod hid them itself.
- “Game object has been destroyed” occurred after commander death or game end when the mod used destroyed controls. Parent traversal was moved through a protected `GetParent`, and the mod stopped when the UI closed.
- If the original Strogo mod was enabled by UID, its built-in “Advanced target priorities” code was not installed. The prefs key was shared, so settings carried over.
- If TIS was enabled alongside the friend's mod, both claimed the TIS message label and only one handler remained; the mod was changed to yield that channel.
- `GetFrame(1)` reportedly crashed the game without a second monitor (`ACCESS_VIOLATION`, not caught by `pcall`); the proposed check was `GetNumRootFrames() >= 2`. The report concerned build v381.
- Logs reportedly failed to write when the Windows username used Cyrillic characters; the mod accounted for this.
- Hotbuild, UMT, and ReUI showed no direct conflicts in the logs, but compatibility was not deliberately tested. Compatibility with other mods changing the same panels was also unchecked.

## Performance Reports (Specific to the Friend's Mod)

- A caught Lua error (`pcall` + `error`) was reported as costly because the engine wrote a full stack (about 5 KB) to its exception list. One session reportedly logged 2,531 errors in five minutes, produced a 13 MB log, grew memory by about 2.5 MB/min, and spent 33 ms on transparency traversal. The reported rule was to avoid catching expected errors in hot paths and check fields instead; after a fix, the friend reported about 50 errors over 20 minutes.
- The mod reportedly used 10.8% of frame time (build 26.10) before reducing to about 6% after recalculating only on changes. Heaviest areas were the hovered-unit window, compact frames, reclaim numbers, transparency, panel discovery, and enemy positions.
- Large 0.4–0.9 s stalls were reported even with the mod disabled; the mod took 0–3 ms in those frames. Some coincided with Lua garbage collection (memory fell by 7–11 MB), others with minimizing a window. The first mod pass at startup reportedly stalled the game for about 0.4 s.
- The friend reported FPS falling from 93–98 to 60–80 in the first minutes. A scan of all panels every ~0.3 s in one frame took 9 ms on average and over 20 ms at times. At 144 Hz, VSync could turn an extra 1 ms into a 7 ms loss. The mod added about 1,170 UI elements (2,120 versus 948). Planned response: spread the scan across frames with a 1–2 ms budget.
- Transparent remnants of standard frames reportedly cost little; periodic discovery scans were the expensive part.
- `WaitSeconds(n)` in UI reportedly used `AvgFPS` to estimate frames, so “10 seconds” could take 20 seconds in wall time. The friend reported no profiling clock in FAF 3840, only `CurrentTime`.
- Orders were traversed twice per pass, costing 3.2 ms/s in that mod; the friend reduced this to one pass.
- The claim that simulation runs on a separate thread, so a UI mod affects FPS but not game speed for everyone, was an assumption and was not directly tested. The impact of 1,170 extra controls on rendering was also not measured, only counted.

## Testing Process Reported by the Friend

- The friend could not launch the game remotely and used: syntax check → mock tests → release → user tests → read `game*.log`.
- Syntax was checked with `texluac -p` after replacing `!=` with `~=`, and upvalues with `texluac -l` (the reported Lua 5.1 count allowed 33, while the engine limit was 32).
- `dev/sim/test*.lua` used `texlua` and stubs for LazyVar/controls at scales 1.0/1.25/1.75. It covered layout logic, ordering, migrations, and voting but not actual rendering, Depth, animations, or timing.
- Image variants were rendered from custom control dumps to PNG/GIF using Python before launch.
- Logs were searched for `DNO MOD`, `warning:`, `Error`, `Evaluating LazyVar failed`, `too many upvalues`, and `stack traceback`. Diagnostic lines (`DNO MOD thin/perf/fpscheck/flags`) were gated by a flag and meant to be disabled in release builds.
- The friend's FPS comparison used the same map/replay with the mod enabled and the in-game “Interface” checkbox disabled; a “pause mod for 15 s” test was rejected as incomplete. A Skirmish with 1–2 bots on a small map was considered sufficient for logic testing.

## Other Observations

- At the end of the startup animation, `HideGameUI('off')` was a convenient moment to restore collapsed panels in the same frame without flicker.
- The mod could identify another player's country only when it was host; in someone else's lobby it used stored data.
- Device-tool copying sometimes wrote an old file, motivating post-release verification.
- Replacing default frames at creation time with same-size placeholder images might work while keeping the game's layout calculations, but it was not attempted and was considered a medium risk.
