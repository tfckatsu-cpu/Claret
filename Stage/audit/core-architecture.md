# ClaretCore — architecture reconstruction and code-quality audit

Audit date: 2026-11-18.
Code base: workspace `ClaretCore/` (batch briefing: byte-identical to the live mod, SHA-256 verified).
Snapshot: `Version = '0.10.13'`, `BuildStamp = '20261117-45'`, `mod_info.version = 32`,
`mod_info.ReUI = 'ClaretCore=0.10.13'`. Dependency: ReUI.Core >= 1.7.0, ReUI.UI, ReUI.Options >= 1.2.0,
`version = 3816` (game build, see `Context/reui-notes.md:39`).

Size: 42 Lua files, 9 645 lines — `Main.lua` (232), `Options.lua` (9), `mod_info.lua` (11),
39 modules. **Production-reachable: 2 899 lines (14 files). Unreachable staging library: 6 735 lines
in 27 files = 70 % of the code** (measured; see §A.4).

Evidence policy: every claim is tied to a line I read in this run. Three tiers are marked explicitly:
**Fact** (code or tool output I read), **Assumption** (reasoned from code, not executed),
**Unknown** (needs game/ReUI verification). Nothing here was executed in FAF. Commands run (read-only):
`node Tests/check-core.cjs --quiet --only <name>`, `Select-String`/`rg`-style scans of `ClaretCore/`,
`ClaretHotbuild/`, `Tests/`, `Context/reui-decompiled/`, and `findstr` over
`C:/ProgramData/FAForever/gamedata/lua.nx2`.

---

## A. Architecture as built

### A.1 Bootstrap and lifecycle (question 1)

**Fact — file-scope phase.** `Main.lua:1-12` sets `Version`, logs the build stamp and calls
`ReUI.Require{...}`. `ReUI.Require` may only be called in the loader's `preload` stage
(`Context/reui-decompiled/ReUI/Core/Modules/Loader.lua:455` asserts exactly that), so this is the
only legal place for the dependency block. ReUI then calls `Main(isReplay)` and publishes the return
value as `ReUI.ClaretCore` (`Loader.lua:299`, `local r = module.Main(self._isReplay)`).

**Fact — `Main()` order** (all in one function, no sub-modules):

1. `options = ReUI.Options.Mods['ClaretCore']` (`Main.lua:17`). This index is *lazy*: ReUI's
   `ModsOptionsMetaTable.__index` imports `/mods/<name>/Options.lua` on first access and caches the
   result with `_rawset` (`Context/reui-decompiled/ReUI/Options/Options.lua:95-108`). So there is no
   init-order dependency on `Options.lua` having run first, and the `OnChanged` object bound at
   `Main.lua:43` is the same instance later used by the menu.
2. `Localization.Initialize(options.language:Get())` → `currentLanguage` (`Main.lua:19`).
3. `transportCargo = TransportCargo.Create(isReplay)` (`Main.lua:20`) — created before the UI exists.
4. Language migration `'auto' → 'en'|'ru'` with `pcall` and rollback (`Main.lua:21-34`).
5. `options.language.OnChanged:Add(languageChanged)` (`Main.lua:43`); the handler forks a thread and
   waits one frame before `SetLanguage` (`Main.lua:35-42`).
6. `strategicRings = StrategicRings.Create()` (`Main.lua:44`). The module itself imports
   `/lua/ui/game/rangeoverlayparams.lua` at **module scope** (`StrategicRings.lua:3`), so this line
   is also a hard load-time dependency on a game file.
7. `ReUI.Core.Hook('/lua/ui/game/painting/PaintingBrush.lua', 'PaintingBrush', …)` (`Main.lua:45-56`).
8. `MenuKey.Create(open)` (`Main.lua:59-61`), then `Menu.Create(menuKey)` (`Main.lua:62`). The
   `open` closure dereferences `menu` only after `uiReady`, so the forward reference is safe.
9. `menu:Register{id='core', …}` (`Main.lua:75-93`), then `OnPreCreateUI` (`Main.lua:94-100`), then
   the registry/event/pending/`registered`/`disposed` block (`Main.lua:101-108`), `RegisterFeature`
   (`Main.lua:104-118`), the `gamemain.OnSelectionChanged` hook (`Main.lua:123-134`), then
   `OnPostCreateUI` (`Main.lua:136-185`).

