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
    local current = 0
    return setmetatable({Set = function(_, value) current = value end}, {__call = function()
        return type(current) == 'function' and current() or current
    end})
end
local function control(parent)
    local self = { parent = parent, destroyed = false, needsFrame = false,
        Depth = variable(), Top = variable(), Left = variable() }
    function self:SetNeedsFrameUpdate(value) self.needsFrame = value end
    function self:SetSolidColor() end
    function self:DisableHitTest() self.hitTest = false end
    function self:EnableHitTest() self.hitTest = true end
    function self:SetAlpha(alpha) self.alpha = alpha end
    function self:SetColor(color) self.color = color end
    function self:SetFont(_, size) self.fontSize = size end
    function self:GetStringAdvance(text) return string.len(text) * (self.fontSize or 14) * 0.5 end
    function self:Show() self.hidden = false end
    function self:Hide() self.hidden = true end
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
root.Width = function() return 1920 end
root.Height = function() return 1080 end
root.Right = root.Width
root.Bottom = root.Height
local selectionEvent
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
    function option:Save() self.saves = (self.saves or 0) + 1 end
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
local selected, selectionReads = {}, 0
local ignored = false
local activeDrag
local selectionObservers = {}
local function changeSelection(_, newSelection)
    if ignored then return end
    for _, observer in pairs(selectionObservers) do observer({newSelection = newSelection}) end
