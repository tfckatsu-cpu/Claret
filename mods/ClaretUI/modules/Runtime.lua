-- Claret UI feature host. A feature is a module with Start(self, scope, isReplay)
-- and optionally SetVisible(self, visible); its option drives that visibility.
local features = {
    { id = 'positions', module = '/mods/ClaretUI/modules/features/RevealPositions.lua', option = 'revealPositions' },
    { id = 'acu', module = '/mods/ClaretUI/modules/features/AcuHealth.lua', option = 'acuHealth' },
    { id = 'selection', module = '/mods/ClaretUI/modules/features/SelectionHud.lua' },
    { id = 'mexes', module = '/mods/ClaretUI/modules/features/Mexes.lua', option = 'mexPanel' },
    { id = 'allRings', module = '/mods/ClaretUI/modules/features/AllRings.lua', option = 'allRings' },
    { id = 'infoShare', module = '/mods/ClaretUI/modules/features/InfoShare.lua' },
    { id = 'notifications', module = '/mods/ClaretUI/modules/features/Notifications.lua' },
}

local service = {}
service.__index = service

function Create(isReplay, options)
    return setmetatable({ isReplay = isReplay, options = options or {}, started = false }, service)
end

function service:Start(scope)
    if self.started then return end
    self.started = true
    scope:Defer(function() self.started = false end)
    for _, definition in ipairs(features) do
        local loaded, feature = pcall(function() return import(definition.module) end)
        if not loaded or type(feature) ~= 'table' then
            WARN('[ClaretUI] feature module failed: ' .. definition.id .. ': ' .. tostring(feature))
        else
            local ok, err = pcall(feature.Start, feature, scope, self.isReplay, self.options)
            if not ok then WARN('[ClaretUI] feature failed: ' .. definition.id .. ': ' .. tostring(err)) end
            local option = definition.option and self.options[definition.option]
            if option and type(feature.SetVisible) == 'function' then
                local function Apply(sender, value)
                    local shown, err = pcall(feature.SetVisible, feature, value ~= false)
                    if not shown then WARN('[ClaretUI] visibility failed: ' .. definition.id .. ': ' .. tostring(err)) end
                end
                local added = pcall(function() option.OnChanged:Add(Apply) end)
                if added then
                    Apply(nil, option:Get())
                    scope:Defer(function() pcall(function() option.OnChanged:Remove(Apply) end) end)
                else
                    WARN('[ClaretUI] option subscribe failed: ' .. definition.id)
                end
            end
        end
    end
end

return { Create = Create }
