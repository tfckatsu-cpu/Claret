-- Mock-only tests for engineer/mobile and factory template click dispatch.
table.getn = function(value) return #value end
local env = setmetatable({}, { __index = _G })
assert(loadfile('../mods/ClaretCore/modules/ConstructionTemplateActions.lua', 't', env))()

local engineer, factory = {}, {}
local currentSelection = { engineer }
local validUnits = { [engineer] = true, [factory] = true }
local blueprints = {
    tower = { General = { UpgradesFrom = 'none' } },
    power = { General = { UpgradesFrom = 'none' } },
    factoryA = { General = { UpgradesFrom = 'none' } },
    factoryB = { General = { UpgradesFrom = 'none' } },
    upgradeA = { General = { UpgradesFrom = 'factoryA' } },
    upgradeB = { General = { UpgradesFrom = 'upgradeA' } },
    restricted = { General = { UpgradesFrom = 'none' } },
}
local calls, buildable, restricted, allowUpgradeAfter = {}, {}, {}, true
local rejectedFactoryCommand
local currentSources = { mobile = {}, factory = {} }
local function sameValue(first, second, seen)
    if type(first) ~= type(second) then return false end
    if type(first) ~= 'table' then return first == second end
    seen = seen or {}
    if seen[first] == second then return true end
    if seen[first] ~= nil then return false end
    seen[first] = second
    for key, value in pairs(first) do if not sameValue(value, second[key], seen) then return false end end
    for key in pairs(second) do if first[key] == nil then return false end end
    return true
end
local function cloneValue(value, seen)
    if type(value) ~= 'table' then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local result = {}
    seen[value] = result
    for key, item in pairs(value) do result[cloneValue(key, seen)] = cloneValue(item, seen) end
    return result
end
buildable.tower, buildable.power, buildable.factoryA, buildable.factoryB = true, true, true, true
buildable.upgradeA, buildable.upgradeB = false, false
local ops = {
    getCurrentSelection = function() return currentSelection end,
    isUnitValid = function(unit) return validUnits[unit] == true end,
    hasCategory = function(unit, category)
        if unit == engineer then return category == 'MOBILE' end
        if unit == factory then return category == 'FACTORY' end
        return false
    end,
    getBlueprint = function(id) return blueprints[id] end,
    validateTemplateCurrent = function(kind, sourceId, snapshot, sourceTemplate)
        local current = currentSources[kind] and currentSources[kind][sourceId]
        return current ~= nil and current == sourceTemplate and sameValue(current, snapshot)
    end,
    isRestricted = function(id) return restricted[id] == true end,
    isBuildable = function(id) return buildable[id] == true end,
    canBuildAfter = function(id, priorEntries)
        return allowUpgradeAfter and ((id == 'upgradeA' and priorEntries[1] and priorEntries[1].id == 'factoryA')
            or (id == 'upgradeB' and priorEntries[2] and priorEntries[2].id == 'upgradeA'))
    end,
    validateMobileTemplate = function(data, selection, firstId)
        assert(firstId == data[3][1] and selection[1] == engineer)
        return true
    end,
    clearActiveBuildTemplate = function() table.insert(calls, { kind = 'clear' }); return true end,
    startCommandMode = function(...)
        table.insert(calls, { kind = 'start', args = { ... } }); return true
    end,
    setActiveBuildTemplate = function(data)
        table.insert(calls, { kind = 'activate', data = data })
        data[3][3] = 999 -- Prove the dispatcher gives the engine an owned copy.
        return true
    end,
    toggleOptions = function(kind, sourceId, template)
        table.insert(calls, { kind = 'options', templateKind = kind, sourceId = sourceId, template = template })
        template.name = 'changed by view callback'
        return true
    end,
    validateFactoryCommand = function(command, id, count, selection)
        assert(selection[1] == factory)
        table.insert(calls, { kind = 'validate', command = command, id = id, count = count })
        return id ~= rejectedFactoryCommand
    end,
    issueBlueprintCommand = function(...)
        table.insert(calls, { kind = 'command', args = { ... } })
        return true
    end,
}
local dispatcher = env.Create(ops)
local mobileTemplate = {
    name = 'Engineer layout',
    templateData = { 4, 3, { 'tower', 1, -2.5, 0 }, { 'power', 2, 1, 3.5 } },
}
currentSources.mobile[17] = mobileTemplate
local mobileEntry = { type = 'templates', template = mobileTemplate, sourceIndex = 17,
    sourceSnapshot = cloneValue(mobileTemplate) }