end
local game = {
    ReUI = { Core = { OnPostCreateUI = function(fn) posts[#posts + 1] = fn end,
        OnPreCreateUI = function(fn) pres[#pres + 1] = fn end,
        Events = { Event = function(name)
            local source = event()
            if name == 'ClaretSelection' then selectionEvent = source end
            return source
        end },
        Hook = function(path, name, callback) hooks[name] = callback end },
        UI = { FloorLayoutFor = function() return layout end,
            FloorLayouter = function(scale)
                return setmetatable({Scale = scale}, {__call = function(layouter, item)
                    return setmetatable({
                        AtTopCenterIn = function(self) item.selectionHud = true; return self end,
                        Width = function(self, width) item.logicalWidth = width; item.Width = function() return width * layouter.Scale end; return self end,
                        Height = function(self, height) item.logicalHeight = height; item.Height = function() return height * layouter.Scale end; return self end,
                        AtLeftTopIn = function(self, _, x, y) item.x, item.y = x, y; return self end,
                    }, getmetatable(layout))
                end})
            end }, Options = options,
        Require = function() end },
    GetFrame = function() return root end,
    PostDragger = function(_, _, drag) activeDrag = drag end,
    SavePreferences = function() end,
    IsDestroyed = function(c) return c.destroyed end,
    GetSelectedUnits = function() selectionReads = selectionReads + 1; return selected end,
    LOC = function(value) return value end,
    LOG = function() end,
    WARN = function(message) warnings[#warnings + 1] = message end,
}
setmetatable(game, { __index = _G })
game.import = function(path)
    if path == '/lua/maui/dragger.lua' then return {Dragger = function() return {
        Destroy = function(self) self.destroyed = true; activeDrag = nil end,
    } end} end
    if path == '/lua/ui/game/gamemain.lua' then return { GetStatusCluster = function() return root end,
        ObserveSelection = { AddObserver = function(_, callback, name) selectionObservers[name] = callback end } }
    end
    if path == '/lua/ui/game/commandmode.lua' then return { GetCommandMode = function() return { false } end } end
    if path == '/lua/maui/layouthelpers.lua' then return {GetPixelScaleFactor = function() return 1.25 end} end
    if path == '/lua/enhancementcommon.lua' then return {GetEnhancements = function(id)
        if id == 'acu' then return {Shield = 'ShieldUpgrade'} end
    end} end
    if path == '/mods/ClaretUI/modules/features/AcuHealth.lua'
        or path == '/mods/ClaretUI/modules/features/AllRings.lua'
        or path == '/mods/ClaretUI/modules/features/Mexes.lua'
        or path == '/mods/ClaretUI/modules/features/RevealPositions.lua' then
        return {Start = function() end, Install = function() end, InstallKeys = function() end}
    end
    if path == '/mods/ClaretUI/modules/UiSection.lua' then return {} end
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
    if path == '/lua/ui/uiutil.lua' then return { bodyFont = 'Arial', CreateText = function(parent, _, size)
        local item = control(parent)
        item.fontSize = size
        return item
    end } end
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
game.ReUI.ClaretCore = core
game.import('/mods/ClaretUI/Options.lua')
game.import('/mods/ClaretUI/Main.lua').Main(false)
local uiOptions = options.Mods.ClaretUI
assert(not uiOptions.selectionHud:Get())
assert(not hooks.OnSelectionChanged, 'Core uses the existing FAF selection observer')
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
changeSelection(nil, nextSelected)
assert(cargoResets == resetsBeforeChange + 1)
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
assert(selectionReads == previousReads, 'recreated panel uses the current event snapshot')
summary = controls[#controls]
option:Set(false); option:Set(true)
assert(driverCount() == 0 and not summary.destroyed, 'diagnostics switch does not affect selection UI')

local function hudPanel()
    for _, item in ipairs(controls) do if item.selectionHud and not item.destroyed then return item end end
end
local function hudText(panel, text)
    for _, item in ipairs(controls) do
        if item.parent == panel and not item.hidden and not item.destroyed and item.text == text then return item end
    end
end
local tank = {BlueprintId = 'tank', General = {UnitName = 'Tank'}, Economy = {BuildCostMass = 52, BuildCostEnergy = 270}}
local engineer = {BlueprintId = 'eng', Description = 'Engineer', CategoriesHash = {ENGINEER = true},
    Economy = {BuildRate = 5, BuildCostMass = 40, BuildCostEnergy = 260}}
local acu = {BlueprintId = 'acu', CategoriesHash = {COMMAND = true}, Economy = {BuildCostMass = 10000},
    Enhancements = {ShieldUpgrade = {ShieldMaxHealth = 1000, BuildCostMass = 500, BuildCostEnergy = 4000}}}
local samples = 0
local function hudUnit(bp, hp, kills, reclaimed, econ, shield, dead)
    return { IsDead = function() return dead end, GetBlueprint = function() return bp end,
        GetEntityId = function() return bp.BlueprintId end, GetBuildRate = function() return 12 end,
        GetHealth = function() samples = samples + 1; return hp end, GetShieldRatio = function() return shield end,
        GetEconData = function() return econ end,
        GetStat = function(_, key) return { Value = key == 'VetExperience' and kills or reclaimed } end }
end
local firstTank, secondTank = hudUnit(tank, 205, 41, 0), hudUnit(tank, 300, 9, 0)
local builder = hudUnit(engineer, 70, 0, 14, {massRequested = 3.5, energyProduced = 1.2})
local commander = hudUnit(acu, 999, 0, 0, nil, 0.5)
assert(not hudPanel(), 'disabled HUD has no controls')
changeSelection(nil, {firstTank})
assert(samples == 0, 'disabled HUD does not sample units')
local warningsBeforeHud = #warnings
uiOptions.selectionHud:Set(true)
local panel = assert(hudPanel(), warnings[#warnings])
assert(core.Localization.Text('claretui.selection.title') == 'Selection Info')
assert(not panel.hidden and summary.destroyed and selectionOption:Get())
assert(core.GetFeatureState('selectionSummary') == 'disabled')
assert(not hudText(panel, 'Tank') and hudText(panel, 'Units') and not hudText(panel, 'Types') and hudText(panel, '1'))
assert(hudText(panel, '52') and hudText(panel, '270') and hudText(panel, '41') and hudText(panel, '205'))
assert(not hudText(panel, 'Build power') and not hudText(panel, 'Mass reclaimed') and not hudText(panel, 'Shield'))
assert(uiOptions.selectionDynamic:Get() and not hudText(panel, 'Resources'))
local staticReads = samples
uiOptions.selectionDynamic:Set(false)
assert(hudText(panel, 'Build power') and hudText(panel, 'Shield') and hudText(panel, 'Mass reclaimed'))
uiOptions.selection_shield:Set(false)
assert(not hudText(panel, 'Shield'), 'static display respects individual field switches')
uiOptions.selection_shield:Set(true)
uiOptions.selectionDynamic:Set(true)
assert(not hudText(panel, 'Shield') and samples == staticReads)

local generator = {Economy = {ProductionPerSecondEnergy = 5}}
local consumer = {Economy = {MaintenanceConsumptionPerSecondEnergy = 5}}
changeSelection(nil, {hudUnit(generator, 100, 0, 0)})
assert(hudText(panel, 'Energy/s') and hudText(panel, '+0.0') and not hudText(panel, 'Mass/s'))
assert(not hudText(panel, 'Mass destroyed') and not hudText(panel, 'Cost'))
changeSelection(nil, {hudUnit(generator, 100, 0, 0, {energyProduced = 5, massProduced = 3}),
    hudUnit(consumer, 100, 0, 0, {energyRequested = 5, massRequested = 3})})
assert(hudText(panel, 'Energy/s') and hudText(panel, '+0.0') and hudText(panel, 'Mass/s'))
local armed = {Weapon = {{Damage = 5}}}
changeSelection(nil, {hudUnit(armed, 100, 0, 0)})
assert(hudText(panel, 'Mass destroyed') and not hudText(panel, 'Mass reclaimed'))

changeSelection(nil, {firstTank, secondTank, hudUnit(acu, 999, 0, 0, nil, 1, true)})
assert(hudText(panel, '2'))
assert(hudText(panel, '104') and hudText(panel, '540') and hudText(panel, '50') and hudText(panel, '505'))
ignored = true; changeSelection(nil, {commander}); ignored = false
assert(hudText(panel, '104') and hudText(panel, '2'), 'ignored engine selection leaves the visible snapshot intact')

changeSelection(nil, {firstTank, builder, commander})
assert(not hudText(panel, 'Tank') and hudText(panel, '3'))
for _, text in ipairs({'-3.5', '+1.2', '17', '592', '4530', '41', '14', '1274', '500'}) do
    assert(hudText(panel, text), 'missing mixed selection value: ' .. text)
end
assert(hudText(panel, 'Shield') and hudText(panel, 'Mass reclaimed'))
assert(hudText(panel, '500').fontSize > 2 * hudText(panel, 'Shield').fontSize)
local colors = game.import('/mods/ClaretCore/modules/Theme.lua').Colors
assert(hudText(panel, '500').color == colors.hudShield and hudText(panel, '1274').color == colors.hudHealth)
assert(hudText(panel, '592').color == colors.hudMass and hudText(panel, '4530').color == colors.hudEnergy)
assert(hudText(panel, '17').color == colors.hudValue and hudText(panel, '41').color == colors.hudDamage)
assert(hudText(panel, 'Shield').color == colors.muted and hudText(panel, 'Cost').color == colors.muted)
local cost, massCost, energyCost = hudText(panel, 'Cost'), hudText(panel, '592'), hudText(panel, '4530')
assert(cost.x == massCost.x and cost.x == energyCost.x and cost.y < massCost.y and massCost.y < energyCost.y)
local fullWidth, fullHeight = panel.logicalWidth, panel.logicalHeight
uiOptions.selectionLabels:Set(false)
assert(not hudText(panel, 'Cost') and not hudText(panel, 'Shield') and hudText(panel, '500'))
assert(panel.logicalWidth < fullWidth and panel.logicalHeight < fullHeight)
uiOptions.selectionLabels:Set(true)
local backdrop
for _, item in ipairs(controls) do if item.parent == panel and item.alpha then backdrop = item end end
assert(backdrop and backdrop.alpha == 1)
uiOptions.selectionTransparency:Set(100)
assert(backdrop.alpha == 0 and not hudText(panel, '500').alpha and panel.hitTest)
assert(not panel:HandleEvent({Type='ButtonPress', Modifiers={Middle=true}, MouseX=20, MouseY=20}))
local press = {Type='ButtonPress', Modifiers={Left=true}, MouseX=20, MouseY=20}
assert(panel:HandleEvent(press) and activeDrag)
activeDrag:OnRelease(145, 70)
assert(uiOptions.selectionPosition:Get().x == 100 and uiOptions.selectionPosition:Get().y == 116)
assert(uiOptions.selectionPosition.saves == 1)
assert(panel:HandleEvent(press) and activeDrag)
activeDrag:OnMove(250, 100)
uiOptions.selectionLocked:Set(true)
assert(not activeDrag and not panel.hitTest and panel.Left() == 125 and panel.Top() == 145)
assert(not panel:HandleEvent(press) and uiOptions.selectionPosition.saves == 1)
local readCount = samples
local initialFont, initialHeight = hudText(panel, '500').fontSize, panel.Height()
for _, percent in ipairs({50, 200, 150}) do
    uiOptions.selectionScale:Set(percent)
    assert(hudText(panel, '500').fontSize == initialFont * percent / 100)
    assert(panel.Height() == initialHeight * percent / 100)
    assert(panel.Left() == 125 and panel.Top() == 145 and samples == readCount)
end
core.Localization.SetLanguage('ru')
assert(core.Localization.Text('claretui.selection.title') == 'Selection Info')
assert(hudText(panel, 'Юниты') and hudText(panel, 'Масса/с') and hudText(panel, 'Энергия/с')
    and hudText(panel, 'БП') and samples == readCount)
core.Localization.SetLanguage('en')
uiOptions.selection_massRate:Set(false)
assert(not hudText(panel, 'Mass/s') and not hudText(panel, '-3.5') and hudText(panel, 'Energy/s'))
local fields = game.import('/mods/ClaretUI/modules/SelectionHudFields.lua').Fields
for _, field in ipairs(fields) do uiOptions['selection_' .. field.key]:Set(false) end
assert(panel.hidden and samples == readCount, 'an empty display hides without resampling')
uiOptions.selection_energyRate:Set(true)
assert(not panel.hidden and hudText(panel, '+1.2') and not hudText(panel, 'Units'))
assert(panel.logicalWidth < fullWidth and panel.logicalHeight < fullHeight)
for _, field in ipairs(fields) do uiOptions['selection_' .. field.key]:Set(true) end
changeSelection(nil, nil)
assert(panel.hidden, 'deselection hides the HUD')
changeSelection(nil, {hudUnit(acu, 999, 0, 0, nil, 0)})
assert(not panel.hidden and hudText(panel, 'Shield'), 'an empty installed shield remains visible')
local shieldZero
for _, item in ipairs(controls) do
    if item.parent == panel and not item.hidden and item.color == colors.hudShield then shieldZero = item.text end
end
assert(shieldZero == '0')
assert(hudText(panel, 'Mass reclaimed'), 'a commander can reclaim even with a zero total')
selectionOption:Set(false); selectionOption:Set(true)
assert(core.GetFeatureState('selectionSummary') == 'disabled', 'Core option cannot show a second panel')
local title = assert(hudText(panel, 'Combat'))
local titleWrites = title.textWrites
uiOptions.selectionHud:Set(false)
assert(panel.destroyed and not hudPanel() and core.GetFeatureState('selectionSummary') == 'running')
assert(next(uiOptions.selection_massRate.OnChanged.callbacks) == nil)
assert(next(uiOptions.selectionScale.OnChanged.callbacks) == nil)
assert(selectionOption:Get(), 'HUD does not rewrite Core settings')
core.Localization.SetLanguage('ru')
assert(title.textWrites == titleWrites, 'disabling the HUD removes its language subscription')
core.Localization.SetLanguage('en')
readCount = samples
changeSelection(nil, {builder}); assert(samples == readCount)
selectionOption:Set(false)
assert(next(selectionEvent.callbacks) == nil, 'disabled HUD and Core leave no selection subscribers')
uiOptions.selectionHud:Set(true)
panel = assert(hudPanel())
assert(hudText(panel, '-3.5').fontSize == initialFont * 1.5 and panel.Left() == 125 and panel.Top() == 145 and not panel.hitTest,
    'reenabling restores position, lock and the newest selection')
uiOptions.enabled:Set(false)
assert(not hudPanel() and next(selectionEvent.callbacks) == nil)
assert(next(uiOptions.selectionHud.OnChanged.callbacks) == nil)
uiOptions.enabled:Set(true)
panel = assert(hudPanel())
assert(core.GetFeatureState('selectionSummary') == 'disabled' and driverCount() == 0)
assert(#warnings == warningsBeforeHud, warnings[#warnings])
uiOptions.selectionLocked:Set(false)
assert(panel:HandleEvent(press))
local closingDrag = assert(activeDrag)
owner:Destroy()
assert(closingDrag.destroyed and not activeDrag, 'match teardown cancels an in-progress drag')
print('PASS: selection HUD grouping, colors, settings, placement and teardown')
assert(welcomeDestroyed == 1, 'welcome window is owned by the Core UI session')
assert(cargoDestroyed, 'Core destroys the transport cargo service with the UI owner')
assert(stops == 2 and next(extensionOption.OnChanged.callbacks) == nil)
assert(next(lateOption.OnChanged.callbacks) == nil)
assert(not core.RegisterFeature('afterDispose', function() end, lateOption))
assert(not core.RegisterSettingsSection({id='afterDispose',title='Disposed'}))
assert(driverCount() == 0 and next(option.OnChanged.callbacks) == nil)
assert(next(selectionOption.OnChanged.callbacks) == nil)
assert(panel.destroyed and next(selectionObservers) == nil and next(selectionEvent.callbacks) == nil)
assert(next(uiOptions.selectionHud.OnChanged.callbacks) == nil)
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
