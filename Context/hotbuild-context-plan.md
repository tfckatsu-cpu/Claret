# Context binds plan

2026-11-13. Target: hotbuild-context-spec.md; Hotbuild 0.10.15/20261113-09. Analysis only; proposals pending questions.

## 1. Model, groups, migration

ContextActions.lua: contexts/priority/builderActions, UnitContext/Classify/MatchesContext/Supports/List/Get. Add units (land/air/navy), missiles (existing silo_tactical/silo_nuclear children); preserve builder/acu/sacu/engineer IDs. Resolve groups in spec order.
ContextModel.lua: generalize childContexts, ResolveAction, EffectiveStats; return effective rows, compare action IDs across selected siblings. Update Copy/Validate/Create/BuildActions/Export. Separate structural and semantic errors. BuildActions indexes List(), excluding legacy Get-resolvable IDs. Preserve invalid/unknown rows with diagnostics; keep corruption/version save guards.
Runtime.lua Execute/RunContext/ExecuteKeyboardComposite: common arbitration, Units before hotbuildPriority/mobileFactoryPriority, no fallthrough for unavailable winner. Preserve Model.lua CopyGrid/Validate/Execute order/cycling/grid.context.

Data: ClaretHotbuildContexts v3 retains ID/name/absolute/rows and context/action/mode; reserves optional quickRepeat/fallback IDs. Hierarchy/diagnostics are not saved. Keep ClaretHotbuild v1/key IDs/maps. Migrate v1 children to own, then v2->v3 in memory. Keep missile leaf IDs/actions under missiles, no parent action. No inferred Other->Units mapping (Q1). Preserve order/modes/inactive absolute rows; explicit-save persistence, rollback, idempotency; reject unknown future fields.
Tests (context-model/actions/runtime): group modes, mixed agreement, empty/disabled rows, unavailable winner, Units+builders, migrations, corruption, IDs/order/rollback. Risks: Other mobile binds and mixed Builders change.

## 2. Editor and locks

ContextEditor.lua Create/CurrentRow/RefreshRows/SelectContext/SetChildMode/CreateContextTile/RowsFor/AddAction: generalize hierarchy/layout. Show invalid/obsolete saved values separately with replacement guidance; remove continuation exclusion where permitted.
Compatibility.lua PresetTraits/BuilderConflicts/ValidateBindingImpl/ValidateContextImpl/GetTileWarning: bidirectional Builders lock across linked presets.
KeyboardBindings.lua Validate/Set/GetChoices/Snapshot + KeyboardEditor.lua/Editor.lua: occupants/linking; shared chord uses preset grid.context, not two native assignments; preserve confirmation/rollback.
Overcharge offer edits draft only after acceptance; preserve SACU overrides. No schema bump. Absolute: one active empty row, old inactive rows retained. Use Theme/layout.scale/CanLeave, scrolling, temporary focus.
Tests (context-editor/compatibility/keyboard-editor/runtime): locks both ways, links, offer, invalid replacement, cancel, absolute rows, modifiers. Risks: viewport/stale locks/key replacement; FAF clicks/scaling pending.

## 3. Repeat, fallback, legacy continuations

ContextModel.lua Copy/Validate/Export/ResolveAction: optional quickRepeat/fallback; column validation (absolute: empty pool); whole-row inheritance pending Q3. Old fields absent; v3 reserved them.
ContextRepeat.lua Create/Remember/Continue/Clear: explicit/legacy state stores trigger/time/army/row/post-result selection, including empty (currently rejected). Repeat precedes columns; clear on expiry/selection/key changes, teardown/edits.
Runtime.lua Execute/ExecuteAbsolute/ExecuteKeyboardAction/ExecuteKeyboardComposite ordering: explicit repeat -> permitted legacy continuation -> winning row -> execution -> eligible fallback -> remember final result. EngineerHold bypasses Continue in preset/absolute paths; preserve legacy hold without bypassing explicit repeat.
ContextActions.lua Available/Execute: internal executed/not_found/unavailable/error, compatible boolean API. Fallback once only on not_found, no recursion. ConExecute selectors always return true: query candidates or confirm via selection event; unchanged selection is insufficient. Refresh context after selection changes.
options.lua: repeatWindow OptionValue default 1.5, finite positive validation; Main.lua F10->Claret setting, immediate save, no polling. UI range pending.
Tests (repeat/runtime/actions/settings): time/selection/army/replay/death guards, aliases/keys, fallback outcomes, failures/hold; legacy timing pending Q4.
Risk: IDs lack chords; FAF keys bypass ContextRepeat. Key/selection history needs events/cleanup without focus capture.