local function click(entry, kind, modifiers, selection)
    return dispatcher.Dispatch(entry, modifiers, { kind = kind, selection = selection or currentSelection })
end

local ok, result = click(mobileEntry, 'mobile', { Left = true })
assert(ok and result.action == 'activate-mobile-template' and result.sourceId == 17
    and result.firstBlueprintId == 'tower' and result.buildingCount == 2,
    'mobile template click preserves stable source identity and building geometry')
assert(calls[1].kind == 'clear' and calls[2].kind == 'start'
    and calls[2].args[1] == 'build' and calls[2].args[2].name == 'tower'
    and calls[3].kind == 'activate', 'mobile template follows native clear, build-mode, activate order')
assert(mobileTemplate.templateData[3][3] == -2.5,
    'engine callback mutation does not alter the stored mobile template geometry')

local beforeOptions = #calls
ok, result = click(mobileEntry, 'mobile', { Right = true })
assert(ok and result.action == 'template-options' and result.sourceId == 17
    and calls[beforeOptions + 1].kind == 'clear'
    and calls[beforeOptions + 2].kind == 'options',
    'mobile right-click explicitly clears active layout then opens template options')
assert(mobileTemplate.name == 'Engineer layout', 'options callback receives a copy, not stored template data')

local factoryTemplate = { name = 'Factory queue', templateData = {
    { id = 'factoryA', count = 2 }, { id = 'upgradeA', count = 4 }, { id = 'upgradeB', count = 1 },
} }
currentSources.factory['saved-factory-9'] = factoryTemplate
local factoryEntry = { type = 'templates', template = factoryTemplate, templateID = 'saved-factory-9',
    sourceSnapshot = cloneValue(factoryTemplate) }
currentSelection = { factory }
allowUpgradeAfter = true
local beforeFactory = #calls
ok, result = click(factoryEntry, 'factory', { Left = true })
assert(ok and result.action == 'queue-factory-template' and result.sourceId == 'saved-factory-9'
    and result.commandCount == 3, 'factory template executes validated entries in stored order')
assert(calls[beforeFactory + 1].kind == 'validate' and calls[beforeFactory + 2].kind == 'validate'
    and calls[beforeFactory + 3].kind == 'validate' and calls[beforeFactory + 4].kind == 'command',
    'all factory commands are preflighted before execution')
assert(calls[beforeFactory + 4].args[1] == 'UNITCOMMAND_BuildFactory'
    and calls[beforeFactory + 4].args[2] == 'factoryA'
    and calls[beforeFactory + 4].args[3] == 2,
    'factory build commands preserve saved counts and native argument shape')
assert(calls[beforeFactory + 5].args[1] == 'UNITCOMMAND_Upgrade'
    and calls[beforeFactory + 5].args[2] == 'upgradeA'
    and calls[beforeFactory + 5].args[3] == 1 and calls[beforeFactory + 5].args[4] == false
    and calls[beforeFactory + 6].args[2] == 'upgradeB',
    'factory upgrade commands use native one-count upgrade signature and preserve order')

local beforeFactoryOptions = #calls
ok, result = click(factoryEntry, 'factory', { Right = true })
assert(ok and result.action == 'template-options' and calls[beforeFactoryOptions + 1].kind == 'options',
    'factory right-click opens options without clearing active mobile layout')

