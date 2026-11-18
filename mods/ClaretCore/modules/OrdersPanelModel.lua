-- Presentation-only model for native-shaped FAF order definitions.
-- It never invokes order behaviors, state initializers, engine APIs or hooks.

local function CopyDisplayDefinition(id, definition, override)
    local result = {
        id = id,
        source = definition,
        bitmapId = definition.bitmapId,
        helpText = definition.helpText,
        preferredSlot = definition.preferredSlot,
        disabledByDefinition = definition.disabled == true,
    }
    if override then
        if override.bitmapId ~= nil then result.bitmapId = override.bitmapId end
        if override.helpText ~= nil then result.helpText = override.helpText end
        if override.preferredSlot ~= nil then result.preferredSlot = override.preferredSlot end
        if override.disabled ~= nil then result.disabledByOverride = override.disabled == true end
    end
    return result
end

function Create(options)
    options = options or {}
    local definitions = options.definitions or {}
    local firstAltSlot = options.firstAltSlot or 8
    local totalSlots = options.totalSlots or 14
    local commonOrder = options.commonOrder or options.commonIds
    if type(commonOrder) ~= 'table' then
        error('commonOrder IDs must be supplied to preserve native common-order display behavior')
    end
    local commonIds = {}
    local items, byId, unknown = {}, {}, {}
    local lastSnapshot = nil

    local function AddUnknown(target, id, reason)
        table.insert(target, { id = id, reason = reason })
    end

    local function ValidateDefinitions(candidate)
        if type(candidate) ~= 'table' then return false, 'order definitions must be a table' end
        for id, definition in pairs(candidate) do
            if type(id) ~= 'string' or id == '' or type(definition) ~= 'table' then
                return false, 'each order definition must be a table keyed by a non-empty native ID'
            end
            if definition.preferredSlot ~= nil and (type(definition.preferredSlot) ~= 'number'
                or definition.preferredSlot < 1 or definition.preferredSlot ~= math.floor(definition.preferredSlot)) then
                return false, 'definition preferredSlot must be a positive integer for ' .. id
            end
        end
        return true
    end

    local function RebuildCommonSet(ids)
        local set = {}
        for key, value in pairs(ids) do
            if type(key) == 'number' then
                if type(value) ~= 'string' or value == '' then return nil, 'common order IDs must be strings' end
                set[value] = true
            elseif value == true then
                if type(key) ~= 'string' or key == '' then return nil, 'common order IDs must be strings' end
                set[key] = true
            elseif value ~= false and value ~= nil then
                return nil, 'common order set values must be booleans or an ID list'
            end
        end
        return set
    end

    local function Clear()
        items, byId, unknown = {}, {}, {}
    end

    local function ValidateIdArray(value, field)
        if type(value) ~= 'table' then return false, field .. ' must be an ID array' end
        for index = 1, table.getn(value) do
            if type(value[index]) ~= 'string' or value[index] == '' then
                return false, field .. ' contains an invalid ID at index ' .. index
            end
        end
        for key in pairs(value) do
            if type(key) ~= 'number' or key < 1 or key > table.getn(value) or key ~= math.floor(key) then
                return false, field .. ' must be a dense ID array'
            end
        end
        return true
    end

    local function NormalizeState(value, id)
        if value == nil then return false, false end
        if type(value) == 'boolean' then return value, false end
        if type(value) ~= 'table' then return nil, nil, 'invalid checkbox state for ' .. id end
        for key in pairs(value) do
            if key ~= 'checked' and key ~= 'mixed' then
                return nil, nil, 'unknown checkbox state field for ' .. id
            end
        end
        if value.checked ~= nil and type(value.checked) ~= 'boolean' then
            return nil, nil, 'checkbox checked state must be boolean for ' .. id
        end
        if value.mixed ~= nil and type(value.mixed) ~= 'boolean' then
            return nil, nil, 'checkbox mixed state must be boolean for ' .. id
        end
        return value.checked == true, value.mixed == true
    end

    local function ApplySnapshot(snapshot)
        Clear()
        if type(snapshot) ~= 'table' then return false, 'snapshot must be a table' end
        local valid, reason = ValidateIdArray(snapshot.availableOrders, 'availableOrders')
        if not valid then return false, reason end
        valid, reason = ValidateIdArray(snapshot.availableToggles, 'availableToggles')
        if not valid then return false, reason end
        for _, field in ipairs({ 'replay', 'readOnly' }) do
            if snapshot[field] ~= nil and type(snapshot[field]) ~= 'boolean' then
                return false, field .. ' must be boolean when supplied'
            end
        end
        local overrides = snapshot.blueprintOverrides or snapshot.overrides or {}
        local states = snapshot.checkboxStates or snapshot.states or {}
        if type(overrides) ~= 'table' then return false, 'blueprintOverrides must be a table' end
        if type(states) ~= 'table' then return false, 'checkboxStates must be a table' end

        local orderAvailable, toggleAvailable = {}, {}
        for _, id in ipairs(snapshot.availableOrders) do orderAvailable[id] = true end
        for _, id in ipairs(snapshot.availableToggles) do toggleAvailable[id] = true end
        local overridesById = {}
        for id, override in pairs(overrides) do
            if type(id) ~= 'string' or id == '' or (override ~= false and type(override) ~= 'table') then
                return false, 'blueprint override must be false or a table keyed by native ID'
            end
            if override and override.preferredSlot ~= nil and (type(override.preferredSlot) ~= 'number'
                or override.preferredSlot < 1 or override.preferredSlot ~= math.floor(override.preferredSlot)) then
                return false, 'blueprint override preferredSlot must be a positive integer for ' .. id
            end
            overridesById[id] = override
        end
        for id, state in pairs(states) do
            if type(id) ~= 'string' or id == '' then return false, 'checkbox states must be keyed by native ID' end
            local _, _, stateError = NormalizeState(state, id)
            if stateError then return false, stateError end
        end

        local staged, stagedById, stagedUnknown = {}, {}, {}
        local commonRows = {}
        for id in pairs(commonIds) do
            local base = definitions[id]
            local override = overridesById[id]
            if base and override ~= false then
                local display = CopyDisplayDefinition(id, base, override)
                if not display.preferredSlot then
                    AddUnknown(stagedUnknown, id, 'common order has no preferred slot')
                elseif display.preferredSlot >= firstAltSlot or display.preferredSlot > totalSlots then
                    AddUnknown(stagedUnknown, id, 'common order preferred slot is outside the common-order range')
                else
                    table.insert(commonRows, display)
                end
            elseif not base then
                AddUnknown(stagedUnknown, id, 'common native ID has no injected definition')
            end
        end
        table.sort(commonRows, function(a, b)
            if a.preferredSlot == b.preferredSlot then return a.id < b.id end
            return a.preferredSlot < b.preferredSlot
        end)

        local occupiedSlots = {}
        local readOnly = snapshot.readOnly == true or snapshot.replay == true
        local function AddDisplay(display, slot, isCommon, available)
            if occupiedSlots[slot] then
                AddUnknown(stagedUnknown, display.id, 'display slot collision at ' .. tostring(slot))
                return false
            end
            local checked, mixed, stateError = NormalizeState(states[display.id], display.id)
            if stateError then return false end
            local item = {
                id = display.id,
                bitmapId = display.bitmapId,
                helpText = display.helpText,
                slot = slot,
                preferredSlot = display.preferredSlot,
                common = isCommon,
                available = available,
                disabled = readOnly or display.disabledByDefinition or display.disabledByOverride == true
                    or (isCommon and not available),
                checked = checked,
                mixed = mixed,
                source = display.source,
            }
            occupiedSlots[slot] = item
            stagedById[item.id] = item
            table.insert(staged, item)
            return true
        end

        for _, display in ipairs(commonRows) do
            local id = display.id
            AddDisplay(display, display.preferredSlot, true, orderAvailable[id] == true)
        end

        local candidateIds, seenCandidate = {}, {}
        local function CollectCandidates(ids, availability)
            for _, id in ipairs(ids) do
                local definition = definitions[id]
                local override = overridesById[id]
                if definition and override ~= false and not commonIds[id] and not seenCandidate[id] then
                    seenCandidate[id] = true
                    table.insert(candidateIds, id)
                elseif not definition then
                    AddUnknown(stagedUnknown, id, 'available native ID has no injected definition')
                end
            end
        end
        CollectCandidates(snapshot.availableOrders, orderAvailable)
        CollectCandidates(snapshot.availableToggles, toggleAvailable)

        local desiredSlots = {}
        for _, id in ipairs(candidateIds) do
            local display = CopyDisplayDefinition(id, definitions[id], overridesById[id])
            local preferred = display.preferredSlot
            if type(preferred) ~= 'number' or preferred < firstAltSlot or preferred > totalSlots then
                AddUnknown(stagedUnknown, id, 'preferred slot is outside the configured alternate-order range')
            else
                desiredSlots[preferred] = desiredSlots[preferred] or {}
                table.insert(desiredSlots[preferred], display)
            end
        end

        local orderInSlot = {}
        for slot = firstAltSlot, totalSlots do
            if desiredSlots[slot] then orderInSlot[slot] = desiredSlots[slot][1] end
        end
        for slot = firstAltSlot, totalSlots do
            local list = desiredSlots[slot]
            if list and table.getn(list) > 1 then
                for index = 2, table.getn(list) do
                    local freeSlot = false
                    for candidateSlot = firstAltSlot, totalSlots do
                        if not orderInSlot[candidateSlot] then
                            orderInSlot[candidateSlot] = list[index]
                            freeSlot = true
                            break
                        end
                    end
                    if not freeSlot then AddUnknown(stagedUnknown, list[index].id, 'no free alternate order slot') end
                end
            end
        end

        for slot = firstAltSlot, totalSlots do
            local display = orderInSlot[slot]
            if display then
                local id = display.id
                local available = orderAvailable[id] == true or toggleAvailable[id] == true
                AddDisplay(display, slot, false, available)
            end
        end
        table.sort(staged, function(a, b) return a.slot < b.slot end)
        items, byId, unknown = staged, stagedById, stagedUnknown
        return true
    end

    local valid, reason = ValidateDefinitions(definitions)
    if not valid then error(reason) end
    local commonSet, commonError = RebuildCommonSet(commonOrder)
    if not commonSet then error(commonError) end
    commonIds = commonSet
    if type(firstAltSlot) ~= 'number' or type(totalSlots) ~= 'number'
        or firstAltSlot < 1 or totalSlots < firstAltSlot or firstAltSlot ~= math.floor(firstAltSlot)
        or totalSlots ~= math.floor(totalSlots) then
        error('order slot range must be valid positive integers')
    end

    local model = {}
    function model:SetSnapshot(snapshot)
        local ok, failure = ApplySnapshot(snapshot)
        if ok then lastSnapshot = snapshot else lastSnapshot = nil end
        return ok, failure
    end
    function model:SetDefinitions(nextDefinitions)
        local ok, failure = ValidateDefinitions(nextDefinitions)
        if not ok then Clear(); lastSnapshot = nil; return false, failure end
        definitions = nextDefinitions
        if lastSnapshot then return ApplySnapshot(lastSnapshot) end
        Clear()
        return true
    end
    function model:GetItems() return items end
    function model:GetById(id) return byId[id] end
    function model:GetUnknown() return unknown end
    function model:Reset()
        Clear()
        lastSnapshot = nil
    end
    return model
end
