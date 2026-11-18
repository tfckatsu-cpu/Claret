-- Selected-unit summary grouping and separation tests.
table.getn = function(value) return #value end
local module = setmetatable({}, { __index = _G })
assert(loadfile('../mods/ClaretCore/modules/ConstructionSelection.lua', 't', module))()

local function unit(id, cats, fuel, idle)
    local categorySet = { ALLUNITS = true }
    for _, category in ipairs(cats or {}) do categorySet[category] = true end
    return { blueprintId = id, categories = categorySet, fuel = fuel or 1, idle = idle == true }
end
local function operations()
    return {
        getBlueprintId = function(value) return value.blueprintId end,
        hasCategory = function(value, category) return value.categories[category] == true end,
        getFuelRatio = function(value) return value.fuel end,
        isIdle = function(value) return value.idle end,
    }
end
local model = module.Create(operations())

local mixed = unit('mixed', { 'LAND', 'AIR', 'STRUCTURE', 'SORTCONSTRUCTION', 'TECH2' })
local landAir = unit('landAir', { 'LAND', 'AIR', 'TECH1' })
local sorted = unit('sorted', { 'SORTCONSTRUCTION', 'TECH1', 'TECH3' })
local result = model.Build({ mixed, landAir, sorted })
assert(#result.errors == 0)
assert(result.entries[1].type == 'unitstack' and result.entries[1].id == 'landAir',
    'later AIR category takes precedence over LAND')
assert(result.entries[2].type == 'spacer')
assert(result.entries[3].type == 'unitstack' and result.entries[3].id == 'sorted',
    'TECH1 takes precedence over TECH3 in unitstack ordering')
assert(result.entries[4].type == 'unitstack' and result.entries[4].id == 'mixed'
    and result.entries[4].sourceIndices[1] == 1,
    'SORTCONSTRUCTION is the last and highest summary category')

local first = unit('same', { 'LAND', 'TECH1' })
local second = unit('same', { 'LAND', 'TECH1' })
local grouped = model.Build({ first, second })
local stack = grouped.entries[1]
assert(stack.type == 'unitstack' and stack.id == 'same' and stack.count == 2
    and stack.units[1] == first and stack.units[2] == second,
    'same-blueprint units retain their identities and count')

local low = unit('air', { 'AIR', 'TECH1' }, 0.19)
local sentinel = unit('sentinel', { 'AIR', 'TECH1' }, -1)
local boundary = unit('boundary', { 'AIR', 'TECH1' }, 0.2)
local idleA = unit('builder', { 'SORTCONSTRUCTION', 'CONSTRUCTION', 'TECH1' }, 1, true)
local idleB = unit('builder', { 'SORTCONSTRUCTION', 'CONSTRUCTION', 'TECH1' }, 1, true)
local ordinaryBuilder = unit('ordinaryBuilder', { 'SORTCONSTRUCTION', 'CONSTRUCTION', 'TECH1' }, 1, false)
local separated = model.Build({ ordinaryBuilder, low, sentinel, boundary, idleA, idleB },
    { separateIdleBuilders = true })
local byId = {}
local spacerTotal = 0
for _, entry in ipairs(separated.entries) do
    if entry.type == 'unitstack' then byId[entry.id] = entry
    elseif entry.type == 'spacer' then spacerTotal = spacerTotal + 1 end
end
assert(byId.air and byId.air.lowFuel and byId.air.units[1] == low)
assert(byId.sentinel and not byId.sentinel.lowFuel and byId.boundary and not byId.boundary.lowFuel,
    'fuel -1 sentinel and exact .2 threshold remain in normal air section')
assert(byId.builder and byId.builder.idleCon and byId.builder.count == 2
    and byId.builder.units[1] == idleA and byId.builder.units[2] == idleB)
assert(byId.ordinaryBuilder and not byId.ordinaryBuilder.idleCon)
assert(spacerTotal >= 1 and separated.entries[#separated.entries].type ~= 'spacer',
    'low-fuel and idle sections use stock separation without trailing spacer')

local unsplit = model.Build({ idleA }, { separateIdleBuilders = false })
assert(unsplit.entries[1].id == 'builder' and not unsplit.entries[1].idleCon,
    'idle engineers remain in normal categories when option is disabled')
local empty = model.Build({})
assert(#empty.entries == 0 and #empty.errors == 0, 'empty selection produces no summary rows')

local malformedUnit = unit('', { 'LAND' })
local badFuel = unit('badFuel', { 'AIR' }, 'low')
local badCategory = unit('badCategory', { 'LAND' })
local malformedModel = module.Create({
    getBlueprintId = function(value) return value.blueprintId end,
    hasCategory = function(value, category)
        if value == badCategory and category == 'TECH2' then error('category query failed') end
        return value.categories[category] == true
    end,
    getFuelRatio = function(value) return value.fuel end,
    isIdle = function(value) return value.idle end,
})
local invalid = malformedModel.Build({ 42, malformedUnit, badFuel, badCategory })
assert(#invalid.entries == 0 and #invalid.errors == 4,
    'invalid identity, malformed fuel and failed category operations are reported and withheld')

print('PASS: construction selection precedence, grouping, low fuel, idle builders and malformed units')
