-- Read-only-on-load enhancement action dispatcher for a future construction HUD.
-- FAF operations are injected; this module installs no hooks and issues nothing on load.
--
-- Create(ops):Dispatch(entry, modifiers, context) returns (success, resultOrError).
-- `requestConfirmation(onYes, onNo, details)` is asynchronous. No declines only the
-- conflicting unit upgrades; eligible non-conflicting units still receive orders,
-- matching FAF's OrderEnhancement(clean, false) behavior.
-- Execution requires acquireIgnoreSelectionScope() -> token and
-- releaseIgnoreSelectionScope(token) -> true. The adapter must restore the exact
-- previous ignore-selection state; FAF3840 exposes no public getter for it.

local function IsArray(value)
    if type(value) ~= 'table' then return false end
    local count, highest = 0, 0
    for key in pairs(value) do
        if type(key) ~= 'number' or key < 1 or key ~= math.floor(key) then return false end
        count = count + 1
        if key > highest then highest = key end
    end
    return count == highest
end

local function CopyArray(source)
    local copy = {}
    for index, value in ipairs(source) do copy[index] = value end
    return copy
end

local function SameSelection(first, second)
    if not IsArray(first) or not IsArray(second) or table.getn(first) ~= table.getn(second) then return false end
    for index, unit in ipairs(first) do if second[index] ~= unit then return false end end
    return true
end

local function SameConflicts(first, second)
    if table.getn(first) ~= table.getn(second) then return false end
    for index, value in ipairs(first) do
        local other = second[index]
        if value.unit ~= other.unit or value.installed ~= other.installed then return false end
    end
    return true
end

local function SameChain(first, second)
    if table.getn(first) ~= table.getn(second) then return false end
    for index, value in ipairs(first) do if second[index] ~= value then return false end end
    return true
end

