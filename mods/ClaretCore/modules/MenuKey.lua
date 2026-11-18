-- One native FAF action; update only its engine entries, preserving other mod maps.
local current
local actionId = 'ClaretCore_OpenMenu'
local initializedKey = 'ClaretCoreMenuKeyInitialized'

local function TraceMap(op, caller)
    local options=ReUI.Options and ReUI.Options.Mods and ReUI.Options.Mods['ClaretCore']
    local probe=options and options.probeEnabled
    if probe and probe:Get() then LOG('[Claret][keymap] op='..op..' by=MenuKey:'..caller) end
end

function Open()
    if not current then return false end
    current()
    return true
end

local function Copy(value)
    if type(value) ~= 'table' then return value end
    local result = {}
    for k,v in pairs(value) do result[k] = Copy(v) end
    return result
end

function Create(open)
    local Localization = import('/mods/ClaretCore/modules/Localization.lua').Localization
    local Mapper = import('/lua/keymap/keymapper.lua')
    local Prefs = import('/lua/user/prefs.lua')
    local descriptions = import('/lua/keymap/keydescriptions.lua').keyDescriptions
    local lookup = Mapper.GetKeyCodeLookup()
    local definition = {action='UI_Lua import("/mods/ClaretCore/modules/MenuKey.lua").Open()',category='Claret'}
    local installed, ready, disposed = {}, false, false
local function T(key)
    if Localization and type(Localization.Text)=='function' then return Localization.Text(key) end
    return key
end

    local service = {}
    local descriptionToken = {}
    current = open

    local function Maps() return {Mapper.GetCurrentKeyMap(), Mapper.GetUserDebugKeyMap()} end
    local function OwnKeys()
        local keys, seen = {}, {}
        for _,map in ipairs(Maps()) do
            for key,id in pairs(map) do
                if id==actionId and not seen[key] then table.insert(keys,key); seen[key]=true end
            end
        end
        table.sort(keys)
        return keys
    end

    function service:Get() return table.concat(OwnKeys(), ', ') end

    function service:FromEvent(event)
        if event.Type~='KeyDown' then return nil end
        local key = lookup[event.RawKeyCode]
        if not key or key=='Ctrl' or key=='Alt' or key=='Shift' then return nil end
        local modifiers = event.Modifiers or {}
        return Mapper.NormalizeKeyBinding((modifiers.Ctrl and 'Ctrl-' or '')
            ..(modifiers.Shift and 'Shift-' or '')..(modifiers.Alt and 'Alt-' or '')..key)
    end

    function service:Matches(event)
        local key=self:FromEvent(event)
        if not key then return false end
        for _,owned in ipairs(OwnKeys()) do if owned==key then return true end end
        return false
    end

    function service:Validate(key)
        if key=='' then return true end
        local parsed = Mapper.NormalizeKey(key)
        if not parsed.key or string.lower(parsed.key)=='escape' or string.lower(parsed.key)=='esc' then
            return false, T('core.menu_key.s001')
        end
        local known = false
        for _,name in pairs(lookup) do if name==parsed.key then known=true end end
        if not known then return false, T('core.menu_key.s002') end
        local normal = Mapper.NormalizeKeyBinding(key)
        for _,map in ipairs(Maps()) do
            for other,id in pairs(map) do
                if Mapper.NormalizeKeyBinding(other)==normal and id~=actionId then
                    return false, T('core.menu_key.s003')..Mapper.GetActionName(id)..T('core.menu_key.s004')
                end
            end
        end
        for other in pairs(Mapper.GenerateHotbuildModifiers()) do
            if Mapper.NormalizeKeyBinding(other)==normal then
                return false, T('core.menu_key.s005')
            end
        end
        return true
    end

    function service:Refresh()
        if disposed or not ready then return end
        local removal, wanted = {}, {}
        local maps = Maps()
        for key in pairs(installed) do
            local foreign = false
            for _,map in ipairs(maps) do if map[key] and map[key]~=actionId then foreign=true end end
            if not foreign then removal[key]=true end
        end
        for _,key in ipairs(OwnKeys()) do wanted[key]=definition end
        if next(removal) then TraceMap('remove','Refresh'); IN_RemoveKeyMapTable(removal) end
        if next(wanted) then TraceMap('add','Refresh'); IN_AddKeyMapTable(wanted) end
        installed = wanted
    end

    function service:Set(key)
        if disposed then return false, T('core.menu_key.s006') end
        local ok,message = self:Validate(key)
        if not ok then return false,message end
        if key~='' then key=Mapper.NormalizeKeyBinding(key) end
        local before = {
            user=Copy(Prefs.GetFromCurrentProfile('UserKeyMap')),
            debug=Copy(Prefs.GetFromCurrentProfile('UserDebugKeyMap')),
        }
        local oldKeys = OwnKeys()
        local success,err = pcall(function()
            for _,old in ipairs(oldKeys) do Mapper.ClearUserKeyMapping(old) end
            if key~='' then Mapper.SetUserKeyMapping(key,nil,actionId) end
            self:Refresh()
            SavePreferences()
        end)
        if not success then
            Prefs.SetToCurrentProfile('UserKeyMap',before.user)
            Prefs.SetToCurrentProfile('UserDebugKeyMap',before.debug)
            -- An engine call can fail after partially installing the requested key.
            local removal = {}; if key~='' then removal[key]=true end
            for _,old in ipairs(oldKeys) do removal[old]=true end
            local restored = {}; for _,old in ipairs(oldKeys) do restored[old]=definition end
            if ready then
                local recovered,recoveryError = pcall(function()
                    if next(removal) then TraceMap('remove','SetRollback'); IN_RemoveKeyMapTable(removal) end
                    if next(restored) then TraceMap('restore','SetRollback'); IN_AddKeyMapTable(restored) end
                end)
                if not recovered then WARN('[Claret] Key rollback failed: '..tostring(recoveryError)) end
            end
            installed=restored
            WARN('[Claret] Menu key save failed: '..tostring(err))
            return false, T('core.menu_key.s007')
        end
        return true
    end

    function service:Initialize()
        Mapper.SetUserKeyAction(actionId,definition)
        descriptions[actionId]=T('core.menu_key.s008')
        if type(Localization.Subscribe)=='function' then
            Localization.Subscribe(descriptionToken,function() descriptions[actionId]=T('core.menu_key.s008') end)
        end
        if not Prefs.GetFromCurrentProfile(initializedKey) then
            if self:Get()=='' and self:Validate('Ctrl-Alt-C') then
                Mapper.SetUserKeyMapping('Ctrl-Alt-C',nil,actionId)
            end
            Prefs.SetToCurrentProfile(initializedKey,true)
            SavePreferences()
        end
    end

    function service:Start() ready=true; self:Refresh() end

    function service:Destroy()
        if disposed then return end
        -- Saved bindings belong to FAF and survive this UI session.
        disposed=true; ready=false
        if type(Localization.Unsubscribe)=='function' then Localization.Unsubscribe(descriptionToken) end
        if current==open then current=nil end
        installed={}
    end
    return service
end
