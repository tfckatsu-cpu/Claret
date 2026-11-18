-- Mock tests for explicit bindings to FAF's installed construction APIs.
table.getn = function(value) return #value end
local unit = {}
local secondUnit = {}
local factory = {}
local creator = {}
local platform = {}
function platform:GetCreator() return creator end
local passengerA = {}
local passengerB = {}
local deadPassenger = {}
function passengerA:IsDead() return false end
function passengerB:IsDead() return false end
function deadPassenger:IsDead() return true end

local selected = { unit }
local allowed = { 'ueb0101', 'ueb0102', 'restricted' }
local allowedForSelection = {}
local factoryQueue = { { id = 'ueb0101', count = 2 }, { id = 'ueb0102', count = 1 } }
local calls = {}
local categories = { MOBILE = 'MOBILE', NEEDMOBILEBUILD = 'NEEDMOBILEBUILD',
    EXTERNALFACTORY = 'EXTERNALFACTORY', FACTORY = 'FACTORY', ENGINEER = 'ENGINEER',
    STRUCTURE = 'STRUCTURE', ALLUNITS = 'ALLUNITS', LAND = 'LAND', AIR = 'AIR', NAVAL = 'NAVAL',
    SORTCONSTRUCTION = 'SORTCONSTRUCTION', SORTECONOMY = 'SORTECONOMY', SORTDEFENSE = 'SORTDEFENSE',
    SORTSTRATEGIC = 'SORTSTRATEGIC', SORTINTEL = 'SORTINTEL', SORTOTHER = 'SORTOTHER',
    TECH1 = 'TECH1', TECH2 = 'TECH2', TECH3 = 'TECH3', EXPERIMENTAL = 'EXPERIMENTAL',
    CONSTRUCTIONSORTDOWN = 'CONSTRUCTIONSORTDOWN' }
local blueprints = {
    builder = { BlueprintId = 'builder', categories = { MOBILE = true, ENGINEER = true,
        ALLUNITS = true, LAND = true, TECH1 = true }, Enhancements = { Slots = { Back = {} },
            BackBasic = { Slot = 'Back', Icon = 'back' } } },
    ueb0101 = { BlueprintId = 'ueb0101', BuildIconSortPriority = 1, General = { UpgradesFrom = 'none' },
        categories = { SORTCONSTRUCTION = true, TECH1 = true } },
    ueb0102 = { BlueprintId = 'ueb0102', StrategicIconSortPriority = 2,
        categories = { SORTECONOMY = true, TECH1 = true } },
    restricted = { BlueprintId = 'restricted', BuildIconSortPriority = 3, categories = { TECH1 = true } },
    factory = { BlueprintId = 'factory', categories = { MOBILE = true, FACTORY = true, ALLUNITS = true } },
}
local function InstallUnit(unitRef, id, unitCategories)
    unitRef.BlueprintId = id
    unitRef.Categories = unitCategories
    function unitRef:GetBlueprint() return blueprints[self.BlueprintId] end
    function unitRef:GetBlueprintId() return self.BlueprintId end
    function unitRef:IsDead() return false end
    function unitRef:GetFuelRatio() return 0.8 end
    function unitRef:IsIdle() return true end
    function unitRef:GetEntityId() return self.BlueprintId .. '_entity' end
    function unitRef:HasUnloadCommandQueuedUp() return false end
end
InstallUnit(unit, 'builder', { MOBILE = true, ENGINEER = true, ALLUNITS = true, LAND = true, TECH1 = true })
InstallUnit(secondUnit, 'builder', { MOBILE = true, ENGINEER = true, ALLUNITS = true, LAND = true, TECH1 = true })
InstallUnit(factory, 'factory', { MOBILE = true, FACTORY = true, ALLUNITS = true })
local attachedUnits = { passengerA, passengerB, passengerA, deadPassenger }
local attachedSelection = selected
local needsMobile = { mobile = false, needsMobile = true }
local mobileCargo = { [passengerA] = true, [passengerB] = true, [deadPassenger] = true }
local selectedExtra = {}
local engine = {
    import = function(path)
        if path == '/lua/game.lua' then return { IsRestricted = function(id) return id == 'restricted' end } end
        if path == '/lua/ui/game/commandmode.lua' then
            return { StartCommandMode = function(...) calls.commandMode = { ... }; return true end }
        end
        error('unexpected import ' .. tostring(path))
    end,
    categories = categories,
    __blueprints = blueprints,
    modules = {},
    GetSelectedUnits = function() return selected end,
    GetFocusArmy = function() return 1 end,
    GetUnitCommandData = function(value)
        assert(type(value) == 'table', 'buildable query receives selection')
        allowedForSelection = {}
        for _, item in ipairs(allowed) do allowedForSelection[item] = true end
        if #value > 1 then allowedForSelection.ueb0102 = nil end
        return {}, {}, 'buildable-category'
    end,
    EntityCategoryContains = function(category, value)
        if category == 'buildable-category' then return allowedForSelection[value] == true end
        if type(value) == 'table' and value.GetBlueprint then
            local blueprint = value:GetBlueprint()
            return blueprint and blueprint.categories and blueprint.categories[category] == true or false
        end
        return type(value) == 'string' and blueprints[value] ~= nil
            and blueprints[value].categories and blueprints[value].categories[category] == true
            or category == 'NEEDMOBILEBUILD' and needsMobile[value] == true
            or category == 'EXTERNALFACTORY' and value == 'external'
    end,
    GetAttachedUnitsList = function(selection)
        assert(selection == attachedSelection, 'cargo query receives the whole selected unit list')
        return attachedUnits
    end,
    EntityCategoryFilterDown = function(category, units)
        assert(category == 'MOBILE')
        local result = {}
        for _, value in ipairs(units) do
            if mobileCargo[value] then table.insert(result, value) end
        end
        return result
    end,
    EntityCategoryGetUnitList = function(category)
        assert(category == 'buildable-category')
        local result = {}
        for _, id in ipairs(allowed) do
            if allowedForSelection[id] then table.insert(result, id) end
        end
        return result
    end,
    IssueBlueprintCommand = function(...) calls.command = { ... }; return true end,
    IssueBlueprintCommandToUnits = function(...) calls.unitsCommand = { ... }; return true end,
    SelectUnits = function(value) calls.selection = value; return true end,
    IncreaseBuildCountInQueue = function(...) calls.increase = { ... }; return true end,
    DecreaseBuildCountInQueue = function(...) calls.decrease = { ... }; return true end,
    SetCurrentFactoryForQueueDisplay = function(value)
        assert(value == factory, 'factory queue provider receives selected factory')
        return factoryQueue
    end,
    AddToSessionExtraSelectList = function(value) selectedExtra[value] = true; return true end,
    RemoveFromSessionExtraSelectList = function(value) selectedExtra[value] = nil; return true end,
}
local env = setmetatable({ categories = categories, __blueprints = blueprints }, { __index = _G })
assert(loadfile('../mods/ClaretCore/modules/ConstructionEngineAdapters.lua', 't', env))()
local adapters = env.Create(engine)

