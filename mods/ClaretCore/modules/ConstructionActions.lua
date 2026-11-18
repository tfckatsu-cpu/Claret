-- Read-only-on-load click dispatcher for a future construction HUD.
-- Engine work is only performed through explicitly injected callbacks.
--
-- Create(ops):Dispatch(data, modifiers, context) returns (success, resultOrError).
-- Context requires the exact current `selection`; queue actions also require the
-- exact current display queue. Inject query callbacks for current selection/queue,
-- unit validity, blueprints, restrictions, buildability, upgrade identity, mobile
-- build classification and external factories. Inject action callbacks for
-- selection, placement, factory/upgrade commands, queue count changes, and the
-- explicitly validated Alt reset. Queue-stack `position` is FAF's logical
-- displayed stack index (not sourceIndex); enhancement rows do not advance it.

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

local function SameSelection(first, second)
    if type(first) ~= 'table' or type(second) ~= 'table'
        or table.getn(first) ~= table.getn(second) then return false end
    for index, unit in ipairs(first) do
        if second[index] ~= unit then return false end
    end
    return true
end

local function SameQueue(first, second)
    if type(first) ~= 'table' or type(second) ~= 'table'
        or table.getn(first) ~= table.getn(second) then return false end
    for index, entry in ipairs(first) do
        local other = second[index]
        if type(entry) ~= 'table' or type(other) ~= 'table'
            or entry.type ~= other.type or entry.id ~= other.id or entry.count ~= other.count
            or entry.displayCount ~= other.displayCount then return false end
    end
    return true
end

local function HasDuplicate(values)
    local seen = {}
    for _, value in ipairs(values) do
        if value == nil or seen[value] then return true end
        seen[value] = true
    end
    return false
end

local function ValidCount(value)
    return type(value) == 'number' and value >= 1 and value == math.floor(value)
end

