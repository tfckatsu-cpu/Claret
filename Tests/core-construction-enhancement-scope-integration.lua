-- Integration test for enhancement actions using the real ignore-scope manager.
table.getn = function(value) return #value end
local function loadModule(path)
    local env = setmetatable({}, { __index = _G })
    assert(loadfile(path, 't', env))()
    return env
end
local scopeModule = loadModule('../mods/ClaretCore/modules/SelectionIgnoreScope.lua')
local actionsModule = loadModule('../mods/ClaretCore/modules/ConstructionEnhancementActions.lua')

local underlyingIgnore, setterCalls = false, {}
local manager = assert(scopeModule.Create(function(value)
    underlyingIgnore = value
    table.insert(setterCalls, value)
end, false))

local unit = {}
local currentSelection, currentSlot = { unit }, 'Back'
local selected = { unit }
local installed = { Back = 'Root' }
local queue = {}
local commands, dialog, failCommand = {}, nil, nil
local enhancements = {
    Slots = { Back = 'Back slot' },
    Root = { Slot = 'Back' },
    Mid = { Slot = 'Back', Prerequisite = 'Root' },
    Target = { Slot = 'Back', Prerequisite = 'Mid' },
    Conflict = { Slot = 'Back' },
}
local blueprint = { BlueprintId = 'worker', Enhancements = enhancements }
local actionOps = {
    getCurrentSelection = function() return currentSelection end,
    getCurrentSlot = function() return currentSlot end,
    isUnitValid = function(value) return value == unit end,
    getBlueprintId = function() return 'worker' end,
    getBlueprint = function() return blueprint end,
    isRestricted = function() return false end,
    getInstalled = function() return installed end,
    getQueue = function() return queue end,
    isCurrentlyUpgrading = function() return false end,
    isIdle = function() return true end,
    getCommandQueue = function() return {} end,
    clearEnhancementQueue = function() queue = {}; return true end,
    acquireIgnoreSelectionScope = manager.AcquireIgnoreSelectionScope,
    releaseIgnoreSelectionScope = manager.ReleaseIgnoreSelectionScope,
    selectUnits = function(units) selected = units; return true end,
    issueCommand = function(command, args, clean)
        if failCommand == args.Enhancement then error('mock engine failure') end
        table.insert(commands, { command = command, args = args, clean = clean })
        return true
    end,
    requestConfirmation = function(onYes, onNo, details)
        dialog = { onYes = onYes, onNo = onNo, details = details }
        return true
    end,
    onComplete = function(ok, result) dialog.completion = { ok = ok, result = result } end,
}
local actions = actionsModule.Create(actionOps)
local entry = { type = 'enhancement', id = 'Target', slot = 'Back',
    enhTable = enhancements.Target, TooltipOnly = false, Disabled = false }
local function dispatch(modifiers)
    return actions.Dispatch(entry, modifiers, { selection = currentSelection, slot = currentSlot })
end

-- A regular append action takes a nested lease and restores the real external state.
local initialSetterCalls = #setterCalls
local ok, result = dispatch({ Left = true, Shift = true })
assert(ok and result.orderCount == 2 and #commands == 2
    and commands[1].args.Enhancement == 'Mid' and commands[2].args.Enhancement == 'Target',
    'actual enhancement dispatcher issues the real-model prerequisite chain')
assert(not underlyingIgnore and selected[1] == unit and #setterCalls == initialSetterCalls + 2
    and setterCalls[initialSetterCalls + 1] == true and setterCalls[initialSetterCalls + 2] == false,
    'action lease toggles then restores the actual ignore-scope manager')

-- Command failure still releases the actual scope and restores selection.
commands, failCommand = {}, 'Target'
local beforeFailure = #setterCalls
ok, result = dispatch({ Left = true, Shift = true })
assert(not ok and result.selectionRestored and result.ignoreRestored
    and selected[1] == unit and not underlyingIgnore
    and setterCalls[beforeFailure + 1] == true and setterCalls[beforeFailure + 2] == false,
    'engine error releases the real scope and restores the original selection')
failCommand = nil

-- While the asynchronous conflict dialog is open, another owner requests true.
installed.Back = 'Conflict'
queue = {}
ok, result = dispatch({ Left = true, Shift = true })
assert(ok and result.status == 'confirmation-pending' and dialog and not underlyingIgnore,
    'conflict confirmation defers acquiring a scope until a choice is made')
assert(manager.SetIgnoreSelection(true) and underlyingIgnore,
    'external caller can request ignore while confirmation is pending')
local beforeApproval = #setterCalls
dialog.onYes()
assert(dialog.completion and dialog.completion.ok and underlyingIgnore
    and #setterCalls == beforeApproval,
    'confirmed action releases its nested lease without clearing the new external request')
assert(manager.SetIgnoreSelection(false) and not underlyingIgnore,
    'external state can be cleared after the enhancement action completes')

-- An outer owner keeps ignore active through the action's inner lease.
installed.Back = 'Root'
local outer = assert(manager.AcquireIgnoreSelectionScope())
assert(underlyingIgnore)
local beforeNested = #setterCalls
ok, result = dispatch({ Left = true, Shift = true })
assert(ok and result.orderCount == 2 and underlyingIgnore and #setterCalls == beforeNested,
    "nested action scope never resets the active outer owner's state")
assert(manager.ReleaseIgnoreSelectionScope(outer) and not underlyingIgnore,
    'outer owner release restores its external baseline')

-- Teardown restores the remembered external state and makes late actions fail closed.
outer = assert(manager.AcquireIgnoreSelectionScope())
assert(manager.SetIgnoreSelection(false))
assert(manager.Destroy() and not underlyingIgnore,
    'manager cleanup releases outstanding owned scopes to the latest external state')
local commandsBeforeDestroyed = #commands
ok = dispatch({ Left = true, Shift = true })
assert(not ok and #commands == commandsBeforeDestroyed,
    'dispatcher rejects actions after its scope manager is destroyed')
assert(not manager.ReleaseIgnoreSelectionScope(outer), 'destroy invalidates outstanding scope tokens')

print('PASS: enhancement actions preserve external ignore state with real scope manager')
