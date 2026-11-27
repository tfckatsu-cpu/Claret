-- Saved construction templates: stable identity, data validation, grid roundtrip and placement.
local testLocalization = dofile('Tests/localization-test-helper.lua')
table.getn=function(t) return #t end
math.mod=math.fmod
local function module(file,env)
    env=setmetatable(env or {},{__index=_G})
    assert(loadfile('../mods/ClaretHotbuild/modules/'..file..'.lua','t',env))()
    return env
end
local records={
    a={id='a',name='Generator',faction='UEF',tech='T1',kind='STRUCTURE',icon='iconA',blueprint={}},
    b={id='b',name='Shield',faction='UEF',tech='T2',kind='STRUCTURE',icon='iconB',blueprint={}},
    c={id='c',name='Aeon',faction='AEON',tech='T1',kind='STRUCTURE',icon='iconC',blueprint={}},
}
local base={Get=function(self,id) return records[id] end,List=function() return {} end,
    DisplayName=function(self,name) return 'Переименовано: '..name end}
local source={{name='Мой шаблон',templateData={4,6,{'a',0,1.5,-2},{'b',0,-1.5,2}}}}
local templates=module('TemplateCatalog').Create(base,function() return source end)
assert(templates:DisplayName('Авиазавод','ueb0102',{})=='Переименовано: Авиазавод',
    'template catalog must forward display-name normalization to the blueprint catalog')
