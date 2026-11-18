-- End-to-end assembly with real Claret controller, cargo/view/facade modules,
-- and Maui/SpecialGrid stand-ins. No game hooks or engine commands are used.
table.getn = function(value) return #value end
table.getsize = function(value) local n = 0; for _ in pairs(value) do n = n + 1 end; return n end
math.mod = math.mod or math.fmod

local function loadModule(path, env)
    env = env or setmetatable({}, { __index = _G })
    assert(loadfile(path, 't', env))()
    return env
end

local function Layout()
    local value = {}
    for _, method in ipairs({ 'AtCenterIn', 'Width', 'Height', 'AtLeftTopIn', 'AtBottomIn',
        'AtRightIn', 'Fill', 'AtLeftBottomIn' }) do
        value[method] = function(self) return self end
    end
    return value
end
local layoutHelpers = {}
for _, method in ipairs({ 'AtCenterIn', 'AtLeftTopIn', 'Below', 'RightOf' }) do
    layoutHelpers[method] = function(control, target, x, y)
        control.layout = { method = method, target = target, x = x, y = y }
    end
end
layoutHelpers.SetDimensions = function(control, width, height) control:SetDimensions(width, height) end
local function NewControl(kind, parent)
    local self = { kind = kind, parent = parent, children = {}, shown = true }
    self.Depth = setmetatable({ value = 0, Set = function(depth, value) depth.value = value end }, {
        __call = function(depth) return type(depth.value) == 'function' and depth.value() or depth.value end,
    })
    if parent and parent.children then table.insert(parent.children, self) end
    function self:Destroy()
        if self.destroyed then return end
        if self.OnDestroy then self:OnDestroy() end
        self.destroyed = true
        for _, child in ipairs(self.children) do child:Destroy() end
    end
    function self:Show() self.shown = true end
    function self:Hide() self.shown = false end
    function self:SetDimensions(w, h) self.width, self.height = w, h end
    function self:DisableHitTest() end
    function self:SetTexture(value) self.texture = value end
    function self:SetSolidColor(value) self.solid = value end
    function self:SetNewTextures(...) self.textures = { ... } end
    function self:UseAlphaHitTest(value) self.alphaHitTest = value end
    function self:SetOverrideTexture(value) self.overrideTexture = value end
    function self:SetOverrideEnabled(value) self.overrideEnabled = value end
    function self:Enable() self.disabled = false end
    function self:Disable() self.disabled = true end
    function self:SetAlpha(value) self.alpha = value end
    function self:SetNeedsFrameUpdate(value) self.needsFrameUpdate = value end
    function self:SetColor(value) self.color = value end
    function self:SetDropShadow() end
    function self:SetText(value) self.text = value end
    function self:BitmapWidth() return 16 end
    function self:BitmapHeight() return 16 end
    function self:SetCheck(value) self.checked = value end
    function self:ToggleCheck()
        self._checkState = self._checkState == 'checked' and 'unchecked' or 'checked'
        if self.OnCheck then self:OnCheck(self, self._checkState == 'checked') end
    end
    return self
end

local function NewGrid(parent, width)
    local grid = NewControl('grid', parent)
    grid.Items, grid.DisplayData, grid.top = {}, {}, 1
    grid.width, grid._vertical = width or 384, true
    grid.CreateElement = function() return NewControl('button', grid) end
    grid.SetControlToType = function(cell, kind)
        cell.kind = kind
        cell.OnClick = function() cell.baseClicked = true end
    end
    grid._baseMethods = { CreateElement = grid.CreateElement, SetControlToType = grid.SetControlToType }
    function grid:ClearItems()
        for index, item in pairs(self.Items) do item:Destroy(); self.Items[index] = nil end
    end
    function grid:CalcVisible()
        local visible = math.min(table.getn(self.DisplayData), math.floor(self.width / 48))
        for index = 1, visible do
            local cell = self.Items[index]
            if not cell then cell = self.CreateElement(); self.Items[index] = cell end
            local data = self.DisplayData[index]
            cell.Data = data
            cell:Show()
            self.SetControlToType(cell, data.type)
        end
        for index = visible + 1, table.getsize(self.Items) do
            if self.Items[index] then self.Items[index]:Hide() end
        end
    end
    function grid:Refresh(data)
        self.top = 1
        self.DisplayData = data
        self:CalcVisible()
    end
    function grid:SetToVertical(value)
        self._vertical = value
        self:ClearItems()
        self:CalcVisible()
    end
    return grid
