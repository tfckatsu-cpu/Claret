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
    ctrlShifted = { entries = { { kind = 'blueprint', id = 'uel0004' } } },
    shiftAlted = { entries = { { kind = 'blueprint', id = 'uel0005' } } },
    allMods = { entries = { { kind = 'blueprint', id = 'uel0006' } } },
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
    { key = 'V', modifiers = { ctrl = true, shift = true }, ref = { kind = 'preset', id = 'ctrlShifted' }, foreign = false },
    { key = 'B', modifiers = { shift = true, alt = true }, ref = { kind = 'preset', id = 'shiftAlted' }, foreign = false },
    { key = 'N', modifiers = { ctrl = true, shift = true, alt = true }, ref = { kind = 'preset', id = 'allMods' }, foreign = false },
    { key = 'E', modifiers = {}, ref = { kind = 'preset', id = 'beta' }, foreign = true },
    { key = 'A', modifiers = {}, ref = { kind = 'action', id = 'claret.order.move' }, foreign = false },
    { key = 'M', modifiers = {}, ref = { kind = 'preset', id = 'missing' }, foreign = false },
    { key = '', modifiers = {}, ref = { kind = 'preset', id = 'alpha' }, foreign = false },
    { key = 'T', modifiers = 'invalid', ref = { kind = 'preset', id = 'alpha' }, foreign = false },
}

local relations = module.Build(model, assignments)
assert(relations.ual0001 and relations.ual0001.ambiguous,
    'blueprints shared by multiple preset chords get an explicit ambiguity marker')
assert(relations.ual0001.key == 'Q+' and relations.ual0001.colour == 'ffffffff'
    and relations.ual0001.chordCount == 3,
    'plain assignment wins the display (white) while different keys keep the plus marker')
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
assert(relations.xsa0101.key == 'R' and relations.xsa0101.colour == 'ffff7785'
    and relations.xsa0101.chords[1] == 'Ctrl+Alt+R', 'Ctrl+Alt uses the brighter theme coral instead of the dark native red')
-- Build 20261117-139 decision: construction tiles show the physical key only;
-- Shift adds no text marker and keeps a distinct colour.
assert(relations.uel0003.key == 'Z' and relations.uel0003.colour == 'ffe8cf6e'
    and relations.uel0003.chords[1] == 'Shift+Z' and relations.uel0003.textsize == 18,
    'Shift collapses to the physical key and uses the muted yellow')
assert(relations.uel0004.key == 'V' and relations.uel0004.colour == 'ff4db6ac'
    and relations.uel0004.chords[1] == 'Ctrl+Shift+V', 'Ctrl+Shift uses the theme teal')
assert(relations.uel0005.key == 'B' and relations.uel0005.colour == 'ff9ccc65'
    and relations.uel0005.chords[1] == 'Alt+Shift+B', 'Shift+Alt uses the theme green')
assert(relations.uel0006.key == 'N' and relations.uel0006.colour == 'ff7986cb'
    and relations.uel0006.chords[1] == 'Ctrl+Alt+Shift+N', 'Ctrl+Shift+Alt uses the theme indigo')

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
    and collisions[1].claret.key == 'Q+',
    'native label collisions are reported in sorted metadata')

print('PASS: build key labels map preset blueprints, preserve modifiers, and report multi-key ambiguity')
