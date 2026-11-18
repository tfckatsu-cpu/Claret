-- Mock-only tests for the standalone construction interaction dispatcher.
table.getn = function(value) return #value end
local env = setmetatable({}, { __index = _G })
assert(loadfile('../mods/ClaretCore/modules/ConstructionActions.lua', 't', env))()

local unitA, unitB, unitC = {}, {}, {}
local platform, creator = {}, {}
local currentSelection = { unitA, unitB, unitC }
local currentQueue = {}
local validUnits = { [unitA] = true, [unitB] = true, [unitC] = true, [platform] = true, [creator] = true }
local blueprints = {
    structure = { General = { UpgradesFrom = 'none' }, Physics = { MotionType = 'RULEUMT_None' } },
    mobile = { General = { UpgradesFrom = 'none' }, Physics = { MotionType = 'RULEUMT_Surf' } },
    base = { BlueprintId = 'base', General = { UpgradesFrom = 'none', UpgradesTo = 'mid' }, Physics = { MotionType = 'RULEUMT_None' } },
    mid = { BlueprintId = 'mid', General = { UpgradesFrom = 'base' }, Physics = { MotionType = 'RULEUMT_None' } },
    target = { BlueprintId = 'target', General = { UpgradesFrom = 'mid' }, Physics = { MotionType = 'RULEUMT_None' } },
    restricted = { General = { UpgradesFrom = 'none' }, Physics = { MotionType = 'RULEUMT_None' } },
    noPhysics = { General = { UpgradesFrom = 'none' } },
    cycleTarget = { BlueprintId = 'cycleTarget', General = { UpgradesFrom = 'cycleParent' }, Physics = { MotionType = 'RULEUMT_None' } },
    cycleParent = { BlueprintId = 'cycleParent', General = { UpgradesFrom = 'cycleTarget' }, Physics = { MotionType = 'RULEUMT_None' } },
    cycleUnit = { BlueprintId = 'cycleParent', General = { UpgradesFrom = 'cycleTarget', UpgradesTo = 'cycleTarget' }, Physics = { MotionType = 'RULEUMT_None' } },
}
local cycleUnit = {}
validUnits[cycleUnit] = true
local unitBlueprints = { [unitA] = blueprints.base, [unitB] = blueprints.base,
    [unitC] = blueprints.base, [creator] = blueprints.base, [platform] = blueprints.base }
unitBlueprints[cycleUnit] = blueprints.cycleUnit
local commands, selected, resets = {}, nil, 0
local allowReset = false
local ops = {
    improvedDeselection = true,
    getCurrentSelection = function() return currentSelection end,
    getCurrentQueue = function() return currentQueue end,
    isUnitValid = function(unit) return validUnits[unit] == true end,
    selectUnits = function(units) selected = units; return true end,
    getBlueprint = function(id) return blueprints[id] end,
    getUnitBlueprint = function(unit) return unitBlueprints[unit] end,
    getUnitBlueprintId = function(unit) return unitBlueprints[unit].BlueprintId end,
    isRestricted = function(id) return id == 'restricted' end,
    isBuildable = function() return true end,
    needsMobileBuild = function() return false end,
    isExternalFactory = function(unit) return unit == platform end,
    getCreator = function() return creator end,
    issueBlueprintCommand = function(...)
        table.insert(commands, { kind = 'selected', args = { ... } })
        return true
    end,
    issueBlueprintCommandToUnits = function(...)
        table.insert(commands, { kind = 'units', args = { ... } })
        return true
    end,
    startCommandMode = function(...)
        table.insert(commands, { kind = 'placement', args = { ... } })
        return true
    end,
    decreaseBuildCountInQueue = function(...)
        table.insert(commands, { kind = 'decrease', args = { ... } })
        return true
    end,
    increaseBuildCountInQueue = function(...)
        table.insert(commands, { kind = 'increase', args = { ... } })
        return true
    end,
    validateQueueReset = function() return allowReset end,
    resetQueues = function() resets = resets + 1; return true end,
}
local dispatcher = env.Create(ops)
local function dispatch(data, modifiers, selection, queue)
    if queue ~= nil then currentQueue = queue end
    return dispatcher.Dispatch(data, modifiers, { selection = selection or currentSelection, queue = queue })
end

local ok, result = dispatch({ type = 'unitstack', units = { unitA, unitB } }, { Left = true }, currentSelection)
assert(ok and result.action == 'select-units' and selected[1] == unitA and selected[2] == unitB,
    'left-click unitstack selects its units in input order')
ok, result = dispatch({ type = 'unitstack', units = { unitA, unitB } }, { Right = true, Shift = true }, currentSelection)
assert(ok and result.removedCount == 1 and selected[1] == unitB and selected[2] == unitC,
    'Shift-right-click removes one matching unit and keeps remaining selection order')
