# ClaretHotbuild — architecture reconstruction and regression-risk audit

Audit date: 2026-11-18.
Code base: workspace `ClaretHotbuild/` (verified byte-identical to the live mod, per batch briefing).
Snapshot: `Version = '0.10.36'`, `BuildStamp = '20261117-143'`, `mod_info.version = 73`,
`mod_info.ReUI = 'ClaretHotbuild=0.10.37'`.
Dependencies: ClaretCore >= 0.10.5 (installed 0.10.13, build 20261117-45), ReUI Main 1.3.2,
ReUI.Core 1.7.0, ReUI.UI, ReUI.Options 1.2.0.

Size: 30 Lua files, 9610 lines — 27 modules, `Main.lua` (138), `Options.lua` (4),
`mod_info.lua` (11). Largest: `ContextEditor.lua` 1156, `Editor.lua` 1100,
`KeyboardBindings.lua` 918, `LocalizationStrings.lua` 823, `Runtime.lua` 819.

Evidence policy used here: every claim is tied to a line I read in this run. Claims about FAF
engine internals (`GetKeyMappings(true)`, `ConExecute("UI_Lua …")`, console-command case
sensitivity, the existence of a global `Colours`) are marked **unknown** and are *not* used as
the basis of a defect — they appear in §3 with the exact check needed.

Nothing in this audit was executed in game. `node Tests/check-core.cjs --only hotbuild` was run
(read-only) and its output is quoted in §G.

**Findings index** (32 total): 3 High, 16 Medium, 8 Low, 5 optional.
§B confirmed: HOT-01…HOT-12 + HOT-32 (2 High, 6 Medium, 5 Low).
§C architectural: HOT-13…HOT-20 (1 High, 7 Medium).
§D unverified risks: HOT-21…HOT-26 (3 Medium, 3 Low).
§E optional: HOT-27…HOT-31.
No Critical finding: nothing found corrupts saved data irreversibly or crashes the game; the worst
confirmed outcome is a silent, session-long loss of hotkeys plus a blocked editor (HOT-03).

---

## A. Architecture as built

### A.1 Module inventory and responsibilities

| Module | Lines | Responsibility | Imported by |
|---|---|---|---|
| `Main.lua` | 138 | mod entry: localization registration, 4 ReUI hooks, feature/settings registration, session `Ensure()` | ReUI loader |
| `Options.lua` | 4 | `ReUI.Options.Mods['ClaretHotbuild'] = { enabled }` | ReUI.Options |
| `modules/Runtime.lua` | 819 | session singleton (`current`), dispatch table, all `Execute*` entry points, context resolution, persistence (`Commit`/`CommitContext`), editor lifecycle, diagnostics | Main, **the 8 keymap action strings** |
| `modules/Model.lua` | 314 | building presets: validate/copy/store `{id,name,key,entries,grid}`, version 1 profile | Runtime |
| `modules/ContextModel.lua` | 320 | composite ("multifunction") binds: rows per context, inherit/own/disabled, version 1–3 profile | Runtime |
| `modules/ContextActions.lua` | 807 | static action catalogue (≈140 ids), context classification, `Available`, `Execute`, `ExecuteWithOutcome`, selection helpers | Runtime, Compatibility, KeyboardBindings |
| `modules/KeyboardBindings.lua` | 918 | per-key "pairs" (preset+composite+action+double), FAF key-map writes, conflict policy, **and** full engine keymap rebuild | Runtime |
| `modules/Keys.lua` | 122 | legacy registration of preset / absolute-composite actions into `UserKeyActions` | Runtime |
| `modules/Adapter.lua` | 228 | selection→order bridge: `Context`, `CanBuild`, `Build` (factory count, templates) | Runtime |
| `modules/Catalog.lua` | 253 | blueprint→record index (`id,name,faction,tech,kind,icon`) | Runtime |
| `modules/TemplateCatalog.lua` | 163 | wraps Catalog, parses `build_templates` into `claret_template_<hash>` records, cross-faction variants | Runtime |
| `modules/Equivalents.lua` | 134 | cross-faction unit/template equivalents | Editor, TemplateCatalog |
| `modules/Compatibility.lua` | 250 | preset↔context cross-validation (builder/factory/absolute gates) | Runtime, Editor, KeyboardBindings |
| `modules/ContextRepeat.lua` | 93 | continuation state (`Remember`/`Continue`, `RememberQuick`/`ContinueQuick`) | Runtime |
| `modules/ContextUpgrade.lua` | 222 | "structure under cursor" upgrade actions + selection transactions | ContextActions |
| `modules/ContextEnhancements.lua` | 184 | ACU/SACU enhancement chains via `UNITCOMMAND_Script` | ContextActions |
| `modules/ContextQueue.lua` | 31 | remove last factory queue item | ContextActions |
| `modules/EngineerHold.lua` | 47 | 0.3 s hold loop that repeats an engineer-selection step | Runtime |
| `modules/StorageFabs.lua` | 90 | "storage / fab ring around mex" actions — uses `SimCallback` | ContextActions |
| `modules/Editor.lua` | 1100 | building-preset editor page (grid of 3 tiers × 4 factions × domains) | Runtime |
| `modules/KeyboardEditor.lua` | 807 | keyboard page: key grid, modifier state, assignment dialog, double-press setup | Runtime |
| `modules/ContextEditor.lua` | 1156 | composite-bind editor page (context tiles, action catalogue, saved list) | Runtime |
| `modules/Navigator.lua` | 170 | 3-tab page switcher inside the Core settings section | Main |
| `modules/BuildKeyLabels.lua` | 127 | decorates `hotkeylabels.getKeyTables` with preset keys | Main |
| `modules/CycleMenu.lua` | 49 | 1.1 s build-cycle preview overlay | Runtime |
| `modules/OpenPerf.lua` | 60 | opt-in timers for editor open (probe gate) | Main |
| `modules/QuickRepeatMenu.lua` | 39 | standalone quick-repeat settings window | **nobody** |
| `modules/QuickRepeatSettings.lua` | 131 | the contents of that window | QuickRepeatMenu |
| `modules/LocalizationStrings.lua` | 823 | `hotbuild.*` string tables (ru/en) | Main |

### A.2 Lifecycle (fact, from code)

1. Mod load → `Main(isReplay)` (`Main.lua:15`). Localization registered first (`:16-18`); a
   registration failure is a hard `error`.
2. Four `ReUI.Core.Hook` calls are *queued* (`Main.lua:30,55,64,117`). ReUI applies queued hooks in
   a **pre-create callback**, in registration order, via `import(path)` + field swap
   (`Context/reui-decompiled/ReUI/Core/Core.lua:10-29`). After UI creation `ReUI.Core.Hook` throws
   (`:33-35`) — so all Hotbuild hooks must be registered during `Main`.
3. `ReUI.ClaretCore.RegisterFeature('hotbuild', fn, options.enabled)` (`Main.lua:71`) only enqueues
   in Core when the registry does not exist yet (`ClaretCore/Main.lua:104-121`).
4. `ReUI.ClaretCore.RegisterSettingsSection{…}` (`Main.lua:76`) builds the 3-page Navigator; the
   page `open` callbacks call `Ensure()` lazily.
5. Core's `OnPostCreateUI` creates the registry, registers pending features and binds the option
   (`ClaretCore/Main.lua:134-182`). `BindOption` immediately calls `SetEnabled(option:Get())`
   (`Registry.lua:40-48`) → `Lifecycle:SetEnabled(true)` → `pcall(start, scope)` →
   `Ensure():Start(scope)` (`Main.lua:72`). **This is where `Runtime.Create` first runs.**
6. `Runtime.Create` (`Runtime.lua:101`) reads two profiles, builds models, `Migrate()`s keyboard
   data, applies keys, sets the module singleton `current = service` (`:846`).
7. `service:Start(scope)` (`Runtime.lua:262`) registers cleanup via `scope:Defer`, sets
   `active = true`, `RefreshKeys()`.
8. Hotbuild's own `OnPostCreateUI` (`Main.lua:129`) runs after Core's — registration order is the
   only ordering guarantee available and the ReUI loader's iteration order was not re-verified in
   this audit (assumption). It calls `Ensure()` (already exists), creates an invisible owner
   `Group(GetFrame(0))` and chains `owner.OnDestroy` → `service:Destroy(); service = nil`
   (`Main.lua:134-136`).
9. Disable via options → `Lifecycle:SetEnabled(false)` → `Clean()` runs the deferred callback:
   `active=false`, `holdModule:StopAll()`, `continuation:Clear()`, `cycleMenu:Destroy()`,
   `keys:Stop()` (`Runtime.lua:263-269`). Enable again → new scope → `Start`.
10. Session end → owner `OnDestroy` → `Destroy()` (`Runtime.lua:833-846`).

`service.active` is therefore "feature enabled **and** start completed", but it is a plain field on
the service table, not the Lifecycle state. `Lifecycle` also holds `state`/`failure`
(`Lifecycle.lua:135-137`); nothing in Hotbuild reads it — `Runtime.Dispatch` gates on
`current.active` (`Runtime.lua:36-47`) and `Main`'s label hook gates on `service.active`
(`Main.lua:35`). On a failed start, `Clean()` runs the deferred callback, so `active` does return to
`false` — the two sources agree in that case (verified by reading `Lifecycle:SetEnabled` +
`Start`). The residual divergence is that `Registry:GetState` reports `error` while Hotbuild keeps
no record of why.

### A.3 Key press → engine command (end-to-end)

