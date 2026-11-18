-- Construction controller orchestration with real presentation/state models and fake views.
table.getn = function(value) return #value end
table.find = function(values, expected)
    for index, value in ipairs(values) do if value == expected then return index end end
end
local function loadModule(path)
    local env = setmetatable({}, { __index = _G })
    assert(loadfile(path, 't', env))()
    return env
end
local choicesModule = loadModule('../mods/ClaretCore/modules/ConstructionChoices.lua')
local gridModule = loadModule('../mods/ClaretCore/modules/ConstructionGridModel.lua')
local selectionModule = loadModule('../mods/ClaretCore/modules/ConstructionSelection.lua')
local queueModule = loadModule('../mods/ClaretCore/modules/ConstructionQueue.lua')
local templatesModule = loadModule('../mods/ClaretCore/modules/ConstructionTemplates.lua')
local cargoModule = loadModule('../mods/ClaretCore/modules/CargoSelection.lua')
local enhancementsModule = loadModule('../mods/ClaretCore/modules/ConstructionEnhancements.lua')
local controllerModule = loadModule('../mods/ClaretCore/modules/ConstructionController.lua')

local unitCategories = {}
local blueprintData = { build1 = { BuildIconSortPriority = 1, General = { UpgradesTo = '' } } }
local restrictedCandidates = {}
blueprintData.restrictedBuild = { BuildIconSortPriority = 2, General = { UpgradesTo = '' } }
unitCategories.build1 = { TECH1 = true }
unitCategories.restrictedBuild = { TECH1 = true }
local function hasCategory(unit, category)
    if type(unit) == 'table' then return unit.categories[category] == true end
    return unitCategories[unit] and unitCategories[unit][category] == true or false
end
local modelOps = {
    hasCategory = hasCategory,
    isAllowed = function() return true end,
    getBlueprint = function(id) return blueprintData[type(id) == 'table' and (id.blueprintId or id.id) or id] end,
    isRestricted = function(id) return restrictedCandidates[id] == true end,
    isBuildable = function(id) return id == 'build1' end,
    getBlueprintId = function(unit) return unit.blueprintId or unit.id end,
    getInstalled = function(unit) return unit.installed or {} end,
    getQueue = function(unit) return unit.enhancementQueue or {} end,
    getFuelRatio = function(unit) return unit.fuel end,
    isIdle = function(unit) return unit.idle end,
    upgradeNext = function() return nil end,
}
blueprintData.engineerBlueprint = { BlueprintId = 'engineerBlueprint', Enhancements = {
    Slots = { Back = 'Back slot', LCH = 'Left slot' },
    BackRoot = { Slot = 'Back', Icon = 'back-root' },
    BackChild = { Slot = 'Back', Icon = 'back-child', Prerequisite = 'BackRoot' },
    LCHRoot = { Slot = 'LCH', Icon = 'lch-root' },
} }
blueprintData.otherBlueprint = { BlueprintId = 'otherBlueprint', Enhancements = { Slots = {} } }
local choices = choicesModule.Create(modelOps)
local grid = gridModule.Create(modelOps)
local summary = selectionModule.Create(modelOps)
local queue = queueModule.Create()
local templates = templatesModule.Create(modelOps)
local queued = {}
local additions, removals = {}, {}
local failRemoval = false
local cargoState = cargoModule.Create({
    isQueued = function(unit) return queued[unit] == true end,
    add = function(unit) table.insert(additions, unit) end,
    remove = function(unit) if failRemoval then error('remove failure') end; table.insert(removals, unit) end,
})

local events, errors = {}, {}
local failGrid = false
local failPrimaryRender = false
local dependencies = {
    choices = choices, gridModel = {
        Build = function(units, options)
            if failGrid then
                local fatal = { id = options.selectedUnit, reason = 'selection category lookup failed', fatal = true }
                return { entries = {}, errors = { fatal }, fatalErrors = { fatal } }
            end
            return grid.Build(units, options)
        end,
    },
    selectionModel = summary, queueModel = queue, templatesModel = templates,
    enhancementsModel = enhancementsModule.Create(modelOps),
    cargoState = cargoState, army = 1, mobileTemplates = {
        { name = 'Basic', icon = 'build1', templateData = { { 'build1' } } },
        { name = 'Unavailable', icon = 'missing', templateData = { { 'missingBuild' } } },
    }, factoryTemplates = {},
    renderPrimary = function(view, mode, data, context)
        table.insert(events, { view = 'primary', mode = mode, data = data, context = context })
        if view.reenter then view.controller:SetTab('enhancement') end
        if failPrimaryRender then return false end
        return true
    end,
    renderSecondary = function(view, mode, data, context)
        table.insert(events, { view = 'secondary', mode = mode, data = data, context = context })
        return true
    end,
    onError = function(message, detail) table.insert(errors, { message = message, detail = detail }) end,
}
dependencies.primaryView = { reenter = false }
dependencies.secondaryView = {}
local controller = controllerModule.Create(dependencies)
dependencies.primaryView.controller = controller