local buildables = adapters.getBuildables(selected)
assert(#buildables == 2 and buildables[1] == 'ueb0101' and buildables[2] == 'ueb0102',
    'buildables come from FAF category calculation and exclude restrictions')
assert(adapters.getSelection()[1] == unit, 'selection maps to GetSelectedUnits')
assert(adapters.getBlueprintId(unit) == 'builder', 'unit blueprint identity uses GetBlueprint')
assert(adapters.actions.isUnitValid(unit), 'live UserUnit passes validity check')
assert(adapters.actions.isBuildable('ueb0101'), 'buildability uses current selection categories')
assert(adapters.actions.isRestricted('restricted', 1), 'restriction query maps to lua/game.lua')
assert(not adapters.actions.needsMobileBuild('mobile'), 'ordinary MOBILE unit does not trigger placement mode')
assert(adapters.actions.needsMobileBuild('needsMobile'), 'NEEDMOBILEBUILD unit triggers placement mode')
assert(adapters.actions.isExternalFactory('external'), 'external factory classification maps to category query')
local cargo = adapters.getCargo(selected)
assert(#cargo == 2 and cargo[1] == passengerA and cargo[2] == passengerB,
    'cargo keeps unique, live mobile passengers from the attached-unit list')
assert(#adapters.getCargo({}) == 0, 'empty selection has empty cargo')
assert(#adapters.getCargo(nil) == 0, 'nil selection has empty cargo')
attachedUnits = nil
assert(#adapters.getCargo(selected) == 0, 'nil attached-unit result has empty cargo')
attachedUnits = {}
assert(#adapters.getCargo(selected) == 0, 'selected non-transport units have empty cargo')
attachedUnits = {}
attachedSelection = { unit, platform }
assert(#adapters.getCargo(attachedSelection) == 0,
    'empty attached list for a mixed non-transport selection has empty cargo')
-- The actual attached list query receives whichever selected transports FAF finds.
attachedUnits = { passengerA, passengerB }
attachedSelection = { platform, platform }
engine.GetAttachedUnitsList = function(selection)
    assert(selection == attachedSelection and #selection == 2,
        'multiple selected transports are queried together')
    return attachedUnits
end
cargo = adapters.getCargo(attachedSelection)
assert(#cargo == 2, 'cargo combines selected transports and removes duplicate passengers')
assert(adapters.actions.getCreator(platform) == creator, 'factory creator uses UserUnit:GetCreator')
assert(adapters.actions.issueBlueprintCommand('UNITCOMMAND_BuildFactory', 'ueb0101', 1)
    and calls.command[2] == 'ueb0101', 'factory orders bind to IssueBlueprintCommand')
assert(adapters.actions.issueBlueprintCommandToUnits({ unit }, 'UNITCOMMAND_BuildFactory', 'ueb0101', 1)
    and calls.unitsCommand[1][1] == unit, 'external factory orders bind to IssueBlueprintCommandToUnits')
assert(adapters.actions.startCommandMode('build', { name = 'ueb0101' })
    and calls.commandMode[1] == 'build', 'placement binds to commandmode.StartCommandMode')
assert(adapters.actions.increaseBuildCountInQueue(1, 5) and calls.increase[2] == 5,
    'queue increment binds to FAF queue API')
assert(adapters.actions.decreaseBuildCountInQueue(1, 1) and calls.decrease[1] == 1,
    'queue decrement binds to FAF queue API')
assert(#adapters.missing >= 5, 'unsupported session-owned capabilities remain explicit')
