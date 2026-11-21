# Claret UI — test build 0.2.108

Child mod of Claret Core: game-interface overlays that Core does not own. The mod fills the `UI` section of the Claret launcher; Core keeps its placeholder until Claret UI is installed.

## InfoShare

Use F10 → Claret → UI → InfoShare to toggle the work list and labels above units independently. InfoShare tracks SMD construction, experimental construction and commander upgrades. SMD interceptor readiness remains a separate notification. The list shows up to five rows and scrolls for additional work. The list and map labels fade in and out. Progress fill remains visible at every background transparency setting. The list size, background transparency and map label size can be set independently. Drag the header to save the list position. Locking the list makes it pass clicks and wheel input through to the game. Map labels use outlined white text, with separate optional unit icons for experimentals and SMD. Active work is listed first, and results remain for 1.5 seconds before fading out.

Work in all three categories is shared automatically with connected allies while Claret UI is enabled, including with both displays off. The positions of shared work are included when available. The list shows unit and upgrade icons. The display toggles, position lock and appearance sliders are in the main settings, with filters and map icon toggles under Advanced. Stock FAF Notify can supply experimental and commander events for allies without InfoShare. Stock experimental events are grouped by blueprint because they have no per-unit identifier. Stock Notify provides no SMD construction event. An unfinished structure that disappears is marked interrupted. Stale snapshots expire without implying cancellation.

Reference: installed TeamInfo Share v11 by 4z0t and FAF lua.nx2, checked 2026-11-20.

## Features

