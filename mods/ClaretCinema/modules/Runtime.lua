local current
local controls, director
local path = '/mods/ClaretCinema/modules/Runtime.lua'
local listeners = {}
local preference = 'ClaretCinemaBindings'
local settings = {actions = {hud = 'H'}}
local defaults = {
    move_origin = 'Ctrl-Q', move_target = 'Ctrl-W',
    move_jump_origin = 'Ctrl-A', move_jump_target = 'Ctrl-S', move_play = 'Ctrl-Z',
}
local commands = import('/mods/ClaretCinema/modules/Commands.lua')
local choices = commands.Choices
local choicesById = {}
local menuAction = 'UI_Lua import("/mods/ClaretCore/modules/MenuKey.lua").Open()'

local function IsMenuAction(definition)
    return type(definition) == 'table' and definition.action == menuAction
end

local function Binding(action)
    return {action = 'UI_Lua import("' .. path .. '").' .. action .. '()', category = 'camera'}
end

local function ActionLayout(actions)
    local result = {}
    for id, key in pairs(actions) do
        local choice = choicesById[id]
        if key ~= '' and choice and not choice.reason then
            result[key] = choice.definition
                or {action = string.format('UI_Lua import("%s").Perform(%q)', path, id), category = 'camera'}
        end
    end
    return result
end

local function Changed(kind, ok, message)
    for _, callback in pairs(listeners) do
        local success, failure = pcall(callback, kind, ok, message)
        if not success then WARN('[ClaretCinema] Keyboard refresh failed: ' .. tostring(failure)) end
    end
end

function Subscribe(owner, callback) listeners[owner] = callback end
function Unsubscribe(owner) listeners[owner] = nil end
function GetChoices() return choices end
function GetDirector() return director end
function GetChord(id)
    local chord = settings.actions[id]
    if not chord or chord == '' then return nil end
    return chord, IsMenuChord(chord)
end

function GetState()
    return current and current.IsActive() or false, current and current.Key()
end

function IsMenuChord(chord)
    return current and current.KeepsKey(chord) or false
end

function GetAssignment(chord)
    if current and chord == current.Key() then return 'mode' end
    for id, key in pairs(settings.actions) do
        if key ~= '' and key == chord then return id end
    end
end

function GetNormalAction(chord)
    if not current or not current.NormalHasKey(chord) then return nil, false end
    local mapper = import('/lua/keymap/keymapper.lua')
    local normalized = mapper.NormalizeKeyBinding(chord)
    for key, action in pairs(mapper.GetCurrentKeyMap()) do
        if mapper.NormalizeKeyBinding(key) == normalized then
            return mapper.GetActionName(action), true
        end
    end
    return nil, true
end

function Assign(id, key)
    if not current then return false, 'cinema.map_wait' end
    if current.IsActive() then return false, 'cinema.turn_off_to_edit' end
    local layout = import('/mods/ClaretCinema/modules/KeyboardLayout.lua')
    if key ~= '' and not layout.IsAssignable(key) then return false, 'cinema.reserved' end
    local choice = choicesById[id]
    if not choice then return false, 'cinema.reserved' end
    if key ~= '' and choice.reason then return false, choice.reason end
    local candidate = {toggle = settings.toggle, actions = {}}
    for action, chord in pairs(settings.actions) do candidate.actions[action] = chord end
    if id == 'mode' then
        if key ~= '' and current.NormalHasKey(key) then return false, 'cinema.toggle_busy' end
        local assigned = GetAssignment(key)
        if assigned and assigned ~= 'mode' then return false, 'cinema.chord_busy' end
        candidate.toggle = key ~= '' and key or nil
        if candidate.toggle == settings.toggle then return true end
    else
        if key ~= '' and IsMenuChord(key) then return false, 'cinema.menu_reserved' end
        if key ~= '' and (key == current.Key() or key == settings.toggle) then return false, 'cinema.reserved' end
        local assigned = GetAssignment(key)
        if assigned and assigned ~= id then return false, 'cinema.chord_busy' end
        if key == candidate.actions[id] then return true end
        candidate.actions[id] = key
    end

    local configured, detail = current.Configure(ActionLayout(candidate.actions), candidate.toggle)
    if not configured then
        WARN('[ClaretCinema] Binding update failed: ' .. tostring(detail))
        return false, 'cinema.switch_failed'
    end
    local prefs = import('/lua/user/prefs.lua')
    local saved = prefs.GetFromCurrentProfile(preference)
    local persisted = {actions = {}}
    if type(saved) == 'table' then
        for field, value in pairs(saved) do if field ~= 'actions' then persisted[field] = value end end
        if type(saved.actions) == 'table' then
            for action, chord in pairs(saved.actions) do persisted.actions[action] = chord end
        end
    end
    if id == 'mode' then persisted.toggle = candidate.toggle else persisted.actions[id] = key end
    local ok, message = pcall(function()
        prefs.SetToCurrentProfile(preference, persisted)
        SavePreferences()
    end)
    if not ok then
        local restored, restoreError = current.Configure(ActionLayout(settings.actions), settings.toggle)
        local reverted, rollbackError = pcall(prefs.SetToCurrentProfile, preference, saved)
        WARN('[ClaretCinema] Binding save failed: ' .. tostring(message))
        if not restored then WARN('[ClaretCinema] Map rollback failed: ' .. tostring(restoreError)) end
        if not reverted then WARN('[ClaretCinema] Preference rollback failed: ' .. tostring(rollbackError)) end
        return false, 'cinema.save_failed'
    end
    settings = candidate
    Changed()
    return true
