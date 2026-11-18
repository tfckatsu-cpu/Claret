-- Read-only enhancement tab and slot presentation for a future HUD.
-- All entity, queue, blueprint, and restriction queries are injected; no commands are issued.

local PreferredSlots = { Back = 1, LCH = 2, RCH = 3 }

function Create(ops)
    ops = ops or {}

    local function Build(selection)
        local slots, errors, fatalErrors = {}, {}, {}
        local function Error(enhancementId, reason, fatal)
            local error = { id = enhancementId, reason = reason, fatal = fatal == true }
            table.insert(errors, error)
            if fatal then table.insert(fatalErrors, error) end
        end
        local function Failure(reason)
            Error(nil, reason, true)
            return { slots = slots, errors = errors, fatalErrors = fatalErrors }
        end

        if type(selection) ~= 'table' or table.getn(selection) == 0 then
            return Failure('enhancement presentation requires a non-empty selection')
        end
        if type(ops.getBlueprint) ~= 'function' or type(ops.getBlueprintId) ~= 'function'
            or type(ops.getInstalled) ~= 'function'
            or type(ops.isRestricted) ~= 'function' then
            return Failure('blueprint, identity, installed, and restriction operations are required')
        end

        local unit = selection[1]
        if unit == nil then return Failure('selected unit is missing') end
        local okUnitId, unitId = pcall(ops.getBlueprintId, unit)
        if not okUnitId or type(unitId) ~= 'string' or unitId == '' then
            return Failure('selected unit blueprint ID is unavailable')
        end
        for index = 2, table.getn(selection) do
            local selectedUnit = selection[index]
            if selectedUnit == nil then return Failure('selected unit is missing at index ' .. tostring(index)) end
            local okSelectedId, selectedId = pcall(ops.getBlueprintId, selectedUnit)
            if not okSelectedId or type(selectedId) ~= 'string' or selectedId == '' then
                return Failure('selected unit blueprint ID is unavailable at index ' .. tostring(index))
            elseif selectedId ~= unitId then
                return Failure('mixed blueprint selections are unsupported')
            end
        end
        local okBlueprint, blueprint = pcall(ops.getBlueprint, unit)
        if not okBlueprint or type(blueprint) ~= 'table' or type(blueprint.Enhancements) ~= 'table' then
            return Failure('selected unit enhancement blueprint is unavailable')
        end
        local enhancements = blueprint.Enhancements
        local slotInfo = enhancements.Slots
        if slotInfo ~= nil and type(slotInfo) ~= 'table' then
            return Failure('enhancement slot definitions are malformed')
        end
        if type(slotInfo) ~= 'table' then
            return { slots = slots, errors = errors, fatalErrors = fatalErrors, unitID = unitId }
        end

        local okInstalled, installed = pcall(ops.getInstalled, unit)
        if not okInstalled or type(installed) ~= 'table' then
            return Failure('installed enhancement state is unavailable')
        end
        local queue = {}
        if table.getn(selection) == 1 then
            if type(ops.getQueue) ~= 'function' then return Failure('enhancement queue operation is required for single-unit selection') end
            local okQueue, selectedQueue = pcall(ops.getQueue, unit)
            if not okQueue or (selectedQueue ~= nil and type(selectedQueue) ~= 'table') then
                return Failure('enhancement queue state is unavailable')
            end
            queue = selectedQueue or {}
        end

        local enhancementIds = {}
        for enhancementId, enhancement in pairs(enhancements) do
            if enhancementId ~= 'Slots' then
                if type(enhancementId) ~= 'string' or enhancementId == '' or type(enhancement) ~= 'table' then
                    Error(enhancementId, 'enhancement blueprint entry is malformed')
                else
                    table.insert(enhancementIds, enhancementId)
                end
            end
        end
        table.sort(enhancementIds)
        local sourceIndexById = {}
        for index, enhancementId in ipairs(enhancementIds) do sourceIndexById[enhancementId] = index end

        local validById, prereqsById, childrenById = {}, {}, {}
        for _, enhancementId in ipairs(enhancementIds) do
            local enhancement = enhancements[enhancementId]
            if type(enhancement.Slot) ~= 'string' or enhancement.Slot == '' then
                Error(enhancementId, 'enhancement slot is missing')
            elseif type(enhancementId) == 'string' and string.find(enhancementId, 'Remove', 1, true) then
                -- Native UI deliberately hides removal pseudo-enhancements.
            else
                local okRestricted, restricted = pcall(ops.isRestricted, enhancementId, unitId)
                if not okRestricted or type(restricted) ~= 'boolean' then
                    Error(enhancementId, 'enhancement restriction check failed')
                elseif restricted then
                    Error(enhancementId, 'enhancement is restricted')
                else
                    validById[enhancementId] = enhancement
                end
            end
        end

        local function ResolvePrerequisites(enhancementId)
            if prereqsById[enhancementId] then return prereqsById[enhancementId] end
            local current = validById[enhancementId]
            local chain, seen = {}, { [enhancementId] = true }
            local prerequisite = current and current.Prerequisite
            while prerequisite ~= nil and prerequisite ~= '' do
                if type(prerequisite) ~= 'string' then
                    Error(enhancementId, 'prerequisite ID is malformed')
                    return nil
                end
                if seen[prerequisite] then
                    Error(enhancementId, 'prerequisite cycle detected at ' .. prerequisite)
                    return nil
                end
                seen[prerequisite] = true
                local parent = enhancements[prerequisite]
                if type(parent) ~= 'table' then
                    Error(enhancementId, 'prerequisite blueprint is missing: ' .. prerequisite)
                    return nil
                end
                table.insert(chain, prerequisite)
                prerequisite = parent.Prerequisite
            end
            local reversed = {}
            for index = table.getn(chain), 1, -1 do table.insert(reversed, chain[index]) end
            prereqsById[enhancementId] = reversed
            return reversed
        end

        for enhancementId, enhancement in pairs(validById) do
            local chain = ResolvePrerequisites(enhancementId)
            if chain then
                local parentId = enhancement.Prerequisite
                if parentId ~= nil and parentId ~= '' then
                    if validById[parentId] then
                        childrenById[parentId] = childrenById[parentId] or {}
                        table.insert(childrenById[parentId], enhancementId)
                    else
                        Error(enhancementId, 'prerequisite is unavailable or restricted: ' .. tostring(parentId))
                    end
                end
            else
                validById[enhancementId] = nil
            end
        end

        local slotNames = {}
        for slotName in pairs(slotInfo) do
            if type(slotName) ~= 'string' or slotName == '' then
                Error(slotName, 'enhancement slot name is malformed')
            else
                table.insert(slotNames, slotName)
            end
        end
        table.sort(slotNames, function(first, second)
            local firstOrder, secondOrder = PreferredSlots[first], PreferredSlots[second]
            if firstOrder and secondOrder then return firstOrder < secondOrder end
            if firstOrder then return true end
            if secondOrder then return false end
            return first < second
        end)

        local validQueue = {}
        for index, queued in ipairs(queue) do
            if type(queued) ~= 'table' or type(queued.Slot) ~= 'string'
                or type(queued.ID) ~= 'string' or queued.ID == '' then
                Error(nil, 'queued enhancement entry is malformed at index ' .. tostring(index), true)
            else
                table.insert(validQueue, queued)
            end
        end
        if table.getn(fatalErrors) > 0 then
            return { slots = slots, errors = errors, fatalErrors = fatalErrors, unitID = unitId }
        end

        local function IsRemoval(id)
            return string.find(id, 'Remove', 1, true) ~= nil
        end

        for _, slotName in ipairs(slotNames) do
            local roots, emitted = {}, {}
            for enhancementId, enhancement in pairs(validById) do
                if enhancement.Slot == slotName and (enhancement.Prerequisite == nil or enhancement.Prerequisite == '') then
                    table.insert(roots, enhancementId)
                end
            end
            table.sort(roots)
            local slotEntries = {}
            local function AddEnhancement(enhancementId)
                local enhancement = validById[enhancementId]
                local prereqs = prereqsById[enhancementId] or {}
                local disabled = false
                for _, queued in ipairs(validQueue) do
                    if queued.Slot == slotName and not IsRemoval(queued.ID)
                        and not table.find(prereqs, queued.ID) then
                        disabled = true
                        break
                    end
                end
                table.insert(slotEntries, {
                    type = 'enhancement',
                    id = enhancementId,
                    unitID = unitId,
                    icon = enhancement.Icon,
                    slot = slotName,
                    source = enhancement,
                    enhTable = enhancement,
                    Selected = installed[slotName] == enhancementId,
                    Disabled = disabled,
                    sourceIndex = sourceIndexById[enhancementId],
                })
                emitted[enhancementId] = true
            end

            local function EmitBranch(enhancementId, path)
                if path[enhancementId] then
                    Error(enhancementId, 'dependency cycle detected during slot traversal')
                    return
                end
                if emitted[enhancementId] or not validById[enhancementId] then return end
                path[enhancementId] = true
                AddEnhancement(enhancementId)
                local children = childrenById[enhancementId] or {}
                table.sort(children)
                for _, childId in ipairs(children) do
                    if validById[childId] and validById[childId].Slot == slotName then
                        table.insert(slotEntries, { type = 'arrow' })
                        EmitBranch(childId, path)
                    end
                end
                path[enhancementId] = nil
            end

            for _, rootId in ipairs(roots) do
                if table.getn(slotEntries) > 0 then table.insert(slotEntries, { type = 'spacer' }) end
                EmitBranch(rootId, {})
            end

            for enhancementId, enhancement in pairs(validById) do
                if enhancement.Slot == slotName and not emitted[enhancementId] then
                    Error(enhancementId, 'enhancement is not reachable from a valid prerequisite root')
                end
            end
            if table.getn(slotEntries) > 0 and slotEntries[table.getn(slotEntries)].type == 'spacer' then
                table.remove(slotEntries, table.getn(slotEntries))
            end
            table.insert(slots, { id = slotName, info = slotInfo[slotName], entries = slotEntries })
        end

        return { slots = slots, errors = errors, fatalErrors = fatalErrors, unitID = unitId }
    end

    return { Build = Build }
end
