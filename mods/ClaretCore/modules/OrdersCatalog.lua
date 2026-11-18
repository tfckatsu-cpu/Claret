-- Static FAF3840 order metadata for an independent client-side presentation.
-- The catalog contains no executable native behavior and installs no hooks.

local baseRows = {
    { 'AttackMove', 'attack_move', 'attack_move', 1, 'AttackMoveBehavior' },
    { 'RULEUCC_Move', 'move', 'move', 2, 'StandardOrderBehavior' },
    { 'RULEUCC_Attack', 'attack', 'attack', 3, 'AttackOrderBehavior', 'AttackOrderInit' },
    { 'RULEUCC_Patrol', 'patrol', 'patrol', 4, 'StandardOrderBehavior' },
    { 'RULEUCC_Stop', 'stop', 'stop', 5, 'StopOrderBehavior' },
    { 'RULEUCC_Guard', 'assist', 'guard', 6, 'StandardOrderBehavior' },
    { 'RULEUCC_RetaliateToggle', 'mode', 'stand-ground', 7, 'RetaliateOrderBehavior', 'RetaliateInitFunction' },

    { 'RULEUCC_Overcharge', 'overcharge', 'overcharge', 8, 'OverchargeBehavior', 'OverchargeInit', 'OverchargeFrame' },
    { 'RULEUCC_SiloBuildTactical', 'build_tactical', 'silo-build-tactical', 9, 'BuildOrderBehavior', 'BuildInitFunction' },
    { 'RULEUCC_SiloBuildNuke', 'build_nuke', 'silo-build-nuke', 9, 'BuildOrderBehavior', 'BuildInitFunction' },
    { 'RULEUCC_Script', 'special_action', 'overcharge', 8, 'StandardOrderBehavior' },
    { 'RULEUCC_Transport', 'transport', 'unload', 9, 'TransportOrderBehavior' },
    { 'RULEUCC_Nuke', 'fire_nuke', 'launch-nuke', 10, 'StandardOrderBehavior', nil, nil, 'NukeBtnText' },
    { 'RULEUCC_Tactical', 'fire_tactical', 'launch-tactical', 10, 'StandardOrderBehavior', nil, nil, 'TacticalBtnText' },
    { 'RULEUCC_Teleport', 'teleport', 'teleport', 10, 'StandardOrderBehavior' },
    { 'RULEUCC_Ferry', 'ferry', 'ferry', 10, 'StandardOrderBehavior' },
    { 'RULEUCC_Sacrifice', 'sacrifice', 'sacrifice', 10, 'StandardOrderBehavior' },
    { 'RULEUCC_Dive', 'dive', 'dive', 11, 'DiveOrderBehavior', 'DiveInitFunction' },
    { 'RULEUCC_Reclaim', 'reclaim', 'reclaim', 12, 'StandardOrderBehavior' },
    { 'RULEUCC_Capture', 'capture', 'convert', 13, 'StandardOrderBehavior' },
    { 'RULEUCC_Repair', 'repair', 'repair', 14, 'StandardOrderBehavior' },
    { 'RULEUCC_Dock', 'dock', 'dock', 14, 'DockOrderBehavior' },
    { 'DroneL', 'drone', 'unload02', 10, 'DroneBehavior', 'DroneInit' },
    { 'DroneR', 'drone', 'unload02', 11, 'DroneBehavior', 'DroneInit' },
    { 'ExFac', 'external_factory', 'exfac', 10, 'ExternalFactoryBehavior' },

    { 'RULEUTC_ShieldToggle', 'toggle_shield', 'shield', 8, 'ShieldToggleOrderBehavior', 'ScriptButtonInitFunction', nil, nil, 0 },
    { 'RULEUTC_WeaponToggle', 'toggle_weapon', 'toggle-weapon', 8, 'ScriptButtonOrderBehavior', 'ScriptButtonInitFunction', nil, nil, 1 },
    { 'RULEUTC_JammingToggle', 'toggle_jamming', 'jamming', 9, 'ScriptButtonOrderBehavior', 'ScriptButtonInitFunction', nil, nil, 2 },
    { 'RULEUTC_IntelToggle', 'toggle_intel', 'intel', 9, 'ScriptButtonOrderBehavior', 'ScriptButtonInitFunction', nil, nil, 3 },
    { 'RULEUTC_ProductionToggle', 'toggle_production', 'production', 10, 'ScriptButtonOrderBehavior', 'ScriptButtonInitFunction', nil, nil, 4 },
    { 'RULEUTC_StealthToggle', 'toggle_stealth', 'stealth', 10, 'ScriptButtonOrderBehavior', 'ScriptButtonInitFunction', nil, nil, 5 },
    { 'RULEUTC_GenericToggle', 'toggle_generic', 'production', 11, 'ScriptButtonOrderBehavior', 'ScriptButtonInitFunction', nil, nil, 6 },
    { 'RULEUTC_SpecialToggle', 'toggle_special', 'activate-weapon', 12, 'ScriptButtonOrderBehavior', 'ScriptButtonInitFunction', nil, nil, 7 },
    { 'RULEUTC_CloakToggle', 'toggle_cloak', 'intel-counter', 12, 'ScriptButtonOrderBehavior', 'ScriptButtonInitFunction', nil, nil, 8 },
}

