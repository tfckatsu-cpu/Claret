# Claret — UI consistency audit (ClaretCore + ClaretHotbuild)

Audit date: 2026-11-18. Read-only audit; this file is the only artefact written.

Code base: workspace `ClaretCore/` (Core 0.10.13, stamp 20261117-45) and `ClaretHotbuild/`
(Hotbuild 0.10.36, `mod_info.version = 73`), byte-identical to the live mods per the batch briefing.
Spec used as the yardstick: `Context/ui-style.md` and `Context/menu-rules.md` (read in full first),
tokens from `ClaretCore/modules/Theme.lua`.

Evidence tiers, used explicitly in every entry:

- **Fact** — quoted from a file I opened in this run, or from a tool output reproduced here.
- **Assumption** — reasoned from that code, not executed.
- **Unknown** — needs an in-game check or a file I did not open.

Nothing here was run in FAF. No in-game screenshots were taken. Tooling used (read-only):
`Select-String` / `rg` over `ClaretCore/`, `ClaretHotbuild/`, `Tests/`; one in-memory read of
`C:/ProgramData/FAForever/gamedata/lua.nx2` entries `lua/ui/game/tooltip.lua` (to verify FAF tooltip
ownership); `Context/reui-decompiled/` for one `StatusBar` call-shape comparison.

---

## 0. Scope, method, and what is clean

UI-bearing modules examined (14 files that construct Maui controls, plus their Core hosts):

| File | Control-creating call sites (count of `Group/Bitmap/Text/Button/Checkbox/Edit/Grid/StatusBar(`) |
|---|---|
| `ClaretHotbuild/modules/KeyboardEditor.lua` | 109 |
| `ClaretHotbuild/modules/ContextEditor.lua` | 76 |
| `ClaretHotbuild/modules/Editor.lua` | 56 |
| `ClaretCore/modules/ConstructionPanelShell.lua` | 45 |
| `ClaretCore/modules/Menu.lua` | 43 |
| `ClaretCore/modules/Welcome.lua` | 13 |
| `ClaretCore/modules/MultifunctionShell.lua` | 11 |
| `ClaretCore/modules/OrdersPanelShell.lua` | 10 |
| `ClaretHotbuild/modules/Navigator.lua`, `QuickRepeatSettings.lua` | 8 each |
| `ClaretCore/modules/SelectionSummary.lua`, `ConstructionItemsView.lua` | 5 each |
| `ClaretHotbuild/modules/CycleMenu.lua`, `QuickRepeatMenu.lua` | 4 / 3 |

Also read for context: `Theme.lua`, `Lifecycle.lua`, `Localization.lua`, `MenuKey.lua`, `Registry.lua`,
`Main.lua` (both mods), `Options.lua` (both), `OrdersPanel.lua`, `ConstructionPanel.lua`,
`ReUICargoIndicator.lua`, `Keys.lua`, `Runtime.lua` (window open/close paths), `StrategicRings.lua`
(ring renderer only), `ConstructionCargoView.lua`.

**Checked and clean** (worth stating so the parent does not re-audit them):

- **Palette.** Every Claret panel colour comes from `Theme.Colors`. The only raw ARGB literals in
  either mod are texture tints and native-icon modulation: `'00000000'` / `'ffffffff'` in
  `ConstructionItemsView.lua` and `ConstructionCargoView.lua`, `'ffff9000'` for the native build-key
  count, `'ffff0000'` for the low-fuel wash, and `'00000000'` for the picker overlay in `Editor.lua`.
  No module defines its own palette. Count of `Color(` matches outside `Theme.lua` = 0 (all matches
  were `SetColor(`).
- **Fonts.** No module hardcodes a font name. `Theme.Fonts.body` / `.heading` are used everywhere,
  with one deliberate exception: `ConstructionItemsView.lua:274` uses `UIUtil.bodyFont` to match the
  native construction grid it decorates.
- **Localization coverage.** 54 Core keys and 637 Hotbuild keys; EN/RU sets are exactly symmetric in
  both dictionaries (scripted comparison, 0 missing on either side). Every `T('…')` literal used in
  code resolves to a defined key (the two apparent misses, `hotbuild.context.` and
  `hotbuild.domain_header.`, are prefix concatenations, and all suffixes they produce exist).
