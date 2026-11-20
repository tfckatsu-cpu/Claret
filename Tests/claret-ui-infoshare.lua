table.getn = table.getn or function(values) return #values end
local env = setmetatable({}, { __index = _G })
local beat, receive, rendered
local time = 0
local sync, packets, callbacks = {}, {}, {}
local smd = { BlueprintId = 'ueb4302', CategoriesHash = { STRUCTURE = true, TECH3 = true, ANTIMISSILE = true, SILO = true } }
local exp = { BlueprintId = 'uel0401', CategoriesHash = {}, TechCategory = 'EXPERIMENTAL' }
local armies = {
    { human = true, nickname = 'Self', authorizedCommandSources = { 1 } },
    { human = true, nickname = 'Ally', authorizedCommandSources = { 2 } },
    { human = true, nickname = 'Enemy', authorizedCommandSources = { 3 } },
}
local fraction = 0.42
local unit = {
    IsDead = function() return false end, GetArmy = function() return 1 end,
    GetEntityId = function() return 11 end, GetBlueprint = function() return smd end,
    GetFractionComplete = function() return fraction end, GetPosition = function() return { 1, 2, 3 } end,
}
local game = {
    OriginalFocusArmy = 1,
    ObserveSelection = { AddObserver = function() end },
    RegisterChatFunc = function(callback) receive = callback end,
    AddBeatFunction = function(callback) beat = callback end,
    RemoveBeatFunction = function() beat = nil end,
}
env.import = function(path)
    if path == '/lua/ui/game/gamemain.lua' then return game end
    assert(path == '/mods/ClaretUI/modules/InfoShareDisplay.lua')
    return { Create = function()
        return { Render = function(_, rows) rendered = rows end }
    end }
end
env.ReUI = { ClaretCore = { Localization = { Text = function(key)
    if key == 'claretui.notifications.upgrade.Shield' then return 'Персональный щит — готов.' end
    return key
end } } }
env.UnitData = { ['11'] = {} }
env.__blueprints = { ueb4302 = smd, uel0401 = exp }
env.LOC = function(text) return text end
env.GetUnitById = function(id) if id == 11 then return unit end end
env.GetFocusArmy = function() return 1 end
env.GetArmiesTable = function() return { armiesTable = armies } end
env.GetSelectedUnits = function() return {} end
env.GetSystemTimeSeconds = function() return time end
env.GetGameTimeSeconds = env.GetSystemTimeSeconds
env.IsAlly = function(a, b) return a == 1 and b == 2 end
env.GetSessionClients = function()
    return {
        { connected = true, authorizedCommandSources = { 1 } },
        { connected = true, authorizedCommandSources = { 2 } },
        { connected = true, authorizedCommandSources = { 3 } },
        { connected = true, authorizedCommandSources = { 4 } },
    }
end
env.SessionSendChatMessage = function(clients, packet)
    assert(table.concat(clients, ',') == '2', 'Only the allied player receives InfoShare packets')
    table.insert(packets, packet)
end
env.AddOnSyncHashedCallback = function(callback, key) sync[key] = callback end
env.RemoveOnSyncHashedCallback = function(key) sync[key] = nil end

local scope = {
    Bind = function(_, event, callback) callbacks[event] = callback end,
    Defer = function() end,
}
local function Option(value)
    local option = { OnChanged = {} }
    function option:Get() return value end
    function option:Set(nextValue)
        value = nextValue
        callbacks[self.OnChanged]()
    end
    return option
end
local options = {}
for _, name in ipairs({ 'Own', 'Allies', 'Smd', 'Experimental', 'Acu', 'SendSmd', 'SendExperimental', 'SendAcu' }) do
    options['infoShare' .. name] = Option(true)
end
for _, name in ipairs({ 'List', 'World' }) do options['infoShare' .. name] = Option(false) end
local function Advance(seconds)
    time = time + seconds
    if beat then beat() end
end
local function Latest() return packets[table.getn(packets)] end

