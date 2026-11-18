-- Read-only mobile and factory template eligibility tests.
table.getn = function(value) return #value end
local module = setmetatable({}, { __index = _G })
assert(loadfile('../mods/ClaretCore/modules/ConstructionTemplates.lua', 't', module))()

local mobileUnit = { MOBILE = true, ENGINEER = true }
local factoryUnit = { FACTORY = true }
local externalFactory = { EXTERNALFACTORY = true }
local ordinaryUnit = { MOBILE = true }
local buildable, restricted, blueprints = {}, {}, {}
local ops = {
    hasCategory = function(unit, category) return unit[category] == true end,
    isBuildable = function(id) return buildable[id] == true end,
    isRestricted = function(id) return restricted[id] == true end,
    getBlueprint = function(id) return blueprints[id] end,
}
ops.canBuildAfter = function(id, priorEntries)
    return id == 'factoryT2' and #priorEntries > 0
        and priorEntries[#priorEntries].id == 'factoryT1'
end
local model = module.Create(ops)

buildable.mobileA, buildable.mobileB = true, true
local mobileOne = { name = 'First', icon = 'mobileA', templateData = { { 'mobileA', 1, 0, 0 }, { 'mobileA', 2, 1, 0 } } }
local mobileTwo = { name = 'Second', icon = 'mobileB', templateData = { { 'mobileB', 1, 0, 0 } } }
local mobileTemplates = { [2] = mobileTwo, [1] = mobileOne }
local mobileResult = model.Build({ mobileUnit }, mobileTemplates, nil)
assert(mobileResult.kind == 'mobile' and #mobileResult.entries == 2)
assert(mobileResult.entries[1].sourceIndex == 1 and mobileResult.entries[1].template == mobileOne)
assert(mobileResult.entries[2].sourceIndex == 2 and mobileResult.entries[2].template == mobileTwo,
    'mobile templates retain source keys and stable order')
assert(mobileResult.entries[1].type == 'templates'
    and mobileResult.entries[1].sourceSnapshot ~= mobileOne
    and mobileResult.entries[1].sourceSnapshot.templateData[1][1] == 'mobileA',
    'click-ready rows carry a detached render-time source snapshot')
assert(mobileResult.entries[1].template.templateID == nil and mobileOne.icon == 'mobileA'
    and mobileOne.templateData[1][1] == 'mobileA', 'model does not annotate or mutate source templates')

local restrictedMobile = { name = 'Restricted', icon = 'mobileA', templateData = { { 'mobileA' }, { 'mobileB' } } }
restricted.mobileB = true
local mobileFilter = model.Build({ mobileUnit }, { restrictedMobile }, nil)
assert(#mobileFilter.entries == 0 and #mobileFilter.errors == 1,
    'restricted blueprint excludes a mobile template')
restricted.mobileB = nil
buildable.foreign = false
local foreignTemplate = { name = 'Foreign', icon = 'foreign', templateData = { { 'foreign' } } }
local foreign = model.Build({ mobileUnit }, { foreignTemplate }, nil, { allowCrossFaction = true })
assert(#foreign.entries == 0 and #foreign.limitations == 1 and foreignTemplate.templateData[1][1] == 'foreign',
    'cross-faction conversion is not guessed or applied')

buildable.factoryT1 = true
buildable.factoryT2 = false
buildable.factoryT3 = true
blueprints.factoryT1 = { General = { UpgradesFrom = 'oldFactory' } }
blueprints.factoryT2 = { General = { UpgradesFrom = 'factoryT1' } }
blueprints.factoryT3 = { General = { UpgradesFrom = 'none' } }
local allowedFactoryTemplate = { name = 'Factory chain', templateData = {
    { id = 'factoryT1', count = 1 }, { id = 'factoryT2', count = 1 }, { id = 'factoryT3', count = 1 },
} }
local invalidFactoryTemplate = { name = 'No upgrade chain', templateData = {
    { id = 'factoryT3', count = 1 }, { id = 'factoryT2', count = 1 },
} }
local unrelatedUpgradeTemplate = { name = 'Unrelated upgrade', templateData = {
    { id = 'unrelatedUpgrade', count = 1 }, { id = 'factoryT2', count = 1 },
} }
blueprints.unrelatedUpgrade = { General = { UpgradesFrom = 'someOtherUnit' } }
buildable.unrelatedUpgrade = true
buildable.factoryT4 = false
local laterUnbuildableTemplate = { name = 'Later unavailable item', templateData = {
    { id = 'factoryT1', count = 1 }, { id = 'factoryT2', count = 1 }, { id = 'factoryT4', count = 1 },
} }
local factoryResult = model.Build({ factoryUnit, externalFactory }, nil,
    { allowedFactoryTemplate, invalidFactoryTemplate, unrelatedUpgradeTemplate, laterUnbuildableTemplate })
assert(factoryResult.kind == 'factory' and #factoryResult.entries == 1
    and factoryResult.entries[1].template == allowedFactoryTemplate,
    'factory eligibility accepts only an explicit matching predecessor proof')
assert(#factoryResult.limitations == 1 and factoryResult.limitations[1]:find('unsupported', 1, true),
    'factory result reports that the native loose upgrade heuristic is unsupported')
assert(factoryResult.entries[1].sourceIndex == 1 and #allowedFactoryTemplate.templateData == 3,
    'factory source order and identity are preserved')

restricted.factoryT2 = true
local restrictedFactory = model.Build({ factoryUnit }, nil, { allowedFactoryTemplate })
assert(#restrictedFactory.entries == 0 and #restrictedFactory.errors > 0,
    'restricted factory entry cannot pass through the upgrade exception')
restricted.factoryT2 = nil

local repeatedFactory = { name = 'Repeated', templateData = {
    { id = 'factoryT1', count = 1 }, { id = 'factoryT1', count = 2 },
} }
local repeated = model.Build({ factoryUnit }, nil, { repeatedFactory })
assert(#repeated.entries == 1 and #repeatedFactory.templateData == 2
    and repeated.entries[1].template == repeatedFactory,
    'repeated unit IDs remain distinct in the source template')

local noUpgradeProof = module.Create({ hasCategory = ops.hasCategory, isBuildable = ops.isBuildable,
    isRestricted = ops.isRestricted })
local noProof = noUpgradeProof.Build({ factoryUnit }, nil, { allowedFactoryTemplate })
assert(#noProof.entries == 0 and #noProof.errors > 0,
    'nonbuildable future factory item is rejected without explicit predecessor proof')

local malformed = model.Build({ mobileUnit }, {
    { name = 'Bad data', templateData = { {} } },
    false,
    { name = 'Sparse', templateData = { [1] = { 'mobileA' }, [3] = { 'mobileB' } } },
}, nil)
assert(#malformed.entries == 0 and #malformed.errors == 3,
    'malformed records, missing mobile IDs, and sparse template data are reported')
local directiveOnly = model.Build({ mobileUnit }, {
    { name = 'No blueprint', templateData = { 'opaque directive' } },
}, nil)
assert(#directiveOnly.entries == 0 and #directiveOnly.errors == 1,
    'template without any blueprint entries is not presented')
local mixedSelection = model.Build({ mobileUnit, factoryUnit }, mobileTemplates, { allowedFactoryTemplate })
assert(#mixedSelection.entries == 0 and mixedSelection.kind == nil,
    'mixed mobile/factory selection has no guessed template eligibility')
local empty = model.Build({}, mobileTemplates, { allowedFactoryTemplate })
assert(#empty.entries == 0 and empty.kind == nil, 'empty selection produces no templates')

print('PASS: construction template eligibility, restrictions, factory upgrades, stable identity and immutability')