**Fact — `OnPreCreateUI` vs `OnPostCreateUI`.** Hooks registered through `ReUI.Core.Hook` are applied
by ReUI.Core's *own* pre-create callback, added when ReUI.Core loads
(`Context/reui-decompiled/ReUI/Core/Core.lua:20-27`), while mod callbacks are appended later
(`Core.lua:54-56`). Consequence: Claret's hooks (PaintingBrush, gamemain) are installed **before** any
Claret UI exists, and ReUI's gamemain patch that defines `IsIgnoredSelection`
(`Context/sources/MainMods/ReUI/hook/lua/ui/game/gamemain.lua:5`) is already in place when Claret's
hook callback runs, because hooks execute in registration order (`Core.lua:10-15`). This is why
`rawget(module, 'IsIgnoredSelection')` at `Main.lua:121` is not nil in production (it *would* be nil
if the read happened before ReUI's patch — the code depends on that ordering, silently).

Pre-create does exactly three things: `menuKey:Initialize()`, and `AddToMenu` for the "Claret" tab
(`Main.lua:95-99`); no Maui control is created. Post-create creates the parent `Group` on
`GetFrame(0)` (`Main.lua:137-141`), the registry, the destroy hook, the `selectionSummary` feature,
flushes `pending`, starts the menu key, sets `uiReady = true`, and creates the welcome window inside
`pcall` (`Main.lua:134-181`).

**Fact — gating.** `uiReady` gates the menu toggle (`Main.lua:60`), `AppendTransportCargo`
(`Main.lua:197`) and `CreateStrategicRing` (`Main.lua:227`). `disposed` gates `RegisterFeature`
(`Main.lua:105`), `AppendTransportCargo`, `CreateStrategicRing` and `menu:Register` (`Menu.lua:35`).
`RegisterFeature` is deliberately *not* gated on `uiReady`: calls before post-create land in
`pending` (`Main.lua:115`) and are registered in `Main.lua:169-172`.

**Fact — replay.** `isReplay` reaches `TransportCargo.Create` (hard-disabled there,
`TransportCargo.lua:60`), the `AppendTransportCargo` gate and the log line only. Menu, welcome,
selection summary and strategic rings are fully active in replays; the selection hook fires there too.

**Fact — cleanup chain.** `owner.OnDestroy` is replaced at `Main.lua:148` and runs, in order:
`menuKey:Destroy()` → `menu:Destroy()` → `transportCargo:Destroy()` → `strategicRings:Destroy()` →
`registry:Destroy()` → `selectionChanged:Clear()` → `options.language.OnChanged:Remove(languageChanged)`
→ the original `OnDestroy`. Each step is correct individually; the chain has no error isolation
(COR-04).

### A.2 Public API surface (question 2)

| API | Definition | Consumer | Cleanup | Verdict |
|---|---|---|---|---|
| `RegisterFeature(id, start, option)` | `Main.lua:104-118` | Hotbuild `Main.lua:71` | `registry:Destroy` → `Lifecycle:Destroy` | Works; validation gaps (COR-03) |
| `RegisterSettingsSection(def)` | `Main.lua:192` | Hotbuild `Main.lua:76` | `menu:Destroy` → `disposed` | Correct; duplicate ids rejected in `Menu.lua:39-49` |
| `Localization` | `Main.lua:193` (module table) | Hotbuild `Main.lua:18` | module state persists | Works; `Register` ignores namespace (COR-09) |
| `IsMenuOpen()` | `Main.lua:194` → `Menu.lua:840` | Hotbuild `Main.lua:81` | — | Correct (`window ~= nil`) |
| `IsKeyCaptureActive()` | `Main.lua:195` → `Menu.lua:841` | Hotbuild `Runtime.lua` (13 references) | relies on `root.OnDestroy`→`Unbind` | Works; fragile (COR-21) |
| `AppendTransportCargo(sel)` | `Main.lua:196-225` | Hotbuild `ContextActions.lua:720` | `transportCargo:Destroy` | Behaviour correct, contract loose (COR-01, COR-06, COR-10) |
| `CreateStrategicRing(vision)` | `Main.lua:226-229` | Hotbuild `ContextActions.lua:725` | `strategicRings:Destroy` | Correct; returns `(false, reason)` |
| `GetFeatureState(id)` | `Main.lua:187-190` | **no caller** (grep over both mods) | — | Documented in README but unused, and asserts on unknown ids (COR-02, COR-18) |

**`AppendTransportCargo` — path-by-path** (the suspicious `reason, fallbackAllowed = directOk, true`
line is `Main.lua:207`). `pcall` returns `(true, …returns…)` or `(false, errorObject)`, so the four
locals mean different things per path:

| # | `AppendNext()` returns | `callOk` | `directOk` | `directMessage` | `directFallback` | Branch taken | Reachable? |
|---|---|---|---|---|---|---|---|
| A | `true, true` (`ReUICargoIndicator.lua:121`) | true | `true` | `true` | nil | first `if` → `return true` | Yes — ReUI.Construction present, append + refresh OK |
| B | `true, true, 'refresh failed'` (`ReUICargoIndicator.lua:120`) | true | `true` | `true` | `'refresh failed'` | first `if` → `WARN` + `return true` | Yes — append OK, `panel:Refresh` failed |
| C | `false, reason, true` (`Failure(reason, true)`) | true | `false` | `reason` | `true` | else → fallback | Yes — no ReUI.Construction, panel destroyed, handler/append API missing, `appended ~= true` |
| D | `false, reason, false` (`Failure(reason)`) | true | `false` | `reason` | `false` | else → `WARN`, `return false` | Yes — `pcall(append, handler)` raised (`ReUICargoIndicator.lua:112`) |
| E | *raises* | **false** | **error object** | nil | nil | `reason, fallbackAllowed = directOk, true` → fallback | Yes — module missing/broken, or any exception escaping `AppendNext` |
| F | single `true` | true | `true` | nil | nil | else → `reason=nil`, `fallbackAllowed=nil` → treated as failure | Not reachable today; latent |

**Conclusion on the flagged line.** Fact: it is *correct in intent and reachable* — it is the "bridge
threw, so use Core's own staging" path, and it is the path the smoke test exercises (the test stubs
`ReUICargoIndicator` with `Mark` only, so `AppendNext` is nil and the call raises —
`Tests/core-smoke.lua:114-117`). What is wrong is the naming and the polymorphism of the third slot:
in C/D it is `fallbackAllowed` (boolean), in B it is a *message string*, in E it is nil, and
`directOk` holds an error object in E. The hidden invariant is "an exception means no side effect
happened yet", which holds only because every call inside `AppendNext` is itself wrapped in `pcall`.
Maintainability hazard, not a live bug (COR-01/COR-10).

**`registered` pre-seed (question 3).** Fact: `registered = { probe = true, selectionSummary = true }`
(`Main.lua:101`). Consequences, verified:
* `RegisterFeature('probe', …)` returns `false, 'Feature already registered: probe'` although no such
  feature exists (`Main.lua:109`); the smoke test asserts this rejection on purpose
  (`Tests/core-smoke.lua:168`), so the reservation is intentional, not an accident.
* `GetFeatureState('probe')` → `registry:GetState('probe')` → `assert(entries[id], 'unknown feature: probe')`
  (`Registry.lua:36`) → **raises**. The two APIs disagree about whether `probe` exists.
* Consequence for third-party mods: the id `probe` is permanently unavailable and the failure message
  is misleading (it claims a duplicate registration). No such mod is known; risk is latent (COR-02).
* `selectionSummary` is pre-seeded *and* really registered (`Main.lua:165-168`), which bypasses
  `RegisterFeature`'s duplicate check by design — so `registered` and `Registry.entries` are two
  sources of truth that happen to agree only for that one id.

### A.3 Registry and Lifecycle (question 4)

`Registry.Create(report, trace)` (`Registry.lua:7-68`) holds `entries`, `order`, `bindings`,
`disposed`. `Register` asserts non-disposed, valid id and no duplicate (`Registry.lua:14-17`) and
wraps `Lifecycle.Create`. `BindOption` asserts a known entry and an unbound id, stores
`{option, callback}`, adds the callback, then immediately applies `SetEnabled(option:Get())`
(`Registry.lua:41-49`). `Destroy` walks `order` in reverse, `pcall`s the `OnChanged:Remove`, destroys
each lifecycle and drops the binding (`Registry.lua:50-64`).

`Lifecycle.Create(start, report)` (`Lifecycle.lua:7-143`) is the strongest piece of infrastructure in
the mod: a per-start `scope` with `Defer/Own/Guard/Bind/Every`, a `busy` re-entrancy flag, states
`disabled/running/error/disposed`, failure capture inside the start call
(`Lifecycle.lua:108-124`) and reverse-order cleanup with `pcall` (`Lifecycle.lua:68-78`).

Edge cases verified by reading:
* **Destroy while busy** — `SetEnabled` returns `false` when `busy` (`Lifecycle.lua:99`) but `Destroy`
  sets `disposed = true` regardless of that return (`Lifecycle.lua:139-144`). If `Destroy` is reached
  re-entrantly from inside `start` (i.e. while `busy`), the pending start still completes and marks
  the controller `running` after it was disposed, and `Clean()` never runs → controls leak
  (COR-30, Low; needs a re-entrant caller that does not exist today).
* **BindOption failure leaves the binding** — if `option.OnChanged:Add` raises (a table with `Get`
  but no `OnChanged`), the exception escapes `BindOption`, and because `RegisterFeature` set
  `registered[id] = true` *before* registering (`Main.lua:110-113`), the id can never be retried and
  the feature is never started (COR-03). If instead `Add` succeeds but `SetEnabled` reports failure,
  the binding stays and the user can retry through the toggle — acceptable.
* **`Every` timer** — the accumulator resets to `0` on fire (`Lifecycle.lua:59`), so the period drifts
  by up to one frame per tick, and the cleanup replaces `control.OnFrame` with an empty function
  (`Lifecycle.lua:52`), permanently discarding any other owner of that callback. No production caller
  uses `Every` (staging API only) → COR-27.

### A.4 Module inventory and families (questions 5, 6, 7)

