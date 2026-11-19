# Claret documentation accuracy audit

**What this is:** a read-only audit of Claret's written documentation against the actual code of the two working mods, for the maintainer. It lists every claim that the code contradicts, every load-bearing invariant that is not documented, and the minimal fixes, prioritized.

**Scope audited:** `Context/quick-reference.md`, `tech-findings.md`, `reui-notes.md`, `menu-rules.md`, `hotbuild-rules.md`, `ui-style.md`, `performance-hotspots.md`, `feature-catalog.md`, `hotbuild-context-spec.md`, `localization-glossary.md`, `mod-inventory.md`, `dependency-map.md`; `ClaretCore/README.md`; `ClaretHotbuild/README.md`, `ClaretHotbuild/CHANGELOG.md` (recent entries); `Stage/stage-1-status.md`.

**Code of record:** project-root `ClaretCore/` (Version `0.10.13`, BuildStamp `20261117-45`, mod_info `version = 32`, `ReUI = 'ClaretCore=0.10.13'`) and `ClaretHotbuild/` (Version `0.10.36`, BuildStamp `20261117-143`, mod_info `version = 73`, `ReUI = 'ClaretHotbuild=0.10.37'`). Both were verified byte-identical to the live mods on 2026-11-18 before this audit.

**Method and limits:**
Read every in-scope document in full, then read the code they describe: Core `Main.lua`, `Options.lua`, `modules/{Registry,Lifecycle,Menu,MenuKey,Localization,Theme,Welcome,TransportCargo,ReUICargoIndicator}.lua`; Hotbuild `Main.lua`, `Options.lua`, `modules/{Model,Runtime,Keys,KeyboardBindings,KeyboardEditor,Editor,ContextEditor,ContextModel,ContextActions,Adapter,TemplateCatalog,Navigator,CycleMenu,QuickRepeatMenu,QuickRepeatSettings,OpenPerf}.lua`.
Not done: no test run (`Tests/check-core.cjs` was not executed in this task), no game launch, no reading of `Context/sources/`, `Context/compiled-lua.txt` or `Stage/stage-1-research.md`, no editing of either mod. Claims about engine behaviour are marked as assumptions where the code alone cannot settle them. Russian CHANGELOG entries are quoted verbatim; translation quality of the recently translated `Context/*.md` files was not assessed.

**Findings count:** 0 Critical, 9 High, 17 Medium, 7 Low; plus 17 optional improvements (Section 4, P0/P1/P2).

**Top three conclusions:**
1. Both user-facing READMEs are stale at the level of the version banner and install instructions (Core says 0.10.1, Hotbuild says 0.10.14; actual 0.10.13 / 0.10.36, and Hotbuild requires Core `>= 0.10.5`, not `>= 0.10.0`).
2. The most damaging errors are behavioural promises the code does not keep: Hotbuild "ignores" a saved disabled option but actually honours it with no UI to reverse it; the building editor is documented as having no reorder arrows but has 24×24 up/down arrows; outside-click behaviour is described three different ways, and the two README versions ("captures clicks" / "closes the menu") are both contradicted by the code.
3. The documentation has no home for the contracts that actually keep the two mods working together: creation order, the double `gamemain.OnSelectionChanged` hook and Hotbuild's hook on Core's `MenuKey.Open`, the three Hotbuild profile keys with their own schema versions, and the real `RegisterSettingsSection`/`RegisterFeature` field set.

---

## 1. Confirmed defects — documentation claims contradicted by code

### DOC-01 — High — Hotbuild can be left permanently disabled by a stale option, while the README promises the opposite
- **Location:** `ClaretHotbuild/README.md` (install paragraph); `ClaretHotbuild/Options.lua:1`; `ClaretHotbuild/Main.lua:Main` (`RegisterFeature('hotbuild', ..., options.enabled)`).
- **Doc claim:** "Hotbuild requires Core >= 0.10.0 and is always active; there is no menu toggle. A previously saved disable option is ignored; the profile and bindings are saved."
- **Code:**
  - `Options.lua`: `enabled = ReUI.Options.OptionValue(true)`.
  - `Main.lua`: `local ok, message = ReUI.ClaretCore.RegisterFeature('hotbuild', function(scope) Ensure():Start(scope) end, options.enabled)`.
