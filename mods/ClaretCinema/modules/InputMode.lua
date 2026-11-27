local function CopyBatch(batch)
    local copy = {}
    for key, value in pairs(batch) do
        if type(value) == 'table' then
            local definition = {}
            for field, item in pairs(value) do definition[field] = item end
            copy[key] = definition
        else
            copy[key] = value
        end
    end
    return copy
end

function Create(native, normalize, candidates, toggle, cinema, keep)
    local mode = {}
    local journal, occupied, toggleKey, preferred
    local retained, installed = {}, {}
    local active = false

    local function ReplayNormal()
        native.Clear()
        for _, entry in ipairs(journal) do entry.apply(entry.batch) end
    end

    local function ApplyCinema()
        local layout = CopyBatch(cinema)
        local passthrough = {}
        for key in pairs(layout) do
            if retained[normalize(key)] then layout[key] = nil end
        end
        for normal, entry in pairs(retained) do
            if normal ~= normalize(toggleKey) then
                layout[entry.key] = entry.definition
                passthrough[normal] = entry
            end
        end
        layout[toggleKey] = toggle
        native.Clear()
        native.Add(layout)
        installed = passthrough
    end

    local function RefreshRetained()
        local remove, add, nextInstalled = {}, {}, {}
        local exitKey = normalize(toggleKey)
        for normal, entry in pairs(retained) do
            if normal ~= exitKey then
                nextInstalled[normal] = entry
                if not installed[normal] or installed[normal].key ~= entry.key then add[entry.key] = entry.definition end
            end
        end
        for normal, entry in pairs(installed) do
            local wanted = nextInstalled[normal]
            if not wanted or wanted.key ~= entry.key then
                remove[entry.key] = true
                if not wanted then
                    for chord, definition in pairs(cinema) do
                        if normalize(chord) == normal then add[chord] = definition end
                    end
                end
            end
        end
        if next(remove) then native.Remove(remove) end
        if next(add) then native.Add(add) end
        installed = nextInstalled
    end

    local function ChooseToggle(layout, requested)
        if requested and not occupied[normalize(requested)] and not layout[requested] then return requested end
        for _, key in ipairs(candidates) do
            if not occupied[normalize(key)] and not layout[key] then return key end
        end
    end

    local function InstallToggle(force, layout, requested)
        local key = ChooseToggle(layout, requested)
        local old = toggleKey
        if key and (force or key ~= old) then native.Add({[key] = toggle}) end
        if old and old ~= key and not occupied[normalize(old)] then native.Remove({[old] = true}) end
        toggleKey = key
    end

    local function Record(batch, apply, adding)
        if not journal then return end
        local copy = CopyBatch(batch)
        table.insert(journal, {batch = copy, apply = apply})
        local changed = false
        for key, definition in pairs(copy) do
            local normal = normalize(key)
            occupied[normal] = adding or nil
            local old = retained[normal]
            local entry = adding and keep and keep(definition) and {key = key, definition = definition} or nil
            retained[normal] = entry
            if old or entry then changed = true end
        end
        return changed
    end

    local function ChangeNormal(batch, apply, adding)
        if active then
            if Record(batch, apply, adding) then return pcall(RefreshRetained) end
            return true
        end
        -- If the native write fails, it may have only partially changed the map.
        -- Do not enter Cinema again before observing a new complete rebuild.
        local ok, message = pcall(apply, batch)
        if not ok then
            journal, occupied, toggleKey = nil, nil, nil
            retained = {}
            error(message)
        end
        Record(batch, apply, adding)
        if journal then
            local installed, installError = pcall(InstallToggle, not adding, cinema, preferred)
            if not installed then return false, installError end
        end
        return true
    end

    function mode.Clear()
        if not active then
            journal, occupied, toggleKey = nil, nil, nil
            native.Clear()
        end
        journal, occupied, retained = {}, {}, {}
        if active and next(installed) then return pcall(RefreshRetained) end
        return true
    end

    function mode.Add(batch)
        return ChangeNormal(batch, native.Add, true)
    end

    function mode.Remove(batch)
        return ChangeNormal(batch, native.Remove, false)
    end

    function mode.IsActive() return active end
    function mode.Key() return toggleKey end
    function mode.NormalHasKey(key) return occupied and occupied[normalize(key)] == true end
    function mode.KeepsKey(key) return retained[normalize(key)] ~= nil end

    function mode.Configure(layout, requested)
        if active then return false end
        if journal then
            local old = toggleKey
            local target = ChooseToggle(layout, requested)
            local ok, message = pcall(InstallToggle, false, layout, requested)
            if not ok then
                local recovered, detail = pcall(function()
                    if target and target ~= old then native.Remove({[target] = true}) end
                    if old then native.Add({[old] = toggle}) end
                end)
                if not recovered then message = tostring(message) .. '; recovery failed: ' .. tostring(detail) end
                return false, message
            end
        end
        cinema = CopyBatch(layout)
        preferred = requested
        return true
    end

    function mode.Enable()
        if active then return true end
        if not journal or not toggleKey then
            return false, 'No complete keyboard map has been captured'
        end
        local ok, message = pcall(ApplyCinema)
        if not ok then
            local restored, recovery = pcall(function()
                ReplayNormal()
                InstallToggle(true, cinema, preferred)
            end)
            if not restored then
                return false, tostring(message) .. '; normal map recovery failed: ' .. tostring(recovery)
            end
            return false, message
        end
        active = true
        return true
    end

    function mode.Disable(closing)
        if not journal then return true end
        if not active and (not closing or not toggleKey) then return true end
        if not active then
            local ok, message = pcall(native.Remove, {[toggleKey] = true})
            if ok then toggleKey = nil end
            return ok, message
        end
        local ok, message = pcall(ReplayNormal)
        if not ok then
            local restored, recovery = pcall(ApplyCinema)
            if not restored then
                return false, tostring(message) .. '; Cinema map recovery failed: ' .. tostring(recovery)
            end
            return false, message
        end
        active = false
        installed = {}
        toggleKey = nil
        if not closing then
            local installed, installError = pcall(InstallToggle, true, cinema, preferred)
            if not installed then return false, installError end
        end
        return true
    end

    return mode
end
