-- Mock-only tests for the standalone enhancement action dispatcher.
table.getn = function(value) return #value end
local env = setmetatable({}, { __index = _G })
assert(loadfile('../mods/ClaretCore/modules/ConstructionEnhancementActions.lua', 't', env))()

local unitA, unitB, mixedUnit = {}, {}, {}
local currentSelection, currentSlot = { unitA }, 'Back'
local selected, ignoreSelection = { unitA }, false
local validUnits = { [unitA] = true, [unitB] = true, [mixedUnit] = true }
local installed = { [unitA] = { Back = 'BackRoot' }, [unitB] = { Back = 'OldBack' }, [mixedUnit] = {} }
local queues = { [unitA] = {}, [unitB] = {}, [mixedUnit] = {} }
local upgrading, idle, commandQueues = {}, {}, {}
local restricted = {}
local enhancements = {
    Slots = { Back = 'Back slot' },
    BackRoot = { Slot = 'Back' },
    BackMid = { Slot = 'Back', Prerequisite = 'BackRoot' },
    BackTarget = { Slot = 'Back', Prerequisite = 'BackMid' },
    OldBack = { Slot = 'Back' },
    OtherBack = { Slot = 'Back' },
}
local blueprint = { BlueprintId = 'acu', Enhancements = enhancements }
local otherBlueprint = { BlueprintId = 'other', Enhancements = enhancements }
local events, dialog, completions = {}, nil, {}
local ignoreScopeSerial = 0
local rejectIgnoreScope = false
local failEnhancement
local ops = {
    getCurrentSelection = function() return currentSelection end,
    getCurrentSlot = function() return currentSlot end,
    isUnitValid = function(unit) return validUnits[unit] == true end,
    getBlueprintId = function(unit) return unit == mixedUnit and 'other' or 'acu' end,
    getBlueprint = function(id) return id == 'acu' and blueprint or otherBlueprint end,
    isRestricted = function(id) return restricted[id] == true end,
    getInstalled = function(unit) return installed[unit] end,
    getQueue = function(unit) return queues[unit] end,
    isCurrentlyUpgrading = function(unit) return upgrading[unit] == true end,
    isIdle = function(unit) return idle[unit] ~= false end,
    getCommandQueue = function(unit) return commandQueues[unit] or {} end,
    clearEnhancementQueue = function(unit)
        table.insert(events, { kind = 'clear-queue', unit = unit })
        queues[unit] = {}
        return true
    end,
    acquireIgnoreSelectionScope = function()
        if rejectIgnoreScope then return false end
        ignoreScopeSerial = ignoreScopeSerial + 1
        local token = { previous = ignoreSelection, serial = ignoreScopeSerial }
        ignoreSelection = true
        table.insert(events, { kind = 'ignore', value = true, phase = 'acquire', token = token })
        return token
    end,
    releaseIgnoreSelectionScope = function(token)
        if type(token) ~= 'table' then return false end
        ignoreSelection = token.previous
        table.insert(events, { kind = 'ignore', value = ignoreSelection, phase = 'release', token = token })
        return true
    end,
    selectUnits = function(units)
        selected = units
        table.insert(events, { kind = 'select', units = units })
        return true
    end,
    issueCommand = function(command, args, clean)
        if failEnhancement == args.Enhancement then error('mock command failure') end
        table.insert(events, { kind = 'command', command = command, args = args, clean = clean })
        return true
    end,
    requestConfirmation = function(onYes, onNo, details)
        dialog = { onYes = onYes, onNo = onNo, details = details }
        table.insert(events, { kind = 'confirm', details = details })
        return true
    end,
    onComplete = function(ok, result) table.insert(completions, { ok = ok, result = result }) end,
}
local dispatcher = env.Create(ops)
local targetEntry = { type = 'enhancement', id = 'BackTarget', slot = 'Back',
    enhTable = enhancements.BackTarget, TooltipOnly = false, Disabled = false }
local function click(entry, modifiers, selection)
    return dispatcher.Dispatch(entry, modifiers, { selection = selection or currentSelection, slot = currentSlot })
end
local function clearEvents()
    events, dialog = {}, nil
