-- Construction grid ordering and restricted-upgrade presentation tests.
table.getn = function(value) return #value end
local module = setmetatable({}, { __index = _G })
assert(loadfile('../mods/ClaretCore/modules/ConstructionGridModel.lua', 't', module))()

local categories, blueprints, restricted = {}, {}, {}
local function define(id, cats, priority, general)
    local categorySet = {}
    for _, category in ipairs(cats or {}) do categorySet[category] = true end
    categories[id] = categorySet
    blueprints[id] = priority == false and {} or { BuildIconSortPriority = priority, General = general }
    return id
end
local function hasCategory(id, category)
    return categories[id] and categories[id][category] == true or false
end
local model = module.Create({
    hasCategory = hasCategory,
    getBlueprint = function(id) return blueprints[id] end,
    isRestricted = function(id, army) return restricted[id] == true end,
})

local overlap = define('overlap', { 'SORTCONSTRUCTION', 'SORTECONOMY' }, 20)
local economyFirst = define('economyFirst', { 'SORTECONOMY' }, 10)
local economyTie = define('economyTie', { 'SORTECONOMY' }, 10)
local defense = define('defense', { 'SORTDEFENSE' }, 5)
local misc = define('misc', {}, 1)
local ordered = model.Build({ overlap, economyTie, economyFirst, defense, misc }, { army = 1 })
assert(#ordered.errors == 0)
local actual = {}
for _, entry in ipairs(ordered.entries) do
    if entry.type == 'item' then table.insert(actual, entry.id) end
end
assert(actual[1] == overlap and actual[2] == economyTie and actual[3] == economyFirst
    and actual[4] == defense and actual[5] == misc,
    'category precedence, priority sort and stable ties match native ordering')
assert(ordered.entries[1].sourceIndex == 1, 'item preserves its input source index')
local spacerCount = 0
for _, entry in ipairs(ordered.entries) do if entry.type == 'spacer' then spacerCount = spacerCount + 1 end end
assert(spacerCount == 3, 'one spacer separates each populated category bucket')

local restrictedUnit = define('restrictedUnit', { 'SORTCONSTRUCTION' }, 1)
restricted[restrictedUnit] = true
local allowedAfterRestriction = define('allowedAfterRestriction', { 'SORTECONOMY' }, 2)
local restrictions = model.Build({ restrictedUnit, allowedAfterRestriction }, { army = 1 })
assert(#restrictions.errors == 1 and restrictions.errors[1].id == restrictedUnit)
assert(#restrictions.entries == 1 and restrictions.entries[1].type == 'item'
    and restrictions.entries[1].id == allowedAfterRestriction,
    'restricted-only category emits neither an item nor a leading spacer')

define('builder', { 'STRUCTURE' }, 0)
local allowedPrereqUpgrade = define('allowedUpgrade', { 'SORTCONSTRUCTION' }, 1,
    { UpgradesFrom = 'allowedBase' })
define('allowedBase', {}, 0)
local deniedPrereqUpgrade = define('deniedUpgrade', { 'SORTECONOMY' }, 1,
    { UpgradesFrom = 'deniedBase' })
define('deniedBase', {}, 0)
restricted.deniedBase = true
local upgradeResult = model.Build({ allowedPrereqUpgrade, deniedPrereqUpgrade },
    { selectedUnit = 'builder', army = 1 })
assert(#upgradeResult.errors == 1 and upgradeResult.errors[1].id == deniedPrereqUpgrade,
    'restricted upgrade prerequisite is reported')
local upgradeItems, arrows, spacers = {}, 0, 0
for _, entry in ipairs(upgradeResult.entries) do
    if entry.type == 'item' then table.insert(upgradeItems, entry.id)
    elseif entry.type == 'arrow' then arrows = arrows + 1
    elseif entry.type == 'spacer' then spacers = spacers + 1 end
end
assert(#upgradeItems == 1 and upgradeItems[1] == allowedPrereqUpgrade and arrows == 1 and spacers == 0,
    'allowed structure upgrades receive one arrow; denied prereq emits no item or spurious spacer')

local missingPriority = define('missingPriority', { 'SORTCONSTRUCTION' }, false)
local noBlueprint = 'noBlueprint'
local malformed = model.Build({ missingPriority, noBlueprint, '', missingPriority }, { army = 1 })
assert(#malformed.entries == 0 and #malformed.errors == 4,
    'missing blueprint, missing priority, invalid ID and duplicate ID are explicit failures')
local missingOps = module.Create({})
local unavailable = missingOps.Build({ overlap })
assert(#unavailable.entries == 0 and #unavailable.errors == 1,
    'missing engine operations fail closed')
local classificationModel = module.Create({
    hasCategory = function(id, category)
        if id == 'badSelection' then error('selection lookup unavailable') end
        return hasCategory(id, category)
    end,
    getBlueprint = function(id) return blueprints[id] end,
    isRestricted = function(id) return restricted[id] == true end,
})
local classificationFailure = classificationModel.Build({ deniedPrereqUpgrade },
    { selectedUnit = 'badSelection' })
assert(#classificationFailure.entries == 0 and #classificationFailure.errors == 1,
    'failed selection classification withholds all choices instead of bypassing prerequisite restrictions')

print('PASS: construction grid category precedence, sorting, restrictions, upgrades and spacers')
