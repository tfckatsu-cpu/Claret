-- Ordered construction-grid presentation based on FAF's category and upgrade rules.
-- All engine data and restriction checks are injected; this module issues no commands.

local SortCategories = {
    'SORTCONSTRUCTION', 'SORTECONOMY', 'SORTDEFENSE',
    'SORTSTRATEGIC', 'SORTINTEL', 'SORTOTHER',
}

function Create(ops)
    ops = ops or {}

    local function Build(unitIds, options)
        options = options or {}
        local entries, errors, fatalErrors = {}, {}, {}
        local function Error(unitId, reason)
            table.insert(errors, { id = unitId, reason = reason })
        end
        local function FatalError(unitId, reason)
            local error = { id = unitId, reason = reason, fatal = true }
            table.insert(errors, error)
            table.insert(fatalErrors, error)
        end

        if type(unitIds) ~= 'table' then
            FatalError(nil, 'unit IDs must be a table')
            return { entries = entries, errors = errors, fatalErrors = fatalErrors }
        end
        if type(ops.hasCategory) ~= 'function' or type(ops.getBlueprint) ~= 'function'
            or type(ops.isRestricted) ~= 'function' then
            FatalError(nil, 'category, blueprint, and restriction operations are required')
            return { entries = entries, errors = errors, fatalErrors = fatalErrors }
        end

        local selectedUnit = options.selectedUnit
        local isStructure = false
        local selectionClassificationFailed = false
        if selectedUnit ~= nil then
            local okStruct, structure = pcall(ops.hasCategory, selectedUnit, 'STRUCTURE')
            local okFactory, factory = pcall(ops.hasCategory, selectedUnit, 'FACTORY')
            local okExternal, external = pcall(ops.hasCategory, selectedUnit, 'EXTERNALFACTORY')
            if not okStruct or not okFactory or not okExternal
                or type(structure) ~= 'boolean' or type(factory) ~= 'boolean' or type(external) ~= 'boolean' then
                FatalError(selectedUnit, 'selection category lookup failed')
                selectionClassificationFailed = true
            else
                isStructure = structure == true and factory ~= true and external ~= true
            end
        end
        if selectionClassificationFailed then
            return { entries = entries, errors = errors, fatalErrors = fatalErrors }
        end

        local buckets, seenIds = {}, {}
        for index = 1, table.getn(SortCategories) + 1 do buckets[index] = {} end
        for sourceIndex, id in ipairs(unitIds) do
            if type(id) ~= 'string' or id == '' then
                Error(id, 'blueprint ID must be a non-empty string')
            elseif seenIds[id] then
                Error(id, 'duplicate blueprint ID')
            else
                seenIds[id] = true
                local bucketIndex = table.getn(SortCategories) + 1
                local categoryFailed = false
                for categoryIndex, category in ipairs(SortCategories) do
                    local ok, matches = pcall(ops.hasCategory, id, category)
                    if not ok then
                        Error(id, 'category lookup failed for ' .. category)
                        categoryFailed = true
                        break
                    elseif type(matches) ~= 'boolean' then
                        Error(id, 'category lookup returned a non-boolean for ' .. category)
                        categoryFailed = true
                        break
                    elseif matches then
                        bucketIndex = categoryIndex
                        break
                    end
                end
                if not categoryFailed then
                    table.insert(buckets[bucketIndex], { id = id, sourceIndex = sourceIndex })
                end
            end
        end

        local orderedBuckets = {}
        for bucketIndex, bucket in ipairs(buckets) do
            local valid = {}
            for _, candidate in ipairs(bucket) do
                local id = candidate.id
                local okRestricted, restricted = pcall(ops.isRestricted, id, options.army)
                if not okRestricted or type(restricted) ~= 'boolean' then
                    Error(id, 'restriction check failed')
                elseif restricted then
                    Error(id, 'blueprint is restricted')
                else
                    local okBlueprint, blueprint = pcall(ops.getBlueprint, id)
                    if not okBlueprint or type(blueprint) ~= 'table' then
                        Error(id, 'blueprint data unavailable')
                    else
                        local priority = blueprint.BuildIconSortPriority
                        if priority == nil then priority = blueprint.StrategicIconSortPriority end
                        if type(priority) ~= 'number' or priority ~= priority
                            or priority == math.huge or priority == -math.huge then
                            Error(id, 'missing or invalid build icon sort priority')
                        else
                            candidate.priority = priority
                            candidate.blueprint = blueprint
                            table.insert(valid, candidate)
                        end
                    end
                end
            end

            table.sort(valid, function(first, second)
                if first.priority == second.priority then
                    return first.sourceIndex < second.sourceIndex
                end
                return first.priority < second.priority
            end)
            if table.getn(valid) > 0 then table.insert(orderedBuckets, valid) end
        end

        for _, bucket in ipairs(orderedBuckets) do
            local bucketEntries = {}
            for _, candidate in ipairs(bucket) do
                local blueprint = candidate.blueprint
                local general = blueprint.General
                local upgradesFrom = type(general) == 'table' and general.UpgradesFrom or nil
                local skipUpgrade = false
                if isStructure and upgradesFrom ~= nil and upgradesFrom ~= '' and upgradesFrom ~= 'none' then
                    local okRestricted, restricted = pcall(ops.isRestricted, upgradesFrom, options.army)
                    if not okRestricted or type(restricted) ~= 'boolean' then
                        Error(candidate.id, 'upgrade prerequisite restriction check failed')
                        skipUpgrade = true
                    elseif restricted then
                        Error(candidate.id, 'upgrade prerequisite is restricted: ' .. tostring(upgradesFrom))
                        skipUpgrade = true
                    else
                        table.insert(bucketEntries, { type = 'arrow' })
                    end
                end
                if not skipUpgrade then
                    table.insert(bucketEntries, { type = 'item', id = candidate.id, sourceIndex = candidate.sourceIndex })
                end
            end
            if table.getn(bucketEntries) > 0 then
                if table.getn(entries) > 0 then table.insert(entries, { type = 'spacer' }) end
                for _, entry in ipairs(bucketEntries) do table.insert(entries, entry) end
            end
        end

        return { entries = entries, errors = errors, fatalErrors = fatalErrors }
    end

    return { Build = Build }
end