end

local Button = function(parent) return NewControl('button', parent) end
local Bitmap = function(parent) return NewControl('bitmap', parent) end
local CheckBox = function(parent) return NewControl('checkbox', parent) end
local function BaseControl(parent)
    local cell = Button(parent)
    cell.Icon = Bitmap(cell)
    cell.StratIcon = Bitmap(cell)
    cell.Count = NewControl('text', cell)
    cell.LowFuel = Bitmap(cell)
    cell.LowFuelIcon = Bitmap(cell.LowFuel)
    cell.OnClick = function() cell.baseClicked = true end
    return cell
end

local factories = {
    group = function(parent) return NewControl('group', parent) end,
    bitmap = Bitmap,
    button = Button,
    checkbox = CheckBox,
    grid = function(parent) return NewGrid(parent) end,
    statusBar = function(parent) return NewControl('status', parent) end,
    createStatusBar = function(parent) return NewControl('status', parent) end,
}

local function MauiImport(path)
    if path == '/lua/maui/button.lua' then return { FixableButton = BaseControl, Button = {} } end
    if path == '/lua/maui/bitmap.lua' then return { Bitmap = Bitmap } end
    if path == '/lua/ui/uiutil.lua' then
        return {
            UIFile = function(value) return value end,
            CreateText = function(parent) return NewControl('text', parent) end,
            bodyFont = 'font',
        }
    end
    error('unexpected import: ' .. path)
end
_G.DiskGetFileInfo = function() return true end
local ReUI = { UI = { FloorLayoutFor = function() return Layout() end } }
local itemViewModule = loadModule('../mods/ClaretCore/modules/ConstructionItemsView.lua',
    setmetatable({ import = MauiImport, ReUI = ReUI }, { __index = _G }))
local cargoViewModule = loadModule('../mods/ClaretCore/modules/ConstructionCargoView.lua',
    setmetatable({ import = MauiImport, ReUI = ReUI }, { __index = _G }))
local shellModule = loadModule('../mods/ClaretCore/modules/ConstructionPanelShell.lua')
local controllerModule = loadModule('../mods/ClaretCore/modules/ConstructionController.lua')
local facadeModule = loadModule('../mods/ClaretCore/modules/ConstructionFacade.lua')
local cargoModule = loadModule('../mods/ClaretCore/modules/CargoSelection.lua')
local queueModule = loadModule('../mods/ClaretCore/modules/ConstructionQueue.lua')
local gridModelModule = loadModule('../mods/ClaretCore/modules/ConstructionGridModel.lua')
local panelModule = loadModule('../mods/ClaretCore/modules/ConstructionPanel.lua')

local passengers = {}
local queuedUnits, added, removed = {}, {}, {}
local failRemoval = false
local currentQueue, failBuildables = {}, false
local events, errors = {}, {}
local cargoView
local state = cargoModule.Create({
    add = function(unit) table.insert(added, unit) end,
    remove = function(unit) if failRemoval then error('transport removal failed') end; table.insert(removed, unit) end,
    isQueued = function(unit) return queuedUnits[unit] == true end,
    refresh = function() if cargoView and cargoView.active then cargoView:Refresh() end end,
})

