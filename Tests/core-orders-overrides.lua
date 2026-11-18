-- Deterministic resolver for injected selected-blueprint order overrides.
table.getn = table.getn or function(value) return #value end
local module = setmetatable({}, { __index = _G })
assert(loadfile('../mods/ClaretCore/modules/OrdersOverrides.lua', 't', module))()
local definitions = {
    RULEUCC_Move = { id = 'RULEUCC_Move', bitmapId = 'move', helpText = 'move', preferredSlot = 2 },
    RULEUCC_Nuke = { id = 'RULEUCC_Nuke', bitmapId = 'launch-nuke', helpText = 'fire_nuke', preferredSlot = 10 },
    RULEUTC_IntelToggle = { id = 'RULEUTC_IntelToggle', bitmapId = 'intel', helpText = 'toggle_intel', preferredSlot = 9 },
}
local resolver = module.Create({
    definitions = definitions,
    behaviorWhitelist = { AutoDeployBehavior = true, AutoDeployInit = true },
})

local empty = resolver:Resolve(nil)
assert(empty.valid and next(empty.displayOverrides) == nil and next(empty.behaviorOverrides) == nil)
local noOverride = resolver:Resolve({ { General = {} }, { General = { OrderOverrides = {} } } })
assert(noOverride.valid and next(noOverride.displayOverrides) == nil)

local same = resolver:Resolve({
    { General = { OrderOverrides = { RULEUCC_Move = { bitmapId = 'custom-move', helpText = 'custom_move' } } } },
    { General = { OrderOverrides = { RULEUCC_Move = { bitmapId = 'custom-move', preferredSlot = 4 } } } },
})
assert(same.valid and same.displayOverrides.RULEUCC_Move.bitmapId == 'custom-move'
    and same.displayOverrides.RULEUCC_Move.helpText == 'custom_move'
    and same.displayOverrides.RULEUCC_Move.preferredSlot == 4,
    'identical values merge while fields omitted by a blueprint stay unchanged')

local conflict = resolver:Resolve({
    { General = { OrderOverrides = { RULEUCC_Nuke = { bitmapId = 'first', helpText = 'same', preferredSlot = 11 } } } },
    { General = { OrderOverrides = { RULEUCC_Nuke = { bitmapId = 'second', helpText = 'same', preferredSlot = 11 } } } },
})
assert(conflict.valid and conflict.displayOverrides.RULEUCC_Nuke.bitmapId == nil
    and conflict.displayOverrides.RULEUCC_Nuke.helpText == 'same'
    and conflict.displayOverrides.RULEUCC_Nuke.preferredSlot == 11,
    'conflicting bitmap falls back to catalog default while agreed display fields apply')
assert(#conflict.diagnostics == 1 and conflict.diagnostics[1].field == 'bitmapId')

local suppressed = resolver:Resolve({
    { General = { OrderOverrides = { RULEUCC_Nuke = false } } },
    { General = { OrderOverrides = { RULEUCC_Nuke = false } } },
})
assert(suppressed.displayOverrides.RULEUCC_Nuke == false, 'uniform false suppresses the order')
local falseAndNoOverride = resolver:Resolve({
    { General = { OrderOverrides = { RULEUCC_Nuke = false } } },
    { General = {} },
})
assert(falseAndNoOverride.displayOverrides.RULEUCC_Nuke == false,
    'a unit with no override contributes no conflicting value; any explicit false suppresses per native merge semantics')
local suppressionConflict = resolver:Resolve({
    { General = { OrderOverrides = { RULEUCC_Nuke = false } } },
    { General = { OrderOverrides = { RULEUCC_Nuke = { bitmapId = 'custom' } } } },
})
assert(suppressionConflict.displayOverrides.RULEUCC_Nuke == nil
    and #suppressionConflict.diagnostics == 1,
    'false versus table override deterministically keeps the catalog definition')

local malformed = resolver:Resolve({
    { General = { OrderOverrides = { RULEUCC_Move = { preferredSlot = 0, bitmapId = 17, unknown = true } } } },
    { General = { OrderOverrides = { MissingOrder = { bitmapId = 'nope' } } } },
    { General = { OrderOverrides = 'invalid' } },
    false,
})
assert(not malformed.valid and next(malformed.displayOverrides) == nil
    and next(malformed.behaviorOverrides) == nil and #malformed.diagnostics >= 5,
    'structurally malformed blueprints invalidate and clear otherwise partial overrides')
local mixedMalformed = resolver:Resolve({
    { General = { OrderOverrides = { RULEUCC_Move = { bitmapId = 'would-be-applied' } } } },
    { General = { OrderOverrides = false } },
})
assert(not mixedMalformed.valid and next(mixedMalformed.displayOverrides) == nil,
    'a malformed blueprint in a mixed selection causes the caller to fail closed for the whole batch')

local approvedBehavior = resolver:Resolve({
    { General = { OrderOverrides = {
        RULEUCC_Move = { behavior = 'AutoDeployBehavior', initialStateFunc = 'AutoDeployInit' },
    } } },
    { General = { OrderOverrides = {
        RULEUCC_Move = { behavior = 'AutoDeployBehavior', initialStateFunc = 'AutoDeployInit' },
    } } },
})
assert(approvedBehavior.behaviorOverrides.RULEUCC_Move.behaviorKey == 'AutoDeployBehavior'
    and approvedBehavior.behaviorOverrides.RULEUCC_Move.initialStateKey == 'AutoDeployInit'
    and approvedBehavior.displayOverrides.RULEUCC_Move == nil,
    'whitelisted keys resolve symbolically and remain outside display overrides')
for _, diagnostic in ipairs(approvedBehavior.diagnostics) do
    assert(diagnostic.reason == 'whitelisted behavior key resolved symbolically only; it was not executed')
end

local rejectedBehavior = resolver:Resolve({
    { General = { OrderOverrides = { RULEUCC_Move = { behavior = 'UnknownCommandBehavior' } } } },
})
assert(rejectedBehavior.behaviorOverrides.RULEUCC_Move == nil
    and #rejectedBehavior.diagnostics == 1)
local behaviorConflict = resolver:Resolve({
    { General = { OrderOverrides = { RULEUCC_Move = { behavior = 'AutoDeployBehavior' } } } },
    { General = { OrderOverrides = { RULEUCC_Move = { behavior = 'OtherBehavior' } } } },
})
assert(behaviorConflict.behaviorOverrides.RULEUCC_Move == nil,
    'a disallowed conflicting behavior key falls back to the catalog behavior')

local malformedEntry = resolver:Resolve({ { General = { OrderOverrides = { RULEUCC_Move = 1 } } } })
assert(not malformedEntry.valid and next(malformedEntry.displayOverrides) == nil
    and #malformedEntry.diagnostics == 1)
local invalidRoot = resolver:Resolve('not-a-selection')
assert(not invalidRoot.valid and #invalidRoot.diagnostics == 1)
assert(definitions.RULEUCC_Move.bitmapId == 'move' and definitions.RULEUCC_Move.preferredSlot == 2,
    'source definitions are never mutated')
print('PASS: order blueprint override conflicts, suppression, whitelist and isolation')