- **Persisted geometry.** No window size or position is written to the profile; menu geometry lives
  in per-session `memory` only, which matches `ui-style.md` ("retain their positions within the
  current match").
- **Tooltip registry.** FAF's `AddControlTooltip` does not keep a control registry — it wraps
  `control.HandleEvent` (`lua.nx2:lua/ui/game/tooltip.lua:355-367`), so repeatedly adding tooltips to
  recreated rows (`ContextEditor` catalog, `Editor` picker) does not leak entries.
- **Frame-update hygiene, mostly.** The theme animation (`Theme.lua:63-73`), the menu transition
  (`Menu.lua:290-302`), `CycleMenu` (`Hide`/`Destroy`), and the transient status timer
  (`Menu.lua:232-240`) all stop their frame update. The only always-on loop is
  `KeyboardEditor.lua:786-792`, which is the documented physical-modifier poll.
- **Menu drag/scale arithmetic.** Checked line by line because it is the classic double-scale trap and
  it is correct: stored offsets are screen pixels (`position.x` comes from `event.MouseX` deltas in
  `Menu.lua:272-277`), `PlacePanel` converts once by dividing (`L(owner):AtLeftTopIn(group,position.baseX+position.x/scale,position.y/scale+…)`,
  `Menu.lua:255-256`), and `ClampPosition` clamps in the same screen space using
  `position.width*scale` (`Menu.lua:258-263`). Panel widths/heights stay in logical units
  (`L(state.panel):Width(state.panelWidth)`, `Menu.lua:353`) and are never divided again. No double
  application found. The per-entry-point *scale selection* still differs — see UI-33.

---

## 1. Confirmed defects

### UI-01 — Quick-repeat time-window UI is unreachable; the documented Hotbuild gear/window path is not wired

- **Severity:** High
- **Category:** UI / Architecture
- **Location:** `ClaretHotbuild/modules/QuickRepeatMenu.lua` (whole file),
  `ClaretHotbuild/modules/QuickRepeatSettings.lua` (whole file),
  `ClaretCore/modules/Menu.lua:427-440` (`Launch`), `ClaretHotbuild/Main.lua:76-113`
  (`RegisterSettingsSection`), `ClaretHotbuild/Options.lua:1-3`.
- **Problem:** `QuickRepeatMenu.Create(parent, scale, option)` builds a 1080×240 standalone window and
  the only thing it renders is `QuickRepeatSettings`, which edits `option` = the global quick-repeat
  time window. No file in either mod imports `QuickRepeatMenu`. Its third argument (a ReUI option)
  does not exist either: `Options.lua` declares only `enabled`; the only place a `quickRepeatWindow`
  option is defined is a test fixture that injects it before loading `Main.lua`. Independently,
  `Menu.lua` renders a gear (⚙) for a section only when that section was registered with
  `accessory = { open = … }`, and no `RegisterSettingsSection` call in either mod sets `accessory`
  (or `actions`). So both the gear and the 384×232 accessory panel are unreachable code, while
  `menu-rules.md` states the flow as a requirement: "Hotbuild gear settings open in the right-hand
  panel next to the menu, with the standard opening animation".
- **Evidence:**
  - `QuickRepeatMenu.lua:1-3`: `-- Standalone quick-repeat settings window, opened from the Hotbuild launcher gear.`
    / `function Create(parent, scale, option)` … `if … type(scale) ~= 'number' or not option then return nil end`.
  - `ClaretHotbuild/Options.lua:1-3`: `ReUI.Options.Mods['ClaretHotbuild'] = {` / `enabled = ReUI.Options.OptionValue(true),` / `}`.
  - `rg -i quickrepeat ClaretCore ClaretHotbuild` → only `ContextEditor`/`ContextModel` per-context
    `quickRepeat` *action* fields (a different feature) and these two modules. `Tests/claret-menu.lua`
    injects `addonEnv.ReUI.Options.Mods.ClaretHotbuild.quickRepeatWindow={Get=…}` before
    `loadfile('…/Main.lua')`, i.e. the harness still expects a wiring that no longer exists.
  - `Menu.lua:761`: `local hasAccessory=section.accessory and type(section.accessory.open)=='function'`;
    `rg "accessory\s*="` → only `Menu.lua` (413, 428, 771) and no registration.
- **Impact:** a documented settings entry point does not exist in the shipped UI; 12 localized strings
  (`hotbuild.repeat.*`) and two modules are dead weight; the module's `nil` return path means even a
  future caller gets `nil` instead of an error, so the failure would be silent.
- **Recommendation:** decide with the user: either re-register the gear
  (`accessory = { titleKey = …, open = … }` on the Hotbuild section, restoring the ReUI option for the
  repeat window) or delete `QuickRepeatMenu.lua`/`QuickRepeatSettings.lua` and their strings. Do not
  keep the half-state.
- **Risk of the fix:** low for deletion; moderate for re-wiring (needs the option to be re-added to
  `Options.lua` with a stable profile key, and the gear path needs an `AttemptLeave` review — see
  UI-13).
- **Confidence:** High for "no caller / no option"; Medium for "intended as the gear target" (that
  part rests on the file comment plus `menu-rules.md`).

### UI-02 — ContextEditor dialogs use frozen depths while the host panel's depth changes by ±1000

- **Severity:** Medium
- **Category:** UI / Correctness
- **Location:** `ClaretHotbuild/modules/ContextEditor.lua:218-229, 242-253, 335-341, 362-372`,
  versus `ClaretCore/modules/Menu.lua:308-312, 340, 366`.
- **Problem:** `Menu` draws the launcher and the settings panel as siblings and raises one of them by
  +1000 on every header press (`state.RaiseWindow`). An embedded page therefore lives under a depth
  that changes at runtime. `ContextEditor` computes its dialog depths **once, as numbers**
  (`conflictOverlay.Depth:Set(frame.Depth()+80)`), so a dialog opened while the panel is *not* raised
  keeps that low absolute depth after the panel is raised — and renders behind the panel it belongs
  to. `KeyboardEditor` does the same thing with closures and is immune.
- **Evidence:**
  - `Menu.lua:340`: `state.panel.Depth:Set(function() return group.Depth()+(state.frontWindow=='panel' and 1000 or 0) end)`
  - `Menu.lua:308-312`: `state.RaiseWindow=function(owner)` … `if owner==state.launcher then state.frontWindow='launcher'` …
  - `Menu.lua:366`: `state.panelDragHeader=DragHeader(state.panel,width-72,panelPosition)` — a header
    ButtonPress calls `state.RaiseWindow(owner)`.
  - `ContextEditor.lua:220`: `conflictOverlay=Panel(frame,0,0,1080,920,C.transparent); conflictOverlay.Depth:Set(frame.Depth()+80)`
  - `ContextEditor.lua:226`: `conflictDialog=Group(frame); … conflictDialog.Depth:Set(frame.Depth()+90)`
  - Counter-example, `KeyboardEditor.lua:359`: `env.uiState.overlay=Panel(frame,0,0,1080,920,C.transparent); env.uiState.overlay.Depth:Set(function() return frame.Depth()+80 end)`
- **Impact:** reachable with ordinary clicks: drag the launcher header once (panel drops to
  `group+0`), open a Contexts draft dialog (frozen at ≈ frame+80), then press the panel header to
  raise it (+1000) — the dialog is now below the panel and invisible, while still holding the mouse
  (its overlay still swallows clicks over the whole 1080×920 page).
- **Recommendation:** replace the frozen numbers in `ContextEditor` with the same closures
  `KeyboardEditor` uses (`function() return frame.Depth()+80 end`). Mechanical, 8 call sites.
- **Risk of the fix:** very low (no layout change; only depth resolution timing).
- **Confidence:** High on the divergence and the arithmetic; Medium on the visual outcome (not
  reproduced in game — depth ordering is FAF-side, not exercised here).

### UI-03 — The same file mixes frozen and live dialog depths (Editor leave dialog)

- **Severity:** Medium
- **Category:** UI / Correctness
- **Location:** `ClaretHotbuild/modules/Editor.lua:333-334, 343`, `366`, `369`.
- **Problem:** `Editor` uses closures for the compatibility dialog but plain numbers for the leave
  dialog, inside the same function, ~20 lines apart. The leave dialog is the one that carries draft
  protection, i.e. the one that must stay visible.
- **Evidence:**
  - `Editor.lua:334`: `compatibilityOverlay.Depth:Set(function() return frame.Depth()+90 end)`
  - `Editor.lua:343`: `compatibilityDialog.Depth:Set(function() return frame.Depth()+100 end)`
  - `Editor.lua:366`: `leaveOverlay=Panel(frame,0,0,1080,920,C.transparent); leaveOverlay.Depth:Set(frame.Depth()+80)`
  - `Editor.lua:369`: `leaveDialog=Group(frame); L(leaveDialog):AtCenterIn(frame):Width(dialogWidth):Height(dialogHeight); leaveDialog.Depth:Set(frame.Depth()+90)`
- **Impact:** same failure mode as UI-02 for the "unsaved changes" prompt.
- **Recommendation:** use closures for 366/369 (and audit `ContextEditor` at the same time).
- **Risk of the fix:** none observed.
- **Confidence:** High (Fact: two different forms in one function).

### UI-04 — Welcome "do not show again" checkbox signals its state by colour only

- **Severity:** Medium
- **Category:** UI
- **Location:** `ClaretCore/modules/Welcome.lua:227-253`.
- **Problem:** `ui-style.md` §Components requires: "Toggles and checkboxes: distinguish on and off
  states with a symbol or text as well as color". The menu toggle does this (`●` / `○`,
  `Menu.lua:531-533`), the welcome checkbox does not — it only swaps fill and border colours, and the
  border difference (`accentText` vs `border`) is itself subtle at 24×24.
- **Evidence:**
  - `Welcome.lua:241-244`: `local function UpdateCheckbox()` / `local checked = dismissedOption and dismissedOption:Get() == true` / `box:SetSolidColor(checked and C.accent or C.surface)` / `setBoxBorder(checked and C.accentText or C.border)`
  - Contrast, `Menu.lua:533-534`: `stateLabel:SetText(value and '●' or '○')` / `stateLabel:SetColor(value and C.accentText or C.muted)`.
- **Impact:** the one place a first-time user sets a persistent preference (whether this window keeps
  appearing) has the weakest state indication in the mod; also fails for colour-blind users.
- **Recommendation:** add a `✓`/`·` glyph inside the box, same pattern as the menu toggle. No layout
  change needed (24×24 box, text at 36 px offset).
- **Risk of the fix:** none (one Text control).
- **Confidence:** High (spec violation is textual; both quotes are verbatim).

### UI-05 — Navigator page tabs lack the selected-section bar that the launcher uses

- **Severity:** Medium
- **Category:** UI
- **Location:** `ClaretHotbuild/modules/Navigator.lua:57-64` versus `ClaretCore/modules/Menu.lua:805-807`.
- **Problem:** `ui-style.md` §Navigation: "mark the selected section with a dark burgundy surface and
  a narrow bar". The launcher row does exactly that; the Hotbuild page strip (Keyboard / Hotbuild /
  Contexts) is the same *kind* of control — a section switcher — and marks selection only with
  fill + border + label colour.
- **Evidence:**
  - `Menu.lua:805-807`: `if item.selected then Surface(item.control,0,0,4,40,C.accent):DisableHitTest()` /
    `else item.paint() end` / `item.paint()`
  - `Navigator.lua:60-63`: `item.control:SetSolidColor(active and C.selected or C.raised)` /
    `item.outline(active and C.selectedBorder or C.border)` /
    `item.label:SetColor(active and C.accentText or C.text)`
- **Impact:** two visually different "selected tab" treatments one click apart in the same window; the
  Hotbuild strip reads as a plain button row and the selected page is only distinguishable by colour
  (which the same spec forbids: "The selected state must be recognizable without color alone").
- **Recommendation:** add the same 4×40 accent strip inside the selected Navigator tab (and keep the
  fill/border logic). Purely additive.
- **Risk of the fix:** low; the strip must be created inside the tab control so it is destroyed with
  the tab (`Navigator` recreates tabs only once, at build time, so no leak).
- **Confidence:** High (both quotes; spec text explicit).

### UI-06 — The three Hotbuild pages have three different headers (2 px drift, one missing accent bar, one unlocalized title)

- **Severity:** Medium
- **Category:** UI
- **Location:** `ClaretHotbuild/modules/Editor.lua:543`,
  `ClaretHotbuild/modules/ContextEditor.lua:162-163`,
  `ClaretHotbuild/modules/KeyboardEditor.lua:221`.
- **Problem:** The three sibling pages in the same navigator should share a header block. Observed:
  Editor — accent bar at (24,18) size 4×22, title at (40,14) size 22, literal `'Hotbuild'`;
  ContextEditor — accent bar at (24,20) size 4×24, title at (40,16) size 22, localized;
  KeyboardEditor — no accent bar at all, title at (24,16) size 22, localized. Subtitle lines are 14 px
  in Editor and 15 px in ContextEditor, both at y≈54/67.