local passengerA = { GetBlueprint = function() return { BlueprintId = 'ual0001', General = { Icon = 'land' } } end }
local passengerB = { GetBlueprint = function() return { BlueprintId = 'ual0002', General = { Icon = 'air' } } end }
passengers = { passengerA, passengerB }
local engineer = { categories = { MOBILE = true, STRUCTURE = false, FACTORY = false, EXTERNALFACTORY = false } }
local gridModel = gridModelModule.Create({
    hasCategory = function(subject, category)
        if subject == engineer then return subject.categories[category] == true end
        return category == 'SORTCONSTRUCTION'
    end,
    getBlueprint = function(id) return { BuildIconSortPriority = 1, General = { UpgradesFrom = '' } } end,
    isRestricted = function() return false end,
})
local templateRow = { type = 'templates', template = { name = 'Blueprint group', icon = 'uel0001' }, sourceSnapshot = { opaque = true } }
local factoryTemplateRow = { type = 'templates', template = { name = 'Factory group', icon = 'uel0002' }, sourceSnapshot = { factory = true } }
local templateModel = { Build = function(selection, mobileTemplates, factoryTemplates)
    local isFactory = selection[1].isFactory == true
    local source = isFactory and factoryTemplates or mobileTemplates
    local entries = source and table.getn(source) > 0
        and { isFactory and factoryTemplateRow or templateRow } or {}
    return { entries = entries, errors = {}, fatalErrors = {}, kind = isFactory and 'factory' or 'mobile' }
end }
local models = {
    choices = { Build = function() return { tabs = { t1 = { 'uel0001' }, t2 = { 'uel0002' }, t3 = {}, t4 = {} }, errors = {} } end },
    gridModel = gridModel,
    selectionModel = { Build = function(selection) return { entries = { { type = 'unitstack', id = 'uel0001', units = selection } }, errors = {} } end },
    queueModel = queueModule.Create(),
    templatesModel = templateModel,
    enhancementsModel = { Build = function()
        return { unitID = 'uel0001', errors = {}, slots = {
            { id = 'Back', info = {}, entries = { { type = 'item', id = 'back' } } },
            { id = 'LCH', info = {}, entries = { { type = 'item', id = 'left' } } },
        } }
    end },
}
local clickData, rolloverEvent
local noTemplates = false
local parent = NewControl('parent')
local panel, createError = panelModule.Create(parent, {
    modules = {
        shell = shellModule.Create,
        controller = controllerModule.Create,
        itemsView = itemViewModule.Create,
        cargoView = cargoViewModule.Create,
        facade = facadeModule.Create,
    },
    factories = factories,
    shellOptions = { factories = factories, uiFile = function(path) return path end,
        layoutHelpers = layoutHelpers, tabLayout = 'right' },
    models = models,
    cargoState = state,
    adapters = {
        getBuildables = function()
            if failBuildables then error('adapter read failed') end
            return { 'uel0001' }
        end,
        getCargo = function() return passengers end,
        getQueue = function() return currentQueue end,
        getTemplates = function(selection)
            if noTemplates then return {}, {} end
            return selection[1].isFactory and {} or { { name = 'mobile-source' } },
                selection[1].isFactory and { { name = 'factory-source' } } or {}
        end,
        onItemClick = function(data, modifiers) clickData = data; return true end,
        onRollover = function(data, active) rolloverEvent = { data = data, active = active } end,
        onError = function(message, detail) table.insert(errors, { message = message, detail = detail }) end,
    },
    controllerDependencies = {
        army = 1,
        renderPrimary = nil,
    },
})
assert(panel and not createError, tostring(createError))
cargoView = panel.cargoView
local root, controls = panel.root, panel.controls
assert(root == controls.root and root.ClaretConstructionFacade, 'panel publishes facade on actual root')

local selection = { engineer }
assert(root:OnSelectionChanged(selection), 'selection creates construction choices and the initial queue grid')
assert(controls.tabsByKey['tech:t1'] and controls.tabsByKey['tech:t2'] and not controls.tabsByKey['tech:t3'],
    'tech tabs reflect the model-provided eligible levels only')
