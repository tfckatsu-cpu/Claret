# Claret Localization and Terminology Guide

This guide standardizes concepts in agent-facing documentation. It does not contain Russian UI strings. User-facing game labels must be obtained from FAF localization/blueprints or Claret's localization service rather than hard-coded from this file.

| Term | Usage |
|---|---|
| ACU | Keep the acronym unchanged. |
| SACU | Keep the acronym unchanged. |
| Hotbuild | Feature/mod name; preserve spelling. |
| extractor | Use for a mass extractor in documentation. Short UI labels may use the game's localized name. |
| unit | Use for a game unit; take proper names from the game. |
| blueprint | Documentation term for a unit blueprint; usually do not show this word in the UI. |
| order | Use for an in-game order; use FAF descriptions for its displayed name. |
| action | A Claret/Hotbuild action that may issue an order or change selection. |
| selection | Use “empty selection” for no selected units. |
| binding | A user key assignment; do not use it to mean a dependency or relation. |
| key assignment | Preferred explanatory term; “bind” is acceptable as a short label. |
| multifunction binding | Use for the multifunction-binding feature; distinguish it from an ordinary key assignment. |
| preset | A Hotbuild build profile. Preserve user-defined names verbatim. |
| build template | A saved in-game build layout. Preserve user-defined names verbatim. |
| context | The current selection type in the multifunction-binding editor. |
| builder | Engineer/commander context used by Hotbuild. |
| factory | Context and in-game structure; use the in-game name for a specific building. |
| mex | Short in-game slang for a mass extractor; use “extractor” in documentation. |
| T1 / T2 / T3 / T4 | Keep Latin tech-level notation. |
| obsolete assignment | A saved reference that cannot be assigned again. |
| chain-occupied | A context reserved by continuation of an action. |
| fallback action | Use for an alternate action after the primary action finds no target; do not confuse with an in-game order. |
| quick repeat | Hotbuild's repeated-key-press mechanic. |

Do not manually translate unit names or native order names. Use in-game blueprint descriptions through `LOC` and FAF's native action descriptions. Only Claret UI strings should be entered manually in tables. Keep logs in English.

## Terms added 2026-11-18

| Term | Usage |
|---|---|
| pair | One ClaretHotbuildKeyboard record: chord -> preset/composite/action; the source of truth for bindings. |
| quarantine | Per-record isolation of a malformed saved record; the raw record is preserved, valid data keeps working. |
| deferred feature | Implemented but intentionally not wired code (Construction/Orders/Multifunction); not dead code. |
| launcher | The compact standalone starting panel of the Claret menu. |
| settings panel | The standard-sized section panel next to the launcher. |
| key capture | Temporary mode where Claret reads the next key combination instead of the game. |
| source of truth | The single structure that owns a fact (pairs for bindings, profile for settings); everything else is a mirror. |