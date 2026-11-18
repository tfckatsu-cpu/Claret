-- Standalone selection state for a future cargo HUD. Engine operations are injected.
-- Only units added by this instance are ever removed from the shared selection list.

local function CopyArray(source)
    local result = {}
    if type(source) == 'table' then
        for index, value in ipairs(source) do result[index] = value end
    end
    return result
end

function Create(options)
    options = options or {}
    local add = options.add or function() end
    local remove = options.remove or function() end
    local isQueued = options.isQueued or function() return false end
    local refresh = options.refresh or function() end
    local state = { cargo = {}, owned = {}, queued = {}, anchor = nil, nextIndex = 1, destroyed = false, busy = false }

    local function SetOwned(unit, enabled)
        if enabled then
            if state.owned[unit] or isQueued(unit) then return false end
            state.busy = true
            local ok, result = pcall(add, unit)
            state.busy = false
            if not ok or result == false then return false end
            state.owned[unit] = true
            return true
        end
        if not state.owned[unit] then return false end
        state.busy = true
        local ok, result = pcall(remove, unit)
        state.busy = false
        if not ok or result == false then return false end
        state.owned[unit] = nil
        return true
    end

    local function Notify(changed)
        if changed then pcall(refresh, CopyArray(state.cargo)) end
        return changed
    end

    function state:SetCargo(cargo)
        if self.destroyed or self.busy then return false end
        local nextCargo, present = {}, {}
        local nextQueued = {}
        if type(cargo) == 'table' then
            for _, unit in ipairs(cargo) do
                if unit ~= nil and not present[unit] then
                    present[unit] = true
                    table.insert(nextCargo, unit)
                    nextQueued[unit] = isQueued(unit) == true
                end
            end
        end
        local changed = false
        for unit in pairs(self.owned) do
            if not present[unit] then
                if SetOwned(unit, false) then changed = true end
            end
        end
        if table.getn(self.cargo) ~= table.getn(nextCargo) then changed = true end
        if not changed then
            for index, unit in ipairs(nextCargo) do
                if self.cargo[index] ~= unit then changed = true; break end
            end
        end
        if not changed then
            for _, unit in ipairs(nextCargo) do
                if self.queued[unit] ~= nextQueued[unit] then changed = true; break end
            end
        end
        self.cargo = nextCargo
        self.queued = nextQueued
        if self.anchor and not present[self.anchor] then self.anchor = nil end
        self.nextIndex = 1
        local cleanupComplete = true
        for unit in pairs(self.owned) do
            if not present[unit] then cleanupComplete = false; break end
        end
        return Notify(changed), cleanupComplete
    end

    function state:IsSelected(index)
        local unit = self.cargo[index]
        return unit ~= nil and (self.owned[unit] == true or isQueued(unit) == true) or false
    end

    function state:GetSelection()
        local result = {}
        for _, unit in ipairs(self.cargo) do
            if self.owned[unit] then table.insert(result, unit) end
        end
        return result
    end

    function state:Toggle(index)
        if self.destroyed or self.busy then return false end
        local unit = self.cargo[index]
        if not unit or isQueued(unit) then return false end
        local changed
        if self.owned[unit] then
            changed = SetOwned(unit, false)
            if changed and self.anchor == unit then self.anchor = nil end
        else
            changed = SetOwned(unit, true)
            if changed then self.anchor = unit end
        end
        return Notify(changed)
    end

    function state:AddRange(index)
        if self.destroyed or self.busy or not self.cargo[index] then return false end
        local anchorIndex
        if self.anchor then
            for cursor, unit in ipairs(self.cargo) do
                if unit == self.anchor then anchorIndex = cursor; break end
            end
        end
        if not anchorIndex then
            local changed = SetOwned(self.cargo[index], true)
            if changed then self.anchor = self.cargo[index] end
            return Notify(changed)
        end
        local first, last = math.min(index, anchorIndex), math.max(index, anchorIndex)
        local changed = false
        for cursor = first, last do
            if SetOwned(self.cargo[cursor], true) then changed = true end
        end
        self.anchor = nil
        return Notify(changed)
    end

    function state:AppendNext()
        if self.destroyed or self.busy then return false end
        while self.nextIndex <= table.getn(self.cargo) do
            local index = self.nextIndex
            local unit = self.cargo[index]
            if not isQueued(unit) and not self.owned[unit] then
                local changed = SetOwned(unit, true)
                if changed then self.nextIndex = index + 1 end
                return Notify(changed), unit, index
            end
            self.nextIndex = index + 1
        end
        return false
    end

    function state:Reset()
        if self.destroyed or self.busy then return false end
        local changed = false
        for unit in pairs(self.owned) do
            if SetOwned(unit, false) then changed = true end
        end
        self.anchor, self.nextIndex = nil, 1
        return Notify(changed), next(self.owned) == nil
    end

    function state:Destroy()
        if self.destroyed or self.busy then return false end
        self:Reset()
        if next(self.owned) then return false end
        self.cargo = {}
        self.queued = {}
        self.destroyed = true
    end

    return state
end