```
physical key
  └─ FAF keymap (UserKeyMap / UserDebugKeyMap, rebuilt by KeyboardBindings:Refresh)
       action string:  UI_Lua import("/mods/ClaretHotbuild/modules/Runtime.lua").<Method>(<arg>[, IsKeyDown(16)])
  └─ Runtime.<Method>(...)                        Runtime.lua:77-94  (thin wrappers around Dispatch)
       └─ Dispatch(method, prefix, id, kind, chord, shiftHeld)      Runtime.lua:24-76
            ├─ probe gate read (ReUI.Options.Mods.ClaretCore.probeEnabled)   :25-27
            ├─ guards: current nil / inactive / replay / key capture         :36-47
            ├─ current:TouchQuick(quickId)   (drops a stale quick repeat)    :60-68
            └─ current[method](current, id, …)                               :70-77
  └─ service:Execute / ExecuteAbsolute / ExecuteKeyboardAction / ExecuteKeyboardComposite /
     ExecuteKeyboardPair / ExecuteFactoryShift                        Runtime.lua:278-637
       ├─ Adapter:Context(isReplay)  → selection, orders set, focusArmy, factorySelection,
       │                               factoryTechTab                   Adapter.lua:55-76
       ├─ RunCursor        (context "cursor", upgrade-under-cursor)     Runtime.lua:231-246
       ├─ continuation:ContinueQuick / Continue  (second press)          Runtime.lua:300-306
       ├─ ResolveContext   (land/air/navy → empty → acu/sacu/engineer → factory →
       │                    silo_tactical/silo_nuclear → transport/mex/scout/other)  :159-195
       ├─ ContextActions.Available / Execute / ExecuteWithOutcome        ContextActions.lua:396-700, :821-838
       ├─ Model:Execute (building preset: first entry the selection can build)  Model.lua:270-305
       └─ Adapter:Build → IssueBlueprintCommand / StartCommandMode / SetActiveBuildTemplate
```

Modifier handling (Shift) appears in **five** places, each with a different mechanism:

| Where | Line | Mechanism |
|---|---|---|
| generated action string | `Keys.lua:66-127`, `KeyboardBindings.lua:151-186` | literal `IsKeyDown(16)` evaluated by the keymap at press time |
| `Runtime.Execute` fallback | `Runtime.lua:275-278` | `pcall(IsKeyDown, 16)` when the caller passed `nil` |
| factory order count | `Adapter.lua:166-172` | re-reads `IsKeyDown(16)` immediately before `IssueBlueprintCommand`, `count = shift and 5 or 1` |
| chord construction | `KeyboardBindings.lua:84-91` | Shift is part of the chord (`Ctrl-Alt-Shift-Key`), so Shift+X is a separate keymap entry |
| factory-shift intercept | `KeyboardBindings.lua:203-242`, `Runtime.lua:617-637` | a synthetic `Shift-<chord>` override that calls `ExecuteFactoryShift(chord, nativeAction)` |

The intercept, precisely (build 145–147):
`FactoryShiftOverrides()` iterates every pair that has a preset and is actually mapped
(`PairIsMapped`), computes `WithShift(chord)`, skips if the user already owns the shifted chord in
either user map, then registers `overrides[shifted] = copy-of-native` with
`action = ExecuteFactoryShift("<chord>", "<native action or pair fallback>")`
(`KeyboardBindings.lua:213-237`). `service:Refresh` appends these after `IN_AddKeyMapTable(mappings)`
and `hotbuild.addModifiers()` (`:896-907`). At press time `ExecuteFactoryShift` re-checks
`context.factorySelection` **and** `pair.preset`; only then does it run
`Execute(pair.preset, pair.composite, chord, nil, shiftHeld=true)` (`Runtime.lua:618-628`), which
reaches `Adapter:Build` with `buildCount = 5`. Otherwise it `ConExecute`s the fallback string.

### A.4 Storage map (what is persisted where)

| Profile key | Owner | Format | Written by |
|---|---|---|---|
| `ClaretHotbuild` | `Model` | `{version=1, bindings={{id,name,key,entries,grid}}}` | `Runtime:Commit` (only after validation) |
| `ClaretHotbuildContexts` | `ContextModel` | `{version=3, bindings={{id,name,absolute,rows}}}` (v1/v2 accepted) | `Runtime:CommitContext` |
| `ClaretHotbuildKeyboard` | `KeyboardBindings` | `{version=2, assignments={chord={preset,composite,action,doubleFirst,doubleSecond}}}` | `WritePairs`/`WriteAssignment`/`Migrate`/`SetDouble*` |
| `UserKeyActions` | FAF, mutated by Claret | `[actionId] = {action=<UI_Lua string>, category='Claret Hotbuild'}` | `Keys:Apply`, `Keys:ApplyAbsolute`, `KeyboardBindings:Register` |
| `UserKeyMap`, `UserDebugKeyMap` | FAF, mutated by Claret | `[chord] = actionId` | `Migrate`, `WritePairs`, `WriteAssignment` via `Mapper.SetUserKeyMapping` |
| `keyDescriptions` (session table) | FAF, mutated by Claret | `[actionId] = label` | same three places |

Action-id namespaces: `ClaretHotbuild_<hex id>` (preset), `ClaretHotbuildAbsolute_<hex>` (legacy
absolute composite), `ClaretHotkeyComposite_<hex>`, `ClaretHotkeyContext_<hex>`,
`ClaretHotkeyPair_<hex chord>`. Encoding is byte-wise `%02X` in three separate implementations
(`Keys.lua:20-22`, `KeyboardBindings.lua:57-59`, `Runtime.lua:31-33`).

Two keys are authoritative for execution: the **pair** record (`KeyboardBindings`) and the keymap
entry it produces. `Model.binding.key` and `Model.binding.grid.context` are legacy fields that are
still read by `Compatibility` and by `Model:Put`'s uniqueness check (§B-1).

---

## B. Section 1 — Confirmed defects

### HOT-01 — `BuildKeyLabels` reads an undefined global `Colours`, so the label decoration can never run
* **Severity**: High
* **Category**: Correctness / UI
* **Location**: `ClaretHotbuild/modules/BuildKeyLabels.lua:35`, `:102`, `:112` (`ReadChord`, `Build`)
* **Problem**: the module returns FAF `HotKeyData` tuples with `colour = Colours.plain`, but
  `Colours` is never defined or imported in this file, and no Claret file defines it.
* **Evidence**:
  ```lua
  local colour = Colours.plain                       -- BuildKeyLabels.lua:35
  ...
  colour = Colours.plain,                            -- :102 and :112
  ```
  `Select-String -Pattern 'Colours'` over `ClaretCore/*.lua`, `ClaretCore/modules/*.lua`,
  `ClaretHotbuild/*.lua`, `ClaretHotbuild/modules/*.lua`, `Tests/*` returns only these three lines
  plus a comment in `Theme.lua:2`. The local test run fails with exactly this:
  `FAIL: hotbuild-build-key-labels.lua: …BuildKeyLabels.lua:35: attempt to index a nil value
  (global 'Colours')`.
* **Impact**: `Main`'s `getKeyTables` hook calls `Build` and `Merge` inside `pcall`
  (`Main.lua:45-50`), so the failure is silent: construction tiles never show Claret preset keys.
  No crash, no log line.
* **Recommendation**: replace with an explicit local constant (the ARGB string FAF's
  `HotKeyData.colour` expects) or take it from `Theme.Colors`; add the value to the module's
  returned table so it is testable without globals.
* **Risk of fix**: low — one constant, three uses; the label path is display-only.
* **Confidence**: High that the global is undefined in Claret and in the test environment.
  **Unknown**: whether FAF happens to define a global `Colours` at runtime. That single check
  (one grep in the installed `lua.nx2`, or one in-game log line) decides between "feature dead"
  and "feature works by accident". Because `pcall` swallows both outcomes, neither is currently
  observable.

### HOT-02 — `Dispatch`'s missing-handler branch calls the handler it just proved is missing
* **Severity**: Medium
* **Category**: Correctness / Maintainability
* **Location**: `ClaretHotbuild/modules/Runtime.lua:47-50`
* **Problem**: the guard is inverted — it is the only `return` that would throw.
* **Evidence**:
  ```lua
  if type(current[method])~='function' then
      if tracing then LOG('[Claret][keys] dispatch action='..action..' result=no_handler') end
      return current[method](current,id)
  end
  ```
* **Impact**: latent. All eight method names exist today, so the branch is unreachable; the moment a
  wrapper is renamed or a stale profile action calls a removed method (profiles outlive builds),
  the "safe" path raises `attempt to call field '…' (a nil value)` inside the keymap action, i.e.
  an error per key press instead of a no-op.
* **Recommendation**: `return false, 'no_handler'` (or `nil, message`), keeping the trace line.
* **Risk of fix**: none — behaviour only changes in the currently-broken branch.
* **Confidence**: High (code is unambiguous).

### HOT-03 — One rejected record in a profile locks the whole subsystem: keys stop applying and every save fails
* **Severity**: High
* **Category**: Correctness / Data safety
* **Location**: `Runtime.lua:247-256` (apply gate), `Runtime.lua:664-668` + `:716-720` (save gates),
  `Model.lua:314-330` (warnings), `ContextModel.lua:223-225` (`CanSave`)
* **Problem**: load warnings are treated as a global stop, not a per-record quarantine. The three
  gates are all "any warning ⇒ refuse".