- **Evidence:**
  - `Editor.lua:543`: `Panel(frame,24,18,4,22,C.accent):DisableHitTest(); Text(frame,'Hotbuild',40,14,22)`
  - `ContextEditor.lua:162-163`: `Panel(frame, 24, 20, 4, 24, C.accent):DisableHitTest()` / `Text(frame, T('hotbuild.context_editor.s001'), 40, 16, 22)`
  - `KeyboardEditor.lua:221`: `Text(frame,'hotbuild.keyboard.title',24,16,22)`
- **Impact:** switching pages shifts the title and the left rule by 2 px and removes the accent bar on
  one page; since the pages are swapped in place inside one fixed panel, this reads as a layout jump.
  The literal `'Hotbuild'` is also the only user-visible string in either mod that is neither a key nor
  a glyph (the word is a proper noun, but the two sibling pages localize their titles).
- **Recommendation:** extract one header helper into `Theme`/`Navigator` (bar 4×24 at y=20, title 22 at
  (40,16)), use a `titleKey` for the Editor page (`hotbuild.section.title` already exists and equals
  `'Hotbuild'`).
- **Risk of the fix:** low; the y-offset change moves the Editor's first content row by 2 px only if
  that row is anchored to the header (it is not — rows start at y=67/136).
- **Confidence:** High (verbatim coordinates).

### UI-07 — KeyboardEditor bypasses the module's own localization accessor 42 times and declares `T` twice

- **Severity:** Medium
- **Category:** Maintainability / UI
- **Location:** `ClaretHotbuild/modules/KeyboardEditor.lua:1-6` and `84-89` (two `local function T`),
  plus 42 inline `ReUI.ClaretCore.Localization.Text(...)` calls in the same file.
- **Problem:** Every other UI module uses one `T()` wrapper that degrades gracefully when Core is
  absent (returns the key). `KeyboardEditor` has *two* identical file-level `T` declarations (the
  second shadows the first, so one is dead) and 42 call sites that skip `T` entirely and index
  `ReUI.ClaretCore.Localization.Text` directly — which errors if `ReUI.ClaretCore` or
  `Localization` is missing, and ignores the `first/second/third` argument path in exactly the strings
  that need it.
- **Evidence:**
  - `KeyboardEditor.lua:1-6`: `local function T(key, first, second, third)` / `local core = ReUI and ReUI.ClaretCore` / `local localization=core and core.Localization` / `if localization and type(localization.Text)=='function' then return localization.Text(key, first, second, third) end` / `return key` / `end`
  - `KeyboardEditor.lua:84-89`: byte-identical re-declaration.
  - `KeyboardEditor.lua:370`: `Text(box,ReUI.ClaretCore.Localization.Text('hotbuild.keyboard_editor.s001')..key..(combo~='' and (' · '..combo) or ''),24,18,20)`
  - Measured: `rg -c 'ReUI\.ClaretCore\.Localization\.Text'` → `KeyboardEditor.lua` 42, all other files 0;
    `T(` call count in the same file: 28.
- **Impact:** two access paths for one concern in one page; the dead duplicate invites editing the
  wrong copy; the direct path removes the only guard the module has against a Core version mismatch.
- **Recommendation:** delete the first `T` (keep one), replace the 42 direct calls with `T(...)`.
  Mechanical; no string changes.
- **Risk of the fix:** low, but the file is 51 KB — do it as a pure textual substitution and diff.
- **Confidence:** High (counts and quotes reproduced).

### UI-08 — `Theme.Metrics` is under-specified and three of its tokens are never used

- **Severity:** Medium
- **Category:** Maintainability / UI
- **Location:** `ClaretCore/modules/Theme.lua:38-43`.
- **Problem:** The token set covers widths, heights, `text`, `secondaryText`, `buttonText`,
  `launcherText`, `padding`, `rowHeight`, but has **no** heading/title/caption size, so every heading
  is a literal (22, 20, 18, 16, 15, 14, 13, 12, 11 appear across the two mods). Three declared tokens
  (`padding`, `secondaryText`, `rowHeight`) are referenced by **nothing**, while the same values are
  typed as literals (24 for padding in every panel; 13/14 for secondary text). Net effect: the token
  file looks like the palette source of truth but is only partially consulted.
- **Evidence:**
  - `Theme.lua:38-43`: `Metrics = { launcherWidth=248, launcherHeight=400, panelWidth=1128, panelHeight=1110,` / `corePanelWidth=552, corePanelHeight=408, coreCardWidth=520, coreRowHeight=56,` / `coreRowStep=64, coreControlHeight=56,` / `panelGap=16, padding=24, text=16, secondaryText=14, buttonText=15, launcherText=18,` / `rowHeight=40, buttonHeight=36, fieldHeight=36 }`
  - `rg "secondaryText|Metrics.padding|Metrics.rowHeight"` → only the definition line.
  - Literal headings, examples: `Menu.lua:368 state.title:SetFont(Theme.Fonts.heading,22*ratio)`;
    `ContextEditor.lua:163 Text(frame, T('hotbuild.context_editor.s001'), 40, 16, 22)`;
    `KeyboardEditor.lua:221 … 24,16,22`; `Editor.lua:632 Text(frame,T('hotbuild.editor.buildings'),24,136,18)`;
    `Welcome.lua:161 BindLabel(titleBox, 'core.welcome.title', Theme.Fonts.heading, 24, C.text)`.
- **Impact:** a spec-driven reviewer cannot change heading sizes in one place; the mismatch between
  `ui-style.md` guidance ("headings 18–22", "explanations 13–14") and the code is invisible until
  someone reads 14 files.
- **Recommendation:** add `heading=22, subheading=18, caption=13` (and use the existing
  `secondaryText`) to `Metrics`, then replace literals file by file. Keep values identical so no
  visual change ships with the refactor.
- **Risk of the fix:** zero visual risk if values are preserved; moderate diff size.
- **Confidence:** High for the facts; the "under-specified" reading is my judgement.

### UI-09 — Untranslated `'fallback'` label shown in ContextEditor's obsolete-action list

- **Severity:** Medium
- **Category:** UI
- **Location:** `ClaretHotbuild/modules/ContextEditor.lua:846-848`.
- **Problem:** The obsolete-row label concatenates a localized field name for `action` and
  `quickRepeat`, but for the third field (`fallback`) it falls through to the raw English identifier.
- **Evidence:** `ContextEditor.lua:846-848`:
  `local fieldLabel=field=='action' and T('hotbuild.context_editor.s076')` /
  `or (field=='quickRepeat' and T('hotbuild.context_editor.s077') or 'fallback')` /
  `table.insert(result,{id=id,label=T('hotbuild.context_editor.s078')..fieldLabel..' · '..ContextLabel(row.context)..' · '..(action and ActionLabel(action) or id),…})`
- **Impact:** the Russian UI shows a mixed-language row ("Устарело: fallback · …"). Small, but it is
  the only untranslated string in a fully translated file, and it is in the surface where the user
  decides whether to delete stored data.
- **Recommendation:** add `hotbuild.context_editor.s… = 'Fallback' / 'Резерв'` and use `T(...)`, or
  reuse `s077`'s neighbour. One-line change plus two dictionary entries.
- **Risk of the fix:** none.
- **Confidence:** High (verbatim).

### UI-10 — SelectionSummary ignores UI scale and uses bare pixel geometry

- **Severity:** Medium
- **Category:** UI
- **Location:** `ClaretCore/modules/SelectionSummary.lua:11-22`.
- **Problem:** Every other Claret element multiplies logical sizes by `scale / GetPixelScaleFactor()`.
  This panel is positioned and sized in raw screen pixels (`320×64` at `20,254`), uses
  `ReUI.UI.FloorLayoutFor` (no scale) and font sizes `14` / `13` without a ratio, so it does not track
  the game's UI scale at all — while `ui-style.md` says "Always respect UI scale when computing,
  saving and restoring sizes/positions" and calls SelectionSummary-like overlays Claret UI.
- **Evidence:** `SelectionSummary.lua:11-19`: `local panel = scope:Own(Bitmap(parent))` /
  `Localization.Text('core.selection.title'), 14, Theme.Fonts.body` /
  `local text = UIUtil.CreateText(panel, '', 13, Theme.Fonts.body)` /
  `LayoutFor(panel):AtLeftTopIn(parent, 20, 254):Width(320):Height(64)`.
  Contrast `Menu.lua:163-165`: `local t=UI.CreateText(owner,value,metrics.text*ratio,Theme.Fonts.body)`.
