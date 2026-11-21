-- Ctrl input behavior used by Hotbuild, isolated from the rest of the UI.
table.getn = function(value) return #value end

local hooks = {}
local behaviors = {}
local selected = {}
local commandMode = false
local commandData
local issuedModeData
local heldControl = true
local active = true
local scheduled = {}
local startedModes = {}
local waitCount = 0

local commandModule = {
    AddEndBehavior = function(callback) table.insert(behaviors, callback) end,
    GetCommandMode = function() return {commandMode, commandData} end,
    StartCommandMode = function(mode, data)
        table.insert(startedModes, {mode, data})
        commandMode = mode
        commandData = data
    end,
}

local reui = {
    Core = {
        Hook = function(path, name, decorator)
            hooks[path .. ':' .. name] = decorator
        end,
    },
}

local environment = setmetatable({
    ReUI = reui,
    import = function(path)
        assert(path == '/lua/ui/game/commandmode.lua', 'unexpected import ' .. tostring(path))
        return commandModule
    end,
    IsKeyDown = function(key) return key == 'Control' and heldControl end,
    GetSelectedUnits = function() return selected end,
    ForkThread = function(callback) table.insert(scheduled, callback) end,
    WaitFrames = function(frames)
        assert(frames == 1)
        waitCount = waitCount + 1
    end,
}, {__index=_G})

local module = setmetatable({}, {__index=environment})
assert(loadfile('../mods/ClaretHotbuild/modules/CtrlInput.lua', 't', module))()

module.Install(reui, function() return active end)
assert(not hooks['/lua/ui/controls/worldview.lua:WorldView'], 'Ctrl input does not intercept world view clicks')

local issuedHook = assert(hooks['/lua/ui/game/commandmode.lua:OnCommandIssued'])
local function issue(command)
    local originalCalls = 0
    local original = function(value)
        originalCalls = originalCalls + 1
        if value.CommandType ~= 'None' then
            commandMode = false
            commandData = nil
            for _, behavior in ipairs(behaviors) do
                behavior('order', issuedModeData)
            end
        end
        return 'original-result'
    end
    local wrapper = issuedHook(original)
    local result = wrapper(command)
    assert(originalCalls == 1 and result == 'original-result',
        'the original command handler still runs exactly once')
end

local function issueMove(units, data)
    selected = units
    commandMode = 'order'
    commandData = data or {name='RULEUCC_Move'}
    issuedModeData = commandData
    issue({CommandType='Move',Units=units})
end

local function flushScheduled()
    local pending = scheduled
    scheduled = {}
    for _, callback in ipairs(pending) do callback() end
end

local first = {GetEntityId=function() return 101 end}
local second = {GetEntityId=function() return 102 end}
issueMove({first})
assert(#scheduled == 1, 'an issued Ctrl-Move schedules a deferred rearm')
flushScheduled()
assert(waitCount == 1 and #startedModes == 1
    and startedModes[1][1] == 'order'
    and startedModes[1][2].name == 'RULEUCC_Move',
    'ordinary Ctrl-Move reopens its cursor after the command ends')

commandMode = false
local before = #startedModes
issueMove({first}, {name='RULEUCC_Move',claretHotbuildReplacingMove=true})
flushScheduled()
assert(#startedModes == before, 'Hotbuild replacement marker suppresses Ctrl-Move rearm')

commandMode = false
issueMove({first})
heldControl = false
flushScheduled()
assert(#startedModes == before, 'releasing Ctrl before the deferred rearm prevents it')
heldControl = true

commandMode = false
issueMove({first})
selected = {second}
flushScheduled()
assert(#startedModes == before, 'changing selection before rearm prevents stale Move')

commandMode = false
issueMove({first})
commandMode = 'order'
commandData = {name='RULEUCC_Attack'}
flushScheduled()
assert(#startedModes == before, 'an active replacement order prevents Move from taking over')

commandMode = false
issueMove({first})
active = false
flushScheduled()
assert(#startedModes == before, 'deactivating Hotbuild before rearm prevents Move')

commandMode = false
active = true
issueMove({first})
for _, behavior in ipairs(behaviors) do behavior('order', {name='RULEUCC_Attack'}) end
flushScheduled()
assert(#startedModes == before, 'a newer command end invalidates a stale deferred rearm')

commandMode = false
issue({CommandType='Attack',Units={first}})
flushScheduled()
assert(#startedModes == before, 'non-Move commands do not arm Ctrl-Move')

print('PASS: Ctrl-Move rearm guards and native world view clicks')
