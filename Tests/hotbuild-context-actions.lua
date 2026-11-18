-- Context partitioning and dispatch with mocked FAF APIs.
local testLocalization = dofile('Tests/localization-test-helper.lua')
table.getn = function(t) return #t end
table.getsize = function(t) local n=0; for _ in pairs(t) do n=n+1 end; return n end

local calls, paused, queue, mode, toggles = {}, false, {}, {}, {}
local units, selectedForCommand = {}, {}
local function unit(categories, repeatQueue, creator)
    local u = {categories=categories, repeatQueue=repeatQueue, creator=creator, info={}}
    function u:IsInCategory(category) return self.categories[category] == true end
    function u:IsRepeatQueue() return self.repeatQueue end
    function u:ProcessInfo(command, value) self.info[command]=value; self.repeatQueue=value=='true' end
    function u:GetCreator() return self.creator end
    function u:IsDead() return false end
    function u:GetBlueprint() return self.blueprint or {} end
    return u
end
local function categories(...)
    local result={}
    for _, name in ipairs({...}) do result[name]=true end
    return result
end
local acu=unit(categories('COMMAND'))
local sacu=unit(categories('SUBCOMMANDER'))
local engineer=unit(categories('ENGINEER'))
local factory=unit(categories('FACTORY'),true)
local external=unit(categories('EXTERNALFACTORY'),true)
local creator=unit(categories('FACTORY'),true)
external.creator=creator
local transport=unit(categories('TRANSPORTATION'))
local tacticalSilo=unit(categories('SILO','TECH2'))
local nuclearSilo=unit(categories('SILO','TECH3'))
local xsbSilo=unit(categories('TECH2'))
function tacticalSilo:GetBlueprint() return {BlueprintId='ues0302'} end
function nuclearSilo:GetBlueprint() return {BlueprintId='ueb4302'} end
function xsbSilo:GetBlueprint() return {BlueprintId='xsb2401'} end
local mex=unit(categories('MASSEXTRACTION'))
local scout=unit(categories('AIR','INTELLIGENCE'))
local other=unit(categories('LAND'))
local mexOne, mexTwo=unit(categories('MASSEXTRACTION','TECH1')),unit(categories('MASSEXTRACTION','TECH2'))
mexOne.entityId=100; mexTwo.entityId=200
function mexOne:GetEntityId() return self.entityId end
function mexTwo:GetEntityId() return self.entityId end
local wrongCategory=unit(categories('TECH1')); wrongCategory.entityId=50
local wrongTech=unit(categories('MASSEXTRACTION','TECH3')); wrongTech.entityId=150
function wrongCategory:GetEntityId() return self.entityId end
function wrongTech:GetEntityId() return self.entityId end
local fireBeetle=unit(categories('LAND')); fireBeetle.blueprint={BlueprintId='xrl0302'}
local secondFireBeetle=unit(categories('LAND')); secondFireBeetle.blueprint={BlueprintId='xrl0302'}
local megalith=unit(categories('CONSTRUCTION')); megalith.blueprint={BlueprintId='xrl0403'}
megalith.categories.LAND=true; megalith.categories.MOBILE=true; megalith.categories.EXPERIMENTAL=true
local satellite=unit(categories('EXPERIMENTAL','AIR')); satellite.blueprint={BlueprintId='xea0002'}
local satelliteLauncher=unit(categories('EXPERIMENTAL','STRUCTURE')); satelliteLauncher.blueprint={BlueprintId='xeb2402'}
local mobileLand=unit(categories('LAND','MOBILE'))
local engineerLand=unit(categories('LAND','MOBILE','ENGINEER'))
local landExperimental=unit(categories('LAND','MOBILE','EXPERIMENTAL')); landExperimental.blueprint={BlueprintId='uel0401'}
local airExperimental=unit(categories('AIR','MOBILE','EXPERIMENTAL')); airExperimental.blueprint={BlueprintId='xsa0402'}
local uefShield=unit(categories('MOBILE','SHIELD','UEF','TECH2','LAND')); uefShield.blueprint={BlueprintId='uel0307'}
local aeonShield=unit(categories('MOBILE','SHIELD','AEON','TECH2','LAND')); aeonShield.blueprint={BlueprintId='ual0307'}
local seraShield=unit(categories('MOBILE','SHIELD','SERAPHIM','TECH3','LAND')); seraShield.blueprint={BlueprintId='xsl0307'}
local excludedNavalShield=unit(categories('MOBILE','SHIELD','UEF','TECH2','NAVAL')); excludedNavalShield.blueprint={BlueprintId='xes0205'}
local excludedCybranStealth=unit(categories('MOBILE','STEALTHFIELD','CYBRAN','TECH2','NAVAL')); excludedCybranStealth.blueprint={BlueprintId='xrs0205'}
local cybranStealth=unit(categories('MOBILE','STEALTHFIELD','CYBRAN','TECH2','LAND')); cybranStealth.blueprint={BlueprintId='url0306'}

local modules={
 ['/lua/ui/game/orders.lua']={
  EnterOverchargeMode=function() calls.overcharge=true end,
  Stop=function(selection) calls.stop=selection end,
  SoftStop=function(selection) calls.soft_stop=selection end,
 },
 ['/lua/ui/game/commandmode.lua']={StartCommandMode=function(kind, command) calls.command={kind,command} end},
 ['/lua/keymap/misckeyactions.lua']={toggleScript=function(name) calls.toggle=name end},
 ['/lua/ui/game/construction.lua']={
  DecreaseBuildCountInQueue=function(count, amount) calls.remove={count,amount} end,
  RefreshUI=function() calls.refresh=true end,
 },
}
local cycleCalls={}
local failQueueDecrease=false
local refreshCount=0
local emptyMexResults, failMexTech2=false,false
local engineerCandidates, failEngineerQuery={},false
local mousePosition={0,0,0}
local ignoreSelection, visibleSelections=false,0
modules['/lua/ui/game/gamemain.lua']={SetIgnoreSelection=function(value) ignoreSelection=value end}
modules['/lua/ui/game/construction.lua'].DecreaseBuildCountInQueue=function(count,amount)
 calls.remove={count,amount}
 if failQueueDecrease then error('simulated queue update failure') end