- **Impact:** at UI scale ≠ 1.0 the box is the wrong physical size relative to the native selection
  panel it sits above, and at 4K it becomes proportionally tiny; 13 px body text at scale 1.0 is
  already below the spec's 15–16.
- **Recommendation:** convert to `ReUI.UI.FloorLayouter(scale)` with `Theme.Metrics.text`/
  `secondaryText`, and derive the anchor from the native panel instead of the constant 254. (The
  constant itself is a second-order issue: it is a fixed offset from the screen top.)
- **Risk of the fix:** low; the panel is an opt-in diagnostic. Verify on one non-1.0 UI scale.
- **Confidence:** High for the divergence; the exact intended anchor is **Unknown** (no spec line).

### UI-11 — Menu leaves FAF's `mouseoverDisplay` upvalue pointing at a destroyed control

- **Severity:** Low
- **Category:** UI / Correctness
- **Location:** `ClaretCore/modules/Menu.lua:116-126` (teardown), tooltip call sites `Menu.lua:231-232, 653-655`.
- **Problem:** `Menu` is the only Claret window that adds tooltips and never calls
  `Tooltip.DestroyMouseoverDisplay()` on teardown. FAF's tooltip module keeps one module-level
  `mouseoverDisplay` and parents the tooltip control to the *hovered control*
  (`lua.nx2:lua/ui/game/tooltip.lua:20, 43-46, 160-163, 166-167`), with no `IsDestroyed` guard. Closing
  the menu with the bind while a tooltip is up destroys the tooltip control but leaves the upvalue set;
  the next hover in the game re-enters `CreateMouseoverDisplay`, which calls
  `mouseoverDisplay:Destroy()` on the already-destroyed control.
- **Evidence:**
  - `Menu.lua:116-126`: `local oldDestroy=root.OnDestroy` / `root.OnDestroy=function(self)` / `Unbind()` /
    `Localization.Unsubscribe(root)` / `if state.escapeBound then Escape.PopEscapeHandler(); state.escapeBound=false end` … (no tooltip call)
  - `Editor.lua:184-187`: `frame.OnDestroy=function(self)` / `if CloseCompatibilityDialog then CloseCompatibilityDialog() end` /
    `Tooltip.DestroyMouseoverDisplay(); oldDestroy(self)`
  - `ContextEditor.lua:73-77` and `KeyboardEditor.lua:127-133` do the same.
  - FAF: `function DestroyMouseoverDisplay()` / `if createThread then KillThread(createThread) end` /
    `if mouseoverDisplay then mouseoverDisplay:Destroy(); mouseoverDisplay = false end`.
- **Impact:** depends on Maui's tolerance of a second `Destroy`; worst case a Lua error in the tooltip
  path on the next hover, best case a silent no-op. Either way the teardown practice is inconsistent
  with the three editors.
- **Recommendation:** add `Tooltip.DestroyMouseoverDisplay()` to `Menu.lua`'s `OnDestroy` (one line,
  same position as in `Editor`).
- **Risk of the fix:** none.
- **Confidence:** Medium — the FAF mechanism is read and quoted; whether the double `Destroy` errors is
  **Unknown** (needs an in-game hover/close sequence).

### UI-12 — Unconditional debug logging on a UI click path

- **Severity:** Low
- **Category:** Maintainability / UI
- **Location:** `ClaretHotbuild/modules/KeyboardEditor.lua:701, 708, 713, 716`.
- **Problem:** right-clicking a key cell logs one to two lines on every click, not gated by the
  `probeEnabled` option that every other diagnostic in both mods honours (`Menu.lua:4-5`,
  `MenuKey.lua:8-9`, `KeyboardBindings.lua:888-910`).
- **Evidence:** `KeyboardEditor.lua:701`: `LOG('[Claret][keyboard-clear] key='..tostring(key)..' combo='..tostring(ComboIndex(modifier))..' event=right')`;
  gate pattern elsewhere, `Menu.lua:5`: `if probe and probe:Get() then LOG('[Claret][input] capture='…) end`.
- **Impact:** log growth during the exact session where the user is experimenting with layouts.
- **Recommendation:** wrap the four calls in the same `probe and probe:Get()` guard, or drop them.
- **Risk of the fix:** none.
- **Confidence:** High.

### UI-13 — Four incompatible "may I leave" protocols for one documented contract

- **Severity:** Medium
- **Category:** Architecture / UI
- **Location:** `ClaretCore/modules/Menu.lua:372-397`, `ClaretHotbuild/modules/Navigator.lua:84-107`
  and `157-166`, `ClaretHotbuild/modules/Editor.lua:396-402, 627-630`,
  `ClaretHotbuild/modules/ContextEditor.lua:277-283, 1142-1150`,
  `ClaretHotbuild/modules/KeyboardEditor.lua:807-810`.
- **Problem:** `menu-rules.md` documents one contract: "`CanLeave(intent)` lets an editor request
  confirmation when closing or switching sections with an unsaved draft". The code implements four
  shapes of it, with different return semantics and different re-entrancy guards.
- **Evidence:**
  - Core host, continuation with serial + `completed` latch: `Menu.lua:386-397`
    `local serial=state.leaveSerial` … `local function Continue(allowed)` / `if completed then return end` /
    `if allowed==false or serial~=state.leaveSerial or ctx.getWindow()~=root or editor~=pendingEditor … then return end` …
    `if allowed then Continue(true) end`.
  - Navigator repeats it with child identity: `Navigator.lua:98-106`
    `local success, leaveError = pcall(function() allowed = child.CanLeave(intent, Continue) end)` …
    `elseif allowed then Continue(true) end`.
  - Editors answer synchronously **and** may call a continuation: `Editor.lua:396-402`
    `local function MayLeave(intent,continuation)` / `if dirty then` / `if not leaveDialog then ShowLeaveDialog(intent,continuation)` /
    `elseif continuation then leaveContinuation=continuation end` / `return false` / `end` / `leaveIntent=nil; return true`.
  - Call sites then disagree on how to consume it: `Editor.lua:628`
    `if MayLeave('close',function() frame:Destroy() end) then frame:Destroy() end` versus
    `ContextEditor.lua:1146-1149`
    `local function Close(accepted) if accepted and not embedded then frame:Destroy() end end` /
    `if MayLeave('close',Close) then Close(true) end`.
  - KeyboardEditor always allows: `KeyboardEditor.lua:807-810`
    `frame.CanLeave=function(intent,allowTransition)` / `if CloseDialog then CloseDialog() end` / `return true`.
- **Impact:** two behaviours for the same intent, and the burden is on the *host* to know which one a
  page implements; a third-party section registered through the documented API can easily return
  `true` from `CanLeave` while also deferring, and the double-call is only saved by the latch in
  `Menu`. `KeyboardEditor` never asks for confirmation at all (it has no draft, by design — but it is
  the only page whose `CanLeave` ignores `intent`).
- **Recommendation:** pick the Core continuation protocol as canonical (it is the one in the README
  and it is already re-entrancy safe), and give `Editor`/`ContextEditor` a thin adapter so their
  local dialogs keep their current text: `CanLeave(intent, cont)` → `MayLeave(intent, cont)`.
  Document the adapter in `ClaretCore/README.md`. Do not change `KeyboardEditor`.
- **Risk of the fix:** moderate — draft protection is the one place where a mistake silently loses
  user data; requires an in-game check of three flows (close via ×, switch page, switch section).
- **Confidence:** High for the divergence (all quotes verbatim); the recommendation is a design
  choice for the parent.

### UI-14 — Localization architecture is split: 333 numbered fragment keys concatenated at call sites

- **Severity:** Medium
- **Category:** Maintainability / UI
- **Location:** `ClaretHotbuild/modules/LocalizationStrings.lua` (333 of 637 keys match `…​.sNNN`),
  `ClaretHotbuild/modules/KeyboardEditor.lua` and `ContextEditor.lua` (concatenation sites),
  versus `ClaretCore/modules/Localization.lua:88-104` (`string.format` path).
- **Problem:** Two mechanisms coexist. Core's `Localization.Text(key, first, second, third)` formats a
  whole sentence with `string.format`; a second family of keys contains *fragments* ("Assign: ",
  " of ", " · Repeat: ", "empty") that call sites concatenate around runtime values. 52 % of Hotbuild
  keys are numbered fragments (`hotbuild.keyboard_editor.s001`…`s048`, `context_editor.s001…s280`,
  `runtime.s001…`), so the translation cannot reorder a sentence or inflect a noun.
