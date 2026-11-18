-- Build-choice classification tests with injected engine-facing operations.
table.getn = function(value) return #value end
table.find = function(values, expected)
    for index, value in ipairs(values) do if value == expected then return index end end
end
local module = setmetatable({}, { __index = _G })
assert(loadfile('../mods/ClaretCore/modules/ConstructionChoices.lua', 't', module))()

local categories = {}
local function unit(id, ...)
    local row = {}
    for _, category in ipairs({ ... }) do row[category] = true end
    categories[id] = row
    return id
end
local factory = unit('factory', 'FACTORY')
local engineer = unit('engineer', 'ENGINEER')
local other = unit('other', 'MOBILE')
local t1 = unit('t1', 'TECH1')
local t2 = unit('t2', 'TECH2')
local t2Down = unit('t2down', 'TECH2', 'CONSTRUCTIONSORTDOWN')
local t3 = unit('t3', 'TECH3')
local t3Down = unit('t3down', 'TECH3', 'CONSTRUCTIONSORTDOWN')
local exp = unit('exp', 'EXPERIMENTAL')
local expDown = unit('expdown', 'EXPERIMENTAL', 'CONSTRUCTIONSORTDOWN')
local forbidden = unit('forbidden', 'TECH1')
local overlap = unit('overlap', 'TECH1', 'TECH2')
local id3 = 'upgrade3'
local id4 = 'upgrade4'
local cycleA = 'cycleA'
local cycleB = 'cycleB'
local links = { base = id3, [id3] = id4, [id4] = '', [cycleA] = cycleB, [cycleB] = cycleA }
local ops = {
    hasCategory = function(value, category) return categories[value] and categories[value][category] == true end,
    isAllowed = function(value) return value ~= forbidden end,
    upgradeNext = function(id) return links[id] end,
}
local model = module.Create(ops)

local factoryResult = model.Build({ t1, t2, t2Down, t3, t3Down, exp, expDown }, { factory })
assert(factoryResult.allFactorySelection and factoryResult.splitByTech)
assert(factoryResult.constructionEnabled and factoryResult.restrictionSource == 'injected')
local tabs = factoryResult.tabs
assert(#tabs.t1 == 2 and tabs.t1[1] == t1 and tabs.t1[2] == t2Down,
    'factory sort-down TECH2 moves down one tab')
assert(#tabs.t2 == 2 and tabs.t2[1] == t2 and tabs.t2[2] == t3Down,
    'factory sort-down TECH3 moves down one tab')
assert(#tabs.t3 == 2 and tabs.t3[1] == t3 and tabs.t3[2] == expDown,
    'factory sort-down experimental moves down one tab')
assert(#tabs.t4 == 1 and tabs.t4[1] == exp)
local overlapping = model.Build({ overlap }, { factory })
assert(#overlapping.tabs.t1 == 1 and #overlapping.tabs.t2 == 1,
    'factory tech tabs independently include multi-tech category members')

local engineerResult = model.Build({ t1, t2Down, t3Down, expDown, forbidden }, { engineer })
assert(engineerResult.tabs.t1[1] == t1 and #engineerResult.tabs.t1 == 1)
assert(engineerResult.tabs.t2[1] == t2Down and engineerResult.tabs.t3[1] == t3Down
    and engineerResult.tabs.t4[1] == expDown, 'engineer sorting follows tech categories without factory sort-down')
assert(not table.find(engineerResult.units, forbidden), 'restriction adapter filters incoming candidates')

local chain = model.Build({ t1 }, { 'base' }, {})
assert(chain.units[1] == t1 and chain.units[2] == id3 and chain.units[3] == id4,
    'upgradesTo chain appends in traversal order')
local queuedChain = model.Build({ t1 }, { 'base' }, { id3 })
assert(#queuedChain.units == 2 and queuedChain.units[2] == id4,
    'queued upgrade is skipped while later chain steps remain eligible')
local cycle = model.Build({}, { cycleA }, {})
assert(#cycle.units == 1 and cycle.units[1] == cycleB,
    'upgrade cycles terminate without duplicating the selected source')

local mixed = model.Build({ t1, t2 }, { engineer, other })
assert(mixed.splitByTech and #mixed.tabs.t1 == 1 and #mixed.tabs.t2 == 1,
    'native sorting mode uses the first selected unit in a mixed selection')
local unsorted = model.Build({ t1, t2, exp }, { other })
assert(not unsorted.splitByTech and #unsorted.tabs.t1 == 3 and #unsorted.tabs.t2 == 0,
    'non-engineer selection keeps the full ordered list in the first tab')
local empty = model.Build({ forbidden }, { engineer })
assert(not empty.constructionEnabled and #empty.units == 0, 'empty restricted build list disables construction')
local noSelection = model.Build({ t1 }, {})
assert(not noSelection.constructionEnabled and #noSelection.units == 0,
    'empty selection cannot retain stale construction choices')

local unverifiedRestrictions = module.Create({ hasCategory = ops.hasCategory })
local unknownRestrictionResult = unverifiedRestrictions.Build({ t1 }, { engineer })
assert(not unknownRestrictionResult.constructionEnabled and unknownRestrictionResult.restrictionSource == 'unavailable',
    'choices are withheld without restriction approval')
local prefilteredModel = module.Create({ hasCategory = ops.hasCategory, upgradeNext = ops.upgradeNext,
    buildablesArePrefiltered = true })
local prefiltered = prefilteredModel.Build({ t1 }, { engineer })
assert(prefiltered.constructionEnabled and prefiltered.restrictionSource == 'pre-filtered-input',
    'restriction-free operation requires explicit prefiltered input declaration')
local prefilteredChain = prefilteredModel.Build({ t1, id3 }, { 'base' })
assert(#prefilteredChain.units == 2 and prefilteredChain.units[2] == id3,
    'prefiltered mode only permits chain candidates already present in the approved input list')
assert(not table.find(prefilteredChain.units, id4), 'an unlisted upgrade chain step is withheld')

print('PASS: construction choice order, tabs, factory sort-down, restrictions and upgrade chains')
