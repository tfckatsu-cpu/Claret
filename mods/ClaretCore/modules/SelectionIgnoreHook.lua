-- Explicit, unregistered adapter for replacing a module table's setter with the
-- ownership-aware SelectionIgnoreScope manager. Install only after the caller has
-- verified the initial external state and before selection callbacks begin.

local installedModules = {}

function Create(moduleTable, knownInitialExternalValue)
    if type(moduleTable) ~= 'table' then return nil, 'module table is required' end
    if type(knownInitialExternalValue) ~= 'boolean' then
        return nil, 'known initial external ignore state is required'
    end
    if installedModules[moduleTable] then return nil, 'ignore setter adapter is already installed' end
    local originalSetter = moduleTable.SetIgnoreSelection
    if type(originalSetter) ~= 'function' then return nil, 'module has no SetIgnoreSelection function' end

    local imported, scopeModule = pcall(import, '/mods/ClaretCore/modules/SelectionIgnoreScope.lua')
    if not imported or type(scopeModule) ~= 'table' or type(scopeModule.Create) ~= 'function' then
        return nil, 'SelectionIgnoreScope module is unavailable'
    end
    local okCreate, manager, createError = pcall(scopeModule.Create,
        originalSetter, knownInitialExternalValue)
    if not okCreate or type(manager) ~= 'table' then
        return nil, okCreate and createError or manager
    end

    local adapter = { originalSetter = originalSetter }
    local wrapper
    local function IsCurrent()
        return moduleTable.SetIgnoreSelection == wrapper
    end

    wrapper = function(value)
        -- Another mod may wrap this callback and leave it reachable through its
        -- own setter. Keep forwarding those calls; only ownership operations and
        -- teardown require us to still be the module's current setter.
        return manager.SetIgnoreSelection(value)
    end
    moduleTable.SetIgnoreSelection = wrapper
    installedModules[moduleTable] = adapter

    function adapter.AcquireIgnoreSelectionScope()
        if not IsCurrent() then return nil, 'ignore setter was replaced by another owner' end
        return manager.AcquireIgnoreSelectionScope()
    end

    function adapter.ReleaseIgnoreSelectionScope(token)
        if not IsCurrent() then return false, 'ignore setter was replaced by another owner' end
        return manager.ReleaseIgnoreSelectionScope(token)
    end

    function adapter.GetState()
        return manager.GetState()
    end

    function adapter.Destroy()
        if not IsCurrent() then
            return false, 'another owner replaced or wrapped the ignore setter; safe detach is unavailable'
        end
        local okDestroy, destroyError = manager.Destroy()
        if not okDestroy then return false, destroyError end
        if not IsCurrent() then
            return false, 'ignore setter changed during cleanup; replacement was left intact'
        end
        moduleTable.SetIgnoreSelection = originalSetter
        installedModules[moduleTable] = nil
        return true
    end

    return adapter
end
