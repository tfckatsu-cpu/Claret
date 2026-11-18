-- Persistence model tests using the real ContextActions catalog.
local testLocalization = dofile('Tests/localization-test-helper.lua')
table.getn = function(t) return #t end
local actions=setmetatable({}, {__index=_G})
assert(loadfile('../mods/ClaretHotbuild/modules/ContextActions.lua','t',actions))()
local modelModule=setmetatable({}, {__index=_G})
assert(loadfile('../mods/ClaretHotbuild/modules/ContextModel.lua','t',modelModule))()
local function binding(id, name, rows)
    return {id=id,name=name or '  Example  ',rows=rows or {{context='acu',action='move'}}}
end

local model=modelModule.Create(nil,actions)
assert(model:CanSave())
local repeatBinding=binding('quick_repeat','Repeat',{{context='empty',action='select_bombers',quickRepeat='select_fighters'}})
assert(model:Put(repeatBinding),'quick repeat must be applicable to the same context')
assert(model:ResolveRow('quick_repeat','empty').quickRepeat=='select_fighters','resolved row exposes quick repeat')
assert(model:Put(binding('parent_repeat','Parent repeat',{{context='builder',action='move',quickRepeat='reclaim'}})),
    'parent builder repeat is validated against the parent context')
assert(model:Put(binding('child_inherit','Child inheritance',{{context='builder',action='move',quickRepeat='reclaim'},
    {context='acu',mode='inherit'}})))
assert(model:ResolveRow('child_inherit','acu').quickRepeat=='reclaim', 'inherited child receives the whole parent row')
local badRepeat=binding('bad_repeat','Bad repeat',{{context='empty',action='select_bombers',quickRepeat='move'}})
local repeatOk,repeatErr=model:Put(badRepeat)
assert(not repeatOk and repeatErr:find('Быстрый повтор',1,true),'inapplicable quick repeat is rejected')
-- Exercise selection-policy validation independently of the concrete catalog.
local originalGet=actions.Get
actions.Get=function(id)
    if id=='test_exclusive' then return {id=id,selectionPolicy='exclusive'} end
    if id=='test_double' then return {id=id,selectionPolicy='double'} end
    if id=='test_accumulate' then return {id=id,selectionPolicy='accumulate'} end
    return originalGet(id)
end
local originalList=actions.List
actions.List=function()
    local result={}
    for _,item in ipairs(originalList()) do table.insert(result,item) end
    table.insert(result,{id='test_exclusive'}); table.insert(result,{id='test_double'})
    table.insert(result,{id='test_accumulate'})
    return result
end
local originalSupports=actions.Supports
actions.Supports=function(id,context)
    if id=='test_exclusive' or id=='test_double' or id=='test_accumulate' then return context=='empty' end
    return originalSupports(id,context)
end
local policies=modelModule.Create(nil,actions)
local function policyRows(action,other)
    return binding('policy','Policy',{{context='empty',action=action},other})
end
assert(policies:Put(policyRows('test_exclusive',{context='acu',action='move'})), 'exclusive selection rejects other actions')
assert(policies:Put(policyRows('test_double',{context='transport',action='move'})), 'double selection rejects transport action')
assert(policies:Put(policyRows('test_accumulate',{context='engineer',action='reclaim'})), 'accumulation rejects engineer action')
assert(policies:Put(policyRows('test_accumulate',{context='acu',action='move'})), 'accumulation blocks individual ACU action')
assert(policies:Put(policyRows('test_double',{context='acu',action='move'})), 'double selection permits individual ACU action')
assert(policies:Put(policyRows('test_exclusive',{context='acu',mode='disabled'})), 'disabled child does not conflict')
local oldConflict=modelModule.Create({version=3,bindings={policyRows('test_exclusive',{context='acu',action='move'})}},actions)
assert(oldConflict:CanSave() and oldConflict:Get('policy').rows[2].action=='move', 'legacy conflicting rows are retained')
assert(oldConflict:Put(oldConflict:Get('policy')), 'legacy conflicts must be resolved before a new save')
actions.Get=originalGet; actions.List=originalList; actions.Supports=originalSupports
-- Validate the complete requested conflict matrix against real action IDs.
local tileRows={
    {context='builder',action='move'}, {context='acu',action='move'},
    {context='sacu',action='move'}, {context='engineer',action='reclaim'},
    {context='factory',action='repeat_queue'}, {context='transport',action='move'},
    {context='silo_tactical',action='tactical'}, {context='silo_nuclear',action='nuke'},
    {context='mex',action='pause'}, {context='scout',action='move'}, {context='other',action='stop'},
}
local matrix=modelModule.Create(nil,actions)
for _,tile in ipairs(tileRows) do
    for _,id in ipairs({'select_bombers','select_acu_double','select_transport_double','select_engineers_t1'}) do
        assert(matrix:Put(policyRows(id,tile)), id..' should allow a natural chain to '..tile.context)
    end
