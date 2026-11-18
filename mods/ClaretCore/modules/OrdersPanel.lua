-- Original unregistered coordinator for Claret's independent orders panel.
-- Dependencies are imported only during Create; this module installs no hooks.
-- Create(parent, options) expects injected action operations and shell UI options.
-- Refresh(selection, availableOrders, availableToggles, states, blueprints, access)
-- uses parallel selection/blueprint arrays (blueprints may be nil). Click(row, mods)
-- dispatches only the current enabled row against the captured unit identities.

local modulePaths = {
    catalog = '/mods/ClaretCore/modules/OrdersCatalog.lua',
    overrides = '/mods/ClaretCore/modules/OrdersOverrides.lua',
    model = '/mods/ClaretCore/modules/OrdersPanelModel.lua',
    shell = '/mods/ClaretCore/modules/OrdersPanelShell.lua',
    actions = '/mods/ClaretCore/modules/OrdersActions.lua',
}

local function LoadModule(options, key)
    local module = options.modules and options.modules[key]
    if not module then module = import(modulePaths[key]) end
    if type(module) ~= 'table' or type(module.Create) ~= 'function' then
        return nil, 'invalid ' .. key .. ' module'
    end
    return module
end

local function CopyDense(source, label, allowNil)
    if source == nil and allowNil then return nil end
    if type(source) ~= 'table' then return nil, label .. ' must be an array' end
    local count = table.getn(source)
    for key in pairs(source) do
        if type(key) ~= 'number' or key < 1 or key > count or key ~= math.floor(key) then
            return nil, label .. ' must be a dense array'
        end
    end
    local copy = {}
    for index = 1, count do
        if source[index] == nil then return nil, label .. ' contains a nil entry' end
        copy[index] = source[index]
    end
    return copy
end

local function AddDiagnostics(target, diagnostics, source)
    for _, item in ipairs(diagnostics or {}) do
        local entry = {}
        for key, value in pairs(item) do entry[key] = value end
        entry.source = source
        table.insert(target, entry)
    end
end

