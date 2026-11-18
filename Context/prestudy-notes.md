# Preliminary Notes from Public Sources

**Status:** translated/reorganized from preliminary notes gathered from public pages (FAF wiki, forum, repository pages). These notes were written before inspecting the user's mods or source code. Treat all claims as leads only and verify them against current code and in-game behavior. They were intended to speed up Stage 1, not replace it.

Sources named in the original research: FAF wiki pages on Development/Modding/Creating UI Mods; `4z0t/FAF-UI-Mods` README and an aggregator summary; FAF forum discussions about 4z0t UI mods and custom hotkeys.

## 1. FAF UI Mod Documentation

### Entry points and hooks

- The wiki identifies `CreateUI` in `gamemain.lua` as the main entry point after game loading.
- For an earlier phase, it says to hook `CreateWldUIProvider` in `gamemain.lua`. It says `StartGameUI` cannot be hooked because `uimain.lua` loads in the frontend.
- Hooks were described as file concatenation: mod code is appended to the original, so error line numbers can extend past the hook file. The wiki recommends keeping implementation in a separate module and leaving only `import` plus a call in the hook. The friend notes in `friend-notes.md` report the same behavior.

### Error resilience and Core design

- The preliminary notes warn that an error in an initialization hook such as `CreateUI` may stop later initialization, including code from other mods. They recommend wrapping the mod call in `pcall` and logging a warning.
- An `import` error aborts the whole file. Avoid complex work at module load time; prefer lazy initialization through a getter/function.
- Suggested Core direction: isolate each registered module so a failure in one mod does not break others. This was aligned with a friend's report that one invalid setting could abort an entire settings window.
- The notes suggest `pcall` is acceptable at rare points such as initialization but costly in frequent paths. Verify against the installed engine; see `friend-notes.md` and `tech-findings.md`.

### Development, simulation data, and Sync

- A “disk watcher” was described: each module has `__moduleinfo` with `OnDirty` and `OnReload` for hot reload without restarting. A dirty module also dirties dependent modules.
- The wiki was summarized as describing two sources of simulation data: engine functions for basic data about the player's own units, and `Sync` for richer information such as score, mass map, nuke launches, and pings.
- For Sync subscriptions, the notes recommend `AddOnSyncHashedCallback` with a category and identifier, so a handler can be replaced; unsubscribe via `RemoveOnSyncHashedCallback`. The older approach is an `OnSync` hook in `UserSync.lua`.
- Information about other players' units was described as heavily restricted (resources, shields, fuel, progress, and similar details are removed). Verify each data type and current visibility rules.

### UI and layout

- UI controls use positions based on `LazyVar`, recalculated when dependencies change. The notes mention `ExtendedErrorMessages` in `lazyvar.lua` for debugging.
- `layouthelpers.lua` includes a `Layouter` class and `ReusedLayoutFor` pattern, described by the wiki as useful for clear and reliable layout.
- The wiki was summarized as praising 4z0t mods for animation and centralized mod settings, while noting they use a custom library and much of the remaining FAF UI is old.

### Hotkeys

- FAF's `keymapper.lua` provides `SetUserKeyAction` to register an action (command and category) and save it in user settings. The category groups actions in the F1 hotkey menu.
- Localized display names are set in `keydescriptions.lua`; `SetUserKeyMapping` assigns the key.
- A fully custom keymap would use other functions such as `IN_AddKeyMapTable`. The wiki reportedly describes this as a fundamental game change better proposed upstream.
- Preliminary Core recommendation: build a shared hotkey registry on top of `SetUserKeyAction`, not in place of it. This still needed verification.

### Other notes

- Localization uses `LOC` and language-specific `strings_db.lua` hooks.
- Console commands use `ConExecute`; output can be read through `AddConsoleOutputReciever`.
- Selection changes use `OnSelectionChanged` in `gamemain.lua`. `selection.lua` provides `Hidden` and `SetIgnoreSelection` to avoid reacting to the mod's own selection changes.
- The wiki briefly mentions that icons can be replaced programmatically by function or blueprint-ID table, but gives no detail. This was flagged for separate research. A friend said UI mods could not replace unit textures/models; the notes say these may be different kinds of assets rather than conflicting claims.

## 2. ReUI (4z0t)

- Repository: `4z0t/FAF-UI-Mods`. An aggregator reported an MIT license and a repository `LICENSE` file; the original notes said to verify the file directly. The subsequent local review is recorded in `license-audit.md` and `reui-notes.md`.
- A forum author reportedly confirmed the repository's MIT license; another participant noted that separate mod licenses were being added gradually. Check each mod and subfolder separately.
- Libraries listed in the README: **ReUI.Core** (hooks, pre/post UI phases, property classes, weak tables); **ReUI.Options** (settings system); **ReUI.UI** (Layouter, Layout, Layoutable, Group/Text/Bitmap/CheckBox); **ReUI.UI.Views** (buttons, arrows, frames, brackets, scrollable control, grid); **ReUI.UI.Animation**, **ReUI.UI.Color**, and **ReUI.LINQ** (data-query library; its author claimed it was faster than UMT's older LuaQ).
- The repository was described as including economy, reclaim, Hotbuild, ActionsPanel, templates, EAS, RFA, IA, and other mods.
- An aggregator showed the main branch's latest update in November 2024; the forum mentioned a `dev` branch. Check the local copy against the repository and installed version. Later local investigation found the installed and readable copies were different versions; see `mod-inventory.md` and `reui-notes.md`.

## 3. Community License Discussion

Forum participants reportedly said code should not be copied when no license file is present, and that use should include author/license attribution or permission from the author. This is a lead, not a legal conclusion; check the actual license per mod and resource.

## 4. Questions Listed for Further Research

- Read ReUI's `LICENSE` and licenses for individual mods.
- Inspect how `ReUI.Options` registers/stores settings and builds its window.
- Check whether FAF itself has a settings window/mechanism for mods.
- Compare the user's ReUI copy with the repository version.
- Identify UMT's author/license, behavior, and whether it is needed as a dependency.
- Investigate the wiki's claim about programmatic icon replacement.
- Inspect FAF repository pull request #5755, reportedly about adding hotkey functionality, and compare it with the project plan.
- Check whether a custom library can coexist with installed ReUI without duplicate hooks on the same files.

Many of these questions were later partially investigated. Consult current source notes rather than treating this preliminary list as an open-state tracker.
