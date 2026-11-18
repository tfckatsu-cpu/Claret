-- Mock tests for the optional bridge to ReUI.Construction's cargo mark.
local unit, other = {}, {}
local engineSelectionCalls = 0
local markCalls, refreshCalls = {}, 0
local active = true
local destroyed = false
local handlerError, contextError, markError, refreshError

local context = {
    cargoUnits = { unit },
    IsActive = function() return active end,
    MarkUnit = function(self, passenger)
        if markError then error('mark exploded') end
        markCalls[#markCalls + 1] = passenger
    end,
}
local handler = { _context = context }
local panel = {
    GetHandler = function(self, name)
        if handlerError then error('handler exploded') end
        assert(name == 'TransportCargo')
        return handler
    end,
    Refresh = function()
        if refreshError then error('refresh exploded') end
        refreshCalls = refreshCalls + 1
    end,
}
ReUI = { UI = { Global = { Construction = panel } } }
IsDestroyed = function() return destroyed end
GetSelectedUnits = function() engineSelectionCalls = engineSelectionCalls + 1; return {} end
AddToSessionExtraSelectList = function() engineSelectionCalls = engineSelectionCalls + 1 end
RemoveFromSessionExtraSelectList = function() engineSelectionCalls = engineSelectionCalls + 1 end

local env = setmetatable({}, { __index = _G })
assert(loadfile('../mods/ClaretCore/modules/ReUICargoIndicator.lua', 't', env))()
local function NoMark(message)
    local beforeMarks, beforeRefresh = #markCalls, refreshCalls
    local ok = env.Mark(unit)
    assert(not ok, message)
    assert(#markCalls == beforeMarks and refreshCalls == beforeRefresh,
        'failure does not mark or refresh')
end

assert(env.Mark(unit), 'active ReUI cargo passenger is marked')
assert(markCalls[1] == unit and refreshCalls == 1, 'mark uses the exact passenger and refreshes ReUI')
assert(engineSelectionCalls == 0, 'bridge makes no engine selection-list calls')

active = false
NoMark('inactive ReUI cargo context fails gracefully')
active = true
context.cargoUnits = { other }
NoMark('passenger identity mismatch fails gracefully')
context.cargoUnits = { unit }

ReUI.UI.Global.Construction = nil
NoMark('missing panel fails gracefully')
ReUI.UI.Global.Construction = panel

destroyed = true
NoMark('destroyed panel fails gracefully')
destroyed = false

handlerError = true
NoMark('handler errors fail gracefully')
handlerError = false
contextError = true
handler._context = setmetatable({}, { __index = function() error('context exploded') end })
NoMark('context errors fail gracefully')
handler._context = context

markError = true
local okMark, reasonMark = env.Mark(unit)
assert(not okMark and string.find(reasonMark, 'passenger mark failed', 1, true),
    'mark exceptions are reported')
markError = false
refreshError = true
local okRefresh, reasonRefresh = env.Mark(unit)
assert(not okRefresh and string.find(reasonRefresh, 'panel refresh failed', 1, true),
    'refresh exceptions are reported')
refreshError = false
assert(engineSelectionCalls == 0, 'bridge never adds, removes or reads engine selection')