| Family | Files (lines) | Responsibility | Reachable from production? |
|---|---|---|---|
| Bootstrap | `Main.lua` 232, `Options.lua` 9 | composition root, API table | yes |
| Infra | `Registry` 68, `Lifecycle` 147, `Localization` 157, `LocalizationStrings` 108, `Theme` 103 | feature registry, lifecycle, EN/RU strings, visual tokens | yes |
| Shell UI | `Menu` 855, `MenuKey` 170, `Welcome` 287 | F10 window, key bind, first-run window | yes |
| Game integration | `TransportCargo` 127, `ReUICargoIndicator` 117, `StrategicRings` 458, `SelectionSummary` 61 | cargo staging, ReUI bridge, range rings, selection panel | yes |
| Staging — construction | `ConstructionController` 465, `ConstructionActions` 433, `ConstructionItemsView` 409, `ConstructionTemplateActions` 387, `ConstructionEnhancementActions` 386, `ConstructionEngineAdapters` 373, `ConstructionPanel` 368, `ConstructionTemplates` 261, `ConstructionEnhancements` 259, `ConstructionPanelShell` 258, `ConstructionCargoView` 257, `ConstructionFacade` 192, `ConstructionSelection` 178, `CargoSelection` 170, `ConstructionGridModel` 156, `ConstructionChoices` 137, `ConstructionQueue` 89 | see layering below | **no** |
| Staging — orders | `OrdersPanelModel` 295, `OrdersPanelShell` 271, `OrdersPanel` 250, `OrdersOverrides` 177, `OrdersActions` 166, `OrdersCatalog` 163 | order-panel slice | **no** |
| Staging — multifunction | `MultifunctionShell` 234, `MultifunctionController` 199 | MFD cluster | **no** |
| Staging — selection | `SelectionIgnoreScope` 132, `SelectionIgnoreHook` 70 | lease-based `SetIgnoreSelection` wrapper | **no** |

**Construction layering (coherent, 6 levels).** Pure models (`Choices`, `GridModel`, `Queue`,
`Selection`, `Enhancements`, `Templates`) → views (`ItemsView`, `CargoView`, `PanelShell`) →
dispatchers (`Actions`, `EnhancementActions`, `TemplateActions`) → assembly (`Panel`) →
orchestration (`Controller`) → engine binding (`EngineAdapters`) → compatibility (`Facade`).
Every module takes injected `ops`/`dependencies`/`modules` tables and defaults to `import(...)` only
through a local `Resolve`; none installs a hook, none touches `_G` state. **Fact:** no module in the
family imports another family module by path at file scope, so load cost is zero until wired.

**Orders/Multifunction vs Construction — same shape, divergent details.** `OrdersPanel.Create`
re-implements the ConstructionPanel pattern (`LoadModule` vs `Resolve`, `CopyDense` vs `CopyArray`,
`AddDiagnostics` vs inline error merging), and `OrdersPanelShell`/`MultifunctionShell` each carry their
own `Resolve` copy. `OrdersPanelModel`/`OrdersCatalog`/`OrdersOverrides` are genuinely independent
(static native metadata + a deterministic override resolver, `OrdersOverrides.lua:1-8`), so this is
copy-paste of the *assembly idiom*, not of logic (COR-13).

**Selection family.** `SelectionIgnoreScope` is a small, careful lease manager (`Desired =
externalRequested or leaseCount > 0`, `SelectionIgnoreScope.lua:30-32`) with explicit
`synchronized` bookkeeping. `SelectionIgnoreHook` installs it by replacing a foreign module's
`SetIgnoreSelection` and refuses to detach if another owner replaced the wrapper
(`SelectionIgnoreHook.lua:57-64`). Neither is installed anywhere in production, so
`Main.lua:121`'s `rawget(module, 'IsIgnoredSelection')` is the *only* consumer of this concept and it
reads ReUI's own global, not this manager. That is the intended separation (the hook is for stock
`selection.lua`, ReUI's is for its own path) but it means two ignore mechanisms would coexist after
wiring — worth an explicit decision (COR-17).

**Docs vs code.** `Context/quick-reference.md` and `Context/menu-rules.md` describe the menu, the
`ClaretCore_OpenMenu` bind, `RegisterSettingsSection`, immediate saving and the capture rules — all
match the code. Divergences found:
* `Context/quick-reference.md` records the Core 0.9.0 decision "all menu sections use the same large
  size (1368×1320 before overall scaling)"; `Theme.Metrics` is now `panelWidth=1128, panelHeight=1110`
  (`Theme.lua:38-39`) and the Core section is compact (`corePanelWidth=552, corePanelHeight=408`,
  `Menu.lua:446-447`). The doc note is stale; the code is the reference.
* `Context/menu-rules.md` says "only the Hotbuild keyboard page may reduce its panel height"; the code
  lets any `inline` section call `layout.setHeight` (`Menu.lua:728-730`), so the constraint is by
  convention, not enforced.
* Neither doc mentions the construction/orders/multifunction staging library, and
  `ClaretCore/README.md` only documents the runtime features. So the 70 % of the code base is
  undocumented by design documents (COR-12).

---

## 1. Confirmed defects

### COR-01 — `AppendTransportCargo` ignores its `selection` argument on the primary path
* **Severity:** Medium
* **Category:** Correctness
* **Location:** `ClaretCore/Main.lua:196-225` (`AppendTransportCargo`)
* **Problem:** The public parameter `selection` is never read before the fallback branch; the primary
  path appends whatever ReUI's live `TransportCargo` handler considers next, using ReUI's own
  selection, not the caller's captured one. The two paths therefore validate different things.
* **Evidence:**
  ```lua
  AppendTransportCargo = function(selection)
      if isReplay or not uiReady or disposed then return false end
      local callOk, directOk, directMessage, directFallback = pcall(function()
          return import('/mods/ClaretCore/modules/ReUICargoIndicator.lua').AppendNext()
      end)
  ```
  and only later `local okFallback, unit, index, cargo = transportCargo:Append(selection)` (`Main.lua:216`).
  `TransportCargo:Append` validates `SameMembers(requested, current)` against `GetSelectedUnits()`
  (`TransportCargo.lua:64-73`); `AppendNext` has no such check.
* **Impact:** Hotbuild passes a selection captured at key-dispatch time (`ContextActions.lua:720`).
  If the live selection differs (unit died, selection changed between capture and execution), the
  primary path reports success while staging a passenger for a different selection. The caller cannot
  detect the mismatch.
* **Recommendation:** Validate `selection` against the live selection (or against ReUI's handler
  selection) before calling `AppendNext`, or document the parameter as advisory and remove it.
* **Risk of the fix:** Low — an extra equality check on a user-initiated action.
* **Confidence:** High (code) / Medium (user-visible frequency).

### COR-02 — `probe` is a phantom feature: `RegisterFeature` says "already registered", `GetFeatureState` asserts
* **Severity:** Medium
* **Category:** Architecture / API
* **Location:** `ClaretCore/Main.lua:101`, `Main.lua:109`, `Main.lua:187-190`, `Registry.lua:35-38`
* **Problem:** `registered` is pre-seeded with `probe`, but no `probe` entry is ever created in the
  registry, so the two APIs give contradictory answers for the same id. `GetFeatureState` has no
  unknown-id path — it asserts.