assert(controls.tabsByKey['tech:templates'], 'template tab appears when mobile template model rows are eligible')
assert(controls.constructionTab.textures[1] == '/game/construct-tab_btn/top_tab_btn_up_bmp.dds'
    and controls.constructionTab.textures[2] == '/game/construct-tab_btn/top_tab_btn_sel_bmp.dds'
    and controls.constructionTab.textures[6] == '/game/construct-tab_btn/top_tab_btn_dis_bmp.dds'
    and controls.tabsByKey['tech:t1'].textures[1] == '/game/construct-tech_btn/t1_btn_up.dds'
    and controls.tabsByKey['tech:t1'].textures[2] == '/game/construct-tech_btn/t1_btn_selected.dds'
    and controls.tabsByKey['tech:t1'].textures[6] == '/game/construct-tech_btn/t1_btn_dis.dds',
    'stock FAF textures are applied to main and nested tabs')
assert(controls.tabsByKey['tech:t1'].layout.method == 'AtLeftTopIn'
    and controls.tabsByKey['tech:t2'].layout.method == 'RightOf'
    and controls.tabsByKey['tech:t1'].layout.target == controls.minBG,
    'right-side nested tabs use the stock layout anchors in model order')
assert(controls.tabsByKey['tech:t2'].OnCheck(controls.tabsByKey['tech:t2'], true)
    and panel.controller.techTab == 't2', 'dynamic tech tab delegates to the controller')
assert(controls.tabsByKey['tech:t2'].checked, 'selected tech tab is checked after successful render')
assert(panel.controller:SelectTech('t1'), 'return to a different active tech tab before testing failed selection')
local oldTechBuild, oldGridRefresh = models.choices.Build, controls.choices.Refresh
models.choices.Build = function() return { tabs = { t1 = { 'uel0001' }, t2 = {}, t3 = {}, t4 = {} }, errors = {} } end
controls.choices.Refresh = function() error('primary render rejected after tab reconciliation') end
local staleT2 = controls.tabsByKey['tech:t2']
assert(not staleT2.OnCheck(staleT2, true), 'failed tech render rejects the tab switch')
assert(staleT2.destroyed and not controls.tabsByKey['tech:t2']
    and controls.tabsByKey['tech:t1'] and controls.tabsByKey['tech:t1'].checked,
    'membership change replaces tabs safely and restores the prior live tab after a failed render')
models.choices.Build, controls.choices.Refresh = oldTechBuild, oldGridRefresh
assert(panel.controller:SelectTech('t2'), 'tech selection recovers after failed reflow')
assert(panel:SetLayout('left') and controls.tabsByKey['tech:t1'].layout.method == 'AtLeftTopIn'
    and controls.constructionTab.textures[1] == '/game/construct-tab_top_btn/top_tab_btn_up_bmp.dds',
    'layout switch applies left-side anchors and its distinct stock textures')
assert(panel:SetLayout('right') and controls.tabsByKey['tech:t2'].layout.method == 'RightOf'
    and controls.constructionTab.textures[1] == '/game/construct-tab_btn/top_tab_btn_up_bmp.dds',
    'layout switch relays existing tabs back to right-side assets and anchors')
assert(controls.choices.DisplayData[1].type == 'item' and controls.choices.Items[1].Icon.texture,
    'actual grid model item shape renders through the item renderer')
assert(controls.secondaryChoices._vertical, 'queue mode retains the base grid orientation')

currentQueue = {
    { type = 'queuestack', id = 'uel0001', count = 3 },
    { type = 'enhancementqueue', id = 'uel0001', icon = 'enh-icon', name = 'Queued enhancement', enhancement = 'Enh' },
}
assert(root:Update('queue'), 'queue update passes the native-shaped queue into the real queue model')
local queueGrid = controls.secondaryChoices
assert(queueGrid.DisplayData[1].kind == 'factory' and queueGrid.Items[1].tooltipID ~= nil,
    'factory model entry is adapted into a rendered queue cell')
assert(queueGrid.DisplayData[2].kind == 'enhancement' and queueGrid.Items[2].tooltipID == 'Queued enhancement',
    'enhancement queue model entry is adapted to enhancementqueue renderer')
queueGrid.Items[1].OnClick(queueGrid.Items[1], {})
assert(clickData ~= queueGrid.DisplayData[1] and clickData.type == 'queuestack'
    and clickData.kind == 'factory' and clickData.sourceIndex == 1,
    'queue click receives a typed copy preserving the original model metadata')
