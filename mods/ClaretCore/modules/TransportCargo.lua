-- Stages attached mobile cargo in the session's extra-select list.
-- This module never clears that shared list and never issues an unload command.

local function IsLive(unit)
    if unit == nil then return false end
    local ok, dead = pcall(function() return unit:IsDead() end)
    return ok and not dead
end

local function UniqueUnits(units)
    if type(units) ~= 'table' then return nil end
    local result, seen = {}, {}
    for _, unit in ipairs(units) do
        if unit == nil or seen[unit] then return nil end
        seen[unit] = true
        table.insert(result, unit)
    end
    return result
end

local function SameMembers(first, second)
    if not first or not second or table.getn(first) ~= table.getn(second) then return false end
    local members = {}
    for _, unit in ipairs(first) do members[unit] = true end
    for _, unit in ipairs(second) do
        if not members[unit] then return false end
        members[unit] = nil
    end
    return true
end

local function HasUnloadQueued(unit)
    local ok, queued = pcall(function()
        if type(unit.HasUnloadCommandQueuedUp) ~= 'function' then return nil end
        return unit:HasUnloadCommandQueuedUp()
    end)
    return ok and queued == true
end

local function FirstUnqueued(cargo)
    for index, unit in ipairs(cargo) do
        if not HasUnloadQueued(unit) then return index end
    end
end

local function PlayFeedback(success)
    pcall(function()
        PlaySound(Sound({Cue=success and 'UI_MFD_Click' or 'UI_Menu_Error_01', Bank='Interface'}))
    end)
end

function Create(isReplay)
    local service = { isReplay = isReplay, destroyed = false }
    local transports, cargo, nextIndex

    function service:Reset()
        transports, cargo, nextIndex = nil, nil, nil
    end

    function service:Append(selection)
        if self.destroyed or self.isReplay then return false end
        local requested = UniqueUnits(selection)
        local current = UniqueUnits(GetSelectedUnits() or {})
        if not requested or table.getn(requested) == 0 or not SameMembers(requested, current) then
            self:Reset()
            return false
        end
        for _, unit in ipairs(requested) do
            if not IsLive(unit) then self:Reset(); return false end
        end

        local selectedTransports = EntityCategoryFilterDown(categories.TRANSPORTATION, requested) or {}
        if not SameMembers(requested, UniqueUnits(selectedTransports)) then
            self:Reset()
            return false
        end

        local attached = GetAttachedUnitsList(requested)
        if type(attached) ~= 'table' or table.getn(attached) == 0 then
            self:Reset()
            return false
        end
        local mobileCargo = EntityCategoryFilterDown(categories.MOBILE, attached) or {}
        local liveCargo = {}
        local seenCargo = {}
        for _, unit in ipairs(mobileCargo) do
            if IsLive(unit) and not seenCargo[unit] then
                seenCargo[unit] = true
                table.insert(liveCargo, unit)
            end
        end
        if table.getn(liveCargo) == 0 then
            self:Reset()
            return false
        end

        if not SameMembers(transports, requested) or not SameMembers(cargo, liveCargo) then
            transports = requested
            cargo = liveCargo
            nextIndex = FirstUnqueued(cargo)
        end
        if not nextIndex then nextIndex = FirstUnqueued(cargo) end
        if not nextIndex then PlayFeedback(false); return false end

        while nextIndex <= table.getn(cargo) do
            local unit = cargo[nextIndex]
            local index = nextIndex
            nextIndex = nextIndex + 1
            if not HasUnloadQueued(unit) then
                local ok = pcall(AddToSessionExtraSelectList, unit)
                if ok then PlayFeedback(true); return true, unit, index, cargo end
                nextIndex = index
                return false
            end
        end
        PlayFeedback(false)
        return false
    end

    function service:Destroy()
        if self.destroyed then return end
        self:Reset()
        self.destroyed = true
    end

    return service
end