* **Evidence:**
  ```lua
  local registered = { probe = true, selectionSummary = true }        -- Main.lua:101
  if registered[id] then return false, 'Feature already registered: ' .. id end  -- Main.lua:109
  GetFeatureState = function(id)
      if not registry then return 'unavailable' end
      return registry:GetState(id)
  end                                                                 -- Main.lua:187-190
  assert(entries[id], 'unknown feature: ' .. tostring(id))            -- Registry.lua:36
  ```
* **Impact:** (a) any consumer calling `GetFeatureState('probe')` gets a Lua error instead of the
  documented state string (README: "returns the registered feature's state"); (b) a third-party mod
  that wants the id `probe` is refused with a misleading "already registered" message; (c)
  `GetFeatureState('anything')` raises instead of returning an unknown state. Today no caller exists
  (grep over `ClaretCore/` and `ClaretHotbuild/`), so the impact is latent.
* **Recommendation:** Single source of truth: drop the `probe` key, or register a real no-op feature;
  make `GetState` return `'unknown'` and have `GetFeatureState` return it instead of asserting.
* **Risk of the fix:** Low; the smoke test asserts the current rejection
  (`Tests/core-smoke.lua:168`) and would need updating.
* **Confidence:** High.

### COR-03 — `RegisterFeature` can leave a half-registered, unretryable feature
* **Severity:** Medium
* **Category:** Correctness
* **Location:** `ClaretCore/Main.lua:104-118`, `Registry.lua:41-49`
* **Problem:** The only validation is `type(id)`, `type(start)` and `not option`. `option` is used as
  `option.OnChanged:Add(callback)` and `option:Get()` with no shape check and no `pcall`. The id is
  marked `registered` *before* the registry calls, so any raise inside `Register`/`BindOption` leaves
  the id permanently taken, the entry present but unbound and never enabled.
* **Evidence:**
  ```lua
  if type(id) ~= 'string' or id == '' or type(start) ~= 'function' or not option then
      return false, 'Feature ID, start function and enabled option required' end
  if registered[id] then return false, 'Feature already registered: ' .. id end
  registered[id] = true
  if registry then
      registry:Register(id, start)
      registry:BindOption(id, option)
  ```
* **Impact:** A consumer passing a plain `{Get=…}` table (or an option from a future ReUI version
  without `OnChanged`) gets an unhandled Lua error out of its own `Main`, and Core keeps a feature
  that can never start even if the caller retries with a correct option.
* **Recommendation:** Validate `type(option.OnChanged) == 'table' and type(option.OnChanged.Add) == 'function'
  and type(option.Get) == 'function'`; wrap the register/bind pair in `pcall` and roll back
  `registered[id]` (and destroy the entry) on failure.
* **Risk of the fix:** Low; behaviour only changes on inputs that currently crash.
* **Confidence:** High.

### COR-04 — The dispose chain has no error isolation
* **Severity:** Medium
* **Category:** Correctness
* **Location:** `ClaretCore/Main.lua:148-163`
* **Problem:** Every teardown step is a bare call. If any `Destroy` raises (a ReUI child control
  destroyed twice, an inline editor throwing during `OnDestroy`, a foreign hook gone), the remaining
  steps are skipped: the registry keeps bound options, `selectionChanged` keeps subscribers and
  `options.language.OnChanged` keeps `languageChanged`.
* **Evidence:**
  ```lua
  owner.OnDestroy = function(self)
      disposed = true
      uiReady = false
      menuKey:Destroy()
      menu:Destroy()
      transportCargo:Destroy()
      if strategicRings then strategicRings:Destroy(); strategicRings = nil end
      if registry then
          registry:Destroy()
          registry = nil
      end
      selectionChanged:Clear()
      options.language.OnChanged:Remove(languageChanged)
  ```
  Compare the standard the staging code holds itself to: `ConstructionPanel.lua:302-334` `pcall`s
  *every* child destroy and keeps a `destroying` re-entrancy flag. Core's own production path is
  weaker than its unwired library.
* **Impact:** A leaked `OnChanged` callback that fires into destroyed controls after a session ends;
  a registry that cannot be re-created; error spam instead of a clean shutdown. Whether the leaked
  state outlives the UI depends on whether the Lua state is reused (COR-22).
* **Recommendation:** Wrap each step (`local function Step(fn) local ok, err = pcall(fn); if not ok then WARN(...) end end`)
  or reuse `Lifecycle`-style guarded cleanup; remove the language handler first.
* **Risk of the fix:** Low — pure teardown, no user-visible behaviour change on the happy path.
* **Confidence:** High (structure) / Medium (user-visible impact).

### COR-05 — Pre-create callback is unguarded and ordered so a keymap failure removes the only settings entry point
* **Severity:** Medium
* **Category:** Correctness / UI
* **Location:** `ClaretCore/Main.lua:94-100`, `MenuKey.lua:148-166`
* **Problem:** `menuKey:Initialize()` runs before `AddToMenu` in the same callback and is not wrapped.
  `Initialize` touches three engine modules (`keymapper`, `prefs`, `keydescriptions`) and calls
  `Mapper.SetUserKeyAction`, `SetUserKeyMapping`, `SavePreferences`.
* **Evidence:**
  ```lua
  ReUI.Core.OnPreCreateUI(function()
      menuKey:Initialize()
      import('/lua/ui/game/tabs.lua').AddToMenu {
          action = 'Claret.Settings', label = 'Claret', tooltip = Localization.Text('core.settings.tooltip'),
          func = function() menu:Open() end,
      }
  end)
  ```
* **Impact:** Any raise inside `Initialize` (keymapper API change, profile write failure outside its
  own `pcall`) aborts the rest of that pre-create callback, so the F10 → Claret tab is never added:
  the user loses the only in-game entry to settings. ReUI only logs the error
  (`Loader.lua:318-324` wraps each pre-create callback in `_pcall` and `WARN`s), so there is no user-facing
  signal and no fallback path.
* **Recommendation:** Wrap `Initialize` in `pcall` (log and continue), and add the tab before it.
* **Risk of the fix:** Low.
* **Confidence:** High (ordering fact) / Medium (likelihood).

### COR-06 — Two independent cargo cursors with no cross-reset
* **Severity:** Low
* **Category:** Correctness
* **Location:** `ClaretCore/Main.lua:201-204` vs `Main.lua:216`, `TransportCargo.lua:97-108`
* **Problem:** The primary path stages a passenger through ReUI and returns without touching
  `transportCargo`'s cached `transports/cargo/nextIndex`. If a later press falls back (ReUI error,
  panel destroyed), the fallback resumes from its own stale cursor.
* **Evidence:**
  ```lua
  if not SameMembers(transports, requested) or not SameMembers(cargo, liveCargo) then
      transports = requested
      cargo = liveCargo
      nextIndex = FirstUnqueued(cargo)
  end
  if not nextIndex then nextIndex = FirstUnqueued(cargo) end
  ```
  (`TransportCargo.lua:97-102`) — the cache is keyed only on transport/cargo identity, which a ReUI
  append does not change, and `HasUnloadQueued` only sees unload orders, not the selective-unload list.
* **Impact:** A passenger already staged through ReUI can be staged again into FAF's shared
  extra-select list, i.e. a duplicate entry, when the two paths interleave.