ok = dispatch({ type = 'unitstack', units = { unitA, unitB } }, { Right = true, Ctrl = true }, currentSelection)
assert(ok and selected[1] == unitC, 'Ctrl-right-click removes up to five matching units')
ok, result = dispatch({ type = 'unitstack', units = { unitA, unitB } },
    { Right = true, Ctrl = true, Shift = true }, currentSelection)
assert(ok and result.removedCount == 2 and #selected == 1 and selected[1] == unitC,
    'Shift-Ctrl-right-click caps removal at ten units and never removes unrelated units')
ok, result = dispatch({ type = 'unitstack', units = { unitA, unitB } }, { Right = true }, currentSelection)
assert(ok and result.removedCount == 2 and #selected == 1 and selected[1] == unitC,
    'unmodified right-click removes the whole unitstack')

ok, result = dispatch({ type = 'item', id = 'mobile' }, { Left = true, Shift = true }, currentSelection)
assert(ok and result.action == 'queue-mobile-unit' and result.count == 5
    and commands[#commands].args[1] == 'UNITCOMMAND_BuildFactory'
    and commands[#commands].args[2] == 'mobile' and commands[#commands].args[3] == 5,
    'Shift-left-click queues five mobile units using the native command signature')
ok, result = dispatch({ type = 'item', id = 'structure' }, { Left = true }, currentSelection)
assert(ok and result.action == 'place-structure' and commands[#commands].kind == 'placement'
    and commands[#commands].args[1] == 'build' and commands[#commands].args[2].name == 'structure',
    'stationary build item enters build placement mode')
currentSelection = { unitA }
ok, result = dispatch({ type = 'item', id = 'target' }, { Left = true }, currentSelection)
assert(ok and result.action == 'upgrade' and #result.chain == 2
    and result.chain[1] == 'mid' and result.chain[2] == 'target',
    'upgrade clicks issue the validated chain from selected base toward target')
assert(commands[#commands - 1].args[1] == 'UNITCOMMAND_Upgrade'
    and commands[#commands - 1].args[2] == 'mid' and commands[#commands].args[2] == 'target',
    'upgrade commands retain order and native arguments')

currentSelection = { platform }
ok, result = dispatch({ type = 'item', id = 'mobile' }, { Left = true }, currentSelection)
assert(ok and result.action == 'queue-mobile-unit' and result.units[1] == creator
    and commands[#commands].kind == 'units' and commands[#commands].args[1][1] == creator,
    'external factory orders route through the attached creator')
ok, result = dispatch({ type = 'item', id = 'mobile' }, { Right = true, Ctrl = true }, currentSelection,
    { { id = 'structure', count = 1 }, { id = 'mobile', count = 8 } })
assert(ok and result.action == 'reduce-queue' and result.index == 2 and result.count == 5
    and commands[#commands].args[1] == 2 and commands[#commands].args[2] == 5,
    'Ctrl-right-click reduces the matching queue stack by five')
local beforeQueue = #commands
ok = dispatch({ type = 'item', id = 'mobile' }, { Right = true }, currentSelection,
    { { id = 'mobile', count = 1 }, { id = 'mobile', count = 1 } })
assert(not ok and #commands == beforeQueue, 'duplicate queue IDs fail closed as ambiguous')
ok = dispatch({ type = 'item', id = 'mobile' }, { Right = true }, currentSelection,
    { { id = 'mobile', count = 0 } })
assert(not ok and #commands == beforeQueue, 'malformed queue counts fail closed')
local mixedQueue = {
    { type = 'enhancementqueue', id = 'enhancement-unit', enhancement = {} },
    { id = 'mobile', count = 4 }, { id = 'mobile', count = 3 }, { id = 'structure', count = 1 },
}
ok, result = dispatch({ type = 'queuestack', id = 'mobile', position = 1 },
    { Left = true, Shift = true }, currentSelection, mixedQueue)
assert(ok and result.action == 'increase-queue' and result.index == 1 and result.count == 5
    and commands[#commands].kind == 'increase' and commands[#commands].args[1] == 1,
    'queue stack left click uses native logical position through enhancement rows')
ok, result = dispatch({ type = 'queuestack', id = 'mobile', position = 1 },
    { Right = true, Ctrl = true }, currentSelection, mixedQueue)
assert(ok and result.action == 'reduce-queue' and result.index == 1 and result.count == 5
    and commands[#commands].kind == 'decrease',
    'queue stack right click reduces by five at the same native logical position')
ok = dispatcher.Dispatch({ type = 'queuestack', id = 'mobile', position = 2 }, { Right = true },
    { selection = currentSelection, queue = mixedQueue, dragging = false })
assert(not ok, 'stale queue position is rejected when it maps to a different displayed stack')
ok, result = dispatcher.Dispatch({ type = 'queuestack', id = 'mobile', position = 2 }, { Right = true },
    { selection = currentSelection, queue = mixedQueue, dragging = true })
assert(ok and result.index == 2, 'drag display position keeps adjacent equal queue entries separate')
currentQueue = { { id = 'mobile', count = 2 } }
ok = dispatcher.Dispatch({ type = 'queuestack', id = 'mobile', position = 1 }, { Right = true },
    { selection = currentSelection, queue = mixedQueue })
assert(not ok, 'stale display queue snapshots fail closed before queue mutation')
currentQueue = mixedQueue

local beforeAlt = #commands
ok = dispatch({ type = 'item', id = 'structure' }, { Left = true, Alt = true }, currentSelection)
assert(not ok and resets == 0 and #commands == beforeAlt, 'Alt reset is rejected without explicit validation')
allowReset = true
ok, result = dispatch({ type = 'item', id = 'structure' }, { Left = true, Alt = true }, currentSelection)
assert(ok and resets == 1 and result.action == 'place-structure',
    'validated Alt reset callback runs before the requested command')

local beforeInvalidAlt = resets
currentSelection = { cycleUnit }
ok = dispatch({ type = 'item', id = 'cycleTarget' }, { Left = true, Alt = true }, currentSelection)
assert(not ok and resets == beforeInvalidAlt, 'invalid upgrade cycle is rejected before Alt queue reset')
currentSelection = { unitA }
ok = dispatch({ type = 'item', id = 'noPhysics' }, { Left = true, Alt = true }, currentSelection)
assert(not ok and resets == beforeInvalidAlt, 'missing motion metadata is rejected before Alt queue reset')
currentSelection = { platform }
local badCreatorOps = {}
for key, value in pairs(ops) do badCreatorOps[key] = value end
badCreatorOps.getCreator = function() return nil end
local badCreatorDispatcher = env.Create(badCreatorOps)
ok = badCreatorDispatcher.Dispatch({ type = 'item', id = 'mobile' }, { Left = true, Alt = true },
    { selection = currentSelection })
assert(not ok and resets == beforeInvalidAlt, 'missing ex-factory creator is rejected before Alt queue reset')
currentSelection = { unitA }
local missingCommandOps = {}
for key, value in pairs(ops) do missingCommandOps[key] = value end
missingCommandOps.issueBlueprintCommand = nil
local missingCommandDispatcher = env.Create(missingCommandOps)
ok = missingCommandDispatcher.Dispatch({ type = 'item', id = 'mobile' }, { Left = true, Alt = true },
    { selection = currentSelection })
assert(not ok and resets == beforeInvalidAlt, 'missing build callback is rejected before Alt queue reset')

local beforeStale = #commands
local stale = { type = 'item', id = 'mobile' }
currentSelection = { unitA }
ok = dispatch(stale, { Left = true }, { unitA, unitB })
assert(not ok and #commands == beforeStale, 'stale selection snapshot issues no commands')
currentSelection = { unitA, unitB, unitC }
ok = dispatch({ type = 'enhancement', id = 'Enhancement' }, { Left = true }, currentSelection)
assert(not ok and #commands == beforeStale, 'enhancement action remains explicitly unsupported')
ok = dispatch({ type = 'templates', template = {} }, { Left = true }, currentSelection)
assert(not ok and #commands == beforeStale, 'template action remains explicitly unsupported')
ok = dispatch({ type = 'item', id = 'missing' }, { Left = true }, currentSelection)
assert(not ok and #commands == beforeStale, 'unavailable blueprints fail closed')
ok = dispatch({ type = 'item', id = 'restricted' }, { Left = true }, currentSelection)
assert(not ok and #commands == beforeStale, 'restricted build items never reach command callbacks')
ok = dispatch({ type = 'item', id = 'mobile' }, { Left = true, Right = true }, currentSelection)
assert(not ok and #commands == beforeStale, 'ambiguous mouse-button state is rejected')

local noBuildOps = {}
for key, value in pairs(ops) do noBuildOps[key] = value end
noBuildOps.needsMobileBuild = nil
local incomplete = env.Create(noBuildOps)
ok = incomplete.Dispatch({ type = 'item', id = 'mobile' }, { Left = true },
    { selection = currentSelection, queue = {} })
assert(not ok and #commands == beforeStale, 'missing mobile-build classifier fails closed')

print('PASS: construction action validation, selection, queue, build, upgrade and external factory dispatch')
