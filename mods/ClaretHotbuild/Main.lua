Version = '0.10.61'
-- Bump for every Hotbuild code change so the loaded build is identifiable.
local BuildStamp = '20261121-171'
LOG('[Claret][build] hotbuild='..Version..' stamp='..BuildStamp)

ReUI.Require {
    'ClaretCore >= 0.10.15',
    'ReUI.Core >= 1.7.0',
    'ReUI.UI >= 1.0.0',
    'ReUI.Options >= 1.2.0',
    enabled = true,
    version = 3816,
}

function Main(isReplay)
    local Localization = ReUI.ClaretCore.Localization
    local localizationTables = import('/mods/ClaretHotbuild/modules/LocalizationStrings.lua').Strings
    local localizationOk, localizationError = Localization.Register('hotbuild', localizationTables)
    if not localizationOk then error(localizationError) end
    local Runtime = import('/mods/ClaretHotbuild/modules/Runtime.lua')
    local BuildKeyLabels = import('/mods/ClaretHotbuild/modules/BuildKeyLabels.lua')
    -- Hotbuild is always active: a private constant-true option keeps Core's
    -- feature binding API while ignoring any saved disable value.
    local alwaysOn = {
        Get = function() return true end,
        OnChanged = { Add = function() end, Remove = function() end },
    }
    local service
    local navigatorMemory = { pageId = 'keyboard', hotbuild = {}, contexts = {} }
    local function Ensure()
        if not service then service = Runtime.Create(isReplay) end
        return service
    end

    ReUI.Core.Hook('/lua/keymap/hotkeylabels.lua', 'getKeyTables', function(original)
        return function()
            -- Keep the stock source of truth and its ReUI setIdRelations wrapper.
            -- This hook only decorates the BPID map returned by the original once.
            local idRelations, upgradeKey, orderKeys = original()
            if not service or not service.active or type(service.model) ~= 'table'
                or type(service.model.Get) ~= 'function'
                or type(service.KeyboardAssignments) ~= 'function' then
                return idRelations, upgradeKey, orderKeys
            end

            local okAssignments, assignments = pcall(service.KeyboardAssignments, service)
            if not okAssignments or type(assignments) ~= 'table' then
                return idRelations, upgradeKey, orderKeys
            end
            local okLabels, claretRelations = pcall(BuildKeyLabels.Build, service.model, assignments)
            if not okLabels or type(claretRelations) ~= 'table' then
                WARN('[ClaretHotbuild] build key labels failed: ' .. tostring(claretRelations))
                return idRelations, upgradeKey, orderKeys
            end
            local okMerge, merged = pcall(BuildKeyLabels.Merge, idRelations, claretRelations)
            if okMerge and type(merged) == 'table' then idRelations = merged end
            return idRelations, upgradeKey, orderKeys
        end
    end)

    ReUI.Core.Hook('/lua/ui/game/gamemain.lua', 'OnSelectionChanged', function(original,module)
        local isIgnored=rawget(module,'IsIgnoredSelection')
        return function(oldSelection, newSelection, added, removed)
            local ignored=isIgnored and isIgnored()
            local result=original(oldSelection,newSelection,added,removed)
            if service and not ignored then service:QuickSelectionChanged(newSelection or {}) end
            return result
        end
    end)
    ReUI.Core.Hook('/mods/ClaretCore/modules/MenuKey.lua', 'Open', function(original)
        return function()
            if service then service:BreakQuick() end
            return original()
        end
    end)

    local ok, message = ReUI.ClaretCore.RegisterFeature('hotbuild', function(scope)
        Ensure():Start(scope)
    end, alwaysOn)
    if not ok then error(message) end

    local settingsOk, settingsError = ReUI.ClaretCore.RegisterSettingsSection {
        id = 'hotbuild', title = 'Hotbuild', titleKey = 'hotbuild.section.title', descriptionKey = 'hotbuild.section.description',
        onMenuClosed = function()
            ForkThread(function()
                WaitFrames(2)
                if service and service.active and not ReUI.ClaretCore.IsMenuOpen() then
                    local success, err = pcall(service.RefreshKeys, service)
                    if not success then WARN('[ClaretHotbuild] Final key refresh failed: '..tostring(err)) end
                end
            end)
        end,
        inline = function(parent, layout)
            local service = Ensure()
            local Navigator = import('/mods/ClaretHotbuild/modules/Navigator.lua')
            return Navigator.Create(parent, layout, {
                { id = 'keyboard', titleKey = 'hotbuild.page.keyboard.title', descriptionKey = 'hotbuild.page.keyboard.description',
                    open = function(host, embedded)
                        local perf = import('/mods/ClaretHotbuild/modules/OpenPerf.lua').Start(ReUI)
                        local window = service:OpenKeyboardEditor(host, embedded, perf)
                        if perf and window then
                            perf:Add('entry_total', perf.entry); perf:Emit('entry_total')
                            if perf:Enabled() then LOG('[Claret][perf] stage=entry_path_navigator_keyboard ms=0') end
                            local previous = window.OnFrame
                            window.OnFrame = function(control, delta)
                                control.OnFrame = previous
                                if previous then previous(control, delta) else control:SetNeedsFrameUpdate(false) end
                                if perf:Enabled() then perf:Add('entry_to_next_frame', perf.entry); perf:Emit('entry_to_next_frame') end
                            end
                            window:SetNeedsFrameUpdate(true)
                        end
                        return window
                    end },
                { id = 'hotbuild', titleKey = 'hotbuild.page.hotbuild.title', descriptionKey = 'hotbuild.page.hotbuild.description',
                    open = function(host, embedded) return service:OpenEditor(host, embedded, navigatorMemory.hotbuild) end },
                { id = 'contexts', titleKey = 'hotbuild.page.contexts.title', descriptionKey = 'hotbuild.page.contexts.description',
                    open = function(host, embedded) return service:OpenContextEditor(host, embedded, navigatorMemory.contexts) end },
            }, navigatorMemory)
        end,
    }
    if not settingsOk then error(settingsError) end

    ReUI.Core.Hook('/lua/ui/dialogs/keybindings.lua', 'CloseUI', function(original)
        if type(original) ~= 'function' then return original end
        return function()
            local result = original()
            if service then
                local success, err = pcall(service.RefreshKeys, service)
                if not success then WARN('[ClaretHotbuild] Key refresh failed: ' .. tostring(err)) end
            end
            return result
        end
    end)

    ReUI.Core.OnPostCreateUI(function()
        Ensure()
        local Group = import('/lua/maui/group.lua').Group
        local owner = Group(GetFrame(0))
        owner:DisableHitTest()
        local onDestroy = owner.OnDestroy
        owner.OnDestroy = function(self)
            if service then service:Destroy(); service = nil end
            onDestroy(self)
        end
        LOG('[ClaretHotbuild ' .. Version .. '] ready')
    end)

    return {
        RegisterAction = function(definition)
            if not service then return false, 'Claret Hotbuild session is not ready' end
            return service:RegisterAction(definition)
        end,
    }
end