end
assert(model:Put(binding('b1')))
assert(model:Get('b1').name=='Example','name is trimmed')
local ok,err=model:Put(binding('b2','Duplicate context',{
    {context='acu',action='move'}, {context='acu',action='attack'},
}))
assert(not ok and err:find('Контекст повторяется',1,true),'each context appears once')
ok,err=model:Put(binding('b2','Unsupported',{{context='acu',action='nuke'}}))
assert(not ok and err:find('поддерживается',1,true),'unsupported action rejected')
ok,err=model:Put(binding('parent_bad','Invalid parent',{{context='builder',action='nuke'}}))
assert(not ok and err:find('не поддерживает',1,true),'parent builder rejects commands not common to child types')
assert(model:Put(binding('parent_ok','Valid parent',{{context='builder',action='move'}})),
    'parent builder accepts shared command')
ok,err=model:Put(binding('bad_mode','Bad mode',{{context='acu',mode='inherit',action='move'}}))
assert(ok,'inherit mode retains an inactive child action')
ok,err=model:Put(binding('bad_mode','Bad mode',{{context='acu',mode='unknown'}}))
assert(not ok and err:find('режим',1,true),'unknown child mode rejected')

local kept=modelModule.Create({version=3,bindings={binding('kept','Kept',{
    {context='builder',action='move'},
    {context='acu',mode='own',action='attack',quickRepeat='reclaim',fallback='old_fallback'},
})}},actions)
local keptDraft=kept:Get('kept')
keptDraft.rows[2].mode='disabled'
assert(kept:Put(keptDraft),'disabling preserves historic additional fields')
local reloaded=modelModule.Create(kept:Export(),actions)
local saved=reloaded:Get('kept').rows[2]
assert(saved.action=='attack' and saved.quickRepeat=='reclaim' and saved.fallback=='old_fallback')
assert(reloaded:ResolveRow('kept','acu')==nil,'disabled child ignores the stored action')
keptDraft=reloaded:Get('kept'); keptDraft.rows[2].mode='inherit'
assert(reloaded:Put(keptDraft) and reloaded:ResolveRow('kept','acu').action=='move',
    'inherit uses the parent while retaining the child action')
keptDraft=reloaded:Get('kept'); keptDraft.rows[2].mode='own'
assert(reloaded:Put(keptDraft) and reloaded:ResolveRow('kept','acu').fallback=='old_fallback',
    'own restores the original child action and historic fields')

-- Version 1 child actions migrate to explicit own overrides; parent-only profiles inherit.
local legacySchema=modelModule.Create({version=1,bindings={
    binding('legacy_own','Legacy own',{{context='builder',action='move'},{context='acu',action='attack'}}),
    binding('legacy_parent','Legacy parent',{{context='builder',action='assist'}}),
}},actions)
assert(legacySchema:CanSave() and legacySchema:ResolveAction('legacy_own','acu')=='attack'
    and legacySchema:ResolveAction('legacy_own','sacu')=='move'
    and legacySchema:ResolveAction('legacy_parent','engineer')=='assist',
    'version 1 child overrides migrate while absent children inherit from builder')
local migratedSchema=legacySchema:Export()
assert(migratedSchema.version==3 and migratedSchema.bindings[1].rows[2].mode=='own'
    and migratedSchema.bindings[2].rows[1].context=='builder',
    'legacy profile exports in version 2 schema with explicit child mode')
local schemaV2=modelModule.Create({version=2,bindings={
    binding('modes','Modes',{{context='builder',action='move'},{context='acu',mode='disabled'},
        {context='sacu',mode='inherit'},{context='engineer',mode='own',action='reclaim'}}),
}},actions)
assert(schemaV2:CanSave() and schemaV2:ResolveAction('modes','acu')==nil
    and schemaV2:ResolveAction('modes','sacu')=='move'
    and schemaV2:ResolveAction('modes','engineer')=='reclaim',
    'version 2 modes distinguish disabled, inherited and own actions')

