-- Read-only construction queue projection tests.
table.getn = function(value) return #value end
local module = setmetatable({}, { __index = _G })
assert(loadfile('../mods/ClaretCore/modules/ConstructionQueue.lua', 't', module))()
local model = module.Create()

local empty = model.Build({})
assert(#empty.entries == 0 and #empty.errors == 0, 'empty queue has no presentation rows')
local queue = {
    { id = 'ueb1101', count = 2 },
    { id = 'ueb1101', count = 3 },
    { type = 'enhancementqueue', id = 'uel0101', name = 'Engineering Suite',
        icon = 'icon', enhancement = { ID = 'EngineeringSuite' } },
    { id = 'ueb1101', count = 4 },
    { id = 'ueb0201', count = 1 },
}
local result = model.Build(queue)
assert(#result.entries == 5 and #result.errors == 0, 'all queue rows are preserved in order')
assert(result.entries[1].kind == 'factory' and result.entries[1].sourceIndex == 1
    and result.entries[1].count == 2 and result.entries[1].position == 1)
assert(result.entries[2].kind == 'factory' and result.entries[2].sourceIndex == 2
    and result.entries[2].count == 3 and result.entries[2].position == 1,
    'adjacent repeated unit stacks retain separate source entries but share native position')
assert(result.entries[3].kind == 'enhancement' and result.entries[3].sourceIndex == 3
    and result.entries[3].name == 'Engineering Suite' and result.entries[3].unitID == 'uel0101',
    'native enhancement id maps to the displayed unitID')
assert(result.entries[4].kind == 'factory' and result.entries[4].sourceIndex == 4
    and result.entries[4].position == 1,
    'enhancement entries do not advance or break native same-id stack position')
assert(result.entries[5].kind == 'factory' and result.entries[5].position == 2)

local dragging = model.Build(queue, { dragging = true })
assert(dragging.entries[1].position == 1 and dragging.entries[2].position == 2
    and dragging.entries[4].position == 3 and dragging.entries[5].position == 4,
    'dragging disables native same-id position grouping')

local invalid = model.Build({
    { id = 'missing-count' },
    { id = 'bad-count', count = 'three' },
    { id = '', count = 1 },
    false,
    { type = 'Script', id = 'raw-command' },
    { id = 'valid', count = 1 },
})
assert(#invalid.entries == 6 and #invalid.errors == 5, 'invalid inputs are reported without dropping source rows')
for index = 1, 5 do
    assert(invalid.entries[index].kind == 'invalid' and invalid.entries[index].sourceIndex == index,
        'invalid row retains stable source index')
end
assert(invalid.entries[6].kind == 'factory' and invalid.entries[6].position == 1,
    'valid queue rows remain usable after invalid entries')
local notTable = model.Build(nil)
assert(#notTable.entries == 0 and #notTable.errors == 1, 'non-table input produces an explicit error')
local sparse = model.Build({ [1] = { id = 'first', count = 1 }, [3] = { id = 'third', count = 1 } })
assert(#sparse.entries == 3 and sparse.entries[2].kind == 'invalid'
    and sparse.entries[2].sourceIndex == 2 and sparse.entries[3].sourceIndex == 3,
    'sparse input reports the missing source slot without losing later rows')

print('PASS: construction queue order, counts, enhancement distinction, grouping and invalid entries')