| Feature | Toggle | Source of the behaviour |
|---|---|---|
| ACU Health panel | `ACU Health panel`; adjustable panel size from 50% to 200% | ACU HP Monitor by NITROFIX |
| Better Minimap | Optional zoom auto-hide and border hiding; implemented in Core | ZeP_MiniMapZoom and Extra mini map as references |
| All Rings | `All Rings`; configurable preview keys and range filters | [Rings For All](https://github.com/4z0t/FAF-UI-Mods/blob/develop/Docs/Overview/RingsForAll.md) by 4z0t and Nomander, installed release 7 (2026-11-20) |
| Mass extractors | Show mex panel, map markers and numbered mode | ECO UI Tools (EUT) v11 by 4z0t, installed copy checked on 2026-11-20 |
| Selection Info | Show selection HUD | DynamicSelectionInfo v3 / ReUI module 1.2.0 by Nuggets HotCheese, installed copy checked on 2026-11-20 |
| Engineer Indicators | Tier number and idle state above own T1–T3 engineers; optional far-zoom hiding | Idle Engineers Light v12 by 4z0t, installed copy checked on 2026-11-21 |
| Reveal Positions | Show starting positions | Reveal Positions (legal) v4 by Myxir, Eternal-, Nomander and Erador; installed copy checked 2026-11-20 |
| Notifications | HQ upgrade, ACU upgrade, strategic missile ready; compact or center | FAF 3840 and Strategic Missile Construction Alerts v2 by SonofaMitch |
| Team info, eco panel, score/reclaim/economy | — | planned |

In **F10 → Claret → UI**, the left column lists feature groups. Selecting a group keeps that column the same width and expands the right side to show the group's settings. Select the same group again to collapse the right side. Each column ends below its own content, and both share a title bar.

The ACU Health panel is created once per match. Its toggle preserves the saved position. The panel shows HP, regeneration per second, and shield charge as a percentage. The upper blue strip represents the charge. Below 15% health, the border and health bar pulse. Below 5%, red corner brackets pulse twice per cycle. The two levels clear at 17% and 7%, respectively. The HP readout stays visible throughout. A positive shield ratio is enough to show the percentage. Identifying an installed shield through its blueprint and enhancements also lets the panel show zero or unavailable charge. The 50–200% size slider updates the panel while dragging and saves the chosen size with the profile. Panel size is independent of the game's UI scale. Position is stored in logical units and restored through the UI scale. **Lock panel position** disables dragging and lets clicks pass through the HUD. The lock is saved in the profile.

The panel identifies commanders through the FAF avatar category API and shows a search message while commander or health data is unavailable. As soon as FAF confirms the commander's death, the panel removes the health and shield bars and displays `Skill issue` for two seconds. The panel then cracks along jagged burgundy edges. The shards scatter and fade as they fall over 0.72 seconds, and the panel hides. Switching the focused army resets the tracked commander and restores the panel for the new focus.

### All Rings

Enable the feature under **F10 → Claret → UI → All Rings**. Use the Shift and Ctrl buttons at the top to choose shortcuts for attack and build range independently. Both start on Shift. The attack shortcut previews weapon and intel ranges for the selection and for the unit under the cursor. Hover can show enemy ranges when FAF exposes the unit's blueprint.

The build preview shows the range of selected builders at the cursor. It moves to the builder or its queued destination while placing a building or issuing a repair, reclaim or guard order. Hold Alt with an engineer or factory selected to preview the 28-unit reclaim radius.

**Advanced** starts collapsed. It contains individual weapon and intel filters, the minimap switch, and an option to include footprint and target size in build range. All Rings is off by default. Its settings are saved in the Claret UI profile.

The user confirmed All Rings in FAF for Claret UI 0.2.38 (build 20261120-41) on 2026-11-20. Individual scenarios and mod combinations were not reported.

Do not run the original mod next to the equivalent Claret UI feature.

## Engineer Indicators

Open **F10 → Claret → UI → Engineer Indicators** to show tier numbers above your T1–T3 engineers on the main map. Red digits indicate idle engineers and white digits indicate active engineers. Commanders and support commanders are excluded. The indicators start off. **Indicator size** ranges from 50% to 200% and uses the game's UI scale. At 100%, markers are 18 logical pixels tall. **Hide at far zoom** is enabled by default. Markers fade between 55% and 65% of the camera range as you zoom in or out. A full opacity change takes about 150 ms when the camera snaps. Disable Idle Engineers Light to avoid duplicate markers.

Claret reuses off-screen markers and updates their positions every frame while they are visible. Position and colour updates stop when the markers are fully transparent. Colour checks are spread across frames, targeting an update every 200 ms per visible engineer. The pool adds at most 24 new markers per frame. Roster discovery uses FAF's category selector every two seconds, deferring while a command mode or input capture is active. Existing unit sync data supplements discovery between scans.

**Optimize display** is off by default. Turn it on to draw at most 128 markers at once. Idle engineers have priority, and existing markers are kept first among engineers with the same status. Shown markers follow the camera every frame. Engineers without markers are scanned in batches, with a target sweep of about 200 ms at 60 FPS for 600 engineers. New markers may appear gradually after a fast pan. When the option is switched on during a match, the pool gradually frees excess controls.

**Idle engineers only** is off by default and can be used with or without display optimization. An engineer's red marker fades over about 150 ms when FAF reports that the engineer is busy. Claret stops checking the engineer's screen position after the marker has faded and continues to sample its idle state in batches.

## Notifications

Experimental completion alerts skip the spawned Novax satellite (`xea0002`) and Othuy (`xsl0402`). The Novax Center and Ythotha still qualify. For a local spawn-menu command, Claret suppresses up to the requested number of matching experimental completions within 1.5 game seconds. FAF identifies these events by blueprint, so an overlapping build of the same type is distinguished only by the total number of completions. The user confirmed the overall result in FAF on 2026-11-21 for build 20261120-105.

The project owner confirmed the 0.2.86 build in FAF on 2026-11-20. Individual scenarios were not specified.

On 2026-11-20 the project owner confirmed SMD notifications in FAF, then confirmed 0.2.88 with the SMD thumbnail. Experimental completion and SMD discovery without selection remain without separate in-game confirmation.

Under **F10 → Claret → UI → Notifications**, enable each event independently. All five switches start off. **Compact** is the default display. It places up to three single-line cards above the lower HUD for four seconds each and saves a 50–200% size setting. **Center** shows one line at a time directly over the map, with a slide and fade lasting 2.6 seconds in total. Both use the FAF UI scale and pass pointer input through to the game. The card grows to fit the complete line and reduces the font size when the available width is too small.

- **HQ upgrade completed** uses the stock FAF completion signal for the player's land, air, and naval T2/T3 HQs. The notification uses the stock construction thumbnail and button frame. The event supplies the HQ tier and factory type. The thumbnail uses the player's faction because the event omits the completed unit ID and faction. An HQ built with another faction's technology may therefore show a thumbnail for the player's faction.
- **Commander upgrade completed** uses the player's ACU completion signal and shows a short EN/RU message with the installed enhancement's game icon. Messages are keyed by enhancement ID, with ACU blueprint overrides where needed. Russian messages agree with the upgrade label in gender and number. Seraphim-specific and other unmapped upgrades use their localized game names in a neutral message. If the game lacks a matching texture, the alert shows only the message.
- **Strategic missile ready** uses increases in a known, owned launcher's strategic ammunition, such as `0 → 1` or `1 → 2`. All increases use the same brief readiness message. Launch structures use the silo icon and submarines use the icon with waves. Other launchers show text alone. First readings establish a baseline. The feature uses synced unit IDs, read-only selection observations and selected builders' targets to discover launchers. Ammo is sampled every 0.5 seconds while the switch is on. Completion and launch between samples can cancel out in the count. Coverage of launchers that never appear in those sources depends on FAF's unit sync and awaits live verification.

- **Experimental completed** uses the stock FAF completion signal for the player's experimentals. It shows the localized blueprint name and a construction thumbnail when available.
- **SMD interceptor ready** shows every observed increase in a known, owned T3 strategic defense installation's stock, including rearming after firing. The alert shows the gain, the resulting count and the installation's construction thumbnail when available. Detection uses the same discovery and sampling as strategic missiles. Coverage and net-count limitations apply to both.

The feature is active during a player's own live army view. Its FAF notification subscriptions and missile watcher are scoped to the match. Event sources feed the same display, which owns card timing and animation. Strategic Missile Construction Alerts v2 was consulted for behaviour on 2026-11-20. Claret UI uses its own code and the shared Claret theme.

## Reveal Positions

Enable **F10 → Claret → UI → Reveal Positions** to show enemy starting locations, names, faction icons and army colors. Left-click a label to dismiss it for the match. Choose no automatic hiding or hide at 1, 5 or 10 minutes of game time; the default is no automatic hiding. The marker size slider saves a scale from 50% to 200% and updates markers immediately. Faction marks use flat blue, green, red and yellow colors, derived from the shared Core artwork. The dark background behind the text only has an independently saved 0–100% transparency slider, defaults to 100% transparent, and changes while dragging. A thicker underline shows the army color. Labels use Nunito through the shared Claret theme; text, icon and underline positions are rounded to screen pixels at fractional scales. Text rendering at different scales still needs in-game verification. Hidden random, balanced and balanced-flex spawns show every map start as an anonymous possible start; reveal variants use the game display. Disabled by default; unavailable in replays. Do not enable the original Reveal Positions mod at the same time. The user confirmed the overall result in FAF on 2026-11-20 for Claret UI 0.2.80; individual scenarios were not specified.

## Selection Info

Enable **F10 → Claret → UI → Selection Info → Show selection HUD**. The panel is off by default. Individual stat switches are under **Advanced**, which starts collapsed. Values are grouped into resources, costs, results and combat, with an optional unit count. The panel collapses empty groups and columns. **Show labels and headings** switches to a numbers-only display. The value colors use the shared theme's bright HUD palette. Health is green, mass is light green, energy is yellow, shields are cyan, and mass destroyed is red.

**Dynamic display** is enabled by default. A field appears when it applies to at least one selected unit. Applicable fields can display zero, such as an empty shield, a builder's reclaim total, or resource flows that cancel out. With dynamic display disabled, the HUD displays all individually enabled fields, including zeros.

Drag with the left mouse button to save the HUD position. **Lock panel position** disables dragging and makes the HUD click-through. **Panel size** scales both the HUD and its text from 50% to 200% and saves the chosen size. The saved position is independent of the HUD size. **Panel background transparency** adjusts the fill alone from 0% to 100%.

The panel takes a snapshot on each visible selection event and hides when selection is cleared. Health and economy values reflect the last selection event. DPS is outside this build's stat set. While the HUD is enabled, Core's composition panel is suspended. Turning the HUD off restores Core's panel according to its saved setting. Disable DynamicSelectionInfo in the FAF mod manager if using Claret's panel.

## Requirements

Claret Core 0.10.27 or newer and ReUI (Core 1.7.0, UI 1.0.0, Options 1.2.0). Client-side only.

## Mass extractors

In **F10 → Claret → UI → Mex Overhaul**, turn on **Show mex panel**. **Panel display** switches immediately between **Static** (all seven cells) and **Adaptive** (only tiers with mexes). Adaptive mode hides the panel when no mexes are present and resizes immediately as tiers appear or disappear. Cells are created only for tiers included in the current layout. The backdrop exists only while the panel has cells to show. Map marker projection runs independently of the panel's layout and visibility in adaptive mode. T1 and T2 each show idle, paused, and upgrading cells. T3 has only an idle cell. Three DDS files from the installed Redux ACU Icons v1 pack by macdeffy identify the tier. The icons display at 36 logical pixels. The installed folder is named ASI Medium. Macdeffy granted reuse with credit in the [Redux Strategic Icons thread](https://forum.faforever.com/topic/2926/redux-strategic-icons). A gold arrow identifies upgrading mexes and the FAF pause mark identifies paused upgrades. Hover over a cell for its controls. Hold the left mouse button over a cell and move the pointer to drag the panel. Releasing the button after a drag saves the position in logical screen units and flushes it to disk. A click still activates the cell. **Lock panel position** disables dragging and saves the lock setting in the profile.

| Cell | Left click | Right click | Ctrl + left | Ctrl + right |
|---|---|---|---|---|
| Idle T1/T2 | Select all | Select on screen | Upgrade all | Upgrade on screen |
| Paused T1/T2 | Select all | Resume all | Select highest progress | Resume highest progress |
| Upgrading T1/T2 | Select all | Pause all | Select highest progress | Pause lowest progress |
| T3 | Select all | Select on screen | Select all | Select on screen |

Each cell shows its count above the mex icon. On paused upgrades, the opaque pause mark is aligned to the green core of the T1 or T2 mex icon. **Panel background transparency** applies to one continuous panel backdrop from 0% to 100%. Cell fills are drawn only at 0% transparency. Icons, counts, and progress tracks stay visible. The panel shows tracks for up to ten upgrades per cell, ordered by progress. Fills grow from the left edge of their own track and remain inside the cell at each panel scale. **Panel size** scales the panel from 50% to 200% in 5% increments and saves the value in the current profile. Map marker sizes are independent of this setting. The **Claret UI** category in FAF's hotkey dialog contains the corresponding selection and upgrade commands, including joint T1/T2 commands for active or paused upgrades. Hotkeys dispatch while the panel is enabled. No keys are assigned by default.

**Show map markers** displays the tech badge with its progress fill. **Show upgrade indicator** enables a gold arrow at the edge of the mex icon as soon as an upgrade is detected, including paused upgrades. Either switch can be enabled separately, and enabling both shows both overlays. During an upgrade, the badge fills with subdued green from bottom to top behind the light digit. The digit is pale for idle T1 or capped T2/T3, and red with a dot for idle uncapped T2/T3. The incomplete target receives no separate badge. Completion replaces the badge with the new tier, cancellation returns the source to idle, and destruction removes it. FAF projects markers in the primary world view. Live mexes and their upgrade targets remain cached across discovery refreshes. The panel and markers are available for the player's army in a live game. All orders require a click or assigned key press.

The installed **ECO UI Tools v11** by 4z0t was inspected on 2026-11-20. Its manifest has no project link or asset permission statement. The gold upgrade arrow uses the PNG supplied for Claret on 2026-11-20. The panel and map markers share the same transparent texture.