* **Evidence**:
  ```lua
  function service:RefreshKeys()
      if table.getn(self.model:GetLoadWarnings()) > 0 or table.getn(self.contextModel:GetLoadWarnings()) > 0 then
          return false, T('hotbuild.runtime.s004')
      end
      if keyboardBindings:GetPairError() then return false,keyboardBindings:GetPairError() end
  ```
  ```lua
  function service:Commit(binding, removeId)
      if keyboardBindings:GetPairError() then return false, keyboardBindings:GetPairError() end
      if table.getn(self.model:GetLoadWarnings()) > 0 then
          return false, T('hotbuild.runtime.s018')
  ```
  ```lua
  function service:CommitContext(binding, removeId, confirmedDelete)
      ...
      if not self.contextModel:CanSave() then return false, T('hotbuild.runtime.s022') end
  ```
  Warnings are produced by `Model.Create` for *any* single bad binding (`Model.lua:319-330`),
  including `CopyGrid` rejecting a grid without a `units` table (`Model.lua:63-66`) — a shape that
  older data can have. `CanSave()` is `readable and actionCatalog ~= nil`
  (`ContextModel.lua:223-225`), and `readable` flips false on the first `LoadWarning`.
* **Impact**: a single malformed saved binding disables **all** hotkeys for the session (silently —
  only `WARN` lines at `Runtime.lua:844-845`) *and* blocks every save and delete from the UI, so
  the user cannot repair the data through the editor. The only escape is hand-editing
  `ClaretHotbuild`/`ClaretHotbuildContexts` in the FAF prefs file. The editor does not even explain
  which record is bad: `Editor.Writable()` (`Editor.lua:538-542`) tests only `draft`/`legacyIssue`,
  and `Commit` returns the generic `hotbuild.runtime.s018`.
* **Recommendation**: quarantine per record (skip + collect), keep the rest working, and expose a
  "reset Hotbuild data" action in the Hotbuild settings page that removes the three profile keys
  after explicit confirmation. At minimum, surface `GetLoadWarnings()` in the editor status line
  the way `ContextEditor.lua:1158-1159` already does for context warnings.
* **Risk of fix**: medium — changing the gate changes what "graceful" means for execution; a
  partially loaded preset list could execute an unintended entry. Quarantine must exclude the bad
  binding from `List()`/`Get()` (it already is excluded) while keeping save enabled.
* **Confidence**: High. The gate chain was read end to end; the failure mode follows directly.

### HOT-04 — Disabling the feature leaves the keys bound and dead
* **Severity**: Medium
* **Category**: Correctness / UX
* **Location**: `Runtime.lua:262-269` (`Start` cleanup), `Keys.lua:62-64` (`Stop` is a no-op),
  `Runtime.lua:36-47` (`Dispatch` gates on `active`)
* **Problem**: the disable path removes nothing from the engine keymap; execution is prevented only
  by the `active` flag, so the key is consumed and does nothing.
* **Evidence**:
  ```lua
  function keys:Stop()
      -- FAF owns the active key map and its lifecycle.
  end                                     -- Keys.lua:62-64
  ```
  ```lua
  scope:Defer(function()
      self.active = false
      if holdModule then holdModule:StopAll() end
      continuation:Clear()
      if cycleMenu then cycleMenu:Destroy(); cycleMenu=nil end
      keys:Stop()                          -- no-op
  end)                                     -- Runtime.lua:263-269
  ```
  The keymap entry survives because it lives in `UserKeyMap`, which only `KeyboardBindings.Write*`
  and `Migrate` rewrite; neither runs on disable.
* **Impact**: after toggling "Hotbuild" off in the Core menu, every previously working key is eaten
  with no feedback; the user has to rebind or clear them manually. The labels also disappear
  (`Main.lua:35` gates the decoration on `service.active`), which makes it look like the mod is
  gone while the keys are still captured.
* **Recommendation**: on disable, call `RefreshKeys()` after `active=false` so
  `keys:Apply`/`ApplyAbsolute` + `keyboardBindings:Refresh` rebuild the map from the *current*
  state (which no longer defines Claret actions), or explicitly clear the Claret ids from
  `UserKeyMap` while remembering them for re-enable.
* **Risk of fix**: medium — must not delete the user's assignments permanently (disabling is
  reversible); the safe variant is "keep the assignments in `ClaretHotbuildKeyboard`, remove the
  engine entries".
* **Confidence**: High for the mechanism; the in-game observable (whether FAF falls through a
  returning-false `UI_Lua` action) is **unknown** and would change the impact from "dead key" to
  "key passes through".

### HOT-05 — Removing the mod leaves orphaned Claret action bindings behind
* **Severity**: Medium
* **Category**: Correctness / Compatibility
* **Location**: `Keys.lua:66-98` (only place that removes stale Claret actions)
* **Problem**: cleanup runs only while the mod is loaded. Uninstalling Hotbuild leaves
  `UserKeyActions` entries whose action string imports `/mods/ClaretHotbuild/modules/Runtime.lua`,
  plus their `UserKeyMap` chords and their `keyDescriptions` labels.
* **Evidence**: the only deletion loop is
  ```lua
  for id, action in pairs(actions) do
      if string.sub(id, 1, string.len(prefix)) == prefix and action.category == category and not wanted[id] then
          actions[id] = nil; descriptions[id] = nil; removed[id] = true
  ```
  and it is inside `keys:Apply`, which is only reachable from `service:RefreshKeys` in a live session.
* **Impact**: after uninstalling, the FAF key dialog shows a "Claret Hotbuild" category that cannot
  be executed, and the chords stay occupied. Same category of risk as any mod that writes global
  keymap state, but here it is systematic (every preset/absolute/pair action).