currentSelection = { engineer }
local function assertNoSourceSideEffect(entry, kind, modifiers, reason)
    local before = #calls
    local success = click(entry, kind, modifiers, currentSelection)
    assert(not success and #calls == before, reason)
end
local savedMobileSource = currentSources.mobile[17]
currentSources.mobile[17] = nil
currentSources.mobile[18] = savedMobileSource
assertNoSourceSideEffect(mobileEntry, 'mobile', { Right = true },
    'reordered template source cannot clear active template on right-click')
currentSources.mobile[18] = nil
assertNoSourceSideEffect(mobileEntry, 'mobile', { Right = true },
    'deleted template source cannot clear active template on right-click')
currentSources.mobile[18] = savedMobileSource
currentSources.mobile[17] = { name = 'replacement', templateData = { 1, 1, { 'tower', 1, 0, 0 } } }
assertNoSourceSideEffect(mobileEntry, 'mobile', { Right = true },
    'replacement at stale source index cannot open options')
currentSources.mobile[17] = { name = 'changed', templateData = { 4, 3, { 'power', 1, 0, 0 } } }
assertNoSourceSideEffect(mobileEntry, 'mobile', { Right = true },
    'changed template content is rejected before right-click clear')
currentSources.mobile[17] = savedMobileSource
local savedMobileName = mobileTemplate.name
mobileTemplate.name = 'changed in place after draw'
assertNoSourceSideEffect(mobileEntry, 'mobile', { Right = true },
    'in-place mutation is rejected against immutable presentation snapshot')
mobileTemplate.name = savedMobileName

local cyclicTemplate = { templateData = { 1, 1, { 'tower', 1, 0, 0 } } }
cyclicTemplate.metadata = cyclicTemplate
currentSources.mobile[19] = cyclicTemplate
assertNoSourceSideEffect({ type = 'templates', sourceIndex = 19, template = cyclicTemplate,
    sourceSnapshot = cloneValue(cyclicTemplate) }, 'mobile',
    { Right = true }, 'cyclic source is rejected before right-click clear')
currentSources.mobile[19] = nil

local savedFactorySource = currentSources.factory['saved-factory-9']
currentSources.factory['saved-factory-9'] = nil
currentSources.factory['saved-factory-10'] = savedFactorySource
currentSelection = { factory }
assertNoSourceSideEffect(factoryEntry, 'factory', { Right = true },
    'deleted or reordered factory template cannot open stale options')
currentSources.factory['saved-factory-9'] = { name = 'changed', templateData = { { id = 'factoryB', count = 1 } } }
assertNoSourceSideEffect(factoryEntry, 'factory', { Left = true },
    'changed factory template is rejected before any queue commands')
currentSources.factory['saved-factory-9'] = savedFactorySource

local function countIssuedCommands()
    local count = 0
    for _, call in ipairs(calls) do if call.kind == 'command' then count = count + 1 end end
    return count
end

local function failsWithoutCommands(template, kind, modifiers, selection, reason)
    local before = countIssuedCommands()
    local success = click(template, kind, modifiers, selection)
    assert(not success and countIssuedCommands() == before, reason)
end

local restrictedTemplate = { type = 'templates', sourceIndex = 1, template = {
    templateData = { 2, 2, { 'tower', 1, 0, 0 }, { 'restricted', 2, 1, 1 } },
} }
restrictedTemplate.sourceSnapshot = cloneValue(restrictedTemplate.template)
currentSources.mobile[1] = restrictedTemplate.template
currentSelection = { engineer }
restricted.restricted = true
failsWithoutCommands(restrictedTemplate, 'mobile', { Left = true }, currentSelection,
    'restricted later mobile entry prevents all side effects')
restricted.restricted = nil
currentSources.mobile[1] = nil

local invalidFactoryTemplate = { type = 'templates', sourceIndex = 2, template = {
    templateData = { { id = 'factoryA', count = 1 }, { id = 'upgradeA', count = 1 },
        { id = 'upgradeB', count = 1 } },
} }
invalidFactoryTemplate.sourceSnapshot = cloneValue(invalidFactoryTemplate.template)
currentSources.factory[2] = invalidFactoryTemplate.template
currentSelection = { factory }
allowUpgradeAfter = false
failsWithoutCommands(invalidFactoryTemplate, 'factory', { Left = true }, currentSelection,
    'unproven factory upgrade sequence issues no partial queue')
allowUpgradeAfter = true
currentSources.factory[2] = nil
local issuedBeforeValidationFailure = countIssuedCommands()
rejectedFactoryCommand = 'upgradeB'
ok = click(factoryEntry, 'factory', { Left = true }, currentSelection)
assert(not ok and countIssuedCommands() == issuedBeforeValidationFailure,
    'rejection of a later command during preflight issues no earlier factory commands')
rejectedFactoryCommand = nil

failsWithoutCommands(mobileEntry, 'mobile', { Left = true }, { engineer, factory },
    'stale live selection is rejected without commands')
currentSelection = { engineer }
local malformed = { type = 'templates', sourceIndex = 3, template = { templateData = { 2, 2, { 'tower' } } } }
malformed.sourceSnapshot = cloneValue(malformed.template)
currentSources.mobile[3] = malformed.template
failsWithoutCommands(malformed, 'mobile', { Left = true }, currentSelection,
    'malformed geometry is rejected without commands')
currentSources.mobile[3] = nil
failsWithoutCommands(mobileEntry, 'factory', { Left = true }, currentSelection,
    'selection kind mismatch is rejected')

print('PASS: construction template action validation, geometry, options and ordered factory commands')
