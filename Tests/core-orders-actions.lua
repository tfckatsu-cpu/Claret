-- Mock-only behavior checks for the independent FAF3840 order dispatcher.
table.getn = table.getn or function(value) return #value end
math.mod = math.mod or math.fmod

local catalogEnv = setmetatable({}, { __index = _G })
assert(loadfile('../mods/ClaretCore/modules/OrdersCatalog.lua', 't', catalogEnv))()
local catalog = catalogEnv.Create()
local definitions = catalog:GetDefinitions()
local actionsEnv = setmetatable({}, { __index = _G })
assert(loadfile('../mods/ClaretCore/modules/OrdersActions.lua', 't', actionsEnv))()

local selected = { {}, {} }
local events = {}
local replay, observer, available = false, false, true
local ops = {
    getLiveSelection = function() return selected end,
    isReplay = function() return replay end,
    isObserver = function() return observer end,
    isAvailable = function(id, units)
        events[#events + 1] = { 'available', id, units }
        return available
    end,
    startCommandMode = function(mode, data) events[#events + 1] = { 'start', mode, data } end,
    endCommandMode = function(cancel) events[#events + 1] = { 'end', cancel } end,
    toggleAttackPriority = function(units, toggleMode) events[#events + 1] = { 'priority', units, toggleMode } end,
    loadIntoTransports = function(clear) events[#events + 1] = { 'load', clear } end,
    dock = function(clear) events[#events + 1] = { 'dock', clear } end,
    dockDamaged = function(threshold, clear) events[#events + 1] = { 'damaged', threshold, clear } end,
    stop = function(units, shift) events[#events + 1] = { 'stop', units, shift } end,
}
local dispatcher = assert(actionsEnv.Create(ops))
local function row(id, checked, toggleMode)
    return { id = id, sourceId = 'catalog:' .. id, source = definitions[id], checked = checked, toggleMode = toggleMode }
end
local function dispatch(id, key, checked, shift)
    return dispatcher:Dispatch(row(id, checked), selected, {
        Left = key == 'left', Right = key == 'right', Shift = shift == true,
    })
end
local function lastEvent() return events[#events] end

-- Consume actual catalog rows (including nested behaviorKey) and preserve IDs.
local ok, result = dispatch('RULEUCC_Move', 'left', false)
assert(ok and result.sourceId == 'catalog:RULEUCC_Move' and result.orderId == 'RULEUCC_Move')
assert(lastEvent()[1] == 'start' and lastEvent()[2] == 'order'
    and lastEvent()[3].name == 'RULEUCC_Move')
ok = dispatch('RULEUCC_Move', 'left', true)
assert(ok and lastEvent()[1] == 'end' and lastEvent()[2] == true)
ok = dispatch('AttackMove', 'left', false)
assert(ok and lastEvent()[1] == 'start' and lastEvent()[3].name == 'RULEUCC_Script'
    and lastEvent()[3].AbilityName == 'AttackMove' and lastEvent()[3].TaskName == 'AttackMove'
    and lastEvent()[3].Cursor == 'ATTACK_MOVE')
local attackRight = row('RULEUCC_Attack', false, 3)
ok = dispatcher:Dispatch(attackRight, selected, { Left = false, Right = true, Shift = false })
assert(ok and lastEvent()[1] == 'priority' and lastEvent()[2] == selected and lastEvent()[3] == 3)

-- Transport and Dock preserve the stock Shift argument meanings.
ok = dispatch('RULEUCC_Transport', 'left', false)
assert(ok and lastEvent()[1] == 'start' and lastEvent()[3].name == 'RULEUCC_Transport')
ok = dispatch('RULEUCC_Transport', 'right', false, false)
assert(ok and lastEvent()[1] == 'load' and lastEvent()[2] == true)
ok = dispatch('RULEUCC_Transport', 'right', false, true)
assert(ok and lastEvent()[1] == 'load' and lastEvent()[2] == false)
ok = dispatch('RULEUCC_Dock', 'left', false, false)
assert(ok and lastEvent()[1] == 'dock' and lastEvent()[2] == true)
ok = dispatch('RULEUCC_Dock', 'left', false, true)
assert(ok and lastEvent()[1] == 'dock' and lastEvent()[2] == false)
ok = dispatch('RULEUCC_Dock', 'right', false, false)
assert(ok and lastEvent()[1] == 'damaged' and lastEvent()[2] == 0.9 and lastEvent()[3] == true)
ok = dispatch('RULEUCC_Dock', 'right', false, true)
assert(ok and lastEvent()[1] == 'damaged' and lastEvent()[2] == 0.9 and lastEvent()[3] == false)
-- Native event modifier tables may omit unset flags; nil has the false meaning.
ok = dispatcher:Dispatch(row('RULEUCC_Move', false), selected, { Left = true })
assert(ok and lastEvent()[1] == 'start', 'omitted optional modifier keys normalize to false')
ok = dispatcher:Dispatch(row('RULEUCC_Transport'), selected, { Right = true })
assert(ok and lastEvent()[1] == 'load' and lastEvent()[2] == true,
    'omitted Shift remains the unshifted native behavior')

ok = dispatch('RULEUCC_Stop', 'left', false, true)
assert(ok and lastEvent()[1] == 'stop' and lastEvent()[2] == selected and lastEvent()[3] == true,
    'stop semantics are delegated explicitly, including Shift')

-- Invalid context is rejected before availability/command side effects.
local actionCount = #events
available = false
ok = dispatch('RULEUCC_Move', 'left', false)
assert(not ok and #events == actionCount + 1 and lastEvent()[1] == 'available',
    'restricted/unavailable order never executes')
available = true
local stale = { {}, {} }
ok = dispatcher:Dispatch(row('RULEUCC_Move'), stale, { Left = true, Right = false, Shift = false })
assert(not ok and #events == actionCount + 1, 'stale displayed selection is rejected before availability')
replay = true
ok = dispatch('RULEUCC_Move', 'left', false)
assert(not ok and #events == actionCount + 1, 'replay is rejected before availability')
replay, observer = false, true
ok = dispatch('RULEUCC_Move', 'left', false)
assert(not ok and #events == actionCount + 1, 'observer is rejected before availability')
observer = false

local malformed = dispatcher:Dispatch(true, selected, { Left = true, Right = false, Shift = false })
assert(not malformed, 'non-table order rows fail without throwing')
local noButton = dispatcher:Dispatch(row('RULEUCC_Move'), selected, { Left = false, Right = false, Shift = false })
assert(not noButton, 'ambiguous/no-button input is rejected')
local both = dispatcher:Dispatch(row('RULEUCC_Move'), selected, { Left = true, Right = true, Shift = false })
assert(not both, 'simultaneous buttons are rejected')
local unsupported = row('RULEUCC_Dive')
ok = dispatcher:Dispatch(unsupported, selected, { Left = true, Right = false, Shift = false })
assert(not ok, 'specialized native behaviors fail explicitly instead of approximating')
local disabled = row('RULEUCC_Move', false)
disabled.disabled = true
ok = dispatcher:Dispatch(disabled, selected, { Left = true })
assert(not ok, 'disabled/read-only model rows cannot dispatch')
local first, second = selected[1], selected[2]
selected = { first, first }
ok = dispatcher:Dispatch(row('RULEUCC_Move', false), { first, second }, { Left = true })
assert(not ok, 'duplicate live selection members do not match the displayed selection')
selected = { first, second }
assert(#events == actionCount + 1, 'validation failures add only the explicit availability probe')

-- Required callbacks and operation failures are explicit.
local partialOps = {
    getLiveSelection = ops.getLiveSelection, isAvailable = ops.isAvailable,
    isReplay = ops.isReplay, isObserver = ops.isObserver,
}
local partial = assert(actionsEnv.Create(partialOps))
ok = partial:Dispatch(row('RULEUCC_Move', false), selected, { Left = true, Right = false, Shift = false })
assert(not ok, 'missing command-mode API fails closed')
local throwingOps = {}
for key, value in pairs(ops) do throwingOps[key] = value end
throwingOps.startCommandMode = function() error('mock command failure') end
local throwing = assert(actionsEnv.Create(throwingOps))
ok = throwing:Dispatch(row('RULEUCC_Move', false), selected, { Left = true, Right = false, Shift = false })
assert(not ok, 'engine operation errors are surfaced')

print('PASS: FAF3840 orders action slice validates live context and dispatches exact injected arguments')
