-- Original Claret binding model. No UI objects, game commands or executable prefs.

local MAX_BINDINGS = 64
local MAX_ENTRIES = 64

local function Trim(value)
    return (string.gsub(string.gsub(value, '^%s+', ''), '%s+$', ''))
end

local function Identifier(value)
    return type(value) == 'string' and string.len(value) > 0
        and string.len(value) <= 96 and string.find(value, '^[%w_][%w_.%-]*$') ~= nil
end

-- Reject holes/dictionary fields instead of silently truncating malformed prefs.
local function IsList(value)
    if type(value) ~= 'table' then return false end
    local count = 0
    local largest = 0
    for key, item in pairs(value) do
        if type(key) ~= 'number' or key < 1 or key ~= math.floor(key) then return false end
        count = count + 1
        if key > largest then largest = key end
    end
    return count == largest
end

---@param value string
---@return string?, string?
function NormalizeKey(value)
    if type(value) ~= 'string' then return nil, 'Key must be text' end
    value = string.upper((string.gsub(value, '%s+', '')))
    if value == '' then return '' end
    if string.len(value) > 48 or string.find(value, '^%-') or string.find(value, '%-$')
        or string.find(value, '%-%-') then return nil, 'Invalid key combination' end
    local parts = {}
    string.gsub(value, '[^%-]+', function(part) table.insert(parts, part) end)
    local count = table.getn(parts)
    local key = parts[count]
    local single = string.find(key, '^[A-Z0-9]$') ~= nil
    local _, _, number = string.find(key, '^F(%d+)$')
    local functionKey = number and tonumber(number) >= 1 and tonumber(number) <= 12
        and key == 'F' .. tostring(tonumber(number))
    if not single and not functionKey then
        return nil, 'Use A-Z, 0-9 or F1-F12 with Ctrl, Alt or Shift'
    end
    local modifiers = {}
    for i = 1, count - 1 do
        local part = parts[i]
        if part ~= 'CTRL' and part ~= 'ALT' and part ~= 'SHIFT' then
            return nil, 'Unknown key modifier: ' .. part
        end
        if modifiers[part] then return nil, 'Repeated key modifier: ' .. part end
        modifiers[part] = true
    end
    local result = ''
    if modifiers.CTRL then result = result .. 'Ctrl-' end
    if modifiers.ALT then result = result .. 'Alt-' end
    if modifiers.SHIFT then result = result .. 'Shift-' end
    return result .. key
end

local factionNames = {'UEF', 'AEON', 'CYBRAN', 'SERAPHIM'}
local domains = {'LAND', 'AIR', 'NAVAL', 'GATE'}

-- Flat legacy unit cells and tiered unit slots remain readable in profile copies.
local function CopyGrid(grid, allowed)
    if type(grid) ~= 'table' or not IsList(grid.buildings) or type(grid.units) ~= 'table' then
        return nil, 'Invalid binding grid'
    end
    if table.getn(grid.buildings) > MAX_ENTRIES then return nil, 'Too many building rows' end
    local output = {buildings = {}, units = {}}
    if grid.context ~= nil then
        if not Identifier(grid.context) then return nil, 'Invalid context binding reference' end
        output.context = grid.context
    end
    local seen = {}
    local unitTiers = {T1=true,T2=true,T3=true,T4=true,LEGACY=true}
    local function CopyId(id)
        if not Identifier(id) then return nil, 'Invalid grid cell' end
        id = string.lower(id)
        if seen[id] or not allowed[id] then return nil, 'Grid cell is missing or duplicated in binding entries' end
        seen[id] = true
        return id
    end
    local function CopyRow(row, allowTechSlots)
        if type(row) ~= 'table' then return nil, 'Invalid grid row' end
        local copy = {}
        for key, value in pairs(row) do
            local known = false
            for _, faction in ipairs(factionNames) do if key == faction then known = true end end
            if not known then return nil, 'Invalid grid cell' end
            if allowTechSlots and type(value) == 'table' then
                local slots = {}
                for tier, id in pairs(value) do
                    if not unitTiers[tier] then return nil, 'Invalid unit tech slot' end
                    local copied, err = CopyId(id)
                    if not copied then return nil, err end
                    slots[tier] = copied
                end
                copy[key] = slots
            else
                local copied, err = CopyId(value)
                if not copied then return nil, err end
                copy[key] = copied
            end
        end
        return copy
    end
    for _, row in ipairs(grid.buildings) do
        local copy, err = CopyRow(row)
        if not copy then return nil, err end
        table.insert(output.buildings, copy)
    end
    for key in pairs(grid.units) do
        if key ~= 'LAND' and key ~= 'AIR' and key ~= 'NAVAL' and key ~= 'GATE' then return nil, 'Invalid unit domain' end
    end
    for _, domain in ipairs(domains) do
        if grid.units[domain] then
            local copy, err = CopyRow(grid.units[domain], true)
            if not copy then return nil, err end
            output.units[domain] = copy
        end
    end
    return output