* **Recommendation**: document the uninstall step (clear FAF bindings for category "Claret
  Hotbuild"), or add a Core-side "release Hotbuild keys" utility that can run when the feature is
  registered but disabled.
* **Risk of fix**: low for documentation, medium for automated cleanup (must not touch other mods'
  actions; the prefix + category pair is the only safe filter).
* **Confidence**: High (no removal path exists in the code base).

### HOT-06 — `StorageFabs` calls simulation callbacks that a `ui_only` ecosystem cannot provide

**Refuted (2026-11-18):** `RingWithFabricators` and `RingWithStorages` are implemented by the base game in `lua/SimCallbacks.lua`; `SimCallback` is the supported path and the actions behave as designed. No fix required.
* **Severity**: Medium
* **Category**: Architecture / Correctness
* **Location**: `ClaretHotbuild/modules/StorageFabs.lua:70`, `:72`
* **Problem**: two catalogue actions (`build_storage_nearest`, `build_fabs_nearest`) end in
  `SimCallback({Func='RingWithFabricators'|'RingWithStorages'})`. Claret ships no sim component
  (`ui_only = true`, `mod_info.lua:9`), and these callback names appear nowhere else in the project.
* **Evidence**:
  ```lua
  SimCallback({ Func = 'RingWithFabricators', Args = { target = mex:GetEntityId(), allFabricators = true } }, true)
  SimCallback({ Func = 'RingWithStorages', Args = { target = mex:GetEntityId() } }, true)
  ```
  `Select-String -Pattern 'RingWith|SimCallback'` over all Claret Lua returns only these two lines;
  no test references them either.
* **Impact**: the actions look available in the editor, change the selection
  (`PrepareBuild` does `SelectUnits(engineers)` after `ConExecute('UI_SelectByCategory …')`) and then
  do nothing visible, because no sim callback answers. That is a dead action with a side effect on
  the user's selection. It also contradicts the project rule "client UI only, no simulation
  changes".
* **Recommendation**: either drop both actions (they are the only survivors of the removed
  "BindStorage" import, see CHANGELOG build 87) or gate them behind the presence of a provider:
  probe once for the callback (log-only) and mark the actions unavailable. Do not ship a UI action
  whose only effect is a sim callback that Claret cannot supply.
* **Risk of fix**: low — both actions are catalog entries; removing them only affects saved
  assignments, which must be kept executable but may become no-ops (the established "obsolete"
  pattern).
* **Confidence**: High that Claret provides no implementation. **Unknown**: whether FAF itself
  registers these callbacks (it does not in stock FAF3840 as far as this audit can tell, but that
  was not verified against `lua.nx2`).

### HOT-07 — Inverted `pairError` test in the keyboard snapshot drops the linked-context label
* **Severity**: Low
* **Category**: Correctness / UI
* **Location**: `ClaretHotbuild/modules/KeyboardBindings.lua:522`
* **Problem**: the preset lookup is performed *only when there is an error*, so the normal path
  never resolves `grid.context` and never fills `linkedRef`/`linkedLabel`.
* **Evidence**:
  ```lua
  elseif ref.kind=='preset' then
      presetLabel=label
      local preset=pairError and runtime.model:Get(ref.id)
      local linkedId=preset and preset.grid and preset.grid.context
  ```
  `pairError` is `nil` in the healthy case (`KeyboardBindings.lua:96`, set only in `Migrate`/`Write*`).
* **Impact**: the keyboard tooltip and the key dialog lose the "multifunction: <context name>" line
  for presets; `KeyboardEditor.ShowKeyTooltip`'s `a.linkedLabel` branch
  (`KeyboardEditor.lua:255-262`) is effectively dead. Cosmetic only.
* **Recommendation**: `not pairError and runtime.model:Get(ref.id)`.
* **Risk of fix**: none.
* **Confidence**: High.

### HOT-08 — Failed save restores the profile but skips `SavePreferences()`
* **Severity**: Low
* **Category**: Correctness
* **Location**: `ClaretHotbuild/modules/Runtime.lua:687-694`
* **Problem**: the first error branch writes `before` back into the profile table and returns without
  persisting, unlike the later rollback branches which call `pcall(SavePreferences)`.
* **Evidence**:
  ```lua
  ok, message = pcall(function()
      Prefs.SetToCurrentProfile('ClaretHotbuild', exported)
      SavePreferences()
  end)
  if not ok then
      Prefs.SetToCurrentProfile('ClaretHotbuild', before)
      return false, 'Could not save: ' .. tostring(message)
  ```
  Compare `Runtime.lua:696-701`, which does `Prefs.SetToCurrentProfile(...); SavePreferences()` in a
  `pcall`.
* **Impact**: low but real — in-memory profile and disk disagree until the next successful save; a
  crash before that would persist the *new* (unwanted) data on the next FAF save, or the *old* data
  overwrites a subsequent legitimate write depending on save order.
* **Recommendation**: mirror the other branches (`pcall(SavePreferences)`).
* **Risk of fix**: none.
* **Confidence**: High.

### HOT-09 — `Keys:Validate` is a stub that always passes
* **Severity**: Low
* **Category**: Correctness / Maintainability
* **Location**: `ClaretHotbuild/modules/Keys.lua:58-60`
* **Problem**: a validation API that validates nothing, while three call sites treat its result as a
  gate (`Runtime.lua:683` in `Commit`, plus the test at `Tests/hotbuild-keys.lua:35` which asserts
  the stub behaviour as a *spec*).
* **Evidence**: `function keys:Validate(bindings) return true end`.
* **Impact**: key conflicts between two Claret presets are not detected at save time. That is
  arguably correct (FAF owns the keymap and the pair model is authoritative), but then the function
  and its call sites are misleading dead weight, and `Model:Put` still enforces a *legacy* `key`
  uniqueness rule (see HOT-14) — so conflict policy is split between a real check and a fake one.
* **Recommendation**: delete `Keys:Validate` and its call sites, or implement it against
  `KeyboardBindings:Validate`.
* **Risk of fix**: low (test must be updated with the code — it currently asserts the stub).
* **Confidence**: High.

### HOT-10 — `KeyboardBindings:Refresh` throws on a keymap inconsistency instead of skipping it
* **Severity**: Medium
* **Category**: Correctness / Robustness
* **Location**: `ClaretHotbuild/modules/KeyboardBindings.lua:884-891`
* **Problem**: a hard `error()` inside the keymap rebuild path.
* **Evidence**:
  ```lua
  for key,id in pairs(current) do
      if ids[id] and not mappings[key] then
          if probe and probe:Get() then LOG('[Claret][keys] key='..key..' action='..id..' defined=false') end
          error('No action definition for '..tostring(key)..': '..tostring(id))
      end
  end
  ```
* **Impact**: `Refresh` is called synchronously from `Runtime.Create` (`Runtime.lua:847`), from
  `Start`→`RefreshKeys`, and from every editor close/commit. A throw here aborts the current
  caller: during `Create` it aborts Core's feature start (Lifecycle catches, state `error`), during
  an editor close it propagates into the `OnDestroy` chain. The throw happens **before**
  `IN_ClearKeyMap()` (`:893`), so the engine map is left as it was while `UserKeyActions` was
  already rewritten by `keys:Apply` — a half-applied state.
* **Recommendation**: log and skip the key (`current[key]=nil` in the source map copy is not
  possible for a read-only table, so simply `mappings[key]=nil` and continue), and never throw from
  a refresh path.
* **Risk of fix**: low, but the trigger conditions need one in-game check (see §C-3).
* **Confidence**: High for the code path; **unknown** for how often `ids[id] and not mappings[key]`
  can occur (depends on what `Mapper.GetKeyMappings(true)` merges — if it excludes the debug map,
  any Claret binding placed there triggers this).

### HOT-11 — `Migrate()` writes the user's key profile during a read path, before the feature is known to be enabled
* **Severity**: Medium
* **Category**: Data safety / Architecture
* **Location**: `ClaretHotbuild/modules/KeyboardBindings.lua:275-336`, invoked at `:916`
  (`Migrate()` at module create), reached from `Runtime.Create` (`:121`) and therefore from
  `Ensure()` in `Main.lua:130` — which runs unconditionally.
* **Problem**: constructing the service rewrites `ClaretHotbuildKeyboard`, `UserKeyMap`,
  `UserKeyDebugKeyMap`, `UserKeyActions` and `keyDescriptions`, then `SavePreferences()`, even when
  the Hotbuild option is disabled and even when the user only opened the game to play.
* **Evidence**:
  ```lua
  local ok,err=pcall(function()
      pairsByKey=proposed
      Prefs.SetToCurrentProfile(profileName,Profile(proposed))
      Prefs.SetToCurrentProfile('UserKeyMap',maps[1]); Prefs.SetToCurrentProfile('UserDebugKeyMap',maps[2])
      for chord in pairs(proposed) do Register(PairId(chord),{kind='pair',id=chord}) end
      SavePreferences()
  end)
  ```
* **Impact**: the legacy→pair migration is *intended* (spec: "Old `grid.context` links are migrated
  per assigned key"), and it does roll back on exception. The risk is timing: a data migration is
  performed by a module constructor, so it also runs for a disabled feature and cannot be reviewed
  by the user first. A bug in the conversion (`existing and (existing.preset~=pair.preset …)` →
  `pairError`) permanently disables the keyboard subsystem with no in-UI recovery (HOT-03 blast
  radius).
* **Recommendation**: move migration behind an explicit "data upgrade" step that runs once per
  profile version (store `version` in the profile and only migrate when it is lower), and skip it
  when the feature is disabled.
* **Risk of fix**: medium — the profile version field already exists (`version=2`), so the mechanic
  is available; a wrong guard would strand users on the old format.
* **Confidence**: High (code is explicit).

### HOT-12 — Build identity is inconsistent in three places
* **Severity**: Low
* **Category**: Maintainability / Diagnostics
* **Location**: `Main.lua:1-4`, `mod_info.lua:3,11`
* **Problem**: the loaded build cannot be identified from the log, and the declared dependency
  version does not exist.
* **Evidence**:
  ```lua
  Version = '0.10.36'
  local BuildStamp = '20261117-143'
  LOG('[Claret][build] hotbuild='..Version..' stamp='..BuildStamp)
  ```
  `mod_info.lua`: `version = 73`, `ReUI = 'ClaretHotbuild=0.10.37'`.
  CHANGELOG's newest entry is `20261117-147`, and the 147 code (shift-variant registration
  independent of a native FAF action) **is** present (`KeyboardBindings.lua:213-237`).
* **Impact**: the startup log claims build 143 while 147 is running — every bug report that quotes
  the log is mis-attributed (this already happened for 145/146). `ClaretHotbuild=0.10.37` advertises
  a version the mod does not have; any future `ReUI.Require{'ClaretHotbuild >= 0.10.37'}` would be
  satisfied by 0.10.36 code.
* **Recommendation**: bump `Version` and `BuildStamp` in the same commit as each change; make the
  stamp derived from the CHANGELOG entry; keep `mod_info.ReUI` equal to `Version`.
* **Risk of fix**: none (metadata only). The real fix is process: a check in
  `Tests/check-core.cjs` that compares `BuildStamp` to the newest CHANGELOG heading.
* **Confidence**: High.

### HOT-32 — Preset deletion confirmation survives closing the list
* **Severity**: Low
* **Category**: Correctness / UX
* **Location**: `ClaretHotbuild/modules/Editor.lua:550` (`deleteIntent` declared), `:576-585` (× button), `:549-552` (`CloseList`)
* **Problem**: deletion uses a two-click arm/confirm state (`deleteIntent`) that `CloseList()` does not
  reset, and no dialog is shown (unlike `ContextEditor.DeleteSaved`, which opens a real dialog with the
  assigned keys listed, `ContextEditor.lua:333-361`).
* **Evidence**:
  ```lua
  if deleteIntent~=id then deleteIntent=id; Status(T('hotbuild.editor.status.delete_confirm',binding.name),true); return end
  local saved,msg=service:Commit(nil,id); deleteIntent=nil
  ```
  `CloseList` only destroys `listPanel`/`listOverlay`.
* **Impact**: arm × on preset A, close the popup, reopen it later, click × on A again → the preset is
  deleted on that first click in the new view, with no confirmation visible at that moment. The same
  pattern means a user who arms and then changes their mind has no way to disarm except by deleting or
  selecting another preset.
* **Recommendation**: reset `deleteIntent` in `CloseList()`/`OpenList()`, or reuse the ContextEditor
  dialog (consistent with the documented "deletion requires confirmation").
* **Risk of fix**: none.
* **Confidence**: High.

---

## C. Section 2 — Strongly supported architectural problems

### HOT-13 — Three authorities for "which key runs which action", and the legacy one is never updated
* **Severity**: High
* **Category**: Architecture / Data integrity
* **Location**: `Model.lua:198-210` (`Put` uniqueness on `key`), `KeyboardBindings.lua:406-419`
  (`PairedBindings` writes `grid.context` on a *copy*), `Compatibility.lua:164-170` (reads
  `grid.context`), `Runtime.lua:664-713` (`Commit` persists the *draft*)
* **Problem**: after the 2026-11-13 decision ("store the pair of slots separately for each key; the
  old field remains in data for historical compatibility only"), three structures describe the same
  relation: `Model.binding.key` + `Model.binding.grid.context`, the `ClaretHotbuildKeyboard` pair
  record, and the FAF `UserKeyMap` entry. Only the last two are maintained when the user edits the
  Keyboard page; `grid.context` is only refreshed inside `PairedBindings`, which mutates throw-away
  copies.
* **Evidence**:
  ```lua
  function service:PairedBindings(model)
      for chord,pair in pairs(pairsByKey) do
          local binding=pair.preset and model:Get(pair.preset)
          if binding and pair.composite and PairIsMapped(chord) then
              binding.grid=binding.grid or {buildings={},units={}}
              binding.grid.context=pair.composite; binding.key=chord
  ```
  `model:Get` returns `CopyBinding` (`Model.lua:193-196`), so both assignments die with the copy.
  `Commit` then saves `binding` — the editor draft — whose `grid.context` came from the loaded
  preset, not from the pair.
* **Impact**: reassigning a preset to a different composite bind on the Keyboard page leaves the
  saved preset pointing at the old context. Later `Compatibility.ValidateBinding` /
  `ValidateContext` calls then validate the *wrong* pair: they can reject a valid configuration or
  accept an incompatible one ("absolute bind linked to a preset", "factory output + Factory row").
  The same split makes `Model:Put` reject a save with `Key already assigned to …` based on a stale
  legacy `key` string, while the authoritative pair says otherwise. This is the highest-value
  architectural risk in the module: it is silent, it accumulates, and it corrupts the meaning of
  saved data rather than the data itself.
* **Recommendation**: make the pair record the single source of truth and derive `key`/
  `grid.context` at read time (or drop them from validation entirely and validate against
  `pairsByKey`); stop persisting them, or persist them from the pair on every assignment change.
  Add a migration that rewrites `grid.context` from `pairsByKey` once.
* **Risk of fix**: medium-high — `Compatibility` and the editor's `Entries`/`CandidateForBinding`
  path read `grid`; dropping the field without a migration would lose the "which context is this
  preset paired with" answer for presets that are not currently mapped.
* **Confidence**: High (the copy semantics and the write paths were read); the user-visible
  frequency depends on how often users move presets between contexts.

### HOT-14 — `Runtime.lua` is a god module and the session singleton is a module-level upvalue
* **Severity**: Medium
* **Category**: Architecture / Testability
* **Location**: `ClaretHotbuild/modules/Runtime.lua:14` (`local current`), `:101-846` (one function),
  `:77-94` (eight export wrappers)
* **Problem**: one file owns dispatch, context resolution, four different execution paths, three
  persistence transactions, editor lifecycle, and diagnostics. State that belongs to a session lives
  in a module-level `current` that is assigned at the end of `Create` and cleared in `Destroy`.
* **Evidence**: `local current` at `:14`; `current = service` at `:846`; `if current == self then
  current = nil end` at `:841`. Every wrapper (`Execute`, `ExecuteAbsolute`, …) routes through the
  singleton. 819 lines: `Dispatch`, eight wrappers, `Create`, and thirteen service methods.
* **Impact**: (a) two "service" identities exist — `Main`'s `local service` upvalue and Runtime's
  `current` — and they are only kept in sync by the `OnDestroy` handler (`Main.lua:131-136`); a
  future code path that destroys the service elsewhere leaves one set and not the other; (b) the
  module cannot be exercised without a hand-built environment — the 13 failing tests each rebuild
  one, which is where most of the test drift comes from; (c) any change to persistence risks the
  dispatch paths in the same file.
* **Recommendation**: split into `Session` (lifecycle, `active`, profiles), `Dispatch` (the eight
  wrappers), `Executor` (the four `Execute*` paths); keep `Runtime.lua` as the thin keymap-facing
  facade that the profile strings already reference (so saved action strings stay valid).
* **Risk of fix**: medium — the action strings in users' profiles are hard-coded to
  `/mods/ClaretHotbuild/modules/Runtime.lua`; the facade must stay.
* **Confidence**: High.

### HOT-15 — Two parallel key-registration subsystems with duplicated encoders and overlapping ownership
* **Severity**: Medium
* **Category**: Architecture / Maintainability
* **Location**: `Keys.lua:20-22,66-127` vs `KeyboardBindings.lua:57-59,121-149,151-186`
* **Problem**: presets and absolute composites are registered twice, by two modules, into the same
  FAF tables, with independently implemented hex encoders and prefix constants.
* **Evidence**: `ActionId` in `Keys.lua:20-22` and `Enc` in `KeyboardBindings.lua:57-59` are the same
  algorithm written twice; `Keys:ApplyAbsolute` defines `ClaretHotbuildAbsolute_<hex>` for every
  assigned composite, while `KeyboardBindings.OwnIds/Register` defines the *same* id for `legacy`
  refs; both write `descriptions[id]`; both write `UserKeyActions`.
* **Impact**: fixes must be made twice (the 144/145/146/147 Shift work touched both files); the two
  writers can disagree on the action string for the same id (currently they agree by luck —
  `Keys.lua:112` and `KeyboardBindings.Register` (`:151-186`) both emit `ExecuteAbsolute(...)` without a Shift
  argument, while the pair path emits `IsKeyDown(16)`); ownership of "who removes a stale action"
  is split between `Keys:Apply`'s prefix sweep and `WritePairs`' per-chord cleanup.
* **Recommendation**: keep one registrar (KeyboardBindings) and reduce `Keys.lua` to what only it
  does — or, better, move the preset registration into KeyboardBindings and delete `Keys`.
* **Risk of fix**: medium — the profile strings and the two id namespaces must be preserved
  byte-for-byte.
* **Confidence**: High.

### HOT-16 — Every refresh rebuilds the entire engine keymap, with no coalescing
* **Severity**: Medium
* **Category**: Architecture / Performance
* **Location**: `KeyboardBindings.lua:861-910`, reached from `Runtime.lua:247-256`
* **Problem**: `Refresh` does `OwnIds()` → `GetKeyMappings(true)` → full copy/mutate →
  `IN_ClearKeyMap()` → `IN_AddKeyMapTable(mappings)` → `hotbuild.addModifiers()` →
  `IN_AddKeyMapTable(overrides)` → `hotkeylabels.init()`. There is no dirty flag, debounce or
  "already applied" check.
* **Evidence**:
  ```lua
  IN_ClearKeyMap()                     -- :893
  IN_AddKeyMapTable(mappings)          -- :895
  if SessionIsActive() then
      import('/lua/keymap/hotbuild.lua').addModifiers()   -- :898
      local overrides=FactoryShiftOverrides()             -- :899
      if next(overrides) then IN_AddKeyMapTable(overrides) end   -- :904
      import('/lua/keymap/hotkeylabels.lua').init()        -- :906
  ```
  Callers: `Runtime.Create:847`, `Start`, every editor `OnDestroy`, every
  `Set`/`Clear`/`SetDouble`/`ClearDouble`/`ClearChord`/`ClearPresetAssignments`/
  `ClearCompositeAssignments`/`Commit`/`CommitContext`, and the keybindings-dialog `CloseUI` hook.
* **Impact**: an editing session performs dozens of full keymap rebuilds, each one clearing the map
  that every other mod's hook may have contributed to (`IN_AddKeyMapTable(mappings)` only restores
  what `GetKeyMappings(true)` knows). Any other mod that adds entries after Claret's last rebuild
  loses them; any mod that rebuilds later loses Claret's overrides. Interaction order becomes
  load-order dependent.
* **Recommendation**: apply the diff (only changed chords), and invalidate on demand; keep the full
  rebuild for session start and for the keybindings-dialog close only.
* **Risk of fix**: medium-high — `IN_ClearKeyMap`/`IN_AddKeyMapTable` is the only reliable primitive
  available; a diff-based approach needs `Mapper` cooperation and careful in-game verification.
* **Confidence**: High for the mechanism; **unknown** for how many other mods' entries survive,
  which needs a two-mod test in game.

### HOT-17 — Error policy is "stop everything", with no diagnostic surface and no recovery action
* **Severity**: Medium
* **Category**: Architecture / UX
* **Location**: `Runtime.lua:247-256`, `:664-668`, `:715-720`; `Model.lua:314-330`;
  `ContextModel.lua:223-225`; `KeyboardBindings.lua:275-336`
* **Problem**: three independent error channels (`model` warnings, `contextModel` warnings,
  `pairError`) are each treated as a global stop, and none of them is visible in the UI.
* **Evidence**: see HOT-03. For `pairError`, `LoadPairs` returns `nil` on *any* unknown field
  (`KeyboardBindings.lua:255-262`), and `Migrate` turns that into a single message
  (`s004`) that the Keyboard page only shows via `Status(...)` — while `Set`/`Clear`/`Validate` all
  return early with the same text, so the page looks functional but every click fails.
* **Impact**: the failure mode is "the mod quietly stops working", which is the most expensive kind
  to debug from a user report, and there is no way to reset from the UI.
* **Recommendation**: one diagnostics object with per-record entries, rendered in a collapsible
  "Problems" section on the Hotbuild page, plus a "reset data" action behind confirmation.
* **Risk of fix**: low (additive UI).
* **Confidence**: High.

### HOT-18 — Hooking a Core module file directly, with an asymmetric guard
* **Severity**: Medium
* **Category**: Compatibility / Maintainability
* **Location**: `Main.lua:64-70` (MenuKey) vs `Main.lua:117-127` (keybindings)
* **Problem**: Hotbuild patches `ClaretCore/modules/MenuKey.lua`'s global `Open`, assuming that
  (a) the file keeps that path, (b) `Open` stays a module-table field, and (c) it exists at
  pre-create time. The `CloseUI` hook guards `type(original) ~= 'function'`; the MenuKey hook does
  not.
* **Evidence**:
  ```lua
  ReUI.Core.Hook('/mods/ClaretCore/modules/MenuKey.lua', 'Open', function(original)
      return function()
          if service then service:BreakQuick() end
          return original()
      end
  end)
  ```
  versus
  ```lua
  ReUI.Core.Hook('/lua/ui/dialogs/keybindings.lua', 'CloseUI', function(original)
      if type(original) ~= 'function' then return original end
  ```
  `MenuKey.lua:12` currently defines `function Open()` as a global, which FAF's `import` exposes as
  a module field — so it works today. ReUI applies hooks by `rawget(module, field)` and
  `module[field] = newField` (`ReUI/Core/Core.lua:12-15`), with `pcall` around the whole hook
  (`:23-27`), so a missing field would surface as "Failed to hook" at load and then as
  `attempt to call nil` on the first menu open.
* **Impact**: the coupling is intentional (break the quick-repeat chain when the Core menu opens),
  but it means Core cannot rename or localise `Open` without a runtime error in Hotbuild's menu
  path. The asymmetry also means the keybindings hook fails *silently* if FAF ever localises
  `CloseUI`, so "refresh keys after the FAF dialog" would just stop happening with no trace.
* **Recommendation**: add the same `type(original)=='function'` guard; prefer a Core-published event
  (`ReUI.ClaretCore.OnMenuOpened`) over hooking a module file.
* **Risk of fix**: low.
* **Confidence**: High for the code; **unknown** for FAF's `CloseUI` visibility (it is guarded, so
  the current behaviour could be a silent no-op).

