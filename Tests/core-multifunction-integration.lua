-- Integration of real multifunction shell/controller with mocked FAF controls.
local function prop()
    local value = {}
    function value:Set(nextValue) self.value = nextValue end
    return value
end
local function control(kind, parent)
    local item = {
        kind = kind, parent = parent, children = {}, destroyed = false,
        Width = prop(), Height = prop(), Left = prop(), Right = prop(), Top = prop(), Bottom = prop(), Depth = prop(),
    }
    if parent and parent.children then table.insert(parent.children, item) end
    function item:SetTexture(value) self.texture = value end
    function item:SetNewTextures(...) self.textures = { ... } end
    function item:SetCheck(value, silent) self.checked, self.silent = value, silent end
    function item:Disable() self.disabled = true end
    function item:Enable() self.disabled = false end
    function item:DisableHitTest() self.hitTestDisabled = true end
    function item:Destroy()
        self.destroyed = true
        if self.parent and self.parent.children then
            for index, child in ipairs(self.parent.children) do
                if child == self then table.remove(self.parent.children, index); break end
            end
        end
    end
    return item
end
local created = {}
local function factory(kind)
    return function(parent)
        local item = control(kind, parent)
        table.insert(created, item)
        return item
    end
end
local factories = {
    group = factory('group'), bitmap = factory('bitmap'), checkbox = factory('checkbox'), button = factory('button'),
    createButtonStd = function(parent, path, ...)
        local item = control('button', parent)
        item.stockButtonPath = path
        table.insert(created, item)
        return item
    end,
}
local layout = {}
for _, method in ipairs({ 'AtLeftTopIn', 'AnchorToLeft', 'AtTopIn', 'AtLeftIn', 'AnchorToRight', 'AtBottomIn', 'AtLeftBottomIn', 'RightOf' }) do
    layout[method] = function(...) end
end
local uiUtil = {
    UIFile = function(path) return 'ui:' .. path end,
    SkinnableFile = function(path) return 'skin:' .. path end,
}
local tooltips = {
    AddCheckboxTooltip = function(button, key) button.tooltip = key end,
    AddButtonTooltip = function(button, key) button.tooltip = key end,
}
local function loadModule(path)
    local env = setmetatable({
        import = function(name) error('unexpected import: ' .. name) end,
        GetFrame = function() return control('frame') end,
        unpack = unpack or table.unpack,
    }, { __index = _G })
    assert(loadfile(path, 't', env))()
    return env
end

local shellModule = loadModule('../mods/ClaretCore/modules/MultifunctionShell.lua')
local controllerModule = loadModule('../mods/ClaretCore/modules/MultifunctionController.lua')
local calls = {}
local function record(name, value) table.insert(calls, { name = name, value = value }) end
local minimapEnabled, collapsed = false, false
local endHandler
local operations = {
    subscribeEndBehavior = function(callback, identifier)
        record('subscribe', identifier)
        endHandler = callback
        return function()
            record('unsubscribe', identifier)
            if endHandler == callback then endHandler = nil end
        end
    end,
    startCommandMode = function(mode, data) record('commandMode', { mode = mode, data = data }) end,
    doPing = function(pingType) record('ping', pingType) end,
    renderOverlayEconomy = function(enabled) record('economy', enabled) end,
    setActiveOverlays = function() record('activateMilitary') end,
    setOverlayFilters = function(filters) record('clearMilitary', filters) end,
    getMinimapState = function() return minimapEnabled end,
    toggleMinimap = function() minimapEnabled = not minimapEnabled; record('minimapToggle', minimapEnabled) end,
    isCollapsed = function() return collapsed end,
    toggleMfdPanel = function(open)
        if open == true then collapsed = false else collapsed = not collapsed end
        record('collapseToggle', open)
    end,
}

local controller = controllerModule.Create({ operations = operations })
local sharedCluster = control('shared-control-cluster')
local shell = shellModule.Create(sharedCluster, controller.callbacks, {
    factories = factories,
    uiUtil = uiUtil,
    tooltip = tooltips,
    layoutHelpers = layout,
})
assert(#calls == 0 and not controller.installed,
    'constructing shell/controller performs no command, overlay, minimap, preference, or subscription side effect')
assert(shell.pingButtons[1].kind == 'button' and shell.overlayButtons[1].kind == 'checkbox')
assert(shell.pingButtons[1].stockButtonPath == '/game/mfd_btn/ping-alert')
assert(controller.Install() and endHandler == controller.GetEndBehavior())

