local env = setmetatable({}, { __index = _G })
local syncCallbacks, selectionObservers, alerts = {}, {}, {}
local army, time, beat = 1, 0, nil
local units, selected = {}, {}
local Game = {
    OriginalFocusArmy = 1,
    ObserveSelection = { AddObserver = function(_, callback, id) selectionObservers[id] = callback end },
    AddBeatFunction = function(callback) beat = callback end,
    RemoveBeatFunction = function(callback) if beat == callback then beat = nil end end,
}
local function Unit(id, unitArmy, categories)
    local unit = { stock = 0, tactical = 0, categories = categories }
    unit.GetEntityId = function() return id end
    unit.GetArmy = function() return unitArmy end
    unit.IsDead = function() return unit.dead end
    unit.GetFocus = function() return unit.focus end
    unit.IsInCategory = function(_, name) return unit.categories[name] end
    unit.GetMissileInfo = function()
        return { nukeSiloStorageCount = unit.stock, tacticalSiloStorageCount = unit.tactical }
    end
    unit.GetBlueprint = function()
        return { BlueprintId = 'uel0001', Enhancements = { Gun = { Name = 'Gun upgrade', Icon = 'gun' } } }
    end
    units[id] = unit
    return unit
end

local silo = Unit(10, 1, { NUKE = true, STRUCTURE = true })
local allySilo = Unit(11, 2, { NUKE = true })
local acu = Unit(12, 1, { COMMAND = true })
local builder = Unit(13, 1, { ENGINEER = true })
local submarine = Unit(14, 1, { NUKE = true, NAVAL = true, SUBMERSIBLE = true })
env.UnitData = { ['10'] = {}, [11] = {} }
env.GetUnitById = function(id) return units[id] end
env.GetFocusArmy = function() return army end
env.GetSystemTimeSeconds = function() return time end
env.GetGameTimeSeconds = env.GetSystemTimeSeconds
env.GetSelectedUnits = function() return selected end
env.GetArmiesTable = function() return { armiesTable = { { faction = 2 } } } end
env.__blueprints = { ueb2401 = { General = { UnitName = 'Mavor', Icon = 'land' } } }
env.DiskGetFileInfo = function(path)
    return path == 'gun.dds' or path == '/icons/units/urb0303_icon.dds' or path == '/icons/units/ueb2401_icon.dds'
        or path == '/icons/units/ueb4302_icon.dds'
end
env.AddOnSyncHashedCallback = function(callback, category) syncCallbacks[category] = callback end
env.RemoveOnSyncHashedCallback = function(category) syncCallbacks[category] = nil end
env.import = function(path)
    if path == '/lua/ui/game/gamemain.lua' then return Game end
    if path == '/lua/ui/uiutil.lua' then return { UIFile = function(texture) return texture end } end
    if path == '/lua/ui/game/construction.lua' then
        return { GetEnhancementTextures = function(id, icon)
            assert(id == 'uel0001' and icon == 'gun', 'Use the completed enhancement and its ACU blueprint to resolve the icon')
            return 'gun.dds', 'gun-pressed.dds'
        end }
    end
    if path == '/mods/ClaretUI/modules/NotificationDisplay.lua' then
        return { Create = function()
            return {
                Show = function(_, kind, textKey, value, icon, frame)
                    table.insert(alerts, { kind = kind, textKey = textKey, value = value, icon = icon, frame = frame })
                end,
                Clear = function() alerts = {} end,
            }
        end }
    end
    error('Unexpected import ' .. path)
end

local cleanups, optionCallbacks = {}, {}
local scope = {
    Defer = function(_, callback) table.insert(cleanups, callback) end,
    Bind = function(_, event, callback) optionCallbacks[event] = callback end,
}
local function Option(initial)
    local option = { OnChanged = {} }
    function option:Get() return initial end
    function option:Set(value)
        initial = value
        if optionCallbacks[self.OnChanged] then optionCallbacks[self.OnChanged]() end
    end
    return option
end
local options = { notificationsHQ = Option(true), notificationsACU = Option(true), notificationsNuke = Option(false),
    notificationsExperimental = Option(false), notificationsSmd = Option(false) }
