-- Read-only enhancement slot/dependency presentation tests.
table.getn = function(value) return #value end
table.find = function(values, expected)
    for index, value in ipairs(values or {}) do if value == expected then return index end end
end
local module = setmetatable({}, { __index = _G })
assert(loadfile('../mods/ClaretCore/modules/ConstructionEnhancements.lua', 't', module))()

local unit = { BlueprintId = 'uas0301' }
local sameBlueprintUnit = { BlueprintId = 'uas0301' }
local differentBlueprintUnit = { BlueprintId = 'uel0001' }
local function enh(slot, prerequisite, icon)
    return { Slot = slot, Prerequisite = prerequisite, Icon = icon }
end
local enhancements = {
    Slots = { RCH = {}, Back = {}, LCH = {} },
    backA = enh('Back', nil, 'a'),
    backB = enh('Back', 'backA', 'b'),
    backC = enh('Back', 'backA', 'c'),
    backRoot2 = enh('Back', nil, 'd'),
    backCycle1 = enh('Back', 'backCycle2', 'e'),
    backCycle2 = enh('Back', 'backCycle1', 'f'),
    backOrphan = enh('Back', 'missingParent', 'g'),
    backRestricted = enh('Back', nil, 'h'),
    backRestrictedChild = enh('Back', 'backRestricted', 'i'),
    backRemove = enh('Back', nil, 'remove'),
    lRoot = enh('LCH', nil, 'j'),
    lChild = enh('LCH', 'lRoot', 'k'),
    lGrandchild = enh('LCH', 'lChild', 'l'),
    rRoot = enh('RCH', nil, 'm'),
}
local blueprint = { BlueprintId = 'uas0301', Enhancements = enhancements }
local installed = { Back = 'backA', LCH = 'lChild' }
local installedForSecondSacu = { Back = 'backRoot2' }
local queued = {
    { Slot = 'Back', ID = 'backA' },
    { Slot = 'LCH', ID = 'otherL' },
    { Slot = 'RCH', ID = 'oldEnhancementRemove' },
}
local restrictedIds = { backRestricted = true }
local queueCalls = 0
local ops = {
    getBlueprint = function() return blueprint end,
    getBlueprintId = function(selected) return selected.BlueprintId end,
    getInstalled = function(selected)
        return selected == sameBlueprintUnit and installedForSecondSacu or installed
    end,
    getQueue = function() queueCalls = queueCalls + 1; return queued end,
    isRestricted = function(id) return restrictedIds[id] == true end,
}
local model = module.Create(ops)
local result = model.Build({ unit })
assert(result.unitID == 'uas0301' and #result.fatalErrors == 0)
assert(#result.slots == 3 and result.slots[1].id == 'Back'
    and result.slots[2].id == 'LCH' and result.slots[3].id == 'RCH',
    'known enhancement slots use stable stock default order')

local function findEntry(slot, id)
    for _, row in ipairs(slot.entries) do
        if row.type == 'enhancement' and row.id == id then return row end
    end
end
local back = result.slots[1]
local backA = findEntry(back, 'backA')
local backB = findEntry(back, 'backB')
local backC = findEntry(back, 'backC')
local root2 = findEntry(back, 'backRoot2')
assert(backA and backA.Selected and backA.Disabled, 'installed option is selected and conflicting queue state disables same root')
assert(backB and not backB.Disabled and backC and not backC.Disabled,
    'queued prerequisite is compatible with dependent branch options')
assert(root2 and root2.Disabled, 'incompatible same-slot queue item disables another root')
assert(not findEntry(back, 'backRestricted') and not findEntry(back, 'backRestrictedChild'),
    'restricted enhancements and dependents are withheld')
assert(not findEntry(back, 'backCycle1') and not findEntry(back, 'backCycle2')
    and not findEntry(back, 'backOrphan'), 'cyclic and missing prerequisite chains are withheld')

local function countType(rows, kind)
    local count = 0
    for _, row in ipairs(rows) do if row.type == kind then count = count + 1 end end
    return count
end
assert(countType(back.entries, 'arrow') == 2 and countType(back.entries, 'spacer') == 1,
    'branch arrows and root separators are emitted without a trailing spacer')
local lch = result.slots[2]
assert(findEntry(lch, 'lRoot').Disabled and findEntry(lch, 'lChild').Disabled
    and findEntry(lch, 'lGrandchild').Disabled, 'incompatible queued slot entry disables its dependency chain')
assert(countType(lch.entries, 'arrow') == 2 and countType(lch.entries, 'spacer') == 0)
assert(not findEntry(result.slots[3], 'rRoot').Disabled,
    'removal queue records do not disable another enhancement')

assert(backA.source == enhancements.backA and backA.enhTable == enhancements.backA
    and backA.sourceIndex ~= nil and enhancements.backA.ID == nil and enhancements.backA.UnitID == nil,
    'presentation retains source identity without annotating source blueprint')
assert(queued[1].ID == 'backA' and installed.Back == 'backA', 'installed and queue input are not mutated')

local beforeMultiQueueCalls = queueCalls
local multi = model.Build({ unit, sameBlueprintUnit })
assert(#multi.fatalErrors == 0 and multi.unitID == 'uas0301' and queueCalls == beforeMultiQueueCalls,
    'homogeneous SACU selection skips enhancement queue lookup')
local multiBackA = findEntry(multi.slots[1], 'backA')
local multiRoot2 = findEntry(multi.slots[1], 'backRoot2')
assert(multiBackA and multiBackA.Selected and not multiBackA.Disabled
    and multiRoot2 and not multiRoot2.Selected,
    'homogeneous selection uses installed state from the first SACU only')
local noQueueOps = {
    getBlueprint = ops.getBlueprint, getBlueprintId = ops.getBlueprintId,
    getInstalled = ops.getInstalled, isRestricted = ops.isRestricted,
}
assert(#module.Create(noQueueOps).Build({ unit, sameBlueprintUnit }).fatalErrors == 0,
    'queue callback is not required for homogeneous multi-unit selection')

local mixed = model.Build({ unit, differentBlueprintUnit })
assert(#mixed.slots == 0 and #mixed.fatalErrors == 1,
    'mixed unit selection is rejected instead of borrowing first-unit enhancements')
local missingApi = module.Create({}).Build({ unit })
assert(#missingApi.slots == 0 and #missingApi.fatalErrors == 1,
    'missing engine-facing operations fail closed')
local malformedQueue = module.Create({
    getBlueprint = ops.getBlueprint, getBlueprintId = ops.getBlueprintId,
    getInstalled = ops.getInstalled, getQueue = function() return { false } end,
    isRestricted = ops.isRestricted,
}).Build({ unit })
assert(#malformedQueue.slots == 0 and #malformedQueue.fatalErrors == 1,
    'malformed queue state cannot make options appear enabled')

print('PASS: enhancement slots, branches, restrictions, installed and queued state, malformed prerequisites')
