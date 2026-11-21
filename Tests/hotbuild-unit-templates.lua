-- Saved factory queue templates: stable identity, validation, conversion and queue dispatch.
table.getn=table.getn or function(t) return #t end
math.mod=math.fmod
-- Localized template text is data for the catalog: provide the shipped labels.
_G.ReUI={ClaretCore={Localization={Text=function(key)
    local map={['hotbuild.templates.s001']='Шаблон ',['hotbuild.templates.s005']='Шаблон юнитов · ',
        ['hotbuild.templates.s006']=' юнитов',['hotbuild.templates.s007']=' шаблон юнитов'}
    return map[key] or key
end}}}
local function module(file,env)
    env=setmetatable(env or {},{__index=_G})
    assert(loadfile('../mods/ClaretHotbuild/modules/'..file..'.lua','t',env))()
    return env
end

local function unit(id,name,faction,tech,kind,upgradesFrom)
    local blueprint={}
    if upgradesFrom then blueprint.General={UpgradesFrom=upgradesFrom} end
    return {id=id,name=name,faction=faction,tech=tech,kind=kind,icon='icon_'..id,blueprint=blueprint}
end

local units={
    uel0101=unit('uel0101','Tank','UEF','T1','LAND'),
    uel0102=unit('uel0102','Mobile AA','UEF','T1','LAND'),
    uel0202=unit('uel0202','Heavy tank','UEF','T2','LAND'),
    ueb0201=unit('ueb0201','Land factory T2','UEF','T2','STRUCTURE','ueb0101'),
    ueb0101=unit('ueb0101','Land factory','UEF','T1','STRUCTURE'),
    ual0101=unit('ual0101','Aeon tank','AEON','T1','LAND'),
    ual0102=unit('ual0102','Aeon AA','AEON','T1','LAND'),
    uaa0101=unit('uaa0101','Interceptor','UEF','T1','AIR'),
}
local base={
    Get=function(self,id) return units[id] end,
    List=function() return {} end,
    DisplayName=function(self,name) return name end,
}

