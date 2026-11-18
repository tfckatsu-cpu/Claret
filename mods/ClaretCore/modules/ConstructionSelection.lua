-- Selected-unit summary presentation for a future HUD. No selection changes or commands.
-- Callbacks provide engine unit identity, categories, fuel and idle state.

local SummaryCategories = { 'ALLUNITS', 'LAND', 'AIR', 'NAVAL', 'STRUCTURE', 'SORTCONSTRUCTION' }
local TechCategories = { 'TECH1', 'TECH2', 'TECH3', 'EXPERIMENTAL' }

function Create(ops)
    ops = ops or {}

    local function Build(units, options)
        options = options or {}
        local entries, errors = {}, {}
        local function AddError(index, unit, reason)
            table.insert(errors, { sourceIndex = index, unit = unit, reason = reason })
        end
        if type(units) ~= 'table' then
            return { entries = entries, errors = { { reason = 'selected units must be a table' } } }
        end
        if type(ops.getBlueprintId) ~= 'function' or type(ops.hasCategory) ~= 'function' then
            return { entries = entries, errors = { { reason = 'unit identity and category operations are required' } } }
        end

        local sectionGroups = {}
        local seenUnits, seenIds = {}, {}
        for index = 1, table.getn(SummaryCategories) do
            sectionGroups[index] = {}
            seenIds[sectionGroups[index]] = {}
        end
        local lowFuelGroups, idleGroups = {}, {}
        seenIds[lowFuelGroups], seenIds[idleGroups] = {}, {}
        local function GroupById(groups, id, unit, sourceIndex, techMatches)
            local group = seenIds[groups][id]
            if not group then
                group = { id = id, units = {}, sourceIndices = {}, techMatches = techMatches }
                seenIds[groups][id] = group
                table.insert(groups, group)
            end
            table.insert(group.units, unit)
            table.insert(group.sourceIndices, sourceIndex)
        end

        for sourceIndex, unit in ipairs(units) do
            local unitType = type(unit)
            if unit == nil or (unitType ~= 'table' and unitType ~= 'userdata') then
                AddError(sourceIndex, unit, 'unit reference is invalid')
            elseif seenUnits[unit] then
                AddError(sourceIndex, unit, 'duplicate unit reference')
            else
                seenUnits[unit] = true
                local okId, id = pcall(ops.getBlueprintId, unit)
                if not okId or type(id) ~= 'string' or id == '' then
                    AddError(sourceIndex, unit, 'blueprint ID is unavailable')
                else
                    local isAir = false
                    local matchedCategory = 0
                    local categoryFailed = false
                    for categoryIndex, category in ipairs(SummaryCategories) do
                        local ok, matches = pcall(ops.hasCategory, unit, category)
                        if not ok or type(matches) ~= 'boolean' then
                            AddError(sourceIndex, unit, 'category lookup failed for ' .. category)
                            categoryFailed = true
                            break
                        end
                        if matches then matchedCategory = categoryIndex end
                        if category == 'AIR' and matches then isAir = true end
                    end

                    local techMatches = {}
                    if not categoryFailed then
                        for _, tech in ipairs(TechCategories) do
                            local ok, matches = pcall(ops.hasCategory, unit, tech)
                            if not ok or type(matches) ~= 'boolean' then
                                AddError(sourceIndex, unit, 'tech category lookup failed for ' .. tech)
                                categoryFailed = true
                                break
                            end
                            techMatches[tech] = matches
                        end
                    end

                    if not categoryFailed then
                        local routed = false
                        if isAir then
                            local okFuel, ratio = pcall(ops.getFuelRatio, unit)
                            if not okFuel or type(ratio) ~= 'number' or ratio ~= ratio
                                or ratio == math.huge or ratio == -math.huge then
                                AddError(sourceIndex, unit, 'fuel ratio is invalid')
                                routed = true
                            elseif ratio < 0.2 and ratio > -1 then
                                GroupById(lowFuelGroups, id, unit, sourceIndex, techMatches)
                                routed = true
                            end
                        end

                        if not routed and options.separateIdleBuilders == true then
                            local okConstruction, construction = pcall(ops.hasCategory, unit, 'CONSTRUCTION')
                            if not okConstruction or type(construction) ~= 'boolean' then
                                AddError(sourceIndex, unit, 'category lookup failed for CONSTRUCTION')
                                routed = true
                            elseif construction then
                                local okIdle, idle = pcall(ops.isIdle, unit)
                                if not okIdle or type(idle) ~= 'boolean' then
                                    AddError(sourceIndex, unit, 'idle state is invalid')
                                    routed = true
                                elseif idle then
                                    GroupById(idleGroups, id, unit, sourceIndex, techMatches)
                                    routed = true
                                end
                            end
                        end

                        if not routed then
                            if matchedCategory == 0 then
                                AddError(sourceIndex, unit, 'unit did not match ALLUNITS summary category')
                            else
                                GroupById(sectionGroups[matchedCategory], id, unit, sourceIndex, techMatches)
                            end
                        end
                    end
                end
            end
        end

        local function InsertSection(groups, lowFuel, idleCon)
            local insertedTech = false
            local used = {}
            for _, tech in ipairs(TechCategories) do
                for _, group in ipairs(groups) do
                    local representative = group.units[1]
                    if representative and not used[group] and group.techMatches[tech] then
                        table.insert(entries, {
                            type = 'unitstack', id = group.id, units = group.units,
                            count = table.getn(group.units), sourceIndices = group.sourceIndices,
                            lowFuel = lowFuel, idleCon = idleCon,
                        })
                        used[group] = true
                        insertedTech = true
                    end
                end
            end
            for _, group in ipairs(groups) do
                if not used[group] then
                    table.insert(entries, {
                        type = 'unitstack', id = group.id, units = group.units,
                        count = table.getn(group.units), sourceIndices = group.sourceIndices,
                        lowFuel = lowFuel, idleCon = idleCon,
                    })
                end
            end
            return insertedTech
        end

        local previousDidInsertTech = false
        local function AddSectionSpacer()
            if previousDidInsertTech then
                table.insert(entries, { type = 'spacer' })
                previousDidInsertTech = false
            end
        end

        for _, groups in ipairs(sectionGroups) do
            AddSectionSpacer()
            previousDidInsertTech = InsertSection(groups, false, false)
        end
        AddSectionSpacer()
        previousDidInsertTech = InsertSection(lowFuelGroups, true, false)
        AddSectionSpacer()
        InsertSection(idleGroups, false, true)

        if table.getn(entries) > 0 and entries[table.getn(entries)].type == 'spacer' then
            table.remove(entries, table.getn(entries))
        end
        return { entries = entries, errors = errors }
    end

    return { Build = Build }
end

