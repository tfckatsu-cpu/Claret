# Claret UI — test build 0.2.63

Child mod of Claret Core: game-interface overlays that Core does not own. The mod fills the `UI` section of the Claret launcher; Core keeps its placeholder until Claret UI is installed.

## Features

| Feature | Toggle | Source of the behaviour |
|---|---|---|
| ACU Health panel | `ACU Health panel`; adjustable panel size from 50% to 200% | ACU HP Monitor by NITROFIX |
| Minimap | Optional zoom auto-hide and border hiding; implemented in Core | ZeP_MiniMapZoom and Extra mini map as references |
| All Rings | `All Rings`; configurable preview keys and range filters | [Rings For All](https://github.com/4z0t/FAF-UI-Mods/blob/develop/Docs/Overview/RingsForAll.md) by 4z0t and Nomander, installed release 7 (2026-11-20) |
| Mass extractors | Show mex panel, map markers and numbered mode | ECO UI Tools (EUT) v11 by 4z0t, installed copy checked on 2026-11-20 |
| Selection info, team info, missile alerts, eco panel, reveal positions, idle engineers, score/reclaim/economy | — | planned |

In **F10 → Claret → UI**, the left column lists feature groups. Selecting a group keeps that column the same width and expands the right side to show the group's settings. Select the same group again to collapse the right side. Each column ends below its own content, and both share a title bar.

The ACU Health panel is created once per match. Its toggle preserves the saved position. The panel shows HP, regeneration per second, and shield charge as a percentage. The upper blue strip represents the charge. Below 15% health, the border and health bar pulse. Below 5%, red corner brackets pulse twice per cycle. The two levels clear at 17% and 7%, respectively. The HP readout stays visible throughout. A positive shield ratio is enough to show the percentage. Identifying an installed shield through its blueprint and enhancements also lets the panel show zero or unavailable charge. The 50–200% size slider updates the panel while dragging and saves the chosen size with the profile. Panel size is independent of the game's UI scale. Position is stored in logical units and restored through the UI scale.

The panel identifies commanders through the FAF avatar category API and shows a search message while commander or health data is unavailable. As soon as FAF confirms the commander's death, the panel removes the health and shield bars and displays `Skill issue` for two seconds. The panel then cracks along jagged burgundy edges. The shards scatter and fade as they fall over 0.72 seconds, and the panel hides. Switching the focused army resets the tracked commander and restores the panel for the new focus.

### All Rings

Enable the feature under **F10 → Claret → UI → All Rings**. Use the Shift and Ctrl buttons at the top to choose shortcuts for attack and build range independently. Both start on Shift. The attack shortcut previews weapon and intel ranges for the selection and for the unit under the cursor. Hover can show enemy ranges when FAF exposes the unit's blueprint.

The build preview shows the range of selected builders at the cursor. It moves to the builder or its queued destination while placing a building or issuing a repair, reclaim or guard order. Hold Alt with an engineer or factory selected to preview the 28-unit reclaim radius.

**Advanced** starts collapsed. It contains individual weapon and intel filters, the minimap switch, and an option to include footprint and target size in build range. All Rings is off by default. Its settings are saved in the Claret UI profile.

The user confirmed All Rings in FAF for Claret UI 0.2.38 (build 20261120-41) on 2026-11-20. Individual scenarios and mod combinations were not reported.

Do not run the original mod next to the equivalent Claret UI feature.

## Requirements

Claret Core 0.10.25 or newer and ReUI (Core 1.7.0, UI 1.0.0, Options 1.2.0). Client-side only; no simulation changes.

## Mass extractors

In **F10 → Claret → UI → Mex Overhaul**, turn on **Show mex panel**. **Panel display** switches immediately between **Static** (all seven cells) and **Adaptive** (only tiers with mexes). Adaptive mode hides the panel when no mexes are present and resizes immediately as tiers appear or disappear. Cells are created only for tiers included in the current layout. The backdrop exists only while the panel has cells to show. Map marker projection runs independently of the panel's layout and visibility in adaptive mode. T1 and T2 each show idle, paused, and upgrading cells. T3 has only an idle cell. Three DDS files from the installed Redux ACU Icons v1 pack by macdeffy identify the tier. The icons display at 36 logical pixels. The installed folder is named ASI Medium. Macdeffy granted reuse with credit in the [Redux Strategic Icons thread](https://forum.faforever.com/topic/2926/redux-strategic-icons). A gold arrow identifies upgrading mexes and the FAF pause mark identifies paused upgrades. Hover over a cell for its controls. Hold the left mouse button over a cell and move the pointer to drag the panel. Releasing the button after a drag saves the position in logical screen units and flushes it to disk. A click still activates the cell. **Lock panel position** disables dragging and saves the lock setting in the profile.

| Cell | Left click | Right click | Ctrl + left | Ctrl + right |
|---|---|---|---|---|
| Idle T1/T2 | Select all | Select on screen | Upgrade all | Upgrade on screen |
| Paused T1/T2 | Select all | Resume all | Select highest progress | Resume highest progress |
| Upgrading T1/T2 | Select all | Pause all | Select highest progress | Pause lowest progress |
| T3 | Select all | Select on screen | Select all | Select on screen |

Each cell shows its count above the mex icon. On paused upgrades, the opaque pause mark is aligned to the green core of the T1 or T2 mex icon. **Panel background transparency** applies to one continuous panel backdrop from 0% to 100%. Cell fills are drawn only at 0% transparency. Icons, counts, and progress tracks stay visible. The panel shows tracks for up to ten upgrades per cell, ordered by progress. Fills grow from the left edge of their own track and remain inside the cell at each panel scale. **Panel size** scales the panel from 50% to 200% in 5% increments and saves the value in the current profile. Map marker sizes are independent of this setting. The **Claret UI** category in FAF's hotkey dialog contains the corresponding selection and upgrade commands, including joint T1/T2 commands for active or paused upgrades. Hotkeys dispatch while the panel is enabled. No keys are assigned by default.

**Show map markers** enables a gold arrow at the edge of the mex icon as soon as an upgrade is detected, including paused upgrades. **Show upgrade indicator** adds the tech badge. During an upgrade, the badge fills with subdued green from bottom to top behind the light digit. The digit is pale for idle T1 or capped T2/T3, and red with a dot for idle uncapped T2/T3. The incomplete target receives no separate badge. Completion replaces the badge with the new tier, cancellation returns the source to idle, and destruction removes it. FAF projects markers in the primary world view. Live mexes and their upgrade targets remain cached across discovery refreshes. The panel and markers are available for the player's army in a live game. All orders require a click or assigned key press.

The installed **ECO UI Tools v11** by 4z0t was inspected on 2026-11-20. Its manifest has no project link or asset permission statement. The gold upgrade arrow uses the PNG supplied for Claret on 2026-11-20. The panel and map markers share the same transparent texture.
