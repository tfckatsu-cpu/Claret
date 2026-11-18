# Hotbuild keyboard open: analysis for Terra

Checked 2026-11-13: local Main Version 0.10.15, installed FAF lua.nx2 version 3840. Static analysis; no timing/game tests or code changes. Paths below: ../mods/ClaretHotbuild/modules unless stated otherwise.

## Call chain / entry discrepancy

Current ../mods/ClaretHotbuild/Main.lua:27-39 registers inline Navigator, NOT a separate keyboard action. Navigator.lua:114 opens page 1; :58-65 destroys previous child and calls Main.lua:33 -> Runtime:OpenKeyboardEditor (:463-481). Runtime prepares state (:465-468; Keys:Stop is a no-op), then KeyboardEditor.Create (:41). Create builds frame/keys (:64,307-340), LoadAssignments -> KeyboardBindings:GetAssignments -> Snapshot (:367,123-126; KeyboardBindings.lua:141-162), paints and returns (:377). Rendering follows return; no explicit Show. Live self.editor is reused (Runtime:464).

Core modules/Menu.lua:318-332 supports action.open(root), hides menu/releases focus, restores both on child OnDestroy. Hotbuild registers no such action. Confirm running entry first.

## Ranked hypotheses

K=84 keys; M=entries in four maps with duplicates; U=profile-map entries; P/C/A=presets/composites/actions; E=model entries/grid cells/rows. Costs unmeasured.

1. **OwnIds rebuilt per map entry.** KeyboardBindings.lua:145 calls OwnIds() inside Snapshot's map loop, before dedup. :70-88 lists/copies both models, encodes IDs, lists actions and reads/scans both profile maps. Model.lua:169-177,110-118 copies entries/grids; ContextModel.lua:131-139 copies composites. Cost ~M*(P+C+A+E+U), ~2M profile-field reads; FAF lua/user/prefs.lua:89-92 calls GetPreference twice per read. Transient allocations may add GC. High confidence; dominance unmeasured.

2. **All controls recreated.** KeyboardEditor.lua:317-340 builds K*(1 cell Bitmap+4 border Bitmaps+1 Text)=504 controls, plus 18 for modifier buttons and frame/header. Core Theme.lua:75-87 creates strips/layout bindings per outline. O(K) native creation/font/layout work each Create. Refresh (:342-356) adds ~7K style setters. High confidence in count, medium in impact. Solid colors only: no key icons/explicit texture loads.

3. **Decoding, labels, layout.** KeyboardBindings.lua:143-156 normalizes/parses M chords, localizes foreign names before dedup; Label (:47-50) twice per owned result calls model:Get, copying bindings. O(M*chord length+owned binding copies). Medium confidence. Layout is shallow frame->keyboard->cell->text/strips; no evident deep LazyVar chain.

Off this path: catalogs/blueprint loops/sorting; GetChoices (:213, click); tooltip wrapping (:128-184, hover); Keys:Apply/RefreshKeys (close/error/start). Runtime.lua:60-67 already session-caches Catalog.Create. Catalog.lua:115-165 scans/sorts blueprints once; TemplateCatalog.lua:71-122 rebuilds/sorts variants when called, :68 creates Equivalents once (Equivalents.lua:16-54). Time close separately: Runtime.lua:476-479 refreshes keys.

## Instrumentation first

Verified via rg in extracted installed lua.nx2: UI lua/ui/game/gamemain.lua:842-847 and lua/ui/game/hotkeys/context-based-templates.lua:411,495 use GetSystemTimeSeconds(). lua/benchmarks/control.lua:17-26 uses GetSystemTimeSecondsOnlyForProfileUse() for elapsed work. Prefer the latter if callable in UI (check first probe); fallback to GetSystemTimeSeconds, precision unestablished. Milliseconds=1000*(end-start); never simulation time.

Gate clocks AND logging on ReUI.Options.Mods['ClaretCore'].probeEnabled:Get(), using nil-safe lookup as Editor.lua:7-11. Format `[Claret][perf] stage=<name> ms=<n>`; aggregate without per-key logs. Stages: entry_total (actual caller through return), runtime_prepare (:465-468), frame_shell, key_controls (:332-340), assignments (:124), snapshot_total, accumulated own_ids and labels inside Snapshot, initial_paint (:367), close_refresh (Runtime:479). Emit afterward; do not sum nested stages.

Chain one-shot OnFrame stage entry_to_next_frame, preserving animation/update ownership; not GPU presentation proof. User compares first+5 repeat opens, same scale/data, then changed bindings. Read via node .tools/faf-log.cjs --grep perf.

## Options / separately verifiable steps

1. Instrument only; establish actual entry and baseline stages.
2. **C, smallest fix:** capture AllMaps and OwnIds once per Snapshot, reuse labels by action ID. Cost approaches O(E+U+M). Preserve order, dedup tokens, legacy IDs and foreign conflicts. Refresh already costs O(K+assignments), NOT K*bind scans. Index key/combo lists per load only if needed.
3. **A, if needed:** session snapshot cache with model/action revisions and exact relevant map/profile content check on open. Invalidate Set/Clear, commits, RefreshKeys, native keybindings CloseUI, profile change and teardown. Identity alone misses in-place mutation. Catalog stays lazy/session-cached. Where used, keep RefreshTemplates on open/selection/press as a cheap change check: compare source content including names/order/geometry/sizes, rebuild only on change. O(source size); avoid hash-only equality.
4. **B, if native creation dominates:** persistent session owner + Hide/Show, refresh on activation. Memory/lifecycle risk: Navigator destroys children, Runtime.editor blocks commands, Menu restores focus via OnDestroy. Need explicit deactivate/reactivate: close tooltip/chooser, release Escape/capture, reset held modifiers, clear active editor, restore host focus on hide, stop animations; destroy once on session teardown. Recompute parent geometry/scale. RequestClose only calls CloseDialog (:370-375); Hide cannot replace Destroy directly. Agree architecture first.
5. **D, last:** shell first, bounded key rows per OnFrame, disable input until complete. Cancel stale work on close/destroy; preserve animation. Spreads latency, retains total work/partial UI; fix Snapshot first.

After each step: focused hotbuild-keyboard-editor/keys/runtime/navigator checks; user verifies reopens, modifiers/tooltips, save/clear, conflicts/legacy, Escape/cleanup, focus, scale, teardown. Tests/hotbuild-keyboard-editor.lua mocks cannot prove speed.