end

function Clear(chord)
    local id = GetAssignment(chord)
    if not id then return true end
    return Assign(id, '')
end

function RunDrawer(id)
    if not current then return false, 'cinema.camera_unavailable' end
    local tab = id == 'move_origin' and 'move' or id == 'move_target' and 'move'
        or id == 'pan_origin' and 'pan' or id == 'spin_origin' and 'spin'
    if tab then
        local ok, message = director.Capture(tab, id == 'move_target' and 'target' or 'origin')
        if ok then Changed('pose') end
        return ok, message
    elseif id == 'move_play' or id == 'pan_play' or id == 'spin_play' then
        return director.Play(id == 'move_play' and 'move' or id == 'pan_play' and 'pan' or 'spin', false)
    elseif id == 'motion_stop' then
        return director.Stop()
    elseif id == 'move_jump_origin' or id == 'move_jump_target' then
        return director.Jump('move', id == 'move_jump_origin' and 'origin' or 'target')
    end
    if id == 'hud' and not current.IsActive() then return false, 'cinema.enable_for_hud' end
    if id == 'reset' or id == 'free' then
        local ok, message = director.Stop()
        if not ok then return false, message end
    end
    return controls.Run(id)
end

function Perform(id)
    if current and current.IsActive() then
        local ok, message = RunDrawer(id)
        Changed('action', ok, message)
        return ok, message
    end
end

function Toggle()
    if not current or not current.Key() then return false, 'cinema.map_wait' end
    local ok, message
    if current.IsActive() then
        director.Stop()
        controls.Restore()
        ok, message = current.Disable(false)
    elseif current.OwnsHooks() then
        ok, message = current.Enable()
    else
        ok, message = false, 'Another mod replaced the key map hooks'
    end
    if ok then
        LOG('[ClaretCinema] Input mode ' .. (current.IsActive() and 'ON' or 'OFF'))
    else
        WARN('[ClaretCinema] ' .. tostring(message))
    end
    Changed()
    return ok, not ok and 'cinema.switch_failed' or nil
end

