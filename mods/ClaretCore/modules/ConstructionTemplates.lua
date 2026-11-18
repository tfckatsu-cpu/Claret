-- Read-only template eligibility model for a future construction HUD.
-- Faction conversion is intentionally unsupported; source records are never modified.

local function CopyValue(value, seen)
    if type(value) ~= 'table' then return value end
    if seen[value] then error('template source contains a cycle') end
    seen[value] = true
    local copy = {}
    for key, item in pairs(value) do copy[CopyValue(key, seen)] = CopyValue(item, seen) end
    seen[value] = nil
    return copy
end

function Create(ops)
    ops = ops or {}

    local function Build(selection, mobileTemplates, factoryTemplates, options)
        options = options or {}
        local entries, errors, fatalErrors, limitations = {}, {}, {}, {}
        local function Error(index, reason, template, fatal)
            local error = { sourceIndex = index, reason = reason, template = template, fatal = fatal == true }
            table.insert(errors, error)
            if fatal then table.insert(fatalErrors, error) end
        end
        if type(selection) ~= 'table' then
            Error(nil, 'selection must be a table', nil, true)
            return { entries = entries, errors = errors, fatalErrors = fatalErrors, limitations = limitations }
        end
        if type(ops.hasCategory) ~= 'function' or type(ops.isBuildable) ~= 'function'
            or type(ops.isRestricted) ~= 'function' then
            Error(nil, 'category, buildability, and restriction operations are required', nil, true)
            return { entries = entries, errors = errors, fatalErrors = fatalErrors, limitations = limitations }
        end
        if options.allowCrossFaction == true then
            table.insert(limitations, 'cross-faction template conversion is unsupported; only exact buildable IDs are eligible')
        end

        local allMobile = table.getn(selection) > 0
        local allFactories = table.getn(selection) > 0
        for index, unit in ipairs(selection) do
            if unit == nil then
                Error(index, 'selection contains an empty unit')
                allMobile, allFactories = false, false
            else
                local okMobile, mobile = pcall(ops.hasCategory, unit, 'MOBILE')
                local okFactory, factory = pcall(ops.hasCategory, unit, 'FACTORY')
                local okExternal, external = pcall(ops.hasCategory, unit, 'EXTERNALFACTORY')
                if not okMobile or not okFactory or not okExternal
                    or type(mobile) ~= 'boolean' or type(factory) ~= 'boolean' or type(external) ~= 'boolean' then
                    Error(index, 'selection category lookup failed', unit, true)
                    allMobile, allFactories = false, false
                else
                    allMobile = allMobile and mobile
                    allFactories = allFactories and (factory or external)
                end
            end
        end
        if table.getn(fatalErrors) > 0 then
            return { entries = entries, errors = errors, fatalErrors = fatalErrors, limitations = limitations }
        end

        local kind, templates
        if allFactories then
            kind, templates = 'factory', factoryTemplates
        elseif allMobile then
            kind, templates = 'mobile', mobileTemplates
        else
            return { entries = entries, errors = errors, fatalErrors = fatalErrors, limitations = limitations }
        end
        if kind == 'factory' then
            table.insert(limitations,
                'native factory future-tech metadata heuristic is unsupported; nonbuildable entries require canBuildAfter proof')
        end
        if type(templates) ~= 'table' then
            return { entries = entries, errors = errors, fatalErrors = fatalErrors, limitations = limitations, kind = kind }
        end

        local templateKeys = {}
        for key in pairs(templates) do
            if (type(key) == 'number' and key >= 1 and key < math.huge and key == math.floor(key))
                or type(key) == 'string' then
                table.insert(templateKeys, key)
            else
                Error(key, 'template collection key must be a positive integer or string')
            end
        end
        table.sort(templateKeys, function(first, second)
            if type(first) ~= type(second) then return type(first) == 'number' end
            return first < second
        end)

        local function ReadArray(value, templateIndex, fieldName)
            if type(value) ~= 'table' then
                Error(templateIndex, fieldName .. ' must be a table')
                return nil
            end
            local maxIndex = 0
            for key in pairs(value) do
                if type(key) == 'number' and key >= 1 and key < math.huge and key == math.floor(key) then
                    if key > maxIndex then maxIndex = key end
                else
                    Error(templateIndex, fieldName .. ' contains a non-array key')
                    return nil
                end
            end
            local result = {}
            for index = 1, maxIndex do
                if value[index] == nil then
                    Error(templateIndex, fieldName .. ' contains a missing entry at ' .. tostring(index))
                    return nil
                end
                result[index] = value[index]
            end
            return result
        end

        local function RestrictionAllowed(id, templateIndex, template)
            if type(id) ~= 'string' or id == '' then
                Error(templateIndex, 'template contains an invalid blueprint ID', template)
                return false
            end
            local okRestricted, restricted = pcall(ops.isRestricted, id, selection)
            if not okRestricted or type(restricted) ~= 'boolean' then
                Error(templateIndex, 'restriction check failed for ' .. id, template)
                return false
            end
            if restricted then
                Error(templateIndex, 'template contains restricted blueprint ' .. id, template)
                return false
            end
            return true
        end

        local function IsBuildable(id, templateIndex, template)
            local okBuildable, buildable = pcall(ops.isBuildable, id, selection)
            if not okBuildable or type(buildable) ~= 'boolean' then
                Error(templateIndex, 'buildability check failed for ' .. id, template)
                return nil
            end
            return buildable
        end

        local function Allowed(id, templateIndex, template)
            if not RestrictionAllowed(id, templateIndex, template) then return false end
            local buildable = IsBuildable(id, templateIndex, template)
            if buildable == false then
                Error(templateIndex, 'template contains unbuildable blueprint ' .. id, template)
            end
            return buildable == true
        end

        for _, templateIndex in ipairs(templateKeys) do
            local template = templates[templateIndex]
            local valid = type(template) == 'table'
            if not valid then
                Error(templateIndex, 'template record must be a table', template)
            elseif type(template.templateData) ~= 'table' then
                Error(templateIndex, 'templateData must be a table', template)
                valid = false
            else
                local data = ReadArray(template.templateData, templateIndex, 'templateData')
                if not data then
                    valid = false
                elseif kind == 'mobile' then
                    local blueprintCount = 0
                    for _, datum in ipairs(data) do
                        if type(datum) == 'table' then
                            blueprintCount = blueprintCount + 1
                            if not Allowed(datum[1], templateIndex, template) then
                                valid = false
                                break
                            end
                        end
                        -- Native mobile templates may contain non-table directives; they do not
                        -- represent buildable blueprint entries and are preserved as opaque data.
                    end
                    if valid and blueprintCount == 0 then
                        Error(templateIndex, 'mobile template contains no blueprint entries', template)
                        valid = false
                    end
                else
                    local ids = {}
                    local recordsValid = true
                    for _, datum in ipairs(data) do
                        if type(datum) ~= 'table' then
                            Error(templateIndex, 'factory template entry must be a table', template)
                            recordsValid = false
                            break
                        end
                        if not RestrictionAllowed(datum.id, templateIndex, template) then
                            recordsValid = false
                            break
                        end
                        table.insert(ids, datum.id)
                    end

                    if recordsValid and table.getn(ids) == 0 then
                        Error(templateIndex, 'factory template contains no blueprint entries', template)
                        recordsValid = false
                    end

                    -- Nonbuildable future entries require an integration-supplied proof of
                    -- a valid predecessor chain. The stock loose metadata heuristic is unsafe.
                    valid = recordsValid
                    if recordsValid then
                        for index, id in ipairs(ids) do
                            local buildable = IsBuildable(id, templateIndex, template)
                            if buildable == nil then
                                valid = false
                                break
                            elseif not buildable then
                                valid = false
                                if index > 1 and type(ops.canBuildAfter) == 'function' then
                                    local priorEntries = {}
                                    for priorIndex = 1, index - 1 do
                                        local copy = {}
                                        for key, value in pairs(data[priorIndex]) do copy[key] = value end
                                        table.insert(priorEntries, copy)
                                    end
                                    local okAfter, allowed = pcall(ops.canBuildAfter, id, priorEntries, selection)
                                    if okAfter and type(allowed) == 'boolean' and allowed then
                                        valid = true
                                    else
                                        if not okAfter or type(allowed) ~= 'boolean' then
                                            Error(templateIndex, 'factory predecessor validation failed for ' .. id, template)
                                        end
                                        valid = false
                                        break
                                    end
                                else
                                    Error(templateIndex, 'nonbuildable factory entry requires canBuildAfter proof: ' .. id, template)
                                    valid = false
                                    break
                                end
                            end
                        end
                    end
                end
            end

            if valid then
                local copied, sourceSnapshot = pcall(CopyValue, template, {})
                if not copied then
                    Error(templateIndex, 'template source snapshot is cyclic or malformed', template)
                else
                    table.insert(entries, {
                        type = 'templates',
                        template = template,
                        sourceIndex = templateIndex,
                        templateID = templateIndex,
                        sourceSnapshot = sourceSnapshot,
                    })
                end
            end
        end

        return { entries = entries, errors = errors, fatalErrors = fatalErrors, limitations = limitations, kind = kind }
    end

    return { Build = Build }
end
