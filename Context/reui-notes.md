# ReUI: Source Review Findings

Review date: 2026-11-10. Scope: separate ReUI version 8 source copy / UID `reui-1.4.0`. The installed version is version 7 / UID `reui-1.3.2`; some of its implementation is bytecode, so do not automatically transfer findings to it.

## Loading and dependencies

Fact: `sources/ReUI/Core/Modules/Loader.lua` parses major.minor.revision versions and comparisons `>=`, `<=`, `>`, `<`, `=`, `==`. It detects a module being loaded twice (possible cycle), records errors, and checks dependency status. A Main error marks the module failed; dependent Main code does not run. Mod-type dependencies are checked by UID among active mods.

Fact: `Wrap` loads modules, runs callbacks before `CreateUI`, calls original `CreateUI`, runs callbacks afterward, and disposes. Pre/post callbacks run through `pcall`.

Recommendation: disabling an installed dependency mod is different from disabling one feature in an already loaded mod. A feature toggle needs its own lifecycle: stop timers, unsubscribe, destroy UI, and clear state. `ReUI.Require` does not provide this.

## Hooks

Fact: `sources/ReUI/Core/Core.lua` accumulates hooks; before UI creation it gets the current member of the imported module, passes it to a callback, and writes back the returned replacement. Hook registration is prohibited after UI creation. No automatic hook-conflict resolution was found; a comment notes the need to check conflicts.

Assumption: a chain works if each participant calls the previous function correctly and preserves its contract. Another mod can break the chain; ReUI itself does not prevent that.

## Settings

Fact: `Options/Options.lua` registers a menu item via `tabs.AddToMenu` and `OnPreCreateUI`, lazily imports mods' Options.lua, and provides Add and Window. An individual mod's Options Main error is caught.

Fact: `Options/Modules/OptionRef.lua` uses GetPreference/SetPreference on a composite path. `Options.lua` reads old values through `Prefs.GetFromCurrentProfile` and migrates them to the new path; `Options/Modules/OptionControls/OptionsWindow.lua:149` calls SavePreferences. It is inaccurate to reduce the whole current system to one profile key.

## Assessment

Recommendation: use separate loading and UI phases, lazily create settings, declare dependencies explicitly, and isolate errors at module boundaries.

Cost hypothesis: LINQ chains may allocate objects and closures; abstraction count alone does not prove FPS loss. Compare against a simple loop under the same workload before choosing an implementation.

Unknown: cost of Layouter/Views, actual allocation count, cleanup completeness, and behavior of the installed binary Loader. These require separate inspection and measurement.

## Detailed Review for the Claret Foundation Decision (2026-11-10)

Scope: supplied `sources/ReUI` folder (Main 1.4.0, manifest version 8). Read source, did not run it. Component versions: Core 1.7.0, Options 2.0.0, UI 1.5.0, UI.Controls 1.1.0, Units 1.1.0, WorldView 1.0.0, Animation 1.1.0, LINQ 1.4.1. This is not a line-by-line library audit or benchmark.

### 1. Dependencies are modular, but the main mod has side effects

Fact: Main.lua requires Core >=1.7.0, UI.QoL >=1.1.0, and FAF >=3816. UI.QoL requires Options, UI, and LINQ. Enabling standard ReUI is therefore not equivalent to enabling only a small Core. Loader also handles all active UI mods with a ReUI field; workload depends on which mods are enabled.

Fact: UI/QoL/Options.lua defaults `movableMenuPanel=true`, `multifunctionPanelCollapsed=true`, `menuPanelCollapsed=true`. UI/QoL/Main.lua hooks panels; some behavior is conditional on settings, while multifunction-arrow correction is unconditional. It also provides advanced ping and disable dialogs, off by default.

Conclusion: Claret can use only required APIs, but standard ReUI still loads the required QoL branch. If styling conflicts, first agree on settings and panel ownership. A separate copy of Core inside Claret would be a fork, not an ordinary dependency.

### 2. Loader and hooks

Fact: Loader.lua finds files using paths derived from module names and checks component version constraints. `version` in mod_info.lua and a component's Version are separate versioning levels. In this source copy, CheckPreloadedModule also checks that the UID of a found folder matches the active mod.

Fact: Core.Hook replaces a module field with the callback result. Its benefit is an ordered registration point and a way to wrap the previous function, not a fundamentally different interception mechanism. Core.lua has no automatic priority for conflicting hooks and no hook removal. Hook registration is prohibited after PostCreateUI.

Fact: loader Dispose clears loader bookkeeping; it does not disable user features during a match. A caught Main error does not roll back changes already made. A pre/post callback error is logged, but does not automatically move all related user objects into a safe state.

Recommendation: Claret needs its own feature enable/disable contract and resource tracking even if it uses ReUI. A hook can be installed once and check feature state inside it, if cost and behavior allow.

### 3. Settings are the most valuable ready-made part

Fact: ReactiveOption stores current and previous values, supports Set/Save/Restore, OnChanged/OnSaved events, and Bind with an immediate first call. OnChanged is an ordinary Event, not SafeEvent. A subscriber error may interrupt dispatch; this is not a claim that such errors are frequent.

Fact: OptionControl subscribes at creation and unsubscribes in OnDestroy. The library has explicit cleanup; the claim that “ReUI subscriptions always leak” is unsupported. Claret remains responsible for unsubscribing its own Bind calls.

Fact: OptionsWindow calls SavePreferences when Save is clicked and tracked settings changed; Cancel restores previous values. This ready-made live preview/cancel behavior would need to be recreated in a custom window.

