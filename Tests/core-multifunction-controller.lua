-- Callback controller tests with injected FAF API shapes; no native APIs run.
local module = setmetatable({}, { __index = _G })
assert(loadfile('../mods/ClaretCore/modules/MultifunctionController.lua', 't', module))()

local calls = {}
local minimapEnabled = false
local collapsed = false
local subscribed = nil
local function record(name, value) table.insert(calls, { name = name, value = value }) end
local operations = {
    subscribeEndBehavior = function(callback, identifier)
        record('subscribe', identifier)
        subscribed = callback
        return function()
            record('unsubscribe', identifier)
            if subscribed == callback then subscribed = nil end
        end
    end,
    startCommandMode = function(mode, data) record('startCommandMode', { mode = mode, data = data }) end,
    doPing = function(pingtype) record('doPing', pingtype) end,
    renderOverlayEconomy = function(checked) record('economy', checked) end,
    setActiveOverlays = function() record('activeOverlays') end,
    setOverlayFilters = function(filters) record('overlayFilters', filters) end,
    getMinimapState = function() return minimapEnabled end,
    toggleMinimap = function()
        record('toggleMinimap')
        minimapEnabled = not minimapEnabled
    end,
    isCollapsed = function() return collapsed end,
    toggleMfdPanel = function(forceOpen)
        record('toggleMfdPanel', forceOpen)
        if forceOpen == true then collapsed = false else collapsed = not collapsed end
    end,
}

local controller = module.Create({ operations = operations })
assert(#calls == 0 and not controller.installed,
    'Create is inert and does not subscribe, change overlays, read/write prefs, or toggle UI')
assert(controller.callbacks.onPing == controller.onPing
    and controller.callbacks.onOverlay == controller.onOverlay
    and controller.callbacks.onCollapse == controller.onCollapse
    and controller.callbacks.onMinimapToggle == controller.onMinimapToggle)
assert(controller.Install() and controller.installed and subscribed == controller.GetEndBehavior())
assert(calls[1].name == 'subscribe')

