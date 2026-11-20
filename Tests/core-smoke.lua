-- Run in Fengari as a logic test; this does not emulate the FAF renderer.
table.getn = function(t) return #t end
local env = setmetatable({}, { __index = _G })
assert(loadfile('../mods/ClaretCore/modules/Lifecycle.lua', 't', env))()
local failures, order, starts = {}, {}, 0
local function report(message) failures[#failures + 1] = message end
local c = env.Create(function(scope)
    starts = starts + 1
    scope:Defer(function() order[#order + 1] = 'first' end)
    scope:Defer(function() order[#order + 1] = 'last' end)
end, report)
assert(c:SetEnabled(true)); assert(c:SetEnabled(true)); assert(starts == 1)
assert(c:SetEnabled(false)); assert(table.concat(order, ',') == 'last,first')
assert(c:SetEnabled(false)); assert(#order == 2)
assert(c:SetEnabled(true)); assert(starts == 2)
c:Destroy(); c:Destroy(); assert(not c:SetEnabled(true)); assert(not c:IsActive())
local cleaned = 0
local broken = env.Create(function(scope)
    scope:Defer(function() cleaned = cleaned + 1 end)
    scope:Defer(function() error('cleanup fault') end)
    error('startup fault')
end, report)
assert(not broken:SetEnabled(true)); assert(not broken:IsActive())
assert(cleaned == 1 and #failures == 2)
assert(not broken:SetEnabled(true)); assert(cleaned == 2)
broken:Destroy()

-- Integration: ReUI startup, option changes, probe callbacks and session destruction.
local controls, posts, modules, warnings, hooks, pres = {}, {}, {}, {}, {}, {}
local cargoSelections, cargoDestroyed, cargoResets = {}, false, 0
local cargoApiResult = true
local cargoPassenger, indicatedPassenger, indicatorFails = {}, nil, false
local welcomeCreated, welcomeDestroyed = 0, 0
local function variable()
    return { Set = function() end }
end
local function control(parent)
    local self = { parent = parent, destroyed = false, needsFrame = false,
        Depth = variable() }
    function self:SetNeedsFrameUpdate(value) self.needsFrame = value end
    function self:SetSolidColor() end
    function self:DisableHitTest() end
    function self:SetColor() end
    function self:SetText(text) self.text = text; self.textWrites = (self.textWrites or 0) + 1 end
    function self:OnDestroy() end
    function self:Destroy()
        if self.destroyed then return end
        self:OnDestroy()
        self.destroyed = true
        self.needsFrame = false
        for _, child in ipairs(controls) do
            if child.parent == self then child:Destroy() end
        end
    end
    controls[#controls + 1] = self
    return self
end
local root = control(nil)
local function event()
    local callbacks = {}
    return {
        callbacks = callbacks,
        Add = function(self, fn) callbacks[fn] = true end,
        Remove = function(self, fn) callbacks[fn] = nil end,
        Clear = function(self) for fn in pairs(callbacks) do callbacks[fn] = nil end end,
        Invoke = function(self, sender, value)
            local snapshot = {}
            for fn in pairs(callbacks) do snapshot[#snapshot + 1] = fn end
            for _, fn in ipairs(snapshot) do if callbacks[fn] then fn(sender, value) end end
        end,
    }
end
local function makeOption(initial)
    local option = { value = initial, OnChanged = event() }
    function option:Get() return self.value end
    function option:Set(value)
        self.value = value
        self.OnChanged:Invoke(self, value)
    end
    return option
end
local options = { Mods = {}, OptionValue = makeOption, Builder = {
    AddOptions = function() end, Filter = function() return {} end,
} }
local layout = setmetatable({}, { __index = function(self) return function() return self end end })
local selected, selectionReads, originalCalls = {}, 0, 0
local ignored = false
local game = {
    ReUI = { Core = { OnPostCreateUI = function(fn) posts[#posts + 1] = fn end,
        OnPreCreateUI = function(fn) pres[#pres + 1] = fn end,
        Events = { Event = event },
        Hook = function(path, name, callback) hooks[name] = callback end },
        UI = { FloorLayoutFor = function() return layout end }, Options = options,
        Require = function() end },
    GetFrame = function() return root end,
    IsDestroyed = function(c) return c.destroyed end,
    GetSelectedUnits = function() selectionReads = selectionReads + 1; return selected end,
    LOG = function() end,
    WARN = function(message) warnings[#warnings + 1] = message end,
}
setmetatable(game, { __index = _G })
game.import = function(path)
    if path == '/mods/ClaretCore/modules/Minimap.lua' then return {Create=function() return {
        ManualToggle=function() end, LayoutChanged=function() end,
        Start=function() return function() end end,
    } end} end
    if path == '/mods/ClaretCore/modules/TransportCargo.lua' then return {Create=function(isReplay)
        assert(isReplay == false)
        return {
            Append=function(self, selection)
                cargoSelections[#cargoSelections + 1] = selection
                return cargoApiResult, cargoApiResult and cargoPassenger or nil, 1
            end,
            Reset=function() cargoResets = cargoResets + 1 end,
            Destroy=function() cargoDestroyed = true end,
        }
    end} end
    if path == '/mods/ClaretCore/modules/ReUICargoIndicator.lua' then return {Mark=function(unit)
        if indicatorFails then error('indicator unavailable') end
        indicatedPassenger=unit
    end} end
    if path == '/mods/ClaretCore/modules/MenuKey.lua' then return {Create=function(open)
        game.openMenu=open
        return {Initialize=function() end,Start=function() end,Destroy=function() game.openMenu=nil end}
    end} end
    if path == '/mods/ClaretCore/modules/Welcome.lua' then return {
        ShouldShowWelcome=function(dismissed) return dismissed ~= true end,
        Create=function(parent)
            welcomeCreated=welcomeCreated+1
            local window=control(parent)
            function window:OnDestroy() welcomeDestroyed=welcomeDestroyed+1 end
            return window
        end,
    } end
    if path == '/lua/ui/game/tabs.lua' then return {AddToMenu=function(item) game.menuItem=item end} end
    if path == '/lua/ui/game/rangeoverlayparams.lua' then return {RangeOverlayParams={}} end
    if path == '/lua/ui/game/worldview.lua' then return {viewLeft=nil} end
    if path == '/lua/maui/group.lua' then return { Group = control } end
    if path == '/lua/maui/bitmap.lua' then return { Bitmap = control } end
    if path == '/lua/ui/uiutil.lua' then return { bodyFont = 'Arial', CreateText = function(parent) return control(parent) end } end
    if modules[path] then return modules[path] end
    local module = setmetatable({}, { __index = game })
    assert(loadfile('..' .. path, 't', module))()
    modules[path] = module
    return module
end
local main = game.import('/mods/ClaretCore/Main.lua')
game.import('/mods/ClaretCore/Options.lua').Main()
local option = options.Mods.ClaretCore.probeEnabled
assert(option:Get() == false, 'probe must be disabled by default')
option:Set(true) -- Exercise the probe lifecycle explicitly.
local selectionOption = options.Mods.ClaretCore.selectionEnabled
local core = main.Main(false)
local cargoSelection = {{id='transport'}}
assert(not core.AppendTransportCargo(cargoSelection) and #cargoSelections == 0,
    'Core cargo API stays unavailable before the UI is ready')
assert(#pres == 1)
pres[1]()
assert(game.menuItem.label == 'Claret' and game.menuItem.action == 'Claret.Settings')
assert(core.RegisterSettingsSection({id='extra',title='Extra'}))
assert(not core.RegisterSettingsSection({id='extra',title='Duplicate'}))
local extensionOption = makeOption(true)
local starts, stops = 0, 0
assert(core.RegisterFeature('external', function(scope)
    starts = starts + 1
    scope:Defer(function() stops = stops + 1 end)
end, extensionOption))
assert(not core.RegisterFeature('external', function() end, extensionOption))
assert(not core.RegisterFeature('probe', function() end, extensionOption))
assert(starts == 0, 'external module must wait for Core UI')
local forwarded
local changeSelection = hooks.OnSelectionChanged(function(a, b, c, d)
    forwarded = {a, b, c, d}
    originalCalls = originalCalls + 1
    return 'original result'
end, { IsIgnoredSelection = function() return ignored end })
assert(#controls == 1 and #posts == 1, 'UI must be deferred')
posts[1]()
assert(welcomeCreated == 1, 'welcome window is created with the game UI')
assert(core.AppendTransportCargo(cargoSelection) and cargoSelections[1] == cargoSelection,
    'Core exposes the cargo API and forwards the transport selection after UI readiness')
assert(indicatedPassenger == cargoPassenger, 'Core forwards the staged passenger to the optional indicator')
cargoApiResult = false
indicatedPassenger = nil
assert(not core.AppendTransportCargo(cargoSelection) and cargoSelections[2] == cargoSelection,
    'Core preserves a false cargo-service result')
assert(indicatedPassenger == nil, 'failed cargo staging does not change the indicator')
cargoApiResult = true
indicatorFails = true
assert(core.AppendTransportCargo(cargoSelection), 'indicator failures do not cancel successful cargo staging')
indicatorFails = false
assert(starts == 1 and core.GetFeatureState('external') == 'running')
extensionOption:Set(false); assert(stops == 1)
extensionOption:Set(true); assert(starts == 2)
local lateOption = makeOption(true)
assert(core.RegisterFeature('late', function() end, lateOption))
assert(core.GetFeatureState('late') == 'running')
local function driverCount()
    local count = 0
    for _, c in ipairs(controls) do if not c.destroyed and c.needsFrame then count = count + 1 end end
    return count
end
assert(driverCount() == 0, 'diagnostics must not create a frame-updated overlay')
local owner = controls[2]
for _, control in ipairs(controls) do
    assert(control.text ~= 'Claret Core | ACTIVE' and control.text ~= 'UI updates: 0',
        'diagnostics must not create the removed overlay')
end
local summary = controls[5]
assert(summary.text == 'Units: 0 | Types: 0')
local function unit(id, dead)
    return { IsDead = function() return dead end, GetBlueprint = function() return { BlueprintId = id } end }
end
local nextSelected = { unit('a'), unit('a'), unit('b'), unit('c', true) }
local resetsBeforeChange = cargoResets
assert(changeSelection(1, nextSelected, 3, 4) == 'original result' and originalCalls == 1)
assert(cargoResets == resetsBeforeChange + 1)
assert(forwarded[1] == 1 and forwarded[2] == nextSelected and forwarded[3] == 3 and forwarded[4] == 4)
assert(summary.text == 'Units: 3 | Types: 2')
selected = nextSelected
changeSelection(selected, nil)
assert(summary.text == 'Units: 0 | Types: 0')
changeSelection(nil, selected)
local writes = summary.textWrites
changeSelection(nil, selected)
assert(summary.textWrites == writes)
local previousReads = selectionReads
local resetsBeforeIgnored = cargoResets
ignored = true; changeSelection(nil, {}); ignored = false
assert(selectionReads == previousReads and cargoResets == resetsBeforeIgnored)
assert(summary.text == 'Units: 3 | Types: 2')
selectionOption:Set(false)
changeSelection(nil, selected)
assert(selectionReads == previousReads and summary.destroyed)
selectionOption:Set(true)
assert(selectionReads == previousReads + 1)
summary = controls[#controls]
option:Set(false); option:Set(true)
assert(driverCount() == 0 and not summary.destroyed, 'diagnostics switch does not affect selection UI')
owner:Destroy()
assert(welcomeDestroyed == 1, 'welcome window is owned by the Core UI session')
assert(cargoDestroyed, 'Core destroys the transport cargo service with the UI owner')
assert(stops == 2 and next(extensionOption.OnChanged.callbacks) == nil)
assert(next(lateOption.OnChanged.callbacks) == nil)
assert(not core.RegisterFeature('afterDispose', function() end, lateOption))
assert(not core.RegisterSettingsSection({id='afterDispose',title='Disposed'}))
assert(driverCount() == 0 and next(option.OnChanged.callbacks) == nil)
assert(next(selectionOption.OnChanged.callbacks) == nil)
previousReads = selectionReads; changeSelection(nil, selected)
assert(selectionReads == previousReads)
option:Set(true); assert(driverCount() == 0)

local Registry = game.import('/mods/ClaretCore/modules/Registry.lua')
local r = Registry.Create(report, function() end)
local cleanedResources = 0
local sourceEvent = event()
r:Register('bad', function(scope)
    scope:Defer(function() cleanedResources = cleanedResources + 1 end)
    scope:Bind(sourceEvent, function() error('event fault') end)
end)
r:Register('good', function() end)
assert(not pcall(function() r:Register('good', function() end) end))
r:SetEnabled('bad', true); r:SetEnabled('good', true)
sourceEvent:Invoke()
assert(r:GetState('bad') == 'error' and r:GetState('good') == 'running')
assert(cleanedResources == 1 and next(sourceEvent.callbacks) == nil)
r:SetEnabled('bad', false); assert(r:GetState('bad') == 'disabled')
r:SetEnabled('bad', true); assert(r:GetState('bad') == 'running')
r:Destroy(); r:Destroy()
assert(cleanedResources == 2 and not r:SetEnabled('good', true))
assert(r:GetState('good') == 'disposed')
local early = Registry.Create(report, function() end)
local earlyEvent = event()
local earlyCleaned = false
early:Register('earlyFault', function(scope)
    scope:Defer(function() earlyCleaned = true end)
    scope:Bind(earlyEvent, function() error('fault during start') end)
    earlyEvent:Invoke()
end)
assert(not early:SetEnabled('earlyFault', true))
assert(early:GetState('earlyFault') == 'error' and earlyCleaned)
assert(next(earlyEvent.callbacks) == nil)
early:Destroy()
print('PASS: rollback, cleanup errors, registry states, duplicate IDs, event faults, independent features, hidden selections, 10 toggles, late callbacks, teardown')
