# Glossary and naming

> **Answers:** term choice, naming and doc-writing rules. **Read when:** wording a label, message, log line or document; translating a concept. **Next:** `ui-visual.md` for component names.

Terms used in Claret code, docs and UI. User-visible labels come from the localization service or game blueprints — this table is naming guidance, not a string table.

| Term | Usage |
|---|---|
| ACU / SACU | keep the acronyms |
| Hotbuild | feature/mod name, spelling fixed |
| extractor | mass extractor in documentation; short UI labels may use the game's localized name |
| mex | in-game slang; use "extractor" in documentation |
| unit | game unit; proper names from the game |
| blueprint | documentation term for a unit blueprint; usually not shown in UI |
| order | in-game order; displayed name from FAF descriptions |
| action | a Claret/Hotbuild action that issues an order or changes selection |
| selection | set of selected units; "empty selection" = none |
| binding | a user key assignment; never a dependency or relation |
| key assignment | preferred explanatory term; "bind" acceptable as a short label |
| pair | one `ClaretHotbuildKeyboard` record: chord → preset/composite/action; source of truth for bindings |
| multifunction binding | the multifunction-binding feature; distinct from an ordinary key assignment |
| preset | a Hotbuild build profile; user-defined names verbatim |
| build template | a saved in-game construction layout; user names verbatim |
| context | the current selection type in the multifunction-binding editor |
| builder | engineer/commander context used by Hotbuild |
| factory | context and in-game structure; specific building by its game name |
| T1 / T2 / T3 / T4 | Latin tech-level notation |
| obsolete assignment | saved reference that cannot be assigned again |
| chain-occupied | context reserved by the continuation of an action |
| fallback action | alternate action when the primary finds no target; not an in-game order |
| quick repeat | Hotbuild's repeated-key-press mechanic |
| quarantine | per-record isolation of a malformed saved record; raw record preserved, valid data keeps working |
| deferred feature | implemented but intentionally not wired code (Construction/Orders/Multifunction); not dead code |
| launcher | the compact standalone starting panel of the Claret menu |
| settings panel | the standard-sized section panel next to the launcher |
| key capture | temporary mode where Claret reads the next combination instead of the game |
| source of truth | the single structure that owns a fact (pairs for bindings, profile for settings); everything else is a mirror |

## Naming rules

- Do not translate unit names or native order names by hand; use `LOC` and FAF's native action descriptions.
- Only Claret UI strings are entered manually, in `LocalizationStrings.lua` tables, under both `en` and `ru`.
- Logs stay English. Historical Russian CHANGELOG entries stay; new entries are English.
- Status messages: short, actionable, no exclamation marks.
- Feature and section titles: 1–2 words; description one line.
- Test names and PASS lines: describe the proven behaviour ("PASS: mex covers three cells with T1 extractors").

## Writing rules for this knowledge base and `Context/`

- Facts, numbers, identifiers, paths. No motivation paragraphs, no marketing, no repetition.
- One rule lives in one owner document; others link to it.
- Mark assumptions and unknowns explicitly; an unverified claim is never phrased as current behaviour.
- Say which version and date a statement was checked against.
- A document that no longer matches the code is updated or moved to history — it is never left looking current.