* **Recommendation:** Call `transportCargo:Reset()` after a successful direct append (it is cheap), or
  have both paths share one cursor.
* **Risk of the fix:** Low; resetting only discards cached indices.
* **Confidence:** Medium (logic traced, not reproduced in game).

### COR-07 — Menu key description is localized once and never refreshed
* **Severity:** Low
* **Category:** UI
* **Location:** `ClaretCore/modules/MenuKey.lua:148-152`, `Main.lua:35-43`
* **Problem:** `descriptions[actionId] = T('core.menu_key.s008')` runs in `Initialize` (pre-create).
  `languageChanged` only calls `Localization.SetLanguage`; nothing rewrites the keybinding
  description.
* **Evidence:** `descriptions[actionId]=T('core.menu_key.s008')` (`MenuKey.lua:150`) with
  `languageChanged = function() ForkThread(function() WaitFrames(1) Localization.SetLanguage(...) end) end`
  (`Main.lua:35-42`).
* **Impact:** After switching EN↔RU, FAF's keybindings dialog shows "Open the Claret menu" in the old
  language until the game restarts.
* **Recommendation:** Re-assign the description from the same `languageChanged` path (or register a
  `Localization.Subscribe`).
* **Risk of the fix:** Low.
* **Confidence:** High.

### COR-08 — `SelectionSummary` indexes `GetBlueprint()` without a guard
* **Severity:** Low
* **Category:** Correctness
* **Location:** `ClaretCore/modules/SelectionSummary.lua:37-52`
* **Problem:** The refresh loop runs inside `scope:Guard`, so a single bad unit raises, `Lifecycle:Fail`
  fires, and the whole feature is disabled for the session instead of skipping one unit.
* **Evidence:** `local id = unit:GetBlueprint().BlueprintId` (`SelectionSummary.lua:44`) — no `nil`
  check, unlike the defensive style used everywhere else in Core.
* **Impact:** Loss of the selection summary until the option is toggled off/on; `WARN` in the log only.
* **Recommendation:** `local blueprint = unit.GetBlueprint and unit:GetBlueprint(); local id = blueprint and blueprint.BlueprintId`.
* **Risk of the fix:** None.
* **Confidence:** High (code) / Low (trigger frequency — `GetBlueprint` normally returns a table).

### COR-09 — `Localization.Register` accepts a namespace and ignores it
* **Severity:** Low
* **Category:** Maintainability
* **Location:** `ClaretCore/modules/Localization.lua:121-133`
* **Problem:** `namespace` is validated but never used; keys go into the single shared
  `dictionaries[en|ru]` table. Two mods registering the same key silently overwrite each other and
  there is no unregister.
* **Evidence:** `function Localization.Register(namespace, tables)` … `dictionaries[language][key] = value`.
  Hotbuild calls it with `'hotbuild'` (`ClaretHotbuild/Main.lua:18`) and relies on prefixed keys.
* **Impact:** The API implies isolation it does not provide; a future third-party Claret mod can
  overwrite Core or Hotbuild strings with no diagnostic.
* **Recommendation:** Prefix keys with `namespace .. '.'` on insert (and on lookup), or drop the
  parameter and document global keys.
* **Risk of the fix:** Medium — changing the key format would break existing `Text('…')` literals;
  prefixing inside `Register` only is safe if all consumers keep passing prefixed keys.
* **Confidence:** High.

### COR-10 — `AppendTransportCargo` returns different arities per path
* **Severity:** Low
* **Category:** Correctness / API
* **Location:** `ClaretCore/Main.lua:201-204` vs `Main.lua:222`
* **Problem:** Primary path `return true`; fallback `return true, unit, index`. Hotbuild's dispatcher
  reads `local result,message = …` (`ClaretHotbuild/modules/Runtime.lua:61-63`) and treats the second
  value as an error message.
* **Evidence:** `if callOk and directOk and directMessage then … return true end` vs
  `return true, unit, index`.
* **Impact:** On the fallback path, `message` becomes a unit object; it is only logged when `result`
  is falsy, so today it is invisible. Any consumer that starts using value 2 gets a unit, not a reason.
* **Recommendation:** Return a fixed tuple (`true, unit, index`) on both paths (the direct path can
  return the unit it marked, which `Mark` already knows).
* **Risk of the fix:** Low.
* **Confidence:** High.

### COR-11 — The only integration test of `Main.lua` does not run; the menu test asserts removed geometry
* **Severity:** Medium
* **Category:** Testing
* **Location:** `Tests/core-smoke.lua:137`, `Tests/claret-menu.lua:166-168`
* **Problem:** `core-smoke.lua` fails before reaching any assertion because its `import` shim has no
  mapping for `/lua/ui/game/rangeoverlayparams.lua` (imported at `StrategicRings.lua:3`). The test that
  covers bootstrap, `AppendTransportCargo`, registry state and session destruction therefore never
  executes. `claret-menu.lua` fails at "settings drag header exists": it looks for a 1128-wide panel
  and a 1056×72 header, but Core's section is now compact (552×408, header `panelWidth-72` = 480).
* **Evidence:**
  ```
  FAIL: core-smoke.lua
  Tests/core-smoke.lua:137: cannot open ../lua/ui/game/rangeoverlayparams.lua: ENOENT
  FAIL: claret-menu.lua
  Tests/claret-menu.lua:168: settings drag header exists
  ```
  Test code: `if c.parent==panel and c.Width()==1056 and c.Height()==72 then panelHeader=c end`.
* **Impact:** No automated coverage of the bootstrap/dispose path; the two failures look like product
  regressions and mask real ones. The `rangeoverlayparams` file *does* exist in the installed game
  (`findstr` over `lua.nx2` finds the path), so the smoke failure is a harness gap, not a game gap.
* **Recommendation:** Add the stub to the harness (`return { RangeOverlayParams = {} }` is enough for
  the module to load); update the menu test to the compact geometry.
* **Risk of the fix:** Low, test-only.
* **Confidence:** High.

---

## 2. Strongly supported architectural problems

### COR-12 — 70 % of the code is an unreachable parallel implementation of the construction/orders HUD

**Decision (2026-11-18, user):** this is intentionally deferred functionality — a planned replacement for the ReUI construction/orders/MFD HUD, implemented ahead of wiring. The modules and their tests are preserved; integration is out of the current refactoring scope. The finding is informational, not a defect to remove.
* **Severity:** High
* **Category:** Architecture
* **Location:** `ClaretCore/modules/Construction*`, `Orders*`, `Multifunction*`, `SelectionIgnore*`,
  `CargoSelection.lua` (27 files, 6 735 lines)
* **Problem:** No production file imports any of them and no `RegisterFeature` call exists; only the
  31 of the 66 test files load them (and nothing else does). They implement a full alternative construction panel, orders panel and MFD
  cluster — the exact surfaces ReUI.Construction already owns, while `Context/quick-reference.md` and
  `ClaretCore/README.md` describe Core as *not* requiring ReUI.Construction.
* **Evidence:** dependency scan — the only intra-Core imports in those files point at `/lua/...` game
  modules; `ClaretCore/README.md` contains no mention of "Construction", "Orders" or "Multifunction"
  (grep), while `Context/quick-reference.md` lists ReUI.Construction as an optional recommendation
  only. `Main.lua` imports 9 Core modules and 2 game modules; none belongs to these families.