## 4. Catalog, Units, capabilities

ContextActions.lua definitions/Supports/Available/Execute: preserve IDs; commands from faf-actions-inventory.md/FAF3840 keyactions.lua. Metadata: leaf columns, selection-independent flag, order/toggle/dynamic predicate, native ID/handler, per-context deprecation. Parent pool = child intersection, not every unit capability. No saved metadata/schema change.
Units: MOBILE minus COMMAND/SUBCOMMANDER/ENGINEER/TRANSPORTATION/scouts, split LAND/AIR/NAVAL; FACTORY/EXTERNALFACTORY/blueprint precedence pending Q6. Current scouts: AIR * INTELLIGENCE. Test amphibious units/satellites/shields/mobile factories/silos/drones/Megalith.
Capability: Adapter.Context currently aggregates GetUnitCommandData; query orders/toggles per live unit at press. Execute only with at least one capable eligible unit. For upgraded SACU Overcharge/teleport use live commands, enhancementcommon if needed; no polling. Verify incapable units ignore native toggleScript. FAF EnterOverchargeMode checks currentSelection[1]/energy: aggregate support cannot prove mixed Overcharge. No temporary selection replacement without agreement.
Tests per column: applicability/dispatch, mixed/zero capability, live upgrades, replay/regressions. Native global/first-unit behaviour and Factory shield need game/source evidence.

## 5. Removal and cleanup

ContextActions.lua List/Get/Supports: hide removed pairs, preserve execution; soft_stop stays for Factory, transport_order for Transport, sacu_tech becomes legacy. ContextModel retains pairs. KeyboardBindings OwnIds/Register must recognize retired assignments hidden by List.
Replace SelectionConflict/editor policies after repeat ownership; tests enforce conflicts contrary to natural chains. Update tests/README/rules/changelog (Units-first). No schema bump/deletion. Test legacy dispatch/reload/unrelated edits. Risk: global legacy flags hide valid contexts.

## Questions (10)

1. Other->Units compatibility: legacy applicability or reviewed migration of old army rows?
2. Do disabled/empty siblings block assigned ones? Does disagreement consume the key or permit lower groups?
3. Inherit whole rows or fields? Rearm repeats? Fallback after failed quickRepeat?
4. Preserve legacy 0.5s double/unlimited accumulate (recommended)? Do native keys/modifiers/aliases/auto-repeat break chains? Does selection change-away-and-back cancel?
5. Building preset means structures/templates or all blueprints? Keep current Factory-row exclusion with production presets?
6. Scouts: SCOUT or AIR * INTELLIGENCE? Precedence for mobile factories/transports/silos, stations/drones, Megalith/satellites?
7. Affect all capable selected units or winning-column members? Adapt Overcharge first-unit logic without visible reselection?
8. Unproven Factory shield: hide new choices, keep old as obsolete? Which modded units are in scope?
9. Define not_found per selector, including already-selected results? Block fallback until detection is reliable?
10. Remove selection-policy conflicts for natural chains? Confirm grid.context linking for shared keys?
## First phase and Luna

Recommend phase 1 after Q1/Q2/Q6, starting with lossless loading/migration and common resolution. Luna suits specified phase-4 column batches/sizeable fixtures; one writer per file, reviewed diffs. Primary owns migration/dispatch/repeat/capabilities/UI integration. 
Sources: modules/tests/rules and FAF3840 lua.nx2 keyactions/misckeyactions/orders. Future check: node Tests/check-core.cjs --quiet (--only for focus); stubs cannot verify FAF.
