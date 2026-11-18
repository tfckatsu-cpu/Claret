# Claret: current facts

Snapshot of decisions and versions. The map of the knowledge base is `README.md`; the state of the current stage is `../Stage/stage-1-status.md`.

Versions (2026-11-18): Claret Core 0.10.14 (mod 33, build 20261118-46), Claret Hotbuild 0.10.38 (mod 74, build 20261118-148). ReUI Main 1.3.2, Core 1.7.0, Options 1.2.0. FAF3840.

## Product shape

- Ecosystem of separate UI-only mods with a shared Core. Core provides the feature registry, menu, theme, localization and selection diagnostics; it never imports Hotbuild.
- Working mods: `../mods/ClaretCore` and `../mods/ClaretHotbuild`. Other mods, `Context/sources/` and the game folder are read-only.
- Settings live in **F10 → Claret** through `ReUI.ClaretCore.RegisterSettingsSection`; there are no ReUI Options tabs for Claret.
- Hotbuild is always active: there is no toggle, and a saved `enabled=false` is ignored.
- The menu is a compact launcher plus a standard panel; the Core section is compact (552×408), Hotbuild keeps the standard size. Hotbuild has three pages: Keyboard, Hotbuild, Contexts.
- The quick-repeat window and its gear were removed in 0.10.38; the per-row `quickRepeat` field remains as legacy saved data.

## Hotbuild data model

- `ClaretHotbuildKeyboard` stores per-chord pairs (`chord → preset/composite/action`, optional double action) and is the single source of truth. FAF key maps are its engine mirror.
- `key`/`grid.context` inside presets are historical metadata from the pre-pair format: preserved, never updated, used only as a fallback when the keyboard profile cannot be read.
- Contexts are stored in `ClaretHotbuildContexts` (versions 1–3, exported as 3).
- Malformed records in any profile are quarantined per record: valid data keeps working, raw records and FAF assignments are preserved, and an unknown version blocks only its own profile.

## Behaviour decisions in force

- Context priority: land/air/navy units → empty selection → ACU/SACU/engineer → factory → silos → transport/mex/scout/other. "Under cursor" is checked first.
- Templates: only complete, unambiguous cross-faction mappings; geometry and order preserved; `claret_template_<hash>` depends on composition and geometry.
- Double-press is configured per key on the Keyboard page and is consumed after one use; the window is 0.5 s. Quick repeat is one-shot with a 1.5 s window and never re-arms.
- Sequential engineer selection requires a mobile engineer (ENGINEER + MOBILE); ACU/SACU are excluded.
- Deleting a preset/context clears its assignments only after confirmation and never touches other slots.
- Selection ignore, transport cargo and strategic rings are Core features; Hotbuild calls them through `ReUI.ClaretCore`.

## Engineering rules

- UI work: read `ui-rules.md` and `ui-style.md`. Menu: `menu-rules.md`. Hotbuild: `hotbuild-rules.md`.
- LuaPlus: no `#`, no `continue`, no `goto`, `table.getn`, `import`; ≤32 upvalues per function; module tables are strict.
- Tests: `node Tests/check-core.cjs --quiet` — auto-discovery, 66 tests; static checks for `#`, `continue`, Core→Hotbuild imports and version identity. Green is required before a task is done.
- Version identity: `Version` in `Main.lua` = `ReUI` in `mod_info.lua` = README heading; `BuildStamp` = newest CHANGELOG build.
- After in-game confirmation: sync only the changed paths with `Tools/Sync-ClaretMods.ps1`, review the diff, commit separately, push to `dev`.

## Reference material

Other mods and versions: `mod-inventory.md`, `license-audit.md`, `dependency-map.md`. ReUI internals: `reui-notes.md`, `reui-decompiled/`. Tests: `testing.md`. Release and commit: `release-checklist.md`. Decisions and rationale: `decisions.md`. Accepted gaps: `known-limitations.md`. Historical analyses: `history/`. Unverified notes: `friend-notes.md`, `community-notes.md`, `prestudy-notes.md` — not specifications.