local commonIds = {
    'RULEUCC_Move', 'RULEUCC_Attack', 'RULEUCC_Patrol', 'RULEUCC_Stop',
    'RULEUCC_Guard', 'RULEUCC_RetaliateToggle', 'AttackMove',
}

local displayFields = { helpText = true, bitmapId = true, preferredSlot = true, disabled = true }
local extensionFields = {
    helpText = true, bitmapId = true, preferredSlot = true, disabled = true,
    behaviorKey = true, initialStateKey = true, frameKey = true,
    buttonTextKey = true, extraInfo = true,
}

local function Copy(source)
    local result = {}
    for key, value in pairs(source) do result[key] = value end
    return result
end

local function ValidDisplayValue(key, value)
    if key == 'preferredSlot' then
        return type(value) == 'number' and value >= 1 and value == math.floor(value)
    elseif key == 'disabled' then
        return type(value) == 'boolean'
    end
    return type(value) == 'string' and value ~= ''
end

function Create()
    local native, extensions = {}, {}
    for _, row in ipairs(baseRows) do
        native[row[1]] = {
            id = row[1], helpText = row[2], bitmapId = row[3], preferredSlot = row[4],
            behaviorKey = row[5], initialStateKey = row[6], frameKey = row[7],
            buttonTextKey = row[8], extraInfo = row[9], native = true,
        }
    end

    local catalog = {}
    function catalog:Get(id)
        local definition = native[id] or extensions[id]
        if not definition then return nil, 'unknown order ID' end
        return Copy(definition)
    end

    function catalog:GetAll()
        local result = {}
        for _, row in ipairs(baseRows) do table.insert(result, Copy(native[row[1]])) end
        for _, definition in pairs(extensions) do table.insert(result, Copy(definition)) end
        table.sort(result, function(a, b)
            if a.preferredSlot == b.preferredSlot then return a.id < b.id end
            return a.preferredSlot < b.preferredSlot
        end)
        return result
    end

    function catalog:GetDefinitions()
        local result = {}
        for _, row in ipairs(baseRows) do result[row[1]] = Copy(native[row[1]]) end
        for id, definition in pairs(extensions) do result[id] = Copy(definition) end
        return result
    end

    function catalog:GetCommonIds()
        local result = {}
        for _, id in ipairs(commonIds) do table.insert(result, id) end
        return result
    end

    function catalog:GetCommonSet()
        local result = {}
        for _, id in ipairs(commonIds) do result[id] = true end
        return result
    end

    function catalog:RegisterExtension(id, definition)
        if type(id) ~= 'string' or id == '' then return false, 'extension ID must be a non-empty string' end
        if native[id] then return false, 'extension cannot replace a native FAF order ID' end
        if extensions[id] then return false, 'extension ID is already registered' end
        if type(definition) ~= 'table' then return false, 'extension definition must be a table' end
        for key in pairs(definition) do
            if not extensionFields[key] then return false, 'unsupported extension metadata field: ' .. tostring(key) end
        end
        for _, key in ipairs({ 'helpText', 'bitmapId', 'preferredSlot' }) do
            if not ValidDisplayValue(key, definition[key]) then
                return false, 'extension requires valid ' .. key
            end
        end
        if definition.disabled ~= nil and not ValidDisplayValue('disabled', definition.disabled) then
            return false, 'extension disabled flag must be boolean'
        end
        for _, key in ipairs({ 'behaviorKey', 'initialStateKey', 'frameKey', 'buttonTextKey' }) do
            if definition[key] ~= nil and (type(definition[key]) ~= 'string' or definition[key] == '') then
                return false, key .. ' must be a symbolic string key'
            end
        end
        if definition.extraInfo ~= nil and type(definition.extraInfo) ~= 'number' and type(definition.extraInfo) ~= 'string' then
            return false, 'extraInfo must be a number or string'
        end
        local stored = Copy(definition)
        stored.id = id
        stored.native = false
        extensions[id] = stored
        return true
    end

    function catalog:Resolve(id, displayOverride)
        local definition = native[id] or extensions[id]
        if not definition then return nil, 'unknown order ID' end
        local result = Copy(definition)
        if displayOverride == nil then return result end
        if type(displayOverride) ~= 'table' then return nil, 'display override must be a table' end
        for key, value in pairs(displayOverride) do
            if not displayFields[key] then return nil, 'unsupported or behavior-bearing override field: ' .. tostring(key) end
            if not ValidDisplayValue(key, value) then return nil, 'invalid display override value for ' .. key end
            result[key] = value
        end
        return result
    end

    return catalog
end