end

local function CopyBinding(binding)
    local result = { id = binding.id, name = binding.name, key = binding.key, entries = {} }
    for _, entry in ipairs(binding.entries) do
        table.insert(result.entries, { kind = entry.kind, id = entry.id })
    end
    if binding.grid then
        local allowed = {}
        for _, entry in ipairs(binding.entries) do if entry.kind == 'blueprint' then allowed[entry.id] = true end end
        result.grid = CopyGrid(binding.grid, allowed)
    end
    return result
end

local function Validate(binding)
    if type(binding) ~= 'table' or not Identifier(binding.id) then
        return nil, 'Binding ID is invalid'
    end
    if type(binding.name) ~= 'string' then return nil, 'Binding name is required' end
    local name = Trim(binding.name)
    if name == '' or string.len(name) > 128 then return nil, 'Binding name must contain 1-128 bytes' end
    local key, err = NormalizeKey(binding.key)
    if not key then return nil, err end
    if not IsList(binding.entries) then return nil, 'Binding entries must be a contiguous list' end
    if table.getn(binding.entries) > MAX_ENTRIES then return nil, 'Too many entries (maximum 64)' end
    local result = { id = binding.id, name = name, key = key, entries = {} }
    local seen = {}
    for _, entry in ipairs(binding.entries) do
        if type(entry) ~= 'table' or (entry.kind ~= 'blueprint' and entry.kind ~= 'action')
            or not Identifier(entry.id) then return nil, 'Invalid binding entry' end
        local id = entry.id
        if entry.kind == 'blueprint' then id = string.lower(id) end
        local entryKey = entry.kind .. ':' .. id
        if seen[entryKey] then return nil, 'Duplicate entry: ' .. id end
        seen[entryKey] = true
        table.insert(result.entries, { kind = entry.kind, id = id })
    end
    if binding.grid ~= nil then
        local allowed = {}
        for _, entry in ipairs(result.entries) do if entry.kind == 'blueprint' then allowed[entry.id] = true end end
        local grid, gridError = CopyGrid(binding.grid, allowed)
        if not grid then return nil, gridError end
        result.grid = grid
    end
    return result
end

local function Descriptor(action)
    return { id = action.id, label = action.label, description = action.description }
end