- **Problem:** The saved value is not ignored: `RegisterFeature` binds the option and `Registry:BindOption` calls `SetEnabled(option:Get())`. With `enabled = false` the feature never starts (`Runtime:Start` is not called), and no menu row exposes the option (`RegisterSettingsSection` for Hotbuild passes no `toggles`; Core's `coreToggles` lists only Core options).
- **Impact:** A profile carrying `ClaretHotbuild.enabled = false` (from an older build or a hand-edited profile) silently disables Hotbuild with no in-game way to re-enable it, directly contradicting the README's support promise. Support time is spent on a "broken mod" that is actually switched off.
- **Recommendation:** Either delete the option and always start Hotbuild (matching the documented product decision), or document it honestly and expose it. Minimal doc-only fix: replace the sentence with "Hotbuild is always active in the menu; a saved `enabled=false` value from older builds still prevents startup — clear it in the ReUI options profile if Hotbuild does not respond."
- **Risk of fix:** Removing the option changes profile semantics for users who relied on disabling Hotbuild (none can via UI today). Keeping it needs a migration that forces `true` once.
- **Confidence:** High for the code path; Medium for how many real profiles contain `false`.

### DOC-02 — High — Hotbuild README describes version 0.10.14 and Core 0.10.0
- **Location:** `ClaretHotbuild/README.md` title and install paragraph.
- **Doc claim:** "# Claret Hotbuild — prototype 0.10.14"; "Enable ReUI, Claret Core 0.10.0, and Claret Hotbuild 0.10.14, then start a new match. Hotbuild requires Core >= 0.10.0…".
- **Code:** `Main.lua`: `Version = '0.10.36'`; `mod_info.lua`: `version = 73`; `ReUI.Require` lists `'ClaretCore >= 0.10.5'`.
- **Problem:** Three version facts are wrong in the first two paragraphs a new user reads: the Hotbuild version (0.10.14 vs 0.10.36) and the minimum Core (0.10.0 vs 0.10.5), repeated twice.
- **Impact:** Users install or keep an older Core (0.10.0–0.10.4), pass the README's check, and then fail ReUI's dependency test or run against a Core that does not export the APIs Hotbuild calls. Bug reports are filed against a build that is 22 releases old.
- **Recommendation:** Replace the title with "prototype 0.10.36" and make the install line "Claret Core 0.10.5 or newer". Add a one-line rule at the top of both READMEs: the version in the heading must equal `Version` in `Main.lua`.
- **Risk of fix:** None (text only).
- **Confidence:** High.

### DOC-03 — High — Core README title and its Hotbuild requirement are stale
- **Location:** `ClaretCore/README.md` title; final paragraph.
- **Doc claim:** "# Claret Core — test build 0.10.1"; "Hotbuild 0.10.1 requires Core >= 0.10.0."
- **Code:** `ClaretCore/Main.lua`: `Version = '0.10.13'`; `mod_info.lua`: `version = 32`, `ReUI = 'ClaretCore=0.10.13'`. `ClaretHotbuild/Main.lua`: `ReUI.Require { 'ClaretCore >= 0.10.5', ... }`.
- **Problem:** Core's headline version is 12 releases behind, and the README states a Hotbuild→Core minimum three minor versions below the enforced one.
- **Impact:** A third-party mod author following the README targets `0.10.0` APIs that may not include `AppendTransportCargo`, `CreateStrategicRing` or `onMenuClosed`; a user reading the last line believes Core 0.10.0 is enough for Hotbuild.
- **Recommendation:** Set the title to 0.10.13; replace the last line with "Hotbuild 0.10.36 requires Core >= 0.10.5." Prefer deriving both from `mod_info.lua` at release time.
- **Risk of fix:** None.
- **Confidence:** High.

### DOC-04 — High — "There are no arrows for reordering rows" — the editor has 24×24 up/down arrows
- **Location:** `ClaretHotbuild/README.md` ("Building editor and diagnostics"); `ClaretHotbuild/modules/Editor.lua` (`RowArrow`, `MoveBuildingRow`).
- **Doc claim:** "There are no arrows for reordering rows: the rows themselves define the order."
- **Code** (`Editor.lua`):
  - `local function RowArrow(owner,glyph,x,y,delta) local button=Panel(owner,x,y,24,24,C.raised)` …
  - `local up=RowArrow(frame,'↑',48,195+(row-1)*65+8,-1)` / `local down=RowArrow(frame,'↓',48,195+(row-1)*65+34,1)`
  - button handler: `MoveBuildingRow(index,delta)`.
- **Problem:** The README denies the primary interaction of the editor. The CHANGELOG itself records the arrows twice (build 20261116-127 "Стрелки перестановки строк увеличены до 24×24", build 20261116-126/109), so the README contradicts both code and changelog.
- **Impact:** A tester following the README will not exercise reordering and may report the arrows as an unrequested change; a new maintainer may remove them as "undocumented".
- **Recommendation:** Replace the sentence with "Each row has ↑/↓ buttons (24×24) that move the whole row; empty rows in the middle keep their position, trailing empty rows are removed." Delete the later "In older versions, arrows and × changed the order…" history note or mark it as history.
- **Risk of fix:** None.
- **Confidence:** High.

### DOC-05 — High — Outside-click behaviour is documented three different ways; the code implements none of the "capture" or "close" variants
- **Location:** `ClaretCore/README.md` ("History: Core 0.9.0"); `ClaretHotbuild/README.md` (end of "Build templates"); `Context/menu-rules.md`; `ClaretCore/modules/Menu.lua:Open`.
- **Doc claims:**
  1. Core README: "The map is not dimmed behind the menu; the transparent area outside the window captures clicks without closing it or issuing game commands."
  2. Hotbuild README: "Clicking outside the menu closes it after checking for an unsaved draft."
  3. `Context/menu-rules.md`: "Do not dim the map or intercept mouse input outside the menu panels. Close the menu via a button or Escape, with draft protection."
- **Code** (`Menu.lua:Open`): `root=Group(parent)`, then `L(root):Fill(parent); root.Depth:Set(parent:GetTopmostDepth()+20); root:DisableHitTest()`. Only `state.launcher` and `state.panel` surfaces carry `HandleEvent`; there is no full-screen catcher and no outside `ButtonPress` path that calls `RequestClose`.
- **Problem:** Statements 1 and 2 are false; statement 3 is the only one that matches the code. They are not marked as historical in two of the three files.
- **Impact:** Testers "verify" a behaviour that cannot happen (menu closing on outside click) and file false regressions; another author copying Core README may add a click catcher and break the documented rule "game hotkeys/commands remain available".
- **Recommendation:** Keep one sentence, in `menu-rules.md`, as the source of truth: "The menu never captures clicks outside its panels; it closes only via ×, Escape, or `RequestClose()`." Replace both README paragraphs with a link to `menu-rules.md`.
- **Risk of fix:** If the original 0.9.0 intent was a catcher, the code has a real regression rather than a doc error — validate once in FAF (see RISK-03).
- **Confidence:** High that the code has no full-screen catcher (root `DisableHitTest`); Medium that no engine-level parent intercepts the click.

### DOC-06 — Medium — Template size limit is documented as 256 buildings; code accepts up to 4096
- **Location:** `ClaretHotbuild/README.md` ("Current limitations"); `ClaretHotbuild/modules/TemplateCatalog.lua:Parse`.
- **Doc claim:** "…with a maximum of 256 buildings."
- **Code:** `if count<3 or count>4098 or not Number(source[1]) or not Number(source[2]) then WARN('[ClaretHotbuild] Template rejected: dimensions/count …') return nil end` — `templateData` is 2 header values plus one entry per building, so the real limit is 4096 buildings, and the rejection message reports the raw count, not a limit.
- **Problem:** The documented limit has no counterpart in code; no other module contains a 256 check (`grep 256` over `ClaretHotbuild/` returns only this README line).
- **Impact:** Testers do not test large templates; if 256 was a deliberate safety bound (memory/placement), it is missing from the implementation rather than from the docs.
- **Recommendation:** Decide the intended bound. If 4096 is intended, change the README to "up to 4096 buildings (templates with more are rejected)". If 256 is intended, add the check in `TemplateCatalog:Parse` and keep the README.
- **Risk of fix:** Adding a 256 limit would silently drop already-saved large templates (they become unavailable); changing the docs is safe.
- **Confidence:** High for the mismatch; Medium for which side is wrong.

### DOC-07 — Medium — "Displaying marked passengers in the bottom HUD has not been implemented" is no longer true
- **Location:** `ClaretCore/README.md` ("Core 0.10.0: selective transport unloading action"); `ClaretCore/Main.lua:Main` (`AppendTransportCargo`); `ClaretCore/modules/ReUICargoIndicator.lua` (`AppendNext`, `Mark`).
- **Doc claim:** "Displaying marked passengers in the bottom HUD has not been implemented."
- **Code:** `AppendTransportCargo` first calls `import('/mods/ClaretCore/modules/ReUICargoIndicator.lua').AppendNext()` and returns success when it marks the passenger; on failure it falls back to `transportCargo:Append(selection)` and then calls `ReUICargoIndicator.Mark(unit, cargo)`. The module header says it "updates that context [ReUI's TransportCargo] for a passenger Core has already staged".
- **Problem:** The README describes the 0.10.0 state; 0.10.13 added a ReUI.Construction HUD bridge plus a fallback path. `Stage/stage-1-status.md` already says "индикатор груза имеет резервный путь Core".
- **Impact:** Testers skip the HUD mark check that the current code is supposed to produce; a regression in `Mark` would go unnoticed.
- **Recommendation:** Replace with: "The passenger mark is drawn through ReUI.Construction's transport-cargo context when that panel exists; otherwise Core falls back to FAF's additional-selection list without a HUD mark." Move the old sentence to history.
- **Risk of fix:** None.
- **Confidence:** High.

### DOC-08 — Medium — Menu geometry 1368×1320 is stale in two documents
- **Location:** `ClaretCore/README.md` ("History: Core 0.9.0"), `Context/quick-reference.md` ("Later decisions and status notes"); `ClaretCore/modules/Theme.lua:Metrics`, `modules/Menu.lua:Open`.
- **Doc claims:** Core README (under the heading "History: Core 0.9.0 — former large window"): "one geometry of 1368×1320 before the shared screen scale, used by every section"; quick-reference, presented as the current rule: "Core 0.9.0: all menu sections use the same large size (1368×1320 before overall scaling)".
- **Code:** `Metrics = { launcherWidth=248, launcherHeight=400, panelWidth=1128, panelHeight=1110, corePanelWidth=552, corePanelHeight=408, … }`; `Menu.lua` picks `metrics.corePanelWidth/Height` for the Core section and `panelWidth/Height` otherwise.
- **Problem:** Both numbers are wrong for the current code, and "the same large size for every section" stopped being true when Core got a compact panel (`Context/ui-style.md` already documents 1128×1110 and a compact Core section). Core README at least labels its section "former", but gives no current geometry, so readers take 1368×1320 as the design; quick-reference states it as current.
- **Impact:** Layout work starts from wrong dimensions; a reviewer comparing screenshots to docs sees a mismatch and may "fix" `Theme.Metrics` instead of the docs.
- **Recommendation:** Delete the numeric geometry from both README/quick-reference and point to `Theme.Metrics`; keep only the history sentence without numbers, and add one current line to `ui-style.md` (already correct) as the single owner.
- **Risk of fix:** None.
- **Confidence:** High.

### DOC-09 — Low — Compact Core panel documented as 552×436; the metric is 552×408
- **Location:** `Context/ui-style.md` ("Dimensions, text, and scale"); `ClaretCore/modules/Theme.lua:Metrics`.
- **Doc claim:** "compact Core section 552×436".
- **Code:** `corePanelHeight=408` (and `Menu.lua` uses `metrics.corePanelHeight` for section `core`).
- **Problem:** 28 logical units of drift; no metric equals 436 (`grep 436` over `ClaretCore/` matches only the colour substring `ff343638` in `Theme.lua`).
- **Impact:** Minor; anyone hand-placing a Core card uses the wrong height.
- **Recommendation:** Change to 552×408, or omit the number and reference `Theme.Metrics.corePanelWidth/corePanelHeight`.
- **Risk of fix:** None.
- **Confidence:** High.

### DOC-10 — Medium — `tech-findings.md` says `rawget(_G, …)` may not see engine globals; production code depends on exactly that
- **Location:** `Context/tech-findings.md` ("Further Research", last bullet); `ClaretCore/modules/Menu.lua:Open`; `ClaretCore/Main.lua:Main`; `ClaretCore/modules/Localization.lua:DetectGameLanguage`; `ClaretCore/modules/ReUICargoIndicator.lua`; `ClaretHotbuild/modules/Editor.lua`.
- **Doc claim:** "In Claret modules, `rawget(_G, ...)` may not see engine globals — use normal access guarded by `pcall`."
- **Code:**
  - `Menu.lua`: `local activeMods=rawget(_G,'__active_mods')` — drives the "recommended mods" block.
  - `Main.lua`: `if rawget(_G, 'REUI_DEV_MODE') then` — decides whether the Diagnostics toggle exists.
  - `Localization.lua`: `local sys = rawget(_G, 'Sys')` — game-language detection.
  - `ReUICargoIndicator.lua`: `local reui = rawget(_G, 'ReUI')`.
- **Problem:** Either the doc rule is over-general (some engine globals are visible via `rawget`) or the code has four latent failures (missing recommendation block, missing Diagnostics toggle, language detection falling back, HUD mark path always failing). The two cannot both be correct as written, and nothing in the docs says which globals are safe.
- **Impact:** If a future maintainer applies the doc rule literally, they will rewrite those four call sites unnecessarily; if an engine update hides `__active_mods`, the recommendation block disappears silently.
- **Recommendation:** Rewrite the rule with the observed exceptions: "`rawget(_G, name)` works for `ReUI`, `Sys`, `__active_mods`, `REUI_DEV_MODE` in FAF3840; for other engine functions use a `pcall`-guarded normal access." Add the check date and the build.
- **Risk of fix:** Doc-only. If any of the four is actually nil in game, that is a code bug to be filed separately.
- **Confidence:** Medium — the doc sentence and the four call sites are facts; which side is wrong needs a game-log check of the recommendation block.

### DOC-11 — Medium — `tech-findings.md` says `GetSystemTimeSecondsOnlyForProfileUse` does not exist, but `OpenPerf` tries it first
- **Location:** `Context/tech-findings.md` ("Further Research"); `ClaretHotbuild/modules/OpenPerf.lua:Start`.
- **Doc claim:** "`GetSystemTimeSecondsOnlyForProfileUse` does not exist in UI context (strict-globals error)… `GetSystemTimeSeconds()` is available for timing."
- **Code:** `local primary=FindClock(function() return GetSystemTimeSecondsOnlyForProfileUse end)`; `local fallback=FindClock(function() return GetSystemTimeSeconds end)`; `local clock,name=primary,'GetSystemTimeSecondsOnlyForProfileUse'`; `if not clock then clock,name=fallback,'GetSystemTimeSeconds' end`. `FindClock` wraps the getter in `pcall` and accepts a function. The chosen clock is logged at session start: `LOG('[Claret][perf] init gate='..tostring(gate)..' timer='..name)`.
- **Problem:** If the doc is right, the primary path is dead and every `[Claret][perf]` measurement uses the fallback clock — but the docs present the fallback as the only option and never mention that the code prefers the profile-only timer. If the code is right, the doc "fact" is wrong. The perf method in `Context/performance-hotspots.md` does not say which clock the probes use, although the log already reports it.
- **Impact:** Timing comparisons can mix clocks between builds if the primary path starts working after a client update; readers cannot tell which function produced the numbers.
- **Recommendation:** Add one line to `performance-hotspots.md`: "OpenPerf prefers `GetSystemTimeSecondsOnlyForProfileUse` when it resolves (pcall) and falls back to `GetSystemTimeSeconds`; the chosen clock is the one in the session's `[Claret][perf]` header." Re-verify the API claim and either delete it or mark it "not available when last checked (2026-11-13)".
- **Risk of fix:** None.
- **Confidence:** Medium — the contradiction is proven; which API works is unverified without the game.

### DOC-12 — Medium — The documented global quick-repeat window (default 1.5 s) does not exist; its settings window is unreachable
- **Location:** `Context/hotbuild-context-spec.md` §4; `Context/menu-rules.md` ("Hotbuild gear settings…"); `ClaretHotbuild/Options.lua`; `modules/QuickRepeatMenu.lua`; `modules/QuickRepeatSettings.lua`; `modules/Runtime.lua:ResolveContext/ExecuteRow`.
- **Doc claims:** Spec §4: "Repeat window: one global setting in F10 -> Claret, default 1.5 s. Within the window quick repeat has priority over the column row." `menu-rules.md`: "Hotbuild gear settings open in the right-hand panel next to the menu…".
- **Code:** `ClaretHotbuild/Options.lua` contains only `enabled`. `QuickRepeatSettings.Create(parent, layout, option)` expects an `option` for the window, but the only caller is `QuickRepeatMenu.Create`, and `QuickRepeatMenu` is imported by no module (grep over `ClaretHotbuild/` returns only its own file). `Menu.lua` still supports `section.accessory` for the ⚙, but Hotbuild's registered section passes no `accessory`, so no gear is drawn. Runtime still reads legacy `row.quickRepeat` / `row.fallback`, so the fields have meaning but no UI and no configurable window.
- **Problem:** The spec describes a setting that cannot be reached: no option value exists to persist the window, no section registers the settings window, and the gear is not created. `menu-rules.md` describes the gear as if it were current.
- **Impact:** Testers look for a "Repeat window" field that is not present; a maintainer may "restore" `QuickRepeatMenu` without the missing option and hit a nil `option` error (`FinitePositive(option:Get())`), or believe quick repeat is configurable when it is fixed in code.
- **Recommendation:** Mark spec §4 as superseded by the 2026-11-13 decision (editor controls removed) and state the actual behaviour: "Legacy `quickRepeat`/`fallback` fields are still executed; they are not offered for new assignments, and no global repeat-window setting exists." In `menu-rules.md`, delete the gear sentence or change it to "sections may register an `accessory` window shown by a ⚙ in the launcher; no section uses it today."
- **Risk of fix:** Wiring the setting for real is a code change, not a doc fix; agree separately.
- **Confidence:** High for the absence of the option and of any `QuickRepeatMenu` import; High that no section provides `accessory`.

### DOC-13 — Medium — Spec lists "Queue template from this factory" in the Factory catalog, but the action is obsolete
- **Location:** `Context/hotbuild-context-spec.md` §7 ("3. Factory"); `ClaretHotbuild/modules/ContextActions.lua` (`removed` table); `CHANGELOG.md` build 20261116-131.
- **Doc claim:** "+ Queue template from this factory [create_template_factory]."
- **Code:** `local removed={…, create_template_factory=true, …}` and then `if removed[action.id] then action.hidden=true; action.obsolete=true end`. Changelog 131: "«Шаблон очереди с этого завода» скрыт для новых назначений и помечен устаревшим".
- **Problem:** The spec's catalog section is read as the target list; the action is intentionally not offered for new assignments.
- **Impact:** A reviewer adds it back as a missing catalog item; testers look for it in the Factory column.
- **Recommendation:** Move the item to the "Removed from the catalog" block of the spec and note that saved bindings keep executing it as obsolete.
- **Risk of fix:** None.
- **Confidence:** High.

### DOC-14 — Medium — Spec states the per-bind absolute flag "stays", but the editor no longer offers it
- **Location:** `Context/hotbuild-context-spec.md` §5 ("Absolute binds"); `ClaretHotbuild/README.md` ("Multifunction bindings"); `modules/ContextEditor.lua`; `modules/ContextModel.lua`.
- **Doc claim:** "The existing per-bind absolute flag stays."
- **Code:** `ContextEditor.lua` only reads `draft.absolute` to filter tiles (`local showContext=not (draft and draft.absolute and item.context~='empty')`) and to reject non-empty contexts; there is no switch that changes the flag. `ContextModel` still validates and loads absolute bindings, and `Runtime` still supports `ExecuteAbsolute` (`ClaretHotbuildAbsolute_`), so the data field persists.
- **Problem:** "Stays" is ambiguous between "data stays" (true) and "the user can still set it" (false). The README says the mode switch was removed; the spec never got the update.
- **Impact:** Testers look for the switch; a maintainer may reintroduce UI that was deliberately removed on 2026-11-13.
- **Recommendation:** Change to "The absolute flag remains in saved data and executes as before; it is not editable — new absolute bindings cannot be created."
- **Risk of fix:** None.
- **Confidence:** High.

### DOC-15 — Medium — `stage-1-status.md` says build 147 while the loaded build stamp is 143
- **Location:** `Stage/stage-1-status.md` ("Claret Hotbuild"); `ClaretHotbuild/Main.lua:1-3`.
- **Doc claim:** "Hotbuild 0.10.36, mod version 73, build `20261117-147`."
- **Code:** `Version = '0.10.36'`; `local BuildStamp = '20261117-143'`; the build-147 intercept code is present (`KeyboardBindings:FactoryShiftOverrides` logging `factory_shift_intercept key=…`, `Runtime:ExecuteFactoryShift` logging `factory_shift_intercept chord=… active=true`).
- **Problem:** The code contains 147-era behaviour but reports stamp 143, so the one value intended to identify the loaded build (`LOG('[Claret][build] hotbuild=… stamp=…')`) cannot be used to confirm that build 147 is running — the very check the status file asks the user to perform.
- **Impact:** In-game verification of "build 147" is ambiguous: the log will say 143 even when the Shift intercept is active. Any bug report keyed on the stamp is unreliable.
- **Recommendation:** Bump `BuildStamp` to `20261117-147` in the same change that ships 147, and state the rule in the README/CHANGELOG: "the stamp equals the build number of the newest CHANGELOG entry". Until then, status should say "build 147 code, stamp 143 (stale)".
- **Risk of fix:** A stamp bump alone does not change behaviour; it must be followed by an in-game load check to confirm the log line.
- **Confidence:** High.

### DOC-16 — Medium — `mod_info.lua` declares `ClaretHotbuild=0.10.37` while `Version` is `0.10.36`
- **Location:** `ClaretHotbuild/mod_info.lua`; `ClaretHotbuild/Main.lua`.
- **Doc/code facts:** `ReUI = 'ClaretHotbuild=0.10.37'`, `version = 73`, `Version = '0.10.36'`.
- **Problem:** ReUI's loader resolves other mods' `ReUI.Require 'ClaretHotbuild >= X'` against the manifest value (0.10.37), not against the code's `Version`. The two version numbers are one release apart, and `stage-1-status.md` repeats 0.10.36 without mentioning the manifest value.
- **Impact:** A dependent mod can declare `>= 0.10.37`, satisfy ReUI's component check, and call an API this build does not have (or the reverse: a real 0.10.37 install is indistinguishable). Version-keyed bug reports mix two builds.
- **Recommendation:** Make `mod_info.lua` and `Version` equal (0.10.36) or bump both with a CHANGELOG entry. Add the manifest value to the status line: "Hotbuild 0.10.36 (manifest 0.10.37)" until fixed.
- **Risk of fix:** Lowering the manifest value could break a dependent mod that already requires 0.10.37 — check dependents first (none known in this repo).
- **Confidence:** High.

### DOC-17 — Low — CHANGELOG has no entries for builds 142/143, which the status file references
- **Location:** `ClaretHotbuild/CHANGELOG.md`; `Stage/stage-1-status.md`.
- **Doc claim (status):** "Build 146 исправил стартовый сбой `PairIsMapped`; builds 143/142/141 затрагивали инициализацию редактора клавиш, удаление назначений пресета и распределение приказов."
- **Code/docs:** CHANGELOG sequence is 147, 146, 145, 144, 141, 140…; 142 and 143 are absent, while `BuildStamp` is `20261117-143`.
- **Problem:** A build number that exists in code and status has no record of what changed; conversely the status attributes changes to 142/143 that cannot be checked against the changelog.
- **Impact:** `git log`/changelog archaeology cannot reconstruct the Shift-intercept work; reviewers cannot tell whether 143 was a code build or a stamp-only change.
- **Recommendation:** Add two short entries (142, 143) describing the actual changes, or add one line "142–143: interim builds, no separate release notes" so numbering is continuous.
- **Risk of fix:** None.
- **Confidence:** High.

### DOC-18 — Low — Quick-reference "status snapshot" is 27 Hotbuild releases old
- **Location:** `Context/quick-reference.md` ("Later decisions and status notes", last bullet).
- **Doc claim:** "Status snapshot dated 2026-11-11: Core 0.10.0 and Hotbuild 0.10.9 (check `mod_info.lua` and `Main.lua` for current versions)."
- **Code:** Core `0.10.13`, Hotbuild `0.10.36`.
- **Problem:** The only dated status in the index points at versions 27 patch releases (Hotbuild) and 13 patch releases (Core) behind, and the feature list that follows (double actions, sequential engineer binds, mixed-selection priorities) is a mix of implemented and since-changed behaviour.
- **Impact:** Agents and readers treat the snapshot as current because it is the only explicit status in the index; it conflicts with `stage-1-status.md`.
- **Recommendation:** Replace the snapshot with a pointer: "Current state: `Stage/stage-1-status.md` (rewritten after every task). This file is an index only." Delete the version numbers.
- **Risk of fix:** None.
- **Confidence:** High.

### DOC-19 — Low — Repeated menu path "F10 → Claret → Claret Core" does not match the section title "Core"
- **Location:** `ClaretCore/README.md` ("Verification status"), `Context/quick-reference.md` (menu bind bullet), `Context/menu-rules.md` (last bullets); `ClaretCore/modules/LocalizationStrings.lua`; `ClaretCore/modules/Menu.lua:Main`.
- **Doc claim:** "use F10 → Claret → Claret Core → **Change**"; "change or clear it through Claret → Claret Core".
- **Code:** `menu:Register { id='core', title='Core', titleKey='core.section.title' … }`; both `en` and `ru` strings for `core.section.title` are `'Core'`.
- **Problem:** The navigation path names a section that does not exist; the visible row is "Core".
- **Impact:** Minor user friction (the welcome window already says "F10 → Claret"); support answers repeat the wrong label.
- **Recommendation:** Replace all occurrences with "F10 → Claret → Core".
- **Risk of fix:** None.
- **Confidence:** High.

---

## 2. Strongly supported architectural problems — undocumented load-bearing invariants

### ARCH-01 — High — Creation order and lifecycle contract is nowhere documented
- **Location:** `ClaretCore/Main.lua:Main`; `ClaretHotbuild/Main.lua:Main`; `ClaretCore/README.md` ("Connecting other mods").
- **What the code requires:**
  1. `Main()` runs before UI creation: `ReUI.Require`, hooks, options, `RegisterFeature`, `RegisterSettingsSection`, `ReUI.Core.OnPreCreateUI(...)`.
  2. `OnPreCreateUI`: Core calls `menuKey:Initialize()` and `tabs.AddToMenu`; Hotbuild does nothing here.
  3. `OnPostCreateUI`: Core creates the `Registry`, registers `selectionSummary`, drains `pending`, calls `menuKey:Start()`, sets `uiReady = true`, then creates the welcome window (inside `pcall`). Hotbuild calls `Ensure()` and creates its owner `Group`, then relies on the feature `start(scope)` (which may run during Core's `OnPostCreateUI`) to call `Runtime:Start`.
  4. `owner.OnDestroy`: Core sets `disposed`, destroys `menuKey/menu/transportCargo/strategicRings/registry`, clears the selection event, removes the language subscription; Hotbuild destroys `service`.
- **Doc gap:** The README says only "`start(scope)` is called after the UI is created when the feature is enabled" and "Registration is allowed before the UI is created and is deferred." It never says that `RegisterFeature` must happen before `OnPostCreateUI` to get the deferred path, that `GetFeatureState` returns `'unavailable'` before the registry exists, or that `AppendTransportCargo`/`CreateStrategicRing` depend on `uiReady` and return `false` before it.
- **Impact:** A new feature that calls `RegisterFeature` from `OnPostCreateUI` (a natural place) works only by accident of callback order; one that calls `ClaretCore.AppendTransportCargo` from `OnPreCreateUI` silently returns `false`. The dispose order (Hotbuild's owner vs Core's owner) is also load-bearing for hooks that call into Core.
- **Recommendation:** Add a short "Lifecycle" section to Core README with the four phases and the guarantees of each, including the exact return values of the API before/after `OnPostCreateUI`.
- **Risk of fix:** Documentation only.
- **Confidence:** High.

### ARCH-02 — High — Cross-mod hook order is undocumented; Hotbuild hooks a private Core module function
- **Location:** `ClaretHotbuild/Main.lua:Main`; `ClaretCore/Main.lua:Main`; `ClaretCore/modules/MenuKey.lua` (`function Open()`); `Context/reui-notes.md` (hooks).
- **Facts:**
  - Both mods hook `/lua/ui/game/gamemain.lua`, `OnSelectionChanged`: Core resets `transportCargo` and fires `ClaretSelection`; Hotbuild calls `service:QuickSelectionChanged(newSelection)`.
  - Hotbuild also hooks `/mods/ClaretCore/modules/MenuKey.lua`, `Open`, to call `service:BreakQuick()` before the menu opens.
  - Core's hook comment: "GetSelectedUnits can still describe the previous selection here."
- **Doc gap:** `reui-notes.md` explains that `Core.Hook` wraps the previous function and that registration after UI creation is prohibited, but no Claret document states which of the two `OnSelectionChanged` wrappers runs first. With `Core.Hook` semantics, the later registration wraps the earlier one and therefore executes first, so Hotbuild's handler runs before Core's reset on the same event. Nothing tells a maintainer that `MenuKey.Open` is a public extension point — Core README presents `MenuKey` as an internal module.
- **Impact:** Renaming/removing `Open` (a plausible refactor) silently breaks Hotbuild's quick-repeat reset, with no load error. Reordering hooks or calling `original` conditionally changes selection semantics for both mods. A third mod hooking the same two functions has no documented ordering contract at all.
- **Recommendation:** Document in `Context/dependency-map.md` (or a new "Integration contracts" section of Core README): (a) the two hooks and their observed nesting order; (b) `MenuKey.Open` is a stable hook target used by Hotbuild; (c) rules for a new hook: wrap, always call `original`, preserve return values, never register after `OnPostCreateUI`.
- **Risk of fix:** None for docs. If `Open` is meant to be private, add a dedicated public `ReUI.ClaretCore.BeforeMenuOpen` event instead — that is a code change to agree with the user.
- **Confidence:** High for the hooks and their targets; Medium for the exact runtime nesting order (derived from `Core.Hook`, not observed in game).

### ARCH-03 — High — Profile format and versioning are undocumented across three keys
- **Location:** `ClaretHotbuild/modules/Runtime.lua`; `Model.lua`; `ContextModel.lua`; `KeyboardBindings.lua`; `Keys.lua`; both READMEs.
- **Facts:**
  - `ClaretHotbuild` — presets, `{ version = 1, bindings = { … } }` (`Model:Export` writes `version = 1`; `Model.Create` accepts only `version == 1`, otherwise warns and starts empty).
  - `ClaretHotbuildContexts` — multifunction bindings, exported as `{ version = 3, bindings = … }`; loader accepts 1, 2 and 3 and migrates v1 `rows` into the new shape; `MAX_BINDINGS = 64`.
  - `ClaretHotbuildKeyboard` — per-key pairs, `{ version = 2, assignments = … }`; loader accepts 1 and 2 and migrates old `grid.context` links into the pair store.
  - FAF profile: action IDs `ClaretHotbuild_<hex>`, `ClaretHotbuildAbsolute_<hex>`, `ClaretHotkeyContext_<hex>`, `ClaretHotkeyComposite_<hex>`, `ClaretHotkeyPair_<hex>` in `UserKeyActions`, plus `UserKeyMap` / `UserDebugKeyMap` and `descriptions`.
  - Corrupt/unknown versions block writes (`Runtime:RefreshKeys` returns `hotbuild.runtime.s004`; `KeyboardBindings` sets `pairError`).
- **Doc gap:** `Hotbuild/README.md` says only "Binding contents are stored in the ClaretHotbuild profile; key assignments are saved in FAF's profile key settings." Neither README nor any `Context` file names `ClaretHotbuildContexts` or `ClaretHotbuildKeyboard`, their versions, or the write-blocking rule.
- **Impact:** Users and maintainers copying a profile (common for bug reports and for restoring settings) move only one of three keys and lose multifunction sets or key pairs. A format bump has no migration note to check against. The "corrupt profile blocks saving" behaviour looks like a bug without documentation.
- **Recommendation:** Add a "Saved data" section to Hotbuild README: table of key → contents → accepted versions → migration, plus "on unknown version, Claret reads nothing and refuses to write; restore a backup rather than editing".
- **Risk of fix:** None.
- **Confidence:** High.

### ARCH-04 — High — `RegisterSettingsSection` is documented with a field set that is smaller than the one Hotbuild and Core actually rely on
- **Location:** `ClaretCore/README.md` ("Separate menu — 0.6.0"); `ClaretCore/modules/Menu.lua:Register/Open`; `ClaretHotbuild/Main.lua:Main`; `ClaretHotbuild/modules/Navigator.lua`; `modules/KeyboardEditor.lua`.
- **Doc claim:** "Fields: a unique `id`, `title`, a short single-line `description`, `toggles = {{label, description, option}}`, `actions = {{label, open(parent)}}`, and/or `inline(parent, layout)`."
- **Code actually supports/uses:**
  - `titleKey` / `descriptionKey` (Hotbuild passes both; `Menu.lua` prefers them over `title`/`description`);
  - `selectors` (Core's own language row: `labelKey`, `option`, `values`, `segmented`, `getLabel`);
  - `onMenuClosed()` (Hotbuild uses it for a final `RefreshKeys` after 2 frames);
  - `inline(parent, layout)` where `layout = { scale = <number>, setHeight = function(height) … end }` (Hotbuild's Navigator and KeyboardEditor depend on both);
  - child `inline` editor optional `AfterParentShow()` (called on re-show) and `OnLanguageChanged()`;
  - `actions[].open(parent, layout)` — called with **two** arguments, not `open(parent)`; `actions[].titleKey` is also read;
  - `section.accessory` (`{ title/titleKey, open }`) renders the ⚙ in the launcher;
  - `placeholder = true` sections (`core`, `hotbuild`, `ui`, `cinema`) that a later registration replaces; registration of those IDs succeeds once, other duplicate IDs are rejected;
  - fixed inline host size `1080×984`, panel `384×232` for an accessory, `CanLeave` serial/continuation semantics.
- **Problem:** The documented contract omits every field that makes the embedded Hotbuild editor and the keyboard page's variable height work. `open(parent)` is documented with the wrong arity.
- **Impact:** A new section author cannot implement a working inline editor or a close-time refresh from the README; a Core refactor may drop `setHeight`/`onMenuClosed` as "unused" and break Hotbuild's panel height and key refresh.
- **Recommendation:** Replace the prose with a compact field table (name, type, required, semantics), and document `setHeight`, `AfterParentShow`, `onMenuClosed`, `accessory` and the reserved IDs. Keep `CanLeave` prose, which is accurate.
- **Risk of fix:** Documentation only.
- **Confidence:** High.

### ARCH-05 — Medium — `RegisterFeature` contract gaps: reserved IDs, a phantom `probe` feature, and an asserting `GetFeatureState`
- **Location:** `ClaretCore/Main.lua:Main`; `ClaretCore/modules/Registry.lua`; `ClaretCore/README.md`.
- **Facts:** `local registered = { probe = true, selectionSummary = true }`. `selectionSummary` is registered directly in `OnPostCreateUI`; **no** feature named `probe` is ever registered — `probeEnabled` is only a logging gate. `RegisterFeature` rejects duplicates with `'Feature already registered: ' .. id`. `GetFeatureState` returns `registry:GetState(id)`, and `Registry:GetState` starts with `assert(entries[id], 'unknown feature: …')`, so an unknown ID raises instead of returning a message.
- **Doc gap:** README says "`id` is unique for the session. Duplicate registrations are rejected" and "`GetFeatureState(id)` returns the registered feature's state, and also returns an error message on failure."
- **Impact:** A third-party mod using the natural ID `probe` gets a duplicate-registration error for a feature that does not exist, with no way to discover why. A caller of `GetFeatureState('typo')` crashes instead of receiving the promised error message.
- **Recommendation:** Remove `probe` from the pre-seed (dead reservation), or document reserved IDs explicitly. Document `GetFeatureState` as "returns `state, failure`; raises for an unknown ID", or wrap it in `pcall`.
- **Risk of fix:** Removing `probe` changes nothing at runtime (no feature is registered); a mod that already (incorrectly) relies on the rejection would start working.
- **Confidence:** High.

### ARCH-06 — Medium — `ReUI.ClaretHotbuild.RegisterAction` is a public extension point with no documentation and a different lifecycle from Core's registration
- **Location:** `ClaretHotbuild/Main.lua` (return table); `modules/Runtime.lua:RegisterAction`; `modules/Model.lua:RegisterAction`; `AGENTS.md` ("Hotbuild actions: `ReUI.ClaretHotbuild.RegisterAction`").
- **Facts:** `RegisterAction = function(definition) if not service then return false, 'Claret Hotbuild session is not ready' end …`. `Model:RegisterAction` requires `id` (identifier), non-empty `label`, and `execute` function; optional `available`; stores `description`. No `contexts`, no catalog entry, no doc.
- **Doc gap:** Neither README mentions the function, its fields, its return values, or when it becomes available. It cannot be used from `OnPreCreateUI`/`OnPreCreateUI`-time code, unlike Core's deferred `RegisterFeature`.
- **Impact:** A consumer following `AGENTS.md` gets `false, 'session is not ready'` during early init and may treat it as a hard failure; actions registered after the keyboard editor is open may not appear until reopen (no documented refresh guarantee).
- **Recommendation:** Add a short "Extending Hotbuild" section: signature, required fields, availability window (`OnPostCreateUI` or later), duplicate-ID rejection, and that registered actions are runtime-only (not persisted).
- **Risk of fix:** Documentation only.
- **Confidence:** High for the code; Medium for the "not persisted" claim (the action definition is in-memory; only assignments persist).

### ARCH-07 — Medium — The localization service used by both mods is undocumented
- **Location:** `ClaretCore/modules/Localization.lua`; `ClaretHotbuild/Main.lua` (`Localization.Register('hotbuild', tables)`); `Context/localization-glossary.md`.
- **Facts:** Public surface includes `Initialize`, `SetLanguage`, `GetLanguage`, `GetGameLanguage`, `DetectGameLanguage`, `GetPreference`, `Text(key, a, b, c)`, `SearchText`, `Fold`, `Matches`, `Register(namespace, tables)`, `Subscribe(owner, callback)`, `Unsubscribe(owner)`, `Validate`. Hotbuild registers its table at `Main` start and errors if registration fails. Core migrates the saved `language` value `'auto'` to `en`/`ru` once at startup.
- **Doc gap:** Core README mentions only the UI language selector; the glossary says "use Claret's localization service" without naming a single function. `Register`, `Subscribe`, `Unsubscribe` and the `'auto'` migration are not described anywhere.
- **Impact:** A new module either hard-codes strings (against the glossary rule) or re-implements subscriptions; the one-time `'auto'` migration is invisible, so a reader may believe `'auto'` remains a valid stored value.
- **Recommendation:** Add an API block to Core README: `Text`/`SearchText` keys and placeholders, `Register(namespace, {en=…, ru=…})` (unique namespace, called from `Main`), `Subscribe(owner, fn)`/`Unsubscribe(owner)` tied to control destruction, and the stored preference values (`en`, `ru`; `'auto'` migrated on first start).
- **Risk of fix:** None.
- **Confidence:** High.

### ARCH-08 — Medium — `probeEnabled` is a private cross-mod channel and its visibility rule is only half documented
- **Location:** `ClaretCore/Options.lua`; `ClaretCore/Main.lua:Main` (`if rawget(_G, 'REUI_DEV_MODE')`); `ClaretHotbuild/modules/Editor.lua`; `modules/Runtime.lua`; `modules/KeyboardBindings.lua`; `modules/OpenPerf.lua`; both READMEs.
- **Facts:** Hotbuild reads Core's option directly: `ReUI.Options.Mods['ClaretCore'].probeEnabled` in at least five places (editor log, factory-shift log, keymap log, runtime log, OpenPerf gate). Core only creates the toggle when `REUI_DEV_MODE` is set.
- **Doc gap:** Core README describes `probeEnabled` as a Core setting; Hotbuild README describes "Core diagnostics" as the gate for `Building editor` logs. Neither says that the option object is a cross-mod dependency (name, table path, boolean), nor that the toggle is hidden without ReUI developer mode while Hotbuild still honours the stored value.
- **Impact:** Renaming the option or moving it out of `ReUI.Options.Mods['ClaretCore']` silently disables all Hotbuild diagnostics; a user cannot enable the toggle without developer mode, yet a saved `true` keeps logging in normal mode.
- **Recommendation:** Document the contract once (Core README "Diagnostics"): option path, default, visibility rule, and the list of consumers. Treat it as a versioned API, not a private field.
- **Risk of fix:** None for docs; a code-level accessor (`ClaretCore.DiagnosticsEnabled()`) would be cleaner but is optional.
- **Confidence:** High.

### ARCH-09 — Medium — The same rules are restated in five documents and have already diverged
- **Location:** `Context/menu-rules.md`, `ui-style.md`, `quick-reference.md`, `ClaretCore/README.md`, `ClaretHotbuild/README.md`; and `Context/hotbuild-rules.md`, `hotbuild-context-spec.md`, `localization-glossary.md`, `ClaretHotbuild/README.md`.
- **Duplicated clusters and observed divergence:**
  1. **Menu geometry/lifecycle:** 1368×1320 (Core README, quick-reference) vs 1128×1110 + compact Core (ui-style, Theme); "captures clicks outside" vs "never intercept" vs "closes on outside click" (DOC-05).
  2. **Section registration:** four restatements; only Core README lists fields, and that list is incomplete (ARCH-04).
  3. **Context priority:** hotbuild-rules, spec §1, Hotbuild README and quick-reference all restate "Units before Builders, Under cursor first"; still consistent today, but four edit sites.
  4. **Templates:** hotbuild-rules (9 bullets), spec §7/§8, README ("Build templates"), quick-reference 0.8.0 — the 256 limit exists only in README (DOC-06), while the spec still lists a removed action (DOC-13).
  5. **Absolute mode:** spec §5 vs README vs hotbuild-rules decision (DOC-14).
  6. **Key storage:** quick-reference, Core README, Hotbuild README, menu-rules — none mentions the three profile keys (ARCH-03).
- **Impact:** Every behaviour change requires 3–5 edits; the audit already found four places where the copies disagree. Readers cannot tell which copy is authoritative.
- **Recommendation:** Pick one owner per cluster: `menu-rules.md` (menu behaviour/contract), `ui-style.md` (geometry/tokens), `hotbuild-rules.md` (Hotbuild behaviour), Core/Hotbuild README (user onboarding only). Replace repeated rules elsewhere with a one-line link. Keep the chronological decision log in `stage-1-research.md`, not in the index.
- **Risk of fix:** Link rot if files are renamed; use section anchors.
- **Confidence:** High.

### ARCH-10 — Low — Hard-coded section IDs/order and the `accessory` slot are implicit Core–Hotbuild coupling
- **Location:** `ClaretCore/modules/Menu.lua:Create` (`sectionOrder={core=1,hotbuild=2,ui=3,cinema=4}`, placeholder list, `section.accessory`).
- **Facts:** Core pre-creates disabled placeholders for `core`, `hotbuild`, `ui`, `cinema`; `hotbuild` is replaced when Hotbuild registers its section. `section.accessory` is supported by the renderer but no section provides one, while `menu-rules.md` still describes Hotbuild gear settings.
- **Doc gap:** Nothing says these IDs are reserved, that `hotbuild` is a placeholder for this mod, or that `accessory` exists and is unused.
- **Impact:** A third-party section named `ui` or `cinema` silently replaces the disabled placeholder — it inherits the reserved slot and can change the visible launcher title/order that Core's rank table fixed — while the author has no way to know the ID was reserved. A maintainer may delete `accessory` code as dead and then wonder why the documented gear is gone.
- **Recommendation:** Document reserved IDs and ordering in Core README (or remove unused placeholders). Delete the `accessory` renderer and the menu-rules sentence if no section will use it.
- **Risk of fix:** Removing placeholders changes launcher ordering for current users (Core/Hotbuild sections are inserted by rank anyway).
- **Confidence:** High for the code; Low for whether `accessory` is planned.

---

## 3. Potential risks requiring validation

### RISK-01 — Medium — The 256-building template limit may be an intended safety bound that is missing from code
- **Basis:** DOC-06. `TemplateCatalog` accepts up to 4096 entries; no other module checks a size. `Adapter:CanBuild` then loops all entries per selected engineer on every availability query (cached per press in `context.plans`).
- **Risk:** A 4000-building template from a malicious/corrupt profile causes a long availability loop and a large `SetActiveBuildTemplate` payload. The README's 256 may be a forgotten mitigation.
- **Validation:** Create a synthetic large `build_templates` entry (or inspect one) and measure `CanBuild` time; decide whether to enforce 256/512 in `Parse`.
- **Confidence:** Medium — absence of the check is proven; intent is not.

### RISK-02 — Low — Perf probes may be measuring with the fallback clock
- **Basis:** DOC-11. `OpenPerf` prefers `GetSystemTimeSecondsOnlyForProfileUse`, which `tech-findings.md` says does not exist in UI context.
- **Risk:** `[Claret][perf]` numbers come from `GetSystemTimeSeconds` (a different clock granularity), and a future client build that exposes the profile-only function would silently change the metric, breaking comparisons across builds.
- **Validation:** Run one session with `probeEnabled` and read `[Claret][perf] init gate=… timer=…`; record the resolved clock in `performance-hotspots.md`.
- **Confidence:** Medium.

### RISK-03 — Medium — Outside-click behaviour needs one in-game check before the docs are rewritten
- **Basis:** DOC-05. The code has no catcher (`root:DisableHitTest()`), but the engine's root frame or another mod could still consume/route the click, and the original 0.9.0 note may describe a deliberate design that was later removed.
- **Risk:** Writing "clicks pass to the map" into `menu-rules.md` could be wrong if FAF's `GetFrame(0)` swallows them.
- **Validation:** One scenario in a new match: open the menu, click on the map outside both panels, record whether a move/attack order is issued, whether the menu closes, and whether the game camera changes. Then fix the docs once.
- **Confidence:** High that the code lacks a catcher; Medium about the observable result.

### RISK-04 — Low — "Build N" numbering convention is undefined
- **Basis:** DOC-15/DOC-17. `BuildStamp` is `20261117-143`, CHANGELOG's newest entry is `20261117-147`, and `stage-1-status.md` calls the current build 147. It is not written anywhere whether the CHANGELOG number is the planned release, the commit count, or the stamp.
- **Risk:** Future builds repeat the same drift; every audit re-discovers it.
- **Validation:** Ask the user which number is authoritative; record the rule next to the `BuildStamp` line in `Main.lua` and in the CHANGELOG header.
- **Confidence:** High that the convention is undocumented; the correct convention is a user decision.

---

## 4. Optional improvements (documentation work, prioritized)

### P0 — do first (user-visible correctness)
1. **Fix the four behavioural lies:** Hotbuild `enabled` (DOC-01), row arrows (DOC-04), outside click (DOC-05), HUD marks (DOC-07). These are the sentences a tester acts on.
2. **Fix both version banners and install lines** (DOC-02, DOC-03) and add the rule "heading version = `Version` in `Main.lua`".
3. **Reconcile build identity** (DOC-15, DOC-16, DOC-17): one build number in `BuildStamp`, CHANGELOG and status; manifest `ReUI` value equal to `Version`.

### P1 — load-bearing contracts (prevents silent breakage)
4. **Add a "Lifecycle" section to Core README** (ARCH-01) and a "Hook contracts" block to `dependency-map.md` (ARCH-02), including `MenuKey.Open`.
5. **Add a "Saved data" section to Hotbuild README** (ARCH-03): three profile keys, versions 1/2/3, migration, corrupt-profile write block.
6. **Replace the `RegisterSettingsSection` field list with a table** (ARCH-04), including `onMenuClosed`, `selectors`, `setHeight`, `AfterParentShow`, `open(parent, layout)`, `accessory`, reserved IDs.
7. **Document `RegisterFeature` reserved IDs and `GetFeatureState` error semantics** (ARCH-05), and `RegisterAction` (ARCH-06).
8. **Document the localization API and the `'auto'`→`en/ru` migration** (ARCH-07).

### P2 — structure and drift prevention
9. **One owner per rule cluster** (ARCH-09): menu behaviour → `menu-rules.md`; geometry/tokens → `ui-style.md`; Hotbuild behaviour → `hotbuild-rules.md`; READMEs stay onboarding-only. Replace copies with links.
10. **Mark `hotbuild-context-spec.md` as a historical target spec** (header: "Superseded by the 2026-11-14 update and build 20261113-30; kept for ID history") and move DOC-12/DOC-13/DOC-14 items to a "Removed/legacy" block.
11. **Restructure Core README** into "What it is → Install → Menu → Extending → Saved data → History"; move 0.5–0.9 sections to a `HISTORY.md` or the end under one heading (DOC-08, DOC-18).
12. **Delete or relabel `Context/feature-catalog.md`** — it contains only reference-mod features, not Claret features; add a Claret section or rename it and say so in the first line.
13. **Add Claret edges to `Context/dependency-map.md`** (`ClaretHotbuild → ClaretCore`, `ClaretHotbuild → ReUI`, `ClaretCore → ReUI`) and the three profile-key storage edges.
14. **Add a doc check to `Tests/`** (or a tiny script under `.tools/`): assert `README` heading version == `Main.lua` `Version` == `mod_info.ReUI` suffix; assert `BuildStamp` == newest CHANGELOG build; fail with the differing values.
15. **Give every `Context/*.md` a two-line header**: "Verified against Core X / Hotbuild Y on date; scope; owner." This turns future drift into a visible date instead of an archaeological exercise.
16. **Update the glossary** (`localization-glossary.md`): mark `quick repeat` and `fallback action` as legacy-only runtime fields; add `pair`, `preset`, `multifunction set`, `context tile`, `obsolete`, `under cursor` with the exact UI wording.
17. **Resolve the dead quick-repeat settings code**: either register `QuickRepeatSettings` through a real option and a section `accessory`, or delete `QuickRepeatMenu.lua`/`QuickRepeatSettings.lua` and the menu-rules gear sentence (DOC-12).

### Table of minimal edits (copy-ready)
| # | File | Edit |
|---|---|---|
| 1 | `ClaretHotbuild/README.md` | title 0.10.14 → 0.10.36; "Core 0.10.0" → "Core 0.10.5"; delete "A previously saved disable option is ignored"; replace "no arrows" sentence; replace "maximum of 256" or add the code check; replace outside-click sentence with a link |
| 2 | `ClaretCore/README.md` | title 0.10.1 → 0.10.13; "Hotbuild 0.10.1 requires Core >= 0.10.0" → "Hotbuild 0.10.36 requires Core >= 0.10.5"; delete "captures clicks"; replace HUD-marks sentence; delete 1368×1320; add Lifecycle / Settings-section / Localization / Data sections |
| 3 | `Stage/stage-1-status.md` | "build 20261117-147" → "build 147 code, `BuildStamp` 143 (stale)"; add manifest 0.10.37 note |
| 4 | `ClaretHotbuild/Main.lua` | `BuildStamp = '20261117-147'` (or status corrected) |
| 5 | `ClaretHotbuild/mod_info.lua` | `ReUI = 'ClaretHotbuild=0.10.36'` |
| 6 | `ClaretHotbuild/CHANGELOG.md` | add 142/143 entries or an "interim builds" line |
| 7 | `Context/tech-findings.md` | rewrite `rawget` rule with observed exceptions; mark the profile-only timer claim as dated/unverified |
| 8 | `Context/quick-reference.md` | delete 1368×1320, the 0.8.0/0.9.0 menu bullets and the 0.10.9 snapshot; point to `stage-1-status.md` |
| 9 | `Context/ui-style.md` | 552×436 → 552×408 (or reference `Theme.Metrics`) |
| 10 | `Context/hotbuild-context-spec.md` | mark superseded; move repeat-window/absolute/create_template_factory to a legacy block |
| 11 | `Context/menu-rules.md` | delete the "gear settings" sentence unless `accessory` is wired |
| 12 | `Context/localization-glossary.md` | mark `quick repeat`/`fallback` as legacy-only |

---

## Not verified / out of scope

- **No test run.** `node Tests/check-core.cjs --quiet` was not executed in this task; the known baseline (47 passed, 15 failed) is taken from the shared briefing, not re-measured.
- **No in-game check.** Every statement about rendering, click routing, HUD marks, keyboard capture and engine API availability is a code reading, not an observation.
- **Reference mods.** `feature-catalog.md`, `mod-inventory.md`, `dependency-map.md` (third-party edges), `reui-notes.md` (ReUI internals) and `performance-hotspots.md` (file:line citations for other mods) could not be checked against `Context/sources/` because that folder is forbidden for this audit. Only their internal consistency and their Claret-relevant claims were reviewed; no defect was found in them beyond the scope issue noted in Section 4, item 12.
- **Not audited:** translation quality of the recently translated `Context/*.md` (explicitly excluded), `Stage/stage-1-research.md`, `Context/compiled-lua.txt`, `Claret Core/` (old draft), `mods/` mirrors.
