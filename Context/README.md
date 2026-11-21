# Claret knowledge base

Agent-facing reference for the Claret project. Written in English; the chat with the user stays in Russian. Everything here describes the current code unless a document says otherwise. When a document and the code disagree, the code wins — then fix the document in the same task.

Current versions and pending FAF checks are listed in `quick-reference.md` and `../Stage/stage-1-status.md`.

## How to choose a file

`AGENTS.md` is read at the start of every task; it points here. This page is the map: use the table below to pick the **owner** document, read one or two files, not the whole folder.

| Your task or symptom | Read |
|---|---|
| Button/panel/label looks wrong, layout shifts, scale applied twice, dialog behind a panel, control not destroyed, tooltip stuck | `ui-rules.md` then `ui-style.md` |
| Colours, fonts, spacing, component states, visual reference | `ui-style.md` |
| Menu does not open/close, F10 entry, key capture, drag, section switching, drafts | `menu-rules.md` |
| Selection Info stats, display modes, or interaction | [Claret UI README](../mods/ClaretUI/README.md#selection-info) |
| On-screen alerts, HQ and ACU completion, strategic missile stock, display styles | [Claret UI README](../mods/ClaretUI/README.md#notifications) |
| InfoShare work list, map labels, ally exchange, and stock Notify fallback | [Claret UI README](../mods/ClaretUI/README.md#infoshare) |
| Engineer indicator tier, colour, zoom fade, or display options | [Claret UI README](../mods/ClaretUI/README.md#engineer-indicators) |
| Hotkey does nothing, preset/context assignment, double-press, templates, engineer chains, saved key data | `hotbuild-rules.md` |
| Profile fails to load, "damaged records" line, unknown version, save blocked | `hotbuild-rules.md` (data model) then `tech-findings.md` (profiles) |
| Lua error, missing global, module fails to load, `#`/`continue`, upvalue limit, `pcall` cost | `tech-findings.md` |
| ReUI API, module version, loader behaviour | `reui-notes.md` |
| Add or fix a test, runner fails, fixture categories, static checks | `testing.md` |
| Release, version bump, sync, commit, rollback | `release-checklist.md` |
| "Why is it like this?", architecture choices | `decisions.md` |
| "Does it work?", downgrade, deferred modules, unverified scenarios | `known-limitations.md` |
| Other mods, versions, UIDs, licenses, cross-mod dependencies | `mod-inventory.md`, `license-audit.md`, `dependency-map.md` |
| Performance work | `performance-hotspots.md` |
| Naming, wording, glossary | `localization-glossary.md` |
| Current project state and plans | `../Stage/stage-1-status.md` |

If a task spans two areas (for example a Hotbuild UI change), read the feature owner first, then the UI owner. Do not read `history/` unless you need the rationale behind an old decision.

## Owners: one rule, one document

| Document | Owns |
|---|---|
| `ui-rules.md` | implementation patterns: scale, depth, lifecycle, input, dialogs, data safety, dialect |
| `ui-style.md` | visual language: colours, fonts, metrics, components, states |
| `menu-rules.md` | menu behaviour: launcher/panel, sections, drag, capture, closing |
| `hotbuild-rules.md` | Hotbuild semantics: contexts, pairs, templates, repeats, saved data |
| `tech-findings.md` | engine facts and limits: LuaPlus, import, profiles, timing, SimCallback |
| `reui-notes.md` | ReUI APIs and version differences |
| `testing.md` | runner, fixtures, stubs, static checks, test rules |
| `release-checklist.md` | version identity, checks, sync, commit, rollback |
| `decisions.md` | ADR log: what was decided, why, consequences |
| `known-limitations.md` | accepted gaps, unverified scenarios, downgrade |
| `performance-hotspots.md` | measurement method and candidate hotspots |
| `localization-glossary.md` | terms and wording rules |
| `mod-inventory.md` | installed mods, versions, UIDs |
| `license-audit.md` | licenses and required notices |
| `dependency-map.md` | cross-mod dependencies |
| `feature-catalog.md` | features of *reference* mods, not Claret |

Rules that used to live in several files now live in one owner and are linked from the others. When adding a rule, put it in the owner and link it — do not copy paragraphs.

## Freshness

- Every document starts with a header: what it describes, against which versions it was verified, and the date.
- A document that no longer matches the code is either updated or moved to `history/` — it is never left as current-looking prose.
- Review notes (`friend-notes.md`, `community-notes.md`, `prestudy-notes.md`) are unverified by definition; they keep their "unchecked" header and are not used as specifications.

## History

`history/` holds superseded analyses and target specs kept for rationale: Hotbuild keys analysis, keyboard open performance study, context plan, the 2026-11-13 context target spec. They describe older builds (0.10.15, pre-pair) and must not be used as current specs. Add new history there instead of deleting context; delete only duplicates and noise.

## Sources

- `../KnowledgeBase/` — derived, self-contained AI-facing copy: entry router, cheat sheet, topic files and the native key-action list. It has no authority of its own: change the owner document here first, then regenerate the copy.

- `sources/` — read-only copies of other mods (git-ignored); start from `sources/SOURCES.md`.
- `reui-decompiled/` — decompiled ReUI reference; check the installed version before relying on an API.
- `claret-ui-reference.png` — visual reference.
