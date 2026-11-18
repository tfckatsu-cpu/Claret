-- Session-owned feature registry. Definitions are fixed before option bindings start.
local Lifecycle = import('/mods/ClaretCore/modules/Lifecycle.lua')

---@param report fun(message:string)
---@param trace fun(message:string)
---@return table
function Create(report, trace)
    local entries = {}
    local order = {}
    local bindings = {}
    local disposed = false
    local registry = {}

    function registry:Register(id, start)
        assert(not disposed, 'registry is disposed')
        assert(type(id) == 'string' and id ~= '', 'feature ID required')
        assert(not entries[id], 'duplicate feature: ' .. id)
        entries[id] = Lifecycle.Create(start, function(message)
            report(id .. ': ' .. message)
        end)
        table.insert(order, id)
    end

    function registry:SetEnabled(id, enabled)
        if disposed then return false end
        local feature = entries[id]
        assert(feature, 'unknown feature: ' .. tostring(id))
        local before = feature:GetState()
        local ok = feature:SetEnabled(enabled)
        local after = feature:GetState()
        if before ~= after then trace(id .. ': ' .. after) end
        return ok
    end

    function registry:GetState(id)
        assert(entries[id], 'unknown feature: ' .. tostring(id))
        return entries[id]:GetState()
    end

    function registry:BindOption(id, option)
        assert(not disposed, 'registry is disposed')
        assert(entries[id], 'unknown feature: ' .. tostring(id))
        assert(not bindings[id], 'option already bound: ' .. id)
        local callback = function(sender, value) self:SetEnabled(id, value) end
        bindings[id] = { option = option, callback = callback }
        option.OnChanged:Add(callback)
        self:SetEnabled(id, option:Get())
    end

    function registry:Destroy()
        if disposed then return end
        disposed = true
        for i = table.getn(order), 1, -1 do
            local id = order[i]
            local binding = bindings[id]
            if binding then
                local ok, err = pcall(function()
                    binding.option.OnChanged:Remove(binding.callback)
                end)
                if not ok then report(id .. ': unbind failed: ' .. tostring(err)) end
            end
            entries[id]:Destroy()
            bindings[id] = nil
        end
    end

    return registry
end
