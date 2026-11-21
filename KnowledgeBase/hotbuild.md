# Hotbuild semantics

> **Answers:** context priority, pair data model, dispatch rules, template ids, timing windows, saved-data policy. **Read when:** a key does nothing or orders the wrong unit, a template disappears, a saved binding is missing, profiles are damaged. **Next:** `engine.md` for the orders API; `testing.md` for fixtures.

Mod: `ClaretHotbuild` (UID `claret-hotbuild-001`, requires Core >= 0.10.15). Always active: no toggle, a saved `enabled=false` is ignored (a private constant-true option keeps Core's binding API). Three pages: **Keyboard**, **Hotbuild**, **Contexts** — there is no repeat page.

## Data model

| Profile key | Content | Version |
|---|---|---|
| `ClaretHotbuildKeyboard` | `chord -> {preset|composite|action, double?}` — **the single source of truth** | 1–2 |
| `ClaretHotbuildContexts` | context bindings | 1–3, exported as 3 |
| `ClaretHotbuild` | presets | 1 |

- FAF key maps (`UserKeyMap`, `UserKeyDebugKeyMap`, `UserKeyActions`, `keyDescriptions`) are the engine **mirror**, rebuilt from pairs.
- Preset `key` and `grid.context` are historical metadata: preserved, never updated, used only as a fallback when the keyboard profile cannot be read. New bindings do not write them. Duplicate legacy `key` values are allowed (`Model:Put` does not reject them).
- Malformed records are quarantined **per record**: raw data preserved, valid records keep working, an unknown version blocks only its own profile, editors show a localized damaged-record summary. No deletion/recovery UI yet.
- A downgrade below the pair migration may not see bindings created on 0.10.38+.

## Contexts

Priority: land/air/navy units → empty selection → ACU/SACU/engineer → factory → silos → transport/mex/scout/other. **"Under cursor" is checked first**: a structure the selected units can upgrade is handled before the ordinary context. Chains reserve their resulting contexts in both directions.

- Removed actions stay in saved rows marked "obsolete" and are not offered for new assignments; they keep their old ids and behaviour.
- With a mixed selection, assigned **Units** take priority over Builders and building hotbuild; if the Units row is empty, "Other" applies.
- Action ids are stable; third-party and native assignments are never overwritten without an explicit request.

## Dispatch

Single choke point: `Adapter:CanBuild` in `ClaretHotbuild/modules/Adapter.lua`. Preset entries, context entries and keyboard pairs all go through `Model:Execute -> Adapter:Build`; a new caller must not issue build/factory orders directly.

- **Placement**: a unit receives a structure or template order only if the blueprint id is in `EntityCategoryGetUnitList(GetUnitCommandData({unit})[3])` **and** the unit is `COMMAND` / `SUBCOMMANDER` / `ENGINEER`. Non-builders (extractors, combat units) are rejected before any command mode starts. The rule matches the original ReUI.Hotbuild catalog check but is reimplemented here; 104 units carry the categories and cover every structure placer.
- **Factory**: a factory queues an item only when `record.kind ~= 'STRUCTURE'`; support factories are `STRUCTURE`, so a factory selection can never queue them as units. SACU keeps its own kind and stays producible.
- **Attached factories** (`EXTERNALFACTORY`: carriers, air staging, Fatboy): order goes to `GetCreator()`; the attachment must be finished (`GetFractionComplete() == 1`), the creator alive and in category `FACTORY`.
- **Mixed selections**: `Model:Execute` keeps only the factory subset (temporary `SelectUnits` transaction restored on both paths), so an engineer next to a factory never receives the queue order.
- **Priority probe parity**: the priority probe copies `factorySelection` and `factoryTechTab` from the real context, so the tech-tab filter behaves identically before and during dispatch (otherwise the key is swallowed).
- **Shift on a factory**: `ExecuteFactoryShift` falls back to the native action when the preset applies nothing; an inapplicable preset must not kill the Shift shortcut.
- **Shift never multiplies unit orders** (decision 2026-11-19): a unit preset queues one unit, a queue template queues its saved counts.
- After an order, refresh the construction panel (`construction.RefreshUI`), as native UI does.

## Keyboard

- Construction tiles show one physical key. Plain assignments take priority and modifier combinations use the corresponding theme color. The label metadata retains all matching chords.
- The build-cycle preview shows T1–T3 at the bottom center of each icon and fades in or out over 150 ms.

- Per-chord pairs are authoritative for dispatch, the keyboard editor and compatibility checks. FAF maps are rebuilt from them on change.
- Assignment happens **only** on the Keyboard page: separate "Build" and "Actions" slots; content editors show usage read-only.
- Double-press: configured per key, consumed after one execution, window **0.5 s**, never mixes unit types. When a standalone action is paired with a building preset, an eligible builder gets priority if it can perform the preset entry; otherwise the action runs.
- Quick repeat: one-shot, window **1.5 s**, never re-arms. The window, its setting and the gear were removed in 0.10.38; per-row `quickRepeat` remains legacy saved data and still executes. Invalid windows (NaN, infinity, <= 0) are rejected.
- Right-clicking a key clears any visible Claret, FAF or other-mod assignment for the displayed combination; saved sets, action definitions and other combinations remain.
- Set deletion requires confirmation and clears it from keys without deleting other slots.
- Sequential engineer selection requires a mobile engineer (`ENGINEER` + `MOBILE`); command units are excluded.
- Order grid: each domain/faction tile splits into three icon sections T1/T2/T3, all visible at once without unit labels; tech is checked against `GetCurrentTechTab()` (FAF3840). Old single slots are distributed by blueprint tech; T4 and unrecognized data are preserved. LAND/AIR/NAVAL labels are centered above the grid.

## Construction templates

- Read from the game's `build_templates` (`TemplateCatalog`). Never modified, never executed if invalid.
- Id `claret_template_<hash>` depends on composition, order and geometry — never on name or index. A changed or deleted source makes the old bind unavailable; never silently substitute another template.
- Cross-faction conversion (`TemplateCatalog/Equivalents`) only on a complete, unambiguous match, without guessing prefixes; geometry, sizes, orientation and order preserved.
- Auto-equivalents change the selected cell and fill only empty cells of other factions. Companion chains handled together: `Percival–Harbinger–Brick–Othuum`, `Mongoose–Hoplite`, `xsl0205` Iashavoh among T2 flak equivalents.
- Old binds are not auto-extended: the user re-selects the template and saves.
- Catalog refresh on open, selection change or bind press — no background polling.
- `Adapter` passes a **copy** of the geometry to `SetActiveBuildTemplate`; the selected engineer must be able to build the whole composition. Factories and replays never execute templates.
- Selection lists: templates first, then usual sort by tech level, category, name. Template rows show a localized "TEMPLATE" label and the burgundy accent.

## Unit templates (factory queue)

- Source: FAF profile `build_templates_factory` via `lua/ui/templates_factory.lua` (`GetTemplates`); records `{name, icon, templateData = {{id, count}, ...}}`. Creation/renaming stays in the game; Claret never writes this profile.
- Id `claret_unit_template_<hash>` from member ids, order and counts.
- Availability: every entry must be in the factory's engine list `EntityCategoryGetUnitList(GetUnitCommandData({unit})[3])`; an entry may follow a factory upgrade in the same queue (mirrors FAF letting a T1 factory queue a T2 template). Replays, observers and non-factory selections never queue.
- Dispatch: `IssueBlueprintCommand('UNITCOMMAND_BuildFactory', id, count)` per entry through `WithFactorySelection` (shared with single-unit orders, explicit selection transaction).
- **Faction-bound**: no cross-faction variants, no filling other factions' cells; the same composition is saved per faction.
- Catalog chain: `Catalog -> TemplateCatalog -> UnitTemplateCatalog`; `:RefreshTemplates()` on editor/picker open and key press, no polling.
- Editor: templates appear in the unit rows of their faction and type, take the tier of the highest member, show the accent and localized TEMPLATE label, and report unit count in the picker.
- Preview: construction templates use one scale for the whole composition, every building centred on its anchor and sized by `Physics.SkirtSizeX/Z` with `SkirtOffsetX/Z` (same maths as `lua/ui/templateUtils.lua` and ReUI `BuildTemplatePreview`); a terrain tile of the building layer sits behind the icon; cells keep an outline up to 64 parts. Queue templates are one horizontal strip of larger icons (up to 416 px). Stack counts sit on a dark plate with white digits and the engine drop shadow. The card is sized from the composition (min 170 wide, right-aligned), hit-test disabled, destroyed on row exit, search change and popup close.
- `BuildKeyLabels` skips every `claret_` pseudo-id so queue templates never create construction key labels.

## Names and localization

- For English building and unit names pass the **full blueprint** to `Catalog:DisplayName`, not the category table; `LOC` depends on game language, so when Claret is set to English use the blueprint's English fallback fields. Check with Russian game locale too.
- Action labels go through `ReUI.ClaretCore.Localization`; never `rawget(_G, 'ReUI')`.
- User-defined preset and template names are preserved verbatim.

## Tests

`Tests/hotbuild-adapter.lua` (mex, factory+structure, factory+engineer, ACU/SACU placement, shift keeps count 1, attached-factory guards), `Tests/hotbuild-context-runtime.lua` (shift fallback), `Tests/hotbuild-unit-templates.lua`, `Tests/hotbuild-catalog.lua`, `Tests/hotbuild-context-labels.lua`, `Tests/hotbuild-keys.lua`, `Tests/hotbuild-runtime.lua`.

## Verification gaps

In-game checks still pending for: Shift intercept after build 147, preview cleanup after closing, sizes and seams without gaps, tiling of the unit layer, the unit row, and the pair migration on a real profile with duplicate legacy keys.
