# Claret FAF UI modding knowledge base

Reference for writing FAF client-side UI mods (`ui_only`) in LuaPlus on ReUI. Written for AI agents and for humans who paste this folder into a project: dense rules, identifiers and numbers, no narrative.

Snapshot: **2026-11-21** · installed game **FAF 3841** (`lua.nx2`) · Claret Core 0.10.37 · Claret UI 0.2.123 · Claret Hotbuild 0.10.61 · ReUI Main 1.3.2 / Core 1.7.0 / Options 1.2.0.

## Answer path

1. **`cheatsheet.md`** — routine questions end here. Syntax bans, registration snippets, scale/depth rules, dispatch rules, commands.
2. **Router** — pick exactly one file and the named section. Two files only when the task crosses areas.
3. **Code** — if a rule here disagrees with the code you are editing, the code wins; fix the rule.

Do not read the folder sequentially. `native-key-actions.md` is data: search it by action id, never read it whole.

## Starting an AI session

Give the assistant the task, the affected feature, and the current build. Ask it to open `cheatsheet.md`, follow one route below, and verify the relevant entry point in code. Include a short log extract if the issue depends on game behavior. Ask the assistant to report what it reproduced, what it changed, what the local tests establish, and what still needs FAF verification. See [how Claret uses AI](../DEVELOPING.md) for worked examples.

## Standalone use

- This folder is self-sufficient for rules and recipes. Paths like `Context/…`, `mods/…`, and `Tests/…` identify provenance. Stage notes are local working files when available.
- Code recipes assume the Claret mod skeleton (`mod_info.lua`, `Options.lua`, `Main.lua`, `modules/`). The skeleton and the registration API are in `architecture.md`.
- Version-specific facts were checked against FAF 3840 and the ReUI versions above. On another game build, re-check APIs before trusting them.

## Router

| If the task looks like… | Read |
|---|---|
| 80% of routine work: which syntax is banned, how to register a feature/section, scale and depth rules, dispatch rules, test and release commands | `cheatsheet.md` |
| Module fails to load, `access to nonexistent global variable`, `#`, `continue`, `goto`, upvalue limit, `pcall` cost, `import` returns nothing | `luaplus.md` § Module system, Banned syntax, Limits |
| Need the engine call for orders, blueprints, categories, selection, profiles, key mapper, templates, timing | `engine.md` § Issuing orders, Key mapper, Blueprints |
| A key assignment vanishes or the whole key map rebuilds | `engine.md` § Key mapper · `hotbuild.md` § Data model |
| A ReUI API is assumed but not verified; hook does not chain; option does not save | `reui.md` § Loader, Hooks, Options, Practical cautions |
| Add a mod, feature, option, menu section; decide which mod owns code; clean up on disable | `architecture.md` § Feature registration, Settings section contract, Scope lifecycle, Recipes |
| Layout shifts, scale applied twice, positions reset after a match | `ui-code.md` § Coordinates and scale |
| Clicks fall through, a control leaks, dialog hides behind a panel, tooltip sticks | `ui-code.md` § Depth and stacking, Controls and lifecycle, Dialogs and drafts |
| Colour, font, spacing, component state, panel surface, textures | `ui-visual.md` § Colours, Metrics, Components, Panel surface, Assets |
| Menu will not open/close, section missing, key capture, Escape, drag, drafts | `menu.md` § Shell, Sections, Keybind, Closing |
| Hotbuild key does nothing or orders the wrong unit; context priority; double press | `hotbuild.md` § Dispatch, Contexts, Keyboard |
| Template disappeared, renamed, cross-faction conversion, unit queue template | `hotbuild.md` § Construction templates, Unit templates |
| Saved profile is damaged or a version is unknown | `hotbuild.md` § Data model · `engine.md` § Profiles |
| Test fails, new test needed, fixture looks stale, reload/log commands | `testing.md` § Runner, When a test fails, In-game checks |
| Shipping: version bump, sync mirrors, commit, rollback | `release.md` steps 2–7 |
| Which reference mod does what, licence, UID, dependency constraint, where sources live | `reference-mods.md` § What each mod provides, Licence rules, Dependency constraints |
| Native FAF action id, its handler, whether Claret has an equivalent | `native-key-actions.md` — search by id |
| "This costs FPS" / how to measure | `performance.md` § Method, Claret candidates |
| "Is this a known bug?", "why is this code unused?" | `pitfalls.md` § UI bugs, Engine traps, Deferred code |
| Word choice, labels, doc conventions | `glossary.md` § Naming rules |
| "Why is it designed like this?" / may I change a public surface? | `decisions.md` |

## Reading budget

| Situation | Budget |
|---|---|
| Routine question | `cheatsheet.md` only |
| One area | Router row + the named sections, ≤ 300 lines |
| Cross-area change (UI + Hotbuild, feature + release) | Two docs, max four sections |
| Debugging an unfamiliar failure | `pitfalls.md` § Engine traps · owner doc for the fix |

If a section answers the question, stop reading. Do not load whole files to "get context". `native-key-actions.md` is ~70 KB of data: search it, never load it whole.

## Ground truth and evidence

1. Code in the repository.
2. This base (derived from the same code and the owner documents in `Context/`).
3. Historical notes — rationale only, never a specification.

- Facts verified in a live game or in `lua.nx2` are marked. Everything else is an implementation-derived expectation.
- Unverified community claims and pending checks are collected in `pitfalls.md`; never promote them to rules silently.
- Stubs, Lua parsing and unit tests do not prove rendering, input or orders.

## Answer rules

- Cite the owning file and section (`§`).
- Separate fact, assumption and unknown. "Should work" is not "verified".
- Never invent a Claret API, option key, profile key or colour; if it is not in the base, it is not known — say so.
- Do not add abstractions, config or files that the task does not need.

## Not in this base

- Project status, pending in-game checks, build history — working notes, not knowledge.
- Decompiled sources and the full mod inventory beyond `reference-mods.md`.
- Assets (fonts, textures, icons): names and rules only, no binaries.

## Files

| File | Role |
|---|---|
| `cheatsheet.md` | the 80% facts, paste-friendly |
| `luaplus.md` | language and module system |
| `engine.md` | FAF 3840 runtime APIs |
| `reui.md` | ReUI library |
| `architecture.md` | mod split, registry, contracts, skeletons |
| `ui-code.md` | implementation patterns |
| `ui-visual.md` | tokens, metrics, components |
| `menu.md` | menu shell |
| `hotbuild.md` | Hotbuild semantics |
| `testing.md` | tests and in-game checks |
| `release.md` | shipping |
| `reference-mods.md` | reference mods, licences, dependencies |
| `native-key-actions.md` | native action data (search only) |
| `performance.md` | measurement |
| `glossary.md` | terms and writing rules |
| `pitfalls.md` | traps, bugs, gaps |
| `decisions.md` | ADR log |
