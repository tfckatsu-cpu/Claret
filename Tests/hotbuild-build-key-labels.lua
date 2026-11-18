-- Pure per-key preset-to-blueprint hotkey-label mapping tests.
table.getn = table.getn or function(value) return #value end

local module = assert(loadfile('../mods/ClaretHotbuild/modules/BuildKeyLabels.lua'))()
local bindings = {
    alpha = { entries = {
        { kind = 'blueprint', id = 'UAL0001' },
        { kind = 'action', id = 'claret.order.move' },
        { kind = 'blueprint', id = 'claret_template_1234567890' },
        { kind = 'template', id = 'uel0003' },
    } },
    single = { entries = { { kind = 'blueprint', id = 'uel0002' } } },
    beta = { entries = { { kind = 'blueprint', id = 'ual0001' } } },
    gamma = { entries = { { kind = 'blueprint', id = 'uaa0101' } } },
    delta = { entries = { { kind = 'blueprint', id = 'xsa0101' } } },
    shifted = { entries = { { kind = 'blueprint', id = 'uel0003' } } },
}
local getCalls = {}
local model = {
    Get = function(_, id)
        getCalls[id] = (getCalls[id] or 0) + 1
        return bindings[id]
    end,
}

local assignments = {
    { key = 'Q', modifiers = {}, ref = { kind = 'preset', id = 'alpha' }, foreign = false },
    -- The same mapped assignment can arrive from more than one key map.
    { key = 'Q', modifiers = {}, ref = { kind = 'preset', id = 'alpha' }, foreign = false },
    { key = 'Q', modifiers = {}, ref = { kind = 'preset', id = 'single' }, foreign = false },
    -- Pair-resolved KeyboardAssignments expose the linked preset as the ref.
    { key = 'W', modifiers = { shift = true }, ref = { kind = 'preset', id = 'alpha' }, foreign = false,
        linkedRef = { kind = 'composite', id = 'ctx1' } },
    { key = 'F', modifiers = { ctrl = true }, ref = { kind = 'preset', id = 'beta' }, foreign = false },
    { key = 'X', modifiers = { alt = true }, ref = { kind = 'preset', id = 'gamma' }, foreign = false },
    { key = 'R', modifiers = { ctrl = true, alt = true }, ref = { kind = 'preset', id = 'delta' }, foreign = false },
    { key = 'Z', modifiers = { shift = true }, ref = { kind = 'preset', id = 'shifted' }, foreign = false },
    { key = 'E', modifiers = {}, ref = { kind = 'preset', id = 'beta' }, foreign = true },
    { key = 'A', modifiers = {}, ref = { kind = 'action', id = 'claret.order.move' }, foreign = false },
    { key = 'M', modifiers = {}, ref = { kind = 'preset', id = 'missing' }, foreign = false },
    { key = '', modifiers = {}, ref = { kind = 'preset', id = 'alpha' }, foreign = false },
    { key = 'T', modifiers = 'invalid', ref = { kind = 'preset', id = 'alpha' }, foreign = false },
}

local relations = module.Build(model, assignments)
assert(relations.ual0001 and relations.ual0001.ambiguous,
    'blueprints shared by multiple preset chords get an explicit ambiguity marker')
assert(relations.ual0001.key == 'F+' and relations.ual0001.colour == 'fffafa00'
    and relations.ual0001.chordCount == 3,
    'ambiguous mapping uses the first sorted key plus marker and its actual modifier colour')
assert(table.getn(relations.ual0001.chords) == 3
    and relations.ual0001.chords[1] == 'Ctrl+F'
    and relations.ual0001.chords[2] == 'Q'
    and relations.ual0001.chords[3] == 'Shift+W',
    'full chords are deduplicated and sorted deterministically')

assert(relations.uel0002.key == 'Q' and relations.uel0002.colour == 'ffffffff'
    and relations.uel0002.textsize == 18 and not relations.uel0002.ambiguous,
    'single unmodified blueprint label uses the FAF white and 18 point convention')
assert(relations.uaa0101.key == 'X' and relations.uaa0101.colour == 'ffffbf80'
    and relations.uaa0101.chords[1] == 'Alt+X', 'Alt label uses the FAF orange convention')
assert(relations.xsa0101.key == 'R' and relations.xsa0101.colour == 'FFe80a0a'
    and relations.xsa0101.chords[1] == 'Ctrl+Alt+R', 'Ctrl+Alt uses the FAF red convention')
assert(relations.uel0003.key == 'S+Z' and relations.uel0003.colour == 'ffffffff'
    and relations.uel0003.chords[1] == 'Shift+Z' and relations.uel0003.textsize == 14,
    'Shift remains visually distinct while plain Shift keeps the FAF white convention')

assert(relations.claret_template_1234567890 == nil and relations['claret.order.move'] == nil
    and relations.missing == nil,
    'synthetic template IDs, action entries, and missing presets are omitted')
assert(getCalls.alpha == 1, 'repeated assignments reuse the preset lookup')
assert(bindings.alpha.entries[1].id == 'UAL0001' and assignments[1].key == 'Q',
    'input model and assignments are not mutated')

local native = { ual0001 = { key = 'N', colour = 'ffffffff', textsize = 18 } }
local merged, collisions = module.Merge(native, relations)
assert(merged ~= native and native.ual0001.key == 'N' and merged.ual0001 == relations.ual0001,
    'native mapping is copied and the Claret key takes precedence')
assert(merged.uel0002 == relations.uel0002 and table.getn(collisions) == 1
    and collisions[1].id == 'ual0001' and collisions[1].native.key == 'N'
    and collisions[1].claret.key == 'F+',
    'native label collisions are reported in sorted metadata')

print('PASS: build key labels map preset blueprints, preserve modifiers, and report multi-key ambiguity')
