-- Runtime integration for context bindings using the real model/action modules.
local testLocalization = dofile('Tests/localization-test-helper.lua')
table.getn = function(value) return #value end
table.getsize = function(value) local n=0; for _ in pairs(value) do n=n+1 end; return n end
local preferences = {
    ClaretHotbuild = {version=1,bindings={
        {id='legacy',name='Legacy',key='',entries={{kind='blueprint',id='ueb1101'}}},
        {id='acu',name='ACU priority',key='',entries={{kind='blueprint',id='ueb1101'}},
            grid={buildings={},units={},context='ctxAcu'}},
        {id='engineer',name='Engineer priority',key='',entries={{kind='blueprint',id='ueb1101'}},
            grid={buildings={},units={},context='ctxEngineer'}},
        {id='empty',name='Empty selection',key='',entries={},grid={buildings={},units={},context='ctxEmpty'}},
        {id='mixed',name='Mixed selection',key='',entries={{kind='blueprint',id='ueb1101'}},grid={buildings={},units={},context='ctxMixed'}},
        {id='hierarchy',name='Builder inheritance',key='',entries={{kind='blueprint',id='ueb1101'}},grid={buildings={},units={},context='ctxHierarchy'}},
        {id='mobile',name='Mobile factory priority',key='',entries={{kind='blueprint',id='ueb1101'}},grid={buildings={},units={},context='ctxMobile'}},
        {id='missing',name='Removed context',key='',entries={},grid={buildings={},units={},context='ctxRemoved'}},
    }},
    ClaretHotbuildContexts = {version=2,bindings={
        {id='ctxAcu',name='ACU action',rows={{context='acu',action='move'}}},
        {id='ctxEngineer',name='Engineer action',rows={{context='engineer',action='reclaim'}}},
        {id='ctxEmpty',name='Empty action',rows={{context='empty',action='select_acu'}}},
        {id='ctxMixed',name='Mixed action',rows={{context='acu',action='move'},
            {context='engineer',action='reclaim'},{context='other',action='stop'}}},
        {id='ctxHierarchy',name='Builder modes',rows={
            {context='builder',action='reclaim'},
            {context='acu',mode='own',action='move'},
            {context='sacu',mode='disabled'},
            {context='engineer',mode='inherit'},
        }},
        {id='ctxMobile',name='Mobile factory action',rows={{context='acu',action='move'}}},
    }},
}
local saveCount, failSave, failSaveOnCall = 0, false, nil
local selected, buildCalls, commandCalls, selectCalls = {}, {}, {}, {}
local cycleFactory
local testNow, simulateSelection, engineerCandidates, fallbackSelection = 0, nil, {}, nil
local modules, runtimeEnvironment = {}, nil
local descriptions = {}
local unit = {}
function unit:IsDead() return false end
function unit:IsInCategory(category) return self.categories[category] == true end
function unit:GetEntityId() return self.entityId or 123 end
function unit:GetPosition() return {self.entityId or 0,0,0} end
local function makeUnit(...)
    local categories, canBuild={},true
    for _, value in ipairs({...}) do
        if value=='CANNOT_BUILD' then canBuild=false else categories[value]=true end
    end
    return setmetatable({categories=categories,canBuild=canBuild}, {__index=unit})
end