* **Impact:** Two competing owners for the same HUD with no recorded decision; every future change to
  the construction UI has an ambiguous home; reviewers cannot tell intended from abandoned code. Cost
  is maintenance and misdirection, not FPS (`import` is lazy, so the files never load in game).
* **Recommendation:** Record an explicit decision in `Stage/`: either wire the family behind a
  registered feature (and make it mutually exclusive with ReUI.Construction), or move it out of the
  shipping mod folder. Until then mark it in the README as unwired.
* **Risk of the fix:** Low for documentation; High for wiring (see COR-14, COR-19).
* **Confidence:** High.

### COR-13 — The staging stack re-implements 15 private helpers across 10 files
* **Severity:** Medium
* **Category:** Maintainability
* **Location:** `ConstructionController.lua:4,12`, `ConstructionChoices.lua:4`, `CargoSelection.lua:4`,
  `ConstructionActions.lua:13,65`, `ConstructionEnhancementActions.lua` (top block),
  `ConstructionTemplateActions.lua` (top block), `ConstructionFacade.lua:7`, `ConstructionPanel.lua:5`,
  `ConstructionPanelShell.lua:5`, `OrdersPanelShell.lua:9`, `MultifunctionShell.lua:9`,
  `TransportCargo.lua` (top block)
* **Problem:** `CopyArray` ×3, `CopyQueue` ×1, `CopyUnits`/`CopyWithType` variants, `IsArray` ×3,
  `Call` ×3, `Resolve` ×4 (plus `ResolveFactory`, `LoadModule`), `Report` ×3, and two spellings of the
  same set comparison (`SameMembers` in `TransportCargo.lua`, `SameIdentitySet` in
  `ConstructionController.lua`).
* **Evidence:** definition counts per file: `CargoSelection:CopyArray`, `ConstructionChoices:CopyArray`,
  `ConstructionController:CopyArray,CopyQueue,SameIdentitySet,Report`,
  `ConstructionActions:IsArray,Call`, `ConstructionEnhancementActions:CopyArray,IsArray,Resolve,Call`,
  `ConstructionTemplateActions:IsArray,Call`, `ConstructionFacade:Call,Report`,
  `ConstructionPanel:Resolve,Report`, `ConstructionPanelShell:ResolveFactory`,
  `OrdersPanelShell:Resolve`, `MultifunctionShell:Resolve`, `TransportCargo:SameMembers`.
* **Impact:** Divergence is already visible (`SameMembers` returns `true` for two empty tables;
  `SameIdentitySet` returns `false` for different lengths only — same result, different code paths).
  When the family is wired, a fix applied to one copy will not reach the others.
* **Recommendation:** Add one `modules/Support.lua` (or a `local Support = import(...)` per file) with
  `CopyArray`, `SameMembers`, `Call`, `Resolve`, `Report` and use it in both families.
* **Risk of the fix:** Low; mechanical, covered by the existing 31 unit tests.
* **Confidence:** High.

### COR-14 — Three ownership models for one UI surface
* **Severity:** Medium
* **Category:** Architecture
* **Location:** `ConstructionPanelShell.lua:12-40`, `ConstructionFacade.lua:54-67/174-190`,
  `ConstructionCargoView.lua:143-195`
* **Problem:** The panel shell *owns* a control tree; the facade *replaces method fields on a foreign
  control* (`OnSelectionChanged`, `Update`, `Refresh`, `GetCurrentTechTab`, `GetHandler`, `Show`,
  `Hide`, `OnDestroy`, `Destroy`); the cargo view *monkey-patches a caller-owned `SpecialGrid`*
  (`grid.CreateElement`, `grid.SetControlToType`, private `grid._vertical`, and cell `OnClick` via
  `cell._claretBaseOnClick`). Restores are conditional on identity:
* **Evidence:**
  ```lua
  local function Install(name, callback)
      previous[name] = root[name]
      installed[name] = callback
      root[name] = callback
  end
  local function Restore()
      for name, callback in pairs(installed) do
          if root[name] == callback then root[name] = previous[name] end
  ```
  and `if grid.CreateElement == cargoCreateElement then grid.CreateElement = baseCreateElement end`
  (`ConstructionCargoView.lua:181-183`).
* **Impact:** A grid can be patched by the cargo view while its owner is patched by the facade, and
  restore is silently skipped when a third party patched in between — leaving Claret's renderer or
  handler installed after teardown. Ownership of one control is spread over three modules with no
  single teardown authority.
* **Recommendation:** Pick one owner (the shell), expose `render`/`dispatch` callbacks to it, and drop
  the facade's method replacement in favour of registering handlers explicitly.
* **Risk of the fix:** Medium — the facade exists to satisfy ReUI.Construction's dispatch surface;
  removing it changes the integration contract.
* **Confidence:** High for the code shape / Medium for the compatibility outcome.

### COR-15 — `Theme` and `MenuKey.Open` are de-facto public modules that the API table does not expose
* **Severity:** Medium
* **Category:** Architecture
* **Location:** `ClaretCore/modules/Theme.lua`, `ClaretCore/modules/MenuKey.lua:16-20`, consumers in
  `ClaretHotbuild/`
* **Problem:** The documented integration point is `ReUI.ClaretCore.*`, but Hotbuild imports
  `/mods/ClaretCore/modules/Theme.lua` by path in seven files and hooks `MenuKey.Open` directly.
  Neither is versioned or exposed through the API table.
* **Evidence:** `Theme` imports: `ContextEditor.lua:57`, `CycleMenu.lua:3`, `Editor.lua:166`,
  `KeyboardEditor.lua:112`, `Navigator.lua:10`, `QuickRepeatMenu.lua:5`, `QuickRepeatSettings.lua:6`;
  `ReUI.Core.Hook('/mods/ClaretCore/modules/MenuKey.lua', 'Open', …)` in `ClaretHotbuild/Main.lua:64`.
* **Impact:** Renaming or moving `Theme.lua`/`MenuKey.Open` silently breaks Hotbuild at load or at
  keypress; there is no dependency check that would catch it (Hotbuild requires `ClaretCore >= 0.10.5`,
  not a module path).
* **Recommendation:** Expose `Theme` (and a `MenuCallbacks`/`OnMenuOpened` event) on the API table and
  migrate Hotbuild's imports; keep the module files as implementation details.
* **Risk of the fix:** Low code risk, but it is a cross-mod change and needs the user's agreement.
* **Confidence:** High.

### COR-16 — `Main.lua` is a 232-line composition root with nine unrelated concerns
* **Severity:** Medium
* **Category:** Architecture
* **Location:** `ClaretCore/Main.lua:15-221`
* **Problem:** One function owns option migration, localization bootstrap, cargo service, strategic
  rings + painting hook, menu key, menu construction, two feature registrations, the gamemain hook,
  the parent control, the dispose chain, the welcome window and the public API. The dispose order is
  an inline list with no counterpart in any module.
* **Evidence:** `Main.lua:15` `function Main(isReplay)` … `Main.lua:231` `end`; 12 `import` calls and
  9 distinct subsystems inside one body; the only structural helper is the local `RegisterFeature`.
* **Impact:** Every new feature edits the same 200-line function; review diffs are noisy; the dispose
  list can drift from the creation list (it already has: `strategicRings` is created at line 44 but
  destroyed behind a nil check at line 154 while `transportCargo` is unguarded).
