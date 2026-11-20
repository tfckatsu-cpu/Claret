Version = '0.10.27'
local BuildStamp = '20261120-59'
LOG('[Claret][build] core='..Version..' stamp='..BuildStamp)

ReUI.Require {
    'ReUI.Core >= 1.7.0',
    'ReUI.Core.Events >= 1.0.0',
    'ReUI.UI >= 1.0.0',
    'ReUI.Options >= 1.2.0',
    version = 3816,
    enabled = true,
}

---@param isReplay boolean
function Main(isReplay)
    local logPrefix = '[ClaretCore ' .. Version .. '] '
    local options = ReUI.Options.Mods['ClaretCore']
    local Localization = import('/mods/ClaretCore/modules/Localization.lua').Localization
    local currentLanguage = Localization.Initialize(options.language:Get())
    local transportCargo = import('/mods/ClaretCore/modules/TransportCargo.lua').Create(isReplay)
    local savedLanguage = options.language:Get()
    if savedLanguage ~= 'en' and savedLanguage ~= 'ru' then
        local languageSaved = pcall(function()
            options.language:Set(currentLanguage)
            options.language:Save()
            SavePreferences()
        end)
        if not languageSaved then
            pcall(function()
                options.language:Set(savedLanguage)
                options.language:Save()
                SavePreferences()
            end)
            WARN(logPrefix .. 'could not migrate interface language preference')
        end
    end
    local languageChanged = function()
        ForkThread(function()
            WaitFrames(1)
            Localization.SetLanguage(options.language:Get())
        end)
    end
    options.language.OnChanged:Add(languageChanged)
    local strategicRings = import('/mods/ClaretCore/modules/StrategicRings.lua').Create()
    local minimap = import('/mods/ClaretCore/modules/Minimap.lua').Create(options.minimapAutoHide, options.minimapBorderless)
    ReUI.Core.Hook('/lua/ui/game/minimap.lua', 'ToggleMinimap', function(original)
        return function()
            if import('/lua/ui/game/gamemain.lua').gameUIHidden then return original() end
            local result = original()
            minimap:ManualToggle()
            return result
        end
    end)
    ReUI.Core.Hook('/lua/ui/game/minimap.lua', 'SetLayout', function(original)
        return function(layout)
            local result = original(layout)
            minimap:LayoutChanged()
            return result
        end
    end)
    ReUI.Core.Hook('/lua/ui/game/painting/PaintingBrush.lua', 'PaintingBrush', function(previousBrush)
        return Class(previousBrush) {
            DeletePaintingAtBrush = function(self, coordinates, radius)
                local result = previousBrush.DeletePaintingAtBrush(self, coordinates, radius)
                if strategicRings then
                    local ok, err = pcall(strategicRings.DeleteAtBrush, strategicRings, coordinates, radius)
                    if not ok then WARN(logPrefix .. 'ring eraser failed: ' .. tostring(err)) end
                end
                return result
            end,
        }
    end)
    local menu
    local uiReady = false
    local menuKey = import('/mods/ClaretCore/modules/MenuKey.lua').Create(function()
        if uiReady then menu:Toggle() end
    end)
    menu = import('/mods/ClaretCore/modules/Menu.lua').Create(menuKey)
    local coreToggles = {
        {labelKey = 'core.setting.selection', option = options.selectionEnabled, centerLabel = true},
        {labelKey = 'core.setting.welcome', option = options.welcomeDismissed, centerLabel = true},
    }
    if rawget(_G, 'REUI_DEV_MODE') then
        table.insert(coreToggles, 1, {
            labelKey = 'core.setting.diagnostics', descriptionKey = 'core.setting.diagnostics_description', option = options.probeEnabled,
        })
    end
    menu:Register {
        id = 'core', title = 'Core', titleKey = 'core.section.title', descriptionKey = 'core.section.description',
        toggles = coreToggles,
        selectors = {{
            labelKey = 'core.menu.language', option = options.language,
            values = {
                {id = 'en', labelKey = 'core.language.english', shortLabel = 'EN'},
                {id = 'ru', labelKey = 'core.language.russian', shortLabel = 'RU'},
            },
            segmented = true,
            getLabel = function()
                local language = options.language:Get()
                if language ~= 'en' and language ~= 'ru' then language = Localization.GetLanguage() end
                return Localization.Text(language == 'ru' and 'core.language.russian' or 'core.language.english')
            end,
        }},
    }
    ReUI.Core.OnPreCreateUI(function()
        menuKey:Initialize()
        import('/lua/ui/game/tabs.lua').AddToMenu {
            action = 'Claret.Settings', label = 'Claret', tooltip = Localization.Text('core.settings.tooltip'),
            func = function() menu:Open() end,
        }
    end)
    local Registry = import('/mods/ClaretCore/modules/Registry.lua')
    local SelectionSummary = import('/mods/ClaretCore/modules/SelectionSummary.lua')
    local selectionChanged = ReUI.Core.Events.Event('ClaretSelection')
    local registry
    local pending = {}
    local registered = { probe = true, selectionSummary = true }
    local disposed = false
    local currentSelection
    local selectionHudActive = false

    local function GetSelection()
        return currentSelection or GetSelectedUnits() or {}
    end

    local function UpdateSelectionSummary()
        if registry and not disposed then
            registry:SetEnabled('selectionSummary', not selectionHudActive and options.selectionEnabled:Get())
        end
    end

    local function UseSelectionHud(scope, refresh)
        assert(registry and not disposed and not selectionHudActive, 'Selection HUD is unavailable')
        scope:Defer(function()
            selectionHudActive = false
            UpdateSelectionSummary()
        end)
        selectionHudActive = true
        UpdateSelectionSummary()
        scope:Bind(selectionChanged, function(_, selection) refresh(selection) end)
        refresh(GetSelection())
    end

    local function RegisterFeature(id, start, option)
        if disposed then return false, 'Claret session is disposed' end
        if type(id) ~= 'string' or id == '' or type(start) ~= 'function' or not option then
            return false, 'Feature ID, start function and enabled option required'
        end
        if registered[id] then return false, 'Feature already registered: ' .. id end
        registered[id] = true
        if registry then
            registry:Register(id, start)
            registry:BindOption(id, option)
        else
            table.insert(pending, { id = id, start = start, option = option })
        end
        return true
    end

    ReUI.Core.OnPostCreateUI(function()
        local Group = import('/lua/maui/group.lua').Group
        local parent = GetFrame(0)
        local owner = Group(parent)
        ReUI.UI.FloorLayoutFor(owner):Fill(parent)
        owner:DisableHitTest()

        registry = Registry.Create(function(message)
            WARN(logPrefix .. message)
        end, function(message)
            LOG(logPrefix .. message)
        end)

        -- FAF publishes this event only for visible selections. The accessor may
        -- still report the previous selection while the observer is running.
        local observeSelection = import('/lua/ui/game/gamemain.lua').ObserveSelection
        observeSelection:AddObserver(function(info)
            currentSelection = info.newSelection or {}
            transportCargo:Reset()
            selectionChanged:Invoke(nil, currentSelection)
        end, 'ClaretCore')
        local onDestroy = owner.OnDestroy
        local stopMinimap = minimap:Start(owner)
        owner.OnDestroy = function(self)
            disposed = true
            uiReady = false
            observeSelection:AddObserver(nil, 'ClaretCore')
            options.selectionEnabled.OnChanged:Remove(UpdateSelectionSummary)
            currentSelection = nil
            menuKey:Destroy()
            menu:Destroy()
            transportCargo:Destroy()
            stopMinimap()
            if strategicRings then strategicRings:Destroy(); strategicRings = nil end
            if registry then
                registry:Destroy()
                registry = nil
            end
            selectionChanged:Clear()
            options.language.OnChanged:Remove(languageChanged)
            LOG(logPrefix .. 'session disposed')
            onDestroy(self)
        end

        registry:Register('selectionSummary', function(scope)
            SelectionSummary.Start(owner, scope, selectionChanged, GetSelection())
        end)
        options.selectionEnabled.OnChanged:Add(UpdateSelectionSummary)
        UpdateSelectionSummary()
        for _, feature in ipairs(pending) do
            registry:Register(feature.id, feature.start)
            registry:BindOption(feature.id, feature.option)
        end
        pending = {}
        menuKey:Start()
        uiReady = true
        local welcomeOk, welcomeError = pcall(function()
            local Welcome = import('/mods/ClaretCore/modules/Welcome.lua')
            if Welcome.ShouldShowWelcome(options.welcomeDismissed:Get()) then
                Welcome.Create(owner, menuKey, options.welcomeDismissed, options.language)
            end
        end)
        if not welcomeOk then WARN(logPrefix .. 'welcome window failed: ' .. tostring(welcomeError)) end
        LOG(logPrefix .. 'ready; replay=' .. tostring(isReplay))
    end)

    return {
        GetFeatureState = function(id)
            if not registry then return 'unavailable' end
            return registry:GetState(id)
        end,
        RegisterFeature = RegisterFeature,
        UseSelectionHud = UseSelectionHud,
        RegisterSettingsSection = function(definition) return menu:Register(definition) end,
        Localization = Localization,
        IsMenuOpen = function() return menu:IsOpen() end,
        IsKeyCaptureActive = function() return menu:IsKeyCaptureActive() end,
        AppendTransportCargo = function(selection)
            if isReplay or not uiReady or disposed then return false end
            local callOk, directOk, directMessage, directFallback = pcall(function()
                return import('/mods/ClaretCore/modules/ReUICargoIndicator.lua').AppendNext()
            end)
            if callOk and directOk and directMessage then
                if directFallback then WARN(logPrefix .. tostring(directFallback)) end
                return true
            end
            local reason, fallbackAllowed
            if not callOk then
                reason, fallbackAllowed = directOk, true
            else
                reason, fallbackAllowed = directMessage, directFallback
            end
            if not fallbackAllowed then
                WARN(logPrefix .. 'transport cargo append failed: ' .. tostring(reason))
                return false
            end

            local okFallback, unit, index, cargo = transportCargo:Append(selection)
            if not okFallback or not unit then return false end
            local markCallOk, marked, markError = pcall(function()
                return import('/mods/ClaretCore/modules/ReUICargoIndicator.lua').Mark(unit, cargo)
            end)
            if not markCallOk or not marked then
                WARN(logPrefix .. 'transport cargo HUD fallback failed: ' .. tostring(markCallOk and markError or marked))
            end
            return true, unit, index
        end,
        CreateStrategicRing = function(includeVision)
            if not uiReady or disposed or not strategicRings then return false, 'Strategic rings are unavailable' end
            return strategicRings:CreateHover(includeVision == true)
        end,
    }
end

