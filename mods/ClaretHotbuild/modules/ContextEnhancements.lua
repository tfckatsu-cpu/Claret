-- Safe single-unit enhancement actions for context bindings.
-- Script commands are queued through FAF's commandmode callback, which also
-- synchronizes the UI enhancement queue. We always append (clear=false).
local EnhancementCommon = import('/lua/enhancementcommon.lua')
local EnhancementQueue = import('/lua/ui/notify/enhancementqueue.lua')

local acuGun = {
    url0001='CoolingUpgrade', uel0001='HeavyAntiMatterCannon',
    xsl0001='RateOfFire', ual0001='HeatSink',
}
local acuSpecial = {
    url0001='MicrowaveLaserGenerator', uel0001='TacticalNukeMissile',
    xsl0001='BlastAttack', ual0001='ChronoDampener',
}
local acuNano1 = {
    url0001='StealthGenerator', uel0001='Shield',
    xsl0001='DamageStabilization', ual0001='Shield',
}
local acuNano2 = {
    url0001='CloakingGenerator', uel0001='ShieldGeneratorField',
    xsl0001='DamageStabilizationAdvanced', ual0001='ShieldHeavy',
}
local sacuEngineering = {
    url0301='Switchback', uel0301='Pod',
    xsl0301='EngineeringThroughput', ual0301='EngineeringFocusingModule',
}

local acuActions = {
    acu_tech=true, acu_ras=true, acu_tele=true, acu_gun=true,
    acu_nano=true, acu_special=true,
}

local function EnhancementTable(unit)
    local blueprint = unit:GetBlueprint()
    if type(blueprint) ~= 'table' or type(blueprint.Enhancements) ~= 'table' then return nil end
    return blueprint, blueprint.Enhancements
end

local function BlueprintId(blueprint)
    return string.lower(blueprint.BlueprintId or '')
end

local function Contains(list, value)
    for _, item in ipairs(list) do if item == value then return true end end
    return false
end

local function EnhancementId(entry)
    return type(entry) == 'table' and entry.ID or nil
end

local function BuildChain(enhancements, target)
    if not enhancements[target] then return nil end
    local reverse, seen, id = {}, {}, target
    while id do
        if seen[id] or not enhancements[id] then return nil end
        seen[id] = true
        table.insert(reverse, id)
        id = enhancements[id].Prerequisite
    end
    local chain = {}
    for index = table.getn(reverse), 1, -1 do
        local name = reverse[index]
        if enhancements[name].Slot ~= enhancements[target].Slot then return nil end
        table.insert(chain, name)
    end
    return chain
end

local function ResolveTarget(action, unit, blueprint, enhancements)
    local bpId = BlueprintId(blueprint)
    if action == 'acu_tech' then
        local installed = EnhancementCommon.GetEnhancements(unit:GetEntityId()) or {}
        local queue = EnhancementQueue.getEnhancementQueue()[unit:GetEntityId()] or {}
        local hasAdvanced, hasT3 = false, false
        for _, entry in ipairs(queue) do
            local id = EnhancementId(entry)
            if id == 'AdvancedEngineering' then hasAdvanced = true end
            if id == 'T3Engineering' then hasT3 = true end
        end
        for _, id in pairs(installed) do
            if id == 'AdvancedEngineering' then hasAdvanced = true end
            if id == 'T3Engineering' then hasT3 = true end
        end
        if hasT3 then return nil end
        return hasAdvanced and 'T3Engineering' or 'AdvancedEngineering'
    elseif action == 'acu_ras' then
        local installed = EnhancementCommon.GetEnhancements(unit:GetEntityId()) or {}
        local queue = EnhancementQueue.getEnhancementQueue()[unit:GetEntityId()] or {}
        local hasBase, hasAdvanced = false, false
        for _, id in pairs(installed) do
            if id == 'ResourceAllocation' then hasBase = true end
            if id == 'ResourceAllocationAdvanced' then hasAdvanced = true end
        end
        for _, entry in ipairs(queue) do
            local id = EnhancementId(entry)
            if id == 'ResourceAllocation' then hasBase = true end
            if id == 'ResourceAllocationAdvanced' then hasAdvanced = true end
        end
        if hasAdvanced then return nil end
        return hasBase and 'ResourceAllocationAdvanced' or 'ResourceAllocation'
    elseif action == 'acu_tele' then
        return 'Teleporter'
    elseif action == 'acu_gun' then
        return acuGun[bpId]
    elseif action == 'acu_special' then
        return acuSpecial[bpId]
    elseif action == 'acu_nano' then
        local first = acuNano1[bpId]
        local second = acuNano2[bpId]
        if not first then return nil end
        local installed = EnhancementCommon.GetEnhancements(unit:GetEntityId()) or {}
        local existing = installed[enhancements[first] and enhancements[first].Slot]
        local queue = EnhancementQueue.getEnhancementQueue()[unit:GetEntityId()] or {}
        local firstQueued = false
        for _, entry in ipairs(queue) do if EnhancementId(entry) == first then firstQueued = true end end
        if existing == first or firstQueued then return second end
        return first
    elseif action == 'sacu_tech' then
        return sacuEngineering[bpId]
    end