assert(loadfile('../mods/ClaretUI/modules/features/InfoShare.lua', 't', env))()
env.Start(env, scope, false, options)
assert(beat and Latest().rows[1].progress == 42 and Latest().rows[1].position[3] == 3)
assert(rendered == nil, 'Automatic sharing works with both HUD modes disabled')
options.infoShareList:Set(true)
assert(rendered[1].status == '42%')
options.infoShareList:Set(false)
fraction = 1
Advance(2)
assert(Latest().rows[1].phase == 'done')
Advance(1.5)
assert(table.getn(Latest().rows) == 0, 'Expired results are cleared for allies immediately')
options.infoShareList:Set(true)
local packet = { version = 1, sequence = 1, enabled = { smd = true }, rows = {
    { key = '1', kind = 'smd', blueprint = 'ueb4302', phase = 'active', progress = 20 },
    { key = '2', kind = 'smd', blueprint = 'ueb4302', phase = 'active', progress = 70 },
} }
receive('Enemy', packet)
Advance(1)
assert(table.getn(rendered) == 0)
receive('Ally', packet)
Advance(1)
assert(table.getn(rendered) == 2 and rendered[2].status == '70%')
receive('Ally', { version = 1, sequence = 2, enabled = {}, rows = {} })
Advance(1)
assert(table.getn(rendered) == 0, 'Withdrawal clears the previous snapshot')
env.ReceiveNotify('Ally', { notifyFrom = 2,
    data = { category = 'experimentals', source = 'uel0401', trigger = 'started' } })
Advance(1)
assert(table.getn(rendered) == 1 and rendered[1].phase == 'active')
env.ReceiveNotify('Ally', { notifyFrom = 2,
    data = { category = 'experimentals', source = 'uel0401', trigger = 'cancelled' } })
Advance(1)
assert(table.getn(rendered) == 1 and rendered[1].phase == 'cancelled')
Advance(9)
assert(table.getn(rendered) == 0)

env.__blueprints.uel0001 = {
    CategoriesHash = { COMMAND = true },
    Enhancements = { Shield = { Name = 'Shield' } },
}
env.ReceiveNotify('Ally', { NotifyOverlay = true,
    data = { id = 25, category = 'uef', source = 'Shield', progress = 60, pos = { 12, 0, 16 } } })
Advance(1)
assert(rendered[1].status == '60%' and rendered[1].position[1] == 12)
assert(rendered[1].name == 'Персональный щит' and rendered[1].enhancement == 'Shield')
env.ReceiveNotify('Ally', { NotifyOverlay = true, data = { id = 25, destroy = true } })
Advance(1)
assert(rendered[1].phase == 'active' and rendered[1].position == nil,
    'The stock overlay ending does not establish cancellation')
sync.ChatMessages({ { From = 2, notifyFrom = 2, to = 'notify', Id = 'shield-complete',
    data = { category = 'uef', source = 'Shield', trigger = 'completed' } } })
Advance(1)
assert(table.getn(rendered) == 1 and rendered[1].phase == 'done')

local delayedFraction = 1
local experimental = {
    IsDead = function() return false end, GetArmy = function() return 1 end,
    GetEntityId = function() return 12 end, GetBlueprint = function() return exp end,
    GetFractionComplete = function() return delayedFraction end, GetPosition = function() return { 4, 0, 8 } end,
}
local getUnit = env.GetUnitById
env.GetUnitById = function(id)
    if id == 12 then return experimental end
    return getUnit(id)
end
env.UnitData['12'] = {}
sync.UnitData({ ['12'] = {} })
sync.EnhanceMessage({ { army = 1, category = 'experimentals', source = 'uel0401', trigger = 'started' } })
Advance(1)
assert(table.getn(rendered) == 0)
delayedFraction = 0.43
Advance(1)
assert(table.getn(rendered) == 1 and rendered[1].progress == 43 and rendered[1].blueprint == 'uel0401',
    'A late build fraction is retried without a selection event')