-- Returned values and inputs are copied at the model boundary.
local input=binding('b2','Copy test',{{context='acu',action='move'}})
assert(model:Put(input)); input.rows[1].action='nuke'; input.name='changed'
local fetched=model:Get('b2'); assert(fetched.rows[1].action=='move' and fetched.name=='Copy test')
fetched.rows[1].action='nuke'; fetched.name='changed'
assert(model:Get('b2').rows[1].action=='move' and model:Get('b2').name=='Copy test')
local listed=model:List(); listed[1].rows[1].action='nuke'; listed[1].name='changed'
assert(model:Get('b1').rows[1].action=='move')

-- Valid saved data restores, while malformed records are skipped with warnings.
local saved={version=1,bindings={
    binding('restore','Restored',{{context='empty',action='select_acu'}}),
    binding('bad','Bad',{{context='silo',action='move',unknownField=true}}),
    binding('restore','Duplicate ID',{{context='acu',action='move'}}),
}}
local restored=modelModule.Create(saved,actions)
assert(not restored:CanSave() and restored:Get('restore').name=='Restored')
assert(not restored:Get('bad') and #restored:GetLoadWarnings()==2)
assert(not restored:Export(),'partial recovery cannot overwrite profile')
local partialOrder=modelModule.Create({version=1,bindings={
    binding('badFirst','Bad first',{{context='silo',action='move',unknownField=true}}),
    binding('keptSecond','Kept second',{{context='acu',action='move'}}),
    binding('keptThird','Kept third',{{context='engineer',action='reclaim'}}),
}},actions)
local partialList=partialOrder:List()
assert(#partialList==2 and partialList[1].id=='keptSecond' and partialList[2].id=='keptThird',
    'valid records after an invalid record remain visible and preserve order')
assert(partialOrder:Get('keptSecond') and partialOrder:Get('keptThird'),
    'valid records after an invalid record remain addressable')
assert(not partialOrder:CanSave() and not partialOrder:Export(),
    'partial recovery remains protected from overwriting the damaged profile')
local clean=modelModule.Create({version=1,bindings={binding('clean','Clean')}},actions)
local exported=clean:Export(); assert(exported.version==3 and exported.bindings[1].id=='clean')

local corrupt=modelModule.Create({version=99,bindings={}},actions)
assert(not corrupt:CanSave() and #corrupt:GetLoadWarnings()>0)
assert(not corrupt:Export(),'corrupt profile cannot be overwritten by export')
assert(corrupt:Put(binding('draft')),'in-memory edits remain possible')
assert(not corrupt:Export(),'in-memory edit cannot overwrite corrupt source')
local malformedList=modelModule.Create({version=1,bindings={[1]=binding('one'),[3]=binding('three')}},actions)
assert(not malformedList:CanSave(),'sparse saved profile is rejected')

-- Limits: 64 bindings and 64 rows; replacing an existing ID remains allowed.
local limited=modelModule.Create(nil,actions)
for i=1,64 do assert(limited:Put(binding('limit'..i))) end
ok,err=limited:Put(binding('limit65')); assert(not ok and err:find('Максимум биндов',1,true))
assert(limited:Put(binding('limit1','Updated')) and limited:Get('limit1').name=='Updated')
local rows={}
for i=1,65 do rows[i]={context='acu',action='move'} end
ok,err=limited:Put(binding('too_many_rows','Rows',rows))
assert(not ok and err:find('Число строк',1,true))
local emptyRowsModel=modelModule.Create(nil,actions)
assert(emptyRowsModel:Put(binding('empty_rows','Empty rows',{}))
    and #emptyRowsModel:Get('empty_rows').rows==0,
    'empty context bindings can represent clearing their final tile')
local absoluteModel=modelModule.Create(nil,actions)
local absoluteBinding=binding('absolute','Absolute',{{context='empty',action='select_bombers'},
    {context='other',action='stop'}})
absoluteBinding.absolute=true
assert(absoluteModel:Put(absoluteBinding),'absolute mode is a valid composite property')
local absoluteExport=absoluteModel:Export()
assert(absoluteExport.bindings[1].absolute==true
    and absoluteExport.bindings[1].rows[2].action=='stop',
    'absolute mode persists without deleting inactive tiles')
local regularBinding=absoluteModel:Get('absolute'); regularBinding.absolute=false
assert(absoluteModel:Put(regularBinding),'switching absolute off preserves natural chains')
absoluteBinding.absolute='yes'
assert(not absoluteModel:Put(absoluteBinding),'absolute mode accepts only a boolean')

-- Phase 1 schema: group rows inherit as whole actions; leaf rows can override
-- or disable inheritance without changing saved order.
local groups=modelModule.Create({version=3,bindings={binding('groups','Groups',{
    {context='units',action='move'},
    {context='land',mode='own',action='attack'},
    {context='air',mode='disabled'},
    {context='navy',mode='inherit'},
    {context='missiles',action='stop'},
    {context='silo_tactical',mode='inherit'},
    {context='silo_nuclear',mode='own',action='nuke'},
    {context='builder',action='assist'},
    {context='acu',mode='inherit'},
    {context='sacu',mode='disabled'},
    {context='engineer',mode='own',action='reclaim'},
})}},actions)
assert(groups:CanSave(), 'v3 grouped profile loads cleanly')
assert(groups:ResolveAction('groups','land')=='attack'
    and groups:ResolveAction('groups','air')==nil
    and groups:ResolveAction('groups','navy')=='move', 'Units children resolve own/disabled/inherit')
assert(groups:ResolveAction('groups','silo_tactical')=='stop'
    and groups:ResolveAction('groups','silo_nuclear')=='nuke', 'missile leaves resolve independently')
assert(groups:ResolveAction('groups','acu')=='assist'
    and groups:ResolveAction('groups','sacu')==nil
    and groups:ResolveAction('groups','engineer')=='reclaim', 'builder children retain modes')
local groupExport=groups:Export()
assert(groupExport.version==3 and groupExport.bindings[1].rows[1].context=='units'
    and groupExport.bindings[1].rows[11].context=='engineer', 'v3 export preserves row order')
local groupReload=modelModule.Create(groupExport,actions):Export()
assert(groupReload.version==3 and groupReload.bindings[1].rows[2].action=='attack'
    and groupReload.bindings[1].rows[3].mode=='disabled', 'reload/export is idempotent')

-- Both supported legacy versions migrate in memory and leave caller data intact.
local legacyV1={version=1,bindings={binding('legacy_v1','Legacy',{
    {context='builder',action='move'}, {context='acu',action='attack'},
    {context='engineer',action='reclaim'},
})}}
local legacyV1Snapshot=legacyV1.bindings[1].rows[2].mode
local migratedV1=modelModule.Create(legacyV1,actions)
assert(legacyV1.bindings[1].rows[2].mode==legacyV1Snapshot
    and migratedV1:ResolveAction('legacy_v1','acu')=='attack'
    and migratedV1:ResolveAction('legacy_v1','sacu')=='move', 'v1 migration is in-memory and preserves inherited siblings')
assert(migratedV1:Export().version==3, 'v1 exports as v3')
local legacyV2={version=2,bindings={binding('legacy_v2','Legacy',{
    {context='builder',action='move'}, {context='acu',mode='own',action='attack'},
    {context='sacu',mode='disabled'}, {context='engineer',mode='inherit'},
})}}
local migratedV2=modelModule.Create(legacyV2,actions)
assert(migratedV2:CanSave() and migratedV2:ResolveAction('legacy_v2','acu')=='attack'
    and migratedV2:ResolveAction('legacy_v2','sacu')==nil
    and migratedV2:ResolveAction('legacy_v2','engineer')=='move'
    and migratedV2:Export().version==3, 'v2 modes migrate to v3 without reinterpretation')

-- Absolute profiles keep inactive rows; malformed/future data cannot be saved.
local inactive={version=2,bindings={binding('inactive','Inactive',{
    {context='empty',action='select_bombers'}, {context='other',action='stop'},
})}}
inactive.bindings[1].absolute=true
local migratedInactive=modelModule.Create(inactive,actions):Export()
assert(migratedInactive.version==3 and migratedInactive.bindings[1].absolute
    and migratedInactive.bindings[1].rows[2].context=='other', 'migration preserves absolute and inactive rows')
local futureVersion=modelModule.Create({version=4,bindings={}},actions)
assert(not futureVersion:CanSave() and not futureVersion:Export(), 'future version blocks overwrite')
local futureField=modelModule.Create({version=3,bindings={},futureField=true},actions)
assert(not futureField:CanSave() and not futureField:Export(), 'unknown schema fields block overwrite')

-- Semantically unknown assignments remain visible and round-trip losslessly;
-- structurally invalid/future records remain protected by the save guard.
local unknownAction=modelModule.Create({version=3,bindings={binding('unknown_action','Unknown',{
    {context='acu',mode='own',action='removed_action'},
})}},actions)
local unknownRow=unknownAction:Get('unknown_action')
assert(unknownRow and unknownRow.rows[1].action=='removed_action', 'unknown action row is preserved')
assert(#unknownAction:GetDiagnostics()>0 and unknownAction:CanSave(), 'semantic diagnostics do not block a lossless export')
local unknownExport=unknownAction:Export()
assert(unknownExport and unknownExport.bindings[1].rows[1].action=='removed_action',
    'unknown action survives export')
local unknownContext=modelModule.Create({version=3,bindings={binding('unknown_context','Unknown context',{
    {context='unknown_column',mode='disabled'},
})}},actions)
assert(unknownContext:CanSave() and #unknownContext:GetDiagnostics()>0
    and unknownContext:Export().bindings[1].rows[1].mode=='disabled', 'unknown context survives with diagnostics')
local invalidAction=modelModule.Create({version=3,bindings={binding('invalid_action','Invalid',{
    {context='acu',mode='own',action='nuke'},
})}},actions)
assert(invalidAction:Get('invalid_action').rows[1].action=='nuke', 'invalid-for-context action is preserved')
-- Unchanged semantic-invalid rows may accompany edits to other binding data.
local retainedRows={
    {context='removed_context',mode='disabled'},
    {context='acu',mode='own',action='removed_action',quickRepeat='removed_repeat',fallback='removed_fallback'},
    {context='acu2',action='nuke'},
}
local retention=modelModule.Create({version=3,bindings={binding('retention','Old name',retainedRows)}},actions)
local changed=retention:Get('retention'); changed.name='New name'
changed.rows[1].mode='disabled'
-- A known supported row can also change while all invalid rows remain exact.
changed.rows[1].context='removed_context'
changed.rows[1].mode='disabled'
changed.rows[2].quickRepeat='removed_repeat'; changed.rows[2].fallback='removed_fallback'
-- Add an unrelated valid row using a context not already present.
changed.rows[4]={context='other',action='stop'}
assert(retention:Put(changed), 'renaming and editing unrelated rows preserves unchanged invalid rows')
local retained=retention:Export().bindings[1]
assert(retained.name=='New name' and retained.rows[2].quickRepeat=='removed_repeat'
    and retained.rows[2].fallback=='removed_fallback' and retained.rows[4].action=='stop',
    'preserved invalid rows retain every field and unrelated changes persist')
changed=retention:Get('retention'); changed.rows[2].action='another_removed_action'
ok,err=retention:Put(changed)
assert(not ok, 'changing unknown action row is rejected: '..tostring(err))
changed=retention:Get('retention'); changed.rows[3].action='move'
ok,err=retention:Put(changed)
assert(not ok and err:find('Неизвестный контекст',1,true), 'changing unknown context row is rejected')
local unsupportedEdit=invalidAction:Get('invalid_action'); unsupportedEdit.rows[1].action='tactical'
ok,err=invalidAction:Put(unsupportedEdit)
assert(not ok and err:find('поддерживается',1,true), 'changing unsupported action row is rejected')
local migration=modelModule.Create({version=3,bindings={binding('cursor_old','Old',{
    {context='factory',action='upgrade_structure_pause'},
})}},actions)
local migrated=migration:Get('cursor_old')
assert(#migrated.rows==1 and migrated.rows[1].context=='cursor'
    and migrated.rows[1].action=='upgrade_structure_pause','migration moves the old assignment to cursor')
assert(migration:Put(migrated),'migrated assignment remains saveable')
local inactiveCursor=modelModule.Create({version=3,bindings={binding('cursor_inactive','Old',{
    {context='acu',mode='inherit',action='upgrade_structure_pause'},
})}},actions)
assert(#inactiveCursor:Get('cursor_inactive').rows==1
    and inactiveCursor:Get('cursor_inactive').rows[1].mode=='inherit',
    'inactive historical actions never become active during cursor migration')
local ambiguous=modelModule.Create({version=3,bindings={binding('cursor_conflict','Old',{
    {context='factory',action='upgrade_structure_pause'},
    {context='mex',action='upgrade_mex_select_next'},
})}},actions)
assert(#ambiguous:Get('cursor_conflict').rows==2 and #ambiguous:GetDiagnostics()>0,
    'ambiguous migration preserves both rows and reports the conflict')
print('PASS: context uniqueness, compatibility, copy isolation, restore, corrupt-profile save guard and limits')