local list=templates:List({kind='STRUCTURE',faction='UEF',search='ШАБЛОН'})
assert(#list==1 and list[1].tech=='T2' and list[1].templateData[3][3]==1.5)
local id=list[1].id
assert(templates:Get(id).name=='Мой шаблон')
source[1].name='Переименован'
source[2]=source[1]; templates:RefreshTemplates()
assert(#templates:List({})==1 and templates:Get(id).name=='Переименован','rename and duplicate must preserve identity')
assert(#templates:List({faction='AEON'})==0 and #templates:List({kind='AIR'})==0)
local model=module('Model').Create()
local binding={id='b1',name='Template',key='',entries={{kind='blueprint',id=id}},
    grid={buildings={{UEF=id}},units={LAND={},AIR={},NAVAL={}}}}
assert(model:Put(binding))
local saved=module('Model').Create(model:Export())
assert(saved:Get('b1').grid.buildings[1].UEF==id)
local selected,active,mode={},nil,nil
local function unit(buildable,factory)
    return {buildable=buildable,IsDead=function() return false end,
        IsInCategory=function(self,category)
            if factory then return category=='FACTORY' end
            return category=='ENGINEER'
        end}
end
local env={
    GetSelectedUnits=function() return selected end,GetFocusArmy=function() return 1 end,
    GetUnitCommandData=function(units) return {},{},units[1].buildable end,
    EntityCategoryGetUnitList=function(category) return category end,
    ClearBuildTemplates=function() active=nil end,
    SetActiveBuildTemplate=function(data) active=data end,
    import=function(path)
        assert(path=='/lua/ui/game/commandmode.lua')
        return {StartCommandMode=function(name,data) mode={name,data} end}
    end,
}
local adapter=module('Adapter',env).Create(templates)
selected={unit({'a','b'},false)}
local context=adapter:Context(false)
assert(adapter:CanBuild(id,context) and adapter:Build(id,context))
assert(mode[1]=='build' and mode[2].name=='a' and mode[2].claretEntry==id)
assert(active[1]==4 and active[2]==6 and active[3][1]=='a' and active[3][3]==1.5 and active[4][4]==2)
active[3][3]=99
assert(templates:Get(id).templateData[3][3]==1.5,'engine must not mutate catalog template')
selected={unit({'a'},false),unit({'b'},false)}
assert(not adapter:CanBuild(id,adapter:Context(false)),'one engineer must be capable of the whole template')
selected={unit({'a','b'},true)}
assert(not adapter:CanBuild(id,adapter:Context(false)),'factory is not a template placer')
selected={unit({'a','b'},false)}
assert(not adapter:CanBuild(id,adapter:Context(true)),'replay guard')
source={}; templates:RefreshTemplates(); assert(not templates:Get(id))
assert(not adapter:CanBuild(id,adapter:Context(false)),'removed template must not target another list slot')
source={{name='',templateData={4,6,{'a',0,0,0}}},
    {name='bad coordinate',templateData={4,6,{'a',0,0/0,0}}},
    {name='mixed factions',templateData={4,6,{'a',0,0,0},{'c',0,1,1}}},
    {name='unknown',templateData={4,6,{'unknown',0,0,0}}},
    {name='executable value',templateData={4,6,{'a',function() error('never run') end,0,0}}},
}
templates:RefreshTemplates()
assert(#templates:List({})==1 and templates:List({})[1].name=='Шаблон a')
print('PASS: saved templates stable identity, UTF-8 search, filters, malformed data, grid persistence, complete engineer capability, geometry copy and deletion guard')

-- Complete faction conversion preserves geometry, source IDs and shared row identity.
local all,groups={}, {Power={},Shield={}}
for index,faction in ipairs({'UEF','AEON','CYBRAN','SERAPHIM'}) do
    for _,part in ipairs({'Power','Shield'}) do
        local blueprint=string.lower(part)..index
        all[blueprint]={id=blueprint,name=part,faction=faction,tech='T2',kind='STRUCTURE',icon=blueprint,blueprint={}}
        table.insert(groups[part],blueprint)
    end
end
local factionBase={Get=function(self,id) return all[id] end,List=function() return {} end}
local equivalence=module('Equivalents')
local convertedModule=module('TemplateCatalog',{import=function(path)
    assert(path=='/mods/ClaretHotbuild/modules/Equivalents.lua'); return equivalence
end})
local original={name='Power + shield',templateData={8,8,{'power1',0,2,-2},{'shield1',1,-2,2}}}
local factionSource={original}
local converted=convertedModule.Create(factionBase,function() return factionSource end,groups)
local originalId
local plain=module('TemplateCatalog').Create(factionBase,function() return factionSource end)
originalId=plain:List({})[1].id
assert(converted:Get(originalId),'old template ID must stay valid')
local eq=equivalence.Create(converted,groups)
local combined=module('UnitTemplateCatalog').Create(converted,function() return {} end)
local combinedEq=equivalence.Create(combined,groups)
assert(#combinedEq:Variants(originalId)==4, 'the runtime catalog exposes all building template variants')
assert(combinedEq:Key(originalId)==eq:Key(originalId), 'the runtime catalog preserves template family identity')
local variants=eq:Variants(originalId)
assert(#variants==4)
for _,variant in ipairs(variants) do
    assert(eq:Key(variant.id)==eq:Key(originalId))
    assert(variant.templateData[3][3]==2 and variant.templateData[4][2]==1 and variant.templateData[4][4]==2)
    assert(all[variant.templateData[3][1]].faction==variant.faction)
    assert(all[variant.templateData[4][1]].faction==variant.faction)
end
assert(original.templateData[3][1]=='power1' and #factionSource==1,'conversion must not edit saved templates')
local aeon=converted:List({faction='AEON'})[1]
selected={unit({'power2','shield2'},false)}
local convertedAdapter=module('Adapter',env).Create(converted)
assert(convertedAdapter:Build(aeon.id,convertedAdapter:Context(false)))
assert(active[3][1]=='power2' and active[4][1]=='shield2' and active[3][3]==2)
assert(mode[2].claretEntry==aeon.id)
all.shield4=nil
converted:RefreshTemplates()
assert(#eq:Variants(originalId)==3 and #converted:List({faction='SERAPHIM'})==0,'partial conversions must be unavailable')
-- Ambiguous target groups must not produce guessed conversions.
all.shield3extra={id='shield3extra',name='Other shield',faction='CYBRAN',tech='T2',kind='STRUCTURE',icon='x',blueprint={}}
table.insert(groups.Shield,'shield3extra')
local ambiguous=convertedModule.Create(factionBase,function() return factionSource end,groups)
assert(#ambiguous:TemplateVariants(originalId)==1)
factionSource={}; converted:RefreshTemplates(); assert(not converted:Get(originalId))
print('PASS: complete four-faction template conversion, stable old IDs, row equivalents, geometry, source immutability, missing/ambiguous mappings and source deletion')
