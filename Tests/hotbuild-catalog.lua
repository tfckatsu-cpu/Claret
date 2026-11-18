-- Logic tests in Fengari; engine blueprint loading/rendering is checked in FAF.
local env = setmetatable({}, { __index = _G })
assert(loadfile('../mods/ClaretHotbuild/modules/Catalog.lua', 't', env))()
local function bp(id, name, faction, categories, description)
    return { BlueprintId = id, General = { UnitName = name, FactionName = faction },
        Categories = categories, Description = description }
end
local data = {
    scout = bp('uea0101', '<LOC scout>Scout', 'UEF', { 'TECH1', 'AIR', 'BUILTBYTIER1FACTORY' }, '<LOC scoutdesc>Air scout'),
    tankB = bp('uel0201', 'Tank', 'UEF', { 'TECH2', 'LAND', 'BUILTBYTIER2FACTORY' }),
    tankA = bp('uel0102', 'Tank', 'UEF', { 'TECH1', 'LAND', 'BUILTBYTIER1FACTORY' }),
    sameName = bp('uel0101', 'Tank', 'UEF', { 'TECH1', 'LAND', 'BUILTBYTIER1FACTORY' }),
    hydro = bp('ueb1102', 'Генератор', 'UEF', { 'TECH1', 'STRUCTURE', 'BUILTBYTIER1ENGINEER' }, 'Hydrocarbon plant'),
    cybran = bp('url0402', 'Monkeylord', 'Cybran', { 'TECH3', 'EXPERIMENTAL', 'LAND', 'BUILTBYTIER3ENGINEER' }),
    factoryExperimental = bp('uel0401', 'Experimental Factory Unit', 'UEF', { 'TECH3', 'EXPERIMENTAL', 'LAND', 'BUILTBYTIER3FACTORY' }),
    hq = bp('ueb0201', 'T2 Land HQ', 'UEF', { 'TECH2', 'STRUCTURE', 'FACTORY', 'RESEARCH', 'BUILTBYTIER2ENGINEER' }),
    naval = bp('uaa0203', 'Frigate', 'Aeon', { 'TECH1', 'NAVAL', 'BUILTBYTIER1FACTORY' }),
    dummy = bp('dummy', 'Dummy', 'UEF', { 'DUMMYUNIT', 'LAND', 'BUILTBYTIER1FACTORY' }),
    civilian = bp('civilian', 'House', 'UEF', { 'CIVILIAN', 'STRUCTURE', 'BUILTBYTIER1ENGINEER' }),
    spawnedCommander = bp('uel0001', 'Commander', 'UEF', { 'LAND', 'COMMAND' }),
    prop = { BlueprintId = 'prop', Categories = { 'BUILTBYTIER1ENGINEER' } },
    projectile = { General = {}, BlueprintId = 'projectile' },
    number = 4,
}
local cat = env.Create(data, function(text)
    if text == '<LOC scout>Scout' then return 'Snoop' end
    return (text:gsub('^<LOC [^>]+>', ''))
end)
assert(#cat:List() == 8)
assert(cat:Get('UEA0101').name == 'Air scout', 'blueprint Description/LOC supplies the visible unit name')
assert(cat:Get('uea0101').description == 'Air scout')
assert(cat:Get('uea0101').icon == '/icons/units/uea0101_icon.dds')
assert(cat:Get('uea0101').blueprint == data.scout)
assert(not cat:Get('dummy') and not cat:Get('civilian') and not cat:Get('uel0001'))
assert(cat:Get('ueb0201'), 'saved HQ blueprints remain addressable')
local renamed = env.Create({
    hydro = bp('ueb1102', 'Генератор', 'UEF', { 'TECH1', 'STRUCTURE', 'BUILTBYTIER1ENGINEER' }),
    aeonHydro = bp('uab1102', 'Генератор', 'AEON', { 'TECH1', 'STRUCTURE', 'BUILTBYTIER1ENGINEER' }),
    regularPower = bp('ueb1101', 'Генератор', 'UEF', { 'TECH1', 'STRUCTURE', 'BUILTBYTIER1ENGINEER' }),
    airFactory = bp('uea0101x', 'Авиазавод (Support)', 'UEF', { 'TECH1', 'STRUCTURE', 'FACTORY', 'AIR', 'BUILTBYTIER1ENGINEER' }),
    landFactory = bp('uel0101x', 'Лэнд завод (Support)', 'UEF', { 'TECH1', 'STRUCTURE', 'FACTORY', 'LAND', 'BUILTBYTIER1ENGINEER' }),
    tacticalSilo = bp('ueb2101x', 'Алоха', 'UEF', { 'TECH2', 'STRUCTURE', 'SILO', 'BUILTBYTIER2ENGINEER' }),
    t2AntiMissile = bp('ueb4201x', 'Антиракеты', 'UEF', { 'TECH2', 'STRUCTURE', 'ANTIMISSILE', 'BUILTBYTIER2ENGINEER' }),
    t3AntiMissile = bp('ueb4302x', 'Антиракеты', 'UEF', { 'TECH3', 'STRUCTURE', 'ANTIMISSILE', 'SILO', 'NUKE', 'BUILTBYTIER3ENGINEER' }),
    t3Radar = bp('ueb4303x', 'PC3 Всеволновой', 'UEF', { 'TECH3', 'STRUCTURE', 'RADAR', 'BUILTBYTIER3ENGINEER' }),
    shield = bp('ueb4301', 'Heavy Shield Generator', 'UEF', { 'TECH3', 'STRUCTURE', 'SHIELD', 'BUILTBYTIER3ENGINEER' }),
    novax = bp('xeb2402', 'Авиазавод', 'UEF', { 'TECH3', 'EXPERIMENTAL', 'STRUCTURE', 'AIR', 'FACTORY', 'ORBITALSYSTEM', 'BUILTBYTIER3ENGINEER' }),
    screenshotAirFactory = bp('ueb0102', 'UEF Air Factory', 'UEF', { 'TECH1', 'STRUCTURE', 'FACTORY', 'AIR', 'BUILTBYTIER1ENGINEER' }),
})
assert(renamed:Get('ueb1102').name == 'Генератор' and renamed:Get('uab1102').name == 'Генератор')
assert(renamed:Get('ueb1101').name == 'Генератор', 'blueprint names are not replaced with Claret aliases')
assert(renamed:Get('uea0101x').name == 'Авиазавод (Support)')
assert(renamed:Get('uel0101x').name == 'Лэнд завод (Support)')
assert(renamed:Get('ueb2101x').name == 'Алоха')
assert(renamed:Get('ueb4201x').name == 'Антиракеты' and renamed:Get('ueb4302x').name == 'Антиракеты')
assert(renamed:Get('ueb4303x').name == 'PC3 Всеволновой')
assert(renamed:Get('ueb4301').name == 'Heavy Shield Generator', 'UEB4301 remains the heavy shield generator')
assert(renamed:Get('xeb2402').name == 'Авиазавод', 'blueprint localization remains authoritative for Novax Center')
assert(renamed:DisplayName('Щит', 'ueb4301', renamed:Get('ueb4301').blueprint) == 'Щит',
    'DisplayName preserves the source name without applying manual aliases')
-- ReUI can be supplied by the module environment rather than raw _G.
env.ReUI = { ClaretCore = { Localization = { GetLanguage = function() return 'en' end } } }
assert(cat:DisplayName('Воздушный разведчик', 'uea0101', data.scout) == 'Air scout')
assert(cat:DisplayName('Генератор', 'ueb1102', data.hydro) == 'Hydrocarbon plant')
assert(cat:DisplayName('Имя', 'test', { Interface = { HelpText = '<LOC help>Help text' } }) == 'Help text')
assert(cat:DisplayName('Имя', 'test', { General = { UnitName = '<LOC unit>Unit name' } }) == 'Unit name')
env.ReUI.ClaretCore.Localization.GetLanguage = function() return 'ru' end
assert(cat:DisplayName('Разведчик', 'uea0101', data.scout) == 'Разведчик')
env.ReUI = nil
local function display(name, id, categories)
    return renamed:DisplayName(name, id, { Categories = categories or {} })
end
assert(display('Колыбель', 'cradle', {'STRUCTURE'}) == 'Колыбель')
assert(display('Массфаб', 'massfab', {'STRUCTURE'}) == 'Массфаб')
assert(display('Антиракеты', 'smd', {'STRUCTURE','TECH3','ANTIMISSILE','SILO','NUKE'}) == 'Антиракеты',
    'DisplayName does not apply category-based manual translations')
for _, record in ipairs(cat:List({ kind = 'STRUCTURE' })) do
    assert(record.id ~= 'ueb0201', 'research HQs are hidden from building choices')
end
assert(not cat:Get('prop') and not cat:Get('projectile') and not cat:Get(false))
assert(cat:List()[1].id == 'uea0101')
assert(cat:List()[3].id == 'uel0101' and cat:List()[4].id == 'uel0102',
    'T1 tanks follow the scout and hydrocarbon plant in blueprint-name order')
assert(#cat:List({ faction = 'uef', tech = 'T1', kind = 'LAND' }) == 2)
assert(#cat:List({ search = 'AIR SCOUT' }) == 1)
assert(#cat:List({ search = 'UEA0101' }) == 1)
assert(#cat:List({ search = '[' }) == 0, 'search must be literal, not Lua pattern')
assert(#cat:List({ faction = 'CYBRAN', tech = 'EXPERIMENTAL' }) == 1)
local sacuCatalog = env.Create({ uel0301 = {
    BlueprintId = 'uel0301', General = { UnitName = 'UEF SACU' },
    Categories = { 'TECH3', 'LAND' },
} })
local gateChoices = sacuCatalog:List({ faction = 'UEF', kind = 'GATE' })
assert(#gateChoices == 1 and gateChoices[1].id == 'uel0301',
    'the stock UEF SACU is offered for gates when FAF omits its SUBCOMMANDER and BUILTBY categories')
assert(sacuCatalog:Get('uel0301').kind == 'SACU' and sacuCatalog:Get('uel0301').faction == 'UEF')
local buildingChoices = cat:List({ kind = 'STRUCTURE' })
local foundExperimental = false
for _, record in ipairs(buildingChoices) do
    if record.id == 'url0402' then foundExperimental = true end
end
assert(foundExperimental, 'experimental engineer-buildable units are available in the building picker')
for _, record in ipairs(buildingChoices) do
    assert(record.id ~= 'uel0401', 'factory-buildable experimentals are not building choices')
end
assert(#cat:List({ faction = 'ALL', tech = 'ALL', kind = 'NAVAL' }) == 1)
local snapshot = cat:List()
table.remove(snapshot, 1)
assert(#cat:List() == 8, 'filtered arrays must not mutate the catalog order')
local alternate = {}
for key, value in pairs(data) do alternate[key] = value end
local firstIds, secondIds = {}, {}
-- Localized name changes affect name sorting intentionally; compare identical LOC.
local third = env.Create(alternate, function(text)
    if text == '<LOC scout>Scout' then return 'Snoop' end
    return (text:gsub('^<LOC [^>]+>', ''))
end)
for _, record in ipairs(cat:List()) do table.insert(firstIds, record.id) end
for _, record in ipairs(third:List()) do table.insert(secondIds, record.id) end
assert(table.concat(firstIds, ',') == table.concat(secondIds, ','))
local hashCatalog = env.Create({ custom = { General = {}, CategoriesHash = {
    SERAPHIM = true, TECH2 = true, AIR = true, TRANSPORTBUILTBYTIER3FACTORY = true },
    Interface = { HelpText = '<LOC custom>Custom transport' } } }, function() error('missing LOC') end)
assert(hashCatalog:Get('custom').name == 'Custom transport')
assert(hashCatalog:Get('custom').faction == 'SERAPHIM')
assert(hashCatalog:Get('custom').tech == 'T2' and hashCatalog:Get('custom').kind == 'AIR')
local aliasCatalog = env.Create({
    aliasZ = bp('shared', 'Alias Z', 'UEF', { 'TECH1', 'LAND', 'BUILTBYTIER1FACTORY' }),
    aliasA = bp('shared', 'Alias A', 'UEF', { 'TECH1', 'LAND', 'BUILTBYTIER1FACTORY' }),
    shared = bp('shared', 'Canonical', 'UEF', { 'TECH1', 'LAND', 'BUILTBYTIER1FACTORY' }),
})
assert(#aliasCatalog:List() == 1 and aliasCatalog:Get('shared').name == 'Canonical')
local russian = env.Create({
    unit = bp('rus', '<LOC test>ЁЖ и РАЗВЕДЧИК', 'UEF', { 'TECH1', 'AIR', 'BUILTBYTIER1FACTORY' }),
})
assert(russian:Get('rus').name == 'ЁЖ и РАЗВЕДЧИК')
assert(#russian:List({search='еж'}) == 1, 'search folds ё to е in blueprint names')
assert(#russian:List({ search = 'ёж и разведчик' }) == 1)
assert(#env.Create(nil):List() == 0)
print('PASS: catalog localized labels, unit filtering, literal search, combined filters, stable ordering and hash categories')