* **Recommendation:** Extract `Session.Create(isReplay)` returning `{api, dispose}` with creation and
  disposal in one table-driven pair; keep `Main` to `ReUI.Require` + `Session.Create`.
* **Risk of the fix:** Medium — touches every registration path; needs an in-game check (menu, key
  capture, cargo, rings) and the smoke test fixed first (COR-11).
* **Confidence:** High.

### COR-17 — Two opposite-direction ReUI bridges, neither connected to the other
* **Severity:** Medium
* **Category:** Architecture
* **Location:** `ReUICargoIndicator.lua` (Core → ReUI) and `ConstructionFacade.lua` (ReUI → Core)
* **Problem:** `ReUICargoIndicator` reaches into ReUI's live panel to *push* a mark; `ConstructionFacade`
  patches a control so ReUI's dispatch *pulls* into a Claret controller. Only the first is wired; the
  second belongs to the unreachable family. They model the same relationship from opposite sides and
  share no adapter.
* **Evidence:** `AppendNext` obtains `panel:GetHandler('TransportCargo')` and calls
  `handler.AppendNextUnitForDrop` (`ReUICargoIndicator.lua:106-116`); the facade installs
  `facade.handlers.TransportCargo.AppendNextUnitForDrop` that calls `controller:AppendCargo`
  (`ConstructionFacade.lua:139-148`).
* **Impact:** If the construction family is ever wired, Core will hold both a push and a pull path to
  the same ReUI handler; the ownership question (who appends) is unanswered in code.
* **Recommendation:** Decide per feature whether Core is a client of ReUI.Construction or its
  replacement, and keep exactly one bridge per direction.
* **Risk of the fix:** Design-level; no code change until the wiring decision (COR-12).
* **Confidence:** High.

### COR-18 — Dead or vestigial API surface
* **Severity:** Low
* **Category:** Maintainability
* **Location:** `Main.lua:187`, `Localization.lua:53/80/84/147`, `Theme.lua:44`, `Welcome.lua:11`
* **Problem:** Several exported names have no production caller.
* **Evidence:** grep over `ClaretCore/` + `ClaretHotbuild/`:
  * `GetFeatureState` — only its definition and the README;
  * `Localization.GetPreference`, `GetGameLanguage`, `DetectGameLanguage`, `Validate` — no caller
    outside tests (Hotbuild uses `SearchText`/`Fold`/`Register`/`Text`);
  * `Theme.FactionIcons` — the table is never read; `Theme.FactionIcon()` builds its path itself
    (`Theme.lua:55-63`), and the 24/32/48 DDS files do exist (`textures/factions/`);
  * `Welcome.ShouldShowFontBlock()` always returns `true` (`Welcome.lua:12-14`), making the
    `showFontBlock and 836 or 604` branch at `Welcome.lua:71` dead.
* **Impact:** Readers cannot tell supported API from leftovers; a future removal will look like a
  breaking change.
* **Recommendation:** Either mark these as public API in the README or delete them; for
  `ShouldShowFontBlock`, keep the function but document that it is intentionally constant
  (`Context/menu-rules.md` requires the Nunito block to always show).
* **Risk of the fix:** Low.
* **Confidence:** High.

---

## 3. Potential risks requiring validation

### COR-19 — `ReUICargoIndicator` depends on ReUI.Construction private internals
* **Severity:** Medium
* **Category:** Compatibility
* **Location:** `ClaretCore/modules/ReUICargoIndicator.lua:86-130`
* **Problem:** The bridge assumes `ReUI.UI.Global.Construction`, `panel:GetHandler('TransportCargo')`,
  `handler._context` (underscore field), `context:IsActive/SetCargo/MarkUnit`, `context.cargoUnits`
  and `handler.AppendNextUnitForDrop` all exist with these exact names. None of that is present in the
  project's ReUI reference copy (`Context/reui-decompiled/` has `ReUI.Construction.Templates` only),
  so it cannot be verified here. The installed ReUI.Construction version is also not in the inventory.
* **Evidence:** `local okContext, context = Read(handler, '_context')` (`:49`) and
  `local okAppend, append = Read(handler, 'AppendNextUnitForDrop')` (`:106`), each guarded by `pcall`
  and each degrading to `Failure(..., true)` → Core's own fallback.
* **Impact:** If any name differs, the "direct" path is permanently dead: every append then costs two
  `pcall`s, a failed `import` lookup and a `WARN`, before falling back. Functionality survives; the
  log fills with warnings and the user sees `TransportCargo`'s own feedback sound twice per press?
  (No — the fallback plays one sound; `AppendNext` plays none.)
* **Recommendation:** Verify once in game with `probeEnabled = true` and a transport selected: expect
  no `transport cargo append failed` warning on a successful press. If warnings appear, pin the field
  names against the installed ReUI.Construction and add a one-time capability check with a cached
  result instead of re-probing per press.
* **Risk of the fix:** Low (bridge only).
* **Confidence:** High that the dependency is private; **Unknown** whether it matches the installed
  version — needs one in-game press with the log open.

### COR-20 — Strategic rings accumulate without bound and redraw every frame
* **Severity:** Medium
* **Category:** Performance
* **Location:** `ClaretCore/modules/StrategicRings.lua:205`, `:258-268`, `:280-313`, `:418-435`
* **Problem:** Every `CreateHover` may add rings that are never expired (only the Alt+RMB brush removes
  them, `:404-419`), and the renderer runs with `OnRender = true`, iterating all live rings each frame.
  A single sphere ring issues `8` circles plus `6 × 20` line segments (`drawSphere`, `:215-255`);
  merged circle arcs can add hundreds of segments (`EnsureGeometry`, `:172-193`).
* **Evidence:** `renderer = {worldview = view, OnRender = true}` (`:205`);
  `function renderer:Render() EnsureGeometry(); for _, ring in ipairs(rings) do …` (`:258-260`);
  `table.insert(rings, {…})` inside `Add` (`:280-313`) with no cap; `DeleteAtBrush` (`:418-435`) is the only removal.
* **Impact:** Cost grows with the number of hovered structures in a match (a player who rings 40 units
  pays 40 ring draws per frame forever). This is the only Core feature whose per-frame cost scales
  with user history rather than with current state.
* **Recommendation:** Cap the ring list (e.g. per group and total), drop rings whose group unit died
  or is off-screen, and consider drawing only when the world view is visible. Measure with the user's
  method (`Context/performance-hotspots.md`) before optimizing further.
* **Risk of the fix:** Low–Medium (changes a feature the user relies on; needs an in-game check).
* **Confidence:** High for the mechanism / **Unknown** for measured impact (no in-game numbers).

### COR-21 — `IsKeyCaptureActive` depends on the destroy order
* **Severity:** Low
* **Category:** Correctness / Compatibility
* **Location:** `ClaretCore/modules/Menu.lua:104-115`, `:841`, `:849-853`
* **Problem:** `capturing` is only cleared by `CancelCapture`, which the teardown reaches through
  `menu:Destroy()` → `window:Destroy()` → `root.OnDestroy` → `Unbind()` → `CancelCapture(true)`. If the
  window is gone but `capturing` is still true (a destroy path that skips `root.OnDestroy`, or a
  future refactor), Hotbuild blocks every hotkey because `Runtime` treats capture as "user is typing".