Limitation: a shared Claret window and feature categories still need design. ReUI.Options does not automatically make older mod settings compatible with Claret; separate migrations will be needed.

### 4. UI, Layouter, and Views

Fact: UI.lua exports Layoutable, BaseLayout, Layouter, and rounding variants. Controls.lua extends standard Maui Bitmap/Group/Text/Checkbox controls; they are still game controls with extra capabilities, not a new rendering engine.

Fact: Layoutable applies layout at creation and explicit Layout changes; Layouter uses LazyVar and layouthelpers. No continuous full-panel recalculation loop per frame was found in the reviewed Layoutable/Layouter files. This gives no basis for rewriting layout to remove such a supposed loop.

Hypothesis: additional cost comes from creating objects/bindings and resolving dependencies after changes; measurement is needed on a real window.

Fact: FloorLayoutFor and RoundLayoutFor are shared instances storing the current control. Do not retain a partial chain or use one instance across a yield; reentry can change the selected control. This is an API limitation, not a proven bug in existing mods.

Fact: DynamicScrollable.GetDataSize traverses all data; CalcVisible walks from the beginning to the first visible row and draws visible rows. For long, frequently updated lists, cost depends on size/position. This is not a reason to rewrite a small settings container; thousands of entries need measurement and possibly an indexed variant.

### 5. Work performed every frame

Fact: WorldView replaces the game worldview class with an extended class, calls OnFrame on enabled components, then calls original OnFrame. It enables frame updates for the main view. ComponentContainer skips disabled components but checks them during traversal; DestroyComponents explicitly destroys components.

Fact: Grid/Modules/AGridItem.lua routes OnFrame to the active component and destroys components in OnDestroy. Cost depends on active item count and handlers; a library layer alone does not prove significant load.

Fact: Animation.Animator enables frame updates on Add and disables them when the animation list empties. For delta>0.05 it splits updates into `ceil(delta/0.05)` substeps. Hypothesis: long frames and many animations may amplify load; this point has no substep cap. Measure it rather than attributing all stalls to it.

Fact: Animator is created in Animation Main. Module Main functions run before original CreateUI, so the project rule “no controls before CreateUI” is not a universal description of ReUI itself: the library creates this service Group earlier. Root-frame availability in the target version must be checked in-game.

### 6. ReUI also has a unit service

Fact: Units/Units.lua fetches a list when Get is called; it uses GameTick and intervals `updateCacheTicks=10`, `updateAllTicks=50`. Full collection uses hidden ALLUNITS selection with selection and command-mode restoration. Between full collections, it removes dead units and adds focus objects. It resets the weak table on army change.

Conclusion: this is a cache with bounded staleness, not a continuously event-driven picture of every appearing unit. Rewriting this service without measurement is not necessarily required. However, it does not provide a ready scheduler for spreading full scans across frames, consumer filters, or latency guarantees.

Fact: HiddenSelect invokes its callback without protecting state restoration from exceptions. If the callback throws, the remaining restoration operations in this function do not run. This is a concrete risk, not an observed in-game failure.

Fact: Units requires Selection, which requires Options. Using the cache also adds selection handling. Selection provides priorities and Add/Remove handlers; choose the service with that dependency chain in mind.

### 7. LINQ and license

Fact: LINQ includes lazy iterators, enumeration objects, sorting, and ToArray materialization. Not every chain means full extra traversals; some operations combine lazy traversal. It is also not proven faster than a specialized loop. A simple loop is acceptable for a Claret hot path even if the UI uses ReUI.

Fact: LINQ.lua header says copyright 2025 4z0t and All rights reserved, while root `sources/LICENSE` says MIT, copyright 2022 4z0t. Clarify license scope before copying/forking; no legal conclusion is made here. Sources were not modified.

### 8. Versions and hypothesis checks

Fact: installed Main.lua reports 1.3.2 and requires Core>=1.7.0, UI.QoL>=1.0.0; separate source copy is 1.4.0 and QoL>=1.1.0. Matching minimum Core version does not prove implementation equivalence. Manifest versions 7/8 are not versions of every API.

History source: https://github.com/4z0t/FAF-UI-Mods/commits/develop/ . The cached page shows updates but not a reliable current list of all breakages as of review. The issues page did not load. Do not guess incompatibility frequency.

To answer the performance question, compare A: minimal UI; B: ReUI only, with QoL settings recorded; C: same ReUI plus one Claret feature; D: functionally equivalent prototype without ReUI, only if B-A or a specific component is materially costly. Use three runs with identical camera/replay and the metric definitions in `performance-hotspots.md`. Do not compare an empty new Core against ReUI plus ten enabled mods.

## Recovered Installed ReUI Family

2026-11-13: at the user's request, all 92 bytecode Lua files from 9 installed ReUI/ReUI.* mods were decompiled; 68 text files were not duplicated. Architecture map, method, versions, and limitations: [reui-decompiled/README.md](reui-decompiled/README.md); file-by-file index: [reui-decompiled/index.md](reui-decompiled/index.md). All 92 disassembly round-trips matched byte-for-byte; Lua output passed syntax parsing. Execution in FAF and semantic equivalence were not verified. Originals were not changed. Construction 1.3.0 is already readable: its `SetupConstructionControl` replaces the construction cluster; its built-in cargo marker is linked to `TransportCargoContext` and `DisplayBPID(..., "down")`. This is not a replacement of the entire bottom HUD.
