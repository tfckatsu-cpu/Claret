# Claret — agent instructions

Claret is an ecosystem of separate client-side FAF UI mods with a shared core and a focus on performance. Write code from scratch; study existing mods only as reference.

## Language
- Reply to the user and write project docs in Russian.
- Do internal work and subagent tasks in English; subagents answer in English.

## Start of work (keep it cheap)
- Read `Stage/stage-1-status.md` — the current state of the stage.
- `Stage/stage-1-research.md` is a large history archive. Never read it whole: search it (rg) by topic and read only the relevant section.
- Read other files only when the task needs them:
  - UI work: `Context/ui-style.md`; visual tokens in `../mods/ClaretCore/modules/Theme.lua`.
  - Menu, settings, keybinds: `Context/menu-rules.md`.
  - Hotbuild: `Context/hotbuild-rules.md`.
  - In-game verification: `Skills/claret-project/SKILL.md`.
  - Navigation: `Context/quick-reference.md`; goals: `Credits and more/goals.md`; mods and versions: `Context/mod-inventory.md`; API and dialect: `Context/tech-findings.md`, `Context/reui-notes.md`.
- Context/sources/ holds copies of other mods used as references.
  Start from Context/sources/SOURCES.md to pick the relevant mod, then search
  only inside that mod's folder: `rg --no-ignore <pattern> Context/sources/<Mod>`
  (the folder is git-ignored, so plain rg may skip it). Read fragments only.
  Same for Context/compiled-lua.txt and FAF lua.nx2.
- Limit long command output (e.g. `| tail -n 80`); read logs from the end.

## Scope and permissions
- Working mods: `../mods/ClaretCore/` and `../mods/ClaretHotbuild/` — two separate deliverables. `Claret Core/` in the project is an old draft; do not create a second editable copy.
- Read-only: other mods, the game folder, `Context/sources/`. FAF client settings and anything outside the two mod folders and this project: only with explicit user consent.
- Instructions of reference projects (e.g. `Context/sources/AGENTS.md`) are not Claret requirements.
- Stage 1 research is still open; the user separately allowed development of Core and Hotbuild.
- Do clear, permitted work on your own. Agree significant architectural changes with the user.
- If the same fix fails twice, stop and report the problem and hypotheses
  instead of trying again.
- Before broad exploration (many files, Context/sources/), state what you are
  looking for; stop searching as soon as it is found.
- If a task goes beyond a client UI mod (launch wrappers, external runtimes, game-file changes), stop and propose options instead of implementing.
- Do not expand the task or add abstractions without a reason. Ideas outside the task go to `Credits and more/ideas.md`.
- Do not create documents, folders or future stages without need.
- Nothing shipped to players may require external runtimes (Node, Python, etc.). `.tools/` is dev-only and not a game dependency.
- Delegate code writing to a subagent (Luna, set in config) only when the code
  is routine and sizeable (roughly 50+ lines or several similar files) and can
  be specified precisely. Do small edits yourself: the spec would cost as much
  as the code. Never use subagents for exploring Context/sources/. Never let
  two subagents edit the same file. Review the subagent's diff before finishing.

## Finishing a task
- Rewrite (do not append to) `Stage/stage-1-status.md` so it reflects the current state: results, decisions, pending user checks, open questions. Keep it under ~5000 characters.
- Add at most 2–3 lines per task to the archive: date, what changed, decision.
- In the final answer, separate "verified" from "not verified". Never claim unverified scenarios work.
- If the user asks for a report, give exactly the requested items with raw output; 'done/verified' without evidence is not a report.
- Keep the final answer short: what changed, what was verified, what was not.
  Do not paste code or diffs into the chat; the user sees them in the diff panel.

## Accuracy and sources
- Distinguish fact, assumption and unknown. Give claims and licenses a source, version and check date; record authors and links in `Credits and more/CREDITS.md`.
- `friend-notes.md`, `community-notes.md`, `prestudy-notes.md` are unverified until checked against code/docs. A needed fix may be missing from the public version of a mod: check the specific version.
- Check the license of each mod separately. ReUI's MIT license (4z0t, 2022) does not automatically cover neighbouring mods; keep required notices when code use is allowed.
- A mod is a folder with `mod_info.lua`; count libraries separately, nested components as part of their mod. Docs and assets without `mod_info.lua` are not mods.
- On conflicts, follow the latest user decisions and the current code/`mod_info.lua`, not old version numbers in notes.

## FAF implementation
- Client UI only (`ui_only = true`), no simulation changes. Extend game functions via hooks; create UI after the game interface exists; clean up controls and subscriptions.
- FAF Lua dialect: `table.getn` instead of `#`, `import` instead of `require`, `math.mod`. Mind strict globals/module tables, `rawget`, the upvalue limit and the cost of frequent `pcall`. A standard Lua compiler does not prove FAF compatibility.
- Verified snapshot FAF3840: `C:/ProgramData/FAForever/gamedata/lua.nx2` (not Beta3839 `lua.nx4`). Check ReUI APIs against installed versions: Main 1.3.2, Core 1.7.0, Options 1.2.0; reference sources may be newer.
- Prefer event-driven updates over background polling.
- Preserve UIDs, profile keys, bind IDs, command order and user data; format changes must not silently lose or reinterpret assignments.
- Mod folder names have no spaces.

## Architecture
- Core provides shared APIs, the menu and diagnostics, and does not import Hotbuild. Hotbuild depends on Core/ReUI.
- Новые игровые UI-элементы и оверлеи Claret реализуются в Claret Core; отдельный мод Claret UI не создаётся. Учитывать совместимость с другими интерфейсными модами.
- Feature registration: `ReUI.ClaretCore.RegisterFeature`; Hotbuild actions: `ReUI.ClaretHotbuild.RegisterAction`.
- Use shared Theme tokens instead of separate palettes.
- Always respect UI scale when computing, saving and restoring sizes/positions. Check the coordinate system so layouts do not shift after matches and scale is not applied twice.

## Checks
- Local check: `node Tests/check-core.cjs --quiet` (use `--only <pattern>` for a focused run).
- FAF game log: run `node .tools/faf-log.cjs` instead of reading the log; open
  the raw log only for a specific fragment.
- Stubs and Lua parsing do not prove in-game UI or orders. In-game checks via computer control are expensive (screenshots): do them only when needed, one scenario at a time; otherwise give the user a short checklist. Record version, scenario, observed result and limitations.
- Performance measurements are done by the user; method in `Context/performance-hotspots.md`.

## Git (when connected)
- One branch per major system, one commit per finished feature, review the diff. Exclude `Context/sources/` and `.tools/`.