### HOT-19 — Per-press full template-catalog rebuild
* **Severity**: Medium
* **Category**: Performance
* **Location**: `Runtime.lua:281` and `:561` (`self:Catalog():RefreshTemplates()`),
  `TemplateCatalog.lua:84-135`
* **Problem**: every preset press re-reads `build_templates` from the profile, re-parses every
  template (validation loops per cell), regenerates cross-faction variants for four factions, sorts,
  and logs.
* **Evidence**:
  ```lua
  function result:RefreshTemplates()
      records,byId,families={},{},{}
      local values=source()                     -- Prefs.GetFromCurrentProfile('build_templates')
      ...
      for _,value in ipairs(values) do
          local record=Parse(value,base)
          if record then
              Add(record)
              local family={record.id}
              if equivalents then
                  for _,faction in ipairs({'UEF','AEON','CYBRAN','SERAPHIM'}) do
                      ... for each cell: equivalents:Variants(cell[1]) ... Parse(...)
      ...
      LOG('[ClaretHotbuild] Templates loaded: source='..table.getn(values)..', available='..table.getn(records))
  ```
* **Impact**: per-press latency and garbage scale with the number of saved templates × cells ×
  factions; the `LOG` line is unconditional. The spec does require a refresh "on bind press"
  (`Context/hotbuild-rules.md`), so the refresh itself is intended — the *cost profile* is not.
