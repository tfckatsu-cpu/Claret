table.getn=function(t) return #t end
local module=setmetatable({},{__index=_G})
assert(loadfile('../mods/ClaretHotbuild/modules/Equivalents.lua','t',module))()
local records={}
local function record(id,faction,tech,kind)
    records[id]={id=id,faction=faction,tech=tech,kind=kind,name=id}
end
record('ueb1101','UEF','T1','STRUCTURE');record('uab1101','AEON','T1','STRUCTURE')
record('ueb1301','UEF','T3','STRUCTURE');record('uab1301','AEON','T3','STRUCTURE')
record('uel0201','UEF','T1','LAND');record('url0107','CYBRAN','T1','LAND')
record('uel9999','UEF','T1','LAND')
record('uel0401','UEF','EXPERIMENTAL','LAND');record('url0402','CYBRAN','EXPERIMENTAL','LAND')
local catalog={Get=function(self,id) return records[id] end,List=function(self) local result={} for _,item in pairs(records) do result[#result+1]=item end return result end}
local equivalents=module.Create(catalog,{
    Power_Generator={'ueb1101','uab1101','ueb1301','uab1301','missing1234'},
    T1_Tank={'uel0201'},T1_Assault_Bot={'url0107'},
    MixedParent={'Power_Generator','T1_Tank','uel9999'},
    Experimental={'uel0401','url0402'},
})
assert(#equivalents:Variants('ueb1101')==2)
assert(equivalents:Variants('ueb1101')[2].id=='uab1101')
assert(equivalents:Key('ueb1101')~=equivalents:Key('ueb1301'),'never mix tech levels')
assert(#equivalents:Variants('url0107')==2,'tank role includes the faction assault bot')
assert(#equivalents:Variants('uel0401')==1,'experimentals are not interchangeable')
assert(#equivalents:Variants('uel9999')==1,'never flatten parent hotkey groups')
local ambiguous=module.Create(catalog,{Bad={'uel0201','uel9999','url0107'}})
assert(#ambiguous:Variants('url0107')==1,'ambiguous faction variants must not pick arbitrarily')
local rows=equivalents:Rows({{kind='blueprint',id='ueb1101'},{kind='blueprint',id='uab1101'},
    {kind='blueprint',id='ueb1301'},{kind='blueprint',id='ueb1101'}})
assert(#rows==3 and rows[1].last==2 and rows[2].first==3,'only adjacent equivalents collapse')
print('PASS: equivalence tiers, known role alias, missing units, unique experimentals, parent and ambiguity rejection')
record('zeb9501','UEF','T2','STRUCTURE');record('zab9501','AEON','T2','STRUCTURE')
record('ueb0201','UEF','T2','STRUCTURE');record('uab0201','AEON','T2','STRUCTURE')
local factories=module.Create(catalog,{Support={'zeb9501','zab9501'}})
assert(#factories:Variants('zeb9501')==2,'explicit support factory equivalents remain available')
assert(#factories:Variants('ueb0201')==2,'legacy HQ equivalents remain available for saved presets')
assert(factories:Key('ueb0201')~=factories:Key('zeb9501'),'HQ and Support remain separate')
print('PASS: explicit support and legacy HQ equivalents')