function Create(ops)
    ops = ops or {}

    local function Fail(reason, extra)
        local result = { reason = reason }
        if type(extra) == 'table' then
            for key, value in pairs(extra) do result[key] = value end
        end
        return false, result
    end

    local function Query(name, ...)
        local callback = ops[name]
        if type(callback) ~= 'function' then return false, 'operation unavailable: ' .. name end
        local ok, first, second = pcall(callback, ...)
        if not ok then return false, first end
        return true, first, second
    end

    local function Call(name, ...)
        local ok, first, second = Query(name, ...)
        if not ok then return false, first end
        if first == false then return false, second or (name .. ' rejected the operation') end
        return true, first, second
    end

    local function BuildChain(enhancements, targetId, slot)
        local reversed, seen = {}, {}
        local currentId = targetId
        while currentId and currentId ~= '' do
            if seen[currentId] then return nil, 'enhancement prerequisite cycle detected' end
            seen[currentId] = true
            local current = enhancements[currentId]
            if type(current) ~= 'table' or current.Slot ~= slot then
                return nil, 'enhancement prerequisite is missing or belongs to another slot'
            end
            table.insert(reversed, currentId)
            local prerequisite = current.Prerequisite
            if prerequisite ~= nil and (type(prerequisite) ~= 'string' or prerequisite == '') then
                return nil, 'enhancement prerequisite ID is malformed'
            end
            currentId = prerequisite
        end
        local chain = {}
        for index = table.getn(reversed), 1, -1 do table.insert(chain, reversed[index]) end
        return chain
    end

    local function ValidateQueue(queue, slot, chain, installedId, clearQueue)
        if queue == nil then queue = {} end
        if not IsArray(queue) then return nil, nil, 'enhancement queue is malformed' end
        if clearQueue then return 0, false, nil, false end
        local lastIndex, removalQueued, targetQueued = 0, false, false
        local chainIndex = {}
        for index, id in ipairs(chain) do chainIndex[id] = index end
        for queueIndex, item in ipairs(queue) do
            if type(item) ~= 'table' or type(item.ID) ~= 'string' or item.ID == ''
                or type(item.Slot) ~= 'string' then
                return nil, nil, 'enhancement queue entry is malformed at index ' .. tostring(queueIndex)
            end
            if item.Slot == slot then
                local index = chainIndex[item.ID]
                if index then
                    if index <= lastIndex then return nil, nil, 'queued prerequisites are out of order' end
                    lastIndex = index
                    if index == table.getn(chain) then targetQueued = true end
                elseif installedId and item.ID == installedId .. 'Remove' then
                    if removalQueued then return nil, nil, 'duplicate installed-enhancement removal is queued' end
                    removalQueued = true
                else
                    return nil, nil, 'queued enhancement is incompatible with the selected prerequisite chain'
                end
            end
        end
        return lastIndex, removalQueued, nil, targetQueued
    end

    local function Prepare(entry, context, clean)
        if type(entry) ~= 'table' or entry.type ~= 'enhancement'
            or entry.TooltipOnly == true or entry.Disabled == true
            or type(entry.id) ~= 'string' or entry.id == '' then
            return nil, 'enhancement entry is malformed, disabled, or tooltip-only'
        end
        local selection = context.selection
        if not IsArray(selection) or table.getn(selection) == 0 then
            return nil, 'selection snapshot is malformed or empty'
        end
        local okCurrent, current = Query('getCurrentSelection')
        if not okCurrent or not SameSelection(selection, current) then return nil, 'stale selection snapshot' end
        local okSlot, currentSlot = Query('getCurrentSlot')
        if not okSlot or type(currentSlot) ~= 'string' or currentSlot == '' then
            return nil, 'current enhancement slot is unavailable'
        end
        if type(context.slot) ~= 'string' or context.slot ~= currentSlot then
            return nil, 'enhancement slot changed since presentation'
        end

        local units, blueprintId = {}, nil
        local seenUnits = {}
        for _, unit in ipairs(selection) do
            local unitType = type(unit)
            if unitType ~= 'table' and unitType ~= 'userdata' then
                return nil, 'selection contains a malformed unit reference'
            end
            if seenUnits[unit] then return nil, 'selection contains duplicate units' end
            seenUnits[unit] = true
            local okValid, valid = Query('isUnitValid', unit)
            if not okValid or valid ~= true then return nil, 'selection contains an unavailable unit' end
            local okId, unitBlueprintId = Query('getBlueprintId', unit)
            if not okId or type(unitBlueprintId) ~= 'string' or unitBlueprintId == '' then
                return nil, 'selected unit blueprint ID is unavailable'
            end
            if blueprintId and blueprintId ~= unitBlueprintId then
                return nil, 'mixed blueprint selections are unsupported'
            end
            blueprintId = unitBlueprintId
            table.insert(units, unit)
        end

        local okBlueprint, blueprint = Query('getBlueprint', blueprintId)
        if not okBlueprint or type(blueprint) ~= 'table'
            or type(blueprint.Enhancements) ~= 'table' then
            return nil, 'selected unit enhancement blueprint is unavailable'
        end
        local target = blueprint.Enhancements[entry.id]
        if type(target) ~= 'table' or type(target.Slot) ~= 'string' or target.Slot ~= currentSlot then
            return nil, 'enhancement is missing from the selected slot'
        end
        if type(entry.enhTable) ~= 'table' or entry.enhTable ~= target
            or (entry.slot ~= nil and entry.slot ~= target.Slot) then
            return nil, 'enhancement row is stale or belongs to another blueprint'
        end
        local okRestricted, restricted = Query('isRestricted', entry.id, blueprintId)
        if not okRestricted or type(restricted) ~= 'boolean' then return nil, 'enhancement restriction check failed' end
        if restricted then return nil, 'enhancement is restricted' end

        local chain, chainError = BuildChain(blueprint.Enhancements, entry.id, target.Slot)
        if not chain then return nil, chainError end
        for _, id in ipairs(chain) do
            local allowedOk, allowed = Query('isRestricted', id, blueprintId)
            if not allowedOk or type(allowed) ~= 'boolean' then return nil, 'prerequisite restriction check failed' end
            if allowed then return nil, 'enhancement prerequisite is restricted: ' .. id end
        end

        local plans, conflicts, conflictSignature = {}, {}, {}
        for _, unit in ipairs(units) do
            local okInstalled, installed = Query('getInstalled', unit)
            if not okInstalled or type(installed) ~= 'table' then return nil, 'installed enhancement state is unavailable' end
            local installedId = installed[target.Slot]
            if installedId ~= nil and type(installedId) ~= 'string' then
                return nil, 'installed enhancement slot state is malformed'
            end
            local installedIndex = 0
            for index, id in ipairs(chain) do if id == installedId then installedIndex = index; break end end
            local conflict = installedId ~= nil and installedIndex == 0
            local okUpgrading, currentlyUpgrading = Query('isCurrentlyUpgrading', unit)
            if not okUpgrading or type(currentlyUpgrading) ~= 'boolean' then
                return nil, 'enhancement queue upgrade state is unavailable'
            end
            local clearQueue = clean and not currentlyUpgrading
            local okQueue, queue = Query('getQueue', unit)
            if not okQueue then return nil, 'enhancement queue is unavailable' end
            local queuedIndex, removalQueued, queueError, targetQueued =
                ValidateQueue(queue, target.Slot, chain, installedId, clearQueue)
            if queueError then return nil, queueError end
            if installedId == entry.id then
                table.insert(plans, { unit = unit, orders = {}, noop = 'already-installed',
                    clearQueue = false, queue = queue or {} })
            elseif targetQueued then
                table.insert(plans, { unit = unit, orders = {}, noop = 'already-queued',
                    clearQueue = false, queue = queue or {} })
            else
                local orderList = {}
                local needsConfirmation = conflict and not removalQueued
                if needsConfirmation then
                    table.insert(conflicts, { unit = unit, installed = installedId })
                    table.insert(conflictSignature, { unit = unit, installed = installedId })
                end
                local highest = math.max(installedIndex, queuedIndex)
                if conflict then highest = queuedIndex end
                for index = highest + 1, table.getn(chain) do table.insert(orderList, chain[index]) end
                if conflict and not removalQueued then table.insert(orderList, 1, installedId .. 'Remove') end
                local cleanOrder = clean
                if clean then
                    local okIdle, idle = Query('isIdle', unit)
                    if not okIdle or type(idle) ~= 'boolean' then return nil, 'unit idle state is unavailable' end
                    if not idle then
                        local okCommandQueue, commandQueue = Query('getCommandQueue', unit)
                        if not okCommandQueue or not IsArray(commandQueue) or not commandQueue[1] then
                            return nil, 'unit command queue is unavailable'
                        end
                        if commandQueue[1].type == 'Script' then cleanOrder = false end
                    end
                end
                table.insert(plans, { unit = unit, orders = orderList, conflict = needsConfirmation,
                    clearQueue = clearQueue, queue = queue or {}, installed = installedId })
                plans[table.getn(plans)].cleanOrder = cleanOrder
            end
        end

        local canExecute = false
        for _, plan in ipairs(plans) do
            if table.getn(plan.orders) > 0 then canExecute = true; break end
        end
        if canExecute then
            for _, name in ipairs({ 'acquireIgnoreSelectionScope', 'releaseIgnoreSelectionScope',
                'selectUnits', 'issueCommand' }) do
                if type(ops[name]) ~= 'function' then return nil, 'operation unavailable: ' .. name end
            end
            for _, plan in ipairs(plans) do
                if table.getn(plan.orders) > 0 and plan.clearQueue and type(ops.clearEnhancementQueue) ~= 'function' then
                    return nil, 'operation unavailable: clearEnhancementQueue'
                end
            end
        end

        return {
            entry = entry, units = units, selection = CopyArray(units), blueprintId = blueprintId,
            slot = target.Slot, chain = chain, plans = plans, conflicts = conflicts,
            conflictSignature = conflictSignature, clean = clean,
            canExecute = canExecute,
        }
    end

    local function Execute(plan, allowDestroy)
        local orderCount, skippedConflicts = 0, 0
        local failed, failure = false, nil
        local scopeOk, ignoreToken = Query('acquireIgnoreSelectionScope')
        if not scopeOk or ignoreToken == nil or ignoreToken == false then
            return false, { reason = 'could not acquire ignore-selection scope', detail = ignoreToken }
        end

        for _, unitPlan in ipairs(plan.plans) do
            if unitPlan.conflict and not allowDestroy then
                skippedConflicts = skippedConflicts + 1
            elseif table.getn(unitPlan.orders) > 0 then
                if unitPlan.clearQueue then
                    local okClear, clearError = Call('clearEnhancementQueue', unitPlan.unit)
                    if not okClear then failed, failure = true, clearError; break end
                end
                local cleanOrder = unitPlan.cleanOrder
                local okSelect, selectError = Call('selectUnits', { unitPlan.unit })
                if not okSelect then failed, failure = true, selectError; break end
                for _, enhancementId in ipairs(unitPlan.orders) do
                    local okCommand, commandError = Call('issueCommand', 'UNITCOMMAND_Script',
                        { TaskName = 'EnhanceTask', Enhancement = enhancementId }, cleanOrder)
                    if not okCommand then failed, failure = true, commandError; break end
                    orderCount = orderCount + 1
                    cleanOrder = false
                end
                if failed then break end
            end
        end

        local restoredSelection, selectionError = Call('selectUnits', plan.selection)
        local releaseOk, released = Query('releaseIgnoreSelectionScope', ignoreToken)
        local restoredIgnore = releaseOk and released == true
        local ignoreRestoreError = not releaseOk and released or nil
        if releaseOk and released ~= true then ignoreRestoreError = 'scope release was not confirmed' end
        if failed then
            return false, { reason = 'enhancement command execution failed', detail = failure,
                orderCount = orderCount, partial = orderCount > 0,
                selectionRestored = restoredSelection, selectionRestoreError = selectionError,
                ignoreRestored = restoredIgnore, ignoreRestoreError = ignoreRestoreError }
        end
        if not restoredSelection or not restoredIgnore then
            return false, { reason = 'enhancement orders were issued but UI selection state could not be restored',
                detail = selectionError or ignoreRestoreError, orderCount = orderCount, partial = true,
                selectionRestored = restoredSelection, ignoreRestored = restoredIgnore }
        end
        return true, { status = skippedConflicts > 0 and 'conflicts-declined' or 'queued',
            orderCount = orderCount, skippedConflicts = skippedConflicts }
    end

    local function ReportComplete(ok, result)
        if type(ops.onComplete) == 'function' then pcall(ops.onComplete, ok, result) end
    end

    local function Dispatch(entry, modifiers, context)
        if type(entry) ~= 'table' then return Fail('enhancement entry is malformed') end
        if type(modifiers) ~= 'table' or type(context) ~= 'table' then
            return Fail('enhancement click input is malformed')
        end
        if modifiers.Left ~= true or modifiers.Right == true then
            return Fail('enhancements support left-click only')
        end
        local clean = modifiers.Shift ~= true
        local selectionSnapshot = IsArray(context.selection) and CopyArray(context.selection) or {}
        local actionEntry = {
            type = entry and entry.type,
            id = entry and entry.id,
            slot = entry and entry.slot,
            enhTable = entry and entry.enhTable,
            TooltipOnly = entry and entry.TooltipOnly,
            Disabled = entry and entry.Disabled,
        }
        local actionContext = { selection = selectionSnapshot, slot = context.slot }
        local plan, planError = Prepare(actionEntry, actionContext, clean)
        if not plan then return Fail(planError) end
        if not plan.canExecute then
            return true, { status = 'no-op', reason = 'enhancement is already installed or queued' }
        end
        if table.getn(plan.conflicts) == 0 then return Execute(plan, false) end
        if type(ops.requestConfirmation) ~= 'function' then
            return Fail('operation unavailable: requestConfirmation', { conflicts = plan.conflicts })
        end

        local settled = false
        local function Resolve(approved)
            if settled then return end
            settled = true
            local currentPlan, currentError = Prepare(actionEntry, actionContext, clean)
            if not currentPlan then
                ReportComplete(false, { reason = 'enhancement state changed before confirmation resolved', detail = currentError })
                return
            end
            if approved and (not SameConflicts(plan.conflictSignature, currentPlan.conflictSignature)
                or not SameChain(plan.chain, currentPlan.chain)) then
                ReportComplete(false, { reason = 'enhancement conflicts changed after confirmation was shown' })
                return
            end
            local ok, result = Execute(currentPlan, approved == true)
            ReportComplete(ok, result)
        end
        local okDialog, shown = Query('requestConfirmation',
            function() Resolve(true) end,
            function() Resolve(false) end,
            { slot = plan.slot, enhancementId = entry.id, conflicts = plan.conflicts })
        if not okDialog or shown ~= true then
            return Fail('enhancement conflict confirmation could not be shown', { detail = shown })
        end
        return true, { status = 'confirmation-pending', enhancementId = entry.id,
            conflictCount = table.getn(plan.conflicts) }
    end

    return { Dispatch = Dispatch }
end
