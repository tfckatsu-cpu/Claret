-- Original, unregistered click dispatcher for a small FAF3840 order slice.
-- All engine effects are injected; loading this module performs no actions.
-- Create(ops), then dispatcher:Dispatch(row, displayedSelection, modifiers).
-- Required operations: getLiveSelection(), isAvailable(id, selection),
-- isReplay(), isObserver(). Mode actions use startCommandMode(mode, data) and
-- endCommandMode(cancel). Attack right uses toggleAttackPriority(selection,
-- toggleMode), with the stock 1/on, 2/off, 3/mixed state supplied by the row.
-- Transport right uses loadIntoTransports(clear). Dock uses dock(clear) and
-- dockDamaged(healthFraction, clear). Stop requires stop(selection, shift),
-- which must implement FAF's configured hard/soft-stop policy explicitly.

local supportedBehaviors = {
    StandardOrderBehavior = true,
    AttackMoveBehavior = true,
    AttackOrderBehavior = true,
    TransportOrderBehavior = true,
    DockOrderBehavior = true,
    StopOrderBehavior = true,
}

local function SameSelection(a, b)
    if type(a) ~= 'table' or type(b) ~= 'table' then return false end
    local countA, countB = 0, 0
    local counts = {}
    for _, unit in ipairs(a) do
        if unit == nil then return false end
        counts[unit] = (counts[unit] or 0) + 1
        countA = countA + 1
    end
    for _, unit in ipairs(b) do
        if unit == nil or not counts[unit] or counts[unit] == 0 then return false end
        counts[unit] = counts[unit] - 1
        countB = countB + 1
    end
    if countA == 0 or countA ~= countB then return false end
    for _, count in pairs(counts) do
        if count ~= 0 then return false end
    end
    return true
end

local function SafeCall(callback, ...)
    local ok, result, detail = pcall(callback, ...)
    if not ok then return false, result end
    return true, result, detail
end

function Create(ops)
    if type(ops) ~= 'table' then return nil, 'operations table is required' end
    for _, key in ipairs({ 'getLiveSelection', 'isAvailable', 'isReplay', 'isObserver' }) do
        if type(ops[key]) ~= 'function' then return nil, 'missing operation: ' .. key end
    end

    local dispatcher = {}

    function dispatcher:IsBehaviorSupported(behaviorKey)
        return type(behaviorKey) == 'string' and supportedBehaviors[behaviorKey] == true
    end

    function dispatcher:Dispatch(row, displayedSelection, modifiers)
        if type(row) ~= 'table' then return false, 'order row is malformed' end
        if type(row.id) ~= 'string' or row.id == '' then return false, 'order row has no ID' end
        if row.disabled == true or row.readOnly == true then
            return false, 'order row is disabled or read-only'
        end
        local behaviorKey = row.behaviorKey
            or (type(row.source) == 'table' and row.source.behaviorKey)
        if type(behaviorKey) ~= 'string' then return false, 'order row has no behavior key' end
        if not supportedBehaviors[behaviorKey] then
            return false, 'unsupported order behavior: ' .. behaviorKey
        end
        local sourceId = row.sourceId or row.id
        if type(sourceId) ~= 'string' or sourceId == '' then return false, 'order row has no stable source ID' end
        if type(modifiers) ~= 'table' then
            return false, 'click modifiers are malformed'
        end
        for _, key in ipairs({ 'Left', 'Right', 'Shift' }) do
            if modifiers[key] ~= nil and type(modifiers[key]) ~= 'boolean' then
                return false, 'click modifier ' .. key .. ' is malformed'
            end
        end
        local left = modifiers.Left == true
        local right = modifiers.Right == true
        local shift = modifiers.Shift == true
        if left == right then return false, 'exactly one mouse button is required' end

        local ok, replay = SafeCall(ops.isReplay)
        if not ok or type(replay) ~= 'boolean' then return false, 'replay state unavailable' end
        if replay then return false, 'orders are unavailable in replay' end
        ok, replay = SafeCall(ops.isObserver)
        if not ok or type(replay) ~= 'boolean' then return false, 'observer state unavailable' end
        if replay then return false, 'orders are unavailable to observers' end

        local liveOk, liveSelection = SafeCall(ops.getLiveSelection)
        if not liveOk or not SameSelection(displayedSelection, liveSelection) then
            return false, 'displayed unit selection is stale or empty'
        end
        local availableOk, available = SafeCall(ops.isAvailable, row.id, liveSelection)
        if not availableOk or available ~= true then return false, 'order is unavailable for live selection' end

        local action, args
        if behaviorKey == 'StandardOrderBehavior'
            or behaviorKey == 'AttackMoveBehavior'
            or (behaviorKey == 'AttackOrderBehavior' and left) then
            local checked = row.checked
            if type(checked) ~= 'boolean' then return false, 'command mode state is unavailable' end
            if checked then
                action = ops.endCommandMode
                args = { true }
            else
                action = ops.startCommandMode
                if behaviorKey == 'AttackMoveBehavior' then
                    args = { 'order', { name = 'RULEUCC_Script', AbilityName = 'AttackMove', TaskName = 'AttackMove', Cursor = 'ATTACK_MOVE' } }
                else
                    args = { 'order', { name = row.id } }
                end
            end
        elseif behaviorKey == 'AttackOrderBehavior' then
            if type(row.toggleMode) ~= 'number' or row.toggleMode < 1 or row.toggleMode > 3
                or row.toggleMode ~= math.floor(row.toggleMode) then
                return false, 'attack target-priority state is unavailable'
            end
            action, args = ops.toggleAttackPriority, { liveSelection, row.toggleMode }
        elseif behaviorKey == 'TransportOrderBehavior' then
            if left then
                local checked = row.checked
                if type(checked) ~= 'boolean' then return false, 'command mode state is unavailable' end
                if checked then
                    action, args = ops.endCommandMode, { true }
                else
                    action, args = ops.startCommandMode, { 'order', { name = row.id } }
                end
            else
                action, args = ops.loadIntoTransports, { not shift }
            end
        elseif behaviorKey == 'DockOrderBehavior' then
            if left then
                action, args = ops.dock, { not shift }
            else
                action, args = ops.dockDamaged, { 0.9, not shift }
            end
        elseif behaviorKey == 'StopOrderBehavior' then
            if not left then return false, 'right-click stop is unsupported' end
            action, args = ops.stop, { liveSelection, shift }
        end

        if type(action) ~= 'function' then return false, 'required operation is unavailable' end
        local operationResult, operationDetail
        ok, operationResult, operationDetail = false, nil, nil
        -- Build the argument call without relying on unpack variants in LuaPlus.
        if table.getn(args) == 1 then
            ok, operationResult, operationDetail = SafeCall(action, args[1])
        elseif table.getn(args) == 2 then
            ok, operationResult, operationDetail = SafeCall(action, args[1], args[2])
        elseif table.getn(args) == 3 then
            ok, operationResult, operationDetail = SafeCall(action, args[1], args[2], args[3])
        else
            return false, 'internal operation argument shape is invalid'
        end
        if not ok then return false, operationResult end
        if operationResult == false then return false, operationDetail or 'operation rejected' end
        return true, { sourceId = sourceId, orderId = row.id, behaviorKey = behaviorKey }
    end

    return dispatcher
end