local function Advance()
    time = time + 1
    if beat then beat() end
end

assert(loadfile('../mods/ClaretUI/modules/features/Notifications.lua', 't', env))()
env.Start(env, scope, true, options)
assert(not next(syncCallbacks) and not beat, 'Replay must not enable alerts')
env.Start(env, scope, false, options)
assert(not beat, 'Missile sampling must stay off until enabled')
syncCallbacks.EnhanceMessage({
    { army = 1, category = 'tech', trigger = 'started', source = 'researchlandtech2' },
    { army = 1, category = 'tech', trigger = 'cancelled', source = 'researchairtech3' },
    { army = 2, category = 'tech', trigger = 'completed', source = 'researchlandtech3' },
    { army = 1, category = 'tech', trigger = 'completed', source = 'researchnavaltech3' },
    { army = 1, category = 'uef', trigger = 'completed', source = 'GunRemove', id = 12 },
    { army = 1, category = 'uef', trigger = 'completed', source = 'Gun', id = acu:GetEntityId() },
    { army = 1, category = 'other', trigger = 'completed', source = 'nuke' },
})
assert(#alerts == 2 and alerts[1].textKey == 'hq_naval' and alerts[1].value == '3', 'Only own completed HQ should alert')
assert(alerts[1].icon == '/icons/units/urb0303_icon.dds' and alerts[1].frame == '/icons/units/sea_up.dds',
    'The HQ thumbnail and frame should match the tier, factory type and army faction')
local enhancement = alerts[2].value
assert(alerts[2].kind == 'acu' and enhancement.id == 'Gun' and enhancement.unitId == 'uel0001'
    and enhancement.name == 'Gun upgrade' and alerts[2].icon == 'gun.dds',
    'An installed enhancement should provide its ID, ACU blueprint, fallback name and normal icon')

silo.stock = 1
options.notificationsNuke:Set(true)
Advance()
assert(#alerts == 2, 'Existing missiles should establish a baseline')
silo.tactical, allySilo.stock = 1, 1
Advance()
assert(#alerts == 2, 'Tactical and foreign stock changes should not alert')
silo.stock = 2
Advance()
assert(#alerts == 3 and alerts[3].kind == 'nuke' and not alerts[3].value, 'Stock growth should alert without a count in the text')
assert(alerts[3].icon == '/mods/ClaretUI/textures/notifications/nuke-silo.png', 'The silo should use the icon without waves')
silo.stock = 0
Advance()
assert(#alerts == 3, 'Launches or stock decreases should not alert')
silo.stock = 2
Advance()
assert(#alerts == 4 and alerts[4].kind == 'nuke', 'A batched stock increase should still trigger an alert')

builder.focus = submarine
selectionObservers['ClaretUI.Notifications']({ newSelection = { builder } })
Advance()
submarine.stock = 1
Advance()
assert(#alerts == 5 and alerts[5].kind == 'nuke', 'A selected builder can discover a launcher by its focus')
assert(alerts[5].icon == '/mods/ClaretUI/textures/notifications/nuke-sub.png', 'Submarines should use the icon with waves')
syncCallbacks.UnitData({ [15] = {} })
Advance()
local battleship = Unit(15, 1, { NUKE = true, NAVAL = true })
Advance()
battleship.stock = 1
Advance()
assert(#alerts == 6, 'A synced ID should still resolve when its handle arrives after the first sample')
assert(alerts[6].kind == 'nuke' and not alerts[6].icon, 'A surface ship should keep a text-only alert')

options.notificationsExperimental:Set(true)
env.__blueprints.xea0002 = { General = { UnitName = 'Defense Satellite' } }
env.__blueprints.xsl0402 = { General = { UnitName = 'Othuy' } }
env.__blueprints.xeb2402 = { General = { UnitName = 'Novax Center' } }
syncCallbacks.EnhanceMessage({
    { army = 1, category = 'experimentals', trigger = 'completed', source = 'xea0002' },
    { army = 1, category = 'experimentals', trigger = 'completed', source = 'xsl0402' },
    { army = 1, category = 'experimentals', trigger = 'completed', source = 'xeb2402' },
})
assert(#alerts == 7 and alerts[7].value == 'Novax Center', 'Only the station should show a completion alert')
table.remove(alerts)
syncCallbacks.EnhanceMessage({
    { army = 1, category = 'experimentals', trigger = 'started', source = 'ueb2401' },
    { army = 2, category = 'experimentals', trigger = 'completed', source = 'ueb2401' },
    { army = 1, category = 'experimentals', trigger = 'completed', source = 'ueb2401' },
})
assert(#alerts == 7 and alerts[7].value == 'Mavor' and alerts[7].icon == '/icons/units/ueb2401_icon.dds',
    'An own completed experimental should show its name and thumbnail')

options.notificationsNuke:Set(false)
local smd = Unit(16, 1, { ANTIMISSILE = true, SILO = true, STRUCTURE = true, TECH3 = true })
smd.GetBlueprint = function() return { BlueprintId = 'ueb4302', General = { Icon = 'land' } } end
env.UnitData[16] = {}
smd.tactical = 1
options.notificationsSmd:Set(true)
Advance()
assert(#alerts == 7, 'SMD should establish a baseline even when nuke alerts are disabled')
smd.tactical = 2
Advance()
assert(#alerts == 8 and alerts[8].kind == 'smd' and alerts[8].value.added == 1 and alerts[8].value.stock == 2,
    'SMD should announce additional interceptors even with existing stock')
assert(alerts[8].icon == '/icons/units/ueb4302_icon.dds' and alerts[8].frame == '/icons/units/land_up.dds',
    'SMD should use the charged installation thumbnail and construction frame')
smd.tactical = 0
Advance()
assert(#alerts == 8, 'Firing interceptors should not show a readiness alert')
smd.tactical = 3
Advance()
assert(#alerts == 9 and alerts[9].value.added == 3 and alerts[9].value.stock == 3,
    'Updates between samples should show the net increase and stock')

army = 2
syncCallbacks.FocusArmyChanged()
assert(not beat and #alerts == 0, 'Leaving the original army should clear alerts and stop sampling')
army = 1
syncCallbacks.FocusArmyChanged()
Advance()
assert(#alerts == 0, 'Returning to the original army should establish new baselines')
options.notificationsSmd:Set(false)
assert(not beat and not syncCallbacks.UnitData and not next(selectionObservers), 'Disabling missiles should remove their listeners')
env.__blueprints.xrl0403 = { TechCategory = 'EXPERIMENTAL', General = { UnitName = 'Megalith' } }
local megalithComplete = { army = 1, category = 'experimentals', trigger = 'completed', source = 'xrl0403' }
local mode = { cheat = true, army = 1, count = 15 }
local forwarded
local hook = {
    OnCommandIssued = function(command) forwarded = command end,
    GetCommandMode = function() return { 'build', mode } end,
    import = function() return env end,
}
assert(loadfile('../mods/ClaretUI/hook/lua/ui/game/commandmode.lua', 't', hook))()
local spawn = { CommandType = 'BuildMobile', Units = {}, Blueprint = 'xrl0403' }
hook.OnCommandIssued(spawn)
assert(forwarded == spawn, 'The hook forwards the original FAF command unchanged')
local completions = {}
for index = 1, 15 do completions[index] = megalithComplete end
syncCallbacks.EnhanceMessage(completions)
assert(#alerts == 0, 'Spawning 15 Megaliths should suppress all 15 notices')
syncCallbacks.EnhanceMessage({ megalithComplete })
assert(#alerts == 1 and alerts[1].value == 'Megalith', 'A simultaneous completion above the spawn count still alerts')
hook.OnCommandIssued(spawn)
Advance()
Advance()
syncCallbacks.EnhanceMessage({ megalithComplete })
assert(#alerts == 2, 'A normal completion after the spawn window still alerts')
mode.MeshOnly = true
hook.OnCommandIssued(spawn)
syncCallbacks.EnhanceMessage({ megalithComplete })
assert(#alerts == 3, 'Mesh previews should not register a spawn')

for index = #cleanups, 1, -1 do cleanups[index]() end
assert(not next(syncCallbacks), 'Match teardown should remove all sync listeners')

print('PASS: Claret UI notifications filter owned events, baseline missile stocks, and tear down listeners')