- **Evidence:**
  - `LocalizationStrings.lua:335-336` (append style): `Strings.en['hotbuild.keyboard_editor.s001'] = 'Assign: '; Strings.ru['hotbuild.keyboard_editor.s001'] = 'Назначить: '`
  - Fragment use, `KeyboardEditor.lua:393`: `buildingText:SetText(Short(ReUI.ClaretCore.Localization.Text('hotbuild.keyboard_editor.s005')..building,74))`;
    `KeyboardEditor.lua:629`: `local range=count==0 and ReUI.ClaretCore.Localization.Text('hotbuild.keyboard_editor.s040') or (top..'–'..math.min(count,top+visible-1)..ReUI.ClaretCore.Localization.Text('hotbuild.keyboard_editor.s041')..count)`
  - Sentence style with arguments, `Localization.lua:94-101`: `local ok, formatted = pcall(string.format, value, first, second, third)` … `if ok then return formatted end`.
- **Impact:** Russian strings that need a different word order ("3 из 10" happens to work, "Назначить: X"
  does not generalise) cannot be fixed without touching code; a translator cannot work from the
  string table alone; 666 dictionary lines are unreadable identifiers.
- **Recommendation:** for the ~40 *composite* strings that embed values, convert to one format string
  per phrase and use `T(key, value)`; leave pure labels as they are. Do it per page, not globally.
  Out of scope for a consistency pass — needs the user's agreement on the string inventory.
- **Risk of the fix:** low per string, high in aggregate (every changed key must be re-checked in both
  languages; no test covers text).
- **Confidence:** High for the counts and the mechanism; the severity is my judgement.

### UI-15 — Widget helpers are re-implemented per module, with divergent behaviour

- **Severity:** Medium
- **Category:** Maintainability / UI
- **Location:** listed per widget below.
- **Problem:** The same six helpers exist 3–17 times, each with small behavioural differences. Not a
  style preference: the differences are observable.

| Widget | Copies | Observable divergences |
|---|---|---|
| `T()` localization accessor | 16 declarations in 15 files (`Adapter`, `Compatibility`, `ContextActions`, `ContextEditor`, `ContextModel`, `ContextRepeat`, `Editor`, `KeyboardBindings`, `KeyboardEditor`×2, `QuickRepeatSettings`, `Runtime`, `TemplateCatalog`, `Menu`, `MenuKey`, `Welcome`) | some fall back to `return key`, some index `ReUI.ClaretCore.Localization` directly (UI-07); `Menu`/`MenuKey` are the only ones that do not pass `first/second/third` |
| `Text(owner,value,x,y,size,color)` | 6 (`Menu` line 163 (no size parameter, fixed `metrics.text`), `Editor` 232, `ContextEditor` 96, `KeyboardEditor` 156, `Navigator` 42, `QuickRepeatSettings` 32); `Welcome` uses `Label(owner,value,font,size,color)` with a required font | default size 14 in four of them, fixed 16 in `Menu`; only `ContextEditor` additionally provides `Fit()` pixel truncation |
| `Button(...)` | 4 (`Menu.Interactive`+`Button`, `Editor.Button`, `ContextEditor.Button`, `KeyboardEditor.Button`) | `Editor` (line 239) has no `SetLabel`; `ContextEditor` (115) adds `SetSelected` with a `'● '` prefix; `KeyboardEditor` (170) takes an explicit height, a `hoverColor` and adds `SetBaseStyle`/`SetTextColor`/`ResetHover`; `Menu` (205) adds focus/pressed state and an 8-strip border |
| `Panel/Surface(owner,x,y,w,h,color)` | 5 (`Menu.Surface`, `Editor.Panel`, `ContextEditor.Panel`, `KeyboardEditor.Panel`, `Navigator.Surface`) | `Menu.Surface` passes `owner` to `Depth()`; `KeyboardEditor.Panel` also re-parents depth for dialog descendants; `ContextEditor.Panel` allows `nil` x/y |
| `SearchField` | 3 (`Editor.lua:266-283`, `ContextEditor.lua:145-159`, `KeyboardEditor.lua:201-219`) | identical construction; different `max` lengths at call sites (96 / 128 / 96) |
| `Short` (truncation) | 3 identical copies + 2 pixel-measured variants | see UI-18 |
| `Fold` (search normalisation) | 6 (`Localization.lua:29`, `Catalog.lua:10`, `ContextEditor.lua:33`, `Editor.lua:23`, `KeyboardEditor.lua:47`, `TemplateCatalog.lua:22`) | all identical today |
- **Evidence:** e.g. `ContextEditor.lua:115-126` (`Button` with `SetSelected`) vs `Editor.lua:239-257`
  (`Button` with the save-button guard) vs `KeyboardEditor.lua:170-187` (`Button` with `SetBaseStyle`);
  `Navigator.lua:42-47` vs `Menu.lua:163-168` (`Text` with/without size).
- **Impact:** any future change to, say, hover colour or tooltip behaviour has to be made 4–6 times;
  the already-visible divergences (button label offsets 0 vs 4 px, focus ring only in `Menu`) are the
  beginning of drift, not the end.
- **Recommendation:** move `Text`, `Panel`, `Button`, `Field`, `SearchField`, `Short`, `Fold` into one
  Core module (e.g. `modules/Widgets.lua`) exported as `ReUI.ClaretCore.Widgets`, parameterised by
  `L`, `ratio`, `C`. Migrate one page per change. This is a sizeable refactor — needs the user's
  approval, and must not alter rendered geometry.
- **Risk of the fix:** high if done in one step (13 UI files, no rendering tests); low per page.
- **Confidence:** High for the inventory; the recommendation is a judgement call.

### UI-16 — UI failures surface three different ways, and one path fails silently

- **Severity:** Medium
- **Category:** UI / Correctness
- **Location:** failure paths in `Menu`, `Editor`, `ContextEditor`, `KeyboardEditor`,
  `OrdersPanelShell`, `OrdersPanel`, `Registry`.
- **Problem:** There is no single policy. Enumerated:

| Mechanism | Where | What the user sees |
|---|---|---|
| Visible status line | `Menu.lua:210-240, 512`, `Editor.lua:296-300`, `ContextEditor.lua:180-186`, `QuickRepeatSettings.lua:56-73`, `KeyboardEditor.lua:782` | a clipped sentence + tooltip |
| `WARN` only | `Menu.lua:436` (`Settings window failed`), `Menu.lua:747` (`Inline editor refresh after show failed`), `Main.lua` (both) | nothing; the panel opens empty |
| `WARN` **plus** inline danger text | `Menu.lua:734`: `Text(state.content,T('core.menu.load_failed'),0,0,C.danger)` | "Could not load the editor…" |
| Thrown `error()` | `OrdersPanelShell.lua` (`Unsupported orders panel layout: …`, `Order slot … outside the … grid`), `Editor.lua:186`/`ContextEditor.lua:83` when creation fails | depends on the caller; `Menu` catches it (`pcall`) and only logs |
| Returned `false, diagnostics` | `OrdersPanel.lua:Refresh` | nothing — no caller displays diagnostics |
| Assertion | `Registry.lua:35-37` (`GetState` asserts a registered id) | Lua error for an unknown feature id |
- **Evidence:** `Menu.lua:435-436`: `local success,openError=pcall(function() child=action.open(state.content,{…}) end)` / `if not success or not child then WARN('[Claret] Settings window failed: '..tostring(openError)) end`
  (no user-visible text, and `state.panel:Show()` still runs).
- **Impact:** the same class of failure (a section or page failing to build) is loud in one path and
  invisible in the neighbouring one; the user's only signal in the accessory path is an empty panel.
- **Recommendation:** standardise on `WARN` + inline danger text for anything that leaves an empty
  region, keep thrown errors only for contract violations of the staging library (which has no
  production caller), and make `Registry:GetState` return `'unknown'` instead of asserting.
- **Risk of the fix:** low; adding text must not shift the layout of the failure path.
- **Confidence:** High for the inventory; the policy recommendation is a judgement.

### UI-17 — Five depth conventions in one UI

- **Severity:** Low
- **Category:** UI / Maintainability
- **Location:** `CycleMenu.lua:12`, `Editor.lua:223`, `ContextEditor.lua:86`,
  `Menu.lua:158, 340`, `Welcome.lua:79`, `KeyboardEditor.lua:359`.
- **Problem:** Absolute constants (`900`, `1000`), `parent.Depth()+1`, `GetTopmostDepth()+20`, and
  frozen numbers all coexist; the same visual layer (a modal overlay) sits at +80, +90, +100 and +1000
  depending on the file.
