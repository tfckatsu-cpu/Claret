# ClaretHotbuild rules

- Working modules Model/Catalog/Adapter/Keys/Runtime/Editor live in the separate ClaretHotbuild mod. Profile: ClaretHotbuild.
- With a mixed selection, assigned “Units” take priority over “Builders” and building hotbuild; if the Units row is empty, use “Other.” Action IDs are stable; third-party and native assignments are not overwritten without a request.
- TemplateCatalog reads the game's `build_templates`. Do not modify the source; do not execute invalid data.
- Template ID `claret_template_<hash>` depends on composition, order and geometry, not on name or index. A changed or deleted source makes the old bind unavailable; never silently substitute another template.
- Cross-faction conversion goes through TemplateCatalog/Equivalents, only on a complete unambiguous match, without guessing prefixes. Preserve geometry, sizes, orientation and order.
- Do not auto-extend old binds: the user re-selects the template and saves.
- Catalog refresh happens on open, selection or bind press — no background polling.
- Adapter passes a copy of the geometry to `SetActiveBuildTemplate`; the selected engineer must build the whole composition. Factories and replays do not execute templates.
- In selection lists, templates come first, then the usual sort by tech level, category, name.
- The list and bind cell must show a localized “TEMPLATE” label and use Theme's burgundy accent.

- User decision (2026-11-13): the pair of slots is stored separately for each key; compatibility is checked on assignment while preserving the other slot. Old `grid.context` links are migrated per assigned key; the old field remains in data for historical compatibility only. Key assignment and clearing happen only on the “Keyboard” page; preset and composite-bind editors show key usage as read-only.

- Action/context pairs removed from the catalog are not offered for new assignments; saved rows and their quick repeat or “if empty” fallback retain their old IDs and behavior. FAF's native paused upgrade acts on the structure under the cursor.

- Build 20261113-30: the absolute-mode, quick-repeat, fallback, and obsolete-row-list controls were removed from the composite-bind editor; saved data and its execution were preserved. For compatible standalone actions, double-press is configured per key on the “Keyboard” page and does not mix unit types. When a standalone action is paired with a building preset, an eligible builder gets priority if it can perform the preset entry; otherwise the action runs. In-game verification is pending.

- Decision (2026-11-14): check the “Under cursor” context first for a structure that the selected units can upgrade; chains reserve their resulting contexts in both directions. An unsuitable cursor target or structure falls through to the ordinary context. Removed actions remain in saved assignments marked “obsolete” and are not offered again. Missile launch selects the type based on the available order; mixed types are not launched. Set deletion requires confirmation and clears it from keys without deleting other slots.

- 2026-11-14: per user decision, right-clicking a key clears any visible Claret, FAF, or other-mod assignments for the displayed combination; saved sets, action definitions, and other combinations remain.
- 2026-11-14: in the original layout, each domain/faction order tile is divided into three icon sections from left to right: T1/T2/T3; all are shown at once without unit labels. Tech level is checked against `GetCurrentTechTab()` in FAF3840. Old single slots are distributed by blueprint tech; T4 and unrecognized data are preserved.
- User decision (2026-11-15): LAND/AIR/NAVAL labels are centered over the order grid; each section visibly shows T1/T2/T3. Auto-adding equivalents changes the selected cell and fills only empty cells for other factions. The `Percival–Harbinger–Brick–Othuum` and `Mongoose–Hoplite` chains are handled together; `xsl0205` Iashavoh is included among T2 Flak equivalents.

- Hotbuild localization (user check in FAF, 2026-11-15, build `20261115-48`): for English building and unit names, pass the full blueprint to `Catalog:DisplayName`, not the category table; `LOC` depends on game language, so when Claret is set to English, use the blueprint's English fallback fields. Also check separately with Russian game locale. Sources: `../mods/ClaretHotbuild/modules/Catalog.lua`, `Tests/hotbuild-catalog.lua`.
- For action labels, use the localization service through `ReUI.ClaretCore.Localization`, as existing modules do; do not rely on `rawget(_G, 'ReUI')`. After switching to direct access, the user confirmed that labels in the order list were fixed; the failure mechanism involving `rawget` was not separately measured in that scenario. Check available orders in FAF and run local tests with ReUI in the module environment. Sources: `KeyboardBindings.lua`, `KeyboardEditor.lua`, `ContextActions.lua`, `Tests/hotbuild-context-labels.lua`.

## Current data model (verified 0.10.38, 2026-11-18)