---@param saved table?
---@return table
function Create(saved)
    local bindings = {}
    local byId = {}
    local actions = {}
    local warnings = {}
    local model = {}

    function model:List()
        local result = {}
        for _, binding in ipairs(bindings) do table.insert(result, CopyBinding(binding)) end
        return result
    end

    function model:Get(id)
        if not byId[id] then return nil end
        return CopyBinding(byId[id])
    end

    function model:Put(binding)
        local validated, err = Validate(binding)
        if not validated then return nil, err end
        if not byId[validated.id] and table.getn(bindings) >= MAX_BINDINGS then
            return nil, 'Too many bindings (maximum 64)'
        end
        for _, other in ipairs(bindings) do
            if other.id ~= validated.id and validated.key ~= '' and other.key == validated.key then
                return nil, 'Key already assigned to ' .. other.name
            end
        end
        if byId[validated.id] then
            for i, other in ipairs(bindings) do
                if other.id == validated.id then bindings[i] = validated; break end
            end
        else
            table.insert(bindings, validated)
        end
        byId[validated.id] = validated
        return true
    end

    function model:Delete(id)
        if not byId[id] then return false end
        for i, binding in ipairs(bindings) do
            if binding.id == id then table.remove(bindings, i); break end
        end
        byId[id] = nil
        return true
    end

    function model:Export()
        return { version = 1, bindings = self:List() }
    end

    function model:GetLoadWarnings()
        local result = {}
        for _, warning in ipairs(warnings) do table.insert(result, warning) end
        return result
    end

    function model:RegisterAction(action)
        if type(action) ~= 'table' or not Identifier(action.id) then return nil, 'Invalid action ID' end
        if actions[action.id] then return nil, 'Action already registered: ' .. action.id end
        if type(action.label) ~= 'string' or Trim(action.label) == '' then return nil, 'Action label required' end
        if type(action.execute) ~= 'function' then return nil, 'Action execute callback required' end
        if action.available ~= nil and type(action.available) ~= 'function' then
            return nil, 'Action availability must be a function'
        end
        actions[action.id] = {
            id = action.id, label = action.label,
            description = type(action.description) == 'string' and action.description or '',
            available = action.available, execute = action.execute,
        }
        return true
    end

    function model:GetAction(id)
        if not actions[id] then return nil end
        return Descriptor(actions[id])
    end

    function model:ListActions()
        local result = {}
        for _, action in pairs(actions) do table.insert(result, Descriptor(action)) end
        table.sort(result, function(a, b)
            if a.label == b.label then return a.id < b.id end
            return a.label < b.label
        end)
        return result
    end

    function model:Execute(bindingId, context, adapter, afterBlueprint)
        local binding = byId[bindingId]
        if not binding then return nil, 'Binding not found' end
        local count = table.getn(binding.entries)
        local start = 1
        if afterBlueprint then
            for i, entry in ipairs(binding.entries) do
                if entry.kind == 'blueprint' and entry.id == afterBlueprint then start = i + 1; break end
            end
        end
        for offset = 0, count - 1 do
            local entry = binding.entries[math.mod(start - 1 + offset, count) + 1]
            if entry.kind == 'blueprint' then
                if adapter and type(adapter.CanBuild) == 'function' and type(adapter.Build) == 'function' then
                    local ok, canBuild = pcall(adapter.CanBuild, adapter, entry.id, context)
                    if not ok then return nil, 'Build availability failed: ' .. tostring(canBuild) end
                    if canBuild then
                        local executed, result, message = pcall(adapter.Build, adapter, entry.id, context)
                        if not executed then return nil, 'Build failed: ' .. tostring(result) end
                        if result == false then return nil, message or 'Build command rejected' end
                        return true, entry.id
                    end
                end
            else
                local action = actions[entry.id]
                if action then
                    local available = true
                    if action.available then
                        local ok, result = pcall(action.available, context)
                        if not ok then return nil, 'Action availability failed: ' .. tostring(result) end
                        available = result and true or false
                    end
                    if available then
                        local ok, result, message = pcall(action.execute, context)
                        if not ok then return nil, 'Action failed: ' .. tostring(result) end
                        if result == false then return nil, message or 'Action rejected' end
                        return true, entry.id
                    end
                end
            end
        end
        return false, 'No applicable entry for the current selection'
    end

    if saved ~= nil then
        if type(saved) ~= 'table' or saved.version ~= 1 or not IsList(saved.bindings) then
            table.insert(warnings, 'Saved Hotbuild data has an unsupported or invalid format; using an empty list')
        else
            local seen = {}
            for i, binding in ipairs(saved.bindings) do
                if i > MAX_BINDINGS then
                    table.insert(warnings, 'Saved bindings beyond the maximum of 64 were ignored')
                    break
                end
                local ok, err
                if type(binding) == 'table' and seen[binding.id] then
                    err = 'Duplicate saved binding ID'
                else
                    ok, err = model:Put(binding)
                end
                if ok then seen[binding.id] = true
                else table.insert(warnings, 'Saved binding ' .. tostring(i) .. ' ignored: ' .. tostring(err)) end
            end
        end
    end
    return model
end