- **Evidence:** `CycleMenu.lua:12`: `local root=Group(parent); root.Depth:Set(900); root:DisableHitTest()`;
  `Editor.lua:223`: `frame.Depth:Set(1000)`;
  `Welcome.lua:79`: `root.Depth:Set(screen:GetTopmostDepth() + 20)`;
  `ContextEditor.lua:86`: `else frame.Depth:Set(1000) end`.
- **Impact:** today no two overlays collide because at most one is open; the values are already
  inconsistent enough that adding a second simultaneous overlay (a third-party `actions` window plus
  a menu dialog) is a coin flip.
- **Recommendation:** one helper `Theme.Layer(control, base, offset)` used everywhere; keep the numbers
  as constants in `Theme`. Purely mechanical; no visible change while one overlay is open.
- **Risk of the fix:** low, but it must be done together with UI-02/UI-03 or the frozen numbers stay.
- **Confidence:** High (quotes).

### UI-18 — Three truncation strategies for one requirement

- **Severity:** Low
- **Category:** UI
- **Location:** `Menu.lua:210-224` and `QuickRepeatSettings.lua:57-73` (pixel-measured with ellipsis),
  `Editor.lua:32-39` / `ContextEditor.lua:22-30` / `KeyboardEditor.lua:39-46` (character-count),
  `Navigator.lua:44` and `Menu.lua:369` (no truncation at all).
- **Problem:** `ui-style.md` §Navigation: "Safely truncate long UTF-8 labels and show the full text in
  a tooltip". Only the two pixel-measured implementations do this; the character-count `Short()`
  ignores glyph width (a Cyrillic string truncated at the same character count is visibly wider) and
  none of the `Short()` call sites attach the full text as a tooltip.
- **Evidence:** `Menu.lua:214-224` measures `text:GetStringAdvance(shown)>(width or 640)*ratio` and
  appends `'…'`, then `Tooltip.AddControlTooltip(text,{text=message},0,640)`;
  `Editor.lua:34-38`: `local b=string.byte(s,p); p=p+(b<128 and 1 or (b<224 and 2 or (b<240 and 3 or 4))); c=c+1`
  (counts characters, no width); `Editor.lua:89`: `if record.templateData then return Short(record.name,18) end`.
- **Impact:** long Russian unit names in the Editor picker or a long status message can still overflow
  the row/dialog; two visually different ellipsis behaviours in the same window.
- **Recommendation:** promote the pixel-measured version into the shared widget module (UI-15) and use
  it wherever a string is user data; keep `Short()` only for log lines.
- **Risk of the fix:** low; needs a long-name test string in one language.
- **Confidence:** High.

### UI-19 — Menu re-renders the whole content group on every scroll notch

- **Severity:** Low
- **Category:** Performance / UI
- **Location:** `ClaretCore/modules/Menu.lua:470-495`, `783-800`.
- **Problem:** `state.panel:ScrollSetTop` calls `state.Render()`, which destroys every row control,
  recreates them and re-registers option callbacks (`Unbind()` → `option.OnChanged:Remove` → `Add`) for
  each 44-logical-pixel step. The embedded editor is deliberately preserved, but the simple rows are
  not.
- **Evidence:** `Menu.lua:483-484`: `function state.panel:ScrollSetTop(axis,value)` /
  `local nextTop=math.max(0,math.min(state.maxContentTop,math.floor(value)))` … `if nextTop~=state.contentTop then state.contentTop=nextTop; state.Render() end`;
  `Menu.lua:440-441`: `state.Render=function()` / `Unbind(); Focus(nil); state.contentItems={}` … `if state.content then state.content:Destroy() end`.
- **Impact:** a wheel flick over a long section allocates and destroys tens of Maui controls per notch;
  it also clears the visual focus (`Focus(nil)`) and cancels an in-progress key capture
  (`Unbind`→`CancelCapture(true)`) as a side effect of scrolling.
- **Recommendation:** either move the rows into a child group that is repositioned (`AtLeftTopIn`
  offset) instead of rebuilt, or accept it and document that scrolling cancels capture/focus. The
  second is a one-line comment; the first is a real change.
- **Risk of the fix:** moderate (the rows are virtualized by `Visible()`, so a simple offset change
  would create all rows — the current approach was chosen for a reason).
- **Confidence:** High for the mechanism; the performance magnitude is **Unknown** (user measures).

### UI-33 — Scale selection differs per entry point (0.25 floor, 24 vs 32 padding, width-only fit)

- **Severity:** Low
- **Category:** UI / Consistency
- **Location:** `Menu.lua:87-88`, `Welcome.lua:72-73`, `Editor.lua:190`, `ContextEditor.lua:67-69`,
  `KeyboardEditor.lua:120`, `CycleMenu.lua:10`.
- **Problem:** Every Claret window computes its own fit. Three use a 0.25 floor and 24 px padding
  (`Editor`, `ContextEditor`, `KeyboardEditor`); `CycleMenu` uses the floor but fits on width only;
  `Menu` and `Welcome` use no floor (padding 24 and 32 respectively). Values agree today (all end up
  at `GetPixelScaleFactor()` on a normal screen), so nothing is visibly wrong — but the divergence is
  exactly the kind that produces "why is this window bigger" reports on unusual resolutions.
- **Evidence:**
  - `Menu.lua:87-88`: `local pixel=Helpers.GetPixelScaleFactor()` / `local scale=math.min(pixel,(parent.Width()-24)/groupWidth,(parent.Height()-24)/height)`
  - `Welcome.lua:72-73`: `local pixel = LayoutHelpers.GetPixelScaleFactor()` / `local scale = math.min(pixel, (parent.Width() - 32) / width, (parent.Height() - 32) / height)`
  - `Editor.lua:190`: `local scale=math.max(0.25,math.min(pixel,(parent.Width()-24)/1080,(parent.Height()-24)/920))`
  - `CycleMenu.lua:10`: `local scale=math.max(0.25,math.min(Helpers.GetPixelScaleFactor(),parent.Width()/800))`
- **Impact:** on a window shorter than 920 logical units `CycleMenu` (a build-cycle preview positioned
  at `parent.Height()/scale*0.72`) can overflow the bottom regardless of `scale`; on a very small
  window the two unfenced entries can scale to near zero, which `ui-style.md` explicitly warns about
  ("check readability at different resolutions and UI scale").
- **Recommendation:** one `Theme.FitScale(parent, width, height, padding, minimum)` helper, used by
  all six, with the same 0.25 floor and 24 padding. Behaviour-preserving on normal screens.
- **Risk of the fix:** low; verify on one small window size.
- **Confidence:** High (quotes); the overflow path is reasoned, not observed.

---

## 2. Strongly supported architectural problems

*(Cross-cutting, evidenced, but a fix needs a design decision rather than a patch. Several are
elaborated above; this section records the ones that do not fit a single file.)*

### UI-20 — Two complete UI toolkits coexist and neither is the source of truth

- **Severity:** Medium — **Category:** Architecture
- **Location:** native-style shells (`ConstructionPanelShell.lua`, `OrdersPanelShell.lua`,
  `MultifunctionShell.lua`, `ConstructionItemsView.lua`, `ConstructionCargoView.lua`) versus Claret
  panels (`Menu`, `Welcome`, the three Hotbuild pages).
