-- Single-unit enhancement actions with mocked FAF queue callbacks.
table.getn = function(t) return #t end

local selected, unitsById, queue, installed, restricted, issued = {}, {}, {}, {}, {}, {}
local function enhancement(slot, prerequisite)
    return {Slot=slot, Prerequisite=prerequisite}
end
local function unit(id, category, enhancements)
    local u={id=id,category=category,bp={BlueprintId=id,Enhancements=enhancements}}
    function u:IsDead() return false end
    function u:IsInCategory(name) return self.category==name end
    function u:GetBlueprint() return self.bp end
    function u:GetEntityId() return self.id end
    unitsById[id]=u
    return u
end

local acuEnhancements={
 AdvancedEngineering=enhancement('Engineering'), T3Engineering=enhancement('Engineering','AdvancedEngineering'),
 ResourceAllocation=enhancement('Ras'), ResourceAllocationAdvanced=enhancement('Ras','ResourceAllocation'),
 Teleporter=enhancement('Tele'), CoolingUpgrade=enhancement('Gun'), HeavyAntiMatterCannon=enhancement('Gun'),
 RateOfFire=enhancement('Gun'), HeatSink=enhancement('Gun'), MicrowaveLaserGenerator=enhancement('Special'),
 TacticalNukeMissile=enhancement('Special'), BlastAttack=enhancement('Special'), ChronoDampener=enhancement('Special'),
 StealthGenerator=enhancement('Nano'), CloakingGenerator=enhancement('Nano','StealthGenerator'),
 Shield=enhancement('Nano'), ShieldGeneratorField=enhancement('Nano','Shield'),
 DamageStabilization=enhancement('Nano'), DamageStabilizationAdvanced=enhancement('Nano','DamageStabilization'),
 ShieldHeavy=enhancement('Nano','Shield'),
}
local sacuEnhancements={
 Switchback=enhancement('Engineering'), Pod=enhancement('Engineering'),
 EngineeringThroughput=enhancement('Engineering'), EngineeringFocusingModule=enhancement('Engineering'),
}
local acu=unit('uel0001','COMMAND',acuEnhancements)
local sacu=unit('uel0301','SUBCOMMANDER',sacuEnhancements)
local other=unit('uel0101','ENGINEER',{})

