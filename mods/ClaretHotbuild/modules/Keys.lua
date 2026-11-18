-- Register saved bindings as ordinary FAF key actions. Key assignments are managed by FAF.
function Create()
    local Prefs = import('/lua/user/prefs.lua')
    local Mapper = import('/lua/keymap/keymapper.lua')
    local descriptions = import('/lua/keymap/keydescriptions.lua').keyDescriptions
    local category = 'Claret Hotbuild'
    local prefix = 'ClaretHotbuild_'
    local absolutePrefix = 'ClaretHotbuildAbsolute_'
    local keys = {}

    function keys:HeldChord(chord)
        local base=type(chord)=='string' and string.match(chord,'([^%-]+)$')
        if base then
            local ok,down=pcall(IsKeyDown,base)
            if ok and down then return base end
        end
    end

    local function ActionId(id)
        -- Encode every byte, including underscores, to avoid collisions between IDs.
        return prefix .. (string.gsub(id, '.', function(c) return string.format('%02X', string.byte(c)) end))
    end

    function keys:HeldKey(id)
        local actionId=ActionId(id)
        for _,profileKey in ipairs({'UserKeyMap','UserDebugKeyMap'}) do
            for key,action in pairs(Prefs.GetFromCurrentProfile(profileKey) or {}) do
                if action==actionId and type(key)=='string' then
                    local base=string.match(key,'([^%-]+)$')
                    if base then
                        -- FAF's IsKeyDown accepts only its enum of special keys;
                        -- ordinary letters raise an error instead of returning false.
                        local ok,down=pcall(IsKeyDown,base)
                        if ok and down then return base end
                    end
                end
            end
        end
    end

    function keys:HeldAbsoluteKey(id)
        local actionId=absolutePrefix .. string.gsub(id, '.', function(c)
            return string.format('%02X', string.byte(c))
        end)
        for _,profileKey in ipairs({'UserKeyMap','UserDebugKeyMap'}) do
            for key,action in pairs(Prefs.GetFromCurrentProfile(profileKey) or {}) do
                if action==actionId and type(key)=='string' then
                    local base=string.match(key,'([^%-]+)$')
                    if base then
                        local ok,down=pcall(IsKeyDown,base)
                        if ok and down then return base end
                    end
                end
            end
        end
    end

    function keys:Validate(bindings)
        return true
    end

    function keys:Stop()
        -- FAF owns the active key map and its lifecycle.
    end

    function keys:Apply(bindings)
        local wanted = {}
        for _, binding in ipairs(bindings) do
            local id = ActionId(binding.id)
            wanted[id] = true
            Mapper.SetUserKeyAction(id, {
                action = string.format('UI_Lua import("/mods/ClaretHotbuild/modules/Runtime.lua").Execute(%q, IsKeyDown(16))', binding.id),
                category = category,
            })
            descriptions[id] = binding.name
        end
        local actions = Prefs.GetFromCurrentProfile('UserKeyActions') or {}
        local removed = {}
        for id, action in pairs(actions) do
            if string.sub(id, 1, string.len(prefix)) == prefix and action.category == category and not wanted[id] then
                actions[id] = nil
                descriptions[id] = nil
                removed[id] = true
            end
        end
        Prefs.SetToCurrentProfile('UserKeyActions', actions)
        -- Remove assignments only for actions that were deleted from Claret.
        for _, profileKey in ipairs({'UserKeyMap', 'UserDebugKeyMap'}) do
            local map = Prefs.GetFromCurrentProfile(profileKey)
            if map then
                local changed = false
                for key, id in pairs(map) do
                    if removed[id] then map[key] = nil; changed = true end
                end
                if changed then Prefs.SetToCurrentProfile(profileKey, map) end
            end
        end
        return true
    end
    function keys:ApplyAbsolute(bindings)
        local wanted, assigned = {}, {}
        for _, profileKey in ipairs({'UserKeyMap','UserDebugKeyMap'}) do
            for _,id in pairs(Prefs.GetFromCurrentProfile(profileKey) or {}) do
                if type(id)=='string' and string.sub(id,1,string.len(absolutePrefix))==absolutePrefix then assigned[id]=true end
            end
        end
        for _, binding in ipairs(bindings or {}) do
                local id = absolutePrefix .. string.gsub(binding.id, '.', function(c) return string.format('%02X', string.byte(c)) end)
                if assigned[id] then
                    wanted[id] = true
                Mapper.SetUserKeyAction(id, {
                    action = string.format('UI_Lua import("/mods/ClaretHotbuild/modules/Runtime.lua").ExecuteAbsolute(%q)', binding.id),
                    category = category,
                })
                    descriptions[id] = binding.name
                end
        end
        local actions = Prefs.GetFromCurrentProfile('UserKeyActions') or {}
        for id, action in pairs(actions) do
            if string.sub(id, 1, string.len(absolutePrefix)) == absolutePrefix
                and action.category == category and not assigned[id] then
                actions[id], descriptions[id] = nil, nil
            end
        end
        Prefs.SetToCurrentProfile('UserKeyActions', actions)
        return true
    end
    return keys
end