- **Problem:** The native shells intentionally re-create stock FAF panels (engine textures,
  `SkinnableFile`, `LayoutHelpers`, `GameCommon.iconWidth`), while Claret panels build flat Theme
  surfaces with `ReUI.UI.FloorLayouter(scale)`. That split is legitimate per `ui-style.md` ("Do not
  create a separate module palette"), but the boundary is undocumented and already leaks: the
  construction family has no production entry point at all, so 4 of the 5 native-style modules are
  unreachable, while `MultifunctionShell` positions a control owned by one parent against a different
  one.
- **Evidence:** `MultifunctionShell.lua`: `LayoutHelpers.AtLeftBottomIn(self.root, self.parent, 15, 0)` …
  `LayoutHelpers.AtLeftTopIn(self.collapseArrow, GetFrame(0), -3, 97)` — the collapse arrow is a child
  of `controls.root` but anchored to the global frame, so it does not follow the panel when the caller
  repositions `root` (which `options.applyLayout` explicitly allows).
- **Impact:** if the construction family is ever wired up, the mixed anchoring and the unscaled
  `FloorLayoutFor` would be read as Claret UI bugs; today it is dead weight (69 % of Core per the
  parallel architecture audit) that still consumes review attention.
- **Recommendation:** document the two toolkits and the rule for choosing one, and either wire or
  remove the shells. Do not restyle them into Theme surfaces.

### UI-21 — "Escape first" is implemented per-dialog with a bare stack pop and per-file booleans

- **Severity:** Low — **Category:** UI / Correctness
- **Location:** `Menu.lua:120, 827`, `Welcome.lua:96-107, 281`, `ContextEditor.lua:192-197, 228, 249, 322-339, 433`,
  `Editor.lua:310, 351`, `KeyboardEditor.lua:129-131, 415-431, 507-512, 596-599, 653`.
- **Problem:** FAF's `Escape.PopEscapeHandler()` takes no argument and pops the top of a global stack.
  Each Claret dialog tracks `handled = true` in its own local and pops unconditionally, assuming it is
  on top. That holds while dialogs are strictly nested, which is true for the current click paths, but
  nothing enforces it: `ContextEditor` keeps four independent flags (`leaveEscape`, `conflictEscape`,
  `deleteEscape`, `savedEscape`) that can be closed programmatically from `RefreshSaved`/`RefreshRows`.
- **Evidence:** `ContextEditor.lua:331-332`: `if deleteEscape then Escape.PopEscapeHandler(); deleteEscape=nil end`;
  `KeyboardEditor.lua:129-131`: `if uiState.confirmation then Escape.PopEscapeHandler(); uiState.confirmation=nil end` /
  `if uiState.dialogEscape then Escape.PopEscapeHandler(); uiState.dialogEscape=nil end`.
  `KeyboardEditor` pops in reverse push order (confirmation pushed last) — correct today.
- **Impact:** one out-of-order close leaves a stale handler on the stack that will call into a
  destroyed control on the next Escape; the failure is a Lua error mid-match, not a visual glitch.
- **Recommendation:** when the shared widget layer exists (UI-15), give it a
  `Dialog(owner, …)` that pushes exactly one handler and pops it in `OnDestroy`; that removes the
  bookkeeping from four files.
- **Confidence:** High for the mechanism, **Unknown** for reachability (no out-of-order path found by
  reading; not exercised).

### UI-22 — Menu's accessory/`actions` path is implemented but never exercised, and its contract is not honoured

- **Severity:** Low — **Category:** Architecture / UI
- **Location:** `Menu.lua:418-440` (`Launch`), `Menu.lua:828-830`, README contract
  (`ClaretCore/README.md:28`).
- **Problem:** The README promises: "For child windows registered through `actions`, `open(parent)`
  returns a window with `RequestClose()` and `OnDestroy`, owned by the passed `parent`." `Launch`
  never calls `RequestClose` on that child, and `AttemptLeave` only consults the *inline* editor
  (`editor` is `state.inlineEditor`), so an accessory child with a draft would be destroyed without a
  prompt when the user switches sections. Nothing registers `actions` today, so this is latent.
- **Evidence:** `Menu.lua:427-436` (`state.accessory=action` … `child=action.open(...)` … `WARN` on
  failure, no `RequestClose`, no `CanLeave`); `Menu.lua:372-374`:
  `AttemptLeave=function(intent,action)` / `if not (editor and editor.CanLeave) then action(); return end`.
- **Impact:** the documented third-party extension point is a trap; a mod that registers `actions`
  gets silent data loss.
- **Recommendation:** either implement `RequestClose`/`CanLeave` for accessory children (small:
  store `state.accessoryChild`, call it in `AttemptLeave` and `closePanel`) or delete the `actions`
  path and the README paragraph. Needs the user's decision because it changes the public API surface.

### UI-23 — Localization is reached through three different entry points from UI code

- **Severity:** Low — **Category:** Maintainability
- **Location:** `T()` (13 files), `ReUI.ClaretCore.Localization.Text` (KeyboardEditor, 42 sites),
  `Localization.Text` from a direct `import` (`MenuKey.lua:31`, `Welcome.lua:59`, `Menu.lua:55`,
  `Editor.lua:174`).
- **Problem:** Three ways to get the same string, two of them bypassing the per-module fallback. The
  direct-`import` variant also creates a second `Localization` instance if the import table is ever
  invalidated.
- **Evidence:** `MenuKey.lua:31-36`: `local function T(key)` / `if Localization and type(Localization.Text)=='function' then return Localization.Text(key) end` / `return key`;
  `Editor.lua:174`: `local function T(key,first,second,third) return Localization.Text(key,first,second,third) end`.
- **Impact:** a language refresh works only if the same object is used; three paths make "why is this
  one label still English" a per-file investigation.
- **Recommendation:** one exported accessor (`ReUI.ClaretCore.T` or `Widgets.T`) referenced by all UI
  modules; the Core-internal copies of `T` then disappear.

### UI-24 — Page lifecycle hooks are optional and implemented unevenly

- **Severity:** Low — **Category:** UI
- **Location:** `Menu.lua:741-745` (`AfterParentShow`), `Editor.lua:1098`,
  `Navigator.lua:171-175`, absent in `ContextEditor` and `KeyboardEditor`.
- **Problem:** `Menu` hides the inline host when it scrolls out of view and calls `AfterParentShow`
  when it comes back. Only `Editor` implements it (a full `Refresh()`); `Navigator` forwards it;
  `ContextEditor` and `KeyboardEditor` have none, so a page scrolled away and back keeps whatever
  layout it computed while hidden.
- **Evidence:** `Menu.lua:743-745`: `if becomingVisible and state.inlineEditor and state.inlineEditor.AfterParentShow then` /
  `local success,refreshError=pcall(state.inlineEditor.AfterParentShow,state.inlineEditor)`;
  `Editor.lua:1098`: `frame.AfterParentShow=function() Refresh() end`.
- **Impact:** only the Hotbuild page recomputes after a re-show; if `ContextEditor` ever gains content
  whose geometry depends on being visible, it will show stale positions.
- **Recommendation:** add `AfterParentShow` to `Navigator`'s contract (refresh the current page) and
  have both editors expose it; or drop the hook and keep the editor always visible. No user-visible
  change today.

---

## 3. Potential risks requiring validation

### UI-25 — Game hotkeys stay live while a Claret text field has focus

- **Severity:** Medium — **Category:** Correctness — **Confidence:** Low (mechanism unverified)
- **Location:** `ClaretHotbuild/modules/Keys.lua:62-66`, call sites `Runtime.lua:766-830`.
- **Problem:** every editor open path calls `keys:Stop()` "so that hotkeys stop firing while the editor
  is open", but the function is an empty body — the comment says FAF owns the map, and nothing is
  suppressed. Hotbuild bindings are ordinary `UserKeyMap` actions
  (`Keys.lua:71-76`: `Mapper.SetUserKeyAction(id, { action = string.format('UI_Lua import(…).Execute(%q, IsKeyDown(16))', binding.id), …})`),
  so they are dispatched by the engine regardless of which Maui control has keyboard focus.
- **Evidence:** `Keys.lua:62-66`: `function keys:Stop()` / `-- FAF owns the active key map and its lifecycle.` / `end`;
  `Editor.lua:265-283` and `ContextEditor.lua:145-159` create `Edit` fields; `QuickRepeatSettings.lua:120-121`
  commits on `field.OnTextChanged`.
- **Impact if confirmed:** typing a number into the quick-repeat field, or a letter into a search
  field, would also trigger the build/hotkey bound to that key — up to and including issuing orders.
- **Unknown:** whether FAF's key dispatch is suppressed while a `maui.Edit` holds focus. I did not
  read `keymapper.lua` / the C-side dispatch path.
- **How to validate:** open the Hotbuild page, focus the search field, hold a bound build key for a
  second, observe whether the build cursor opens. One scenario, one screenshot.
- **Recommendation if confirmed:** guard the `Runtime.Execute*` entry points with a "menu open or
  editor focused" check (`ReUI.ClaretCore.IsMenuOpen()` already exists and is exported), or ask the
  user whether they prefer bindings to stay live.

### UI-26 — `Depth:Set(<Depth object>)` relies on Maui calling the object

- **Severity:** Low — **Category:** UI — **Confidence:** Low
- **Location:** `ContextEditor.lua:229, 253, 341, 372, 1066, 1112`, `Editor.lua:345`.
- **Problem:** siblings pass closures (`back.Depth:Set(function() return dialog.Depth()+1 end)`), these
  pass the `Depth` object itself: `back.Depth:Set(conflictDialog.Depth)`. This works only if Maui's
  `Depth:Set` accepts a callable object and invokes it; if it treats non-number values as literal, the
  arithmetic path (`depth + 1`) would later fail or the value would be wrong.
- **Evidence:** `ContextEditor.lua:229`: `local back=Panel(conflictDialog,0,0,dialogWidth,dialogHeight,C.surface); back.Depth:Set(conflictDialog.Depth)`
  versus `ContextEditor.lua:149`: `field.Depth:Set(function() return owner.Depth()+2 end)`.
- **Impact if broken:** the dialog background would sort wrong relative to its own dialog (cosmetic),
  or raise an arithmetic error when a parent adds to it.
- **How to validate:** open any ContextEditor dialog in game; background must be behind the dialog
  text and not spamming the log. Or read the Maui binding — not available as Lua in `lua.nx2`
  (`Depth` is engine-side).
- **Recommendation:** replace with the closure form for uniformity regardless of the answer.

### UI-27 — Fixed 1080×920 page canvases are not clipped by the panel

- **Severity:** Low — **Category:** UI — **Confidence:** Medium
- **Location:** `Editor.lua:231`, `ContextEditor.lua:160`, versus `KeyboardEditor.lua` (no page canvas).
- **Problem:** Two pages paint their own `C.canvas` background at the full 1080×920 embedded size; the
  third paints none and relies on the host panel. The menu panel height is dynamic
  (`SetPanelHeight`, used by the keyboard page to shrink to 570/850). Nothing clips children
  (`ui-style.md` warns: "Do not rely on clipping child Maui controls without checking"). Today the
  pages that draw a canvas do not call `setHeight`, so 920 always fits — but the invariant is implicit.
- **Evidence:** `Editor.lua:231`: `local bg=Panel(frame,0,0,1080,920,C.canvas); bg.Depth:Set(function() return frame.Depth()+1 end); bg:DisableHitTest()`;
  `ContextEditor.lua:160`: `local bg = Panel(frame, 0, 0, 1080, 920, C.canvas)`;
  `Navigator.lua:57`: `L(content):AtLeftTopIn(root, childLeft, navHeight + navGap):Width(childWidth):Height(childHeight)`.
- **Impact:** the day a page both draws a canvas and shrinks the panel, the canvas will paint over the
  map below the menu.
- **How to validate:** set the keyboard page's height while the Hotbuild page is mounted (not possible
  through the UI today) — or simply note the invariant when adding a `setHeight` call.
