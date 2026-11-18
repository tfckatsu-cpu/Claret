---
name: claret-project
description: Work on the Claret project and its FAF mods: studying sources, Lua, ReUI, UI compatibility, and sensible delegation between agents.
---

# Claret / FAF

Before changing anything read `AGENTS.md` and `Stage/stage-1-status.md`; for UI work read `Context/ui-rules.md` and `Context/ui-style.md`. The knowledge-base map is `Context/README.md`, current facts are in `Context/quick-reference.md`. Sources in `Context/sources` and other mods are read-only; the working mods are `../mods/ClaretCore` and `../mods/ClaretHotbuild`. Do not copy other mods' code. Follow the user's instructions and the current access limits.

## Cheap delegation

Call a subagent only when current instructions and the user allow it. For a small self-contained study, API lookup, fact check or simple overview, use an available cheap model (for example Luna) if permitted. For complex design and integration use your own work or a suitable model; do not trade quality for savings. Bound the task and the output, pass concrete paths and context, and use a fork without full history when possible. Do not parallel-edit one file and do not delegate sequential steps without a benefit. Verify and integrate results yourself. Do not repeat calls after hitting a limit.

## FAF rules

FAF Lua: `table.getn` instead of `#`, `import` instead of `require`, `math.mod`; be careful with missing globals and module fields. Do not assume stock Lua compatibility with LuaPlus; respect the upvalue limit (32). Verify game APIs against the installed version; the verified snapshot is FAF3840 at `C:/ProgramData/FAForever/gamedata/lua.nx2` (read-only). ReUI versions and dependencies are in `quick-reference.md`. Create UI after the interface exists; clean up subscriptions and controls; never change the simulation.

Preserve binding IDs, order and profile data; when changing a format, read old data and never migrate silently with lost commands. Run local logic and syntax checks; stubs do not confirm in-game behaviour. Document the scenario and limitations in the current stage.

## In-game checks

The user allows using the computer for Claret checks. When a control tool is available and an in-game check helps the task, inspect the game state and reproduce the problem or verify the change yourself instead of offloading it to the user. Follow the current computer-use instructions; do not disturb someone else's or an important match and do not lose unsaved data. If the game is unavailable or a check is impossible, state the exact limitation.

To reload changes quickly in a suitable test match: reveal the hidden top panel, press the first button "Menu (F10)", then "Restart game" and wait for the new match. The user explicitly allowed this for testing; check the current state and never restart an important or networked game without separate permission. Mind the UI scale and the active mod version. After a check, distinguish what you actually saw, local test results and unverified scenarios; on failure read the current game log.