local queueModule={getEnhancementQueue=function() return queue end}
local commonModule={
 GetEnhancements=function(id) return installed[id] or {} end,
 GetRestricted=function() return restricted end,
}
local module
local environment=setmetatable({
 import=function(path)
  if path=='/lua/enhancementcommon.lua' then return commonModule end
  if path=='/lua/ui/notify/enhancementqueue.lua' then return queueModule end
  if path=='/mods/ClaretHotbuild/modules/ContextEnhancements.lua' then return module end
  error('unexpected import '..path)
 end,
 GetSelectedUnits=function() return selected end,
 IssueCommand=function(kind, params, clear)
  issued[#issued+1]={kind=kind,params=params,clear=clear}
  assert(kind=='UNITCOMMAND_Script' and clear==false)
  local unit=selected[1]
  local entry=unit.bp.Enhancements[params.Enhancement]
  local perUnit=queue[unit.id] or {}; queue[unit.id]=perUnit
  perUnit[#perUnit+1]=entry
 end,
}, {__index=_G})
module=setmetatable({}, {__index=environment})
assert(loadfile('../mods/ClaretHotbuild/modules/ContextEnhancements.lua','t',module))()
local function context(unit, selection, replay, army)
 return {selection=selection or {unit},isReplay=replay or false,focusArmy=army or 1}
end

selected={acu}; local c=context(acu)
assert(module.Available('acu_tech',c))
assert(module.Execute('acu_tech',c) and issued[#issued].params.Enhancement=='AdvancedEngineering')
assert(module.Available('acu_tech',c),'queued prerequisite advances chain')
assert(module.Execute('acu_tech',c) and issued[#issued].params.Enhancement=='T3Engineering')
assert(not module.Available('acu_tech',c),'queued target is not duplicated')

queue[acu.id]={}; installed[acu.id]={Engineering='AdvancedEngineering'}
assert(module.Execute('acu_tech',c) and issued[#issued].params.Enhancement=='T3Engineering','installed prerequisite advances chain')
queue[acu.id]={acuEnhancements.AdvancedEngineering}; installed[acu.id]={Engineering='AdvancedEngineering'}
assert(module.Available('acu_tech',c),'installed prerequisite may remain represented in the enhancement queue')
assert(module.Execute('acu_tech',c) and issued[#issued].params.Enhancement=='T3Engineering','queued-after-installed chain appends in order')
queue[acu.id]={acuEnhancements.AdvancedEngineering,acuEnhancements.T3Engineering}
assert(not module.Available('acu_tech',c),'target already queued after installed prerequisite is blocked')
queue[acu.id]={}; installed[acu.id]={Engineering='UnrelatedEngineering'}
assert(not module.Available('acu_tech',c),'incompatible installed slot blocks action')
installed[acu.id]={}; queue[acu.id]={acuEnhancements.Teleporter}
assert(not module.Available('acu_tele',c),'already queued target is blocked')
queue[acu.id]={}; restricted.Teleporter=true
assert(not module.Available('acu_tele',c),'restricted enhancement blocked')
restricted={AdvancedEngineering=true}; queue[acu.id]={acuEnhancements.AdvancedEngineering}; installed[acu.id]={}
assert(not module.Available('acu_tech',c),'restricted queued prerequisite blocks continuation')
restricted={}

local map={acu_gun='HeavyAntiMatterCannon',acu_special='TacticalNukeMissile',acu_nano='Shield',acu_tele='Teleporter'}
for action, expected in pairs(map) do
 queue[acu.id]={}; installed[acu.id]={}
 assert(module.Available(action,c),action..' has blueprint candidate')
 assert(module.Execute(action,c) and issued[#issued].params.Enhancement==expected,action..' exact faction mapping')
end
queue[acu.id]={}; installed[acu.id]={}
assert(module.Execute('acu_nano',c) and issued[#issued].params.Enhancement=='Shield')
assert(module.Available('acu_nano',c),'nano queued prerequisite advances to second tier')
assert(module.Execute('acu_nano',c) and issued[#issued].params.Enhancement=='ShieldGeneratorField')
assert(not module.Available('acu_nano',c),'nano target is not repeated')

selected={sacu}; local sc=context(sacu)
assert(module.Available('sacu_tech',sc))
assert(module.Execute('sacu_tech',sc) and issued[#issued].params.Enhancement=='Pod')
assert(not module.Available('sacu_tech',sc),'SACU enhancement is not repeated')

assert(not module.Available('acu_tech',context(acu,{acu,other})))
assert(not module.Available('acu_tech',context(acu,{acu},true)))
assert(not module.Available('acu_tech',context(acu,{acu},false,-1)))
selected={other}
assert(not module.Available('acu_tech',context(other)))
selected={acu}
assert(not module.Available('sacu_tech',context(acu)))
assert(not module.Available('sacu_tech',context(sacu)),'selection mismatch blocks command')

-- Exercise the public dispatch path used by context bindings.
local actions=setmetatable({}, {__index=environment})
assert(loadfile('../mods/ClaretHotbuild/modules/ContextActions.lua','t',actions))()
queue[acu.id]={}; installed[acu.id]={}; selected={acu}; local integrationContext=context(acu)
local registered=actions.Get('acu_tech')
assert(registered and registered.special=='enhancement' and actions.Supports('acu_tech','acu'))
assert(actions.Available(registered,integrationContext))
assert(actions.Execute(registered,integrationContext))
assert(issued[#issued].params.Enhancement=='AdvancedEngineering','ContextActions dispatches enhancement execution')
assert(actions.Available(registered,integrationContext),'ContextActions availability advances from queued prerequisite')
assert(actions.Execute(registered,integrationContext))
assert(issued[#issued].params.Enhancement=='T3Engineering','ContextActions dispatches the queued follow-up')
assert(not actions.Available(registered,integrationContext),'ContextActions blocks queued target repetition')
print('PASS: exact ACU/SACU maps, prerequisites, installed and queued state, restrictions, single-selection guard and append-only queue')