local engineer = { id = 'engineer', categories = { MOBILE = true, ENGINEER = true, ALLUNITS = true, TECH1 = true } }
engineer.blueprintId = 'engineerBlueprint'
engineer.installed = { Back = 'BackRoot' }
engineer.enhancementQueue = { { Slot = 'Back', ID = 'BackRoot' } }
local engineer2 = { id = 'engineer2', blueprintId = 'otherBlueprint', categories = { MOBILE = true, ENGINEER = true, ALLUNITS = true, TECH1 = true } }
local passenger1, passenger2, passenger3, passenger4 = {}, {}, {}, {}
queued[passenger1] = true

restrictedCandidates.restrictedBuild = true
assert(controller:OnSelection({ 'build1', 'restrictedBuild' }, { engineer }, { passenger1, passenger2, passenger3 }))
assert(events[#events - 1].mode == 'construction' and events[#events].mode == 'queue',
    tostring(events[#events - 1].mode) .. '/' .. tostring(events[#events].mode) .. ':'
        .. tostring(errors[#errors] and errors[#errors].message) .. ':'
        .. tostring(errors[#errors] and errors[#errors].detail and errors[#errors].detail[1]
            and errors[#errors].detail[1].reason))
assert(#events[#events - 1].data == 1 and events[#events - 1].context.errors[1].id == 'restrictedBuild',
    'restricted candidate is diagnosed while valid build choices still render')
assert(controller:AppendCargo() and additions[1] == passenger2 and events[#events].mode == 'queue',
    'cargo append works on construction tab without replacing its queue view')
local afterInitial = #events
assert(not controller:OnSelection({ 'build1' }, { engineer, engineer }, { passenger1, passenger2 }))
for index = afterInitial + 1, #events do
    assert(events[index].mode ~= 'construction', 'invalid duplicate selection does not set up a build grid')
end
assert(removals[1] == passenger2 and not controller:AppendCargo(),
    'invalid selection clears owned cargo and prevents stale transport append')
assert(controller:OnSelection({ 'build1' }, { engineer }, { passenger1, passenger3 }))
failPrimaryRender = true
assert(not controller:OnSelection({ 'build1' }, { engineer }, { passenger1, passenger3 }),
    'selection update reports render failure')
failPrimaryRender = false
assert(controller:OnSelection({ 'build1' }, { engineer }, { passenger1, passenger3 }),
    'dirty view retries successfully on selection refresh')
local eventCount = #events
assert(not controller:SetTab('construction') and #events == eventCount,
    'duplicate tab selection does not rerender')
local realTemplatesModel = dependencies.templatesModel
dependencies.templatesModel = templatesModule.Create({})
assert(not controller:SetTab('templates') and events[#events - 1].mode == 'clear',
    'missing template engine operations fail closed')
dependencies.templatesModel = realTemplatesModel
assert(controller:SetTab('templates') and events[#events - 1].mode == 'templates'
    and #events[#events - 1].data == 1 and #events[#events - 1].context.errors == 1,
    'valid template renders alongside rejected-template diagnostics')
assert(controller:SetTab('selection') and events[#events - 1].mode == 'selection'
    and events[#events].mode == 'cargo', 'selection tab shows summary and attached cargo')
assert(controller:AppendCargo() and additions[2] == passenger3,
    'append skips queued passengers and selects the next cargo')
eventCount = #events
assert(not controller:AppendCargo() and #events == eventCount,
    'exhausted append produces no duplicate redraw')

local queueData = { { id = 'build1', count = 2 } }
assert(controller:OnQueueChanged(queueData), 'queue update is stored while cargo tab is active')
assert(events[#events].mode == 'cargo', 'queue updates do not replace cargo presentation')
eventCount = #events
assert(not controller:OnQueueChanged({ { id = 'build1', count = 2 } }) and #events == eventCount,
    'duplicate queue content is suppressed')

assert(controller:OnSelection({ 'build1' }, { engineer2 }, { passenger4 }))
assert(removals[2] == passenger3 and events[#events].mode == 'cargo',
    'selection changes clean only owned cargo and refresh attached rows')
assert(not cargoState:IsSelected(1), 'stale owned passenger is absent after selection change')

assert(controller:OnSelection({ 'build1' }, { engineer }, { passenger4 }),
    'enhancement tab can be evaluated for a single eligible unit')
assert(controller:SetTab('construction') and events[#events - 1].mode == 'construction')
assert(controller:OnQueueChanged({ { id = 'build1', count = 4 } })
    and events[#events].mode == 'queue', 'construction tab redraws on queue changes')
assert(controller:SetTab('enhancement') and events[#events - 1].mode == 'enhancement'
    and events[#events].mode == 'queue', 'enhancement tab renders model entries with queue secondary')
assert(events[#events - 1].context.selectedSlot == 'Back'
    and events[#events - 1].context.slots[1].id == 'Back', 'first valid enhancement slot is selected by default')
local enhancementEntries = events[#events - 1].data
assert(enhancementEntries[1].id == 'BackRoot' and enhancementEntries[1].Selected
    and enhancementEntries[1].Disabled, 'installed and queued state are reflected in slot entries')
assert(controller:SelectEnhancementSlot('LCH') and events[#events].context.selectedSlot == 'LCH'
    and events[#events].data[1].id == 'LCHRoot', 'slot selection redraws only that slot')
local sacuOne = { id = 'sacu-one', blueprintId = 'engineerBlueprint', installed = { Back = 'BackRoot' },
    categories = { MOBILE = true, ENGINEER = true, ALLUNITS = true, TECH1 = true } }
local sacuTwo = { id = 'sacu-two', blueprintId = 'engineerBlueprint',
    categories = { MOBILE = true, ENGINEER = true, ALLUNITS = true, TECH1 = true } }
assert(controller:OnSelection({ 'build1' }, { sacuOne, sacuTwo }, { passenger4 })
    and events[#events - 1].context.selectedSlot == 'Back'
    and events[#events - 1].data[1].Selected,
    'homogeneous multi SACU selection defaults to first slot and uses first unit installed state')
assert(not controller:OnSelection({ 'build1' }, { engineer, engineer2 }, { passenger4 })
    and events[#events - 1].mode == 'clear', 'mixed blueprint enhancement selection fails closed')
assert(not controller:SelectEnhancementSlot('Back'), 'failed mixed selection cannot retain stale slot data')
assert(controller:OnSelection({ 'build1' }, { engineer }, { passenger4 }),
    'valid selection recovers after mixed enhancement selection')

assert(controller:SetTab('construction'))
failGrid = true
eventCount = #events
assert(not controller:SelectTech('t2'))
assert(events[eventCount + 1].mode == 'clear' and #errors > 0,
    'model errors clear primary without rendering partial grid entries')
failGrid = false

controller:SetTab('selection')
cargoState:Toggle(1)
failRemoval = true
assert(not controller:OnSelection({ 'build1' }, { engineer }, { passenger1 }),
    'selection change fails if an owned passenger cannot be removed')
assert(not controller:AppendCargo(), 'failed cleanup cannot leave the old selection actionable')
failRemoval = false
assert(controller:OnSelection({ 'build1' }, { engineer2 }, { passenger4 }),
    'selection change can recover after cleanup succeeds')
cargoState:Toggle(1)
failRemoval = true
assert(not controller:Destroy() and not controller.destroyed and controller.teardownPending,
    'failed owned cleanup does not report teardown complete')
assert(not controller:SetTab('construction'), 'pending teardown blocks new presentation actions')
failRemoval = false
assert(controller:Destroy())
assert(removals[#removals] == passenger4, 'successful retry clears only controller-owned cargo')
eventCount = #events
assert(not controller:SetTab('construction') and not controller:OnQueueChanged({})
    and #events == eventCount, 'destroyed controller rejects future actions')
assert(not controller:Destroy(), 'destroy is idempotent')

print('PASS: construction controller tabs, enhancement slots, redraw, cargo ownership, queue updates and teardown')
