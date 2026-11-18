-- Compatibility surface for ReUI.Construction's installed dispatch wrappers.
-- This attaches the surface to a caller-owned Maui control; it does not create,
-- destroy, hook, or otherwise own that control or the controller.

local TECH_TABS = { t1 = 1, t2 = 2, t3 = 3, t4 = 4 }

local function Call(object, method, ...)
    if type(object) ~= 'table' or type(object[method]) ~= 'function' then
        return false, 'method unavailable: ' .. tostring(method)
    end
    local ok, result = pcall(object[method], object, ...)
    if not ok then return false, result end
    return result ~= false, result
end

function Create(root, controller, operations)
    local rootType = type(root)
    if (rootType ~= 'table' and rootType ~= 'userdata') or type(controller) ~= 'table' then
        return nil, 'Maui root and controller required'
    end
    operations = operations or {}

    local destroyed = false
    local previous = {}
    local installed = {}
    local facade = {}

    local function Report(message, detail)
        if type(operations.onError) == 'function' then pcall(operations.onError, message, detail) end
    end

    local function Alive()
        if destroyed then return false end
        if type(IsDestroyed) == 'function' then
            local ok, value = pcall(IsDestroyed, root)
            if not ok or value then return false end
        end
        return true
    end

    local function InvokeController(method, ...)
        local ok, result = Call(controller, method, ...)
        if not ok then Report('construction controller call failed: ' .. method, result) end
        return ok, result
    end

    local function InvalidateControllerSelection()
        if type(controller.OnSelection) ~= 'function' then return false end
        local ok, result = pcall(controller.OnSelection, controller, nil, nil, nil)
        if not ok then Report('controller selection invalidation failed', result) end
        return ok
    end

    local function Install(name, callback)
        previous[name] = root[name]
        installed[name] = callback
        root[name] = callback
    end

    local function Restore()
        for name, callback in pairs(installed) do
            if root[name] == callback then root[name] = previous[name] end
            installed[name] = nil
            previous[name] = nil
        end
    end

    function facade:OnSelectionChanged(selection)
        if not Alive() then return false end
        if type(selection) ~= 'table' or type(operations.getBuildables) ~= 'function'
            or type(operations.getCargo) ~= 'function' then
            InvalidateControllerSelection()
            return false
        end
        local okBuildables, buildables = pcall(operations.getBuildables, selection)
        local okCargo, cargo = pcall(operations.getCargo, selection)
        if not okBuildables or type(buildables) ~= 'table'
            or not okCargo or type(cargo) ~= 'table' then
            Report('construction selection adapters failed', not okBuildables and buildables or cargo)
            InvalidateControllerSelection()
            return false
        end
        local ok, result = InvokeController('OnSelection', buildables, selection, cargo)
        return ok and result == true
    end

    function facade:Update(reason)
        if not Alive() then return false end
        if reason == 'queue' then
            if type(operations.getQueue) ~= 'function' then return false end
            local ok, queue = pcall(operations.getQueue)
            if not ok or type(queue) ~= 'table' then Report('construction queue adapter failed', queue); return false end
            local updated, result = InvokeController('OnQueueChanged', queue)
            return updated and result == true
        end
        if reason == nil or reason == 'refresh' then
            if type(operations.refresh) ~= 'function' then return false end
            local ok, result = pcall(operations.refresh, controller, root)
            if not ok then Report('construction refresh adapter failed', result); return false end
            return result ~= false
        end
        if type(operations.update) ~= 'function' then return false end
        local ok, result = pcall(operations.update, reason, controller, root)
        if not ok then Report('construction update adapter failed', result); return false end
        return result ~= false
    end

    function facade:Refresh()
        return self:Update('refresh')
    end

    function facade:GetCurrentTechTab()
        if not Alive() then return 0 end
        if type(operations.getCurrentTechTab) == 'function' then
            local ok, value = pcall(operations.getCurrentTechTab, controller)
            if ok and type(value) == 'number' then return value end
            Report('construction tech tab adapter failed', value)
            return 0
        end
        return TECH_TABS[controller.techTab] or 0
    end

    function facade:GetHandler(name)
        if not Alive() then return nil end
        if name == 'TransportCargo' then return facade.handlers.TransportCargo end
        if name == 'BuildOptions' or name == 'BuildOptionsFactory' then return facade.handlers[name] end
        if type(operations.getHandler) == 'function' then
            local ok, handler = pcall(operations.getHandler, name, controller)
            if ok then return handler end
            Report('construction handler adapter failed', handler)
        end
        return nil
    end

    facade.handlers = {
        TransportCargo = {
            AppendNextUnitForDrop = function()
                if not Alive() then return false end
                local ok, result = InvokeController('AppendCargo')
                return ok and result == true
            end,
        },
    }
    local function SetHotKeys(kind, relations, upgradeKey)
        if not Alive() or type(operations.setHotKeys) ~= 'function' then return false end
        local ok, result = pcall(operations.setHotKeys, kind, relations, upgradeKey, controller)
        if not ok then Report('construction hotkey adapter failed', result); return false end
        return result ~= false
    end
    facade.handlers.BuildOptions = { SetHotKeys = function(_, relations, upgradeKey) return SetHotKeys('BuildOptions', relations, upgradeKey) end }
    facade.handlers.BuildOptionsFactory = { SetHotKeys = function(_, relations, upgradeKey) return SetHotKeys('BuildOptionsFactory', relations, upgradeKey) end }

    local oldShow, oldHide = root.Show, root.Hide
    Install('OnSelectionChanged', function(_, selection) return facade:OnSelectionChanged(selection) end)
    Install('Update', function(_, reason) return facade:Update(reason) end)
    Install('Refresh', function() return facade:Refresh() end)
    Install('GetCurrentTechTab', function() return facade:GetCurrentTechTab() end)
    Install('GetHandler', function(_, name) return facade:GetHandler(name) end)
    Install('Show', function(self, ...)
        if not Alive() then return end
        if type(oldShow) == 'function' then return oldShow(self, ...) end
    end)
    Install('Hide', function(self, ...)
        if not Alive() then return end
        if type(oldHide) == 'function' then return oldHide(self, ...) end
    end)

    local oldOnDestroy = root.OnDestroy
    Install('OnDestroy', function(self, ...)
        facade:Destroy()
        if type(oldOnDestroy) == 'function' then return oldOnDestroy(self, ...) end
    end)
    local oldDestroy = root.Destroy
    Install('Destroy', function(self, ...)
        facade:Destroy()
        if type(oldDestroy) == 'function' then return oldDestroy(self, ...) end
    end)

    function facade:Destroy()
        if destroyed then return false end
        destroyed = true
        Restore()
        if root.ClaretConstructionFacade == self then root.ClaretConstructionFacade = nil end
        self.handlers = nil
        return true
    end

    -- ReUI's IsDestroyed/layout code must receive the actual Maui control.
    -- The facade is retained as a named handle for explicit caller teardown.
    root.ClaretConstructionFacade = facade
    return root
end