function Create(parent, options)
    options = options or {}
    if type(parent) ~= 'table' and type(parent) ~= 'userdata' then
        return nil, 'panel parent control is required'
    end
    if type(options.actionOps) ~= 'table' then return nil, 'actionOps are required' end

    local modules = {}
    for _, key in ipairs({ 'catalog', 'overrides', 'model', 'shell', 'actions' }) do
        local module, moduleError = LoadModule(options, key)
        if not module then return nil, moduleError end
        modules[key] = module
    end

    local ok, catalog = pcall(modules.catalog.Create)
    if not ok or type(catalog) ~= 'table' then return nil, 'catalog creation failed: ' .. tostring(catalog) end
    for _, extension in ipairs(options.extensions or {}) do
        if type(extension) ~= 'table' or type(extension.id) ~= 'string' or type(extension.definition) ~= 'table' then
            return nil, 'extension entry is malformed'
        end
        local registered, registerError = catalog:RegisterExtension(extension.id, extension.definition)
        if not registered then return nil, registerError end
    end

    local definitions = catalog:GetDefinitions()
    local behaviorWhitelist = options.behaviorWhitelist or {}
    local overridesOk, overrides = pcall(modules.overrides.Create, {
        definitions = definitions,
        behaviorWhitelist = behaviorWhitelist,
    })
    if not overridesOk or type(overrides) ~= 'table' then
        return nil, 'override resolver creation failed: ' .. tostring(overrides)
    end
    local modelOk, model = pcall(modules.model.Create, {
        definitions = definitions,
        commonOrder = catalog:GetCommonIds(),
        firstAltSlot = options.firstAltSlot or 8,
        totalSlots = options.totalSlots or 14,
    })
    if not modelOk or type(model) ~= 'table' then return nil, 'panel model creation failed: ' .. tostring(model) end
    local actionsOk, actions = pcall(modules.actions.Create, options.actionOps)
    if not actionsOk or type(actions) ~= 'table' then return nil, 'action dispatcher creation failed: ' .. tostring(actions) end

    local state = {
        destroyed = false,
        selection = nil,
        access = nil,
        diagnostics = {},
        items = {},
    }
    local controller = {}
    local shellCallbacks = {
        onClick = function(row, modifiers)
            return controller:Click(row, modifiers)
        end,
        onHover = options.onHover,
    }
    local shellOptions = options.shellOptions or {}
    local shellOk, shell = pcall(modules.shell.Create, parent, shellCallbacks, shellOptions)
    if not shellOk or type(shell) ~= 'table' then
        return nil, 'panel shell creation failed: ' .. tostring(shell)
    end
    state.shell = shell

    local function ClearCurrent()
        state.selection = nil
        state.access = nil
        state.items = {}
        if not state.destroyed and state.shell and state.shell.SetOrders then
            pcall(state.shell.SetOrders, state.shell, {})
        end
    end

    function controller:Refresh(selection, availableOrders, availableToggles, states, blueprints, access)
        if state.destroyed then return false, 'orders panel is destroyed' end
        local copiedSelection, selectionError = CopyDense(selection, 'selection', false)
        if not copiedSelection then
            ClearCurrent()
            state.diagnostics = { { source = 'refresh', reason = selectionError } }
            return false, state.diagnostics
        end
        local copiedOrders, ordersError = CopyDense(availableOrders, 'availableOrders', false)
        local copiedToggles, togglesError = CopyDense(availableToggles, 'availableToggles', false)
        local copiedBlueprints, blueprintError = CopyDense(blueprints, 'blueprints', true)
        if not copiedOrders or not copiedToggles or (blueprints ~= nil and not copiedBlueprints) then
            ClearCurrent()
            local reason = ordersError or togglesError or blueprintError
            state.diagnostics = { { source = 'refresh', reason = reason } }
            return false, state.diagnostics
        end
        if copiedBlueprints and table.getn(copiedBlueprints) ~= table.getn(copiedSelection) then
            ClearCurrent()
            state.diagnostics = { { source = 'refresh', reason = 'blueprint count must match selection count' } }
            return false, state.diagnostics
        end
        if type(states) ~= 'table' then
            ClearCurrent()
            state.diagnostics = { { source = 'refresh', reason = 'checkbox states must be a table' } }
            return false, state.diagnostics
        end
        if type(access) ~= 'table' then
            ClearCurrent()
            state.diagnostics = { { source = 'refresh', reason = 'explicit access state is required' } }
            return false, state.diagnostics
        end
        for _, key in ipairs({ 'replay', 'observer', 'readOnly' }) do
            if type(access[key]) ~= 'boolean' then
                ClearCurrent()
                state.diagnostics = { { source = 'refresh', reason = 'access.' .. key .. ' must be boolean' } }
                return false, state.diagnostics
            end
        end

        local resolved = overrides:Resolve(copiedBlueprints)
        local diagnostics = {}
        AddDiagnostics(diagnostics, resolved.diagnostics, 'overrides')
        if not resolved.valid then
            ClearCurrent()
            state.diagnostics = diagnostics
            return false, diagnostics
        end
        local snapshot = {
            availableOrders = copiedOrders,
            availableToggles = copiedToggles,
            checkboxStates = states,
            blueprintOverrides = resolved.displayOverrides,
            replay = access.replay,
            readOnly = access.readOnly or access.replay or access.observer,
        }
        local modelOk, modelError = model:SetSnapshot(snapshot)
        if not modelOk then
            ClearCurrent()
            table.insert(diagnostics, { source = 'model', reason = modelError })
            state.diagnostics = diagnostics
            return false, diagnostics
        end

        local items = model:GetItems()
        for _, item in ipairs(items) do
            local behaviorKey = item.source and item.source.behaviorKey
            if not actions:IsBehaviorSupported(behaviorKey) then item.disabled = true end
        end
        local setOk, setError = pcall(shell.SetOrders, shell, items)
        if not setOk or setError == false then
            ClearCurrent()
            table.insert(diagnostics, { source = 'shell', reason = setOk and 'SetOrders rejected items' or setError })
            state.diagnostics = diagnostics
            return false, diagnostics
        end
        local unknown = model:GetUnknown()
        AddDiagnostics(diagnostics, unknown, 'model')
        state.selection = copiedSelection
        state.access = {
            replay = access.replay, observer = access.observer, readOnly = access.readOnly,
        }
        state.items = items
        state.diagnostics = diagnostics
        return true, { items = items, diagnostics = diagnostics }
    end

    function controller:Click(row, modifiers)
        if state.destroyed then return false, 'orders panel is destroyed' end
        if not state.selection then return false, 'orders panel has no current live selection snapshot' end
        if type(row) ~= 'table' or type(row.id) ~= 'string' then return false, 'order row is malformed' end
        local current = model:GetById(row.id)
        if current ~= row then return false, 'order row is stale' end
        if row.disabled or state.access.readOnly or state.access.replay or state.access.observer then
            return false, 'order row is disabled or current access is read-only'
        end
        local okDispatch, result, detail = pcall(actions.Dispatch, actions, row, state.selection, modifiers)
        if not okDispatch then return false, result end
        return result, detail
    end

    function controller:GetDiagnostics()
        return state.diagnostics
    end

    function controller:GetItems()
        return state.items
    end

    function controller:GetControls()
        return shell
    end

    function controller:Destroy()
        if state.destroyed then return true end
        local destroyOk, destroyResult, destroyError = pcall(shell.Destroy, shell)
        if not destroyOk or destroyResult == false then
            return false, destroyOk and (destroyError or 'shell destroy rejected') or destroyResult
        end
        state.destroyed = true
        state.selection = nil
        state.items = {}
        return true
    end

    return controller
end