end
local function ordersSince(index)
    local result = {}
    for eventIndex = index + 1, #events do
        local event = events[eventIndex]
        if event.kind == 'command' then table.insert(result, event.args.Enhancement) end
    end
    return result
end

-- A queued prerequisite advances the chain and Shift appends without cleaning.
currentSelection = { unitA }
installed[unitA] = { Back = 'BackRoot' }
queues[unitA] = { { Slot = 'Back', ID = 'BackMid' } }
clearEvents()
local before = #events
local ok, result = click(targetEntry, { Left = true, Shift = true })
assert(ok and result.status == 'queued' and result.orderCount == 1
    and #ordersSince(before) == 1 and ordersSince(before)[1] == 'BackTarget',
    'append mode emits only enhancement steps after installed and queued prerequisites')
assert(events[1].value == true and events[2].kind == 'select'
    and events[3].kind == 'command' and events[3].clean == false,
    'Shift preserves the queue and all script commands append')
assert(selected[1] == unitA and not ignoreSelection,
    'successful command path restores the prior unit selection and ignore flag')

-- Native clean flags are suppressed when an active Script command already leads the queue.
queues[unitA] = {}
upgrading[unitA] = true
idle[unitA] = false
commandQueues[unitA] = { { type = 'Script' } }
clearEvents()
ok, result = click(targetEntry, { Left = true })
assert(ok and result.orderCount == 2 and events[1].value == true
    and events[2].kind == 'select' and events[3].kind == 'command'
    and events[3].clean == false and events[4].clean == false,
    'clean click preserves native active-Script append behavior while upgrading')
for _, event in ipairs(events) do
    assert(event.kind ~= 'clear-queue', 'currently upgrading units retain their enhancement queue')
end
upgrading[unitA], idle[unitA], commandQueues[unitA] = nil, nil, nil

