-- Ordered build-choice classification for a future construction HUD.
-- The caller supplies engine category and restriction operations; no FAF globals are read here.

local function CopyArray(values)
    local result = {}
    if type(values) == 'table' then
        for index, value in ipairs(values) do result[index] = value end
    end
    return result
end

function Create(ops)
    ops = ops or {}
    local hasCategory = ops.hasCategory or function() return false end
    local isAllowed = ops.isAllowed
    local upgradeNext = ops.upgradeNext or function() return nil end

    local function Has(unit, category)
        return hasCategory(unit, category) == true
    end

    local function UniqueAllowed(units)
        local result, seen = {}, {}
        if type(units) ~= 'table' then return result end
        for _, unit in ipairs(units) do
            if unit ~= nil and not seen[unit] then
                local allowed = isAllowed and isAllowed(unit) == true
                    or (not isAllowed and ops.buildablesArePrefiltered == true)
                if allowed then
                    seen[unit] = true
                    table.insert(result, unit)
                end
            end
        end
        return result
    end

    local function FilterTech(units, category)
        local result = {}
        for _, unit in ipairs(units) do
            if Has(unit, category) then table.insert(result, unit) end
        end
        return result
    end

    local function Build(buildables, selection, queuedIds)
        local selected = CopyArray(selection)
        local units = table.getn(selected) > 0 and UniqueAllowed(buildables) or {}
        local prefiltered = {}
        for _, unit in ipairs(units) do prefiltered[unit] = true end
        local queued = {}
        if type(queuedIds) == 'table' then
            for _, id in ipairs(queuedIds) do queued[id] = true end
        end

        -- FAF adds the upgrade chain of the first selected non-factory unit.
        if selected[1] ~= nil and not Has(selected[1], 'FACTORY') then
            local id = selected[1]
            local seen = {}
            while id ~= nil and id ~= '' and not seen[id] do
                seen[id] = true
                local nextId = upgradeNext(id)
                if nextId == nil or nextId == '' then break end
                local allowed = isAllowed and isAllowed(nextId) == true
                    or (not isAllowed and ops.buildablesArePrefiltered == true and prefiltered[nextId] == true)
                if not seen[nextId] and not queued[nextId] and allowed then
                    table.insert(units, nextId)
                end
                id = nextId
            end
        end

        -- Keep original order while removing duplicates introduced by upgrade traversal.
        local unique, seen = {}, {}
        for _, unit in ipairs(units) do
            if not seen[unit] then seen[unit] = true; table.insert(unique, unit) end
        end
        units = unique

        local allFactories = table.getn(selected) > 0
        for _, unit in ipairs(selected) do
            if not (Has(unit, 'FACTORY') or Has(unit, 'EXTERNALFACTORY')) then
                allFactories = false
                break
            end
        end

        local tabs = { t1 = {}, t2 = {}, t3 = {}, t4 = {} }
        local splitByTech = allFactories
        if not splitByTech and selected[1] ~= nil then
            splitByTech = Has(selected[1], 'ENGINEER') or Has(selected[1], 'FACTORY')
                or Has(selected[1], 'EXTERNALFACTORY')
        end

        if not splitByTech then
            tabs.t1 = CopyArray(units)
        elseif not allFactories then
            tabs.t1 = FilterTech(units, 'TECH1')
            tabs.t2 = FilterTech(units, 'TECH2')
            tabs.t3 = FilterTech(units, 'TECH3')
            tabs.t4 = FilterTech(units, 'EXPERIMENTAL')
        else
            local sortDown = {}
            for _, unit in ipairs(units) do
                if Has(unit, 'CONSTRUCTIONSORTDOWN') then
                    table.insert(sortDown, unit)
                else
                    if Has(unit, 'TECH1') then table.insert(tabs.t1, unit) end
                    if Has(unit, 'TECH2') then table.insert(tabs.t2, unit) end
                    if Has(unit, 'TECH3') then table.insert(tabs.t3, unit) end
                    if Has(unit, 'EXPERIMENTAL') then table.insert(tabs.t4, unit) end
                end
            end
            for _, unit in ipairs(sortDown) do
                if Has(unit, 'EXPERIMENTAL') then
                    table.insert(tabs.t3, unit)
                elseif Has(unit, 'TECH3') then
                    table.insert(tabs.t2, unit)
                elseif Has(unit, 'TECH2') then
                    table.insert(tabs.t1, unit)
                end
            end
        end

        return {
            units = units,
            tabs = tabs,
            constructionEnabled = table.getn(units) > 0,
            allFactorySelection = allFactories,
            splitByTech = splitByTech,
            restrictionSource = ops.isAllowed and 'injected'
                or (ops.buildablesArePrefiltered == true and 'pre-filtered-input' or 'unavailable'),
        }
    end

    return { Build = Build }
end