* **Evidence:** `function menu:Destroy() disposed=true; if window then window:Destroy() end; sections,ids={},{} end`
  (`:849-853`) — no explicit `capturing = false`; `function menu:IsKeyCaptureActive() return capturing end`.
* **Impact:** All Hotbuild keys dead for the rest of the session, with no visible cause.
* **Recommendation:** Set `capturing = false` and drop `state.capture` directly in `menu:Destroy`.
* **Risk of the fix:** None.
* **Confidence:** High for the coupling / Low for the trigger.

### COR-22 — Impact of the unguarded dispose chain depends on an unknown: does the Lua state survive UI teardown?
* **Severity:** Low
* **Category:** Correctness
* **Location:** `ClaretCore/Main.lua:148-163`
* **Problem:** COR-04's leak only matters if ReUI options / the Claret module tables outlive the UI
  session. In a normal FAF flow the UI Lua state is discarded when returning to the main menu, which
  would make the leak invisible. I did not verify the FAF lifecycle here, and the mod is loaded again
  from scratch on the next session either way.
* **Evidence:** No test covers it (`core-smoke.lua` is the only candidate and it does not run —
  COR-11). `Lifecycle` and `Registry` are per-session objects created in `OnPostCreateUI`.
* **Impact:** If the state is reused (UI reload, mod reload, ReUI re-init), leaked `OnChanged`
  handlers and a stale registry would fire into destroyed controls.
* **Recommendation:** Fix COR-04 regardless (cheap), and record the lifecycle fact in
  `Context/tech-findings.md` when verified.
* **Risk of the fix:** None.
* **Confidence:** **Unknown** — explicitly listed as unverified.

### COR-23 — `Menu` rebuilds its whole content on every scroll step
* **Severity:** Low
* **Category:** Performance / UI
* **Location:** `ClaretCore/modules/Menu.lua:442-620` (`state.Render`), `:483-486` (`ScrollSetTop`)
* **Problem:** `ScrollSetTop` calls `state.Render()`, which destroys `state.content`, recreates every
  visible row, re-adds `option.OnChanged` bindings and re-creates scrollbar state. Scrolling one notch
  therefore allocates a full row set.
* **Evidence:** `function state.panel:ScrollSetTop(axis,value) … if nextTop~=state.contentTop then state.contentTop=nextTop; state.Render() end end`;
  `state.Render=function() Unbind(); Focus(nil); state.contentItems={}; if state.content then state.content:Destroy() end …`.
* **Impact:** Allocation churn and input latency while scrolling; today only two sections exist and
  Core's compact panel has no long list, so the practical cost is small. It becomes relevant when
  Hotbuild's inline editor grows the section list.
* **Recommendation:** Move only the rows that cross the viewport boundary, or reuse row controls and
  re-bind their option. Keep as a follow-up, not a fix now.
* **Risk of the fix:** Medium (UI regression risk in the menu the user validates by hand).
* **Confidence:** High for the mechanism / **Unknown** for perceptible cost.

---

## 4. Optional improvements

### COR-24 — Make disposal a table of guarded steps
* **Severity:** Low · **Category:** Maintainability · **Location:** `Main.lua:148-163`
* Replace the inline sequence with `{ {name='menuKey', destroy=function() menuKey:Destroy() end}, … }`
  and `pcall` each entry, logging failures. Removes COR-04 permanently and makes creation/disposal
  symmetry reviewable. **Confidence:** High.

### COR-25 — Replace the three-value cargo protocol with a table result
* **Severity:** Low · **Category:** Maintainability · **Location:** `Main.lua:196-225`, `ReUICargoIndicator.lua:6-8`
* `return { ok = true }` / `{ ok = false, reason = '…', fallback = true }` removes the `directOk`
  overload and the boolean/message polymorphism in slot 3 (COR-01/COR-10). Update the smoke test stubs
  accordingly. **Confidence:** High.

### COR-26 — Single source of truth for feature ids
* **Severity:** Low · **Category:** Architecture · **Location:** `Main.lua:101-118`, `Registry.lua:14-38`
* Drop the `registered` table and ask the registry (`registry:Has(id)` or a `pending` lookup) instead;
  return `'unknown'` from `GetState` rather than asserting. Fixes COR-02 and makes
  `GetFeatureState` safe for third parties. **Confidence:** High.

### COR-27 — Document or delete the unused `Lifecycle` surface
* **Severity:** Low · **Category:** Maintainability · **Location:** `Lifecycle.lua:45-63`
* `Every` has no caller and two sharp edges (frame-period drift, `OnFrame` takeover). Either document
  it as reserved with those limits or remove it; `Own/Bind/Guard/Defer` are used and fine.
  **Confidence:** High.

### COR-28 — Give the rings a budget
* **Severity:** Low · **Category:** Performance · **Location:** `StrategicRings.lua:280-313`
* Cap total rings (e.g. 64), drop rings when their group unit is dead, and skip drawing an off-screen
  ring. Pair with a user measurement before/after. **Confidence:** Medium.

### COR-29 — Repair the test harness and the stale menu test
* **Severity:** Low · **Category:** Testing · **Location:** `Tests/core-smoke.lua:120-140`, `Tests/claret-menu.lua:160-168`
* Add a `rangeoverlayparams` stub so the only bootstrap/lifecycle test actually runs; update the menu
  test to the compact Core panel (552 wide, header 480×72) or assert the header by parent rather than
  by hard-coded width. **Confidence:** High.

### COR-30 — Close the `Lifecycle` re-entrancy hole
* **Severity:** Low · **Category:** Correctness · **Location:** `Lifecycle.lua:98-144`
* `Destroy` should check the `SetEnabled(false)` result and, if `busy`, set a `destroyPending` flag
  that `SetEnabled` honours when it finishes, instead of marking `disposed` while a start is in
  flight. No current caller triggers it; cheap insurance before third-party features use the API.
  **Confidence:** High (code) / Low (current impact).

---

## Appendix — measurements used above

| Metric | Value | How obtained |
|---|---|---|
| Lua files | 42 (39 modules + `Main` + `Options` + `mod_info`) | `Get-ChildItem` |
| Total lines | 9 645 | line count per file |
| Production-reachable | 2 899 lines / 14 files | import graph from `Main.lua` |
| Staging (unreachable) | 6 735 lines / 27 files (70 %) | import graph + grep for `RegisterFeature` |
| Modules with no production importer | 27 | grep over `ClaretCore/`, `ClaretHotbuild/`, `Tests/` |
| Duplicated private helpers | 15 definitions / 10 files | per-file regex count |
| `pcall` in `Main.lua` | 6 (migration ×2, ring eraser, welcome, cargo ×2) | grep |
| Polling loops (`ForkThread`+`WaitFrames`) | 1 (`languageChanged`) | grep across Core |
| `OnChanged:Add` sites | 4 (`Main.lua:43`, `Registry.lua:46`, `Menu.lua:540`, `Menu.lua:630`) — all paired with a `Remove` | grep |
| Tests covering staging modules | 31 of 66 test files under `Tests/` | `Tests/` listing |
| Tests failing for Core | `core-smoke.lua`, `claret-menu.lua` | `node Tests/check-core.cjs --quiet --only …` |