function Create(ops)
    ops = ops or {}

    local function Fail(reason)
        return false, { reason = reason }
    end

    local function Call(name, ...)
        local callback = ops[name]
        if type(callback) ~= 'function' then return false, 'operation unavailable: ' .. name end
        local ok, first, second = pcall(callback, ...)
        if not ok then return false, first end
        if first == false then return false, second or (name .. ' rejected the action') end
        return true, first, second
    end

    local function Query(name, ...)
        local callback = ops[name]
        if type(callback) ~= 'function' then return false, 'operation unavailable: ' .. name end
        local ok, first, second = pcall(callback, ...)
        if not ok then return false, first end
        return true, first, second
    end

    local function ValidUnit(unit)
        local ok, valid = Query('isUnitValid', unit)
        return ok and valid == true
    end

    local function ValidateSelection(snapshot)
        if not IsArray(snapshot) or table.getn(snapshot) == 0 or HasDuplicate(snapshot) then
            return false, 'selection snapshot is malformed'
        end
        if type(ops.getCurrentSelection) ~= 'function' then
            return false, 'operation unavailable: getCurrentSelection'
        end
        local ok, current = Query('getCurrentSelection')
        if not ok or not SameSelection(snapshot, current) then return false, 'stale selection snapshot' end
        for _, unit in ipairs(snapshot) do
            if not ValidUnit(unit) then return false, 'selection contains an unavailable unit' end
        end
        return true
    end

    local function ValidateQueue(snapshot)
        if not IsArray(snapshot) then return false, 'command queue snapshot is malformed' end
        if type(ops.getCurrentQueue) ~= 'function' then return false, 'operation unavailable: getCurrentQueue' end
        local ok, current = Query('getCurrentQueue')
        if not ok or not SameQueue(snapshot, current) then return false, 'stale command queue snapshot' end
        return true
    end

    local function BuildCount(modifiers)
        if modifiers.Ctrl or modifiers.Shift then return 5 end
        return 1
    end

    local function UnitStack(item, modifiers, selection)
        if not IsArray(item.units) or table.getn(item.units) == 0 or HasDuplicate(item.units) then
            return Fail('unit stack is malformed')
        end
        local members = {}
        local selected = {}
        for _, unit in ipairs(selection) do selected[unit] = true end
        for _, unit in ipairs(item.units) do
            if not ValidUnit(unit) then return Fail('unit stack contains an unavailable unit') end
            if not selected[unit] then return Fail('unit stack no longer belongs to the selection') end
            members[unit] = true
        end
        if modifiers.Left then
            local ok, err = Call('selectUnits', item.units)
            if not ok then return Fail(err) end
            return true, { action = 'select-units', units = item.units }
        end
        if not modifiers.Right then return Fail('unit stack requires left or right click') end

        local removeCount = 0
        local removeAll = true
        if ops.improvedDeselection == true then
            if modifiers.Shift and modifiers.Ctrl then removeCount = 10
            elseif modifiers.Ctrl then removeCount = 5
            elseif modifiers.Shift then removeCount = 1 end
            if removeCount > 0 then removeAll = false end
        end
        local keep, remaining = {}, removeCount
        for _, unit in ipairs(selection) do
            if members[unit] and (removeAll or remaining > 0) then
                remaining = remaining - 1
            else
                table.insert(keep, unit)
            end
        end
        if HasDuplicate(keep) then return Fail('resulting selection is ambiguous') end
        local removedCount = table.getn(selection) - table.getn(keep)
        local ok, err = Call('selectUnits', keep)
        if not ok then return Fail(err) end
        return true, { action = 'remove-units', units = keep, removedCount = removedCount }
    end

    local function GetBlueprint(id)
        local ok, blueprint = Query('getBlueprint', id)
        if not ok or type(blueprint) ~= 'table' or type(blueprint.General) ~= 'table' then
            return nil, 'blueprint is unavailable or malformed'
        end
        if type(blueprint.General.UpgradesFrom) ~= 'string' then
            return nil, 'blueprint upgrade metadata is malformed'
        end
        return blueprint
    end

    local function IsRestricted(id)
        local ok, restricted = Query('isRestricted', id)
        if not ok or type(restricted) ~= 'boolean' then return nil, 'restriction check failed' end
        return restricted
    end

    local function CheckBuildable(id)
        local restricted, err = IsRestricted(id)
        if restricted == nil then return false, err end
        if restricted then return false, 'blueprint is restricted' end
        local ok, buildable = Query('isBuildable', id)
        if not ok or buildable ~= true then return false, 'blueprint is not currently buildable' end
        return true
    end

    local function UpgradeChain(targetId, selection)
        local target, err = GetBlueprint(targetId)
        if not target then return nil, err end
        if target.General.UpgradesFrom == 'none' then return nil, 'target is not an upgrade' end
        local chain, visited, nextId = {}, {}, targetId
        local fromId = target.General.UpgradesFrom
        while fromId and fromId ~= '' and fromId ~= 'none' do
            if visited[nextId] or fromId == nextId then return nil, 'upgrade chain contains a cycle' end
            visited[nextId] = true
            table.insert(chain, 1, nextId)
            local parent, parentError = GetBlueprint(fromId)
            if not parent then return nil, parentError end
            nextId = fromId
            fromId = parent.General.UpgradesFrom
        end
        if table.getn(chain) == 0 then return nil, 'upgrade chain is empty' end

        local firstBlueprintId
        for _, unit in ipairs(selection) do
            local ok, unitBlueprintId = Query('getUnitBlueprintId', unit)
            if not ok or type(unitBlueprintId) ~= 'string' then return nil, 'selected unit blueprint ID is unavailable' end
            if firstBlueprintId and firstBlueprintId ~= unitBlueprintId then
                return nil, 'mixed unit blueprints make upgrade order ambiguous'
            end
            firstBlueprintId = unitBlueprintId
        end
        if firstBlueprintId ~= nextId then return nil, 'upgrade chain does not reach selected unit' end
        return chain
    end

    local function IsUpgradeTarget(target, selection)
        if target.General.UpgradesFrom == 'none' then return false end
        local fromBase = target.General.UpgradesFromBase
        for _, unit in ipairs(selection) do
            local ok, current = Query('getUnitBlueprint', unit)
            if not ok or type(current) ~= 'table' or type(current.General) ~= 'table'
                or type(current.BlueprintId) ~= 'string' then
                return nil, 'selected unit blueprint is unavailable'
            end
            if target.General.UpgradesFrom == current.BlueprintId
                or target.General.UpgradesFrom == current.General.UpgradesTo
                or (fromBase and fromBase ~= 'none'
                    and (fromBase == current.BlueprintId or fromBase == current.General.UpgradesFromBase)) then
                return true
            end
        end
        return false
    end

    local function ResetIfRequested(modifiers, selection)
        if not modifiers.Alt then return true end
        local ok, valid = Call('validateQueueReset', selection)
        if not ok or valid ~= true then return false, valid or 'queue reset not authorized for this selection' end
        ok, valid = Call('resetQueues', selection)
        if not ok then return false, valid end
        return true
    end

    local function PrepareBuild(id, target, count, selection)
        if target.Physics == nil or type(target.Physics.MotionType) ~= 'string' then
            return false, 'target motion metadata is unavailable'
        end
        local stationary = target.Physics.MotionType == 'RULEUMT_None'
        local needsMobile = false
        if not stationary then
            if type(ops.needsMobileBuild) ~= 'function' then
                return false, 'operation unavailable: needsMobileBuild'
            end
            local mobileOk, value = Query('needsMobileBuild', id)
            if not mobileOk or type(value) ~= 'boolean' then return false, 'mobile-build category check failed' end
            needsMobile = value
        end
        if stationary or needsMobile then
            if type(ops.startCommandMode) ~= 'function' then return false, 'operation unavailable: startCommandMode' end
            return true, { kind = 'placement', id = id }
        end

        local external, ordinary = {}, {}
        if type(ops.isExternalFactory) ~= 'function' then
            return false, 'operation unavailable: isExternalFactory'
        end
        for _, unit in ipairs(selection) do
            local ok, value = Query('isExternalFactory', unit)
            if not ok or type(value) ~= 'boolean' then return false, 'external factory check failed' end
            if value then table.insert(external, unit) else table.insert(ordinary, unit) end
        end
        if table.getn(external) > 0 then
            if type(ops.getCreator) ~= 'function' then return false, 'operation unavailable: getCreator' end
            local seen, commandUnits = {}, {}
            for _, unit in ipairs(ordinary) do
                if not seen[unit] then table.insert(commandUnits, unit); seen[unit] = true end
            end
            for _, unit in ipairs(external) do
                local ok, creator = Call('getCreator', unit)
                if not ok or not ValidUnit(creator) then return false, 'external factory creator is unavailable' end
                if not seen[creator] then table.insert(commandUnits, creator); seen[creator] = true end
            end
            if type(ops.issueBlueprintCommandToUnits) ~= 'function' then
                return false, 'operation unavailable: issueBlueprintCommandToUnits'
            end
            return true, { kind = 'external-build', id = id, count = count, units = commandUnits }
        end
        if type(ops.issueBlueprintCommand) ~= 'function' then
            return false, 'operation unavailable: issueBlueprintCommand'
        end
        return true, { kind = 'mobile-build', id = id, count = count }
    end

    local function ExecuteBuild(plan)
        if plan.kind == 'placement' then
            local ok, err = Call('startCommandMode', 'build', { name = plan.id })
            if not ok then return false, err end
            return true, { action = 'place-structure', id = plan.id }
        elseif plan.kind == 'external-build' then
            local ok, err = Call('issueBlueprintCommandToUnits', plan.units,
                'UNITCOMMAND_BuildFactory', plan.id, plan.count)
            if not ok then return false, err end
            return true, { action = 'queue-mobile-unit', id = plan.id, count = plan.count, units = plan.units }
        else
            local ok, err = Call('issueBlueprintCommand', 'UNITCOMMAND_BuildFactory', plan.id, plan.count)
            if not ok then return false, err end
            return true, { action = 'queue-mobile-unit', id = plan.id, count = plan.count }
        end
    end

    local function QueueStack(item, modifiers, queue, dragging)
        if modifiers.Left == modifiers.Right then return Fail('queue stack requires exactly one mouse button') end
        if not ValidCount(item.position) or type(item.id) ~= 'string' or item.id == '' then
            return Fail('queue stack identity or position is malformed')
        end
        local validQueue, queueError = ValidateQueue(queue)
        if not validQueue then return Fail(queueError) end
        local currentPosition, lastId, matchingPositionId, hasPosition = 0, nil, nil, false
        for _, entry in ipairs(queue) do
            if type(entry) ~= 'table' then return Fail('queue projection contains malformed entries') end
            if entry.type == 'enhancementqueue' then
                -- Native display inserts these without advancing queue positions.
            elseif entry.type == nil or entry.type == 'queuestack' then
                if type(entry.id) ~= 'string' or entry.id == '' or not ValidCount(entry.displayCount or entry.count) then
                    return Fail('queue projection contains malformed factory entries')
                end
                if dragging == true or lastId ~= entry.id then
                    currentPosition = currentPosition + 1
                end
                if currentPosition == item.position then
                    hasPosition = true
                    if matchingPositionId and matchingPositionId ~= entry.id then
                        return Fail('queue display position is ambiguous')
                    end
                    matchingPositionId = entry.id
                end
                lastId = entry.id
            else
                return Fail('queue projection type makes display positions ambiguous')
            end
        end
        if not hasPosition or matchingPositionId ~= item.id then
            return Fail('queue stack is stale or does not match its position')
        end
        local operation = modifiers.Left and 'increaseBuildCountInQueue' or 'decreaseBuildCountInQueue'
        if type(ops[operation]) ~= 'function' then return Fail('operation unavailable: ' .. operation) end
        local count = BuildCount(modifiers)
        local ok, err = Call(operation, item.position, count)
        if not ok then return Fail(err) end
        return true, { action = modifiers.Left and 'increase-queue' or 'reduce-queue',
            id = item.id, index = item.position, count = count }
    end

    local function Item(item, modifiers, selection, queue)
        if type(item.id) ~= 'string' or item.id == '' then return Fail('build item ID is malformed') end
        if modifiers.Left == modifiers.Right then return Fail('build item requires exactly one mouse button') end
        local okBuildable, buildableError = CheckBuildable(item.id)
        if not okBuildable then return Fail(buildableError) end
        local blueprint, blueprintError = GetBlueprint(item.id)
        if not blueprint then return Fail(blueprintError) end
        local count = BuildCount(modifiers)

        if modifiers.Right then
            if not IsArray(queue) then return Fail('command queue is malformed') end
            local validQueue, queueError = ValidateQueue(queue)
            if not validQueue then return Fail(queueError) end
            local matchIndex, matches = nil, 0
            for index, entry in ipairs(queue) do
                if type(entry) ~= 'table' or type(entry.id) ~= 'string' or not ValidCount(entry.count) then
                    return Fail('command queue contains malformed entries')
                end
                if entry.id == item.id then matchIndex = index; matches = matches + 1 end
            end
            if matches == 0 then return Fail('build item is absent from the command queue') end
            if matches > 1 then return Fail('duplicate queue IDs make removal index ambiguous') end
            local ok, err = Call('decreaseBuildCountInQueue', matchIndex, count)
            if not ok then return Fail(err) end
            return true, { action = 'reduce-queue', id = item.id, index = matchIndex, count = count }
        end

        local upgrade, upgradeError = IsUpgradeTarget(blueprint, selection)
        if upgrade == nil then return Fail(upgradeError) end
        if upgrade then
            local chain, chainError = UpgradeChain(item.id, selection)
            if not chain then return Fail(chainError) end
            for _, upgradeId in ipairs(chain) do
                local allowed, restrictionError = CheckBuildable(upgradeId)
                if not allowed then return Fail('upgrade chain contains unavailable blueprint: ' .. restrictionError) end
            end
            if type(ops.issueBlueprintCommand) ~= 'function' then return Fail('operation unavailable: issueBlueprintCommand') end
            if type(ops.validateBlueprintCommand) == 'function' then
                for _, upgradeId in ipairs(chain) do
                    local valid, reason = Query('validateBlueprintCommand', 'UNITCOMMAND_Upgrade', upgradeId, 1, false)
                    if not valid or reason ~= true then return Fail('upgrade command validation failed') end
                end
            end
            local reset, resetError = ResetIfRequested(modifiers, selection)
            if not reset then return Fail(resetError) end
            for _, upgradeId in ipairs(chain) do
                local issued, issueError = Call('issueBlueprintCommand', 'UNITCOMMAND_Upgrade', upgradeId, 1, false)
                if not issued then return Fail(issueError) end
            end
            return true, { action = 'upgrade', id = item.id, chain = chain }
        end
        local prepared, plan = PrepareBuild(item.id, blueprint, count, selection)
        if not prepared then return Fail(plan) end
        local reset, resetError = ResetIfRequested(modifiers, selection)
        if not reset then return Fail(resetError) end
        local issued, issueError = ExecuteBuild(plan)
        if not issued then return Fail(issueError) end
        return true, issueError
    end

    local function Dispatch(data, modifiers, context)
        if type(data) ~= 'table' or type(modifiers) ~= 'table' or type(context) ~= 'table' then
            return Fail('click input is malformed')
        end
        local snapshot = context.selection
        local validSelection, selectionError = ValidateSelection(snapshot)
        if not validSelection then return Fail(selectionError) end
        if modifiers.Left == modifiers.Right then return Fail('click must specify exactly one mouse button') end
        if data.type == 'unitstack' then
            return UnitStack(data, modifiers, snapshot)
        elseif data.type == 'item' then
            return Item(data, modifiers, snapshot, context.queue)
        elseif data.type == 'queuestack' then
            return QueueStack(data, modifiers, context.queue, context.dragging)
        elseif data.type == 'enhancement' or data.type == 'enhancementqueue'
            or data.type == 'templates' then
            return Fail('unsupported interaction type: ' .. data.type)
        end
        return Fail('unknown presentation entry type')
    end

    return { Dispatch = Dispatch }
end