queueGrid.Items[1].HandleEvent(queueGrid.Items[1], { Type = 'MouseEnter' })
assert(rolloverEvent and rolloverEvent.data.type == 'queuestack'
    and rolloverEvent.data.kind == 'factory' and rolloverEvent.active,
    'rollover receives the typed queue row and state')

assert(root.ClaretConstructionFacade, 'facade remains on the shell root')
assert(controls.selectionTab.OnCheck(controls.selectionTab, true), 'selection tab binds to controller.SetTab')
assert(not controls.tabsByKey['tech:t1'] and not controls.tabsByKey['tech:t2'],
    'switching away from construction removes stale tech tabs')
assert(not queueGrid._vertical and queueGrid.DisplayData[1].type == 'claretCargo',
    'selection mode switches the shared secondary grid to cargo')
assert(queueGrid.Items[1].Data.unit == passengerA and not queueGrid.Items[1].overrideEnabled,
    'cargo row is rendered as its own passenger')
assert(root:GetHandler('TransportCargo'):AppendNextUnitForDrop(), 'facade cargo action appends the next passenger')
assert(state:IsSelected(1) and queueGrid.Items[1].overrideEnabled,
    'cargo append updates the visible selected highlight')
queueGrid.Items[2].OnClick(queueGrid.Items[2], {})
assert(state:IsSelected(2) and added[2] == passengerB, 'cargo cell click toggles the real cargo state')

assert(controls.constructionTab.OnCheck(controls.constructionTab, true), 'construction tab reactivates queue display')
assert(controls.tabsByKey['tech:t1'] and controls.tabsByKey['tech:t2'], 'construction restores eligible tech tabs')
assert(queueGrid._vertical and queueGrid.DisplayData[1].kind == 'factory'
    and queueGrid.DisplayData[2].kind == 'enhancement',
    'cargo renderer deactivates before queue rows are restored to the shared grid')
assert(queueGrid.Items[1].tooltipID ~= nil and queueGrid.Items[2].tooltipID == 'Queued enhancement',
    'queue renderer redraws both reused cells after cargo mode')

local primaryRefresh = controls.choices.Refresh
controls.choices.Refresh = function() error('primary grid refresh failed') end
assert(not controls.selectionTab.OnCheck(controls.selectionTab, true),
    'tab switch reports a rejected controller render')
assert(controls.constructionTab.checked and not controls.selectionTab.checked,
    'failed tab render restores the last successfully active checkbox')
controls.choices.Refresh = primaryRefresh
assert(controls.constructionTab.OnCheck(controls.constructionTab, true),
    'tab selection recovers after view rendering succeeds')

assert(controls.enhancementTab.OnCheck(controls.enhancementTab, true), 'enhancement tab renders available slots')
assert(controls.tabsByKey['enhancement:Back'] and controls.tabsByKey['enhancement:LCH'],
    'enhancement slot tabs follow the enhancement model metadata')
assert(controls.tabsByKey['enhancement:LCH'].OnCheck(controls.tabsByKey['enhancement:LCH'], true)
    and panel.controller.enhancementSlot == 'LCH', 'enhancement slot tab delegates to the controller')
assert(controls.tabsByKey['enhancement:LCH'].checked, 'selected enhancement slot is visibly checked')
assert(not controls.tabsByKey['tech:t1'] and not controls.tabsByKey['tech:t2'],
    'enhancement mode removes tech tabs')
assert(controls.tabsByKey['enhancement:LCH'].textures[1] == '/game/construct-tech_btn/left_upgrade_btn_up.dds',
    'enhancement slot texture follows the stock slot ID mapping')
assert(controls.constructionTab.OnCheck(controls.constructionTab, true),
    'construction mode can be restored after enhancement slot selection')

assert(panel.controller:SelectTech('templates'), 'template view is selectable by the controller')
assert(controls.tabsByKey['tech:templates'] and controls.tabsByKey['tech:templates'].checked,
    'template tab remains visible and checked in template mode')