ignoreSelection = true -- Another UI component owns an outer ignore-selection scope.
currentSelection = { unitA }
selected = { unitA }
installed[unitA] = { Back = 'BackRoot' }
queues[unitA] = {}
clearEvents()
ok, result = click(targetEntry, { Left = true, Shift = true })
assert(ok and ignoreSelection and events[#events].phase == 'release'
    and events[#events].value == true,
    'dispatcher releases its scope without clearing a pre-existing ignore state')
ignoreSelection = false

rejectIgnoreScope = true
clearEvents()
ok, result = click(targetEntry, { Left = true, Shift = true })
assert(not ok and #events == 0 and selected[1] == unitA,
    'unavailable ignore scope fails before selection or queue side effects')
rejectIgnoreScope = false

-- Normal click asks before replacing another installed enhancement.
currentSelection = { unitB }
installed[unitB] = { Back = 'OldBack' }
queues[unitB] = {}
clearEvents()
ok, result = click(targetEntry, { Left = true })
assert(ok and result.status == 'confirmation-pending' and events[1].kind == 'confirm'
    and #ordersSince(0) == 0, 'conflicting installed enhancement is never destroyed before approval')
local yes = dialog.onYes
local beforeYes = #events
yes()
local yesOrders = ordersSince(beforeYes)
assert(#yesOrders == 4 and yesOrders[1] == 'OldBackRemove' and yesOrders[2] == 'BackRoot'
    and yesOrders[3] == 'BackMid' and yesOrders[4] == 'BackTarget',
    'approval issues removal then full prerequisite chain in native order')
assert(events[beforeYes + 1].kind == 'ignore' and events[beforeYes + 2].kind == 'clear-queue'
    and events[beforeYes + 3].units[1] == unitB
    and selected[1] == unitB and not ignoreSelection,
    'clean mode clears enhancement queue and selection state is restored after confirmation')
assert(completions[#completions].ok, 'async confirmation completion reports successful issue')

-- Declining matches native OrderEnhancement(clean, false): other eligible units proceed.
currentSelection = { unitA, unitB }
installed[unitA] = { Back = 'BackRoot' }
installed[unitB] = { Back = 'OldBack' }
queues[unitA], queues[unitB] = {}, {}
clearEvents()
ok, result = click(targetEntry, { Left = true, Shift = true })
assert(ok and result.status == 'confirmation-pending', 'mixed conflict selection asks once')
local no = dialog.onNo
local beforeNo = #events
no()
local noOrders = ordersSince(beforeNo)
assert(#noOrders == 2 and noOrders[1] == 'BackMid' and noOrders[2] == 'BackTarget',
    'declining skips only the conflicting unit and retains eligible unit orders')
assert(selected[1] == unitA and selected[2] == unitB and not ignoreSelection
    and completions[#completions].ok and completions[#completions].result.skippedConflicts == 1,
    'decline completion restores the original multi-selection and reports skipped conflicts')

-- Async approval revalidates selection, slot, target and conflict state.
currentSelection = { unitB }
installed[unitB] = { Back = 'OldBack' }
queues[unitB] = {}
clearEvents()
ok = click(targetEntry, { Left = true, Shift = true })
local staleYes = dialog.onYes
local beforeStale = #events
currentSelection = { unitA }
staleYes()
assert(#ordersSince(beforeStale) == 0 and completions[#completions].ok == false,
    'selection changes during confirmation prevent stale orders')

currentSelection = { unitB }
installed[unitB] = { Back = 'OldBack' }
clearEvents()
ok = click(targetEntry, { Left = true, Shift = true })
local staleSlot = dialog.onYes
local beforeStaleSlot = #events
currentSlot = 'LCH'
staleSlot()
assert(#ordersSince(beforeStaleSlot) == 0 and completions[#completions].ok == false,
    'slot changes during confirmation prevent stale orders')
currentSlot = 'Back'

-- Already installed or queued targets are a safe no-op, even on clean click.
currentSelection = { unitA }
installed[unitA] = { Back = 'BackTarget' }
queues[unitA] = { { Slot = 'Back', ID = 'BackTarget' } }
clearEvents()
ok, result = click(targetEntry, { Left = true })
assert(ok and result.status == 'no-op' and #events == 0,
    'already installed and queued target does not clear unrelated work or reissue')

-- Incompatible queued work, mixed blueprints, stale slot, restrictions and malformed chains fail closed.
clearEvents()
ok = dispatcher.Dispatch(true, { Left = true }, { selection = currentSelection, slot = currentSlot })
assert(not ok and #events == 0, 'non-table action entry fails gracefully without indexing')
installed[unitA] = { Back = 'BackRoot' }
queues[unitA] = { { Slot = 'Back', ID = 'OtherBack' } }
clearEvents()
ok = click(targetEntry, { Left = true, Shift = true })
assert(not ok and #events == 0, 'incompatible queued enhancement blocks append')
queues[unitA] = {}
ok = click(targetEntry, { Left = true, Shift = true }, { unitA, mixedUnit })
assert(not ok and #events == 0, 'mixed blueprint selection fails before commands')
currentSlot = 'LCH'
ok = click(targetEntry, { Left = true, Shift = true })
assert(not ok and #events == 0, 'slot changed since rendering fails closed')
currentSlot = 'Back'
restricted.BackMid = true
ok = click(targetEntry, { Left = true, Shift = true })
assert(not ok and #events == 0, 'restricted prerequisite blocks entire chain')
restricted.BackMid = nil
enhancements.BackMid.Prerequisite = 'BackTarget'
ok = click(targetEntry, { Left = true, Shift = true })
assert(not ok and #events == 0, 'cyclic prerequisite chain fails before commands')
enhancements.BackMid.Prerequisite = 'BackRoot'

-- Engine failure still restores selection and ignore-selection state.
currentSelection = { unitA, unitB }
selected = { unitA, unitB }
ignoreSelection = true
installed[unitA] = { Back = 'BackRoot' }
installed[unitB] = { Back = 'BackRoot' }
queues[unitA], queues[unitB] = {}, {}
failEnhancement = 'BackTarget'
clearEvents()
ok, result = click(targetEntry, { Left = true, Shift = true })
assert(not ok and result.selectionRestored and result.ignoreRestored and result.partial
    and selected[1] == unitA and selected[2] == unitB and ignoreSelection,
    'engine command failure restores original selection and pre-existing ignore state')
failEnhancement = nil
ignoreSelection = false

print('PASS: construction enhancement action chains, confirmation, queue modes and cleanup')