- ClaretHotbuildKeyboard pairs are the single source of truth: `chord -> preset / composite / action` plus an optional double action. Dispatch, the keyboard editor and compatibility checks read pairs; FAF key maps are rebuilt from them.
- Preset `key` and `grid.context` are historical metadata: preserved, never updated, and used only as a fallback when the keyboard profile cannot be read. New bindings do not write them.
- Profiles are loaded with per-record quarantine: broken records keep their raw data, valid records keep working, an unknown version blocks only its own profile, and editors show a localized damaged-record summary.
- Hotbuild is always active. A saved `enabled=false` is ignored; there is no menu toggle.
- Double-press actions are consumed after one execution and limited by a 0.5 s window. Quick repeat is one-shot, limited by a 1.5 s window and never re-arms. Invalid windows (NaN, infinity, <=0) are rejected.
- The quick-repeat window, its setting and the gear were removed in 0.10.38. The per-row `quickRepeat` field remains as legacy saved data and still executes.
- Sequential engineer selection requires a mobile engineer (ENGINEER + MOBILE); command units are excluded.
- Version identity: `Version` in Main.lua = `ReUI` in mod_info.lua = README heading; `BuildStamp` = newest CHANGELOG build; Hotbuild requires Core >= 0.10.15.
## Order dispatch rules (verified 2026-11-19, build 0.10.40)

Single choke point: Adapter:CanBuild (ClaretHotbuild/modules/Adapter.lua). Preset entries, context entries and keyboard pairs all dispatch through Model:Execute -> Adapter:Build, so a new caller must not issue build/factory orders directly.

- Placement rule: a unit may receive a structure or template order only if the blueprint id is in EntityCategoryGetUnitList(GetUnitCommandData({unit})[3]) **and** the unit passes CanPlaceBuilds (COMMAND / SUBCOMMANDER / ENGINEER). Non-builders (mass extractors, combat units) are rejected before any command mode starts. FAF3840 data check: 104 units carry ENGINEER/COMMAND/SUBCOMMANDER and cover every structure placer; the only CONSTRUCTION unit outside the list is the Megalith (XRL0403), whose targets are CRABEGG structures without BUILTBY* categories, so they never reach the catalog.
- Factory rule: a factory queues an item only when ecord.kind ~= 'STRUCTURE'. Support factories are STRUCTURE, therefore a factory selection can never queue them as units; SACU keeps its own kind and stays producible. Vanilla equivalent: lua/keymap/hotbuild.lua filters by uildableCategories only, which never contains structures.
- Attached factories: for EXTERNALFACTORY (carriers, air staging, Fatboy) the order goes to GetCreator(), as vanilla TranslateExFacUnits does; Claret additionally requires the attachment to be finished (GetFractionComplete()==1) and the creator to be alive and in category FACTORY.
- Mixed selections: Model:Execute keeps the factory subset (temporary SelectUnits transaction with restoration on both paths), so an engineer next to a factory never receives the queue order.
- Priority probe parity: the hotbuild-priority probe in Runtime copies actorySelection and actoryTechTab from the real context, so the factory tech-tab filter is evaluated identically before and during dispatch (otherwise the key was swallowed).
- Shift on a factory: ExecuteFactoryShift falls back to the native action when the preset applies nothing; an inapplicable preset must not kill the Shift shortcut.
- Tests: Tests/hotbuild-adapter.lua (mex, factory+structure, factory+engineer, ACU/SACU placement, shift keeps count 1, attached-factory guards) and Tests/hotbuild-context-runtime.lua (shift fallback).

## Unit (factory queue) templates (in-game 0.10.42, refined 0.10.43, 2026-11-19)

Source: FAF profile `build_templates_factory` via `lua/ui/templates_factory.lua` (`GetTemplates`). Records are data only: `{name, icon, templateData = {{id, count}, ...}}`. Creation and renaming stay in the game (construction panel Templates tab or FAF's `create_template_factory`); Claret never writes this profile.

- Identity: `claret_unit_template_<hash>` is computed from member ids, their order and counts, never from the name or list index. A changed or deleted source makes the old binding unavailable; another template at the same index is never substituted.
- Availability: dispatch lives in `Adapter:CanBuild` (branch before the tech-tab check) and `Adapter:TemplatePlan`. Every entry must be in the factory's engine list `EntityCategoryGetUnitList(GetUnitCommandData({unit})[3])`; an entry may follow an earlier factory upgrade in the same queue, mirroring FAF's rule that lets a T1 factory queue a T2 template. Replays, observers and non-factory selections never queue.
- Dispatch: `IssueBlueprintCommand('UNITCOMMAND_BuildFactory', id, count)` per entry through `WithFactorySelection` (shared with single-unit factory orders, including the explicit selection transaction). Shift never repeats a unit order: the composition is queued once with its saved counts.
- Faction-bound (user decision 2026-11-19): no cross-faction variants are created and no other faction cell is filled; the same composition is saved per faction.
- Catalog composition in Runtime: `Catalog` → `TemplateCatalog` → `UnitTemplateCatalog`; `:Catalog():RefreshTemplates()` refreshes the chain on editor/picker open and on key press, without polling.
- Editor: unit templates appear in the unit rows of their faction and type, take the tier of the highest member, show the burgundy accent and the localized TEMPLATE label, and report the unit count in the picker list.
- `BuildKeyLabels` skips every `claret_` pseudo-id so queue templates never create construction key labels.
- Shift no longer multiplies unit orders (user decision 2026-11-19, superseding build 2026-1117-147): a unit preset queues one unit and a queue template queues its saved counts.
- Tests: `Tests/hotbuild-unit-templates.lua`; the shared factory path stays covered by `Tests/hotbuild-adapter.lua`.