local function check(button, checked)
    button:SetCheck(checked)
    button.OnCheck(button, checked)
end
check(shell.overlayButtons[3], true)
assert(shell.overlayButtons[3].checked and calls[#calls].name == 'economy' and calls[#calls].value)
check(shell.overlayButtons[4], true)
assert(shell.overlayButtons[4].checked and calls[#calls].name == 'activateMilitary')
check(shell.overlayButtons[4], false)
assert(not shell.overlayButtons[4].checked and calls[#calls].name == 'clearMilitary'
    and next(calls[#calls].value) == nil)

local pingButton = shell.pingButtons[1]
pingButton.OnClick(pingButton, { Shift = true })
local commandMode = calls[#calls]
assert(commandMode.name == 'commandMode' and commandMode.value.mode == 'ping'
    and commandMode.value.data.cursor == 'RULEUCC_Guard'
    and commandMode.value.data.pingtype == 'alert'
    and commandMode.value.data.pingLocation == true,
    'shell ping definition feeds native command mode cursor and type')
assert(endHandler('ping', { pingtype = 'alert', pingLocation = { x = 100, y = 200 }, isCancel = false }))
assert(calls[#calls].name == 'ping' and calls[#calls].value == 'alert')
local pingCount = 0
for _, call in ipairs(calls) do if call.name == 'ping' then pingCount = pingCount + 1 end end
assert(not endHandler('ping', { pingtype = 'alert', pingLocation = true, isCancel = true }))
assert(pingCount == 1, 'cancelled command mode does not emit a ping')

assert(shell:RequestMinimapToggle(false) == false and not minimapEnabled)
assert(shell:RequestMinimapToggle(true) == true and minimapEnabled)
assert(shell:RequestMinimapToggle(true) == true and minimapEnabled)
local toggleCount = 0
for _, call in ipairs(calls) do if call.name == 'minimapToggle' then toggleCount = toggleCount + 1 end end
assert(toggleCount == 1, 'repeated requested minimap state never flips twice')

local teamColor = shell.overlayButtons[2]
check(teamColor, true)
assert(not teamColor.checked and not teamColor._claretChecked,
    'unsupported team-color action is rejected and checkbox visual state rolls back')
assert(controller.callbacks.onCollapse(true) and collapsed)
assert(controller.callbacks.onCollapse(true) and collapsed, 'collapse request is idempotent')
check(shell.collapseArrow, false)
assert(not collapsed and not shell.collapsed, 'shell collapse checkbox and controller state stay in sync')

-- FAF disables pings in replay/without a focus army; team color is separately
-- marked disableInReplay. Other overlays and UI visibility controls remain live.
assert(controller.SetAccess({ replay = true }))
assert(shell:SetAccess({ replay = true }))
assert(pingButton.disabled and teamColor.disabled and not shell.overlayButtons[3].disabled
    and not shell.overlayButtons[4].disabled and not shell.collapseArrow.disabled)
local beforeReplayClick = #calls
pingButton.OnClick(pingButton, {})
assert(#calls == beforeReplayClick, 'controller rejects ping initiation during replay')
check(shell.overlayButtons[3], false)
assert(calls[#calls].name == 'economy', 'native-enabled economy overlay remains usable in replay')
check(teamColor, false)
assert(teamColor.checked == false, 'rejected disabled overlay remains visually unchecked')
assert(controller.callbacks.onMinimapToggle(false) and controller.callbacks.onCollapse(true),
    'minimap and collapse UI controls remain usable during replay')

assert(controller.SetAccess({ replay = false, readOnly = true }))
assert(shell:SetAccess({ replay = false, readOnly = true }))
assert(pingButton.disabled and not teamColor.disabled and not shell.overlayButtons[3].disabled)
local beforeReadOnlyPing = #calls
pingButton.OnClick(pingButton, {})
assert(#calls == beforeReadOnlyPing, 'read-only policy blocks ping commands')
check(shell.overlayButtons[3], true)
assert(calls[#calls].name == 'economy', 'read-only policy retains UI-only overlays')

local staleEndHandler = endHandler
shell:Destroy()
controller.Destroy()
assert(sharedCluster.children[1] == nil and endHandler == nil)
local afterDestroy = #calls
assert(not staleEndHandler('ping', { pingtype = 'move', pingLocation = true, isCancel = false }))
assert(#calls == afterDestroy, 'stale command-mode callback is inert after destruction')
assert(calls[#calls].name == 'unsubscribe')
print('PASS: multifunction shell/controller ping, overlays, replay gating, minimap and teardown')