assert(controls.choices.DisplayData[1] == templateRow
    and controls.choices.DisplayData[1].sourceSnapshot == templateRow.sourceSnapshot,
    'template model row and sourceSnapshot pass through unchanged')

local factoryEngineer = { isFactory = true, categories = { MOBILE = true, STRUCTURE = false, FACTORY = true, EXTERNALFACTORY = false } }
assert(root:OnSelectionChanged({ factoryEngineer }), 'factory selection refreshes template eligibility')
assert(controls.tabsByKey['tech:templates'] and controls.tabsByKey['tech:templates'].shown,
    'factory template tab is visible when factory model rows are eligible')
assert(controls.tabsByKey['tech:templates'].checked and controls.choices.DisplayData[1] == factoryTemplateRow,
    'factory selection renders rows from the factory template source and keeps its tab checked')
assert(root:OnSelectionChanged(selection), 'mobile selection restores after factory eligibility check')
noTemplates = true
assert(root:OnSelectionChanged(selection), 'selection refreshes after template source empties')
assert(not controls.tabsByKey['tech:templates'] and table.getn(controls.choices.DisplayData) == 0,
    'template tab is removed when the actual model has no eligible mobile rows')
noTemplates = false
assert(root:OnSelectionChanged(selection), 'eligible mobile templates restore after source recovery')

failBuildables = true
assert(not root:OnSelectionChanged(selection), 'failed adapter invalidates the old selection')
assert(#panel.controller.selection == 0 and not panel.controller.hasValidSelection)
assert(not controls.tabsByKey['tech:t1'] and not controls.tabsByKey['tech:t2']
    and not controls.tabsByKey['enhancement:Back'] and not controls.tabsByKey['enhancement:LCH'],
    'failed selection clears every stale nested tab')
local appendCount = #added
assert(not root:GetHandler('TransportCargo'):AppendNextUnitForDrop() and #added == appendCount,
    'stale transport action cannot append from prior selection')

failBuildables = false
assert(root:OnSelectionChanged(selection), 'valid selection can be restored after adapter recovery')
assert(controls.selectionTab.OnCheck(controls.selectionTab, true))
assert(root:GetHandler('TransportCargo'):AppendNextUnitForDrop(), 'owned cargo exists before teardown test')
failRemoval = true

local primaryGrid, secondaryGrid = controls.choices, controls.secondaryChoices
local basePrimaryCreate = primaryGrid._baseMethods.CreateElement
local baseSecondaryCreate = secondaryGrid._baseMethods.CreateElement
assert(not panel:Destroy(), 'failed cargo cleanup defers explicit panel destruction')
assert(not panel.destroyed and not root.destroyed and root.GetHandler ~= nil,
    'failed cleanup keeps root, facade, controller, and views alive for retry')
assert(not root:GetHandler('TransportCargo'):AppendNextUnitForDrop(),
    'teardown-pending controller rejects further cargo actions while remaining retryable')
failRemoval = false
assert(#removed == 2, 'failed removal retains ownership until the successful retry')
assert(panel:Destroy(), 'panel teardown succeeds after cargo removal recovers')
assert(panel.destroyed and panel.root == nil and controls.root == nil)
assert(primaryGrid.CreateElement == basePrimaryCreate and secondaryGrid.CreateElement == baseSecondaryCreate
    and primaryGrid.SetControlToType == primaryGrid._baseMethods.SetControlToType
    and secondaryGrid.SetControlToType == secondaryGrid._baseMethods.SetControlToType,
    'reverse teardown restores both caller grid renderer chains')
assert(root.destroyed and not root.ClaretConstructionFacade, 'assembly destroys its own root and clears facade state')
assert(state.destroyed and #removed == 3, 'controller cleanup releases owned transport selections')
assert(root.GetHandler == nil, 'destroyed root no longer carries the facade handler')
assert(panel:Destroy(), 'panel teardown is idempotent after external root destruction')
print('PASS: assembled construction panel renders construction, queue, cargo, templates, failures, and teardown')