end
modules['/lua/ui/game/construction.lua'].RefreshUI=function() refreshCount=refreshCount+1 end
local environment=setmetatable({
 import=function(path) return assert(modules[path],path) end,
 ConExecute=function(command) calls.conexecute=command end,
 GetUnitCommandData=function(selection)
  if selection and #selection==1 then
   local selected=selection[1]
   return selected.orders or {},selected.toggles or toggles
  end
  return {},toggles
 end,
 GetSelectedUnits=function() return selectedForCommand end,
 GetMouseWorldPos=function() return mousePosition end,
 SelectUnits=function(selection)
  selectedForCommand=selection; calls.selected=selection
  if not ignoreSelection then visibleSelections=visibleSelections+1 end
 end,
 UISelectionByCategory=function(category, a, onScreen)
  cycleCalls[#cycleCalls+1]={category=category,onScreen=onScreen}
  if category:find('ENGINEER',1,true) then
   assert(ignoreSelection,'engineer candidate query must be hidden from UI observers and command mode')
   if failEngineerQuery then error('simulated engineer query failure') end
   selectedForCommand={}
   for _,candidate in ipairs(engineerCandidates) do
    if (category:find('TECH1',1,true) and candidate:IsInCategory('TECH1'))
     or (category:find('TECH2',1,true) and candidate:IsInCategory('TECH2'))
     or (category:find('TECH3',1,true) and candidate:IsInCategory('TECH3'))
     or (not category:find('TECH1',1,true) and not category:find('TECH2',1,true)
      and not category:find('TECH3',1,true)) then
     table.insert(selectedForCommand,candidate)
    end
   end
   return
  end
  if category=='LAND MOBILE' then selectedForCommand={mobileLand,megalith,engineerLand}; return end
  if category=='EXPERIMENTAL MOBILE LAND' then selectedForCommand={megalith,satellite,landExperimental}; return end
  if category=='EXPERIMENTAL AIR' then selectedForCommand={satellite,airExperimental}; return end
  if category=='EXPERIMENTAL' then selectedForCommand={satellite,satelliteLauncher}; return end
  if category=='MOBILE SHIELD' then selectedForCommand={uefShield,aeonShield,seraShield,excludedNavalShield}; return end
  if category:find('TECH2',1,true) and failMexTech2 then error('simulated mex query failure') end
  if emptyMexResults then return end
  selectedForCommand=category:find('TECH1',1,true) and {mexOne,wrongCategory} or {mexTwo,wrongTech}
 end,
 SetPaused=function(selection, value) assert(selection and #selection>0); paused=value end,
 GetIsPaused=function() return paused end,
 SetCurrentFactoryForQueueDisplay=function(selected) assert(selected==factory); return queue end,
 ClearCurrentFactoryForQueueDisplay=function() calls.clearqueue=(calls.clearqueue or 0)+1 end,
 IsKeyDown=function(key) return key=='Shift' end,
}, {__index=_G})
environment._G=environment
environment.ReUI={ClaretCore={Localization=testLocalization}}
local ContextActions=setmetatable({}, {__index=environment})
local contextQueue=setmetatable({}, {__index=environment})
assert(loadfile('../mods/ClaretHotbuild/modules/ContextQueue.lua','t',contextQueue))()
modules['/mods/ClaretHotbuild/modules/ContextQueue.lua']=contextQueue
assert(loadfile('../mods/ClaretHotbuild/modules/ContextActions.lua','t',ContextActions))()
for _,domain in ipairs({'land','naval','air'}) do
    for level=1,3 do
        for _,area in ipairs({'screen','map'}) do
            local id='select_'..domain..'_factories_t'..level..'_'..area
            local action=assert(ContextActions.Get(id),id)
            local command='UI_SelectByCategory '..(area=='screen' and '+inview ' or '')
                ..'STRUCTURE FACTORY '..string.upper(domain)..' TECH'..level
            assert(not action.hidden and ContextActions.Supports(id,'empty') and action.select==command,id)
        end
    end
    assert(ContextActions.Get('select_'..domain..'_factories_screen').hidden,'old combined assignment remains available but hidden')
end
local instant=assert(ContextActions.Get('kill_selected_units'))
local delayed=assert(ContextActions.Get('suicide'))
assert(not instant.hidden and ContextActions.Supports(instant.id,'units'))
assert(delayed.hidden and delayed.obsolete, 'historic delayed destruction is not offered')
assert(instant.select:find('ConfirmUnitDestruction(true)',1,true)
    and delayed.select:find('ConfirmUnitDestruction(false)',1,true),
    'instant and historic delayed destruction retain separate commands')
assert(ContextActions.Execute(instant,{selection={other},focusArmy=1,isReplay=false},'test'))
assert(calls.conexecute==instant.select,'instant destruction dispatches the native FAF command')
assert(ContextActions.Execute(delayed,{selection={other},focusArmy=1,isReplay=false},'test'))
assert(calls.conexecute==delayed.select,'saved delayed destruction still dispatches its original command')
local factoryCycle=assert(ContextActions.Get('cycle_idle_factories'))
assert(factoryCycle.continuation=='cycle' and ContextActions.Available(factoryCycle,
    {selection={factory},focusArmy=1,isReplay=false,isRepeat=true,orders={}}),
    'cycle continues after selecting a factory')
local missile=assert(ContextActions.Get('smart_missile'))
assert(ContextActions.Supports('smart_missile','missiles') and ContextActions.Supports('smart_missile','acu'))
tacticalSilo.orders={'RULEUCC_Tactical'}; nuclearSilo.orders={'RULEUCC_Nuke'}
acu.orders={'RULEUCC_Tactical'}; sacu.orders={}
local function missileContext(selection)
 return {selection=selection,focusArmy=1,isReplay=false,orders={}}
end
assert(ContextActions.Execute(missile,missileContext({tacticalSilo}),'test'))
assert(calls.command[2].name=='RULEUCC_Tactical')
assert(ContextActions.Execute(missile,missileContext({nuclearSilo}),'test'))
assert(calls.command[2].name=='RULEUCC_Nuke')
assert(ContextActions.Execute(missile,missileContext({acu}),'test'))
assert(not ContextActions.Execute(missile,missileContext({sacu}),'test'))
assert(not ContextActions.Execute(missile,missileContext({tacticalSilo,nuclearSilo}),'test'))


local outcomeContext={selection={},focusArmy=1,isReplay=false,orders={},absolute=true}
local selectOutcomeContext={selection={},focusArmy=1,isReplay=false,orders={}}
local cycleFactory=ContextActions.Get('cycle_idle_factories')
assert(cycleFactory and ContextActions.Supports(cycleFactory.id,'empty') and ContextActions.IsSelection(cycleFactory.id))
selectedForCommand={factory}
local _,cycleOutcome=ContextActions.ExecuteWithOutcome(cycleFactory,outcomeContext,'test')
assert(cycleOutcome=='executed' and calls.conexecute=='UI_Lua import("/lua/keymap/misckeyactions.lua").CycleIdleFactories()', 'idle factory action dispatch and target')
selectedForCommand={other}
_,cycleOutcome=ContextActions.ExecuteWithOutcome(cycleFactory,outcomeContext,'test')
assert(cycleOutcome=='not_found','idle factory fallback requires a factory selection')
selectedForCommand={}
local _,outcome=ContextActions.ExecuteWithOutcome(ContextActions.Get('select_acu'),selectOutcomeContext,'test')
assert(outcome=='not_found','empty target selection is not_found')
selectedForCommand={acu}
local beforeAlreadySelected=calls.conexecute
_,outcome=ContextActions.ExecuteWithOutcome(ContextActions.Get('select_acu'),selectOutcomeContext,'test')
assert(outcome=='executed' and calls.conexecute==beforeAlreadySelected,
    'already selected target is found without dispatching over a racing selection update')
selectedForCommand={other}
local beforeDifferentSelection=calls.conexecute
_,outcome=ContextActions.ExecuteWithOutcome(ContextActions.Get('select_acu'),selectOutcomeContext,'test')
assert(outcome=='unavailable' and calls.conexecute==beforeDifferentSelection,
    'a different selection is preserved when an empty-selection action races')
selectedForCommand={}

assert(ContextActions.Classify(nil)=='empty')
assert(ContextActions.Classify({})=='empty')
local cases={
 {acu,'acu'}, {sacu,'sacu'}, {engineer,'engineer'}, {factory,'factory'},
 {transport,'transport'}, {tacticalSilo,'silo_tactical'}, {nuclearSilo,'silo_nuclear'},
 {xsbSilo,'silo_nuclear'}, {mex,'mex'}, {scout,'scout'}, {other,'other'},
 {megalith,'land'}, {mobileLand,'land'}, {satellite,'air'},
}
for _, case in ipairs(cases) do assert(ContextActions.Classify({case[1]})==case[2],case[2]) end
assert(ContextActions.Classify({acu,acu})=='acu','homogeneous group')
assert(ContextActions.Classify({acu,sacu})=='acu','ACU priority in mixed selection')
assert(ContextActions.Classify({engineer,mobileLand})=='land','army takes priority over builders')
local mobileFactory=unit(categories('MOBILE','LAND','FACTORY'))
local mobileMissile=unit(categories('MOBILE','LAND','SILO','TECH2'))
local landScout=unit(categories('MOBILE','LAND','INTELLIGENCE'))
local drone=unit(categories('MOBILE','AIR','DRONE'))
assert(ContextActions.Classify({mobileFactory})=='land','mobile factories are Units')
assert(ContextActions.Classify({mobileMissile})=='silo_tactical','mobile missile unit is a missile')
assert(ContextActions.Classify({mobileMissile,mobileLand})=='land','army precedes mobile missile unit')
assert(ContextActions.Classify({landScout})=='land','land scout is Units')
assert(ContextActions.Classify({drone})=='other','drones are Other')
assert(ContextActions.Supports('move','units') and ContextActions.Supports('stop','missiles')
    and not ContextActions.Supports('nuke','missiles'),'group applicability is common to children')
assert(ContextActions.Supports('pause_unit','missiles') and ContextActions.Supports('pause_unit','silo_tactical')
    and ContextActions.Supports('pause_unit','silo_nuclear'), 'pause is shared by both missile contexts')
assert(ContextActions.Supports('ferry','transport') and ContextActions.Supports('dock','transport')
    and not ContextActions.Supports('ferry','units'), 'transport receives ferry and dock only in its own context')
assert(ContextActions.Supports('upgrade_structure_pause','mex'), 'extractors offer native rollover upgrade with pause')
assert(ContextActions.Supports('patrol','scout') and ContextActions.Supports('dock','scout'),
    'air scouts offer patrol and docking')
-- Units is the parent row for Land, Air, and Navy. Shared actions are valid
-- for each child and the grouped row; child-only actions stay scoped.
for _,kind in ipairs({'units','land','air','navy'}) do
    assert(ContextActions.Supports('move',kind) and ContextActions.Supports('patrol',kind),
        'shared Units actions apply to '..kind)
end
assert(not ContextActions.Supports('dock','units') and ContextActions.Supports('dock','air')
    and not ContextActions.Supports('dock','land') and not ContextActions.Supports('dock','navy'),
    'air-only action does not widen to the Units parent or other children')
assert(not ContextActions.Supports('dive','units') and ContextActions.Supports('dive','navy')
    and not ContextActions.Supports('dive','land') and not ContextActions.Supports('dive','air'),
    'navy-only action does not widen to the Units parent or other children')
local submarine=unit(categories('NAVAL','MOBILE'))
local diveContext={selection={submarine},focusArmy=1,isReplay=false,orders={},resolvedContext='navy'}
assert(not ContextActions.Available(ContextActions.Get('dive'),diveContext),'dive requires a live unit command')
submarine.orders={'RULEUCC_Dive'}
for _,id in ipairs({'dive','dive_all','undive_all'}) do
    assert(ContextActions.Available(ContextActions.Get(id),diveContext),id..' accepts a capable naval unit')
end
assert(ContextActions.Supports('cycle_unit_types_in_sel','units')
    and ContextActions.Supports('cycle_unit_types_in_sel','land')
    and ContextActions.Supports('cycle_unit_types_in_sel','air')
    and ContextActions.Supports('cycle_unit_types_in_sel','navy')
    and not ContextActions.Supports('cycle_unit_types_in_sel','builder')
    and not ContextActions.Supports('cycle_unit_types_in_sel','acu'),
    'Units-specific selection action does not apply to builder contexts')
assert(ContextActions.Get('cycle_unit_types_in_sel').hidden and ContextActions.Get('cycle_unit_types_in_sel').obsolete,
    'the cycle-unit-types command is retired from new context assignments while its saved ID remains addressable')
assert(ContextActions.Get('attack').label=='Атака по площади'
    and ContextActions.Get('attack').order=='RULEUCC_Attack',
    'all uses of the Attack order share the corrected area-attack label; got '..tostring(ContextActions.Get('attack').label))
assert(ContextActions.Classify({factory,other})=='factory','factory priority in mixed selection')
assert(ContextActions.Classify({engineer,other})=='engineer','engineer priority in mixed selection')
-- Lock down the full precedence chain, including both silo classes and lower-priority units.
local precedence={
 {mobileLand,'land'},{acu,'acu'},{sacu,'sacu'},{engineer,'engineer'},{factory,'factory'},
 {tacticalSilo,'silo_tactical'},{nuclearSilo,'silo_nuclear'},
 {transport,'transport'},{mex,'mex'},{scout,'scout'},{other,'other'},
}
for i=1,#precedence do
    for j=i+1,#precedence do
        assert(ContextActions.Classify({precedence[i][1],precedence[j][1]})==precedence[i][2],
            'mixed selection precedence '..precedence[i][2]..' before '..precedence[j][2])
    end
end
assert(ContextActions.Classify({other,scout,mex})=='mex','classification is independent of selection array order')
assert(ContextActions.Supports('overcharge','acu') and ContextActions.Supports('overcharge','sacu'))
assert(ContextActions.Supports('tactical','silo_tactical') and not ContextActions.Supports('nuke','silo_tactical'))
assert(ContextActions.Supports('nuke','silo_nuclear') and not ContextActions.Supports('tactical','silo_nuclear'))
assert(ContextActions.Supports('select_all_scouts','empty') and ContextActions.Supports('select_all_scouts','scout'))
assert(ContextActions.Get('select_t3_artillery').select:find('TECH3',1,true), 'mobile artillery is T3 only')
for _,id in ipairs({'select_t3_mml'}) do
    assert(not ContextActions.Get(id).select:find('TECH3',1,true), id..' includes all tech levels')
end
assert(ContextActions.Get('select_t3_mml').select:find('+excludeengineers',1,true),
    'MML selection excludes commanders and support commanders with SILO')
for _,id in ipairs({'select_bombers','select_fighters','select_gunships','select_land_army_screen',
    'select_land_army_map','select_naval_army_screen','select_naval_army_map','select_experimentals',
    'select_satellites','select_land_experimentals','select_air_experimentals',
    'select_transport_screen','select_transport_map','select_tactical_silos',
    'select_nuclear_silos','select_t3_artillery','select_t3_shields','select_t3_stealth','select_t3_mml'}) do
    local item=ContextActions.Get(id)
    assert(item and ContextActions.Supports(id,'empty') and item.selectionPolicy=='exclusive',
        id..' is available with empty selection and blocks conflicting contexts')
end
assert(ContextActions.Get('select_transport_nearest').selectionPolicy=='accumulate'
    and ContextActions.Supports('select_transport_nearest','empty'),
    'nearest free transport accumulates into the selection')
assert(ContextActions.Get('select_experimentals').special=='select_mobile_land_experimentals',
    'default experimental selection is mobile land, excluding Scathis and satellite')
assert(ContextActions.Get('select_land_army_screen').special=='select_land_army_screen'
    and ContextActions.Get('select_land_army_map').special=='select_land_army_map',
    'land army selectors exclude Scathis')
assert(ContextActions.Get('select_land_experimentals').select=='UI_SelectByCategory EXPERIMENTAL LAND'
    and ContextActions.Get('select_air_experimentals').special=='select_air_experimentals',
    'land and air experimental selectors are separate')
assert(ContextActions.Get('select_t3_shields').special=='select_mobile_shields',
    'mobile shields are filtered by exact requested blueprint IDs')
assert(ContextActions.Get('select_t3_stealth').select:find('LAND MOBILE STEALTHFIELD CYBRAN TECH2',1,true),
    'mobile stealth is limited to land Cybran T2')
assert(ContextActions.Get('cycle_mex_screen').legacy and ContextActions.Get('cycle_mex_map').legacy,
    'extractor cycle actions remain intact for legacy profiles')
local shownActionIds={}
for _,action in ipairs(ContextActions.List()) do shownActionIds[action.id]=true end
assert(not shownActionIds.cycle_mex_screen and not shownActionIds.cycle_mex_map,
    'extractor cycle actions are hidden from new editor lists')
for _,id in ipairs({'select_engineers_t1','select_engineers_t2','select_engineers_t3','select_engineers_all'}) do
    local item=ContextActions.Get(id)
    assert(item and item.selectionPolicy=='accumulate' and item.continuation=='accumulate',id..' accumulates on subsequent presses')
end
assert(ContextActions.Get('select_acu').selectionPolicy=='exclusive'
    and ContextActions.Get('select_acu_double').selectionPolicy=='double',
    'ordinary and double selection actions use distinct policies')
assert(ContextActions.Execute(ContextActions.Get('select_satellites'),{selection={},focusArmy=1,isReplay=false,orders={}})
    and #calls.selected==1 and calls.selected[1]==satellite,
    'satellite action selects the unit ID while filtering out its launcher')
assert(ContextActions.Execute(ContextActions.Get('select_land_army_screen'),{selection={},focusArmy=1,isReplay=false,orders={}})
    and #calls.selected==1 and calls.selected[1]==mobileLand and cycleCalls[#cycleCalls].onScreen==true,
    'screen army filtering excludes engineers and Scathis')
assert(ContextActions.Execute(ContextActions.Get('select_land_army_map'),{selection={},focusArmy=1,isReplay=false,orders={}})
    and #calls.selected==1 and calls.selected[1]==mobileLand and cycleCalls[#cycleCalls].onScreen==false,
    'map army filtering excludes engineers and Scathis')
assert(ContextActions.Execute(ContextActions.Get('select_experimentals'),{selection={},focusArmy=1,isReplay=false,orders={}})
    and #calls.selected==1 and calls.selected[1]==landExperimental,
    'mobile land experimental action filters Scathis and satellite')
assert(ContextActions.Execute(ContextActions.Get('select_air_experimentals'),{selection={},focusArmy=1,isReplay=false,orders={}})
    and #calls.selected==1 and calls.selected[1]==airExperimental,
    'air experimental action filters satellite')
assert(ContextActions.Execute(ContextActions.Get('select_t3_shields'),{selection={},focusArmy=1,isReplay=false,orders={}})
    and #calls.selected==3 and calls.selected[1]==uefShield and calls.selected[2]==aeonShield and calls.selected[3]==seraShield,
    'mobile shields include only UEF T2, Aeon T2 and Seraphim T3 units')
selectedForCommand={}
assert(ContextActions.Get('select_t3_stealth').select=='UI_SelectByCategory +inview LAND MOBILE STEALTHFIELD CYBRAN TECH2',
    'Cybran T2 naval stealth unit is excluded by the land filter')
assert(ContextActions.Available(ContextActions.Get('select_gunships'),
    {selection={scout},focusArmy=1,isReplay=false,orders={},absolute=true}),
    'absolute selection actions remain available regardless of current selection')
selectedForCommand={}
local mobileCarrier=unit(categories('TRANSPORTATION','EXTERNALFACTORY','MOBILE'))
assert(ContextActions.Available(ContextActions.Get('select_transport_double'),
    {selection={mobileCarrier},focusArmy=1,isReplay=false,isRepeat=true,orders={}}),
    'a pending transport double press also supports mobile factory transports')
local upgradeDispatch={}
modules['/mods/ClaretHotbuild/modules/ContextUpgrade.lua']={
    Available=function(id) upgradeDispatch.available=id; return true end,
    Execute=function(id) upgradeDispatch.execute=id; return true end,
}
local upgradeContext={selection={},focusArmy=1,isReplay=false,orders={}}
assert(ContextActions.Execute(ContextActions.Get('upgrade_structure_under_cursor'),upgradeContext)
    and upgradeDispatch.available=='upgrade_structure_under_cursor'
    and upgradeDispatch.execute=='upgrade_structure_under_cursor','hover upgrade is routed through the upgrade module')
assert(ContextActions.Execute(ContextActions.Get('upgrade_mex_select_next'),upgradeContext)
    and upgradeDispatch.execute=='upgrade_mex_select_next','mex upgrade is routed from empty context')
upgradeContext.selection={mex}
assert(ContextActions.Execute(ContextActions.Get('upgrade_mex_select_next'),upgradeContext),
    'mex upgrade continuation is supported with a mex selected')

local action=ContextActions.Get('move')
units={acu}
local context={selection=units,orders={RULEUCC_Move=true},focusArmy=1,isReplay=false}
assert(ContextActions.Available(action,context))
assert(ContextActions.Execute(action,context) and calls.command[1]=='order' and calls.command[2].name=='RULEUCC_Move')
context.orders.RULEUCC_Move=nil
assert(not ContextActions.Available(action,context) and not ContextActions.Execute(action,context),'missing order')
context.orders.RULEUCC_Move=true; context.focusArmy=-1
assert(not ContextActions.Available(action,context),'no focus army')
context.focusArmy=1; context.isReplay=true
assert(not ContextActions.Available(action,context) and not ContextActions.Execute(action,context),'replay blocks execution')
context.isReplay=false

-- A common Units command stays native and applies to the existing mixed
-- army selection without Claret temporarily selecting a subset.
local mixedUnits={mobileLand,scout}
context.selection=mixedUnits
context.resolvedContext='units'
context.orders={RULEUCC_Move=true}
local beforeSelection=selectedForCommand
local beforeVisibleSelections=visibleSelections
assert(ContextActions.Available(action,context),'shared command supports a mixed Units child selection')
assert(ContextActions.Execute(action,context) and calls.command[2].name=='RULEUCC_Move',
    'mixed Units command opens the native order mode')
assert(selectedForCommand==beforeSelection and visibleSelections==beforeVisibleSelections,
    'mixed Units command does not reselect or split the selection')

local patrol=ContextActions.Get('patrol')
local capableBuilder=unit(categories('ENGINEER'))
capableBuilder.orders={'RULEUCC_Patrol'}
context.selection={mobileLand,capableBuilder}
context.resolvedContext='units'
assert(not ContextActions.Available(patrol,context) and not ContextActions.Execute(patrol,context),
    'builder patrol capability cannot enable the Units action in a mixed selection')
mobileLand.orders={'RULEUCC_Patrol'}
assert(ContextActions.Available(patrol,context) and ContextActions.Execute(patrol,context)
    and calls.command[2].name=='RULEUCC_Patrol',
    'one eligible Units child with the native patrol capability enables and dispatches')
mobileLand.orders=nil
context.selection={mobileLand}
assert(not ContextActions.Available(patrol,context) and not ContextActions.Execute(patrol,context),
    'Units patrol is unavailable when no eligible selected unit has the native capability')

local discharge=ContextActions.Get('discharge')
capableBuilder.toggles={'RULEUTC_ShieldToggle'}
context.selection={mobileLand,capableBuilder}
context.resolvedContext='units'
assert(not ContextActions.Available(discharge,context) and not ContextActions.Execute(discharge,context),
    'builder shield capability cannot enable the Units discharge action')
mobileLand.toggles={'RULEUTC_ShieldToggle'}
assert(ContextActions.Available(discharge,context) and ContextActions.Execute(discharge,context)
    and calls.conexecute:find('DischargeShields',1,true),
    'one eligible land unit with the shield capability enables and dispatches discharge')
mobileLand.toggles=nil
context.selection={mobileLand}
assert(not ContextActions.Available(discharge,context) and not ContextActions.Execute(discharge,context),
    'discharge is unavailable when no eligible land unit has the shield capability')

-- Builders is a parent of ACU, SACU, and Engineer. Repair applies across
-- those children, while engineer filtering and ACU teleport stay scoped.
for _,kind in ipairs({'builder','acu','sacu','engineer'}) do
    assert(ContextActions.Supports('repair',kind),'builder repair applies to '..kind)
end
for _,kind in ipairs({'transport','scout','silo_tactical','silo_nuclear'}) do
    assert(ContextActions.Supports('spreadattack',kind),'distribute orders applies to '..kind)
end
local mobileFactory=unit(categories('FACTORY','MOBILE','LAND'))
assert(not ContextActions.Available(ContextActions.Get('spreadattack'),{
    selection={mobileFactory},orders={},focusArmy=1,isReplay=false,
}), 'distribute orders is unavailable when FAF would filter every selected factory')
assert(not ContextActions.Supports('repair','units') and not ContextActions.Supports('repair','land'),
    'builder repair does not leak into Units contexts')
assert(ContextActions.Supports('filter_highest_engineer_and_assist','engineer')
    and not ContextActions.Supports('filter_highest_engineer_and_assist','builder')
    and not ContextActions.Supports('filter_highest_engineer_and_assist','acu'),
    'engineer filtering remains limited to Engineer')
assert(ContextActions.Supports('teleport','acu') and not ContextActions.Supports('teleport','builder')
    and not ContextActions.Supports('teleport','sacu') and not ContextActions.Supports('teleport','engineer'),
    'ACU teleport remains an ACU-only builder action')

local repair=ContextActions.Get('repair')
local mixedBuildersAndArmy={acu,engineerLand,mobileLand}
context.selection=mixedBuildersAndArmy
context.resolvedContext='builder'
mobileLand.orders={'RULEUCC_Repair'}
assert(not ContextActions.Available(repair,context) and not ContextActions.Execute(repair,context),
    'army repair capability cannot enable the Builders action in a mixed selection')
engineerLand.orders={'RULEUCC_Repair'}
local beforeSelection=selectedForCommand
local beforeVisibleSelections=visibleSelections
assert(ContextActions.Available(repair,context) and ContextActions.Execute(repair,context)
    and calls.command[1]=='order' and calls.command[2].name=='RULEUCC_Repair',
    'one capable selected Builder enables and dispatches native Repair')
assert(selectedForCommand==beforeSelection and visibleSelections==beforeVisibleSelections,
    'mixed Builders command preserves the whole selection without hidden reselection')
engineerLand.orders=nil
context.selection={acu,engineer}
context.resolvedContext='builder'
assert(not ContextActions.Available(repair,context) and not ContextActions.Execute(repair,context),
    'Repair is unavailable when no selected Builder has its native capability')

local teleport=ContextActions.Get('teleport')
context.selection={acu,engineer}
context.resolvedContext='builder'
acu.orders={'RULEUCC_Teleport'}
assert(ContextActions.Available(teleport,context) and ContextActions.Execute(teleport,context)
    and calls.command[2].name=='RULEUCC_Teleport',
    'ACU teleport dispatch requires and accepts the ACU native capability')
acu.orders=nil
assert(not ContextActions.Available(teleport,context) and not ContextActions.Execute(teleport,context),
    'ACU teleport is unavailable when the ACU lacks its native capability')
context.resolvedContext=nil

-- Cargo selection uses the stable Core API with no optional ReUI module dependency.
local cargoAction=ContextActions.Get('append_transport_cargo')
assert(cargoAction and cargoAction.id=='append_transport_cargo','cargo action ID remains stable')
assert(ContextActions.Supports('append_transport_cargo','transport')
 and not ContextActions.Supports('append_transport_cargo','other'),'cargo action is transport-only')
local cargoCalls,cargoResult={},false
local fakeReUI={ClaretCore={AppendTransportCargo=function(selection)
 cargoCalls[#cargoCalls+1]=selection; return cargoResult
end},Exists=function() error('cargo action must not query optional ReUI module versions') end}
context.selection={transport}
environment.ReUI=nil
assert(not ContextActions.Available(cargoAction,context) and not ContextActions.Execute(cargoAction,context),
 'missing Core cargo API is safe')
environment.ReUI={ClaretCore={}}
assert(not ContextActions.Available(cargoAction,context) and not ContextActions.Execute(cargoAction,context),
 'missing Core cargo function is safe')
environment.ReUI=fakeReUI
assert(ContextActions.Available(cargoAction,context),'transport context exposes the Core cargo action')
assert(not ContextActions.Execute(cargoAction,context) and cargoCalls[1]==context.selection,
 'Core API receives the selected transport and its false return is propagated')
cargoResult=true
assert(ContextActions.Execute(cargoAction,context) and cargoCalls[2]==context.selection,
 'Core API success return is propagated')
context.selection={transport,other}
local cargoCount=#cargoCalls
assert(not ContextActions.Available(cargoAction,context) and not ContextActions.Execute(cargoAction,context)
 and #cargoCalls==cargoCount,'transport cargo remains restricted to all-transport selections')
context.selection={other}
assert(not ContextActions.Available(cargoAction,context) and not ContextActions.Execute(cargoAction,context)
 and #cargoCalls==cargoCount,'non-transport selection never reaches the Core cargo API')
context.selection={acu}
context.orders.RULEUCC_Overcharge=true
context.selection={}
assert(ContextActions.Execute(ContextActions.Get('select_acu'),context))
assert(calls.conexecute=='UI_SelectByCategory +nearest +goto COMMAND')
assert(not ContextActions.Execute(ContextActions.Get('select_acu'),{focusArmy=1,orders={},selection={},isReplay=true}))
selectedForCommand={scout}; context.selection={scout}
assert(ContextActions.Execute(ContextActions.Get('select_all_scouts'),context)
 and calls.conexecute=='UI_SelectByCategory AIR INTELLIGENCE','select all scouts is also available from scout context')
selectedForCommand={}; context.selection={}

-- Cycle spans both T1 and T2 even when both categories contain candidates.
for i=#cycleCalls,1,-1 do cycleCalls[i]=nil end
assert(ContextActions.Execute(ContextActions.Get('cycle_mex_screen'),context))
assert(calls.selected[1]==mexOne and #cycleCalls==2 and cycleCalls[1].onScreen==true
 and cycleCalls[2].onScreen==true,'screen cycle queries both tech groups')
context.selection={mexOne}; selectedForCommand={mexOne}
assert(ContextActions.Execute(ContextActions.Get('cycle_mex_screen'),context))
assert(calls.selected[1]==mexTwo,'cycle advances from T1 to T2')
context.selection={mexTwo}; selectedForCommand={mexTwo}
assert(ContextActions.Execute(ContextActions.Get('cycle_mex_map'),context))
assert(calls.selected[1]==mexOne and cycleCalls[5].onScreen==false and cycleCalls[6].onScreen==false,
 'map cycle wraps over both tech groups')
selectedForCommand={scout}; context.selection={}
emptyMexResults=true
assert(not ContextActions.Execute(ContextActions.Get('cycle_mex_screen'),context),'no eligible mex reports no action')
emptyMexResults=false
assert(selectedForCommand[1]==scout and calls.selected[1]==scout,'empty mex result restores original selection')
selectedForCommand={scout}; failMexTech2=true
local queryOk=pcall(ContextActions.Execute,ContextActions.Get('cycle_mex_screen'),context)
failMexTech2=false
assert(not queryOk and selectedForCommand[1]==scout and calls.selected[1]==scout,
 'failed second query restores selection before propagating the error')
context.selection={acu}
context.orders={RULEUCC_Nuke=true,RULEUCC_Tactical=true,RULEUCC_Overcharge=true,RULEUCC_Move=true}
context.selection={tacticalSilo}
assert(ContextActions.Execute(ContextActions.Get('tactical'),context)
 and calls.command[2].name=='RULEUCC_Tactical','TECH2 silo exposes tactical launch')
context.selection={nuclearSilo}
assert(ContextActions.Execute(ContextActions.Get('nuke'),context)
 and calls.command[2].name=='RULEUCC_Nuke','TECH3 silo exposes nuclear launch')
context.selection={xsbSilo}
assert(ContextActions.Execute(ContextActions.Get('nuke'),context)
 and calls.command[2].name=='RULEUCC_Nuke','xsb2401 is classified as nuclear')
context.selection={acu}
context.orders.RULEUCC_Move=true

-- Sequential engineer selection adds one unseen unit per invocation, excludes command units,
-- includes busy engineers, and preserves the original list when candidate discovery fails.
local engOne,engTwo=unit(categories('ENGINEER','MOBILE','TECH1')),unit(categories('ENGINEER','MOBILE','TECH1'))
local engThree=unit(categories('ENGINEER','MOBILE','TECH2'))
local engFour=unit(categories('ENGINEER','MOBILE','TECH3'))
local engAcu=unit(categories('ENGINEER','COMMAND'))
local engSacu=unit(categories('ENGINEER','SUBCOMMANDER'))
for i,u in ipairs({engOne,engTwo,engThree,engAcu,engSacu,engFour}) do
 u.entityId=i
 function u:GetEntityId() return self.entityId end
 function u:GetPosition() return self.position end
end
engOne.position={20,0,0}; engTwo.position={3,0,0}; engThree.position={9,0,0}
engAcu.position={1,0,0}; engSacu.position={2,0,0}
engFour.position={7,0,0}
engineerCandidates={engTwo,engAcu,engOne,engThree,engSacu,engFour}
context.selection={}; selectedForCommand={}
local addT1=ContextActions.Get('select_engineers_t1')
local visibleBefore=visibleSelections
assert(ContextActions.Execute(addT1,context) and #selectedForCommand==1
 and selectedForCommand[1]==engTwo,'T1 selects the closest eligible engineer to the cursor')
assert(not ignoreSelection and visibleSelections==visibleBefore+1,
 'only the final engineer addition notifies the UI')
mousePosition={19,0,0}
context.selection=selectedForCommand
assert(ContextActions.Execute(addT1,context) and #selectedForCommand==2
 and selectedForCommand[2]==engOne,'next press uses the new cursor position and retains existing selection')
context.selection=selectedForCommand
visibleBefore=visibleSelections
assert(not ContextActions.Execute(addT1,context),'T1 ignores already selected units and excludes ACU/SACU')
assert(not ignoreSelection and visibleSelections==visibleBefore,'no candidates produce no visible selection update')
context.selection={}; selectedForCommand={}
local addT2=ContextActions.Get('select_engineers_t2')
assert(ContextActions.Execute(addT2,context) and #selectedForCommand==1
 and selectedForCommand[1]==engThree,'T2 action filters by tech while querying the whole map')
context.selection={}; selectedForCommand={}
assert(ContextActions.Execute(ContextActions.Get('select_engineers_t3'),context)
 and selectedForCommand[1]==engFour,'T3 action selects an eligible T3 engineer')
context.selection={}; selectedForCommand={}; mousePosition={0,0,0}
assert(ContextActions.Execute(ContextActions.Get('select_engineers_all'),context)
 and selectedForCommand[1]==engTwo,'all tiers selects nearest across tech levels')
context.selection={}; selectedForCommand={}; mousePosition=nil
assert(not ContextActions.Execute(addT1,context) and #selectedForCommand==0,
 'missing mouse position leaves selection unchanged')
mousePosition={0,0,0}
context.selection={engOne}; selectedForCommand={engOne}
local originalEngineerSelection=context.selection
failEngineerQuery=true
visibleBefore=visibleSelections
local engineerQueryOk=pcall(ContextActions.Execute,addT1,context)
failEngineerQuery=false
assert(not engineerQueryOk and context.selection==originalEngineerSelection
 and #selectedForCommand==1 and selectedForCommand[1]==engOne,
 'failed engineer discovery restores original selection without mutating its array')
assert(not ignoreSelection and visibleSelections==visibleBefore,
 'failed discovery resets the ignore flag without publishing candidate or restoration selections')

context.selection={fireBeetle,secondFireBeetle}
assert(ContextActions.Available(ContextActions.Get('fire_beetle_detonate'),context))
assert(ContextActions.Execute(ContextActions.Get('fire_beetle_detonate'),context) and calls.toggle=='Production',
 'all selected xrl0302 units may detonate through the standard Production toggle')
local previousToggle=calls.toggle
context.selection={fireBeetle,other}
assert(not ContextActions.Available(ContextActions.Get('fire_beetle_detonate'),context)
 and not ContextActions.Execute(ContextActions.Get('fire_beetle_detonate'),context)
 and calls.toggle==previousToggle,'mixed blueprint selection cannot trigger detonation')
context.selection={acu}

-- Other toggles are offered only in Other, check each selected unit's live
-- native toggle capability, and execute the unchanged native hotkey command.
local otherToggle=ContextActions.Get('toggle_production')
local listedOtherActions={}
for _,item in ipairs(ContextActions.List()) do listedOtherActions[item.id]=true end
assert(listedOtherActions.toggle_production and ContextActions.Supports('toggle_production','other')
 and not ContextActions.Supports('toggle_production','land'),
 'production toggle is catalogued for Other only')
local drone=unit(categories('DRONE','AIR'))
local otherUnit=unit(categories('STATIONASSISTPOD'))
context.selection={drone,otherUnit}; context.resolvedContext='other'; context.legacyUnits=nil
drone.toggles={}; otherUnit.toggles={}
assert(not ContextActions.Available(otherToggle,context) and not ContextActions.Execute(otherToggle,context),
 'Other toggle is unavailable when no selected eligible unit has its native capability')
drone.toggles={'RULEUTC_ProductionToggle'}
local otherToggleSelection=selectedForCommand
local otherToggleVisibleSelections=visibleSelections
assert(ContextActions.Available(otherToggle,context) and ContextActions.Execute(otherToggle,context)
 and calls.conexecute=='UI_Lua import("/lua/keymap/misckeyactions.lua").toggleScript("Production")',
 'one capable selected Other unit enables and dispatches the exact native production toggle')
assert(selectedForCommand==otherToggleSelection and visibleSelections==otherToggleVisibleSelections,
 'Other toggle preserves the complete selection without hidden reselection')

-- When the Units row is empty, its legacy fallback displays Other actions for
-- a mobile army selection; capability is still read from each live unit.
context.selection={mobileLand}; context.resolvedContext='other'; context.legacyUnits=true
mobileLand.toggles={'RULEUTC_ProductionToggle'}
otherToggleSelection=selectedForCommand
otherToggleVisibleSelections=visibleSelections
assert(ContextActions.Available(otherToggle,context) and ContextActions.Execute(otherToggle,context)
 and calls.conexecute=='UI_Lua import("/lua/keymap/misckeyactions.lua").toggleScript("Production")',
 'capable mobile Unit can use the Other toggle through the legacy Units-empty fallback')
assert(selectedForCommand==otherToggleSelection and visibleSelections==otherToggleVisibleSelections,
 'legacy Other toggle preserves the mobile selection without reselection')
context.selection={acu}; context.resolvedContext=nil; context.legacyUnits=nil

assert(ContextActions.Execute(ContextActions.Get('overcharge'),context) and calls.overcharge)
assert(ContextActions.Execute(ContextActions.Get('attack_move'),context))
assert(calls.command[2].AbilityName=='AttackMove')
context.selection={factory}
assert(ContextActions.Execute(ContextActions.Get('pause'),context) and paused)
assert(ContextActions.Execute(ContextActions.Get('pause'),context) and not paused)
context.selection={acu}
assert(ContextActions.Execute(ContextActions.Get('stop'),context) and calls.stop==context.selection)
assert(ContextActions.Execute(ContextActions.Get('soft_stop'),context) and calls.soft_stop==context.selection)

-- Factory catalog additions remain visible to assignments and dispatch their
-- native actions; Patrol is gated by capability on an eligible factory.
local listedFactoryActions={}
for _,item in ipairs(ContextActions.List()) do listedFactoryActions[item.id]=true end
for _,id in ipairs({'patrol','upgrade_structure','upgrade_structure_pause','create_template_factory'}) do
    assert(listedFactoryActions[id] and ContextActions.Supports(id,'factory'),
        id..' is available in the Factory catalog')
end
for _,id in ipairs({'upgrade_structure','upgrade_structure_pause','create_template_factory'}) do
    assert(not ContextActions.Supports(id,'land') and not ContextActions.Supports(id,'builder'),
        id..' remains Factory-only')
end
context.selection={factory}
context.resolvedContext='factory'
context.orders={RULEUCC_Patrol=true}
factory.orders=nil
local factoryPatrol=ContextActions.Get('patrol')
assert(not ContextActions.Available(factoryPatrol,context) and not ContextActions.Execute(factoryPatrol,context),
    'Factory Patrol is unavailable without a per-factory native capability')
factory.orders={'RULEUCC_Patrol'}
local selectedBeforeFactoryPatrol=selectedForCommand
assert(ContextActions.Available(factoryPatrol,context) and ContextActions.Execute(factoryPatrol,context)
    and calls.command[1]=='order' and calls.command[2].name=='RULEUCC_Patrol',
    'Factory Patrol dispatches when the selected factory has its native capability')
assert(selectedForCommand==selectedBeforeFactoryPatrol,
    'Factory Patrol does not change the selected factory')
factory.orders=nil
for _,id in ipairs({'upgrade_structure','upgrade_structure_pause','create_template_factory'}) do
    local item=ContextActions.Get(id)
    assert(ContextActions.Available(item,context) and ContextActions.Execute(item,context)
        and calls.conexecute==item.select,
        id..' dispatches its native action without a per-unit capability requirement')
end
context.resolvedContext=nil
context.orders={}

factory.repeatQueue=true; external.repeatQueue=true; creator.repeatQueue=true
units={factory,external}
context.selection=units
assert(ContextActions.Execute(ContextActions.Get('repeat_queue'),context))
assert(not factory.repeatQueue and external.info.SetRepeatQueue=='false' and creator.info.SetRepeatQueue=='false')
assert(ContextActions.Execute(ContextActions.Get('repeat_queue'),context) and factory.repeatQueue)

units={factory}; context.selection=units; queue={'a','b','c'}
assert(not ContextActions.Supports('remove_queue','factory'),
    'retired queue removal is no longer assignable in Factory context')
assert(contextQueue.Execute(context))
assert(calls.remove[1]==3 and calls.remove[2]==5 and calls.clearqueue and refreshCount==1)
queue={}
local clearsBefore=calls.clearqueue
assert(not contextQueue.Execute(context),'empty queue reports no action')
assert(calls.clearqueue==clearsBefore+1 and refreshCount==1,'empty queue still clears display without refresh')
queue={'one'}; failQueueDecrease=true
clearsBefore=calls.clearqueue
local queueOk=pcall(contextQueue.Execute,context)
failQueueDecrease=false
assert(not queueOk and calls.clearqueue==clearsBefore+1,'queue display clears after a failed queue update')

toggles={'RULEUTC_ShieldToggle'}; units={acu}; context.selection=units
context.orders={}
assert(ContextActions.Available(ContextActions.Get('shield'),context))
assert(ContextActions.Execute(ContextActions.Get('shield'),context) and calls.toggle=='Shield')
assert(not ContextActions.Available(ContextActions.Get('stealth'),context),'toggle unavailable')
context.isReplay=true
assert(not ContextActions.Execute(ContextActions.Get('shield'),context),'toggle blocked in replay')
print('PASS: context partition, mixed selections, supported actions, mocked dispatch, availability and replay guard')
