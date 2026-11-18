-- Runs one engineer-selection step while the assigned key remains held.
-- The caller resolves the active FAF key mapping and supplies its key name.

local INTERVAL = 0.3
local activeByKey = {}

local function StopState(state)
    if not state or not state.active then return end
    state.active = false
    if activeByKey[state.key] == state then
        activeByKey[state.key] = nil
    end
end

local function Run(state)
    while state.active do
        WaitSeconds(INTERVAL)
        if not IsKeyDown(state.key) then break end

        local ok = pcall(state.step)
        if not ok then break end

    end
    StopState(state)
end

function Active(keyName)
    local state=activeByKey[keyName]
    return state and state.active or false
end

-- Start(keyName, step) starts a single guarded hold loop per key.
-- Returns a cancellation function; repeated Start calls on that key are ignored.
function Start(keyName, step)
    if type(keyName) ~= 'string' or keyName == '' or type(step) ~= 'function' then
        return nil, 'Expected an assigned key name and a step function'
    end

    local previous = activeByKey[keyName]
    if previous and previous.active then return previous.cancel end

    local state = {key = keyName, step = step, active = true}
    state.cancel = function() StopState(state) end
    activeByKey[keyName] = state
    state.thread = ForkThread(Run, state)
    return state.cancel
end

-- Stop(keyName) cancels one loop; StopAll() is suitable for UI teardown.
function Stop(keyName)
    StopState(activeByKey[keyName])
end

function StopAll()
    local states = {}
    for _, state in pairs(activeByKey) do table.insert(states, state) end
    for _, state in ipairs(states) do StopState(state) end
end