* **Recommendation**: cache the parsed family by a cheap revision (profile table identity or a
  stored `version`), rebuild only when the source table changed since the last press; drop the
  `LOG` to the probe gate.
* **Risk of fix**: low-medium — a stale cache would hide a newly saved template until the editor is
  opened; mitigate by invalidating on editor close/save.
* **Confidence**: High.

### HOT-20 — Quadratic allocation in the keyboard-binding paths
* **Severity**: Medium
* **Category**: Performance / Maintainability
* **Location**: `KeyboardBindings.lua:121-149` (`OwnIds`), `:392-405` (`PairIsMapped`),
  `:203-242` (`FactoryShiftOverrides`), `Model.lua:187-196`
* **Problem**: `OwnIds()` is rebuilt on every call and calls `runtime.model:List()` and
  `runtime.contextModel:List()`, both of which deep-copy every binding; `PairIsMapped` calls
  `OwnIds()` *inside* its per-key loop; `FactoryShiftOverrides` calls `PairIsMapped` for every pair,
  and `service:Validate` calls `OwnIds()` several times.
* **Evidence**:
  ```lua
  local function OwnIds()          -- KeyboardBindings.lua:121 — rebuilds every call
  PairIsMapped=function(chord)     -- :392
      local id=PairId(chord)
      for _,map in ipairs({GetMap('UserKeyMap'),GetMap('UserDebugKeyMap')}) do
          for key,value in pairs(map) do
              ...
              local ref=OwnIds()[value]         -- rebuild per key
  ```
* **Impact**: `Refresh` cost is O(pairs × keys × bindings) with fresh tables each time; with a
  realistic 20–30 pairs and ~150 keys this is tens of thousands of allocations per refresh, on the
  UI thread, and `Refresh` runs on every assignment change and editor close.
* **Recommendation**: build `OwnIds` once per refresh and pass it down; memoize it on the model
  version.
* **Risk of fix**: low.
* **Confidence**: High (code is explicit). In-game measurable with the existing `OpenPerf`/probe
  instrumentation.

---

## D. Section 3 — Potential risks requiring validation (not defects yet)

### HOT-21 — Six catalogue actions use uppercase `UI_LUA`, the rest `UI_Lua`
* **Severity**: Low
* **Category**: Correctness / Compatibility
* **Location**: `ContextActions.lua:95,96,98,120,126,127`
* **Problem**: `select='UI_LUA import(...)...'` is passed to `ConExecute` verbatim
  (`ContextActions.lua:672` `ConExecute(action.select)`). If the console command name is
  case-sensitive, those six actions (`set_target_priority`, `set_default_target_priority`,
  `copy_orders`, `cap`, `upgrade_structure`, `upgrade_structure_pause`) silently do nothing while
  the otherwise identical `UI_Lua` ones work.
* **Evidence**: `select='UI_LUA import("/lua/keymap/misckeyactions.lua").SetWeaponPrioritiesToUnitType()'`
  vs `select='UI_Lua import("/lua/keymap/misckeyactions.lua").CycleRetaliateStateUp()'`.
* **Check needed**: one in-game press of `copy_orders` with the probe log on; or grep the FAF
  console-command registration in `lua.nx2`.
* **Confidence**: Low that it is broken; High that the inconsistency exists.

### HOT-22 — `ExecuteFactoryShift`'s fallback is `ConExecute(<a keymap action string>)`
* **Severity**: Medium
* **Category**: Compatibility / Correctness
* **Location**: `Runtime.lua:631-636`, `KeyboardBindings.lua:226-237`
* **Problem**: `native.action` comes from `Mapper.GenerateHotbuildModifiers()` — a *keymap*
  definition (`{action=<UI_Lua script>, category=…}`), which the keymap runner executes as Lua.
  `ExecuteFactoryShift` passes that same string to `ConExecute`, i.e. treats it as a console
  command. If FAF's console does not accept a `UI_Lua …` command, the "outside factory context"
  branch is a no-op — which is exactly the case builds 145–147 were iterating on.
* **Evidence**: `if type(nativeAction)=='string' and type(ConExecute)=='function' then
  ConExecute(nativeAction); return true end`; the override is built as
  `copy.action=string.format('UI_Lua import("…Runtime.lua").ExecuteFactoryShift(%q,%q)', chord, fallback)`
  where `fallback` is `native.action` (already a `UI_Lua …` string).
* **Note in favour of the code**: `ContextActions` already relies on `ConExecute('UI_Lua …')` for
  `cycle_idle_factories` (`:92`), so the pattern is at least partly proven in this codebase.
* **Check needed**: press Shift+<preset key> with a mixed (non-factory) selection; the fallback
  should run the native action.
* **Confidence**: Medium that the fallback works; High that it is untested in this audit.

### HOT-23 — Override entries inherit FAF's category, not Claret's
* **Severity**: Low
* **Category**: UI / Ownership
* **Location**: `KeyboardBindings.lua:230-237`
* **Problem**: `local copy={category='Claret Hotbuild'}` then
  `for field,value in pairs(native) do copy[field]=value end` — `native.category` overwrites the
  Claret category. The synthetic `Shift-<key>` binding therefore appears in the FAF keybindings
  dialog under FAF's own category, labelled with FAF's description, while it actually runs Claret's
  intercept.
* **Impact**: users cannot tell that the Shift variant is Claret's; `Keys:Apply`'s stale cleanup
  (which filters on `category == 'Claret Hotbuild'`) never considers these ids — harmless today
  because they are chord keys, not new ids, but the intent is unclear.
* **Check needed**: open FAF keybindings with a preset bound and Shift free; inspect the category of
  the Shift entry.
* **Confidence**: High for the overwrite (plain Lua table copy order); Low for whether the dialog
  actually shows it that way.

### HOT-24 — `Model:Put` still rejects duplicate legacy `key` strings
* **Severity**: Medium
* **Category**: Data integrity
* **Location**: `Model.lua:203-208`
* **Problem**: `if other.key == validated.key` → `'Key already assigned to ' .. other.name`, but
  `key` is the legacy field that the Keyboard page no longer maintains. Two presets can end up with
  the same stale `key` (e.g. both migrated from the same pre-2026-11-13 assignment), after which
  neither can be saved — with an error that points at the *other* preset's name.
* **Impact**: plausible save-blocker after a migration; not reproduced.
* **Check needed**: import a profile with two presets sharing `key`, edit and save.
* **Confidence**: Medium (path exists; frequency unknown).

### HOT-25 — Quick-repeat has no window; a `double` continuation re-arms indefinitely
* **Severity**: Medium
* **Category**: Correctness / UX
* **Location**: `ContextRepeat.lua:89-108`, decision in CHANGELOG build 20261116-73
* **Problem**: `Continue` consumes `pending`, then re-`Remember`s the same action on success, so a
  `continuation='double'` action (e.g. `select_transport_double`, `select_acu_double`) keeps firing
  on every press as long as the selection is unchanged. The 1.5 s window from
  `Context/hotbuild-context-spec.md` §4 was removed by decision, and the spec was not updated.
