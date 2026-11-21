table.getn = table.getn or function(values) return #values end
local env = setmetatable({}, { __index = _G })
env.LOG = function() end
local beat, receive, receiveTis, rendered, renderedSilos, renderedList
local time = 0
local sync, packets, callbacks, tisPackets, tisSilos = {}, {}, {}, {}, {}
local smd = { BlueprintId = 'ueb4302', CategoriesHash = { STRUCTURE = true, TECH3 = true, ANTIMISSILE = true, SILO = true } }
local exp = { BlueprintId = 'uel0401', CategoriesHash = {}, TechCategory = 'EXPERIMENTAL',
    General = { UnitName = 'Fatboy' } }
local armies = {
    { human = true, nickname = 'Self', authorizedCommandSources = { 1 } },
    { human = true, nickname = 'Ally', authorizedCommandSources = { 2 } },
    { human = true, nickname = 'Enemy', authorizedCommandSources = { 3 } },
}
local fraction = 0.42
local missileProgress, missileStock, siloDead = 0, 0, false
local unit = {
    IsDead = function() return siloDead end, GetArmy = function() return 1 end,
    GetEntityId = function() return 11 end, GetBlueprint = function() return smd end,
    GetFractionComplete = function() return fraction end, GetPosition = function() return { 1, 2, 3 } end,
    GetWorkProgress = function() return missileProgress end,
    GetMissileInfo = function() return { tacticalSiloStorageCount = missileStock } end,
}
local game = {
    OriginalFocusArmy = 1,
    ObserveSelection = { AddObserver = function() end },
    RegisterChatFunc = function(callback, channel)
        if channel == 'TIS' then receiveTis = callback
        elseif channel == 'ClaretUI.InfoShare' then receive = callback end
    end,
    AddBeatFunction = function(callback) beat = callback end,
    RemoveBeatFunction = function() beat = nil end,
}
env.import = function(path)
    if path == '/lua/ui/game/gamemain.lua' then return game end
    assert(path == '/mods/ClaretUI/modules/InfoShareDisplay.lua')
    return { Create = function()
        return { Render = function(_, rows, _, _, silos, listRows)
            rendered, renderedSilos, renderedList = rows, silos, listRows
        end }
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
env.GameTick = function() return math.floor(time * 10) end
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
    if packet.TIS then
        assert(packet.Identifier == nil and packet.to == 'allies', 'TIS must use the legacy chat envelope')
        table.insert(packet.text.nuke and tisSilos or tisPackets, packet.text)
    else
        table.insert(packets, packet)
    end
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
local startUpvalues, index = 0, 1
while true do
    local name = debug.getupvalue(env.Start, index)
    if not name then break end
    if name ~= '_ENV' then startUpvalues = startUpvalues + 1 end
    index = index + 1
end
assert(startUpvalues <= 32, 'InfoShare.Start exceeds the FAF LuaPlus limit: ' .. startUpvalues .. ' upvalues')
env.Start(env, scope, false, options)
assert(beat and Latest().rows[1].progress == 42 and Latest().rows[1].position[3] == 3)
assert(rendered == nil, 'Automatic sharing works with both HUD modes disabled')
options.infoShareList:Set(true)
assert(rendered[1].status == '42%')
fraction = 0.50
Advance(1)
assert(rendered[1].eta == 7, 'SMD ETA uses simulation seconds and incremental construction progress')
Advance(2)
assert(rendered[1].eta == nil and Latest().rows[1].eta == nil, 'A stalled build stops showing an ETA')
Advance(8)
assert(table.getn(renderedList) == 0 and table.getn(rendered) == 1, 'An own build hides only from the list after ten seconds of stall')
fraction = 0.51
Advance(0.5)
assert(renderedList[1] and renderedList[1].status == '51%', 'Resuming an own build restores its HUD row')
options.infoShareList:Set(false)
fraction = 1
Advance(2)
assert(Latest().rows[2].phase == 'done', 'The SMD construction completion remains in the snapshot briefly')
assert(Latest().rows[1].kind == 'silo' and Latest().rows[1].stock == 0 and tisSilos[1].init,
    'A completed SMD starts a separate native and legacy missile production stream')
missileProgress = 0.25
Advance(1.5)
assert(table.getn(Latest().rows) == 1 and Latest().rows[1].kind == 'silo' and Latest().rows[1].eta == 5,
    'The construction result expires while the live missile production ETA remains')
assert(tisSilos[table.getn(tisSilos)].progress == 0.25 and tisSilos[table.getn(tisSilos)].eta == 5,
    'TIS receives real missile production progress and ETA')
missileProgress, missileStock = 0, 1
Advance(2)
assert(Latest().rows[1].stock == 1 and Latest().rows[1].eta == nil,
    'A finished interceptor increases stock and clears the previous missile ETA')
siloDead = true
Advance(0.5)
assert(table.getn(Latest().rows) == 0 and tisSilos[table.getn(tisSilos)].remove,
    'Destroyed silos are removed from both protocols')
options.infoShareList:Set(true)
local packet = { version = 1, sequence = 1, enabled = { smd = true }, rows = {
    { key = '1', kind = 'smd', blueprint = 'ueb4302', phase = 'active', progress = 20 },
    { key = '2', kind = 'smd', blueprint = 'ueb4302', phase = 'active', progress = 70, eta = 31 },
} }
receive('Enemy', packet)
Advance(1)
assert(table.getn(rendered) == 0)
receive('Ally', packet)
Advance(1)
assert(table.getn(rendered) == 2 and rendered[2].status == '70%')
assert(rendered[2].eta == 30, 'The ETA in a native snapshot counts down on the receiving client')
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
local import = env.import
env.import = function(path)
    if path == '/mods/ClaretUI/modules/features/InfoShare.lua' then return env end
    return import(path)
end
local stockOverlayCalls, removedStockOverlay = 0, false
env.processNotification = function() stockOverlayCalls = stockOverlayCalls + 1 end
env.overlays = { [25] = { Destroy = function() removedStockOverlay = true end } }
assert(loadfile('../mods/ClaretUI/hook/lua/ui/notify/notifyoverlay.lua', 't', env))()
local overlayPacket = { NotifyOverlay = true,
    data = { id = 25, category = 'uef', source = 'Shield', progress = 60, pos = { 12, 0, 16 } } }
env.processNotification('Ally', overlayPacket)
assert(stockOverlayCalls == 1 and not removedStockOverlay, 'List-only mode keeps the stock map overlay')
options.infoShareWorld:Set(true)
env.processNotification('Ally', overlayPacket)
assert(stockOverlayCalls == 1 and removedStockOverlay and not env.overlays[25],
    'The Claret map label replaces the existing local stock ETA overlay')
Advance(1)
assert(rendered[1].status == '60%' and rendered[1].position[1] == 12)
assert(rendered[1].name == 'Персональный щит' and rendered[1].enhancement == 'Shield')
options.infoShareAcu:Set(false)
env.processNotification('Ally', overlayPacket)
assert(stockOverlayCalls == 2, 'Disabling Claret commander labels restores the stock map overlay')
options.infoShareAcu:Set(true)
env.processNotification('Ally', { NotifyOverlay = true, data = { id = 25, destroy = true } })
assert(stockOverlayCalls == 3, 'Stock teardown packets still reach the original handler')
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

assert(tisPackets[1].init and tisPackets[1].exp and tisPackets[1].id == 12 and tisPackets[1].pos[3] == 8
    and tisPackets[1].blueprint == 'uel0401', 'A legacy init packet carries the position and optional Claret blueprint')
assert(tisPackets[2].progress == 0.43 and tisPackets[2].eta == -1,
    'TIS receives the exact construction fraction and unknown ETA')
delayedFraction = 0.50
Advance(0.5)
assert(table.getn(tisPackets) == 3 and tisPackets[3].progress == 0.5 and tisPackets[3].eta == 4
    and not tisPackets[3].init, 'A legacy heartbeat carries the measured construction ETA')
delayedFraction = 1
Advance(0.5)
assert(tisPackets[4].is_done and tisPackets[5].remove and tisPackets[5].id == 12,
    'Completion ends the legacy overlay and releases the entity ID')
Advance(2)

local originalCalls = 0
env.ReceiveChat = function(sender, message)
    originalCalls = originalCalls + 1
    if receiveTis and (message.Identifier == 'TIS' or not message.Identifier and message.TIS) then
        receiveTis(sender, message)
    end
end
assert(loadfile('../mods/ClaretUI/hook/lua/ui/game/gamemain.lua', 't', env))()
local function ReceiveTis(sender, data)
    receiveTis(sender, { TIS = true, to = 'allies', text = data })
end
local init = { exp = true, init = true, id = '90', pos = { 9, 0, 8 } }
ReceiveTis('Enemy', init)
ReceiveTis('Ally', { nuke = 'true', init = 'true', id = 'unit:91', pos = { '9', '0', '8' } })
Advance(0.5)
assert(table.getn(rendered) == 0 and table.getn(renderedSilos) == 1,
    'Enemy traffic is ignored and legacy silo data stays out of the list')
ReceiveTis('Ally', { nuke = 'true', id = 'unit:91', progress = '0.75', eta = '61', silo = '2' })
Advance(1)
assert(renderedSilos[1].status == '75%' and renderedSilos[1].eta == 60 and renderedSilos[1].stock == 2,
    'The silo map label keeps production progress, a countdown and missile stock')
Advance(1)
ReceiveTis('Ally', { nuke = true, id = 'unit:91', progress = 0.80, eta = -1, silo = 2 })
Advance(0.5)
assert(renderedSilos[1].eta and renderedSilos[1].eta <= 9,
    'If TIS stops estimating ETA, Claret derives it from the observed production progress')
ReceiveTis('Ally', { nuke = true, id = 'unit:91', remove = true })
Advance(0.5)
assert(table.getn(renderedSilos) == 0, 'Legacy silo removal clears the map label')
options.infoShareList:Set(false)
ReceiveTis('Ally', init)
ReceiveTis('Ally', { exp = true, id = 90, progress = 0.375, eta = 90 })
ReceiveTis('Ally', { exp = true, id = 90, progress = 99 })
options.infoShareList:Set(true)
assert(originalCalls == 0, 'Legacy packets reach InfoShare through the registered channel alone')
assert(table.getn(rendered) == 1 and rendered[1].status == '~37%'
    and rendered[1].position[1] == 9 and rendered[1].eta == 90,
    'A TIS row uses approximate progress and registered ETA even if the list was disabled at receipt')
env.ReceiveNotify('Ally', { notifyFrom = 2,
    data = { category = 'experimentals', source = 'uel0401', trigger = 'started' } })
Advance(0.5)
assert(table.getn(rendered) == 1 and renderedList[1].status == '~37%'
    and renderedList[1].blueprint == 'uel0401' and renderedList[1].name == 'Fatboy',
    'A unique Notify start adds its blueprint to the TIS progress row without a duplicate')
ReceiveTis('Ally', { exp = true, init = true, id = 93, pos = { 30, 0, 31 } })
Advance(0.5)
assert(table.getn(rendered) == 2 and not rendered[1].blueprint and not rendered[2].blueprint,
    'Unidentified simultaneous experimental rows do not borrow an ambiguous blueprint')
ReceiveTis('Ally', { exp = true, id = 93, remove = true })
local findExistingUnit = env.GetUnitById
env.GetUnitById = function(id)
    if id == 93 then return { GetArmy = function() return 2 end, IsDead = function() return false end,
        GetPosition = function() return { 30, 0, 31 } end, GetBlueprint = function() return exp end } end
    return findExistingUnit(id)
end
ReceiveTis('Ally', { exp = true, init = true, id = 93, pos = { 30, 0, 31 } })
ReceiveTis('Ally', { exp = true, id = 93, progress = 0.25 })
Advance(0.5)
assert(table.getn(rendered) == 2 and rendered[2].blueprint == 'uel0401' and rendered[2].status == '~25%',
    'An allied entity identifies its own TIS row while progress remains marked approximate')
ReceiveTis('Ally', { exp = true, id = 93, remove = true })
receive('Ally', { version = 1, sequence = 3, enabled = { experimental = true }, rows = {
    { key = 'exp', kind = 'experimental', blueprint = 'uel0401', phase = 'active', progress = 30 },
} })
Advance(0.5)
assert(table.getn(rendered) == 1 and rendered[1].status == '30%' and rendered[1].blueprint == 'uel0401',
    'The native Claret snapshot takes precedence over TIS for the same ally')
receive('Ally', { version = 1, sequence = 4, enabled = {}, rows = {} })
ReceiveTis('Ally', { exp = true, id = 90, is_done = true, progress = 1, eta = -1 })
Advance(0.5)
assert(table.getn(rendered) == 0, 'The TIS completion heuristic clears the overlay without claiming completion')
ReceiveTis('Ally', init)
Advance(0.5)
assert(table.getn(rendered) == 1, 'A fresh legacy init can recreate the row')
ReceiveTis('Ally', { exp = true, id = 90, remove = true })
Advance(0.5)
assert(table.getn(rendered) == 0, 'An explicit legacy removal clears the row')
ReceiveTis('Ally', init)
Advance(12)
assert(table.getn(rendered) == 0, 'A stale TIS overlay expires without a completion claim')

receive('Ally', { version = 1, sequence = 5, enabled = { acu = true }, rows = {
    { key = 'shield', kind = 'acu', blueprint = 'uel0001', enhancement = 'Shield',
        phase = 'active', progress = 65, position = { 12, 0, 16 } },
} })
env.processNotification('Ally', overlayPacket)
assert(stockOverlayCalls == 3, 'A native Claret upgrade label also supersedes stock ETA')
env.processNotification('Ally', { NotifyOverlay = true,
    data = { id = 26, category = 'uef', source = 'Shield', progress = 20, pos = { 60, 0, 80 } } })
assert(stockOverlayCalls == 4, 'An overlay for a different commander remains visible')
receive('Ally', { version = 1, sequence = 6, enabled = { acu = true }, rows = {
    { key = 'shield', kind = 'acu', blueprint = 'uel0001', enhancement = 'Shield', phase = 'active' },
} })
env.processNotification('Ally', overlayPacket)
assert(stockOverlayCalls == 5, 'Stock ETA remains available while a native row has no map position')

receive('Ally', { version = 1, sequence = 7, enabled = { smd = true }, rows = {
    { key = 'defense', kind = 'smd', blueprint = 'ueb4302', phase = 'active', position = init.pos },
} })
ReceiveTis('Ally', { nuke = true, init = true, id = 91, pos = init.pos })
Advance(0.5)
assert(table.getn(renderedSilos) == 0, 'A silo fallback does not overlap an existing Claret SMD label')
receive('Ally', { version = 1, sequence = 8, enabled = { smd = true }, rows = {} })
Advance(0.5)
assert(table.getn(renderedSilos) == 1, 'The silo fallback can appear when the construction label clears')
receive('Ally', { version = 1, sequence = 9, enabled = { silo = true }, rows = {
    { key = 'production', kind = 'silo', blueprint = 'ueb4302', phase = 'active',
        position = init.pos, progress = 50, stock = 2, eta = 25 },
} })
Advance(0.5)
assert(table.getn(renderedSilos) == 1 and renderedSilos[1].blueprint == 'ueb4302'
    and renderedSilos[1].stock == 2 and renderedSilos[1].eta == 25,
    'Native silo production takes precedence over a legacy marker for the same allied silo')

local sentCount = table.getn(tisPackets)
env._G = env
env.__active_mods = { { uid = 'teaminfo-share-v11' } }
local originalTis = function() end
receiveTis = originalTis
delayedFraction = 0.5
env.Start(env, scope, false, options)
Advance(0.5)
assert(table.getn(tisPackets) == sentCount and Latest().rows[1].progress == 50,
    'A locally active TIS sends its own packets while native Claret sharing continues')
assert(receiveTis == originalTis, 'Claret leaves the locally installed TIS channel handler registered')
env.ReceiveChat('Ally', { TIS = true, to = 'allies', text = init })
Advance(0.5)
assert(originalCalls == 1 and rendered[2] and rendered[2].key == 'tis:2:90',
    'When TIS is installed locally the chat hook forwards packets to both receivers')

local commander = {
    IsDead = function() return false end, GetArmy = function() return 1 end,
    GetBlueprint = function() return { BlueprintId = 'uel0001' } end,
    GetWorkProgress = function() return 0.5 end, GetPosition = function() return { 10, 0, 12 } end,
}
local getTeamUnit = env.GetUnitById
env.GetUnitById = function(id)
    if id == 27 then return commander end
    return getTeamUnit(id)
end
sync.EnhanceMessage({ { army = 1, id = 27, category = 'uef', source = 'Shield', trigger = 'started' } })
Advance(0.5)
local ownOverlayPacket = { NotifyOverlay = true,
    data = { id = 27, category = 'uef', source = 'Shield', progress = 50, pos = { 10, 0, 12 } } }
env.processNotification('Self', ownOverlayPacket)
assert(stockOverlayCalls == 5, 'Claret also suppresses duplicate ETA for the local commander')
options.infoShareOwn:Set(false)
env.processNotification('Self', ownOverlayPacket)
assert(stockOverlayCalls == 6, 'The own-work filter leaves the original FAF overlay available')

local nuclearBlueprint = { BlueprintId = 'ueb2305', CategoriesHash = { STRUCTURE = true, SILO = true, NUKE = true } }
local nuclearSilo = {
    IsDead = function() return false end, GetArmy = function() return 1 end, GetEntityId = function() return 37 end,
    GetBlueprint = function() return nuclearBlueprint end, GetFractionComplete = function() return 1 end,
    GetMissileInfo = function() return { nukeSiloStorageCount = 3 } end, GetWorkProgress = function() return 0.65 end,
    GetPosition = function() return { 30, 0, 20 } end,
}
local getExistingUnit = env.GetUnitById
env.GetUnitById = function(id)
    if id == 37 then return nuclearSilo end
    return getExistingUnit(id)
end
sync.UnitData({ ['37'] = {} })
Advance(2)
local observedNuke = false
for _, row in ipairs(Latest().rows) do
    if row.blueprint == 'ueb2305' then observedNuke = row.kind == 'silo' and row.progress == 65 and row.stock == 3 end
end
assert(observedNuke, 'Stationary nuclear silos use strategic missile stock and production progress')

local function HasRow(rows, key)
    for _, row in ipairs(rows) do
        if row.key == key then return true end
    end
    return false
end
local slow = { key = 'slow', kind = 'experimental', blueprint = 'uel0401', phase = 'active',
    progress = 40, position = { 16, 0, 20 } }
local fast = { key = 'fast', kind = 'smd', blueprint = 'ueb4302', phase = 'active',
    progress = 65, position = { 24, 0, 20 } }
local upgrade = { key = 'shield', kind = 'acu', blueprint = 'uel0001', enhancement = 'Shield',
    phase = 'active', progress = 20 }
local function ReceiveConstruction(sequence)
    receive('Ally', { version = 1, sequence = sequence, enabled = { experimental = true, smd = true, acu = true },
        rows = { slow, fast, upgrade } })
end
ReceiveConstruction(10)
Advance(9)
assert(renderedList[1].key == 'remote:2:fast' and renderedList[2].key == 'remote:2:slow'
    and renderedList[3].key == 'remote:2:shield', 'The HUD sorts active work by descending progress')
slow.progress = 35
fast.progress = 66
ReceiveConstruction(11)
Advance(1)
assert(not HasRow(renderedList, 'remote:2:slow') and HasRow(rendered, 'remote:2:slow')
    and HasRow(renderedList, 'remote:2:shield'), 'A drop does not reset the ten-second HUD timer, and other views keep the row')
slow.progress, slow.fraction = 34, 0.34
ReceiveConstruction(12)
Advance(0.5)
assert(not HasRow(renderedList, 'remote:2:slow'), 'Decreasing again does not wake up a hidden build')
slow.fraction = 0.341
ReceiveConstruction(13)
Advance(0.5)
assert(HasRow(renderedList, 'remote:2:slow'), 'New growth restores the row even below its previous high')

print('PASS: InfoShare native, stock Notify and TeamInfo Share v11 exchange; Start upvalues: ' .. startUpvalues)
