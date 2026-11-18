-- Callback-only controller for an independent multifunction panel.
-- Install is explicit; construction does not touch game state or preferences.

local instanceCounter = 0

function Create(options)
    options = options or {}
    local operations = options.operations or {}
    if type(operations) ~= 'table' then error('multifunction operations must be a table') end

    instanceCounter = instanceCounter + 1
    local identifier = options.identifier or ('ClaretCore.MultifunctionController.PingEnd.' .. instanceCounter)
    local controller = {
        readOnly = options.readOnly == true,
        replay = options.replay == true,
        identifier = identifier,
        installed = false,
        destroyed = false,
        subscriptionState = 'not-installed',
    }
    local active = false
    local endBehavior = false
    local unsubscribe = false

    local function CanUseUI()
        return active and not controller.destroyed
    end

    local function CanPing()
        return CanUseUI() and not controller.readOnly and not controller.replay
    end

    local function EndBehavior(mode, data)
        if not CanPing() or mode ~= 'ping' or type(data) ~= 'table'
            or not data.pingLocation or data.isCancel == true
            or (data.isCancel ~= nil and type(data.isCancel) ~= 'boolean')
            or type(data.pingtype) ~= 'string' or data.pingtype == '' then
            return false
        end
        if type(operations.doPing) ~= 'function' then return false end
        operations.doPing(data.pingtype)
        return true
    end
    endBehavior = EndBehavior

    function controller.Install()
        if controller.destroyed then return false, 'controller has been destroyed' end
        if controller.installed then return true end
        if type(operations.addEndBehavior) ~= 'function'
            and type(operations.subscribeEndBehavior) ~= 'function' then
            return false, 'an end-behavior subscription operation is required'
        end

        if type(operations.subscribeEndBehavior) == 'function' then
            local token = operations.subscribeEndBehavior(endBehavior, identifier)
            if type(token) == 'function' then
                unsubscribe = token
            elseif type(token) == 'table' and type(token.unsubscribe) == 'function' then
                unsubscribe = function() token:unsubscribe() end
            elseif type(operations.removeEndBehavior) == 'function' then
                unsubscribe = function() operations.removeEndBehavior(identifier, endBehavior) end
            else
                unsubscribe = false
            end
            controller.subscriptionState = unsubscribe and 'removable-subscription' or 'guarded-subscription'
        else
            operations.addEndBehavior(endBehavior, identifier)
            controller.subscriptionState = 'keyed-nonremovable'
            unsubscribe = false
        end
        active = true
        controller.installed = true
        return true
    end

    function controller.SetAccess(access)
        if type(access) ~= 'table' then return false, 'access flags must be a table' end
        if access.readOnly ~= nil and type(access.readOnly) ~= 'boolean' then
            return false, 'readOnly must be boolean'
        end
        if access.replay ~= nil and type(access.replay) ~= 'boolean' then
            return false, 'replay must be boolean'
        end
        if access.readOnly ~= nil then controller.readOnly = access.readOnly end
        if access.replay ~= nil then controller.replay = access.replay end
        return true
    end

    function controller.onPing(definition)
        if not CanPing() then return false end
        if type(definition) ~= 'table' or type(definition.id) ~= 'string' or definition.id == ''
            or type(definition.cursor) ~= 'string' or definition.cursor == ''
            or type(operations.startCommandMode) ~= 'function' then
            return false
        end
        operations.startCommandMode('ping', {
            cursor = definition.cursor,
            pingtype = definition.id,
            pingLocation = true,
        })
        return true
    end

    function controller.onOverlay(definition, checked, _, control)
        if not CanUseUI() or type(definition) ~= 'table' or type(checked) ~= 'boolean' then return false end
        local id = definition.id
        if id == 'economy' then
            if type(operations.renderOverlayEconomy) ~= 'function' then return false end
            operations.renderOverlayEconomy(checked)
            return true
        elseif id == 'military' then
            if checked then
                if type(operations.setActiveOverlays) ~= 'function' then return false end
                operations.setActiveOverlays()
            else
                if type(operations.setOverlayFilters) ~= 'function' then return false end
                operations.setOverlayFilters({})
            end
            return true
        end
        -- Map-options dropdown and team-color behavior require separate native
        -- adapters; do not approximate them with unrelated overlay operations.
        if type(operations.onUnsupportedOverlay) == 'function' then
            operations.onUnsupportedOverlay(definition, checked, control)
        end
        return false
    end

    function controller.onCollapse(collapsed)
        if not CanUseUI() or type(collapsed) ~= 'boolean' then return false end
        if type(operations.setCollapsed) == 'function' then
            operations.setCollapsed(collapsed)
            return true
        end
        if type(operations.isCollapsed) ~= 'function' or type(operations.toggleMfdPanel) ~= 'function' then
            return false
        end
        local current = operations.isCollapsed()
        if type(current) ~= 'boolean' then return false end
        if current == collapsed then return true end
        if collapsed then operations.toggleMfdPanel()
        else operations.toggleMfdPanel(true) end
        return true
    end

    function controller.onMinimapToggle(enabled)
        if not CanUseUI() or type(enabled) ~= 'boolean' then return false end
        if type(operations.setMinimapEnabled) == 'function' then
            operations.setMinimapEnabled(enabled)
            return true
        end
        if type(operations.getMinimapState) ~= 'function' or type(operations.toggleMinimap) ~= 'function' then
            return false
        end
        local current = operations.getMinimapState()
        if type(current) ~= 'boolean' then return false end
        if current == enabled then return true end
        operations.toggleMinimap()
        return operations.getMinimapState() == enabled
    end

    function controller.GetEndBehavior()
        return endBehavior
    end

    function controller.Destroy()
        if controller.destroyed then return end
        active = false
        controller.installed = false
        controller.destroyed = true
        if unsubscribe then
            unsubscribe()
            controller.subscriptionState = 'unsubscribed'
        elseif controller.subscriptionState == 'keyed-nonremovable' then
            if type(operations.getEndBehavior) == 'function'
                and operations.getEndBehavior(identifier) == endBehavior
                and type(operations.addEndBehavior) == 'function' then
                operations.addEndBehavior(function() end, identifier)
                controller.subscriptionState = 'replaced-with-inert'
            else
                -- FAF3840 AddEndBehavior has no RemoveEndBehavior or getter.
                -- The unique-keyed callback is left registered but deactivated;
                -- never overwrite an entry whose ownership cannot be verified.
                controller.subscriptionState = 'inactive-registration-retained'
            end
        elseif controller.subscriptionState == 'guarded-subscription' then
            controller.subscriptionState = 'inactive-subscription-retained'
        end
        unsubscribe = false
    end

    controller.callbacks = {
        onPing = controller.onPing,
        onOverlay = controller.onOverlay,
        onCollapse = controller.onCollapse,
        onMinimapToggle = controller.onMinimapToggle,
    }
    return controller
end