- **Recommendation:** move the canvas into `Navigator` (one background for all pages, sized to the
  content group) and delete the per-page backgrounds.

### UI-28 — `CanLeave` on a page that is being destroyed by its own parent

- **Severity:** Low — **Category:** UI — **Confidence:** Medium
- **Location:** `Navigator.lua:148-156`, `Menu.lua:116-126`, `Runtime.lua:776-782`.
- **Problem:** three `OnDestroy` handlers can run in one teardown (page → navigator → menu), each
  calling into the next; the page's `OnDestroy` calls `self:RefreshKeys()` (Runtime) *and*
  `oldDestroy(control)`, which may itself touch `frame`-owned controls that are already being
  destroyed by the parent. `KeyboardEditor`'s handler additionally reads `perf` after the frame is
  gone.
- **Evidence:** `Runtime.lua:821-829`: `window.OnDestroy=function(control)` / `self.editor=nil` /
  `oldDestroy(control)` / `local measuring=perf and perf:Enabled()` … `self:RefreshKeys()`.
- **Impact:** if any of those steps throws, the chain stops and a later `oldDestroy` never runs —
  leaving `Menu.state.inlineEditor` pointing at a destroyed control. `Menu` guards the *entry*
  (`pcall(action.open)`) but not the teardown chain.
- **How to validate:** open the Hotbuild page, close the whole menu with the bind, check the log for a
  `[Claret]` warning and confirm the menu reopens cleanly. Cheap.
- **Recommendation:** wrap each `OnDestroy` body in `pcall` (the pattern already used in
  `ConstructionPanel.lua:302-332`) or order the calls so `RefreshKeys` runs last.

---

## 4. Optional improvements

### UI-29 — Language selection looks different in the two places it appears

- **Severity:** Low — **Category:** UI
- `Menu` renders EN/RU as segmented buttons `48×28` inside the Core card
  (`Menu.lua:585-586`: `local buttonWidth=compactCore and 48 or 56` / `local buttonHeight=compactCore and 28 or 32`);
  `Welcome` renders the same choice as `108×36` buttons with a 1 px inset fill
  (`Welcome.lua:182-184`: `L(button):AtLeftTopIn(panel, x, 278):Width(108):Height(36)` /
  `L(fill):AtLeftTopIn(button, 1, 1):Width(106):Height(34)`). Different sizes and different
  hover-revert logic (Welcome re-runs `UpdateLanguageButtons()` on exit; the menu repaints from
  `update()`). Aligning the Welcome block with the segmented style is cosmetic and cheap.

### UI-30 — `ui-style.md` and `Theme.Metrics` disagree on two dimensions

- **Severity:** Low — **Category:** Maintainability
- `ui-style.md` says "compact Core section 552×436" and "field 24"; `Theme.lua:39,43` has
  `corePanelHeight=408` and `fieldHeight=36`. The spec itself says code wins ("code values take
  precedence over examples"), so the doc is stale, but a reader implementing a new section will size
  against the wrong numbers. Two-line doc fix.

### UI-31 — F10 tooltip is computed once, so it does not follow a language change

- **Severity:** Low — **Category:** UI
- `Main.lua` (Core) builds the F10 menu entry inside `ReUI.Core.OnPreCreateUI`
  (`Main.lua:91-93`: `action = 'Claret.Settings', label = 'Claret', tooltip = Localization.Text('core.settings.tooltip'),`). Changing the language from the menu updates
  every subscribed label but not this tooltip until the UI session ends. If `AddToMenu` entries cannot
  be updated, a one-line comment is enough; otherwise re-add the entry on `Localization.Subscribe`.

### UI-32 — Small dead code worth deleting while touching these files

- **Severity:** Low — **Category:** Maintainability
- `Menu.lua:805-807`: `if item.selected then … else item.paint() end` followed by an unconditional
  `item.paint()` (the selected branch paints twice' worth of work, the else branch three times).
- `Menu.lua:10-23` (`InsertSection`): any section id that is not in `sectionOrder` breaks the loop on
  the first iteration and is inserted at index 1, i.e. a third-party section would appear *above*
  Core. Not reachable today.
- `OrdersPanelShell.lua` `MakeButton`: `if button.OnClick ~= nil or kind == 'button' then … else … end`
  with identical bodies.
- `QuickRepeatSettings.lua:124-137`: `Localization.Subscribe(root, …)` and `root.OnLanguageChanged` do the
  same work; `Navigator.lua:133` calls `child.OnLanguageChanged`, so a page that also subscribes
  updates twice (and would error if the earlier `pcall` block failed and `valueLabel` is nil).
- `Keys.lua:62-66`: `Stop()` is empty and `Validate()` (line 58) returns `true` unconditionally — either
  implement (see UI-25) or delete both and the call sites' pretence.
- `Menu.lua:288-290`: `Focus(item)` maintains a focus ring with no keyboard traversal; either add
  arrow/Enter navigation or drop the focus colour from `item.paint()`.

---

## 5. Counts

| Severity | Confirmed defects (§1) | Architectural (§2) | Risks (§3) | Optional (§4) | Total |
|---|---|---|---|---|---|
| High | 1 | – | – | – | 1 |
| Medium | 13 | 1 | 1 | – | 15 |
| Low | 6 | 4 | 3 | 4 | 17 |
| **Total** | **20** | **5** | **4** | **4** | **33** |

Entry ids: §1 = UI-01…UI-19 plus UI-33 (High: UI-01; Medium: UI-02…UI-10, UI-13…UI-16; Low: UI-11,
UI-12, UI-17, UI-18, UI-19, UI-33), §2 = UI-20…UI-24 (Medium: UI-20), §3 = UI-25…UI-28 (Medium:
UI-25), §4 = UI-29…UI-32 (all Low).

Most likely to matter in play, in order: **UI-01** (a documented setting has no UI), **UI-02/UI-03**
(a draft dialog can end up behind its panel), **UI-25** (if confirmed, hotkeys fire while typing),
**UI-13** (draft protection has four shapes), **UI-04/UI-05** (spec-mandated state cues missing in
the two most visible new surfaces).

Open questions for the user, in one batch:

1. Quick-repeat window: restore the gear + option, or delete the two modules (UI-01)?
2. Are game hotkeys supposed to stay live while a Claret text field has focus (UI-25)?
3. Is the `actions`/`accessory` extension point still wanted (UI-22)?
4. May the shared widget layer (UI-15) be introduced, given it touches 13 UI files?