function Start(isReplay)
    if current then return end
    local mapper = import('/lua/keymap/keymapper.lua')
    choices = import('/mods/ClaretCinema/modules/NativeActions.lua').Build(
        commands.Choices, mapper, isReplay, SessionIsMultiplayer(), DebugFacilitiesEnabled()
    )
    choicesById = {}
    for _, choice in ipairs(choices) do choicesById[choice.id] = choice end
    local layout = import('/mods/ClaretCinema/modules/KeyboardLayout.lua')
    local prefs = import('/lua/user/prefs.lua')
    local saved = prefs.GetFromCurrentProfile(preference)
    local legacy = prefs.GetFromCurrentProfile('ClaretCinemaHudKey')
    settings = {actions = {}}
    local occupied = {}
    if type(saved) == 'table' and layout.IsAssignable(saved.toggle) then
        settings.toggle = saved.toggle
        occupied[saved.toggle] = true
    end
    local stored = type(saved) == 'table' and type(saved.actions) == 'table' and saved.actions or {}
    for _, choice in ipairs(choices) do
        local id = choice.id
        local key = stored[id]
        if id == 'hud' and key == nil then key = (legacy == '' or layout.IsAssignable(legacy)) and legacy or 'H' end
        if id ~= 'mode' and (key == '' or layout.IsAssignable(key) and not occupied[key]) then
            settings.actions[id] = key
            if key ~= '' then occupied[key] = true end
        end
    end
    -- Only initialize a fresh profile once. Existing, damaged, or legacy
    -- preferences must never gain defaults again after a user clears a key.
    if saved == nil and legacy == nil then
        local initial = {actions = {}}
        for id, key in pairs(settings.actions) do initial.actions[id] = key end
        for id, key in pairs(defaults) do
            if not occupied[key] then initial.actions[id] = key end
        end
        local ok, message = pcall(function()
            prefs.SetToCurrentProfile(preference, initial)
            SavePreferences()
        end)
        if ok then
            settings.actions = initial.actions
        else
            pcall(prefs.SetToCurrentProfile, preference, saved)
            WARN('[ClaretCinema] Default binding initialization failed: ' .. tostring(message))
        end
    end
    controls = commands.Create()
    director = import('/mods/ClaretCinema/modules/Director.lua').Create(
        function() return GetCamera('WorldCamera') end,
        function(seconds, callback)
            ForkThread(function() WaitSeconds(seconds); callback() end)
        end,
        function(command) return ConExecute(command) end,
        function(step)
            ForkThread(function()
                while true do
                    WaitFrames(1)
                    if not step() then return end
                end
            end)
        end,
        function() return GetSystemTimeSeconds() end
    )
    local original = {Clear = IN_ClearKeyMap, Add = IN_AddKeyMapTable, Remove = IN_RemoveKeyMapTable}
    local mode = import('/mods/ClaretCinema/modules/InputMode.lua').Create(
        original,
        function(key) return string.lower(mapper.NormalizeKeyBinding(key)) end,
        {'Ctrl-Alt-F9', 'Ctrl-Alt-F8', 'Ctrl-Alt-F7'},
        Binding('Toggle'),
        ActionLayout(settings.actions),
        IsMenuAction
    )
    mode.Configure(ActionLayout(settings.actions), settings.toggle)
    local closed = false
    local function Clear()
        if closed then return original.Clear() end
        local before = mode.Key()
        local ok, message = mode.Clear()
        if ok == false then WARN('[ClaretCinema] ' .. tostring(message)) end
        Changed('bindings')
    end
    local function Add(batch)
        if closed then return original.Add(batch) end
        local before = mode.Key()
        local ok, message = mode.Add(batch)
        if ok == false then WARN('[ClaretCinema] ' .. tostring(message)) end
        if not mode.IsActive() and mode.Key() and before ~= mode.Key() then
            LOG('[ClaretCinema] Toggle: ' .. mode.Key())
        end
        Changed('bindings')
    end
    local function Remove(batch)
        if closed then return original.Remove(batch) end
        local before = mode.Key()
        local ok, message = mode.Remove(batch)
        if ok == false then WARN('[ClaretCinema] ' .. tostring(message)) end
        Changed('bindings')
    end
    function mode.OwnsHooks()
        return IN_ClearKeyMap == Clear and IN_AddKeyMapTable == Add and IN_RemoveKeyMapTable == Remove
    end

    -- The engine does not expose the installed binding table through its Lua
    -- key-map API. Observe the same writes FAF and UI mods use from the next clear.
    rawset(_G, 'IN_ClearKeyMap', Clear)
    rawset(_G, 'IN_AddKeyMapTable', Add)
    rawset(_G, 'IN_RemoveKeyMapTable', Remove)
    current = mode

    return function()
        if closed then return end
        director.Destroy()
        controls.Restore()
        local ok, message = mode.Disable(true)
        if not ok then
            WARN('[ClaretCinema] Could not restore the keyboard on teardown: ' .. tostring(message))
            return
        end
        closed = true
        if IN_ClearKeyMap == Clear then rawset(_G, 'IN_ClearKeyMap', original.Clear) end
        if IN_AddKeyMapTable == Add then rawset(_G, 'IN_AddKeyMapTable', original.Add) end
        if IN_RemoveKeyMapTable == Remove then rawset(_G, 'IN_RemoveKeyMapTable', original.Remove) end
        current, director = nil, nil
    end
end
