-- Cross-validation rules for context tile and Hotbuild preset edits.
local testLocalization = dofile('Tests/localization-test-helper.lua')
table.getn = function(t) return #t end
local actions = setmetatable({}, {__index=_G})
actions.import = function(path)
    if path == '/mods/ClaretHotbuild/modules/ContextActions.lua' then
        local module = setmetatable({}, {__index=actions})
        assert(loadfile('../mods/ClaretHotbuild/modules/ContextActions.lua','t',module))()
        return module
    end
    error('unexpected import: '..path)
end
actions.LOC = function(text) return text end
local compatibility = setmetatable({}, {__index=actions})
assert(loadfile('../mods/ClaretHotbuild/modules/Compatibility.lua','t',compatibility))()

local records = {
    mobile = {blueprint={CategoriesHash={BUILTBYT1FACTORY=true, MOBILE=true}}},
    structure = {blueprint={Categories={'BUILTBYT2FACTORY','STRUCTURE'}}},
    engineerOnly = {kind='STRUCTURE',blueprint={CategoriesHash={BUILTBYT1ENGINEER=true, STRUCTURE=true}}},
    engineerMobile = {kind='LAND',blueprint={CategoriesHash={BUILTBYT1ENGINEER=true, MOBILE=true}}},
    template = {templateData={4,4,{'mobile',0,0,0}}},
}
local catalog = {Get=function(self,id) return records[id] end}
local selected = {id='ctx',name='Context',rows={{context='other',action='move'}}}
local contextModel = {Get=function(self,id) if id==selected.id then return selected end end}
local function binding(context, entries)
    return {id='preset',name='Preset',key='Ctrl-A',grid={context=context and 'ctx' or nil},entries=entries or {}}
end

local ok, message = compatibility.ValidateBinding(binding(true,{{kind='blueprint',id='mobile'}}),contextModel,catalog)
assert(ok and not message,'factory production alone does not lock builders')
ok, message = compatibility.ValidateBinding(binding(true,{{kind='blueprint',id='engineerOnly'}}),contextModel,catalog)
assert(ok and message,'other tile warning for any construction preset')
ok, message = compatibility.ValidateBinding(binding(true,{{kind='blueprint',id='template'}}),contextModel,catalog)
assert(ok and message,'templates count as construction presets')
ok, message = compatibility.ValidateBinding(binding(true,{{kind='action',id='move'}}),contextModel,catalog)
assert(ok and not message,'action-only preset has no construction warning')

for _, context in ipairs({'acu','sacu','engineer'}) do
    selected.rows={{context=context,action='move'}}
    ok,message=compatibility.ValidateBinding(binding(true,{{kind='blueprint',id='engineerOnly'}}),contextModel,catalog)
    assert(not ok and message:find('плитк',1,true),'rejects build preset with '..context..' tile')
end

-- The preset editor draft keeps its saved entries separate from the live grid
-- until SaveDraft rebuilds them. The compatibility badge must validate the same
-- entries that Commit receives after that rebuild.
selected.rows={{context='acu',action='move'}}
local liveGrid={context='ctx'}
local draft={id='preset',name='Preset',key='Ctrl-A',grid={context='ctx'},entries={{kind='action',id='move'}}}
ok=compatibility.ValidateBinding(draft,contextModel,catalog)
assert(ok,'saved draft entries may still be compatible before rebuilding from the live grid')
local commitCandidate={id=draft.id,name=draft.name,key=draft.key,grid=liveGrid,
    entries={{kind='blueprint',id='engineerOnly'}}}
ok,message=compatibility.ValidateBinding(commitCandidate,contextModel,catalog)
assert(not ok and message:find('ACU',1,true),
    'compatibility validation rejects the live-grid candidate that SaveDraft sends to Commit')

selected.rows={{context='builder',action='move'},{context='acu',mode='inherit'}}
ok,message,details=compatibility.ValidateBinding(binding(true,{{kind='blueprint',id='engineerOnly'}}),contextModel,catalog)
assert(not ok and message:find('Строители',1,true) and details.parent,
    'inherited parent action is reported as a parent/build conflict')
selected.rows={{context='acu',mode='disabled'}}
ok,message=compatibility.ValidateBinding(binding(true,{{kind='blueprint',id='engineerOnly'}}),contextModel,catalog)
assert(ok and not message,'disabled child has no effective action and permits a build preset')
selected.rows={{context='builder',action='move'},{context='acu',mode='disabled'},
    {context='sacu',mode='disabled'},{context='engineer',mode='disabled'}}
ok,message=compatibility.ValidateBinding(binding(true,{{kind='blueprint',id='engineerOnly'}}),contextModel,catalog)
assert(not ok and message:find('Строители',1,true),
    'parent builder assignment remains incompatible with a construction preset even when children are disabled')
selected.rows={{context='builder',action='move'},{context='acu',mode='own',action='attack'}}
ok,message,details=compatibility.ValidateBinding(binding(true,{{kind='blueprint',id='engineerOnly'}}),contextModel,catalog)
assert(not ok and message:find('ACU',1,true),'own child override remains incompatible with a build preset')
assert(details.kind=='build_context' and details.parent==true and #details.contexts==3
    and #details.ownContexts==1 and details.ownContexts[1]=='acu',
    'build conflict details separate inherited effective children from the explicit child assignment')