local source={{name='Мой отряд',templateData={{id='uel0101',count=2},{id='uel0102',count=1}}}}
local catalog=module('UnitTemplateCatalog').Create(base,function() return source end)
local list=catalog:List({kind='LAND',faction='UEF',search='ШАБЛОН ЮНИТОВ'})
assert(#list==1,'queue template must be listed for its unit row and searchable by its localized kind')
local record=list[1]
local id=record.id
assert(record.unitTemplate and record.templateData==nil,'queue templates must not look like placement geometry')
assert(record.tech=='T1' and record.unitCount==3 and table.getn(record.queueData)==2)
assert(record.queueData[1][1]=='uel0101' and record.queueData[1][2]==2 and record.queueData[1][3]==false)
assert(string.find(record.search,'мой отряд',1,true)~=nil,'search must fold the saved Russian name')
assert(catalog:Get(id).name=='Мой отряд')
source[1].name='Другой отряд'
catalog:RefreshTemplates()
assert(catalog:Get(id) and catalog:Get(id).name=='Другой отряд','renaming must preserve identity')
assert(#catalog:List({kind='AIR'})==0 and #catalog:List({faction='AEON'})==0)
assert(catalog:Get('uel0101').kind=='LAND','plain units stay available through the wrapper')

-- Identity follows composition, order and counts, never the name or list position.
source[1].templateData[1].count=3
catalog:RefreshTemplates()
local changed=catalog:List({})[1]
assert(changed.id~=id and changed.unitCount==4,'changed counts must produce a new identifier')
assert(not catalog:Get(id),'the old identifier must not resolve')

-- Invalid saved queues are rejected as data, never executed or guessed.
source={
    {name='mixed factions',templateData={{id='uel0101',count=1},{id='ual0101',count=1}}},
    {name='plain structure',templateData={{id='ueb0101',count=1}}},
    {name='zero count',templateData={{id='uel0101',count=0}}},
    {name='unknown unit',templateData={{id='nope',count=1}}},
    {name='executable count',templateData={{id='uel0101',count=function() error('never run') end}}},
    {name='mixed kinds',templateData={{id='uel0101',count=1},{id='uaa0101',count=1}}},
}
catalog:RefreshTemplates()
assert(#catalog:List({})==0,'malformed queue templates must be ignored')

-- A queue may start with a factory upgrade; the tier comes from the whole queue.
source={{name='',templateData={{id='ueb0201',count=1},{id='uel0202',count=2}}}}
catalog:RefreshTemplates()
local chained=catalog:List({})[1]
assert(chained and chained.tech=='T2' and chained.unitCount==3)
assert(chained.queueData[1][3]==true and chained.queueData[2][3]==false,'upgrade entries are marked as data')
assert(chained.queueData[1][1]=='ueb0201' and chained.icon=='/icons/units/uel0202_icon.dds',
    'a default name and icon come from the first unit in the queue')

-- Adapter: one capable factory queues the whole composition in saved order.
local selected,commands,modes,transaction={},{},{},{}
local refreshes,ignoreSelection=0,false
local function factory(unitId,buildable,template)
    local box=template or {}
    box.buildable=buildable or {}
    box.IsDead=function() return false end
    box.IsInCategory=function(self,category)
        return category=='FACTORY' or (not unitId and category=='ENGINEER')
    end
    return box
end
local env={
    GetSelectedUnits=function() return selected end,
    GetFocusArmy=function() return 1 end,
    GetUnitCommandData=function(units) return {},{},units[1].buildable end,
    EntityCategoryGetUnitList=function(category) return category end,
    IsKeyDown=function() return false end,
    SelectUnits=function(list) table.insert(transaction,'select'); selected=list end,
    IssueBlueprintCommand=function(kind,unitId,count) table.insert(transaction,'issue'); table.insert(commands,{kind,unitId,count}) end,
    ClearBuildTemplates=function() end,
    import=function(path)
        if path=='/lua/ui/game/construction.lua' then return {RefreshUI=function() refreshes=refreshes+1 end, GetCurrentTechTab=function() return 1 end} end
        if path=='/lua/ui/game/commandmode.lua' then return {
            StartCommandMode=function(kind,data) table.insert(modes,{kind=kind,name=data.name}) end,
            CacheAndClearCommandMode=function() table.insert(transaction,'cache') end,
            RestoreCommandMode=function() table.insert(transaction,'restoreMode') end,
        } end
        if path=='/lua/ui/game/gamemain.lua' then return {SetIgnoreSelection=function(value)
            ignoreSelection=value; table.insert(transaction,value and 'ignoreOn' or 'ignoreOff')
        end} end
        error('Unexpected import: '..path)
    end,
}
local adapter=module('Adapter',env).Create(catalog)
source={{name='Tank + AA',templateData={{id='uel0101',count=2},{id='uel0102',count=1}}}}
catalog:RefreshTemplates()
local templateId=catalog:List({})[1].id
selected={factory(nil,{'uel0101','uel0102'})}
local context=adapter:Context(false)
assert(adapter:CanBuild(templateId,context),'a factory that can build every member accepts the template')
assert(adapter:Build(templateId,context))
assert(#commands==2 and commands[1][1]=='UNITCOMMAND_BuildFactory' and commands[1][2]=='uel0101' and commands[1][3]==2)
assert(commands[2][2]=='uel0102' and commands[2][3]==1,'saved order and counts are kept')
assert(#modes==0,'no placement mode for a queue template')
assert(refreshes==1,'the construction panel refreshes once')
assert(table.concat(transaction,',')=='issue,issue','a full factory selection needs no selection transaction')

-- Shift never multiplies saved counts: the template queues exactly its composition.
commands={}
local shiftContext=adapter:Context(false); shiftContext.shiftHeld=true
assert(adapter:Build(templateId,shiftContext))
assert(#commands==2 and commands[1][3]==2 and commands[2][3]==1,'shift must not repeat unit template members')

-- One missing member makes the whole template unavailable.
selected={factory(nil,{'uel0101'})}
assert(not adapter:CanBuild(templateId,adapter:Context(false)))

-- A mixed selection is reduced to its factories, then restored.
commands,transaction={},{}
selected={factory(nil,{'uel0101','uel0102'}),factory(nil,nil,{FACTORY=false})}
selected[2].IsInCategory=function(self,category) return category=='ENGINEER' end
selected[2].buildable={'uel0101','uel0102'}
local original=selected
local mixed=adapter:Context(false)
assert(adapter:Build(templateId,mixed))
assert(#commands==2 and selected==original and ignoreSelection==false)
assert(table.concat(transaction,',')=='cache,ignoreOn,select,issue,issue,select,ignoreOff,restoreMode',
    'every restoration step runs for queue templates')

local function domainFactory(domain, faction, buildable)
    local result=factory(nil,buildable)
    function result:IsInCategory(category) return category=='FACTORY' or category==domain end
    function result:GetBlueprint() return {General={FactionName=faction}} end
    return result
end
local landFactory=domainFactory('LAND','UEF',{'uel0101','uel0102'})
commands={}
for _, mismatch in ipairs({domainFactory('AIR','UEF',{}),domainFactory('LAND','Aeon',{})}) do
    selected={landFactory,mismatch}
    local selection = adapter:Context(false)
    assert(not adapter:Build(templateId,selection) and not adapter:Build('uel0101',selection)
        and #commands==0, 'mixed factory domains and factions block unit orders')
end
selected={landFactory,domainFactory('LAND','UEF',{'uel0101','uel0102'})}
assert(adapter:Build(templateId,adapter:Context(false)) and #commands==2,
    'same-domain, same-faction factories still accept queue templates')
assert(adapter:Build('uel0101',adapter:Context(false)) and #commands==3,
    'same-domain, same-faction factories still accept unit presets')

-- A queue that starts with a factory upgrade is valid for the earlier factory.
selected={factory(nil,{'ueb0201'})}
local chainedId
source={{name='Chain',templateData={{id='ueb0201',count=1},{id='uel0202',count=1}}}}
catalog:RefreshTemplates()
chainedId=catalog:List({})[1].id
commands={}
assert(adapter:CanBuild(chainedId,adapter:Context(false)),'a leading upgrade makes later tiers queueable')
assert(adapter:Build(chainedId,adapter:Context(false)))
assert(#commands==2 and commands[2][2]=='uel0202')

-- Replays and incapable factories never receive queue orders.
commands={}
assert(not adapter:CanBuild(chainedId,adapter:Context(true)))
assert(#commands==0)

-- Queue templates are faction-bound: no cross-faction records are generated.
source={{name='Both',templateData={{id='uel0101',count=2},{id='uel0102',count=1}}}}
catalog:RefreshTemplates()
local boundId=catalog:List({faction='UEF'})[1].id
assert(#catalog:List({faction='AEON'})==0 and #catalog:List({faction='CYBRAN'})==0,
    'a queue template must not fill other factions')
assert(#catalog:List({faction='UEF'})==1 and catalog:Get(boundId).faction=='UEF')
assert(#catalog:List({})==1,'one saved queue is one record')

print('PASS: queue template identity, validation, upgrade chains, dispatch counts, saved counts under shift, mixed-selection transaction and faction-bound listings')