end

local function Plan(action, context)
    if type(action) ~= 'string' or (not acuActions[action] and action ~= 'sacu_tech') then return nil end
    if type(context) ~= 'table' or context.isReplay or type(context.focusArmy) ~= 'number' or context.focusArmy < 1 then return nil end
    if type(context.selection) ~= 'table' or table.getn(context.selection) ~= 1 then return nil end
    local unit = context.selection[1]
    if not unit or unit:IsDead() then return nil end
    local isACU = unit:IsInCategory('COMMAND')
    local isSACU = unit:IsInCategory('SUBCOMMANDER')
    if (acuActions[action] and not isACU) or (action == 'sacu_tech' and not isSACU) then return nil end

    -- Key dispatch may race selection changes; never issue to a different unit.
    local current = GetSelectedUnits() or {}
    if table.getn(current) ~= 1 or current[1] ~= unit then return nil end

    local blueprint, enhancements = EnhancementTable(unit)
    if not blueprint then return nil end
    local target = ResolveTarget(action, unit, blueprint, enhancements)
    if not target or not enhancements[target] then return nil end

    local chain = BuildChain(enhancements, target)
    if not chain then return nil end
    local slot = enhancements[target].Slot
    if not slot then return nil end
    local installed = EnhancementCommon.GetEnhancements(unit:GetEntityId()) or {}
    local existing = installed[slot]
    local installedIndex = 0
    if existing then
        for index, name in ipairs(chain) do if name == existing then installedIndex = index end end
        if installedIndex == 0 then return nil end
    end

    local restricted = EnhancementCommon.GetRestricted() or {}
    local queued = EnhancementQueue.getEnhancementQueue()[unit:GetEntityId()] or {}
    local queuedIndex, lastQueueIndex = 0, 0
    for _, entry in ipairs(queued) do
        if entry.Slot == slot then
            local entryId = EnhancementId(entry)
            local found
            for index, name in ipairs(chain) do if name == entryId then found = index; break end end
            if not found or found <= lastQueueIndex or entryId:find('Remove', 1, true) then return nil end
            lastQueueIndex = found
            queuedIndex = found
        end
    end
    for index = installedIndex + 1, table.getn(chain) do
        if restricted[chain[index]] then return nil end
    end
    local startIndex = math.max(installedIndex, queuedIndex)
    if startIndex >= table.getn(chain) then return nil end

    local orders = {}
    for index = startIndex + 1, table.getn(chain) do
        local name = chain[index]
        table.insert(orders, name)
    end
    if table.getn(orders) == 0 then return nil end
    return {unit=unit, blueprint=blueprint, enhancements=enhancements, orders=orders}
end

function Available(id, context)
    return Plan(id, context) ~= nil
end

function Execute(id, context)
    local plan = Plan(id, context)
    if not plan then return false end
    local blueprintId = plan.blueprint.BlueprintId
    for _, name in ipairs(plan.orders) do
        -- The stock UI adds these queue metadata fields before issuing orders.
        -- The script-issued callback stores the same blueprint record in its queue.
        local enhancement = plan.enhancements[name]
        enhancement.ID = name
        enhancement.UnitID = blueprintId
        IssueCommand('UNITCOMMAND_Script', {TaskName='EnhanceTask', Enhancement=name}, false)
    end
    return true
end
