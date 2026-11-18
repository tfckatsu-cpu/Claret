-- Unregistered assembly of Claret construction presentation components.
-- The caller supplies game/model adapters and decides when to connect selection,
-- queue, command, and lifecycle events. This module installs no hooks.

local function Resolve(options, key, path, symbol)
    local supplied = options.modules and options.modules[key]
    if supplied then return supplied end
    return import(path)[symbol]
end

local function CopyWithType(entry, itemType)
    local copy = {}
    for key, value in pairs(entry) do copy[key] = value end
    copy.type = itemType
    return copy
end

local function AdaptQueueEntry(entry)
    if type(entry) ~= 'table' then return nil end
    if entry.kind == 'factory' then return CopyWithType(entry, 'queuestack') end
    if entry.kind == 'enhancement' then return CopyWithType(entry, 'enhancementqueue') end
    if entry.type == 'templates' then return entry end
    if entry.type then return entry end
    return nil
end

function Create(parent, options)
    options = options or {}
    if not parent then return nil, 'construction panel parent required' end
    local adapters = options.adapters or {}
    local models = options.models or {}
    local cargoState = options.cargoState
    if not cargoState then return nil, 'construction panel cargoState required' end

    local Shell = Resolve(options, 'shell', '/mods/ClaretCore/modules/ConstructionPanelShell.lua', 'Create')
    local Controller = Resolve(options, 'controller', '/mods/ClaretCore/modules/ConstructionController.lua', 'Create')
    local ItemsView = Resolve(options, 'itemsView', '/mods/ClaretCore/modules/ConstructionItemsView.lua', 'Create')
    local CargoView = Resolve(options, 'cargoView', '/mods/ClaretCore/modules/ConstructionCargoView.lua', 'Create')
    local Facade = Resolve(options, 'facade', '/mods/ClaretCore/modules/ConstructionFacade.lua', 'Create')
    if type(Shell) ~= 'function' or type(Controller) ~= 'function'
        or type(ItemsView) ~= 'function' or type(CargoView) ~= 'function'
        or type(Facade) ~= 'function' then return nil, 'construction panel modules unavailable' end

    local shellOptions = options.shellOptions or {}
    if options.factories and not shellOptions.factories then shellOptions.factories = options.factories end
    local shell = Shell(parent, shellOptions)
    local root = shell and shell.root
    if not root then return nil, 'construction shell did not create a root' end

    local controller, primaryItems, secondaryItems, cargoView, facadeRoot, panel
    local destroyed, destroying, rootDestroying = false, false, false
    local report = adapters.onError or function(message, detail) WARN('[Claret Construction] ' .. tostring(message) .. ': ' .. tostring(detail)) end

    local function Report(message, detail)
        if type(report) == 'function' then pcall(report, message, detail) end
    end

    local function ClearGrid(grid)
        local clearOk, clearError = true, nil
        if type(grid.ClearItems) == 'function' then clearOk, clearError = pcall(grid.ClearItems, grid) end
        if not clearOk then Report('construction grid clear failed', clearError); return false end
        if type(grid.Refresh) ~= 'function' then Report('construction grid refresh unavailable'); return false end
        local refreshOk, refreshError = pcall(grid.Refresh, grid, {})
        if not refreshOk then Report('construction grid clear refresh failed', refreshError); return false end
        return true
    end

    local function SyncNestedTabs(kind, items, selected)
        if type(items) ~= 'table' then return end
        local existing = {}
        for _, tab in ipairs(shell.tabs) do
            if tab.kind == kind then table.insert(existing, tab) end
        end
        local unchanged = table.getn(existing) == table.getn(items)
        if unchanged then
            for index, item in ipairs(items) do
                if existing[index].ID ~= item.id then unchanged = false; break end
            end
        end
        if not unchanged then
            shell:ClearNestedTabs(kind)
            existing = {}
            for _, item in ipairs(items) do
                local tab = shell:CreateNestedTab(kind, item.id)
                table.insert(existing, tab)
            end
        end
        for index, item in ipairs(items) do
            local id = item.id
            if id ~= nil then
                local tab = existing[index]
                local key = tostring(kind) .. ':' .. tostring(id)
                tab:SetCheck(id == selected, true)
                tab.OnCheck = function(_, checked)
                    if checked == false or destroyed or not controller then return false end
                    local previous = kind == 'tech' and controller.techTab or controller.enhancementSlot
                    local ok, result
                    if kind == 'tech' then ok, result = pcall(controller.SelectTech, controller, id)
                    else ok, result = pcall(controller.SelectEnhancementSlot, controller, id) end
                    if not ok or result == false then
                        for _, current in ipairs(shell.tabs) do
                            if current.kind == kind and current.SetCheck
                                and shell.tabsByKey[kind .. ':' .. tostring(current.ID)] == current then
                                local isDead = false
                                if type(IsDestroyed) == 'function' then
                                    local checkOk, value = pcall(IsDestroyed, current)
                                    isDead = checkOk and value == true
                                end
                                if not isDead then pcall(current.SetCheck, current, current.ID == previous, true) end
                            end
                        end
                        return false
                    end
                    return true
                end
                if item.texture then shell:SetNestedTabTextures(tab, item.texture) end
            end
        end
    end

    local function HasEligibleTemplates()
        local model = models.templatesModel or (options.controllerDependencies and options.controllerDependencies.templatesModel)
        if type(model) ~= 'table' or type(model.Build) ~= 'function'
            or not controller or type(controller.selection) ~= 'table'
            or table.getn(controller.selection) == 0 then return false end
        local mobileTemplates, factoryTemplates
        local getTemplates = adapters.getTemplates
            or (options.controllerDependencies and options.controllerDependencies.getTemplates)
        if type(getTemplates) == 'function' then
            local ok, first, second = pcall(getTemplates, controller.selection)
            if not ok then return false end
            mobileTemplates, factoryTemplates = first, second
        else
            mobileTemplates = options.controllerDependencies and options.controllerDependencies.mobileTemplates
            factoryTemplates = options.controllerDependencies and options.controllerDependencies.factoryTemplates
        end
        local ok, result = pcall(model.Build, controller.selection, mobileTemplates, factoryTemplates,
            { allowCrossFaction = options.controllerDependencies and options.controllerDependencies.allowCrossFaction == true })
        if not ok or type(result) ~= 'table' or type(result.entries) ~= 'table' then return false end
        if type(result.fatalErrors) == 'table' and table.getn(result.fatalErrors) > 0 then return false end
        return table.getn(result.entries) > 0
    end

    local function SyncAvailableTechTabs(selected, templatesEligible)
        local result = controller and controller.choiceResult
        local tabs = result and result.tabs
        local available = {}
        for _, id in ipairs({ 't1', 't2', 't3', 't4' }) do
            local entries = tabs and tabs[id]
            if type(entries) == 'table' and table.getn(entries) > 0 then
                table.insert(available, { id = id })
            end
        end
        if templatesEligible == nil then templatesEligible = HasEligibleTemplates() end
        if templatesEligible then table.insert(available, { id = 'templates' }) end
        SyncNestedTabs('tech', available, selected)
    end

    local function RenderPrimary(_, mode, data, detail)
        if destroyed then return false end
        if mode == 'clear' then
            shell:ClearNestedTabs('tech')
            shell:ClearNestedTabs('enhancement')
            return ClearGrid(shell.choices)
        end
        if type(data) ~= 'table' then return false end
        if mode == 'construction' then
            shell:ClearNestedTabs('enhancement')
            SyncAvailableTechTabs(detail and detail.techTab)
        elseif mode == 'templates' then
            shell:ClearNestedTabs('enhancement')
            SyncAvailableTechTabs(controller and controller.techTab, table.getn(data) > 0)
        elseif mode == 'enhancement' then
            shell:ClearNestedTabs('tech')
            local slots = {}
            for _, slot in ipairs(detail and detail.slots or {}) do
                table.insert(slots, { id = slot.id })
            end
            SyncNestedTabs('enhancement', slots, detail and detail.selectedSlot)
        else
            shell:ClearNestedTabs('tech')
            shell:ClearNestedTabs('enhancement')
        end
        shell.choices:Refresh(data)
        return true
    end

    local function RenderSecondary(_, mode, data, detail)
        if destroyed then return false end
        if mode == 'cargo' then
            if type(data) ~= 'table' or type(data.units) ~= 'table' then return false end
            return cargoView:Activate(data.units)
        end
        if mode == 'clear' then
            if cargoView.active then
                return cargoView:Deactivate({})
            end
            return ClearGrid(shell.secondaryChoices)
        end
        if type(data) ~= 'table' then return false end
        if cargoView.active then
            return cargoView:Deactivate(data)
        end
        shell.secondaryChoices:Refresh(data)
        return true
    end

    local function Click(data, modifiers)
        if destroyed or type(adapters.onItemClick) ~= 'function' then return false end
        local payload = AdaptQueueEntry(data) or data
        local ok, result = pcall(adapters.onItemClick, payload, modifiers, controller, root)
        if not ok then Report('item click adapter failed', result); return false end
        return result ~= false
    end

    local function Rollover(data, active)
        if destroyed or type(adapters.onRollover) ~= 'function' then return end
        local payload = AdaptQueueEntry(data) or data
        local ok, result = pcall(adapters.onRollover, payload, active, controller, root)
        if not ok then Report('item rollover adapter failed', result) end
    end

    local ok, err = pcall(function()
        primaryItems = ItemsView(shell.choices, {
            OnClick = Click,
            OnRollover = Rollover,
            AdaptData = AdaptQueueEntry,
        })
        secondaryItems = ItemsView(shell.secondaryChoices, {
            OnClick = Click,
            OnRollover = Rollover,
            AdaptData = AdaptQueueEntry,
        })
        cargoView = CargoView(root, cargoState, { grid = shell.secondaryChoices })

        local controllerDependencies = {}
        for key, value in pairs(options.controllerDependencies or {}) do controllerDependencies[key] = value end
        controllerDependencies.choices = models.choices or controllerDependencies.choices
        controllerDependencies.gridModel = models.gridModel or controllerDependencies.gridModel
        controllerDependencies.selectionModel = models.selectionModel or controllerDependencies.selectionModel
        controllerDependencies.queueModel = models.queueModel or controllerDependencies.queueModel
        controllerDependencies.templatesModel = models.templatesModel or controllerDependencies.templatesModel
        controllerDependencies.enhancementsModel = models.enhancementsModel or controllerDependencies.enhancementsModel
        controllerDependencies.cargoState = cargoState
        controllerDependencies.primaryView = primaryItems
        controllerDependencies.secondaryView = secondaryItems
        controllerDependencies.renderPrimary = RenderPrimary
        controllerDependencies.renderSecondary = RenderSecondary
        controllerDependencies.onError = function(message, detail) Report(message, detail) end
        controllerDependencies.getTemplates = adapters.getTemplates or controllerDependencies.getTemplates
        controllerDependencies.army = adapters.army or controllerDependencies.army
        controller = Controller(controllerDependencies)

        local function SetTab(name, checked)
            if destroyed or not controller then return false end
            local changed = false
            if checked ~= false then changed = controller:SetTab(name) end
            -- The controller retains the last successfully rendered tab when a
            -- view update fails; use that to roll back Maui's eager checkbox.
            local active = controller.lastTab or controller.currentTab
            for _, tabName in ipairs({ 'construction', 'selection', 'enhancement' }) do
                local tab = shell[tabName .. 'Tab']
                if tab and tab.SetCheck then tab:SetCheck(tabName == active, true) end
            end
            return changed
        end
        shell.constructionTab.OnCheck = function(_, checked) return SetTab('construction', checked) end
        shell.selectionTab.OnCheck = function(_, checked) return SetTab('selection', checked) end
        shell.enhancementTab.OnCheck = function(_, checked) return SetTab('enhancement', checked) end

        local function Refresh(controllerRef, rootRef)
            if type(adapters.refresh) == 'function' then return adapters.refresh(controllerRef, rootRef) end
            if type(adapters.getSelection) ~= 'function' then return false end
            local okSelection, selection = pcall(adapters.getSelection)
            if not okSelection then Report('selection refresh adapter failed', selection); return false end
            return rootRef:OnSelectionChanged(selection)
        end
        local dispatch = Facade(root, controller, {
            getBuildables = adapters.getBuildables,
            getCargo = adapters.getCargo,
            getQueue = adapters.getQueue,
            getCurrentTechTab = adapters.getCurrentTechTab,
            setHotKeys = adapters.setHotKeys,
            refresh = Refresh,
            getHandler = adapters.getHandler,
            onError = function(message, detail) Report(message, detail) end,
        })
        if dispatch ~= root then error('construction facade did not preserve root identity') end
        facadeRoot = dispatch
    end)

    panel = {
        root = root,
        controls = shell,
        controller = controller,
        primaryItems = primaryItems,
        secondaryItems = secondaryItems,
        cargoView = cargoView,
        destroyed = false,
    }

    local function CleanupChildren(externalDestroy)
        if destroying then return false end
        destroying = true
        if controller and type(controller.Destroy) == 'function' then
            local okDestroy, result = pcall(controller.Destroy, controller)
            if not okDestroy or result == false then
                Report(externalDestroy and 'root is being destroyed with cargo cleanup incomplete'
                    or 'panel destruction deferred until cargo cleanup succeeds', result)
                if not externalDestroy then destroying = false; return false end
            end
        end
        if facadeRoot and facadeRoot.ClaretConstructionFacade then
            pcall(facadeRoot.ClaretConstructionFacade.Destroy, facadeRoot.ClaretConstructionFacade)
        end
        if cargoView and type(cargoView.Destroy) == 'function' then pcall(cargoView.Destroy, cargoView) end
        if secondaryItems and type(secondaryItems.Destroy) == 'function' then
            local okDestroy, result = pcall(secondaryItems.Destroy, secondaryItems, {})
            if not okDestroy or result == false then Report('secondary renderer cleanup incomplete', result) end
        end
        if primaryItems and type(primaryItems.Destroy) == 'function' then
            local okDestroy, result = pcall(primaryItems.Destroy, primaryItems, {})
            if not okDestroy or result == false then Report('primary renderer cleanup incomplete', result) end
        end
        if rootDestroying then
            shell.root, shell.constructionGroup = nil, nil
        else
            pcall(shell.Destroy, shell)
        end
        panel.destroyed = true
        panel.root = nil
        destroyed = true
        destroying = false
        return true
    end

    function panel:Destroy()
        if self.destroyed then return true end
        if not CleanupChildren(false) then return false end
        return self.destroyed
    end

    function panel:SetLayout(layout)
        if self.destroyed or not shell.SetTabLayout then return false end
        return shell:SetTabLayout(layout)
    end

    if not ok then
        Report('construction panel assembly failed', err)
        if controller and controller.Destroy then pcall(controller.Destroy, controller) end
        if cargoView and cargoView.Destroy then pcall(cargoView.Destroy, cargoView) end
        if secondaryItems and secondaryItems.Destroy then pcall(secondaryItems.Destroy, secondaryItems, {}) end
        if primaryItems and primaryItems.Destroy then pcall(primaryItems.Destroy, primaryItems, {}) end
        pcall(shell.Destroy, shell)
        return nil, tostring(err)
    end

    local previousOnDestroy = root.OnDestroy
    root.OnDestroy = function(self, ...)
        if not panel.destroyed and not destroying then
            rootDestroying = true
            CleanupChildren(true)
        end
        if type(previousOnDestroy) == 'function' then return previousOnDestroy(self, ...) end
    end

    return panel
end
