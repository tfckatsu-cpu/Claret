-- Independent model tests. No game globals or executable command strings.
table.getn = table.getn or function(t) return #t end
local module = setmetatable({}, { __index = _G })
assert(loadfile('../mods/ClaretHotbuild/modules/Model.lua', 't', module))()
assert(module.NormalizeKey(' shift - ctrl - e ') == 'Ctrl-Shift-E')
assert(module.NormalizeKey('Alt-F12') == 'Alt-F12')
assert(module.NormalizeKey('') == '')
assert(not module.NormalizeKey('Ctrl-Ctrl-E'))
assert(not module.NormalizeKey('Ctrl-F13'))
assert(not module.NormalizeKey('E; LOG(1)'))
assert(not module.NormalizeKey('F01'))

local m = module.Create()
local binding = { id = 'scout', name = 'Scout', key = 'e', entries = {
    { kind = 'action', id = 'future.action' },
    { kind = 'blueprint', id = 'UEA0101' },
    { kind = 'action', id = 'context.fallback' },
} }
assert(m:Put(binding))
binding.entries[2].id = 'changed'
assert(m:Get('scout').entries[2].id == 'uea0101')
local got = m:Get('scout'); got.name = 'mutated'
assert(m:Get('scout').name == 'Scout')
assert(not m:Put({ id = 'other', name = 'Other', key = 'E', entries = {} }))
assert(m:Put({ id = 'other', name = 'Other', key = '', entries = {} }))
assert(not m:Put({ id = 'invalid', name = 'Bad', key = 'Q', entries = {{kind='command',id='script'}} }))
assert(not m:Put({ id = 'sparse', name = 'Sparse', key = 'Q', entries = {[2]={kind='action',id='a'}} }))
local executions = {}
local context = { buildable = true, selected = true }
local adapter = {
    CanBuild = function(self, id, ctx) return ctx.buildable and id == 'uea0101' end,
    Build = function(self, id, ctx) table.insert(executions, id) end,
}
assert(m:RegisterAction({id='context.fallback',label='Context fallback', available=function(ctx) return ctx.selected end,
    execute=function(ctx) table.insert(executions,'fallback') end}))
assert(not m:RegisterAction({id='context.fallback',label='Duplicate',execute=function() end}))
assert(m:Execute('scout', context, adapter))
assert(table.concat(executions, ',') == 'uea0101')
context.buildable = false
assert(m:Execute('scout', context, adapter))
assert(table.concat(executions, ',') == 'uea0101,fallback')
context.selected = false
assert(not m:Execute('scout', context, adapter))
-- Registering a future action later makes the saved reference immediately usable.
assert(m:RegisterAction({ id='future.action',label='A future action',execute=function() table.insert(executions,'future') end }))
assert(m:Execute('scout', context, adapter))
assert(executions[3] == 'future')
local action = m:GetAction('future.action'); action.label='mutated'
assert(m:GetAction('future.action').label == 'A future action')
assert(m:ListActions()[1].id == 'future.action')

local saved = m:Export()
assert(saved.version == 1 and saved.bindings[1].entries[1].id == 'future.action')
saved.bindings[1].name = 'external'
assert(m:Get('scout').name == 'Scout')
local restored = module.Create(m:Export())
assert(restored:Get('scout').key == 'E' and not restored:GetAction('future.action'))
assert(restored:Delete('other') and not restored:Delete('other'))
assert(not module.Create('bad'):Get('scout'))
assert(#module.Create({version=99,bindings={}}):GetLoadWarnings() == 1)
assert(#module.Create({version=1,bindings={unexpected=true}}):GetLoadWarnings() == 1)
local corrupt = module.Create({version=1,bindings={
    {id='a',name='First',key='Q',entries={}},
    {id='a',name='Duplicate',key='W',entries={}},
    {id='b',name='Conflicting',key='Q',entries={}},
    {id='c',name='Valid',key='R',entries={}},
}})
assert(#corrupt:List() == 2 and #corrupt:GetLoadWarnings() == 2)
assert(corrupt:Get('a').name == 'First' and corrupt:Get('c').key == 'R')

-- Errors stop processing; never fall through to another action unexpectedly.
local bad = module.Create()
assert(bad:RegisterAction({id='bad',label='Bad',execute=function() error('expected') end}))
local lowerRan = false
assert(bad:RegisterAction({id='lower',label='Lower',execute=function() lowerRan=true end}))
assert(bad:Put({id='badbind',name='Bad bind',key='B',entries={{kind='action',id='bad'},{kind='action',id='lower'}}}))
local success, message = bad:Execute('badbind', {}, {})
assert(not success and string.find(message,'Action failed') and not lowerRan)
local capped = module.Create()
for i=1,64 do assert(capped:Put({id='b'..i,name='Bind '..i,key='',entries={}})) end
assert(not capped:Put({id='overflow',name='Overflow',key='',entries={}}))
print('PASS: Hotbuild model normalization, priorities, context actions, unknown references, cloning, corrupt saves, conflicts, limits, error isolation')