* **Impact**: intended per build 73 ("второе действие … срабатывает на каждом нажатии без
  временного окна"), but the *implementation* now has no upper bound at all: a double action whose
  execution does not change the selection becomes a permanent toggle. The failing test
  `Tests/hotbuild-context-repeat.lua:22` encodes the old expectation.
* **Check needed**: decide whether "no window" means "no time limit" or "until selection changes";
  the test and the spec disagree with the code, and the code is the only thing that was decided.
* **Confidence**: High for the code, Medium for whether the behaviour is desired.

### HOT-26 — `FactoryShiftOverrides` cost is hidden inside `Refresh`
* **Severity**: Low
* **Category**: Performance
* **Location**: `KeyboardBindings.lua:203-242`
* **Problem**: for every pair it calls `PairIsMapped` (which itself scans both maps and rebuilds
  `OwnIds`), plus `Mapper.GenerateHotbuildModifiers()` once (a table build over all hotbuild keys),
  plus a scan of both user maps per pair for `userOwnsShifted`.
* **Impact**: O(pairs² × keys) per refresh; measured only through the editor-open timing today.
* **Check needed**: `OpenPerf` timing with ~30 pairs, or the probe log line count.
* **Confidence**: High for the complexity, unknown for the absolute cost.

---

## E. Section 4 — Optional improvements

### HOT-27 — Dead code: `QuickRepeatMenu.lua` + `QuickRepeatSettings.lua`
* **Severity**: Low (optional) · **Category**: Maintainability
Nothing imports `QuickRepeatMenu` (import graph: 27 modules, `QuickRepeatMenu` has no consumer;
`QuickRepeatSettings` only by `QuickRepeatMenu`). The option they edit was removed in build 73
(CHANGELOG: "Удалена настройка интервала повтора"). 170 lines of dead UI.
*Recommendation*: delete both, or keep them behind the future "repeat window" decision.
*Confidence*: High. *Risk*: none (no profile data).

### HOT-28 — Duplicated/shadowed locals and dead locals
* **Severity**: Low (optional) · **Category**: Maintainability
* `KeyboardEditor.lua:1` and `:84` define the same `local function T` twice;
  `:230` and `:348` define `local function LoadAssignments` twice; `Cancel` is defined three times
  (`:415`, `:507`, `:596`) and `Close` twice in `ContextEditor.lua:1142,1147`.
* `Runtime.lua:336` `local kind = contextId and ContextActions.Classify(context.selection)` is
  never used afterwards in `service:Execute`.
* `ContextEditor.lua:580-581` `ConflictsWithEmpty()`/`EmptySelectionPolicy()` are stubs returning
  `false`/`nil`.
*Impact*: readers cannot tell which definition is live; the upvalue limit (a known FAF failure mode,
  see CHANGELOG build 55) is closer than necessary. *Confidence*: High. *Risk of fix*: low.

### HOT-29 — Unconditional log lines in hot paths
* **Severity**: Low (optional) · **Category**: Diagnostics / Performance
`[ClaretHotbuild] Templates loaded: …` per press (`TemplateCatalog.lua:135`),
`[Claret][keyboard-clear] …` per right-click (`KeyboardEditor.lua:701,708,713,716`),
`[ClaretHotbuild] no build templates in profile` once per session. All of these are cheap but they
are not behind the `probeEnabled` gate that the rest of the diagnostics use
(`Runtime.lua:25-27`). *Recommendation*: route through the probe gate or drop. *Confidence*: High.

### HOT-30 — `mod_info.name = 'Claret Hotbuild (Test)'`
* **Severity**: Low (optional) · **Category**: Maintainability
A shipped mod advertises "(Test)" in the FAF mod list. Cosmetic, but it is the name users report
bugs against. *Confidence*: High. *Risk*: none (display only; changing it does not touch the UID).

### HOT-31 — Per-frame modifier polling in the keyboard editor
* **Severity**: Low (optional) · **Category**: Performance
`KeyboardEditor.lua:781-797`: a `watcher` control calls `IsKeyDown(17), IsKeyDown(16), IsKeyDown(18)`
on every frame while the page is visible, and on change calls `DrawModifiers()` + `Refresh()`
(all key buttons + tooltip). The project rule prefers event-driven updates; the FAF keymap already
delivers key events to `OnKeyboardEvent` (`root.OnKeyboardEvent` is wired in `Navigator.lua:165-168`,
but the editor does not use it for modifiers).
*Impact*: 3 engine calls per frame for as long as the settings page is open; `Refresh` on every
modifier transition. *Recommendation*: drive from key events, or poll at a coarse interval via
`scope:Every`. *Confidence*: High. *Risk of fix*: low (editor-only).

---

## F. Spec vs code

| Spec statement | Code state | Verdict |
|---|---|---|
| `hotbuild-context-spec.md` §4: "Repeat window: one global setting in F10 → Claret, default 1.5 s" | setting removed in build 73; `Options.lua` has only `enabled`; `ContextRepeat` has no time check | **doc drift** (decision supersedes spec) |
| §4: "A different key breaks the repeat chain" | implemented via `TouchQuick` (`Runtime.lua:60-68` + `ContextRepeat.lua:35-38`) | matches |
| §6: "If a key has a building preset, the whole Builders group for that key is locked" | not implemented: a preset and builder context rows can share a key; context rows win when they match (`Runtime.lua:337-357`), which is the later 2026-11-13 decision | **doc drift** (later decision wins) |
| §1 column order (units → builders → factory → missiles → transport → mex → scouts → other) | `ResolveContext` order: land/air/navy → empty → acu/sacu/engineer → factory → silo_tactical/silo_nuclear → transport/mex/scout/other (`Runtime.lua:150-186`) | matches |
| §3 "never delete invalid binds silently" | `ContextModel.Validate` preserves invalid rows on load (`preserveInvalid`, `ContextModel.lua:74-96`) and `Compatibility` blocks new ones | matches |
| §8 "keep all existing action IDs working" | ~40 ids carry `obsolete=true`/`hidden=true` but remain executable (`ContextActions.lua:290-330`) | matches |
| `hotbuild-rules.md`: "Catalog refresh … on open, selection or bind press — no background polling" | per-press `RefreshTemplates` (`Runtime.lua:281`), plus a per-frame modifier poll in the keyboard editor (HOT-31) and a 1.1 s `CycleMenu` frame update | **partial drift** |
| `hotbuild-rules.md`: "Adapter passes a copy of the geometry to `SetActiveBuildTemplate`" | `Adapter.Build` builds `data` from `record.templateData` (`Adapter.lua:108-116`) | matches |
| `hotbuild-rules.md`: "Factories and replays do not execute templates" | `CanBuild` returns false for `isReplay`; factory branch is separate from the template branch | matches |
| `hotbuild-rules.md`: "Key assignment and clearing happen only on the Keyboard page" | `Editor` no longer edits keys; `KeyboardEditor` + `service:SetKeyboardAssignment` do | matches |

---

## G. Test failure observations (module-level only; root cause owned by the tests task)

Run: `node Tests/check-core.cjs --only hotbuild` → 12 PASS lines, 13 FAIL lines.

| Failing test | First error | Module-level cause visible in this audit |
|---|---|---|
| `hotbuild-equivalents` | `Equivalents.lua:72: attempt to call a nil value (method 'List')` | the test's catalog stub has no `List`; production `Catalog:List(filters)` exists and tolerates `nil` (`Catalog.lua:245-246`) → **harness gap** |
| `hotbuild-templates` | `Tests/…:54 assertion failed` | fixture `unit({...}, false)` has no ENGINEER category; `CanPlaceBuilds` (build 134) then returns false → **stale fixture** |
| `hotbuild-build-key-labels` | `BuildKeyLabels.lua:35: nil global 'Colours'` | **real defect** (HOT-01) |
| `hotbuild-adapter` | `Tests/…:111 Not buildable by this selection` | same ENGINEER-category fixture effect as templates → **stale fixture** |
| `hotbuild-keys` | `Tests/…:41 assertion failed` | expects `Execute("x")`; code emits `Execute("x", IsKeyDown(16))` since build 144 → **stale expectation** |
| `hotbuild-runtime` | `Tests/…:147 assertion failed` | same `IsKeyDown(16)` suffix → **stale expectation** |
| `hotbuild-grid-editor` | `Editor.lua:1100` rethrow of test-side `filters` nil | test reads an env field the editor no longer exports (`Editor.lua:1004-1009` has no `filters`) → **harness/API drift** |
| `hotbuild-cycle-menu` | `Tests/…:68 nil 'filters'` | same helper expectation → **harness drift** |
| `hotbuild-keyboard-editor` | `KeyboardEditor.lua:803` rethrow of `/lua/maui/edit.lua` import | test env does not provide the `Edit` module the editor imports → **harness gap** |
| `hotbuild-context-actions` | `Tests/…:306` `select_transport_nearest` availability/`exclusive` | definition is `selectionPolicy='accumulate'` since build 76/77 → **stale expectation** |
| `hotbuild-context-repeat` | `Tests/…:22 "double is consumed"` | window removed in build 73 → **stale expectation** (see HOT-25) |
| `hotbuild-context-runtime` | `Tests/…:360` engine keymap action text | expects `ExecuteKeyboardPair("A")`, code emits `ExecuteKeyboardPair("A", IsKeyDown(16))` → **stale expectation** |
| `hotbuild-context-editor` | `ContextEditor.lua:1161` rethrow of `:154 SetTexture` nil | test `Bitmap` mock lacks `SetTexture` → **harness gap** |

Summary of the pattern (for the tests task): **9–10 of 13 are stale tests/fixtures against builds
134–147**, one is the real `Colours` defect, and the remaining two encode decisions that were
superseded (repeat window, transport policy). None of them indicates a new runtime regression in
144–147 except HOT-01.

---

## H. Versioning / metadata (item 9)

* `Version = '0.10.36'` (`Main.lua:1`) vs `mod_info.ReUI = 'ClaretHotbuild=0.10.37'` → mismatch.
* `BuildStamp = '20261117-143'` while the 147 feature is present → the log line
  `[Claret][build] hotbuild=0.10.36 stamp=20261117-143` mislabels the running code (HOT-12).
* `mod_info.version = 73` — integer revision, unrelated to `Version`; fine, but nothing links it to
  the CHANGELOG either.
* `mod_info.name = 'Claret Hotbuild (Test)'` (HOT-30), `uid = 'claret-hotbuild-001'` (stable),
  `ui_only = true`, `selectable = true`.
* `ReUI.Require{'ClaretCore >= 0.10.5', …}` — the floor is far below the installed 0.10.13; the
  code uses `ReUI.ClaretCore.IsMenuOpen`/`IsKeyCaptureActive`/`AppendTransportCargo`/
  `CreateStrategicRing`, all of which exist in 0.10.13 (`ClaretCore/Main.lua:186-230`) but none of
  which is guaranteed by a 0.10.5 floor. **Recommendation**: raise the floor to the version that
  introduced them.

## I. Cross-module API check (item 5)

Every Core symbol Hotbuild touches exists in Core's returned table:

| Symbol | Hotbuild use | Core definition |
|---|---|---|
| `Localization` (`.Text`, `.SearchText`, `.Register`, `.Subscribe`, `.Unsubscribe`) | 54 sites | `ClaretCore/Main.lua:193` (`Localization = Localization`) |
| `RegisterFeature` | `Main.lua:71` | `ClaretCore/Main.lua:191`, impl `:104-121` |
| `RegisterSettingsSection` | `Main.lua:76` | `:192` → `menu:Register` |
| `IsMenuOpen` | `Main.lua:81` | `:194` |
| `IsKeyCaptureActive` | `Runtime.lua:19-21` | `:195` → `Menu.lua:841` |
| `AppendTransportCargo` | `ContextActions.lua:451-452,716-720` | `:196-225` |
| `CreateStrategicRing` | `ContextActions.lua:723-725` | `:226-230` |

Plus two hard file dependencies: `import('/mods/ClaretCore/modules/Theme.lua')` (6 modules) and the
`MenuKey.lua` hook (HOT-18). No `ReUI.ClaretCore.*` call is undefined. The `append_transport_cargo`
and `create_strategic_rings_*` actions use `rawget(_G,'ReUI')` instead of the module-level
`ReUI.ClaretCore` used everywhere else — inconsistent with the project rule recorded in
`hotbuild-rules.md` ("do not rely on `rawget(_G, 'ReUI')`"), and it makes those two actions
silently unavailable if `ReUI` is only reachable through the module environment.

## J. Hooks summary (item 6)

1. `/lua/keymap/hotkeylabels.lua#getKeyTables` (`Main.lua:30-53`) — decorates the BPID→HotKeyData
   map with Claret preset keys. Guarded on `service`, `service.active`, `model.Get`,
   `KeyboardAssignments`; both `Build` and `Merge` are `pcall`ed → **fails silent** (HOT-01).
2. `/lua/ui/game/gamemain.lua#OnSelectionChanged` (`Main.lua:55-62`) — calls
   `service:QuickSelectionChanged(newSelection)`. Core hooks the same function
   (`ClaretCore/Main.lua:122-133`) and both read `IsIgnoredSelection` from the module before calling
   the original. ReUI applies hooks in registration order, so Core's wrapper is inner and Hotbuild's
   is outer; both compute `ignored` *before* the original runs, so the semantics agree. No
   interaction defect found; the cost is two extra closure layers per selection change.
3. `/mods/ClaretCore/modules/MenuKey.lua#Open` (`Main.lua:64-70`) — HOT-18.
4. `/lua/ui/dialogs/keybindings.lua#CloseUI` (`Main.lua:117-127`) — refresh keys after the FAF
   dialog closes; guarded, so a missing field is a silent no-op (**unknown** whether FAF exposes
   it as a module field).

## K. Performance inventory (item 10)

Per **frame**: `KeyboardEditor` modifier poll (3 × `IsKeyDown`, while the page is visible);
`CycleMenu` `OnFrame` (only while a cycle preview is up, max 1.1 s); `EngineerHold` thread
(`WaitSeconds(0.3)` + `IsKeyDown`, only while an engineer key is held). No always-on polling found.

Per **key press**: `Dispatch` probe gate read (2 table lookups + `OptionValue:Get()`), `pcall`
guards around `IsKeyDown`, `Adapter:Context` (selection copy, `GetUnitCommandData` over the
selection, `CurrentFactoryTechTab` import + pcall), `Catalog:RefreshTemplates` (HOT-19),
`ContextActions.Available` up to 3× per press (once in `RunResolved`, once in `Execute`, once in
`ExecuteWithOutcome`), `pcall` around `ExecuteRow`/`Execute`, `model:Get` deep copies (3× per press
in `Execute`), `continuation:Remember`/`RememberQuick` (selection snapshots), `GetCommandMode()`
twice at the end, and `model:List()` inside `OwnIds` on the engineer-hold path.

Per **edit action**: full keymap rebuild + `hotkeylabels.init()` (HOT-16), plus `OwnIds`/`PairIsMapped`
quadratic work (HOT-20).

No `pcall` inside a loop of consequence except `SelectNextUnit`/`SelectFiltered` (selection
transactions, one per action) and `HasEligibleUnitCapability` (per unit × per capability), which is
per-press, not per-frame. That is acceptable under the project's constraint.

---

## L. Recent regression surface, builds 141–147 (item 4)

| Build | Change | Present in current code? | Residual risk |
|---|---|---|---|
| 141 | `Distribute orders` for transport / scouts / builders / TML / nuke silos | yes: `spreadattack` gets `transport, scout, silo_tactical, silo_nuclear` added to `contexts` (`ContextActions.lua:225-229`), and `Available` requires at least one non-factory unit in the selection (`:398-407`) — matching the changelog wording “FAF3840 accepts all non-factory units” | none found |
| 144 | Shift read as numeric code 16 in the generated action strings | yes: `Keys.lua`/`KeyboardBindings.Register` emit `IsKeyDown(16)`; `Runtime.Execute` falls back to `pcall(IsKeyDown,16)` (`:275-278`) | the three failing tests that expect `Execute("x")` are stale (see §G) |
| 145 | Shift variant intercepted to send count 5 for factory-only selections | yes: `FactoryShiftOverrides` (`KeyboardBindings.lua:203-242`) + `ExecuteFactoryShift` (`Runtime.lua:617-636`) | HOT-22 (fallback semantics), HOT-23 (category attribution) |
| 146 | `PairIsMapped` scope crash fixed | **yes, verified**: `local PairIsMapped` at `KeyboardBindings.lua:192`, assignment at `:392`, and the only call during construction is `service:Refresh` → `FactoryShiftOverrides` at `:899`, after the assignment; `Migrate()` (`:916`) does not call it | none for this cause. Spot-check of the other forward-declared locals that hold functions (`Editor.lua:646 Pick`, `KeyboardEditor.lua:227 Refresh`, `:497 SaveChoice`, `ContextEditor.lua:525 RowsFor`, `:837 AddAction`) found no call during module construction — Medium confidence, not exhaustive |
| 147 | Shift variant registered regardless of a native FAF action | yes: `fallback = native.action or ExecuteKeyboardPair(<chord>,false)` (`KeyboardBindings.lua:226-229`), so an override is created for every mapped preset pair unless the user owns the shifted chord (`:216-225`) | HOT-22 |
| — | Preset deletion | `Editor.lua:576-585`: two-click arm/confirm, `service:Commit(nil,id)` clears the keyboard assignments and restores the profile on failure (`Runtime.lua:695-701`) | HOT-32 (arm state survives closing the list) |
| — | Keyboard editor init | `KeyboardEditor.Create` rethrows the real error once (`:803`); no nil-call remains | the failing test lacks the `/lua/maui/edit.lua` mock (§G) |

Command distribution detail (build 141): the action only checks “not a factory” once for availability
and then delegates to FAF's `DistributeOrders(true)` (`ContextActions.lua:97`). It does not filter the
selection itself, so an unsupported unit in a mixed selection is handled by FAF, not by Claret —
consistent with the changelog note.

## M. Confidence statement

* Everything in §B is read directly from the current code and quoted; the only external assumption
  is that the workspace `ClaretHotbuild/` is the live code, which the batch briefing asserts and the
  `mod_info`/`Version` values confirm.
* §C items are architecture judgements grounded in quoted code; their *impact* estimates (how often
  a user hits them) are assumptions, marked in each entry.
* §D items are explicitly unverified; each has the exact check that would settle it.
* Nothing in this audit was verified in game. The three highest-value in-game checks are:
  (1) whether a disabled Hotbuild leaves dead keys (HOT-04), (2) whether Shift+preset outside a
  factory selection runs the native action (HOT-22), (3) whether construction tiles ever show
  Claret keys (HOT-01).
