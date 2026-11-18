-- Integration of template eligibility rows with the isolated click dispatcher.
table.getn = function(value) return #value end
local function loadModule(path)
    local env = setmetatable({}, { __index = _G })
    assert(loadfile(path, 't', env))()
    return env
end
local templatesModule = loadModule('../mods/ClaretCore/modules/ConstructionTemplates.lua')
local actionsModule = loadModule('../mods/ClaretCore/modules/ConstructionTemplateActions.lua')

local engineer, factory = {}, {}
local currentSelection = { engineer }
local currentSources = { mobile = {}, factory = {} }
local buildable = { tower = true, power = true, factoryA = true }
local blueprintData = {
    tower = { General = { UpgradesFrom = 'none' } },
    power = { General = { UpgradesFrom = 'none' } },
    factoryA = { General = { UpgradesFrom = 'none' } },
}
local events = {}
local function deepEqual(first, second, seen)
    if type(first) ~= type(second) then return false end
    if type(first) ~= 'table' then return first == second end
    seen = seen or {}
    if seen[first] == second then return true end
    if seen[first] ~= nil then return false end
    seen[first] = second
    for key, value in pairs(first) do if not deepEqual(value, second[key], seen) then return false end end
    for key in pairs(second) do if first[key] == nil then return false end end
    return true
end
local function hasCategory(unit, category)
    if unit == engineer then return category == 'MOBILE' end
    if unit == factory then return category == 'FACTORY' end
    return false
end
local ops = {
    hasCategory = hasCategory,
    isBuildable = function(id) return buildable[id] == true end,
    isRestricted = function() return false end,
    getBlueprint = function(id) return blueprintData[id] end,
    getCurrentSelection = function() return currentSelection end,
    isUnitValid = function(unit) return unit == engineer or unit == factory end,
    validateTemplateCurrent = function(kind, sourceId, snapshot, sourceTemplate)
        local current = currentSources[kind] and currentSources[kind][sourceId]
        return current ~= nil and current == sourceTemplate and deepEqual(current, snapshot)
    end,
    validateMobileTemplate = function() return true end,
    clearActiveBuildTemplate = function() table.insert(events, 'clear'); return true end,
    startCommandMode = function(mode, args)
        table.insert(events, { kind = 'start', mode = mode, args = args })
        return true
    end,
    setActiveBuildTemplate = function(data)
        table.insert(events, { kind = 'activate', data = data })
        return true
    end,
    toggleOptions = function(kind, id, snapshot)
        table.insert(events, { kind = 'options', templateKind = kind, sourceId = id, snapshot = snapshot })
        return true
    end,
    validateFactoryCommand = function() return true end,
    issueBlueprintCommand = function(...)
        table.insert(events, { kind = 'command', args = { ... } })
        return true
    end,
}
local model = templatesModule.Create(ops)
local actions = actionsModule.Create(ops)

local mobileRecord = { name = 'Line', templateData = { 3, 2, { 'tower', 1, -1.5, 0 }, { 'power', 2, 2, 1 } } }
currentSources.mobile[1] = mobileRecord
local mobileRows = model.Build({ engineer }, { mobileRecord }, nil)
assert(mobileRows.kind == 'mobile' and #mobileRows.entries == 1)
local mobileRow = mobileRows.entries[1]
assert(mobileRow.type == 'templates' and mobileRow.sourceIndex == 1 and mobileRow.templateID == 1
    and mobileRow.sourceSnapshot.templateData[3][1] == 'tower',
    'real model emits the dispatcher entry type, stable source ID and geometry snapshot')
local ok, result = actions.Dispatch(mobileRow, { Left = true }, { kind = 'mobile', selection = currentSelection })
assert(ok and result.sourceId == 1 and result.buildingCount == 2
    and events[1] == 'clear' and events[2].kind == 'start' and events[3].kind == 'activate',
    'real mobile template row reaches its injected actions without losing geometry')

local beforeStale = #events
mobileRecord.templateData[3][3] = 10
ok = actions.Dispatch(mobileRow, { Right = true }, { kind = 'mobile', selection = currentSelection })
assert(not ok and #events == beforeStale,
    'in-place stored template changes are rejected before right-click side effects')
mobileRecord.templateData[3][3] = -1.5
currentSources.mobile[1] = nil
currentSources.mobile[2] = mobileRecord
ok = actions.Dispatch(mobileRow, { Right = true }, { kind = 'mobile', selection = currentSelection })
assert(not ok and #events == beforeStale,
    'removed/reordered mobile source is rejected without selecting a replacement by index')
currentSources.mobile[1] = mobileRecord
currentSources.mobile[2] = nil
ok, result = actions.Dispatch(mobileRow, { Right = true }, { kind = 'mobile', selection = currentSelection })
assert(ok and result.action == 'template-options' and events[#events - 1] == 'clear'
    and events[#events].kind == 'options', 'current mobile right-click opens options after source validation')

local cyclic = { name = 'Cycle', templateData = { 1, 1, { 'tower', 1, 0, 0 } } }
cyclic.metadata = cyclic
local cyclicRows = model.Build({ engineer }, { cyclic }, nil)
assert(#cyclicRows.entries == 0 and #cyclicRows.errors == 1,
    'model fails closed when the full render snapshot cannot be copied safely')

currentSelection = { factory }
local factoryRecord = { name = 'Factory', templateData = { { id = 'factoryA', count = 3 } } }
currentSources.factory[1] = factoryRecord
local factoryRows = model.Build({ factory }, nil, { factoryRecord })
assert(factoryRows.kind == 'factory' and factoryRows.entries[1].type == 'templates'
    and factoryRows.entries[1].sourceSnapshot.templateData[1].count == 3,
    'factory model provides a detached source snapshot and click discriminator')
ok, result = actions.Dispatch(factoryRows.entries[1], { Left = true },
    { kind = 'factory', selection = currentSelection })
assert(ok and result.sourceId == 1 and events[#events].kind == 'command'
    and events[#events].args[1] == 'UNITCOMMAND_BuildFactory'
    and events[#events].args[2] == 'factoryA' and events[#events].args[3] == 3,
    'real factory model row reaches ordered factory command dispatch')

print('PASS: construction template model-to-action snapshots, stale source checks and dispatch')
