-- Native-shaped definitions, availability and state presentation tests.
table.getn = table.getn or function(value) return #value end
local module = setmetatable({}, { __index = _G })
assert(loadfile('../mods/ClaretCore/modules/OrdersPanelModel.lua', 't', module))()

local behaviorCalls, initializerCalls = 0, 0
local function nativeOrder(helpText, bitmapId, preferredSlot)
    return {
        helpText = helpText,
        bitmapId = bitmapId,
        preferredSlot = preferredSlot,
        behavior = function() behaviorCalls = behaviorCalls + 1 end,
        initialStateFunc = function() initializerCalls = initializerCalls + 1 end,
    }
end

local definitions = {
    AttackMove = nativeOrder('attack_move', 'attack_move', 1),
    RULEUCC_Move = nativeOrder('move', 'move', 2),
    RULEUCC_Attack = nativeOrder('attack', 'attack', 3),
    RULEUCC_Patrol = nativeOrder('patrol', 'patrol', 4),
    RULEUCC_Stop = nativeOrder('stop', 'stop', 5),
    RULEUCC_Guard = nativeOrder('assist', 'guard', 6),
    RULEUCC_RetaliateToggle = nativeOrder('mode', 'stand-ground', 7),
    RULEUCC_Overcharge = nativeOrder('overcharge', 'overcharge', 8),
    RULEUCC_SiloBuildTactical = nativeOrder('build_tactical', 'silo-build-tactical', 9),
    RULEUCC_SiloBuildNuke = nativeOrder('build_nuke', 'silo-build-nuke', 9),
    RULEUTC_ShieldToggle = nativeOrder('toggle_shield', 'shield', 8),
    RULEUTC_WeaponToggle = nativeOrder('toggle_weapon', 'toggle-weapon', 8),
    ExtensionAction = nativeOrder('extension_action', 'ext-action', 12),
}
local commonOrder = {
    'AttackMove', 'RULEUCC_Move', 'RULEUCC_Attack', 'RULEUCC_Patrol',
    'RULEUCC_Stop', 'RULEUCC_Guard', 'RULEUCC_RetaliateToggle',
}
local model = module.Create({
    definitions = definitions,
    commonOrder = commonOrder,
    firstAltSlot = 8,
    totalSlots = 14,
})

local snapshot = {
    availableOrders = {
        'RULEUCC_Move', 'RULEUCC_Stop', 'RULEUCC_Overcharge',
        'RULEUCC_SiloBuildTactical', 'RULEUCC_SiloBuildNuke', 'RULEUCC_Pause',
    },
    availableToggles = { 'RULEUTC_ShieldToggle', 'RULEUTC_WeaponToggle', 'ExtensionAction' },
    checkboxStates = {
        RULEUCC_Attack = { checked = true, mixed = true },
        RULEUCC_Overcharge = true,
        RULEUTC_ShieldToggle = { checked = false, mixed = true },
    },
}
local ok, err = model:SetSnapshot(snapshot)
assert(ok, err)
local items = model:GetItems()
local function at(id) return model:GetById(id) end
assert(#items == 13, 'renders seven common plus six available alternate IDs that have definitions')
assert(at('AttackMove').slot == 1 and at('RULEUCC_Move').slot == 2)
assert(at('RULEUCC_Attack').checked and at('RULEUCC_Attack').mixed,
    'caller-supplied mixed checkbox state is preserved')
assert(at('RULEUCC_Patrol').disabled and at('RULEUCC_Guard').disabled
    and at('RULEUCC_RetaliateToggle').disabled,
    'common order cells remain visible and disabled when unavailable')
assert(not at('RULEUCC_Move').disabled and not at('RULEUCC_Stop').disabled)
assert(at('RULEUCC_Overcharge').slot == 8 and at('RULEUCC_SiloBuildTactical').slot == 9)
assert(at('RULEUTC_ShieldToggle').slot == 10 and at('RULEUTC_WeaponToggle').slot == 11
    and at('RULEUCC_SiloBuildNuke').slot == 13 and at('ExtensionAction').slot == 12,
    'same-preferred-slot entries spill into the first free native alternate slots')
assert(at('ExtensionAction').slot == 12, 'extension IDs work when definitions are injected')
assert(at('RULEUCC_Overcharge').bitmapId == 'overcharge' and at('RULEUCC_Overcharge').source == definitions.RULEUCC_Overcharge)
assert(at('RULEUCC_Pause') == nil, 'unknown special order is withheld without invoking its behavior')
assert(model:GetUnknown()[1].id == 'RULEUCC_Pause')
assert(behaviorCalls == 0 and initializerCalls == 0, 'native order callbacks and initializers are never executed')

local overrideOk, overrideError = model:SetSnapshot({
    availableOrders = { 'RULEUCC_Overcharge', 'RULEUCC_SiloBuildTactical', 'RULEUCC_SiloBuildNuke' },
    availableToggles = {},
    blueprintOverrides = {
        RULEUCC_Overcharge = { bitmapId = 'custom-overcharge', helpText = 'custom-help', preferredSlot = 12 },
        RULEUCC_SiloBuildTactical = false,
        RULEUCC_SiloBuildNuke = { preferredSlot = 12 },
    },
    states = { RULEUCC_Overcharge = false },
})
assert(overrideOk, overrideError)
assert(at('RULEUCC_SiloBuildTactical') == nil, 'false blueprint override suppresses an order')
assert(at('RULEUCC_Overcharge').bitmapId == 'custom-overcharge'
    and at('RULEUCC_Overcharge').helpText == 'custom-help'
    and at('RULEUCC_Overcharge').slot == 12,
    'normalized blueprint display fields override the base definition without mutating it')
assert(at('RULEUCC_SiloBuildNuke').slot == 8,
    'overridden preferred-slot collisions use native first-free spillover')
assert(definitions.RULEUCC_Overcharge.bitmapId == 'overcharge'
    and definitions.RULEUCC_Overcharge.behavior ~= nil,
    'injected definitions remain untouched')

local readonlyOk = model:SetSnapshot({
    availableOrders = { 'RULEUCC_Move', 'RULEUCC_Overcharge' },
    availableToggles = {},
    readOnly = true,
})
assert(readonlyOk and at('RULEUCC_Move').disabled and at('RULEUCC_Overcharge').disabled,
    'read-only snapshots disable all visible entries')
local replayOk = model:SetSnapshot({
    availableOrders = { 'RULEUCC_Move', 'RULEUCC_Overcharge' },
    availableToggles = {},
    replay = true,
})
assert(replayOk and at('RULEUCC_Move').disabled and at('RULEUCC_Overcharge').disabled,
    'replay snapshots fail closed for every visible action')

local invalidOk = model:SetSnapshot({
    availableOrders = { 'RULEUCC_Move' },
    availableToggles = {},
    states = { RULEUCC_Move = 'checked' },
})
assert(not invalidOk and model:GetItems()[1] == nil,
    'malformed state invalidates the snapshot and clears stale actionable rows')

local updateOk = model:SetSnapshot({
    availableOrders = { 'RULEUCC_Move', 'ExtensionAction' },
    availableToggles = {},
})
assert(updateOk and at('RULEUCC_Overcharge') == nil and at('ExtensionAction').slot == 12,
    'capability changes replace stale dynamic orders while preserving injected extensions')
assert(behaviorCalls == 0 and initializerCalls == 0)
model:Reset()
assert(#model:GetItems() == 0 and model:GetById('RULEUCC_Move') == nil)
print('PASS: orders model native IDs, availability, slots, overrides, state and replay safety')
