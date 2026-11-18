-- Construction panel shell control ownership and lifecycle tests.
table.getn = table.getn or function(value) return #value end
local created = {}
local function Depth()
    return setmetatable({ value = 0, Set = function(depth, value) depth.value = value end }, {
        __call = function(depth) return type(depth.value) == 'function' and depth.value() or depth.value end,
    })
end
local function control(kind, parent)
    local value = { kind = kind, parent = parent, children = {}, destroyed = false }
    value.Depth = Depth()
    if parent and parent.children then table.insert(parent.children, value) end
    function value:SetDimensions(width, height) self.width, self.height = width, height end
    function value:Destroy()
        if self.OnDestroy then self:OnDestroy() end
        self.destroyed = true
    end
    function value:Refresh(items) self.lastItems = items end
    function value:CalcVisible() self.calculated = true end
    function value:Show() self.shown = true end
    function value:Hide() self.shown = false end
    function value:SetNewTextures(...) self.textures = { ... } end
    function value:UseAlphaHitTest(value) self.alphaHitTest = value end
    function value:SetCheck(checked) self._checkState = checked and 'checked' or 'unchecked' end
    function value:ToggleCheck()
        self._checkState = self._checkState == 'checked' and 'unchecked' or 'checked'
        if self.OnCheck then self:OnCheck(self, self._checkState == 'checked') end
    end
    created[#created + 1] = value
    return value
end
local factories = {
    group = function(parent) return control('group', parent) end,
    bitmap = function(parent) return control('bitmap', parent) end,
    button = function(parent) return control('button', parent) end,
    checkbox = function(parent) return control('checkbox', parent) end,
    grid = function(parent, auto) return control('grid', parent) end,
    statusBar = function(parent) return control('statusbar', parent) end,
    createStatusBar = function(parent) return control('statusbar', parent) end,
}
local sharedControls = { marker = true }
local layoutHelpers = {}
for _, method in ipairs({ 'AtCenterIn', 'AtLeftTopIn', 'Below', 'RightOf' }) do
    layoutHelpers[method] = function(control, target, x, y)
        control.layout = { method = method, target = target, x = x, y = y }
    end
end
layoutHelpers.SetDimensions = function(control, width, height) control:SetDimensions(width, height) end
local env = setmetatable({ controls = sharedControls }, { __index = _G })
assert(loadfile('../mods/ClaretCore/modules/ConstructionPanelShell.lua', 't', env))()
local parent = control('parent', nil)
local panel = env.Create(parent, { factories = factories, width = 640, height = 200,
    uiFile = function(path) return path end, layoutHelpers = layoutHelpers, tabLayout = 'left' })

assert(panel.root == panel.constructionGroup and panel.root.parent == parent)
assert(panel.root.width == 640 and panel.root.height == 200, 'optional shell geometry is applied to owned root')
assert(panel.minBG.kind == 'bitmap' and panel.midBG3.kind == 'bitmap' and panel.maxBG.kind == 'bitmap')
assert(panel.choices.kind == 'grid' and panel.secondaryChoices.kind == 'grid')
assert(panel.choices.parent == panel.root and panel.secondaryChoices.parent == panel.root)
assert(panel.scrollMin.parent == panel.choices and panel.pageMax.parent == panel.choices)
assert(panel.secondaryScrollMin.parent == panel.secondaryChoices
    and panel.secondaryPageMax.parent == panel.secondaryChoices)
assert(panel.constructionTab.ID == 'construction' and panel.selectionTab.ID == 'selection'
    and panel.enhancementTab.ID == 'enhancement')
assert(panel.constructionTab.textures[1] == '/game/construct-tab_top_btn/top_tab_btn_up_bmp.dds'
    and panel.constructionTab.textures[2] == '/game/construct-tab_top_btn/top_tab_btn_sel_bmp.dds'
    and panel.constructionTab.textures[6] == '/game/construct-tab_top_btn/top_tab_btn_dis_bmp.dds'
    and panel.enhancementTab.textures[1] == '/game/construct-tab_top_btn/bot_tab_btn_up_bmp.dds',
    'main tabs use the native state texture contract')
assert(panel.constructionTab.layout.method == 'AtLeftTopIn'
    and panel.selectionTab.layout.method == 'RightOf' and panel.enhancementTab.layout.target == panel.selectionTab,
    'left-side main tabs use stock horizontal anchors')
assert(panel.constructionTab.Depth() == panel.root.Depth() + 10
    and panel.constructionTab.disabledGroup.Depth() == panel.constructionTab.Depth() + 1,
    'main tab and disabled overlay use the native depth contract')
assert(next(panel.tabs) == nil, 'shell does not create model-dependent tabs before eligibility is known')
local techOne = panel:CreateNestedTab('tech', 't1')
local techTwo = panel:CreateNestedTab('tech', 't2')
assert(techOne.textures[1] == '/game/construct-tech_btn/t1_btn_up.dds'
    and techTwo.layout.method == 'Below' and techOne.layout.target == panel.minBG,
    'left-side nested tabs use native tech textures and vertical anchors')
assert(techOne.disabledGroup.width == 40 and techOne.disabledGroup.height == 25
    and techOne.disabledGroup.Depth() == techOne.Depth() + 1,
    'nested disabled overlay matches stock size and depth')
panel:ClearNestedTabs('tech')
assert(techOne.disabledGroup.Depth.value == 1, 'destroyed nested tab resets overlay depth to avoid frame errors')
local slot = panel:CreateNestedTab('enhancement', 'Back')
assert(slot.textures[1] == '/game/construct-tech_btn/m_upgrade_btn_up.dds',
    'back slot uses the native enhancement texture')
assert(panel.tabsByKey['enhancement:Back'] == slot and panel.tabs[1] == slot,
    'shell preserves deterministic control order and indexes nested controls by kind and ID')
assert(panel:SetTabLayout('right') and panel.constructionTab.textures[1] == '/game/construct-tab_btn/top_tab_btn_up_bmp.dds'
    and slot.layout.method == 'AtLeftTopIn' and slot.layout.target == panel.minBG,
    'layout switch refreshes current tab textures and right-side anchors')
assert(panel:SetTabLayout('mini') and slot.layout.method == 'AtLeftTopIn',
    'mini layout is exposed and applies right-side tab geometry')
panel.constructionTab._checkState = 'checked'
panel.constructionTab.OnClick(panel.constructionTab)
assert(panel.constructionTab._checkState == 'checked', 'active tab click cannot uncheck the tab')
assert(panel.constructionTab.OnCheck == nil and panel.choices.Refresh ~= nil,
    'controller remains responsible for tab callbacks and grid data')
assert(sharedControls.marker and sharedControls.constructionGroup == nil,
    'shell does not modify shared global controls')

local changedTab = 0
panel.constructionTab.OnCheck = function() changedTab = changedTab + 1 end
panel.choices:Refresh({ { id = 'unit' } })
assert(panel.choices.lastItems[1].id == 'unit', 'controller can attach callbacks and grid behavior')
assert(changedTab == 0, 'shell does not invoke controller callbacks during construction')

panel:Destroy()
assert(panel.root == nil and panel.constructionGroup == nil)
assert(created[2].destroyed, 'destroying the owned root invokes its Maui cleanup')
panel:Destroy()
assert(sharedControls.marker and sharedControls.constructionGroup == nil, 'destroy is idempotent and isolated')

print('PASS: construction panel shell fields, callback ownership, geometry and cleanup')
