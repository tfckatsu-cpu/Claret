-- Deterministic, presentation-only resolver for selected blueprint overrides.
-- FAF3840 orders.lua comments say conflicting values fall back to defaults,
-- but its ApplyOverrides merge retains earlier conflicting fields; false plus
-- a later table may also index a boolean. This resolver avoids both cases.
-- A missing override on another selected blueprint is not a conflict with false:
-- native code only records keys that are explicitly present.

local displayFields = { bitmapId = true, helpText = true, preferredSlot = true }

local function ValidValue(field, value)
    if field == 'preferredSlot' then
        return type(value) == 'number' and value >= 1 and value == math.floor(value)
    end
    return type(value) == 'string' and value ~= ''
end

local function AddDiagnostic(target, unitIndex, orderId, field, reason)
    table.insert(target, {
        unitIndex = unitIndex,
        orderId = orderId,
        field = field,
        reason = reason,
    })
end

function Create(options)
    options = options or {}
    local definitions = options.definitions or {}
    local behaviorWhitelist = options.behaviorWhitelist or {}
    if type(definitions) ~= 'table' then error('order definitions must be an ID-keyed table') end
    if type(behaviorWhitelist) ~= 'table' then error('behavior whitelist must be a table') end

    local resolver = {}
    function resolver:Resolve(selectedBlueprints)
        local result = {
            displayOverrides = {},
            behaviorOverrides = {},
            diagnostics = {},
            valid = true,
        }
        if selectedBlueprints == nil then return result end
        if type(selectedBlueprints) ~= 'table' then
            result.valid = false
            AddDiagnostic(result.diagnostics, nil, nil, nil, 'selected blueprint list must be a table')
            return result
        end
        local selectionCount = table.getn(selectedBlueprints)
        for key in pairs(selectedBlueprints) do
            if type(key) ~= 'number' or key < 1 or key > selectionCount or key ~= math.floor(key) then
                result.valid = false
                AddDiagnostic(result.diagnostics, nil, nil, nil, 'selected blueprint list must be a dense array')
                return result
            end
        end

        local accumulators = {}
        local function Accumulate(orderId)
            if not accumulators[orderId] then
                accumulators[orderId] = {
                    values = {}, conflicts = {}, suppressions = 0, records = 0,
                }
            end
            return accumulators[orderId]
        end

        for unitIndex, blueprint in ipairs(selectedBlueprints) do
            if type(blueprint) ~= 'table' then
                result.valid = false
                AddDiagnostic(result.diagnostics, unitIndex, nil, nil, 'blueprint entry must be a table')
            else
                local general = blueprint.General
                if general ~= nil and type(general) ~= 'table' then
                    result.valid = false
                    AddDiagnostic(result.diagnostics, unitIndex, nil, nil, 'blueprint General field must be a table')
                elseif general and general.OrderOverrides ~= nil and type(general.OrderOverrides) ~= 'table' then
                    result.valid = false
                    AddDiagnostic(result.diagnostics, unitIndex, nil, nil, 'General.OrderOverrides must be a table')
                elseif general and general.OrderOverrides then
                    for orderId, override in pairs(general.OrderOverrides) do
                        if type(orderId) ~= 'string' or orderId == '' then
                            result.valid = false
                            AddDiagnostic(result.diagnostics, unitIndex, tostring(orderId), nil, 'override key must be a native order ID')
                        elseif not definitions[orderId] then
                            AddDiagnostic(result.diagnostics, unitIndex, orderId, nil, 'override has no catalog definition')
                        elseif override == false then
                            local entry = Accumulate(orderId)
                            entry.suppressions = entry.suppressions + 1
                        elseif type(override) == 'table' then
                            local entry = Accumulate(orderId)
                            entry.records = entry.records + 1
                            for field, value in pairs(override) do
                                if displayFields[field] then
                                    if not ValidValue(field, value) then
                                        result.valid = false
                                        entry.conflicts[field] = true
                                        entry.values[field] = nil
                                        AddDiagnostic(result.diagnostics, unitIndex, orderId, field, 'invalid display override value')
                                    elseif not entry.conflicts[field] then
                                        local prior = entry.values[field]
                                        if prior ~= nil and prior ~= value then
                                            entry.values[field] = nil
                                            entry.conflicts[field] = true
                                            AddDiagnostic(result.diagnostics, unitIndex, orderId, field,
                                                'selected blueprints disagree; catalog default is retained')
                                        else
                                            entry.values[field] = value
                                        end
                                    end
                                elseif field == 'behavior' or field == 'initialStateFunc' then
                                    local keyField = field == 'behavior' and 'behaviorKey' or 'initialStateKey'
                                    if type(value) ~= 'string' or value == '' then
                                        result.valid = false
                                        entry.conflicts[keyField] = true
                                        entry.values[keyField] = nil
                                        AddDiagnostic(result.diagnostics, unitIndex, orderId, field,
                                            'behavior override must be a symbolic function key')
                                    elseif behaviorWhitelist[value] ~= true then
                                        entry.conflicts[keyField] = true
                                        entry.values[keyField] = nil
                                        AddDiagnostic(result.diagnostics, unitIndex, orderId, field,
                                            'behavior override is not present in the injected whitelist; no behavior selected')
                                    elseif not entry.conflicts[keyField] then
                                        local prior = entry.values[keyField]
                                        if prior ~= nil and prior ~= value then
                                            entry.values[keyField] = nil
                                            entry.conflicts[keyField] = true
                                            AddDiagnostic(result.diagnostics, unitIndex, orderId, field,
                                                'selected blueprints disagree; catalog behavior key is retained')
                                        else
                                            entry.values[keyField] = value
                                        end
                                    end
                                else
                                    AddDiagnostic(result.diagnostics, unitIndex, orderId, field,
                                        'unsupported override field; it is not applied')
                                end
                            end
                        else
                            result.valid = false
                            AddDiagnostic(result.diagnostics, unitIndex, orderId, nil,
                                'override must be false or a table')
                        end
                    end
                end
            end
        end

        for orderId, entry in pairs(accumulators) do
            if entry.suppressions > 0 and entry.records > 0 then
                AddDiagnostic(result.diagnostics, nil, orderId, nil,
                    'suppression conflicts with a table override; catalog definition is retained')
            elseif entry.suppressions > 0 then
                result.displayOverrides[orderId] = false
            else
                local display, behavior = {}, {}
                for field, value in pairs(entry.values) do
                    if displayFields[field] then display[field] = value
                    elseif field == 'behaviorKey' then behavior.behaviorKey = value
                    elseif field == 'initialStateKey' then behavior.initialStateKey = value end
                end
                if next(display) then result.displayOverrides[orderId] = display end
                if next(behavior) then
                    result.behaviorOverrides[orderId] = behavior
                    AddDiagnostic(result.diagnostics, nil, orderId, nil,
                        'whitelisted behavior key resolved symbolically only; it was not executed')
                end
            end
        end
        if not result.valid then
            result.displayOverrides = {}
            result.behaviorOverrides = {}
        end
        return result
    end

    return resolver
end
