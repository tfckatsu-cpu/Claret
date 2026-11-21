# Claret Reclaim experiment

Archived from Claret UI 0.2.112, build 20261121-115, on 2026-11-21. This folder is outside the game's mod directory.

`ClaretUI/` preserves the renderer, spatial index, data feed, and FAF reclaim hook with their original module paths. `integration.patch` records the options, RU/EN settings, and runtime registration relative to the Claret UI mod root. Review that patch against the current mod before restoring the feature. `claret-ui-reclaim.lua` is its standalone local regression test and expects the project root as the working directory.

The experiment shows individual mass labels at close zoom and cell sums at far zoom. The settings include a minimum mass per prop and label scale. The vanilla toggle and Ctrl+Shift activate the display when Claret owns the overlay. The installed ReUI.Reclaim 1.2.1 and FAF 3841 served as behaviour references. The build 115 log recorded 128 displayed overview labels at a threshold of 10. Live visibility and FPS were awaiting user confirmation when the experiment was archived.
