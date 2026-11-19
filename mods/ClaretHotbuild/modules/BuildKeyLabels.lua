-- Pure mapping from assigned Hotbuild presets to FAF construction hotkey labels.
-- The renderer still decides which of these blueprint IDs are actually visible.

local KeySigns = {
    Comma = ',', Period = '.', Slash = '/', Backslash = '\\', Minus = '-',
    NumPlus = '+', NumMinus = '-', NumStar = '*', NumSlash = '/', Quote = "'",
    LeftBracket = '[', RightBracket = ']', Chevron = '<', Backtick = '`',
}

-- Label colours for the construction tiles. Plain and Alt follow the native
-- FAF white/orange; Ctrl is the muted red and Shift the muted yellow chosen
-- for readability on the dark tile background (not acid tones). The native
-- Ctrl+Alt red is replaced by the brighter coral. Shift combinations keep
-- the Theme.Colors.keyCombo* tones used by the keyboard-editor legend.
local LabelColours = {
    plain = 'ffffffff',
    ctrl = 'ffd26060',
    shift = 'ffe8cf6e',
    ctrlShift = 'ff4db6ac',
    alt = 'ffffbf80',
    ctrlAlt = 'ffff7785',
    shiftAlt = 'ff9ccc65',
    ctrlShiftAlt = 'ff7986cb',
}

local function ValidId(value)
    return type(value) == 'string' and value ~= ''
        and not string.find(string.lower(value), '^claret_')
end

local function TextSize(length)
    if length <= 1 then return 18 end
    if length <= 3 then return 14 end
    return math.max(8, 14 - ((length - 3) * 2))
end

local function ReadChord(assignment)
    if type(assignment) ~= 'table' or assignment.foreign == true
        or type(assignment.ref) ~= 'table' or assignment.ref.kind ~= 'preset'
        or type(assignment.ref.id) ~= 'string' or assignment.ref.id == ''
        or type(assignment.key) ~= 'string' or assignment.key == '' then
        return nil
    end
    local modifiers = assignment.modifiers
    if modifiers ~= nil and type(modifiers) ~= 'table' then return nil end
    modifiers = modifiers or {}
    local ctrl, alt, shift = modifiers.ctrl == true, modifiers.alt == true, modifiers.shift == true
    local key = KeySigns[assignment.key] or assignment.key
    -- Construction tiles show the physical key only. Modifiers still matter
    -- to dispatch, but must not turn the tile label into a chord.
    local colour = LabelColours.plain
    if ctrl and alt and shift then colour = LabelColours.ctrlShiftAlt
    elseif ctrl and alt then colour = LabelColours.ctrlAlt
    elseif ctrl and shift then colour = LabelColours.ctrlShift
    elseif shift and alt then colour = LabelColours.shiftAlt
    elseif ctrl then colour = LabelColours.ctrl
    elseif alt then colour = LabelColours.alt
    elseif shift then colour = LabelColours.shift end
    local full = {}
    if ctrl then table.insert(full, 'Ctrl') end
    if alt then table.insert(full, 'Alt') end
    if shift then table.insert(full, 'Shift') end
    table.insert(full, key and (shift and (KeySigns[assignment.key] or assignment.key) or key))
    return assignment.ref.id, { key = key, colour = colour, chord = table.concat(full, '+'),
        plain = not (ctrl or alt or shift) }
end

local function CopyEntries(binding)
    if type(binding) ~= 'table' or type(binding.entries) ~= 'table' then return {} end
    local result, seen = {}, {}
    for _, entry in ipairs(binding.entries) do
        if type(entry) == 'table' and entry.kind == 'blueprint' and ValidId(entry.id) then
            local id = string.lower(entry.id)
            if not seen[id] then seen[id] = true; table.insert(result, id) end
        end
    end
    return result
end

local function Add(chordsById, id, chord)
    local byChord = chordsById[id]
    if not byChord then byChord = {}; chordsById[id] = byChord end
    -- A chord can be observed in both user key maps. Keep one relation per chord.
    if not byChord[chord.chord] then byChord[chord.chord] = chord end
end

function Build(model, assignments)
    local chordsById = {}
    if type(model) ~= 'table' or type(model.Get) ~= 'function' or type(assignments) ~= 'table' then
        return {}
    end

    local bindingCache = {}
    for _, assignment in ipairs(assignments) do
        local presetId, chord = ReadChord(assignment)
        if presetId then
            local binding = bindingCache[presetId]
            if binding == nil then
                local ok, result = pcall(model.Get, model, presetId)
                binding = ok and result or false
                bindingCache[presetId] = binding
            end
            if binding then
                for _, blueprintId in ipairs(CopyEntries(binding)) do Add(chordsById, blueprintId, chord) end
            end
        end
    end

    local relations = {}
    for blueprintId, byChord in pairs(chordsById) do
        local chords = {}
        for chord in pairs(byChord) do table.insert(chords, chord) end
        table.sort(chords)
        local keys, byKey = {}, {}
        for _, chordText in ipairs(chords) do
            local chord = byChord[chordText]
            if not byKey[chord.key] then
                byKey[chord.key] = chord
                table.insert(keys, chord.key)
            end
        end
        table.sort(keys)
        -- The unmodified assignment has display priority: when the same
        -- blueprint is reachable both with and without modifiers, show the
        -- plain key (white); modifier chords stay in the metadata only.
        local displayKey = keys[1]
        for _, candidate in ipairs(keys) do
            if byKey[candidate].plain then displayKey = candidate; break end
        end
        if table.getn(keys) == 1 then
            relations[blueprintId] = {
                key = displayKey,
                colour = byKey[displayKey].colour,
                textsize = TextSize(string.len(displayKey)),
                chords = chords,
                ambiguous = false,
            }
        else
            -- ReUI/FA accept one HotKeyData per BPID. Different keys keep a
            -- plus marker; retain every full chord in metadata.
            relations[blueprintId] = {
                key = displayKey .. '+',
                colour = byKey[displayKey].colour,
                textsize = TextSize(string.len(displayKey .. '+')),
                chords = chords,
                chordCount = table.getn(chords),
                ambiguous = true,
            }
        end
    end
    return relations
end

function Merge(nativeRelations, claretRelations)
    if type(nativeRelations) ~= 'table' then return nativeRelations end
    local merged, collisions = {}, {}
    for id, relation in pairs(nativeRelations) do merged[id] = relation end
    for id, relation in pairs(type(claretRelations) == 'table' and claretRelations or {}) do
        if merged[id] ~= nil then
            table.insert(collisions, { id = id, native = merged[id], claret = relation })
        end
        -- The panel has one label per blueprint; prefer the user's Claret key.
        merged[id] = relation
    end
    table.sort(collisions, function(first, second) return first.id < second.id end)
    return merged, collisions
end

return { Build = Build, Merge = Merge }
