# Hotbuild keys — analysis, 2026-11-13

Inspected Hotbuild 0.10.15/build 20261113-03 and FAF3840 `C:/ProgramData/FAForever/gamedata/lua.nx2`; no code changes or game interaction. HB below = `../mods/ClaretHotbuild/modules/`; FAF paths = archive members.

## Press -> effect

HB `KeyboardBindings.lua:78` begins Register; SetUserKeyAction is currently :90. Category: `Claret Hotbuild`.
- Preset b1, ID `ClaretHotbuild_6231`: `UI_Lua import("/mods/ClaretHotbuild/modules/Runtime.lua").Execute("b1")` (:81).
- Context select_acu, ID `ClaretHotkeyContext_73656C6563745F616375`: `UI_Lua import("/mods/ClaretHotbuild/modules/Runtime.lua").ExecuteKeyboardAction("select_acu")` (:88). goto_acu uses the same wrapper with its own ID.
Composites: ExecuteKeyboardComposite; legacy: ExecuteAbsolute (:82–86).

FAF `lua/keymap/keymapper.lua:235–238` saves the definition in UserKeyActions. HB `KeyboardBindings.lua:206–209` maps W -> ID, saves and Refreshes. Refresh re-registers assigned IDs (:246–250), gets W -> definition (:251), clears/adds the engine map (:261–262), then modifiers/labels (:263–265).

Physical W must reach the engine map; its command interpreter runs UI_Lua, imports Runtime and calls the export. Engine internals uninspected; Keys.lua has no press dispatcher.
- Preset: HB `Runtime.lua:46` -> Dispatch (:12), invoke (:19), current:Execute (:39/:122). Fresh context (:124–126); optional context rows (:164–223) call ContextActions.Execute (:188/:196). Otherwise Model:Execute (:220/:223) -> HB `Model.lua:252–269` -> Adapter:Build -> HB `Adapter.lua:81–128`: placement (:128), factory command (:104/:115), template (:92–94).
- Context: Runtime :48 -> same Dispatch -> service:ExecuteKeyboardAction (:308); guards (:309), lookup/context/availability (:310–318), continuation (:320), ContextActions.Execute (:322). HB `ContextActions.lua:375–380` validates and ConExecute(action.select). select_acu/goto_acu (:21/:23) execute UI_SelectByCategory +nearest [ +goto ] COMMAND.

## Diagnostics

Runtime :13–15 and KeyboardBindings :253–254/:267 both directly access `ReUI.Options.Mods['ClaretCore'].probeEnabled:Get()`, with nil guards. Neither uses rawget(_G,...). OpenPerf :20–22 uses the passed ReUI object. invoke precedes all session/active/replay/editor/ID checks. Those guards cannot hide invoke when tracing is enabled. Failure before :19 or changed probe value remains possible.

`node .tools/faf-log.cjs --grep keys`, raw excerpt:
```text
info: [Claret][keys] key=W action=ClaretHotkeyContext_73656C6563745F616375 defined=true (x6)
info: [Claret][keys] key=W action=ClaretHotbuild_6231 defined=true (x2)
info: [Claret][keys] key=W action=ClaretHotkeyContext_676F746F5F616375 defined=true (x2)
```
No invoke/dispatch in this filtered digest. defined checks only `mappings[key] ~= nil`, not command contents, engine acceptance or later replacement.

## Load/editor/native comparison

Runtime :73–76 creates models/KeyboardBindings; its Create immediately Refreshes (:275). Runtime :522–523 sets current/RefreshKeys; Start :118–119 activates/refreshes. RefreshKeys :100–105 registers presets through Keys:Apply (:58–67), legacy definitions, then keyboard actions. Both preset registrars emit identical strings/category. Saved contexts are re-registered from ContextActions. Editor Set :198 registers before mapping/Refresh; editor close Refreshes again (Runtime :498–503). Keys:Stop (:54–56) does nothing.

FAF keymapper :194–232 freshly merges user/native/debug actions; native IDs win collisions. :246–259 freshly builds mappings; true is an unused extra argument. No persistent action/map cache there. Runtime reads current models; stale models still produce invoke. Native `lua/ui/dialogs/keybindings.lua:70–78` uses the same save/clear/add sequence. Native `lua/keymap/keyactions.lua:229–231` uses UI_Lua import(...).SelectCommander(false), category selection. Category affects grouping/modifiers; Claret IDs have no forbidden hyphens.

ReUI Actions installed bytecode is 1.3.0. Reference `Context/sources/ReUI/Actions/Actions.lua` 1.3.0 :239–246 deletes ReUI-tagged actions only (Claret lacks tags); :292–301 rebuilds fresh mappings after one frame. Installed symbols agree; semantics unverified. Native success must use the identical Claret ID, not merely a native equivalent.

## Ranked causes and proposal

1. Engine map differs from the logged table, or input is consumed before command execution. Best fit for both action types lacking invoke; no specific overwriter is proven. Balanced capture=off weakens Claret focus leakage, but does not inspect every input consumer.
2. Installed command differs from expected, or UI_Lua/import fails before Dispatch. Log the actual command. Native success for the identical ID weakens this hypothesis.
3. Probe changes at press time. Access is correct; the old rawget failure is absent. Verify with an unconditional entry marker/direct call.
4. Context/model availability: explains no effect, but not missing invoke. select_acu sets absolute=true (Runtime :317), bypassing the empty-selection restriction (ContextActions :192); starting with ACU selected is insufficient explanation.

Fresh start restores the same saved ID/command and installation path. Upstream map/command failure can persist without editor use; editor-only stale-model theories cannot explain this.

No proven fix. Conditional fix for #1: if replacement is demonstrated, remove/add affected Claret chords at final menu-close/post-create, preserving IDs/native assignments. First diagnostic: log exact command and unconditional entry; compare identical ID via native UI.

One game session: enable probe, close menus, test saved W and direct Runtime.ExecuteKeyboardAction("select_acu") in the UI Lua console. Assign W to that exact Claret ID via native UI, close/test; assign the same ID via Claret, fully close/test. Repeat with b1 and a valid builder. Record entry/dispatch and effect. Direct call succeeds + only Claret assignment fails localizes before Runtime; a native equivalent alone is inconclusive. Fix/game results unverified.



