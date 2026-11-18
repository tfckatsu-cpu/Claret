-- Read-only-on-load template click dispatcher for a future construction HUD.
-- FAF3840's mobile templates preserve width/height plus ordered [id, order, x, z]
-- entries; factory templates preserve ordered { id, count } entries.
--
-- Create(ops):Dispatch(entry, modifiers, context) returns (success, resultOrError).
-- Context requires kind ('mobile' or 'factory') and the exact live selection.
-- Each rendered entry must also carry sourceSnapshot: an immutable deep copy
-- captured when it was displayed. validateTemplateCurrent(kind, sourceId,
-- sourceSnapshot, sourceTemplateRef) must resolve the current stored record by
-- stable ID, verify the same source object, and compare its content before any UI
-- or engine callback can run. The source reference is passed read-only.
-- All engine/UI work is delegated to injected callbacks; no stored source template
-- is passed to a mutating operation.

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

local function IsSourceId(value)
    return (type(value) == 'number' and value >= 1 and value == math.floor(value))
        or (type(value) == 'string' and value ~= '')
end

local function SameSelection(first, second)
    if type(first) ~= 'table' or type(second) ~= 'table'
        or table.getn(first) ~= table.getn(second) then return false end
    for index, unit in ipairs(first) do
        if second[index] ~= unit then return false end
    end
    return true
end

local function SameValue(first, second, seen)
    if type(first) ~= type(second) then return false end
    if type(first) ~= 'table' then return first == second end
    seen = seen or {}
    if seen[first] == second then return true end
    if seen[first] ~= nil then return false end
    seen[first] = second
    for key, value in pairs(first) do
        if not SameValue(value, second[key], seen) then return false end
    end
    for key in pairs(second) do
        if first[key] == nil then return false end
    end
    return true
end

local function CopyValue(value, seen)
    if type(value) ~= 'table' then return value end
    if seen[value] then error('template data contains a cycle') end
    seen[value] = true
    local result = {}
    for key, item in pairs(value) do result[CopyValue(key, seen)] = CopyValue(item, seen) end
    seen[value] = nil
    return result
end