selected.rows={{context='acu',action='move'},{context='sacu',action='attack'},{context='engineer',action='assist'}}
ok,message,details=compatibility.ValidateBinding(binding(true,{{kind='blueprint',id='engineerOnly'}}),contextModel,catalog)
assert(not ok and message:find('ACU, SACU и Инженера',1,true),
    'build conflict message enumerates every affected builder tile')
assert(message:find('Очистите плитки ACU, SACU и Инженера',1,true),
    'multiple conflict resolution uses plural tile wording')
assert(#details.contexts==3 and details.contexts[1]=='acu' and details.contexts[2]=='sacu'
    and details.contexts[3]=='engineer','structured conflict lists all affected child contexts')
selected.rows={{context='factory',action='move'}}
ok,message,details=compatibility.ValidateBinding(binding(true,{{kind='blueprint',id='mobile'}}),contextModel,catalog)
assert(not ok and message:find('Завод',1,true),'factory-produced output rejected for factory tile')
assert(details.kind=='factory' and details.contexts[1]=='factory','factory conflict details identify the clearable tile')
ok,message=compatibility.ValidateContext(selected,{
    {id='preset',name='Preset',key='Ctrl-A',grid={context='ctx'},entries={{kind='blueprint',id='mobile'}}},
},catalog)
assert(not ok and message:find('Завод',1,true),
    'adding a factory row to an already linked factory-production preset is rejected')
ok,message=compatibility.ValidateBinding(binding(true,{{kind='blueprint',id='engineerOnly'}}),contextModel,catalog)
assert(ok and not message,'engineer-only build output is not classified as factory-produced')
selected.rows={{context='acu',action='move'}}
ok=compatibility.ValidateBinding(binding(true,{{kind='blueprint',id='engineerMobile'}}),contextModel,catalog)
assert(ok,'mobile engineer output does not lock Builders')
local linked={{id='preset',name='Preset',key='Ctrl-A',grid={context='ctx'},entries={{kind='blueprint',id='engineerOnly'}}}}
for _,id in ipairs({'builder','acu','sacu','engineer'}) do
    local warning=compatibility.GetTileWarning(id,'ctx',linked,catalog,{id='ctx',rows={}})
    assert(warning and warning:find('занято хотбилдом зданий',1,true),id..' locks even without a row')
end
assert(not compatibility.GetTileWarning('factory','ctx',linked,catalog,{id='ctx',rows={}}),'structure alone does not lock Factory')
linked[1].entries={{kind='blueprint',id='mobile'}}
assert(compatibility.GetTileWarning('factory','ctx',linked,catalog,{id='ctx',rows={}}),'factory production locks Factory')
assert(not compatibility.GetTileWarning('builder','ctx',linked,catalog,{id='ctx',rows={}}),'factory production does not lock Builders')

selected.rows={{context='acu',action='move'}}
ok,message=compatibility.ValidateContext(selected,{{id='preset',name='Preset',key='Ctrl-A',grid={context='ctx'},entries={{kind='blueprint',id='engineerOnly'}}}},catalog)
assert(not ok and message,'editing context validates existing assigned preset')
selected.rows={{context='other',action='move'}}
ok,message=compatibility.ValidateContext(selected,{{id='preset',name='Preset',key='Ctrl-A',grid={context='ctx'},entries={{kind='blueprint',id='engineerOnly'}}}},catalog)
assert(ok and message and message:find('Предупреждение',1,true),'context edit propagates nonblocking warning')
selected.rows={{context='other',action='move'},{context='acu',action='move'}}
ok,message=compatibility.ValidateContext(selected,{
    {id='warn',name='Warning',key='',grid={context='ctx'},entries={{kind='blueprint',id='engineerOnly'}}},
    {id='blocked',name='Blocked',key='',grid={context='ctx'},entries={{kind='blueprint',id='engineerOnly'}}},
},catalog)
assert(not ok and message:find('ACU',1,true),'context edit continues past warning to detect later conflict')
selected.absolute=true
selected.name='Absolute composite'
ok,message,details=compatibility.ValidateBinding(binding(true,{{kind='action',id='move'}}),contextModel,catalog)
assert(not ok and message:find('абсолютный',1,true) and details.kind=='absolute_link',
    'Hotbuild cannot link to an absolute composite')
ok,message,details=compatibility.ValidateContext(selected,{
    {id='linkedA',name='Linked A',key='Ctrl-A',grid={context='ctx'},entries={}},
    {id='linkedB',name='Linked B',key='',grid={context='ctx'},entries={}},
},catalog)
assert(not ok and message:find('Linked A',1,true) and message:find('Linked B',1,true)
    and message:find('Ctrl-A',1,true) and details.kind=='absolute_link' and #details.bindings==2,
    'switching a linked composite to absolute reports every Hotbuild and assigned key')
print('PASS: context/preset compatibility gates and warning cases')