local ping = { id = 'move', cursor = 'RULEUCC_Move' }
assert(controller.callbacks.onPing(ping))
local started = calls[#calls]
assert(started.name == 'startCommandMode' and started.value.mode == 'ping')
assert(started.value.data.cursor == 'RULEUCC_Move' and started.value.data.pingtype == 'move'
    and started.value.data.pingLocation == true,
    'ping cursor/type and native pingLocation command-mode data are preserved')

local endBehavior = subscribed
assert(not endBehavior('ping', { pingtype = 'move', pingLocation = false }))
assert(not endBehavior('order', { pingtype = 'move', pingLocation = true }))
assert(not endBehavior('ping', { pingtype = 'move', pingLocation = true, isCancel = true }))
assert(not endBehavior('ping', { pingtype = 'move', pingLocation = true, isCancel = 'uncertain' }))
assert(not endBehavior('ping', { pingLocation = true }))
assert(endBehavior('ping', { pingtype = 'move', pingLocation = { x = 120, y = 240 }, isCancel = false }))
assert(calls[#calls].name == 'doPing' and calls[#calls].value == 'move')
local pingCount = 0
for _, call in ipairs(calls) do if call.name == 'doPing' then pingCount = pingCount + 1 end end
assert(pingCount == 1, 'only completed ping-location command modes send one ping')

assert(controller.callbacks.onOverlay({ id = 'economy' }, true))
assert(calls[#calls].name == 'economy' and calls[#calls].value == true)
assert(controller.callbacks.onOverlay({ id = 'military' }, true))
assert(calls[#calls].name == 'activeOverlays')
assert(controller.callbacks.onOverlay({ id = 'military' }, false))
assert(calls[#calls].name == 'overlayFilters' and next(calls[#calls].value) == nil)
local unsupportedBefore = #calls
assert(not controller.callbacks.onOverlay({ id = 'teamcolor' }, true))
assert(#calls == unsupportedBefore, 'unsupported overlay does not trigger guessed behavior')

assert(controller.callbacks.onMinimapToggle(false) and minimapEnabled == false)
local minimapCalls = 0
for _, call in ipairs(calls) do if call.name == 'toggleMinimap' then minimapCalls = minimapCalls + 1 end end
assert(minimapCalls == 0, 'requesting current minimap state does not toggle it')
assert(controller.callbacks.onMinimapToggle(true) and minimapEnabled == true)
assert(controller.callbacks.onMinimapToggle(true) and minimapEnabled == true)
local afterMinimapCalls = 0
for _, call in ipairs(calls) do if call.name == 'toggleMinimap' then afterMinimapCalls = afterMinimapCalls + 1 end end
assert(afterMinimapCalls == 1, 'repeated target-state request avoids duplicate toggle')

assert(controller.callbacks.onCollapse(false) and collapsed == false)
assert(controller.callbacks.onCollapse(true) and collapsed == true)
assert(controller.callbacks.onCollapse(true) and collapsed == true)
assert(controller.callbacks.onCollapse(false) and collapsed == false)
local collapseCalls = {}
for _, call in ipairs(calls) do if call.name == 'toggleMfdPanel' then table.insert(collapseCalls, call) end end
assert(#collapseCalls == 2 and collapseCalls[1].value == nil and collapseCalls[2].value == true,
    'collapse operations are idempotent and use native ToggleMFDPanel semantics')

local beforeReadOnly = #calls
assert(controller.SetAccess({ readOnly = true }))
assert(not controller.callbacks.onPing(ping), 'read-only mode blocks command-mode pings')
assert(controller.callbacks.onOverlay({ id = 'economy' }, false)
    and controller.callbacks.onMinimapToggle(false)
    and controller.callbacks.onCollapse(true))
assert(#calls == beforeReadOnly + 3,
    'read-only mode retains native UI-only overlay, minimap and collapse actions')
assert(controller.SetAccess({ readOnly = false, replay = true }))
assert(not controller.callbacks.onPing(ping) and controller.callbacks.onOverlay({ id = 'military' }, true)
    and controller.callbacks.onCollapse(false) and controller.callbacks.onMinimapToggle(true),
    'replay disables pings while retaining native overlay/minimap/collapse controls')
assert(controller.SetAccess({ replay = false }))

local oldHandler = subscribed
controller.Destroy()
assert(controller.destroyed and not controller.installed and subscribed == nil)
assert(calls[#calls].name == 'unsubscribe' and controller.subscriptionState == 'unsubscribed')
local afterDestroy = #calls
assert(not controller.callbacks.onPing(ping)
    and not oldHandler('ping', { pingtype = 'move', pingLocation = true }))
assert(#calls == afterDestroy, 'destroyed callback closures are inert')
controller.Destroy()

local registry = {}
local keyedOps = {
    addEndBehavior = function(callback, identifier) registry[identifier] = callback end,
    getEndBehavior = function(identifier) return registry[identifier] end,
    doPing = function(value) record('keyedPing', value) end,
}
local keyed = module.Create({ operations = keyedOps, identifier = 'Claret.MFD.Test.Key' })
assert(keyed.Install() and type(registry[keyed.identifier]) == 'function')
local installedHandler = registry[keyed.identifier]
keyed.Destroy()
assert(registry[keyed.identifier] ~= installedHandler and keyed.subscriptionState == 'replaced-with-inert')
assert(registry[keyed.identifier]('ping', { pingtype = 'alert', pingLocation = true }) == nil)

local takeover = module.Create({ operations = keyedOps, identifier = 'Claret.MFD.Takeover.Key' })
assert(takeover.Install())
local takeoverHandler = registry[takeover.identifier]
local thirdPartyHandler = function() record('thirdPartyHandler') end
registry[takeover.identifier] = thirdPartyHandler
takeover.Destroy()
assert(registry[takeover.identifier] == thirdPartyHandler
    and takeover.subscriptionState == 'inactive-registration-retained',
    'teardown leaves a later owner intact when keyed ownership was taken over')
assert(takeoverHandler('ping', { pingtype = 'move', pingLocation = true }) == false,
    'displaced local handler is inactive after teardown')

local nonremovableRegistry = {}
local nonremovable = module.Create({ operations = {
    addEndBehavior = function(callback, identifier) nonremovableRegistry[identifier] = callback end,
    doPing = function(value) record('nonremovablePing', value) end,
} })
assert(nonremovable.Install())
local retainedHandler = nonremovableRegistry[nonremovable.identifier]
nonremovable.Destroy()
assert(nonremovable.subscriptionState == 'inactive-registration-retained'
    and nonremovableRegistry[nonremovable.identifier] == retainedHandler)
assert(not retainedHandler('ping', { pingtype = 'move', pingLocation = true }),
    'FAF-style nonremovable end-behavior registration remains safely inert')

local replayController = module.Create({ operations = operations, replay = true })
local beforeReplayInstall = #calls
local replayInstall = replayController.Install()
assert(replayInstall and #calls == beforeReplayInstall + 1 and replayController.installed)
assert(not replayController.callbacks.onPing(ping), 'installed replay controller still rejects ping initiation')
replayController.Destroy()
print('PASS: multifunction controller ping lifecycle, overlays, idempotent toggles and access gates')
