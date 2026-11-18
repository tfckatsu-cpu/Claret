table.getn = function(value) return #value end
local function loadModule(path)
    local env = setmetatable({}, { __index = _G })
    assert(loadfile(path, 't', env))()
    return env
end

local facadeModule = loadModule('../mods/ClaretCore/modules/ConstructionFacade.lua')
local controllerModule = loadModule('../mods/ClaretCore/modules/ConstructionController.lua')

local rendered, errors = {}, {}
local queue = {}
local appendCalls = 0
local controller = controllerModule.Create({
    choices = { Build = function() return { tabs = { t1 = {}, t2 = {}, t3 = {}, t4 = {} }, errors = {} } end },
    gridModel = { Build = function() return { entries = {}, errors = {} } end },
    queueModel = { Build = function(items) return { entries = items, errors = {} } end },
    selectionModel = { Build = function() return { entries = {}, errors = {} } end },
    enhancementsModel = { Build = function() return { slots = {}, errors = {} } end },
    cargoState = {
        Reset = function() return true end,
        SetCargo = function() return true end,
        IsSelected = function() return false end,
        GetSelection = function() return {} end,
        AppendNext = function() appendCalls = appendCalls + 1; return true end,
        Destroy = function() return true end,
    },
    renderPrimary = function(_, mode, data) table.insert(rendered, { 'primary', mode, data }); return true end,
    renderSecondary = function(_, mode, data) table.insert(rendered, { 'secondary', mode, data }); return true end,
    onError = function(message) table.insert(errors, message) end,
})

local root = {
    visible = false, destroyed = false,
    Show = function(self) self.visible = true end,
    Hide = function(self) self.visible = false end,
    OnDestroy = function(self) self.baseOnDestroy = (self.baseOnDestroy or 0) + 1 end,
    Destroy = function(self) self.destroyed = true end,
}
local beforeShow, beforeHide, beforeDestroy = root.Show, root.Hide, root.Destroy
local unit = {}
local hotkeys = {}
local refreshes = 0
local failSelectionAdapter = false
local adapter = {
    getBuildables = function(selection)
        if failSelectionAdapter then error('buildable adapter failed') end
        assert(selection[1] == unit); return { 'bp' }
    end,
    getCargo = function(selection) assert(selection[1] == unit); return { {}, {} } end,
    getQueue = function() return queue end,
    refresh = function() refreshes = refreshes + 1; return true end,
    setHotKeys = function(kind, relations, key) hotkeys[kind] = { relations, key }; return true end,
}

local result = facadeModule.Create(root, controller, adapter)
assert(result == root and root.ClaretConstructionFacade, 'facade methods attach to and return the Maui root')
assert(#rendered == 0 and refreshes == 0, 'creation has no controller, rendering, or engine side effects')
root:Show()
assert(root.visible, 'Show delegates to the original Maui method')
root:Hide()
assert(not root.visible, 'Hide delegates to the original Maui method')
assert(root:OnSelectionChanged({ unit }), 'selection dispatches through validated adapters into the real controller')
assert(controller.selection[1] == unit and controller.buildables[1] == 'bp' and #controller.cargo == 2)
assert(root:GetCurrentTechTab() == 1, 'current tech maps t1 to native tech tab 1')
assert(root:GetHandler('TransportCargo'):AppendNextUnitForDrop(), 'transport handler delegates to controller.AppendCargo')
assert(appendCalls == 1)
assert(root:GetHandler('BuildOptions'):SetHotKeys({ bp = 'A' }, 'U'))
assert(root:GetHandler('BuildOptionsFactory'):SetHotKeys({ bp = 'B' }, 'V'))
assert(hotkeys.BuildOptions[1].bp == 'A' and hotkeys.BuildOptionsFactory[2] == 'V')
assert(not root:Update('queue'), 'unchanged empty queue is suppressed by the controller')
queue = { { id = 'bp', count = 2 } }
assert(root:Update('queue') and rendered[#rendered][3][1].count == 2)
assert(root:Refresh() and refreshes == 1, 'Refresh delegates to the injected redraw adapter')

failSelectionAdapter = true
assert(not root:OnSelectionChanged({ unit }), 'adapter failure rejects the new selection')
assert(#controller.selection == 0 and not controller.hasValidSelection,
    'adapter failure invalidates controller state from the prior selection')
local beforeRejectedAppend = appendCalls
assert(not root:GetHandler('TransportCargo'):AppendNextUnitForDrop()
    and appendCalls == beforeRejectedAppend,
    'append action cannot target cargo from the prior selection after adapter failure')

local foreignUpdate = function() return 'third-party' end
root.Update = foreignUpdate
local staleSelection = root.OnSelectionChanged
local staleCargoHandler = root:GetHandler('TransportCargo')
root.ClaretConstructionFacade:Destroy()
assert(root.Update == foreignUpdate, 'cleanup leaves a later third-party method replacement untouched')
assert(root.Show == beforeShow and root.Hide == beforeHide and root.Destroy == beforeDestroy,
    'facade teardown restores only methods it still owns')
assert(not staleSelection(root, { unit }), 'destroyed facade rejects stale selection dispatch')
assert(not staleCargoHandler.AppendNextUnitForDrop(), 'destroyed facade handlers reject stale actions')

local second = { Show = function() end, Hide = function() end, OnDestroy = function() end,
    Destroy = function(self) self.destroyed = true end }
local secondController = controllerModule.Create({
    renderPrimary = function() return true end, renderSecondary = function() return true end,
})
assert(facadeModule.Create(second, secondController, {}) == second)
second:Destroy()
assert(second.destroyed and not second.ClaretConstructionFacade,
    'Maui Destroy tears down facade methods before delegating to the original control destroy')

assert(#errors > 0, 'adapter and controller invalidation failures are diagnosed')
print('PASS: Construction facade preserves root identity, dispatches controller operations, and cleans up safely')