function Create(ops)
    ops = ops or {}

    local function Fail(reason)
        return false, { reason = reason }
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
        if first == false then return false, second or (name .. ' rejected the action') end
        return true, first, second
    end

    local function ValidateSelection(selection)
        if not IsArray(selection) or table.getn(selection) == 0 then
            return false, 'selection snapshot is malformed or empty'
        end
        local ok, current = Query('getCurrentSelection')
        if not ok or not SameSelection(selection, current) then return false, 'stale selection snapshot' end
        for _, unit in ipairs(selection) do
            local validOk, valid = Query('isUnitValid', unit)
            if not validOk or valid ~= true then return false, 'selection contains an unavailable unit' end
        end
        return true
    end

    local function ValidateSelectionKind(kind, selection)
        for _, unit in ipairs(selection) do
            local okMobile, mobile = Query('hasCategory', unit, 'MOBILE')
            if not okMobile or type(mobile) ~= 'boolean' then return false, 'mobile category lookup failed' end
            local okFactory, factory = Query('hasCategory', unit, 'FACTORY')
            if not okFactory or type(factory) ~= 'boolean' then return false, 'factory category lookup failed' end
            local okExternal, external = Query('hasCategory', unit, 'EXTERNALFACTORY')
            if not okExternal or type(external) ~= 'boolean' then return false, 'external factory category lookup failed' end
            if kind == 'mobile' and not mobile then return false, 'mobile template requires a mobile selection' end
            if kind == 'factory' and not (factory or external) then
                return false, 'factory template requires a factory selection'
            end
        end
        return true
    end

    local function ReadTemplate(entry, kind)
        if type(entry) ~= 'table' or type(entry.template) ~= 'table'
            or type(entry.template.templateData) ~= 'table' then
            return nil, 'template entry is malformed'
        end
        local sourceId = entry.sourceIndex
        if sourceId == nil then sourceId = entry.templateID end
        if sourceId == nil then sourceId = entry.sourceId end
        if not IsSourceId(sourceId) then return nil, 'template source identity is missing' end
        local data = entry.template.templateData
        if not IsArray(data) then return nil, 'template data is not a dense array' end
        if type(entry.sourceSnapshot) ~= 'table' then
            return nil, 'immutable template source snapshot is required'
        end

        if kind == 'mobile' then
            if table.getn(data) < 3 or type(data[1]) ~= 'number' or data[1] <= 0
                or type(data[2]) ~= 'number' or data[2] <= 0 then
                return nil, 'mobile template geometry header is malformed'
            end
            local count = 0
            for index = 3, table.getn(data) do
                local building = data[index]
                if type(building) ~= 'table' or type(building[1]) ~= 'string' or building[1] == ''
                    or type(building[2]) ~= 'number' or type(building[3]) ~= 'number'
                    or type(building[4]) ~= 'number' then
                    return nil, 'mobile template building geometry is malformed at index ' .. tostring(index)
                end
                count = count + 1
            end
            if count == 0 then return nil, 'mobile template contains no buildings' end
            return { kind = kind, sourceId = sourceId, sourceTemplate = entry.template,
                sourceSnapshot = entry.sourceSnapshot, sourceData = data,
                firstBlueprintId = data[3][1], count = count }
        elseif kind == 'factory' then
            if table.getn(data) == 0 then return nil, 'factory template contains no queue entries' end
            local records = {}
            for index, factoryEntry in ipairs(data) do
                if type(factoryEntry) ~= 'table' or type(factoryEntry.id) ~= 'string'
                    or factoryEntry.id == '' or type(factoryEntry.count) ~= 'number'
                    or factoryEntry.count < 1 or factoryEntry.count ~= math.floor(factoryEntry.count) then
                    return nil, 'factory template entry is malformed at index ' .. tostring(index)
                end
                local copy = {}
                for key, value in pairs(factoryEntry) do copy[key] = value end
                table.insert(records, copy)
            end
            return { kind = kind, sourceId = sourceId, sourceTemplate = entry.template,
                sourceSnapshot = entry.sourceSnapshot, sourceData = data, records = records }
        end
        return nil, 'unknown template kind'
    end

    local function Blueprint(id)
        local ok, blueprint = Query('getBlueprint', id)
        if not ok or type(blueprint) ~= 'table' or type(blueprint.General) ~= 'table'
            or type(blueprint.General.UpgradesFrom) ~= 'string' then
            return nil, 'blueprint or upgrade metadata is unavailable for ' .. tostring(id)
        end
        return blueprint
    end

    local function CheckBlueprint(id, selection)
        local okRestricted, restricted = Query('isRestricted', id, selection)
        if not okRestricted or type(restricted) ~= 'boolean' then
            return false, 'restriction check failed for ' .. id
        end
        if restricted then return false, 'template contains restricted blueprint ' .. id end
        local okBuildable, buildable = Query('isBuildable', id, selection)
        if not okBuildable or type(buildable) ~= 'boolean' then
            return false, 'buildability check failed for ' .. id
        end
        return true, buildable
    end

    local function PrepareMobile(plan, selection)
        for index = 3, table.getn(plan.sourceData) do
            local id = plan.sourceData[index][1]
            local allowed, buildableOrError = CheckBlueprint(id, selection)
            if not allowed then return false, buildableOrError end
            if not buildableOrError then return false, 'template blueprint is not buildable: ' .. id end
            local blueprint, blueprintError = Blueprint(id)
            if not blueprint then return false, blueprintError end
        end
        if type(ops.validateMobileTemplate) ~= 'function' then
            return false, 'operation unavailable: validateMobileTemplate'
        end
        local ok, validationData = pcall(CopyValue, plan.sourceData, {})
        if not ok then return false, 'template geometry cannot be copied for validation' end
        local validCheck, validTemplate = Query('validateMobileTemplate', validationData,
            selection, plan.firstBlueprintId)
        if not validCheck or validTemplate ~= true then return false, 'mobile template validation failed' end
        for _, operation in ipairs({ 'clearActiveBuildTemplate', 'startCommandMode', 'setActiveBuildTemplate' }) do
            if type(ops[operation]) ~= 'function' then return false, 'operation unavailable: ' .. operation end
        end
        local copied, geometry = pcall(CopyValue, plan.sourceData, {})
        if not copied then return false, 'template geometry cannot be copied safely' end
        return true, { geometry = geometry, firstBlueprintId = plan.firstBlueprintId, sourceId = plan.sourceId }
    end

    local function ValidateCurrentSource(plan)
        if type(ops.validateTemplateCurrent) ~= 'function' then
            return false, 'operation unavailable: validateTemplateCurrent'
        end
        local okCopy, snapshot = pcall(CopyValue, plan.sourceSnapshot, {})
        if not okCopy then return false, 'stored template snapshot is malformed or cyclic' end
        if not SameValue(plan.sourceTemplate, snapshot) then
            return false, 'template content changed since it was displayed'
        end
        local okArgument, callbackSnapshot = pcall(CopyValue, snapshot, {})
        if not okArgument then return false, 'stored template snapshot cannot be validated safely' end
        local ok, current = Query('validateTemplateCurrent', plan.kind, plan.sourceId,
            callbackSnapshot, plan.sourceTemplate)
        if not ok or current ~= true then
            return false, 'template source is missing, reordered, or changed since presentation'
        end
        plan.sourceSnapshot = snapshot
        return true
    end

    local function PrepareFactory(plan, selection)
        local commands, priorEntries = {}, {}
        for index, factoryEntry in ipairs(plan.records) do
            local id, count = factoryEntry.id, factoryEntry.count
            local valid, buildableOrError = CheckBlueprint(id, selection)
            if not valid then return false, buildableOrError end
            local blueprint, blueprintError = Blueprint(id)
            if not blueprint then return false, blueprintError end
            local isUpgrade = blueprint.General.UpgradesFrom ~= 'none'
            if not buildableOrError then
                if not isUpgrade or index == 1 or type(ops.canBuildAfter) ~= 'function' then
                    return false, 'nonbuildable factory entry lacks verified upgrade predecessors: ' .. id
                end
                local copyOk, priorCopy = pcall(CopyValue, priorEntries, {})
                if not copyOk then return false, 'factory predecessor list cannot be copied safely' end
                local okAfter, allowed = Query('canBuildAfter', id, priorCopy, selection)
                if not okAfter or allowed ~= true then
                    return false, 'factory upgrade dependency check failed for ' .. id
                end
            end
            local command, commandCount
            if isUpgrade then
                command, commandCount = 'UNITCOMMAND_Upgrade', 1
            else
                command, commandCount = 'UNITCOMMAND_BuildFactory', count
            end
            if type(ops.validateFactoryCommand) ~= 'function' then
                return false, 'operation unavailable: validateFactoryCommand'
            end
            local copyOk, priorCopy = pcall(CopyValue, priorEntries, {})
            if not copyOk then return false, 'factory command context cannot be copied safely' end
            local okCommand, commandAllowed = Query('validateFactoryCommand', command, id,
                commandCount, selection, priorCopy)
            if not okCommand or commandAllowed ~= true then
                return false, 'factory command validation failed for ' .. id
            end
            if type(ops.issueBlueprintCommand) ~= 'function' then
                return false, 'operation unavailable: issueBlueprintCommand'
            end
            table.insert(commands, { command = command, id = id, count = commandCount })
            table.insert(priorEntries, factoryEntry)
        end
        return true, { commands = commands, sourceId = plan.sourceId }
    end

    local function ValidateEligibility(plan, selection)
        if plan.kind == 'mobile' then
            for index = 3, table.getn(plan.sourceData) do
                local id = plan.sourceData[index][1]
                local valid, buildableOrError = CheckBlueprint(id, selection)
                if not valid then return false, buildableOrError end
                if not buildableOrError then return false, 'template blueprint is not buildable: ' .. id end
                local blueprint, blueprintError = Blueprint(id)
                if not blueprint then return false, blueprintError end
            end
            return true
        end
        local priorEntries = {}
        for index, entry in ipairs(plan.records) do
            local valid, buildableOrError = CheckBlueprint(entry.id, selection)
            if not valid then return false, buildableOrError end
            local blueprint, blueprintError = Blueprint(entry.id)
            if not blueprint then return false, blueprintError end
            local isUpgrade = blueprint.General.UpgradesFrom ~= 'none'
            if not buildableOrError then
                if not isUpgrade or index == 1 or type(ops.canBuildAfter) ~= 'function' then
                    return false, 'nonbuildable factory entry lacks verified upgrade predecessors: ' .. entry.id
                end
                local copyOk, priorCopy = pcall(CopyValue, priorEntries, {})
                if not copyOk then return false, 'factory predecessor list cannot be copied safely' end
                local okAfter, allowed = Query('canBuildAfter', entry.id, priorCopy, selection)
                if not okAfter or allowed ~= true then
                    return false, 'factory upgrade dependency check failed for ' .. entry.id
                end
            end
            table.insert(priorEntries, entry)
        end
        return true
    end

    local function Options(plan)
        if type(ops.toggleOptions) ~= 'function' then return Fail('operation unavailable: toggleOptions') end
        if plan.kind == 'mobile' and type(ops.clearActiveBuildTemplate) ~= 'function' then
            return Fail('operation unavailable: clearActiveBuildTemplate')
        end
        local copied, templateCopy = pcall(CopyValue, plan.sourceSnapshot, {})
        if not copied then return Fail('template options input cannot be copied safely') end
        if plan.kind == 'mobile' then
            local ok, err = Call('clearActiveBuildTemplate')
            if not ok then return Fail(err) end
        end
        local ok, err = Call('toggleOptions', plan.kind, plan.sourceId, templateCopy)
        if not ok then return Fail(err) end
        return true, { action = 'template-options', kind = plan.kind, sourceId = plan.sourceId }
    end

    local function Dispatch(entry, modifiers, context)
        if type(entry) ~= 'table' or entry.type ~= 'templates'
            or type(modifiers) ~= 'table' or type(context) ~= 'table' then
            return Fail('template click input is malformed')
        end
        local kind = context.kind
        if kind ~= 'mobile' and kind ~= 'factory' then return Fail('template kind is unavailable or unsupported') end
        local validSelection, selectionError = ValidateSelection(context.selection)
        if not validSelection then return Fail(selectionError) end
        local validKind, kindError = ValidateSelectionKind(kind, context.selection)
        if not validKind then return Fail(kindError) end
        local left, right = modifiers.Left == true, modifiers.Right == true
        if left == right then return Fail('template click requires exactly one mouse button') end
        local plan, planError = ReadTemplate(entry, kind)
        if not plan then return Fail(planError) end
        local current, currentError = ValidateCurrentSource(plan)
        if not current then return Fail(currentError) end

        if right then
            local eligible, eligibilityError = ValidateEligibility(plan, context.selection)
            if not eligible then return Fail(eligibilityError) end
            return Options(plan)
        end
        if kind == 'mobile' then
            local prepared, mobilePlan = PrepareMobile(plan, context.selection)
            if not prepared then return Fail(mobilePlan) end
            local copied, dialog = pcall(function() return { name = mobilePlan.firstBlueprintId } end)
            if not copied then return Fail('build mode arguments could not be prepared') end
            local ok, err = Call('clearActiveBuildTemplate')
            if not ok then return Fail(err) end
            ok, err = Call('startCommandMode', 'build', dialog)
            if not ok then return Fail(err) end
            ok, err = Call('setActiveBuildTemplate', mobilePlan.geometry)
            if not ok then return Fail(err) end
            return true, { action = 'activate-mobile-template', sourceId = plan.sourceId,
                firstBlueprintId = mobilePlan.firstBlueprintId, buildingCount = plan.count }
        end

        local prepared, factoryPlan = PrepareFactory(plan, context.selection)
        if not prepared then return Fail(factoryPlan) end
        for _, command in ipairs(factoryPlan.commands) do
            local ok, err
            if command.command == 'UNITCOMMAND_Upgrade' then
                ok, err = Call('issueBlueprintCommand', command.command, command.id, command.count, false)
            else
                ok, err = Call('issueBlueprintCommand', command.command, command.id, command.count)
            end
            if not ok then return Fail(err) end
        end
        return true, { action = 'queue-factory-template', sourceId = plan.sourceId,
            commandCount = table.getn(factoryPlan.commands) }
    end

    return { Dispatch = Dispatch }
end
