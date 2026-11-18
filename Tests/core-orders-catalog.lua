-- FAF3840 orders.lua factual metadata and safe extension catalog tests.
local module = setmetatable({}, { __index = _G })
assert(loadfile('../mods/ClaretCore/modules/OrdersCatalog.lua', 't', module))()
local catalog = module.Create()

local move = catalog:Get('RULEUCC_Move')
assert(move.id == 'RULEUCC_Move' and move.helpText == 'move' and move.bitmapId == 'move'
    and move.preferredSlot == 2 and move.native and move.behaviorKey == 'StandardOrderBehavior')
local attackMove = catalog:Get('AttackMove')
assert(attackMove.preferredSlot == 1 and attackMove.behaviorKey == 'AttackMoveBehavior')
local common = catalog:GetCommonSet()
assert(common.AttackMove and common.RULEUCC_Move and common.RULEUCC_Attack
    and common.RULEUCC_Patrol and common.RULEUCC_Stop and common.RULEUCC_Guard
    and common.RULEUCC_RetaliateToggle and not common.RULEUCC_Transport)

local transport = catalog:Get('RULEUCC_Transport')
local nuke = catalog:Get('RULEUCC_Nuke')
local tactical = catalog:Get('RULEUCC_Tactical')
assert(transport.bitmapId == 'unload' and transport.helpText == 'transport' and transport.preferredSlot == 9)
assert(nuke.bitmapId == 'launch-nuke' and nuke.helpText == 'fire_nuke' and nuke.preferredSlot == 10
    and nuke.buttonTextKey == 'NukeBtnText')
assert(tactical.bitmapId == 'launch-tactical' and tactical.preferredSlot == 10
    and tactical.buttonTextKey == 'TacticalBtnText')

local toggleFacts = {
    RULEUTC_ShieldToggle = { bitmapId = 'shield', slot = 8, extraInfo = 0 },
    RULEUTC_WeaponToggle = { bitmapId = 'toggle-weapon', slot = 8, extraInfo = 1 },
    RULEUTC_ProductionToggle = { bitmapId = 'production', slot = 10, extraInfo = 4 },
    RULEUTC_SpecialToggle = { bitmapId = 'activate-weapon', slot = 12, extraInfo = 7 },
    RULEUTC_CloakToggle = { bitmapId = 'intel-counter', slot = 12, extraInfo = 8 },
}
for id, expected in pairs(toggleFacts) do
    local definition = catalog:Get(id)
    assert(definition.bitmapId == expected.bitmapId and definition.preferredSlot == expected.slot
        and definition.extraInfo == expected.extraInfo)
    if id == 'RULEUTC_ShieldToggle' then
        assert(definition.behaviorKey == 'ShieldToggleOrderBehavior')
    else
        assert(definition.behaviorKey == 'ScriptButtonOrderBehavior')
    end
end

local nativeCount = #catalog:GetAll()
local okNative, nativeReason = catalog:RegisterExtension('RULEUCC_Move', {
    helpText = 'overwrite', bitmapId = 'overwrite', preferredSlot = 1,
})
assert(not okNative and string.find(nativeReason, 'native'))
local extensionSource = {
    helpText = 'mod_action', bitmapId = 'mod-action', preferredSlot = 13,
    behaviorKey = 'ModOrderHandler', initialStateKey = 'ModOrderInitialState',
}
assert(catalog:RegisterExtension('Mod_CustomAction', extensionSource))
extensionSource.bitmapId = 'mutated-outside-catalog'
local extension = catalog:Get('Mod_CustomAction')
assert(extension.id == 'Mod_CustomAction' and extension.bitmapId == 'mod-action'
    and extension.behaviorKey == 'ModOrderHandler' and extension.native == false)
local duplicateOk, duplicateReason = catalog:RegisterExtension('Mod_CustomAction', {
    helpText = 'another', bitmapId = 'another', preferredSlot = 13,
})
assert(not duplicateOk and string.find(duplicateReason, 'already'))
assert(#catalog:GetAll() == nativeCount + 1)
local definitions = catalog:GetDefinitions()
assert(definitions.RULEUCC_Move.id == 'RULEUCC_Move' and definitions.Mod_CustomAction.bitmapId == 'mod-action')
definitions.RULEUCC_Move.bitmapId = 'map-mutated-native'
definitions.Mod_CustomAction.bitmapId = 'map-mutated-extension'
local definitionsAgain = catalog:GetDefinitions()
assert(definitionsAgain.RULEUCC_Move.bitmapId == 'move'
    and definitionsAgain.Mod_CustomAction.bitmapId == 'mod-action',
    'ID-keyed definitions API returns isolated copies for model adapters')

local resolved = catalog:Resolve('RULEUCC_Nuke', {
    bitmapId = 'nuke-custom', helpText = 'nuke_custom', preferredSlot = 11, disabled = true,
})
assert(resolved.bitmapId == 'nuke-custom' and resolved.preferredSlot == 11 and resolved.disabled)
assert(nuke.bitmapId == 'launch-nuke' and nuke.preferredSlot == 10,
    'resolved display overrides do not mutate a prior catalog result or the catalog')
local conflict, conflictReason = catalog:Resolve('RULEUCC_Nuke', { behaviorKey = 'InjectedBehavior' })
assert(conflict == nil and conflictReason == 'unsupported or behavior-bearing override field: behaviorKey',
    'behavior-bearing override conflicts are rejected: ' .. tostring(conflict) .. ' / ' .. tostring(conflictReason))
local invalidOverride = catalog:Resolve('RULEUCC_Nuke', { id = 'RULEUCC_Stop' })
assert(invalidOverride == nil, 'override cannot replace the native ID')
local unknown = catalog:Resolve('RULEUCC_Unknown')
assert(unknown == nil)

local commonIds = catalog:GetCommonIds()
local countBefore = #commonIds
commonIds[1] = 'changed-by-caller'
assert(#catalog:GetCommonIds() == countBefore and catalog:GetCommonIds()[1] == 'RULEUCC_Move',
    'common ID results are defensive copies')
local all = catalog:GetAll()
all[1].bitmapId = 'changed-by-caller'
assert(catalog:Get(all[1].id).bitmapId ~= 'changed-by-caller', 'catalog reads are isolated copies')

for _, definition in ipairs(catalog:GetAll()) do
    assert(type(definition.behaviorKey) == 'string' or definition.behaviorKey == nil)
    assert(type(definition.behavior) ~= 'function', 'catalog contains no executable native behavior')
end
print('PASS: FAF3840 orders catalog facts, conflicts, extensions and defensive copies')
