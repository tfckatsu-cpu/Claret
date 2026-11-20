# Claret UI — test build 0.2.33

Child mod of Claret Core: game-interface overlays that Core does not own. The mod fills the `UI` section of the Claret launcher; Core keeps its placeholder until Claret UI is installed.

## Features

| Feature | Toggle | Source of the behaviour |
|---|---|---|
| ACU Health panel | `ACU Health panel`; adjustable panel size from 50% to 200% | ACU HP Monitor by NITROFIX |
| Minimap | Optional zoom auto-hide and border hiding; implemented in Core | ZeP_MiniMapZoom and Extra mini map as references |
| Rings, selection info, team info, missile alerts, eco panel, reveal positions, idle engineers, score/reclaim/economy | — | planned, ported one by one |

In **F10 → Claret → UI**, the left column lists feature groups. Selecting a group keeps that column the same width and expands the right side to show the group's settings. Select the same group again to collapse the right side. Each column ends below its own content, and both share a title bar.

The ACU Health panel is created once per match. Its toggle preserves the saved position. The panel shows HP, regeneration per second, and shield charge as a percentage. The upper blue strip represents the charge. Below 15% health, the border and health bar pulse. Below 5%, red corner brackets pulse twice per cycle. The two levels clear at 17% and 7%, respectively. The HP readout stays visible throughout. A positive shield ratio is enough to show the percentage. Identifying an installed shield through its blueprint and enhancements also lets the panel show zero or unavailable charge. The 50–200% size slider updates the panel while dragging and saves the chosen size with the profile. Panel size is independent of the game's UI scale. Position is stored in logical units and restored through the UI scale.

The panel identifies commanders through the FAF avatar category API and shows a search message while commander or health data is unavailable. As soon as FAF confirms the commander's death, the panel removes the health and shield bars and displays `Skill issue` for two seconds. The panel then cracks along jagged burgundy edges. The shards scatter and fade as they fall over 0.72 seconds, and the panel hides. Switching the focused army resets the tracked commander and restores the panel for the new focus.

Do not run the original mod next to the equivalent Claret UI feature.

## Requirements

Claret Core 0.10.25 or newer and ReUI (Core 1.7.0, UI 1.0.0, Options 1.2.0). Client-side only; no simulation changes.