local prefs = {
    GetFromCurrentProfile=function(key)
        if key=='UserKeyActions' then return preferences.UserKeyActions end
        if key=='UserKeyMap' then return preferences.UserKeyMap end
        if key=='UserDebugKeyMap' then return preferences.UserDebugKeyMap end
        return preferences[key]
    end,
    SetToCurrentProfile=function(key,value) preferences[key]=value end,
}
local commandMode = {'normal'}
local commandModule = {
    GetCommandMode=function() return commandMode end,
    StartCommandMode=function(kind, data) commandCalls[#commandCalls+1]={kind,data}; commandMode={kind,data} end,
}
local mapperCalls={}
local engineKeyMap, failEngineAdd = {}, false
local applyCalls, diagnosticLines = {}, {}
local probeEnabled = false
local keyCaptureActive = false
local missingDefinitionKey
local defaultKeyMap={['Ctrl-D']='DefaultAction'}
local generatedModifiers={}
local mapper
mapper={
 SetUserKeyAction=function(id,action) mapperCalls[#mapperCalls+1]={id,action}; preferences.UserKeyActions=preferences.UserKeyActions or {}; preferences.UserKeyActions[id]=action end,
 SetUserKeyMapping=function(key,_,id) preferences.UserKeyMap=preferences.UserKeyMap or {}; preferences.UserKeyMap[key]=id end,
 ClearUserKeyMapping=function(key) if preferences.UserKeyMap then preferences.UserKeyMap[key]=nil end end,
 GetCurrentKeyMap=function()
  local result={}; for key,id in pairs(defaultKeyMap) do result[key]=id end
  for key,id in pairs(preferences.UserKeyMap or {}) do result[key]=id end
  for key,id in pairs(preferences.UserDebugKeyMap or {}) do result[key]=id end
  return result
 end,
 GetUserDebugKeyMap=function() return preferences.UserDebugKeyMap or {} end,
 GetKeyCodeLookup=function() return {} end,
 NormalizeKeyBinding=function(key) return key end,
 NormalizeKey=function(key)
  local out={}; for part in string.gmatch(key,'[^%-]+') do out.key=part end
  out.Ctrl=string.find(key,'Ctrl%-',1)~=nil; out.Alt=string.find(key,'Alt%-',1)~=nil; out.Shift=string.find(key,'Shift%-',1)~=nil
  return out
 end,
 SaveUserKeyMap=function() applyCalls[#applyCalls+1]='save' end,
 GetKeyMappings=function()
  local result={}; local map=mapper.GetCurrentKeyMap()
  for key,id in pairs(map) do if key~=missingDefinitionKey then result[key]=(preferences.UserKeyActions or {})[id] or {action='native:'..id} end end
  return result
 end,
 GenerateHotbuildModifiers=function()
  local result={}; local map=mapper.GetCurrentKeyMap()
  for key,value in pairs(generatedModifiers) do if not map[key] then result[key]=value end end
  return result
 end,
 GetActionName=function(id) return tostring(id) end,
}
runtimeEnvironment=setmetatable({
    __blueprints={ueb1101={BlueprintId='ueb1101',General={UnitName='Power Generator'},Description='Generator',
        Categories={'UEF','STRUCTURE','TECH1','BUILTBYTIER1FACTORY'}}},
    LOC=function(value) return value end,
    GetSelectedUnits=function() return selected end,
    SelectUnits=function(units) selected=units end,
    UISelectionByCategory=function(category)
        if category=='ENGINEER TECH1' or category=='MOBILE ENGINEER TECH1' then selected=engineerCandidates end
    end,
    ConExecute=function(command)
        selectCalls[#selectCalls+1]=command
        if command=='UI_Lua import("/lua/keymap/misckeyactions.lua").CycleIdleFactories()' and cycleFactory then
            selected={cycleFactory}
        end
        if simulateSelection and (command=='UI_SelectByCategory +inview +nearest COMMAND'
            or command=='UI_SelectByCategory +nearest COMMAND'
            or command=='UI_SelectByCategory +nearest +goto COMMAND') then selected={simulateSelection} end
        if fallbackSelection and command=='UI_SelectByCategory AIR BOMBER' then selected={fallbackSelection} end
    end,
    GetSystemTimeSeconds=function() return testNow end,
    GetMouseWorldPos=function() return {0,0,0} end,
    ClearBuildTemplates=function() end,
    GetFocusArmy=function() return 1 end,
    GetUnitCommandData=function(units)
        local category='EMPTY'
        if units and #units==1 and units[1].canBuild then category='BUILDABLE' end
        return {'RULEUCC_Move','RULEUCC_Reclaim'}, {}, category
    end,
    EntityCategoryGetUnitList=function(category) return category=='BUILDABLE' and {'ueb1101'} or {} end,
    IssueBlueprintCommand=function(...) buildCalls[#buildCalls+1]={...} end,
    GetFrame=function() return {} end,
    IsDestroyed=function() return true end,
    SavePreferences=function()
        if failSave or failSaveOnCall==saveCount+1 then failSave=false; failSaveOnCall=nil; error('simulated profile write failure') end
        saveCount=saveCount+1
    end,
    WARN=function() end,
    LOG=function(line) diagnosticLines[#diagnosticLines+1]=line end,
    ReUI={ClaretCore={Localization=testLocalization,IsKeyCaptureActive=function() return keyCaptureActive end},Options={Mods={ClaretCore={probeEnabled={Get=function() return probeEnabled end}}}}},
    SessionIsActive=function() return true end,
    IN_ClearKeyMap=function() applyCalls[#applyCalls+1]='clear'; for key in pairs(engineKeyMap) do engineKeyMap[key]=nil end end,
    IN_AddKeyMapTable=function(map)
        applyCalls[#applyCalls+1]='add'
        for key,value in pairs(map) do
            engineKeyMap[key]=engineKeyMap[key] or value
            if failEngineAdd and key=='C' then failEngineAdd=false; error('simulated partial engine map failure') end
        end
    end,
    IN_RemoveKeyMapTable=function(map) for key in pairs(map) do engineKeyMap[key]=nil end end,
    import=function(path)
        if path=='/lua/keymap/hotbuild.lua' then return {addModifiers=function() applyCalls[#applyCalls+1]='modifiers' end} end
        if path=='/lua/keymap/hotkeylabels.lua' then return {init=function() applyCalls[#applyCalls+1]='labels' end} end
        if path=='/lua/user/prefs.lua' then return prefs end
        if path=='/lua/keymap/keymapper.lua' then return mapper end
        if path=='/lua/keymap/keydescriptions.lua' then return {keyDescriptions=descriptions} end
        if path=='/lua/keymap/unitkeygroups.lua' then return {unitkeygroups={}} end
        if path=='/lua/ui/game/commandmode.lua' then return commandModule end
        if path=='/lua/ui/game/gamemain.lua' then return {SetIgnoreSelection=function() end} end
        if path=='/mods/ClaretHotbuild/modules/CycleMenu.lua' then
            return {Create=function() return {Show=function() end,Hide=function() end,Destroy=function() end} end}
        end
        if path=='/mods/ClaretHotbuild/modules/TemplateCatalog.lua' then
            return {Create=function(base)
                base.RefreshTemplates=function() end
                return base
            end}
        end
        if modules[path] then return modules[path] end
        local module=setmetatable({}, {__index=runtimeEnvironment})
        assert(loadfile('..'..path,'t',module))()
        modules[path]=module
        return module
    end,
}, {__index=_G})

local Runtime=runtimeEnvironment.import('/mods/ClaretHotbuild/modules/Runtime.lua')
local function assertProfileProtected(profile, validBindingId)
    preferences.ClaretHotbuild=profile
    local beforeSaves=saveCount
    local service=Runtime.Create(false)
    local binding=validBindingId and service.model:Get(validBindingId) or {
        id='candidate',name='Candidate',key='',entries={},
    }
    if validBindingId then binding.name='Changed copy' end
    local saved,saveError=service:Commit(binding)
    assert(not saved and (saveError:find('повреждён',1,true) or saveError:find('Повреждён',1,true)),
        'save is rejected for damaged source profile: '..tostring(saveError))
    local deleted,deleteError=service:Commit(nil,validBindingId or 'missing')
    assert(not deleted and (deleteError:find('повреждён',1,true) or deleteError:find('Повреждён',1,true)),
        'delete is rejected for damaged source profile: '..tostring(deleteError))
    assert(preferences.ClaretHotbuild==profile,'profile table is not replaced')
    assert(saveCount==beforeSaves,'SavePreferences is not called')
    if validBindingId then assert(service.model:Get(validBindingId),'valid entry remains readable') end
    service:Destroy()
end
local originalProfile=preferences.ClaretHotbuild
preferences.UserKeyActions={
    ClaretHotbuild_old={category='Claret Hotbuild',action='old action'},
    unrelated={category='Other',action='unrelated action'},
}
local function encoded(value)
    return (value:gsub('.',function(c) return string.format('%02X',string.byte(c)) end))
end
preferences.UserKeyMap={['Ctrl-X']='ClaretHotbuild_old',F1='ClaretHotbuild_'..encoded('acu'),F2='ClaretHotbuild_'..encoded('engineer')}
preferences.UserDebugKeyMap={['Ctrl-Y']='ClaretHotbuild_old', ['Alt-F2']='ClaretHotbuild_'..encoded('engineer')}
local oldActions, oldMap, oldDebugMap = preferences.UserKeyActions,
    preferences.UserKeyMap, preferences.UserDebugKeyMap
local oldMapperCalls=#mapperCalls
local unknownProfile={version=99,bindings={{id='kept',name='Legacy',key='',entries={}}}}
assertProfileProtected(unknownProfile,nil)
local partialProfile={version=1,bindings={
    {id='kept',name='Legacy',key='',entries={}},
    {id='broken',name='',key='',entries={},grid={buildings={},units={},context='ctxAcu'}},
}}
preferences.ClaretHotbuild=partialProfile
local partialService=Runtime.Create(false)
assert(partialService.model:Get('kept'),'valid preset loads from a partially damaged profile')
local kept=partialService.model:Get('kept'); kept.name='Changed copy'
local partialSaved,partialSaveError=partialService:Commit(kept)
assert(partialSaved,'save is allowed for a partially damaged profile: '..tostring(partialSaveError))
local partialExport=preferences.ClaretHotbuild
assert(partialExport and #partialExport.bindings==2
    and partialExport.bindings[1].name=='Changed copy'
    and partialExport.bindings[2].id=='broken'
    and partialExport.bindings[2].grid.context=='ctxAcu',
    'valid edit is saved and the quarantined preset is preserved in place')
assert(preferences.UserKeyActions['ClaretHotbuild_'..encoded('kept')]
    and not preferences.UserKeyActions['ClaretHotbuild_'..encoded('broken')],
    'only valid presets register key actions')
local contextSaved,contextSaveError=partialService:CommitContext({id='ctxS2',name='S2 context',rows={{context='empty',action='select_acu'}}})
assert(contextSaved,'context saving is independent from a damaged preset profile: '..tostring(contextSaveError))
assert(partialService.contextModel:Get('ctxS2'),'saved context is available')
partialService:Destroy()
assert(unknownProfile.version==99 and #unknownProfile.bindings==1
    and partialProfile.bindings[2].name=='' and partialProfile.bindings[2].grid.context=='ctxAcu',
    'original profile tables are never mutated in place')
preferences.ClaretHotbuild=originalProfile
local migrationUserMap=preferences.UserKeyMap
local migrationDebugMap=preferences.UserDebugKeyMap
failSave=true
local failedMigration=Runtime.Create(false)
assert(not preferences.ClaretHotbuildKeyboard
    and preferences.UserKeyMap.F1=='ClaretHotbuild_'..encoded('acu')
    and preferences.UserDebugKeyMap['Alt-F2']=='ClaretHotbuild_'..encoded('engineer')
    and preferences.UserKeyMap==migrationUserMap and preferences.UserDebugKeyMap==migrationDebugMap
    and preferences.UserKeyActions.ClaretHotkeyPair_4631==nil
    and preferences.UserKeyActions.ClaretHotkeyPair_416C742D4632==nil,
    'failed migration restores profile, both native maps and generated actions')
failedMigration:Destroy()
local service=Runtime.Create(false)
local migratedKeyboard=preferences.ClaretHotbuildKeyboard
assert(migratedKeyboard and migratedKeyboard.version==2
    and migratedKeyboard.assignments.F1.preset=='acu' and migratedKeyboard.assignments.F1.composite=='ctxAcu'
    and migratedKeyboard.assignments.F2.preset=='engineer' and migratedKeyboard.assignments.F2.composite=='ctxEngineer'
    and migratedKeyboard.assignments['Alt-F2'].preset=='engineer'
    and migratedKeyboard.assignments['Alt-F2'].composite=='ctxEngineer'
    and preferences.UserKeyMap.F2=='ClaretHotkeyPair_'..encoded('F2')
    and preferences.UserDebugKeyMap['Alt-F2']=='ClaretHotkeyPair_'..encoded('Alt-F2'),
    'legacy preset keys migrate to independent per-chord preset/composite slots')
local migratedKeyboardRef=migratedKeyboard
local migrationCheck=Runtime.Create(false)
assert(preferences.ClaretHotbuildKeyboard==migratedKeyboardRef
    and migratedKeyboard.assignments.F1.composite=='ctxAcu'
    and migratedKeyboard.assignments['Alt-F2'].composite=='ctxEngineer',
    'keyboard migration is idempotent across runtime initialization')
service=migrationCheck
local legacyDirectId='ClaretHotkeyContext_'..encoded('cycle_mex_map')
local legacyDirectMap=preferences.UserKeyMap
local legacyDirectOld=legacyDirectMap['Ctrl-M']
legacyDirectMap['Ctrl-M']=legacyDirectId
assert(service:RefreshKeys(),'legacy direct action key refresh succeeds')
assert(preferences.UserKeyMap['Ctrl-M']==legacyDirectId
    and engineKeyMap['Ctrl-M']
    and engineKeyMap['Ctrl-M'].action:find('ExecuteKeyboardAction("cycle_mex_map","Ctrl-M")',1,true),
    'saved hidden cycle action is registered for execution without rewriting its key map: id='
        ..tostring(preferences.UserKeyMap['Ctrl-M'])..', action='
        ..tostring(engineKeyMap['Ctrl-M'] and engineKeyMap['Ctrl-M'].action))
local legacyAssignmentFound=false
for _,assignment in ipairs(service.keyboardBindings:GetAssignments()) do
    if assignment.key=='M' and assignment.modifiers.ctrl and assignment.ref.kind=='action'
        and assignment.ref.id=='cycle_mex_map' and assignment.legacy then legacyAssignmentFound=true end
end
assert(legacyAssignmentFound,'hidden legacy direct action remains visible as a saved assignment')
local legacyChoices=service.keyboardBindings:GetChoices()
local cycleChoice,sacuTechChoice=false,false
for _,choice in ipairs(legacyChoices.actions) do
    if choice.ref.id=='cycle_mex_map' then cycleChoice=true end
    if choice.ref.id=='sacu_tech' then sacuTechChoice=true end
end
assert(not cycleChoice and not sacuTechChoice,'retired actions are absent from new keyboard choices')
local missileChoices={}
for _,choice in ipairs(legacyChoices.actions) do missileChoices[choice.ref.id]=choice.label end
assert(missileChoices.smart_missile=='Запуск ракет' and not missileChoices.tactical and not missileChoices.nuke,
    'keyboard offers one smart missile action and hides both historic launch actions')
for _,id in ipairs({'suicide','dock','mode','set_default_target_priority'}) do
    assert(not missileChoices[id], 'removed action is not offered for new keyboard assignments: '..id)
end
assert(missileChoices.kill_selected_units,'instant destruction is offered on the keyboard')

local legacyReassign,legacyReassignMessage=service.keyboardBindings:Validate(
    {kind='action',id='cycle_mex_map',legacy=true},'N',{})
assert(not legacyReassign and legacyReassignMessage,'hidden legacy action cannot be assigned to a new key')
if legacyDirectOld then legacyDirectMap['Ctrl-M']=legacyDirectOld else legacyDirectMap['Ctrl-M']=nil end
assert(service:RefreshKeys(),'key refresh succeeds after restoring the test mapping')
local linkedAbsolute=service.contextModel:Get('ctxAcu')
linkedAbsolute.absolute=true
local beforeLinkedSave=saveCount
local linkedSave,linkedMessage,linkedDetails=service:CommitContext(linkedAbsolute)
assert(not linkedSave and linkedDetails and linkedDetails.kind=='absolute_link'
    and linkedMessage:find('ACU priority',1,true) and saveCount==beforeLinkedSave,
    'Runtime rejects changing a migrated linked composite to absolute and returns modal details')
assert(#mapperCalls>oldMapperCalls,'valid profile still registers its key actions')
assert(preferences.UserKeyActions.ClaretHotbuild_old==nil
    and preferences.UserKeyMap['Ctrl-X']==nil and preferences.UserDebugKeyMap['Ctrl-Y']==nil,
    'valid profile still removes stale Claret key actions and their assignments')
assert(service.model:Get('legacy').name=='Legacy','legacy profile entry remains readable')
local migrated=service.model:Export()
assert(migrated.bindings[1].id=='legacy' and migrated.bindings[1].entries[1].id=='ueb1101'
    and migrated.bindings[1].grid==nil,
    'legacy Hotbuild bindings without a composite-grid field survive normalization unchanged')
assert(service.contextModel:Get('ctxAcu').rows[1].action=='move','context profile loads separately')
local hotbuildProfile=preferences.ClaretHotbuild
local ok=service:CommitContext({id='ctxNew',name='New context',rows={{context='empty',action='select_acu'}}})
assert(ok and preferences.ClaretHotbuild==hotbuildProfile,'context save must not rewrite the Hotbuild profile')
assert(service.model:Get('legacy') and service.contextModel:Get('ctxNew'),'old and new records remain available')

local removed, removeError=service:CommitContext(nil,'ctxAcu')
assert(not removed and removeError:find('Подтвердите',1,true),'direct keyboard assignment requires confirmed deletion')
assert(service.contextModel:Get('ctxAcu'),'rejected delete leaves binding intact')

service:Start({Defer=function() end})
probeEnabled=true; diagnosticLines={}
assert(Runtime.ExecuteKeyboardAction('select_acu'),'direct context action is handled through key entry point')
Runtime.Execute('legacy')
Runtime.ExecuteKeyboardAction('unknown_action')
service.editor={}; assert(Runtime.ExecuteKeyboardAction('select_acu'),'open editor does not block the action')
keyCaptureActive=true; assert(not Runtime.ExecuteKeyboardAction('select_acu'),'active key capture blocks the action')
keyCaptureActive=false; assert(Runtime.ExecuteKeyboardAction('select_acu'),'action resumes when capture ends'); service.editor=nil
local sawInvoke,sawHandled,sawBlocked,sawBuilding,sawUnknown=false,false,false,false,false
for _,line in ipairs(diagnosticLines) do
    if line:find('[Claret][keys] invoke action=ClaretHotkeyContext_',1,true) then sawInvoke=true end
    if line:find('result=handled',1,true) then sawHandled=true end
    if line:find('result=skipped:key_capture',1,true) then sawBlocked=true end
    if line:find('[Claret][keys] invoke action=ClaretHotbuild_',1,true) then sawBuilding=true end
    if line:find('result=unknown_id',1,true) then sawUnknown=true end
end
assert(sawInvoke and sawHandled and sawBlocked and sawBuilding and sawUnknown,'probe logs key invocation and actual dispatch outcomes')
probeEnabled=false; diagnosticLines={}; Runtime.ExecuteKeyboardAction('select_acu')
assert(#diagnosticLines==0,'dispatch diagnostics stay disabled when probe is off')
local absoluteComposite={id='ctxAbsolute',name='Absolute standalone',absolute=true,rows={
    {context='empty',action='select_acu'},
}}
assert(service:CommitContext(absoluteComposite),'unlinked absolute composite can be saved')
local standaloneRegistered=false
for _,call in ipairs(mapperCalls) do
    if call[1]=='ClaretHotkeyPair_41'
        and call[2].action:find('ExecuteKeyboardPair("A", IsKeyDown(16))',1,true) then standaloneRegistered=true end
end
assert(not standaloneRegistered,'unassigned absolute composite does not add a native key action')
assert(service.keyboardBindings:Set({kind='composite',id='ctxAbsolute'},'A',{}),'keyboard page assigns composite')
assert(engineKeyMap.A and engineKeyMap.A.action:find('ExecuteKeyboardPair("A", IsKeyDown(16))',1,true),
    'keyboard assignment is applied to the engine map immediately')
preferences.UserDebugKeyMap={['Alt-Z']='ForeignDebugAction',
    ['Alt-F2']='ClaretHotkeyPair_'..encoded('Alt-F2')}
-- Count OwnIds through its single model:List() call, without exposing an internal API.
local originalList=service.model.List
local originalContextGet=service.contextModel.Get
local listCalls,labelCalls=0,0
service.model.List=function(self) listCalls=listCalls+1; return originalList(self) end
service.contextModel.Get=function(self,id)
    if id=='ctxAbsolute' then labelCalls=labelCalls+1 end
    return originalContextGet(self,id)
end
local compositeId=preferences.UserKeyMap.A
preferences.UserKeyMap.B=compositeId
preferences.UserDebugKeyMap.A=compositeId -- duplicate token across maps
preferences.UserDebugKeyMap.B='ForeignConflict' -- same chord, distinct action
preferences.UserDebugKeyMap.C='ClaretHotbuildAbsolute_6D697373696E67' -- removed legacy composite
local expected,seen={},{}
for _,map in ipairs({preferences.UserKeyMap,preferences.UserDebugKeyMap,mapper.GetCurrentKeyMap(),mapper.GetUserDebugKeyMap()}) do
    for key,id in pairs(map) do
        local token=mapper.NormalizeKeyBinding(key)..'|'..tostring(id)
        if not seen[token] then seen[token]=true; expected[#expected+1]={key=key,id=id} end
    end
end
local assignmentRows=service.keyboardBindings:GetAssignments()
assert(listCalls==1,'OwnIds must run exactly once per snapshot')
assert(labelCalls==1,'the label for an action ID is resolved once per snapshot')
assert(#assignmentRows==#expected,'duplicate tokens are omitted')
local legacy,conflict=false,false
for _,item in ipairs(expected) do
    local parsed=mapper.NormalizeKey(item.key)
    local found=false
    for _,row in ipairs(assignmentRows) do
        local sameChord=row.key==parsed.key and row.modifiers.ctrl==(parsed.Ctrl==true)
            and row.modifiers.alt==(parsed.Alt==true) and row.modifiers.shift==(parsed.Shift==true)
        local pair=service.keyboardBindings:GetPair(mapper.NormalizeKeyBinding(item.key))
        local pairRefMatches=pair and ((pair.preset and row.ref.kind=='preset' and row.ref.id==pair.preset)
            or (not pair.preset and pair.composite and row.ref.kind=='composite' and row.ref.id==pair.composite))
        if pairRefMatches and pair.composite and row.linkedRef then
            pairRefMatches=row.linkedRef.id==pair.composite
        end
        local actualId=row.ref.kind=='foreign' and row.ref.id or
            (row.ref.legacy and ('ClaretHotbuildAbsolute_'..string.upper((row.ref.id:gsub('.',function(c) return string.format('%02x',string.byte(c)) end)))) or compositeId)
        if sameChord and ((item.id:find('ClaretHotkeyPair_',1,true)==1 and pairRefMatches) or actualId==item.id) then
            found=true
            if row.ref.legacy and row.ref.id=='missing' then legacy=true end
            if row.ref.kind=='foreign' and row.ref.id=='ForeignConflict' then conflict=true end
        end
    end
    if not found then
        local rows={}
        for _,row in ipairs(assignmentRows) do table.insert(rows,tostring(row.key)..'/'..tostring(row.ref.kind)..'/'..tostring(row.ref.id)) end
        assert(found,'assignment identity and modifiers are preserved for '..tostring(item.key)..' / '..tostring(item.id)..' rows='..table.concat(rows,','))
    end
end
assert(legacy and conflict,'removed legacy IDs and foreign conflicts remain visible')
service.keyboardBindings:GetAssignments()
assert(listCalls==2 and labelCalls==2,'each snapshot recomputes IDs and labels')
service.model.List=originalList
service.contextModel.Get=originalContextGet
preferences.UserKeyMap.B=nil
preferences.UserDebugKeyMap.A=nil; preferences.UserDebugKeyMap.B=nil; preferences.UserDebugKeyMap.C=nil
local sawDefault,sawForeign=false,false
for _,row in ipairs(assignmentRows) do
    if row.ref.kind=='foreign' and row.ref.id=='DefaultAction' then sawDefault=true end
    if row.ref.kind=='foreign' and row.ref.id=='ForeignDebugAction' then sawForeign=true end
end
assert(sawDefault and sawForeign,'assignment snapshot includes native defaults and debug-map conflicts')
local free,message=service.keyboardBindings:Validate({kind='composite',id='ctxAbsolute'},'D',{ctrl=true})
assert(not free and message,'native default assignment blocks the exact chord')
local ref={kind='composite',id='ctxAbsolute'}
local _,_,collision=service.keyboardBindings:Validate(ref,'D',{ctrl=true})
assert(collision and collision.kind=='conflict' and collision.id=='DefaultAction','default conflict identifies occupant')
assert(not service.keyboardBindings:Set(ref,'D',{ctrl=true}),'conflict requires confirmation')
assert(not service.keyboardBindings:Set(ref,'D',{ctrl=true},'ChangedAction'),'stale confirmation cannot replace a different action')
engineKeyMap['Ctrl-D']={action='previous engine action'}
applyCalls={}; probeEnabled=true
assert(service.keyboardBindings:Set(ref,'D',{ctrl=true},collision.id),'confirmed default conflict can be replaced')
assert(table.concat(applyCalls,',')=='save,clear,add,modifiers,add,labels','commit follows native save and full apply sequence')
assert(engineKeyMap.A and engineKeyMap['Alt-Z'],'full apply preserves other Claret and foreign bindings')
local logged=false; for _,line in ipairs(diagnosticLines) do if line:find('[Claret][keys] key=Ctrl-D action=',1,true) and line:find('defined=true',1,true) then logged=true end end
assert(logged,'enabled probe reports resolved Claret binding')
missingDefinitionKey='Q'; applyCalls={}
local failed,reason=service.keyboardBindings:Set({kind='action',id='select_acu'},'Q',{})
assert(not failed and reason and not preferences.UserKeyMap.Q and engineKeyMap.A,'missing resolved definition rejects and rolls back assignment')
local missingLogged=false; for _,line in ipairs(diagnosticLines) do if line:find('key=Q action=',1,true) and line:find('defined=false',1,true) then missingLogged=true end end
assert(missingLogged,'enabled probe reports an unresolved definition')
missingDefinitionKey=nil
assert(service.keyboardBindings:Set({kind='action',id='select_acu'},'Q',{}),'context definition is registered before applying')
assert(engineKeyMap.Q and engineKeyMap.Q.action:find('ExecuteKeyboardAction',1,true),'context mapping contains the registered action')
assert(engineKeyMap.Q.action:find('"Q"',1,true),'direct action dispatch carries its actual chord')
assert(service.keyboardBindings:Set({kind='preset',id='legacy'},'R',{}),'building definition is registered before applying')
assert(engineKeyMap.R and engineKeyMap.R.action:find('ExecuteKeyboardPair("R", IsKeyDown(16))',1,true),'building mapping contains the registered action')
probeEnabled=false
assert(preferences.UserKeyMap['Ctrl-D']~='DefaultAction' and engineKeyMap['Ctrl-D'].action:find('ExecuteKeyboardPair("Ctrl-D", IsKeyDown(16))',1,true),'confirmed replacement removes the existing engine action before installation')
local removed,removeMessage=service:CommitContext(nil,'ctxAbsolute')
assert(not removed and removeMessage:find('Подтвердите',1,true),
    'a composite with a direct keyboard assignment requests confirmation')
for _,call in ipairs(mapperCalls) do
    if call[1]=='ClaretHotkeyPair_41'
        and call[2].action:find('ExecuteKeyboardPair("A", IsKeyDown(16))',1,true) then standaloneRegistered=true end
end
assert(standaloneRegistered,'assigned composite gets a standalone native key action')
assert(service.keyboardBindings:Set({kind='composite',id='ctxAbsolute'},'B',{ctrl=true}),
    'same action can retain a second modified key chord')
assert(engineKeyMap['Ctrl-B'],'second chord is immediately installed')
assert(service.keyboardBindings:Clear({kind='composite',id='ctxAbsolute'},'B',{ctrl=true}),
    'one exact chord can be removed')
assert(not engineKeyMap['Ctrl-B'] and engineKeyMap.A,'clearing one chord preserves the other')
failSave=true
local clearSaved=service.keyboardBindings:Clear({kind='composite',id='ctxAbsolute'},'A',{})
assert(not clearSaved and preferences.UserKeyMap.A and engineKeyMap.A,
    'failed clear write restores the profile and engine assignment')
failEngineAdd=true
local failedKey,failedMessage=service.keyboardBindings:Set({kind='composite',id='ctxAbsolute'},'C',{})
assert(not failedKey and failedMessage and not preferences.UserKeyMap.C,
    'engine mapping failure rolls profile assignment back')
assert(engineKeyMap.A and not engineKeyMap.C,'engine rollback restores previous mapping and removes a partial write')
preferences.UserKeyMap.B='ClaretHotbuildAbsolute_6374784162736F6C757465'
service:RefreshKeys()
local targetUnit=makeUnit('COMMAND')
simulateSelection=targetUnit
selected={makeUnit('FACTORY')}
assert(service:ExecuteAbsolute('ctxAbsolute') and selected[1]==targetUnit,
    'standalone absolute empty-context action executes regardless current selection')
simulateSelection=nil
local switchedOff=service.contextModel:Get('ctxAbsolute'); switchedOff.absolute=false
assert(service:CommitContext(switchedOff),'standalone composite can switch absolute mode off')
local preservedRegistered=false
for _,call in ipairs(mapperCalls) do
    if call[1]:find('ClaretHotbuildAbsolute_',1,true)
        and call[2].action:find('ExecuteAbsolute("ctxAbsolute")',1,true) then preservedRegistered=true end
end
assert(preferences.UserKeyMap.B=='ClaretHotbuildAbsolute_6374784162736F6C757465',
    'switching off absolute mode preserves the legacy profile action link')
assert(preservedRegistered,'assigned legacy absolute ID retains its ExecuteAbsolute action')
selected={makeUnit('COMMAND','CANNOT_BUILD')}
local executed=service:ExecuteKeyboardPair('F1')
assert(executed and #commandCalls==1 and commandCalls[1][2].name=='RULEUCC_Move','ACU action runs before build')
assert(#buildCalls==0,'ACU action priority must suppress build')

selected={makeUnit('ENGINEER')}
local beforeActions=#commandCalls
executed=service:ExecuteKeyboardPair('F2')
assert(executed and commandMode[1]=='build' and #buildCalls==0,'engineer build placement runs first')
assert(#commandCalls==beforeActions+1 and commandCalls[#commandCalls][2].name=='ueb1101',
    'engineer action must not override an available build')

selected={}
local beforeEmptySelects=#selectCalls
executed=service:Execute('empty','ctxEmpty')
assert(executed and #selectCalls==beforeEmptySelects+2
    and selectCalls[#selectCalls-1]=='UI_SelectByCategory +inview +nearest COMMAND'
    and selectCalls[#selectCalls]=='UI_SelectByCategory +nearest +goto COMMAND',
    'empty selection tries the visible ACU first, then uses the configured map fallback')

selected={makeUnit('COMMAND','CANNOT_BUILD'),makeUnit('ENGINEER','CANNOT_BUILD')}
local beforeMixed=#commandCalls
local beforeMixedBuilds=#buildCalls
executed=service:Execute('mixed','ctxMixed')
assert(not executed and #commandCalls==beforeMixed and #buildCalls==beforeMixedBuilds,
    'conflicting builder siblings consume the key without executing')

selected={makeUnit('ENGINEER','CANNOT_BUILD'),makeUnit('LAND')}
local beforeEngineerOther=#commandCalls
executed=service:Execute('mixed','ctxMixed')
assert(executed and #commandCalls==beforeEngineerOther+1
    and commandCalls[#commandCalls][2].name=='RULEUCC_Reclaim',
    'engineer context wins over other units in mixed selection')

selected={makeUnit('COMMAND','CANNOT_BUILD')}
beforeMixed=#commandCalls
executed=service:Execute('hierarchy','ctxHierarchy')
assert(executed and commandCalls[#commandCalls][2].name=='RULEUCC_Move'
    and #commandCalls==beforeMixed+1,'child own action overrides the parent builder action')

selected={makeUnit('ENGINEER','CANNOT_BUILD')}
beforeMixed=#commandCalls
executed=service:Execute('hierarchy','ctxHierarchy')
assert(executed and commandCalls[#commandCalls][2].name=='RULEUCC_Reclaim'
    and #commandCalls==beforeMixed+1,'inherit mode dispatches the shared parent builder action')

selected={makeUnit('SUBCOMMANDER','CANNOT_BUILD')}
beforeMixed=#commandCalls
beforeMixedBuilds=#buildCalls
local disabledResult,disabledReason=service:Execute('hierarchy','ctxHierarchy')
assert(not disabledResult and #commandCalls==beforeMixed and #buildCalls==beforeMixedBuilds,
    'disabled child does not inherit an action')

selected={makeUnit('EXTERNALFACTORY','MOBILE'),makeUnit('COMMAND','CANNOT_BUILD')}
local beforeMobileActions=#commandCalls
executed=service:Execute('mobile','ctxMobile')
assert(executed and #commandCalls==beforeMobileActions+1 and #buildCalls==beforeMixedBuilds,
    'mobile-only factory multibind has priority when the ordinary builder cannot build')

selected={makeUnit('COMMAND')}
local beforeMissing=#commandCalls
local missing, missingReason=service:Execute('missing','ctxRemoved')
assert(missing==nil and missingReason:find('ctxRemoved',1,true),'removed context link reports unavailable')
assert(#commandCalls==beforeMissing,'removed link never executes a replacement action')

local savesBeforeFailure=saveCount
failSave=true
preferences.ClaretHotbuildContexts.version=2
local beforeSaved=preferences.ClaretHotbuildContexts
local beforeCount=#service.contextModel:List()
local saveOk=service:CommitContext({id='ctxFailure',name='Failed save',rows={{context='empty',action='select_acu'}}})
assert(not saveOk and preferences.ClaretHotbuildContexts==beforeSaved and preferences.ClaretHotbuildContexts.version==2
    and not service.contextModel:Get('ctxFailure'),'failed write restores profile data')
assert(#service.contextModel:List()==beforeCount and not service.contextModel:Get('ctxFailure'),
    'failed write leaves runtime model unchanged')
failSave=false
assert(saveCount==savesBeforeFailure,'failed context write never reaches a successful SavePreferences')
assert(service.contextModel:Put({id='ctxQuick',name='Quick',rows={
    {context='empty',action='select_acu',quickRepeat='select_bombers'},
    {context='acu',action='move'}}}))
assert(service.contextModel:Put({id='ctxFallback',name='Fallback',rows={
    {context='empty',action='select_acu',fallback='select_bombers',quickRepeat='select_transport_map'}}}))
assert(service.contextModel:Put({id='ctxFallbackAbs',name='Fallback absolute',absolute=true,rows={
    {context='empty',action='select_acu',fallback='select_bombers',quickRepeat='select_transport_map'}}}))
assert(not service.contextModel:Put({id='badFallback',name='Invalid',rows={{context='acu',action='move',fallback='stop'}}}))
selected={}; simulateSelection=nil; fallbackSelection=makeUnit('AIR','BOMBER'); testNow=0
local beforeFallback=#selectCalls
assert(service:ExecuteKeyboardComposite('ctxFallback','Z'))
assert(#selectCalls==beforeFallback+3
    and selectCalls[beforeFallback+1]=='UI_SelectByCategory +inview +nearest COMMAND'
    and selectCalls[beforeFallback+2]=='UI_SelectByCategory +nearest +goto COMMAND'
    and selectCalls[#selectCalls]=='UI_SelectByCategory AIR BOMBER','fallback runs once after both ACU selection attempts miss')
testNow=0.1
assert(service:ExecuteKeyboardComposite('ctxFallback','Z'))
assert(#selectCalls==beforeFallback+4 and selectCalls[#selectCalls]=='UI_SelectByCategory AIR TRANSPORTATION','quick repeat remembers fallback selection and does not trigger fallback')
simulateSelection=makeUnit('COMMAND','CANNOT_BUILD'); selected={}; testNow=1
beforeFallback=#selectCalls
assert(service:ExecuteKeyboardComposite('ctxFallback','Z'))
assert(#selectCalls==beforeFallback+1,'found main action does not run fallback')
selected={simulateSelection}; testNow=3; beforeFallback=#selectCalls
assert(service:ExecuteAbsolute('ctxFallbackAbs','Z'))
assert(#selectCalls==beforeFallback+1,'already selected target suppresses absolute fallback')
simulateSelection=nil; selected={}; testNow=5; beforeFallback=#selectCalls
assert(service:ExecuteAbsolute('ctxFallbackAbs','Z'))
assert(#selectCalls==beforeFallback+3,'absolute fallback runs after both ACU selection attempts miss')
fallbackSelection=nil
simulateSelection=makeUnit('COMMAND','CANNOT_BUILD')
selected={}; testNow=0
assert(service:ExecuteKeyboardComposite('ctxQuick','Q'))
testNow=0.4
assert(service:ExecuteKeyboardComposite('ctxQuick','Q') and selectCalls[#selectCalls]=='UI_SelectByCategory AIR BOMBER',
    'quick repeat precedes the new selection column')
testNow=0.5
assert(service:ExecuteKeyboardComposite('ctxQuick','Q') and commandCalls[#commandCalls][2].name=='RULEUCC_Move',
    'quick repeat does not rearm')
selected={}; testNow=1
assert(service:ExecuteKeyboardComposite('ctxQuick','Q'))
service:QuickSelectionChanged({}); service:QuickSelectionChanged({simulateSelection})
selected={simulateSelection}; testNow=1.2
assert(service:ExecuteKeyboardComposite('ctxQuick','Q') and commandCalls[#commandCalls][2].name=='RULEUCC_Move',
    'selection change and restoration breaks the chain')
selected={}; testNow=2
assert(service:ExecuteKeyboardComposite('ctxQuick','Q'))
testNow=4
assert(service:ExecuteKeyboardComposite('ctxQuick','Q') and commandCalls[#commandCalls][2].name=='RULEUCC_Move',
    'expired window uses the normal column')
selected={}; testNow=5
assert(service:ExecuteKeyboardComposite('ctxQuick','Q'))
testNow=5.2
assert(service:ExecuteKeyboardAction('select_acu','R'))
testNow=5.3
assert(service:ExecuteKeyboardComposite('ctxQuick','Q') and commandCalls[#commandCalls][2].name=='RULEUCC_Move',
    'another Claret chord breaks the repeat chain')
selected={}; testNow=5.4
assert(service:ExecuteKeyboardComposite('ctxQuick','Q'))
testNow=5.5
assert(not Runtime.ExecuteKeyboardAction('removed_action','R'))
testNow=5.6
assert(service:ExecuteKeyboardComposite('ctxQuick','Q') and commandCalls[#commandCalls][2].name=='RULEUCC_Move',
    'an unavailable different Claret key also breaks the repeat chain')
assert(service.contextModel:Put({id='ctxAbsoluteQuick',name='Absolute quick',absolute=true,rows={
    {context='empty',action='select_acu',quickRepeat='select_bombers'}}}))
selected={}; testNow=6
assert(service:ExecuteAbsolute('ctxAbsoluteQuick','P'))
testNow=6.2
assert(service:ExecuteAbsolute('ctxAbsoluteQuick','P') and selectCalls[#selectCalls]=='UI_SelectByCategory AIR BOMBER',
    'absolute binding executes quick repeat after selection')
selected={}; testNow=7
assert(service:ExecuteMappedAbsolute('ctxAbsoluteQuick','P'))
testNow=7.2
assert(service:ExecuteMappedAbsolute('ctxAbsoluteQuick','U')
    and selectCalls[#selectCalls]=='UI_SelectByCategory +inview +nearest COMMAND',
    'different physical chords assigned to one legacy action are not a quick repeat')
selected={}; testNow=8
assert(service:ExecuteKeyboardAction('select_acu_double','P'))
testNow=8.2
assert(service:ExecuteKeyboardAction('select_acu_double','U')
    and selectCalls[#selectCalls]=='UI_SelectByCategory +nearest +goto COMMAND',
    'legacy continuation retains action-ID semantics for existing aliases')
assert(service.contextModel:Put({id='ctxDouble',name='Double ACU',rows={
    {context='empty',action='select_acu_double'},{context='acu',action='move'}}}))
assert(service.model:Put({id='double',name='Double',key='',entries={},grid={buildings={},units={},context='ctxDouble'}}))
simulateSelection=makeUnit('COMMAND','CANNOT_BUILD')
selected={}; testNow=0
assert(service:Execute('double','ctxDouble') and selected[1]==simulateSelection,'first press selects ACU')
testNow=0.3
assert(service:Execute('double','ctxDouble') and selectCalls[#selectCalls]=='UI_SelectByCategory +nearest +goto COMMAND',
    'double press runs continuation before the individual ACU action')
selected={}; testNow=1
assert(service:Execute('double','ctxDouble'))
testNow=2
assert(service:Execute('double','ctxDouble') and commandCalls[#commandCalls][2].name=='RULEUCC_Move',
    'after the double-click window the individual ACU action remains available')
assert(service.contextModel:Put({id='ctxAdd',name='Add engineers',rows={
    {context='empty',action='select_engineers_t1',quickRepeat='select_engineers_t1'}}}))
assert(service.model:Put({id='add',name='Add',key='',entries={},grid={buildings={},units={},context='ctxAdd'}}))
local engineerA=makeUnit('ENGINEER','MOBILE','TECH1','CANNOT_BUILD'); engineerA.entityId=1
local engineerB=makeUnit('ENGINEER','MOBILE','TECH1','CANNOT_BUILD'); engineerB.entityId=2
local engineerC=makeUnit('ENGINEER','MOBILE','TECH1','CANNOT_BUILD'); engineerC.entityId=3
local engineerD=makeUnit('ENGINEER','MOBILE','TECH1','CANNOT_BUILD'); engineerD.entityId=4
local engineerE=makeUnit('ENGINEER','MOBILE','TECH1','CANNOT_BUILD'); engineerE.entityId=5
engineerCandidates={engineerA,engineerB,engineerC,engineerD,engineerE}; selected={}; testNow=5
assert(service:Execute('add','ctxAdd') and #selected==1 and selected[1]==engineerA,'first press selects one engineer')
testNow=25
assert(service:Execute('add','ctxAdd') and #selected==2 and selected[2]==engineerB,
    'same binding adds the next engineer even after a long pause')
for press=3,5 do
    testNow=testNow+0.1
    assert(service:Execute('add','ctxAdd') and #selected==press, 'legacy accumulation adds engineer on press '..press)
end
assert(service.contextModel:Put({id='ctxQuickAdd',name='Quick add',rows={
    {context='empty',action='select_acu',quickRepeat='select_engineers_t1'}}}))
selected={}; simulateSelection=engineerA; testNow=30
assert(service:ExecuteKeyboardComposite('ctxQuickAdd','K') and #selected==1)
for press=2,5 do
    testNow=testNow+0.1
    assert(service:ExecuteKeyboardComposite('ctxQuickAdd','K') and #selected==press,
        'quick repeat enters legacy accumulation on press '..press)
end
local unrelated=makeUnit('LAND','CANNOT_BUILD'); unrelated.entityId=33
selected={unrelated}; testNow=26
assert(service:Execute('add','ctxAdd') and #selected==2 and selected[1]==unrelated and selected[2]==engineerA,
    'engineer binding adds to an unrelated existing selection without a preceding empty press')
local mexA=makeUnit('MASSEXTRACTION','CANNOT_BUILD'); mexA.entityId=20
local mexB=makeUnit('MASSEXTRACTION','CANNOT_BUILD'); mexB.entityId=21
local upgrades=0
modules['/mods/ClaretHotbuild/modules/ContextUpgrade.lua']={
    Available=function() return true end,
    Execute=function(_,context)
        if #context.selection==0 then selected={mexA}
        else upgrades=upgrades+1; selected={mexB} end
        return true
    end,
}
assert(service.contextModel:Put({id='ctxMexNext',name='Mex',rows={
    {context='empty',action='upgrade_mex_select_next'}}}))
assert(service.model:Put({id='mexNext',name='Mex',key='',entries={},grid={buildings={},units={},context='ctxMexNext'}}))
selected={}; assert(service:Execute('mexNext','ctxMexNext') and selected[1]==mexA,'mex action begins from empty selection')
testNow=50
assert(service:Execute('mexNext','ctxMexNext') and selected[1]==mexB and upgrades==1,
    'mex action continues through runtime after the selection changes')
local cursorEligible=true
local cursorCalls=0
modules['/mods/ClaretHotbuild/modules/ContextUpgrade.lua']={
    Available=function() return cursorEligible end,
    Execute=function() cursorCalls=cursorCalls+1; return true end,
}
assert(service.contextModel:Put({id='cursor_priority',name='Cursor',rows={
    {context='cursor',action='upgrade_structure_under_cursor'},
    {context='empty',action='select_acu_double'}, {context='acu',action='select_acu_double'},
}}))
selected={}; simulateSelection=makeUnit('COMMAND','CANNOT_BUILD'); testNow=58
cursorEligible=false
assert(service:ExecuteKeyboardComposite('cursor_priority') and selected[1]==simulateSelection,
    'invalid rollover falls through to the ordinary empty-selection action')
cursorEligible=true
local beforeCursorRepeat=#selectCalls
assert(service:ExecuteKeyboardComposite('cursor_priority') and cursorCalls==1 and #selected==1
    and #selectCalls==beforeCursorRepeat,
    'valid cursor has priority over the selection action and clears its pending continuation')
cursorEligible=false
assert(service:ExecuteKeyboardComposite('cursor_priority')
    and selectCalls[#selectCalls]=='UI_SelectByCategory +nearest COMMAND',
    'after an invalid rollover the changed selection uses ordinary context without stale continuation')

-- A valid cursor binding also precedes a buildable Hotbuild structure.
assert(service.model:Put({id='cursor_build_priority',name='Cursor vs build',key='',
    entries={{kind='blueprint',id='ueb1101'}},grid={buildings={},units={},context='cursor_priority'}}))
selected={makeUnit('ENGINEER')}; simulateSelection=nil; cursorEligible=true
local buildsBeforeCursor=#buildCalls
local commandsBeforeCursor=#commandCalls
assert(service:Execute('cursor_build_priority','cursor_priority') and cursorCalls==2
    and #buildCalls==buildsBeforeCursor and #commandCalls==commandsBeforeCursor
    and #selected==1 and selected[1]:IsInCategory('ENGINEER'),
    'valid cursor has priority over build placement and preserves the engineer selection')
cursorEligible=false; selected={makeUnit('ENGINEER')}
local commandsBeforeFallback=#commandCalls
assert(service:Execute('cursor_build_priority','cursor_priority') and #commandCalls==commandsBeforeFallback+1
    and commandCalls[#commandCalls][1]=='build' and commandCalls[#commandCalls][2].name=='ueb1101',
    'the same buildable preset proceeds through the ordinary builder path when rollover is invalid')

-- Factory cycle continuation is accepted after the first press selects a factory.
assert(service.contextModel:Put({id='cycle_factory',name='Factory cycle',rows={{context='empty',action='cycle_idle_factories'}}}))
cycleFactory=makeUnit('FACTORY'); cycleFactory.entityId=98765
selected={}; testNow=59
assert(service:ExecuteKeyboardComposite('cycle_factory') and selected[1]==cycleFactory
    and selectCalls[#selectCalls]=='UI_Lua import("/lua/keymap/misckeyactions.lua").CycleIdleFactories()',
    'first factory cycle press selects an idle factory')
local cycleCallsBefore=#selectCalls
assert(service:ExecuteKeyboardComposite('cycle_factory') and selected[1]==cycleFactory
    and #selectCalls==cycleCallsBefore+1
    and selectCalls[#selectCalls]=='UI_Lua import("/lua/keymap/misckeyactions.lua").CycleIdleFactories()',
    'factory cycle repeats after its first press changes selection to a factory')
cycleFactory=nil
selected={}; simulateSelection=makeUnit('COMMAND','CANNOT_BUILD'); testNow=60
assert(service:ExecuteKeyboardComposite('ctxDouble') and selected[1]==simulateSelection,
    'direct non-absolute composite executes its empty-context row')
testNow=60.3
assert(service:ExecuteKeyboardComposite('ctxDouble') and selectCalls[#selectCalls]=='UI_SelectByCategory +nearest +goto COMMAND',
    'direct composite continuation runs before the changed ACU context row')
selected={}; testNow=61
assert(service:ExecuteKeyboardAction('select_acu_double') and selected[1]==simulateSelection,
    'standalone individual action executes under an empty selection')
testNow=61.3
assert(service:ExecuteKeyboardAction('select_acu_double') and selectCalls[#selectCalls]=='UI_SelectByCategory +nearest +goto COMMAND',
    'standalone action preserves double-press continuation after selection changes')
-- Units win over a buildable engineer, and the same arbitration is used by direct binds.
assert(service.contextModel:Put({id='phase1',name='Phase 1',rows={
    {context='units',action='move'}, {context='air',mode='own',action='stop'},
    {context='engineer',mode='own',action='reclaim'}, {context='other',action='stop'},
}}))
assert(service.model:Put({id='phase1_preset',name='Phase 1 preset',key='',entries={{kind='blueprint',id='ueb1101'}},
    grid={buildings={},units={},context='phase1'}}))
selected={makeUnit('MOBILE','LAND'),makeUnit('ENGINEER')}
local phaseCommands=#commandCalls
local phaseResult,phaseMessage=service:Execute('phase1_preset','phase1')
assert(phaseResult and #commandCalls==phaseCommands+1
    and commandCalls[#commandCalls][2].name=='RULEUCC_Move', 'Units action precedes a buildable engineer: '..tostring(phaseMessage)..' calls='..tostring(#commandCalls-phaseCommands))
selected={makeUnit('MOBILE','LAND'),makeUnit('MOBILE','AIR')}
phaseCommands=#commandCalls
assert(not service:ExecuteKeyboardComposite('phase1') and #commandCalls==phaseCommands,
    'different selected unit child actions consume the key')
assert(service.contextModel:Put({id='phase1_same',name='Matching siblings',rows={
    {context='units',action='move'}, {context='air',mode='own',action='move'},
}}))
assert(service:ExecuteKeyboardComposite('phase1_same') and #commandCalls==phaseCommands+1,
    'matching sibling actions execute once')
assert(service.contextModel:Put({id='phase1_disabled',name='Disabled sibling',rows={
    {context='land',mode='own',action='move'}, {context='air',mode='disabled'},
}}))
phaseCommands=#commandCalls
assert(service:ExecuteKeyboardComposite('phase1_disabled') and #commandCalls==phaseCommands+1,
    'disabled sibling does not block an assigned sibling')
assert(service.contextModel:Put({id='phase1_legacy',name='Legacy fallback',rows={{context='other',action='move'}}}))
selected={makeUnit('MOBILE','LAND')}
phaseCommands=#commandCalls
assert(service:ExecuteKeyboardComposite('phase1_legacy') and #commandCalls==phaseCommands+1,
    'empty Units group falls back to legacy Other')
-- Per-chord pairs own both slots and dispatch independently of grid.context metadata.
selected={makeUnit('COMMAND','CANNOT_BUILD')}
local pairCommands=#commandCalls
assert(service:ExecuteKeyboardPair('F1') and commandCalls[#commandCalls][2].name=='RULEUCC_Move',
    'first migrated key dispatches its own composite')
selected={makeUnit('ENGINEER','CANNOT_BUILD')}
assert(service:ExecuteKeyboardPair('Alt-F2') and commandCalls[#commandCalls][2].name=='RULEUCC_Reclaim',
    'second migrated key dispatches a different composite')
local acuPreset=service.model:Get('acu')
acuPreset.grid.context='ctxEngineer' -- Deliberately disagrees with migrated F1 pair.
pairCommands=#commandCalls
selected={makeUnit('COMMAND','CANNOT_BUILD')}
assert(service:ExecuteKeyboardPair('F1') and commandCalls[#commandCalls][2].name=='RULEUCC_Move'
    and #commandCalls==pairCommands+1,'pair dispatch ignores preset grid.context after migration')

assert(service:CommitContext({id='pair_empty',name='Pair empty',rows={{context='empty',action='select_acu'}}}))
assert(service:CommitContext({id='pair_other',name='Pair other',rows={{context='empty',action='select_engineers_t1'}}}))
assert(service:Commit({id='pair_preset',name='Pair preset',key='',entries={{kind='blueprint',id='ueb1101'}}}))
assert(service:Commit({id='pair_preset_2',name='Pair preset 2',key='',entries={{kind='blueprint',id='ueb1101'}}}))
local pairPreset={kind='preset',id='pair_preset'}
local pairComposite={kind='composite',id='pair_empty'}
assert(service.keyboardBindings:Set(pairPreset,'Z',{}),'preset slot can be assigned to an unoccupied chord')
assert(service.keyboardBindings:Set(pairComposite,'Z',{}),'compatible composite fills the other slot without confirmation')
local chordPair=preferences.ClaretHotbuildKeyboard.assignments.Z
assert(chordPair.preset=='pair_preset' and chordPair.composite=='pair_empty'
    and preferences.UserKeyMap.Z=='ClaretHotkeyPair_'..encoded('Z'),
    'pair slots share a generated pair action mapping')
assert(service.keyboardBindings:Set({kind='composite',id='pair_other'},'Z',{}),
    'setting an occupied slot replaces that slot without confirmation')
chordPair=preferences.ClaretHotbuildKeyboard.assignments.Z
assert(chordPair.composite=='pair_other' and chordPair.preset=='pair_preset',
    'replacing the composite preserves the preset slot')
assert(service.keyboardBindings:Set({kind='preset',id='pair_preset_2'},'Z',{}),
    'setting an occupied preset slot replaces that slot without confirmation')
assert(preferences.ClaretHotbuildKeyboard.assignments.Z.preset=='pair_preset_2'
    and preferences.ClaretHotbuildKeyboard.assignments.Z.composite=='pair_other',
    'replacing the preset preserves the composite slot')
assert(service.keyboardBindings:Clear({kind='preset',id='pair_preset_2'},'Z',{}),
    'preset slot can be cleared independently')
assert(preferences.ClaretHotbuildKeyboard.assignments.Z.preset==nil
    and preferences.ClaretHotbuildKeyboard.assignments.Z.composite=='pair_other',
    'clearing preset leaves the composite slot intact')
assert(service.keyboardBindings:Set(pairPreset,'Z',{}),'preset slot can be re-added independently')
assert(service.keyboardBindings:Set(pairPreset,'Y',{}),
    'one preset can be assigned to a second chord')
assert(service.keyboardBindings:Set(pairComposite,'Y',{}),
    'the same preset can use a different composite on its second chord')
assert(preferences.ClaretHotbuildKeyboard.assignments.Y.preset=='pair_preset'
    and preferences.ClaretHotbuildKeyboard.assignments.Y.composite=='pair_empty'
    and preferences.ClaretHotbuildKeyboard.assignments.Z.composite=='pair_other',
    'one preset retains per-key composite choices across two chords')
assert(service.keyboardBindings:Set(pairPreset,'X',{}),'preset can share a chord with a direct action')
assert(service.keyboardBindings:Set({kind='action',id='select_scout'},'X',{}),
    'direct action fills the additional pair slot')
local actionPair=preferences.ClaretHotbuildKeyboard.assignments.X
assert(actionPair.preset=='pair_preset' and actionPair.action=='select_scout'
    and preferences.UserKeyMap.X=='ClaretHotkeyPair_'..encoded('X'),
    'preset and direct action are preserved in the same per-key profile entry')
local previousSelects,previousCommands=#selectCalls,#commandCalls
selected={makeUnit('MOBILE','LAND'),makeUnit('ENGINEER')}
assert(service:ExecuteKeyboardPair('X') and #commandCalls==previousCommands+1
    and #selectCalls==previousSelects,
    'a buildable preset takes priority when ordinary builders are mixed with units')
selected={makeUnit('ENGINEER','CANNOT_BUILD'),makeUnit('MOBILE','LAND')}
previousSelects=#selectCalls
assert(service:ExecuteKeyboardPair('X') and #selectCalls==previousSelects+1,
    'direct action runs when no ordinary builder can build the paired preset')
local doubleChoices=service.keyboardBindings:GetDoubleChoices('select_scout')
local transportActions={'append_transport_cargo','ferry','transport_order'}
for _,first in ipairs(transportActions) do
    local choices=service.keyboardBindings:GetDoubleChoices(first)
    assert(#choices==2,'transport action offers the other transport actions: '..first..' -> '..#choices)
    for _,choice in ipairs(choices) do assert(choice.id~=first,'transport action does not offer itself') end
end

assert(service.keyboardBindings:Set({kind='action',id='append_transport_cargo'},'V',{}))
assert(service.keyboardBindings:SetDoubleForKey('V',{},'append_transport_cargo','ferry'))
local shownDouble
for _,assignment in ipairs(service.keyboardBindings:GetAssignments()) do
    if assignment.key=='V' then shownDouble=assignment.doubleLabel end
end
assert(shownDouble=='Паромный маршрут','assignment exposes the saved repeat action')
service:RefreshKeys()
assert(service.keyboardBindings:GetDoubleForKey('V',{}).second=='ferry','transport pair survives reload')
assert(not service.keyboardBindings:SetDoubleForKey('V',{},'append_transport_cargo','select_transport_map'),'transport action does not offer selection actions')
preferences.ClaretHotbuildKeyboard.assignments.V.doubleSecond='transport_order'
local reloaded=Runtime.Create(false)
assert(reloaded.keyboardBindings:GetDoubleForKey('V',{}).second=='transport_order','previously saved pair survives reload')
assert(not service.keyboardBindings:SetDoubleForKey('V',{},'append_transport_cargo','append_transport_cargo'),'transport action cannot repeat itself')
assert(#doubleChoices==1 and doubleChoices[1].id=='select_all_scouts',
    'scout double press exposes only the same-unit-type safe target')
assert(not service.keyboardBindings:SetDoubleForKey('X',{},'select_scout','select_transport_map'),
    'double press rejects cross-unit-type selection mappings')
assert(service.keyboardBindings:SetDoubleForKey('X',{},'select_scout','select_all_scouts'),
    'safe double press can be persisted per chord')
assert(service.keyboardBindings:GetDoubleForKey('X',{}).second=='select_all_scouts'
    and preferences.ClaretHotbuildKeyboard.version==2,
    'double press is queryable and stored in the migrated profile format')
assert(service.keyboardBindings:Set({kind='composite',id='pair_other'},'X',{}),
    'composite replaces the action in the shared direct-action slot')
assert(preferences.ClaretHotbuildKeyboard.assignments.X.action==nil
    and preferences.ClaretHotbuildKeyboard.assignments.X.composite=='pair_other'
    and preferences.ClaretHotbuildKeyboard.assignments.X.doubleFirst==nil,
    'replacing action with composite clears stale action and double data')
assert(service.keyboardBindings:Set({kind='action',id='select_scout'},'X',{}),
    'action replaces composite in the shared direct-action slot')
assert(preferences.ClaretHotbuildKeyboard.assignments.X.action=='select_scout'
    and preferences.ClaretHotbuildKeyboard.assignments.X.composite==nil,
    'replacing composite with action clears the old composite')
assert(service.keyboardBindings:Clear(pairPreset,'X',{}),'preset can be removed independently of its action')
assert(service.keyboardBindings:Clear({kind='action',id='select_scout'},'X',{}),
    'paired action can be cleared')
assert(service.keyboardBindings:Set({kind='action',id='select_scout'},'X',{}),
    'direct action can be assigned before the preset')
assert(service.keyboardBindings:SetDoubleForKey('X',{},'select_scout','select_all_scouts'),
    'double press can be configured on a native direct action')
assert(service.keyboardBindings:Set(pairPreset,'X',{}),
    'preset can be added after a direct action assignment')
assert(preferences.ClaretHotbuildKeyboard.assignments.X.action=='select_scout'
    and preferences.ClaretHotbuildKeyboard.assignments.X.preset=='pair_preset'
    and preferences.ClaretHotbuildKeyboard.assignments.X.doubleSecond=='select_all_scouts',
    'adding a preset after a direct action preserves action and double configuration')
assert(service.keyboardBindings:Set({kind='composite',id='ctxAbsolute'},'H',{}),
    'direct composite can occupy the action/composite slot')
assert(service.keyboardBindings:Set({kind='action',id='select_scout'},'H',{}),
    'direct action can replace a standalone composite')
assert(preferences.UserKeyMap.H=='ClaretHotkeyPair_'..encoded('H')
    and preferences.ClaretHotbuildKeyboard.assignments.H.composite==nil
    and preferences.ClaretHotbuildKeyboard.assignments.H.action=='select_scout',
    'replacement installs the paired action mapping without stale composite data')
engineerCandidates={makeUnit('ENGINEER','MOBILE','CANNOT_BUILD')}; selected={}
assert(service:ExecuteKeyboardPair('Z') and selected[1]==engineerCandidates[1],
    'same preset dispatches the first chord composite')
selected={}; simulateSelection=makeUnit('COMMAND')
assert(service:ExecuteKeyboardPair('Y') and selected[1]==simulateSelection,
    'same preset dispatches its different second chord composite')
simulateSelection=nil
local oldPairMap=preferences.UserKeyMap.Z
local oldPairAction=preferences.UserKeyActions['ClaretHotkeyPair_5A']
failSave=true
assert(not service.keyboardBindings:Set({kind='composite',id='pair_empty'},'Z',{}),
    'failed pair save reports failure')
assert(preferences.ClaretHotbuildKeyboard.assignments.Z.composite=='pair_other'
    and preferences.ClaretHotbuildKeyboard.assignments.Z.preset=='pair_preset'
    and preferences.UserKeyMap.Z==oldPairMap
    and preferences.UserKeyActions['ClaretHotkeyPair_5A'].action==oldPairAction.action
    and preferences.UserKeyActions['ClaretHotkeyPair_5A'].category==oldPairAction.category,
    'failed pair save restores profile slots, native map and action definition')
assert(service.keyboardBindings:Clear({kind='composite',id='pair_other'},'Z',{}),'clearing a pair slot succeeds')
assert(preferences.ClaretHotbuildKeyboard.assignments.Z.composite==nil
    and preferences.ClaretHotbuildKeyboard.assignments.Z.preset=='pair_preset',
    'clearing composite leaves the preset slot intact')
assert(service.keyboardBindings:Clear(pairPreset,'Z',{}),'independent preset slot can be cleared')
assert(preferences.ClaretHotbuildKeyboard.assignments.Z==nil,
    'clearing final slot removes the empty chord assignment')
local allowed,_,incompatible=service.keyboardBindings:Validate({kind='composite',id='ctxEngineer'},'F1',{})
assert(not allowed and incompatible==nil,
    'an incompatible slot assignment is rejected without replacing the existing pair')
assert(service.keyboardBindings:Set(pairPreset,'V',{}),'preset slot accepts a free chord before compatibility is checked')
local incompatibleForward=service.keyboardBindings:Set({kind='composite',id='ctxAcu'},'V',{})
assert(not incompatibleForward and preferences.ClaretHotbuildKeyboard.assignments.V.preset=='pair_preset'
    and preferences.ClaretHotbuildKeyboard.assignments.V.composite==nil,
    'adding an incompatible builder composite to a preset is rejected')
assert(service.keyboardBindings:Set({kind='composite',id='ctxAcu'},'W',{}),
    'composite can occupy a free chord before compatibility is checked')
local incompatibleReverse=service.keyboardBindings:Set(pairPreset,'W',{})
assert(not incompatibleReverse and preferences.ClaretHotbuildKeyboard.assignments.W.composite=='ctxAcu'
    and preferences.ClaretHotbuildKeyboard.assignments.W.preset==nil,
    'adding an incompatible preset to a composite is rejected in the reverse direction')
assert(service:CommitContext({id='ctxFactory',name='Factory action',rows={{context='factory',action='pause'}}}))
local factoryForward=service.keyboardBindings:Set({kind='composite',id='ctxFactory'},'J',{})
assert(factoryForward,'standalone factory action can be assigned')
local factoryConflictReverse=service.keyboardBindings:Set(pairPreset,'J',{})
assert(not factoryConflictReverse and preferences.ClaretHotbuildKeyboard.assignments.J.composite=='ctxFactory'
    and preferences.ClaretHotbuildKeyboard.assignments.J.preset==nil,
    'factory context conflicts with a building preset when the preset is added second')
assert(service.keyboardBindings:Set(pairPreset,'K',{}),'building preset can be assigned before factory compatibility check')
local factoryConflictForward=service.keyboardBindings:Set({kind='composite',id='ctxFactory'},'K',{})
assert(not factoryConflictForward and preferences.ClaretHotbuildKeyboard.assignments.K.preset=='pair_preset'
    and preferences.ClaretHotbuildKeyboard.assignments.K.composite==nil,
    'factory context conflicts with a building preset when the composite is added second')
service:Destroy()
service=Runtime.Create(false)
local restoredPair=service.keyboardBindings:GetPair('Y')
assert(restoredPair and restoredPair.preset=='pair_preset' and restoredPair.composite=='pair_empty'
    and preferences.UserKeyMap.Y=='ClaretHotkeyPair_'..encoded('Y'),
    'independent pair and native mapping survive a runtime reload')
preferences.UserKeyMap=nil
preferences.UserDebugKeyMap=nil
assert(service.keyboardBindings:Set({kind='composite',id='ctxEmpty'},'L',{}),
    'assignment initializes nil user maps')
assert(preferences.UserKeyMap.L=='ClaretHotkeyPair_'..encoded('L')
    and preferences.UserKeyMap['Ctrl-D']=='DefaultAction'
    and mapper.GetCurrentKeyMap()['Ctrl-D']=='DefaultAction'
    and engineKeyMap['Ctrl-D'] and engineKeyMap['Ctrl-D'].action=='native:DefaultAction',
    'assignment from nil maps preserves unrelated default mappings: map='..tostring(preferences.UserKeyMap.L)
        ..' profileDefault='..tostring(preferences.UserKeyMap['Ctrl-D'])
        ..' current='..tostring(mapper.GetCurrentKeyMap()['Ctrl-D'])
        ..' engine='..tostring(engineKeyMap['Ctrl-D'] and engineKeyMap['Ctrl-D'].action))
service:Destroy()
preferences.ClaretHotbuildKeyboard.assignments.W={preset='pair_preset',composite='pair_empty'}
preferences.UserKeyMap.W='ForeignAction'
preferences.UserDebugKeyMap.W=nil
service=Runtime.Create(false)
local candidate={kind='action',id='select_scout'}
assert(service.keyboardBindings:Set(candidate,'O',{})
    and preferences.UserKeyMap.O=='ClaretHotkeyContext_'..encoded('select_scout')
    and engineKeyMap.O and engineKeyMap.O.action:find('ExecuteKeyboardAction',1,true),
    'an individual action can still be assigned to an otherwise empty chord')
local valid,reason,conflict=service.keyboardBindings:Validate(candidate,'W',{})
assert(not valid and conflict and conflict.kind=='conflict' and conflict.id=='stale:W'
    and reason:find('ForeignAction',1,true), 'stale pair requests an explicit replacement and identifies the FAF occupant')
assert(not service.keyboardBindings:Set(candidate,'W',{})
    and preferences.ClaretHotbuildKeyboard.assignments.W.preset=='pair_preset'
    and preferences.UserKeyMap.W=='ForeignAction', 'unconfirmed recovery preserves both saved and native assignments')
preferences.UserDebugKeyMap.W='AnotherAction'
local ambiguous,_,ambiguousConflict=service.keyboardBindings:Validate(candidate,'W',{})
assert(not ambiguous and not ambiguousConflict, 'recovery refuses multiple conflicting native mappings')
preferences.UserDebugKeyMap.W=nil
assert(service.keyboardBindings:Set(candidate,'W',{},conflict.id)
    and preferences.ClaretHotbuildKeyboard.assignments.W==nil
    and preferences.UserKeyMap.W=='ClaretHotkeyContext_'..encoded('select_scout'),
    'confirmed recovery replaces only the stale chord with the requested action')
generatedModifiers['Shift-T']={action='native hotbuild'}
local allowedModifier,_,modifierConflict=service.keyboardBindings:Validate(candidate,'T',{shift=true})
assert(not allowedModifier and modifierConflict and modifierConflict.id=='Hotbuild modifier',
    'a generated FAF hotbuild modifier requests explicit confirmation')
assert(not service.keyboardBindings:Set(candidate,'T',{shift=true}) and not preferences.UserKeyMap['Shift-T'],
    'unconfirmed replacement leaves the generated modifier active')
assert(service.keyboardBindings:Set(candidate,'T',{shift=true},modifierConflict.id)
    and preferences.UserKeyMap['Shift-T']=='ClaretHotkeyContext_'..encoded('select_scout')
    and not mapper.GenerateHotbuildModifiers()['Shift-T'],
    'confirmed explicit mapping takes precedence over the generated FAF modifier')

-- Confirmed deletion removes only direct composite slots and keeps other data.
assert(service:CommitContext({id='ctxDelete',name='Delete target',rows={{context='empty',action='select_acu'}}}))
assert(service.keyboardBindings:Set({kind='composite',id='ctxDelete'},'M',{}))
assert(service.keyboardBindings:Set(pairPreset,'M',{}),'deletion fixture has an independent preset slot')
assert(service.keyboardBindings:Set(candidate,'N',{}),'deletion fixture has an unrelated direct action')
local historical=service.model:Get('legacy')
historical.grid={context='ctxDelete'}
local beforeDeleteMap=preferences.UserKeyMap.M
local denied=service:CommitContext(nil,'ctxDelete')
assert(not denied and service.contextModel:Get('ctxDelete')
    and preferences.UserKeyMap.M==beforeDeleteMap,
    'unconfirmed deletion leaves its context and keyboard mappings intact')
local deleted,deleteMessage=service:CommitContext(nil,'ctxDelete',true)
local retained=preferences.ClaretHotbuildKeyboard.assignments.M
assert(deleted and not service.contextModel:Get('ctxDelete') and retained
    and retained.preset=='pair_preset' and retained.composite==nil
    and preferences.UserKeyMap.M=='ClaretHotkeyPair_'..encoded('M')
    and preferences.UserKeyMap.N=='ClaretHotkeyContext_'..encoded('select_scout')
    and historical.grid.context=='ctxDelete',
    'confirmed deletion clears only the composite slot and preserves preset, other action and historical grid data')

-- A keyboard profile write failure rolls back the already staged context deletion.
assert(service:CommitContext({id='ctxDeleteFail',name='Delete rollback',rows={{context='empty',action='select_acu'}}}))
assert(service.keyboardBindings:Set({kind='composite',id='ctxDeleteFail'},'P',{}))
local beforeFailContext=preferences.ClaretHotbuildContexts
local beforeFailKeyboard=preferences.ClaretHotbuildKeyboard
local beforeFailMap=preferences.UserKeyMap.P
failSaveOnCall=saveCount+2 -- context profile save succeeds; keyboard profile save fails
local failDelete=service:CommitContext(nil,'ctxDeleteFail',true)
assert(not failDelete and service.contextModel:Get('ctxDeleteFail')
    and preferences.ClaretHotbuildContexts==beforeFailContext
    and preferences.ClaretHotbuildKeyboard.assignments.P.composite=='ctxDeleteFail'
    and preferences.UserKeyMap.P==beforeFailMap,
    'failed keyboard write rolls back context model, keyboard pair and native map')

-- Historical direct composite key IDs outside the pair profile are cleared too.
assert(service:CommitContext({id='ctxLegacyDelete',name='Legacy key deletion',rows={{context='empty',action='select_acu'}}}))
local legacyCompositeId='ClaretHotkeyComposite_'..encoded('ctxLegacyDelete')
preferences.UserKeyMap.R=legacyCompositeId
preferences.UserDebugKeyMap.R='ForeignDebugAction'
preferences.UserKeyActions[legacyCompositeId]={action='legacy context action',category='Claret Hotbuild'}
assert(service.keyboardBindings:HasDirectAssignment({kind='composite',id='ctxLegacyDelete'}))
assert(service:CommitContext(nil,'ctxLegacyDelete',true)
    and preferences.UserKeyMap.R=='ClaretHotkeyPair_'..encoded('R')
    and preferences.ClaretHotbuildKeyboard.assignments.R.preset=='legacy'
    and preferences.ClaretHotbuildKeyboard.assignments.R.composite==nil
    and preferences.UserDebugKeyMap.R=='ForeignDebugAction'
    and preferences.UserKeyActions[legacyCompositeId]==nil,
    'confirmed deletion clears legacy composite mappings while preserving the preset slot')
service:Destroy()
-- Right-click removes only this chord, atomically and without deleting the saved sets.
do
    local kb=service.keyboardBindings
    assert(kb:Set({kind='preset',id='pair_preset'},'F12',{ctrl=true}))
    assert(kb:Set({kind='composite',id='pair_empty'},'F12',{ctrl=true}))
    assert(kb:Set({kind='action',id='select_scout'},'F12',{}))
    local before=preferences.ClaretHotbuildKeyboard.assignments['Ctrl-F12']
    failSave=true
    assert(not kb:ClearChord('F12',{ctrl=true}),'failed write must not clear either slot')
    local after=preferences.ClaretHotbuildKeyboard.assignments['Ctrl-F12']
    assert(after and after.preset==before.preset and after.composite==before.composite)
    preferences.UserDebugKeyMap['Ctrl-F12']='OtherModAction'
    assert(kb:ClearChord('F12',{ctrl=true}))
    assert(not preferences.UserDebugKeyMap['Ctrl-F12'], 'foreign action on the same chord is cleared')
    assert(not preferences.ClaretHotbuildKeyboard.assignments['Ctrl-F12'] and not preferences.UserKeyMap['Ctrl-F12'])
    assert(preferences.UserKeyMap.F12 and service.model:Get('pair_preset') and service.contextModel:Get('pair_empty'),
        'other modifiers and the underlying saved sets remain intact')
    assert(kb:ClearChord('F12',{}),'standalone action can be removed')
    preferences.UserKeyActions.SomeForeign={action='other mod',category='Other'}
    preferences.UserKeyMap.F7='SomeForeign'; preferences.UserDebugKeyMap.F7='OtherModAction'
    preferences.UserKeyMap['Shift-F7']='SomeForeign'; preferences.UserKeyMap.F8='SomeForeign'
    failSave=true
    assert(not kb:ClearChord('F7',{}),'failure rolls back both foreign mappings')
    assert(preferences.UserKeyMap.F7=='SomeForeign' and preferences.UserDebugKeyMap.F7=='OtherModAction')
    assert(kb:ClearChord('F7',{}),'foreign mappings are removable')
    assert(not preferences.UserKeyMap.F7 and not preferences.UserDebugKeyMap.F7
        and preferences.UserKeyMap['Shift-F7']=='SomeForeign' and preferences.UserKeyMap.F8=='SomeForeign'
        and preferences.UserKeyActions.SomeForeign, 'other chords and foreign action definitions are preserved')
    local savedUser,savedDebug,savedCurrent=preferences.UserKeyMap,preferences.UserDebugKeyMap,mapper.GetCurrentKeyMap
    preferences.UserKeyMap=nil; preferences.UserDebugKeyMap={}
    mapper.GetCurrentKeyMap=function()
        local map={}
        for key,id in pairs(preferences.UserKeyMap or defaultKeyMap) do map[key]=id end
        for key,id in pairs(preferences.UserDebugKeyMap or {}) do map[key]=id end
        return map
    end
    assert(kb:ClearChord('D',{ctrl=true}), 'default binding can be removed without a saved user map')
    assert(not mapper.GetCurrentKeyMap()['Ctrl-D'], 'cleared default must not reappear')
    preferences.UserKeyMap=savedUser; preferences.UserDebugKeyMap=savedDebug; mapper.GetCurrentKeyMap=savedCurrent


end
print('PASS: context runtime migration, per-key pair dispatch, independent slot edits and rollback')
