-- Own, unregistered control shell for a future construction HUD.
-- Controller callbacks and grid data methods are deliberately left to the caller.

local function ResolveFactory(options, key, path, symbol)
    local supplied = options.factories and options.factories[key]
    if supplied then return supplied end
    local module = import(path)
    return module[symbol]
end

function Create(parent, options)
    options = options or {}
    local Group = ResolveFactory(options, 'group', '/lua/maui/group.lua', 'Group')
    local Bitmap = ResolveFactory(options, 'bitmap', '/lua/maui/bitmap.lua', 'Bitmap')
    local Button = ResolveFactory(options, 'button', '/lua/maui/button.lua', 'Button')
    local Checkbox = ResolveFactory(options, 'checkbox', '/lua/maui/checkbox.lua', 'Checkbox')
    local Grid = ResolveFactory(options, 'grid', '/lua/ui/controls/specialgrid.lua', 'SpecialGrid')
    local StatusBar = ResolveFactory(options, 'statusBar', '/lua/maui/statusbar.lua', 'StatusBar')
    local uiFile = options.uiFile or import('/lua/ui/uiutil.lua').UIFile
    local LayoutHelpers = options.layoutHelpers or import('/lua/maui/layouthelpers.lua')
    local tabLayout = options.tabLayout or 'right'
    local mainTabNames = {
        construction = 'top_tab_btn_',
        selection = 'mid_tab_btn_',
        enhancement = 'bot_tab_btn_',
    }
    local nestedTabFiles = {
        t1 = '/game/construct-tech_btn/t1_btn_',
        t2 = '/game/construct-tech_btn/t2_btn_',
        t3 = '/game/construct-tech_btn/t3_btn_',
        t4 = '/game/construct-tech_btn/t4_btn_',
        templates = '/game/construct-tech_btn/template_btn_',
        LCH = '/game/construct-tech_btn/left_upgrade_btn_',
        RCH = '/game/construct-tech_btn/r_upgrade_btn_',
        Back = '/game/construct-tech_btn/m_upgrade_btn_',
    }

    local function SetTabTextures(tab, id, main)
        local prefix
        if main then
            local directory = tabLayout == 'left' and '/game/construct-tab_top_btn/' or '/game/construct-tab_btn/'
            prefix = directory .. mainTabNames[id]
        else
            prefix = nestedTabFiles[id]
        end
        if not prefix or not tab.SetNewTextures then return false end
        if main then
            tab:SetNewTextures(uiFile(prefix .. 'up_bmp.dds'), uiFile(prefix .. 'sel_bmp.dds'),
                uiFile(prefix .. 'over_bmp.dds'), uiFile(prefix .. 'down_bmp.dds'),
                uiFile(prefix .. 'dis_bmp.dds'), uiFile(prefix .. 'dis_bmp.dds'))
        else
            tab:SetNewTextures(uiFile(prefix .. 'up.dds'), uiFile(prefix .. 'selected.dds'),
                uiFile(prefix .. 'over.dds'), uiFile(prefix .. 'down.dds'),
                uiFile(prefix .. 'dis.dds'), uiFile(prefix .. 'dis.dds'))
        end
        if tab.UseAlphaHitTest then tab:UseAlphaHitTest(false) end
        return true
    end

    local SetTabDepth

    local function SetupMainTabs(controls)
        for _, name in ipairs({ 'construction', 'selection', 'enhancement' }) do
            local tab = controls[name .. 'Tab']
            SetTabTextures(tab, name, true)
            SetTabDepth(tab, controls.constructionGroup)
            if tab.disabledGroup then
                LayoutHelpers.SetDimensions(tab.disabledGroup, 40, 25)
                LayoutHelpers.AtCenterIn(tab.disabledGroup, tab)
            end
            if tabLayout == 'left' then
                if name == 'construction' then LayoutHelpers.AtLeftTopIn(tab, controls.constructionGroup, 20, 7)
                else LayoutHelpers.RightOf(tab, controls[(name == 'selection' and 'construction' or 'selection') .. 'Tab'], 0) end
            else
                if name == 'construction' then LayoutHelpers.AtLeftTopIn(tab, controls.constructionGroup, 0, 14)
                else LayoutHelpers.Below(tab, controls[(name == 'selection' and 'construction' or 'selection') .. 'Tab'], -16) end
            end
        end
    end

    local function PlaceNestedTab(controls, tab, previous)
        if tabLayout == 'left' then
            if previous then LayoutHelpers.Below(tab, previous, 0)
            else LayoutHelpers.AtLeftTopIn(tab, controls.minBG, 134, 60) end
        else
            if previous then LayoutHelpers.RightOf(tab, previous, 0)
            else LayoutHelpers.AtLeftTopIn(tab, controls.minBG, 82, 0) end
        end
        if tab.disabledGroup then
            LayoutHelpers.SetDimensions(tab.disabledGroup, 40, 25)
            LayoutHelpers.AtCenterIn(tab.disabledGroup, tab)
        end
    end

    SetTabDepth = function(tab, owner)
        if tab.Depth and tab.Depth.Set then tab.Depth:Set(function() return owner.Depth() + 10 end) end
        if tab.disabledGroup and tab.disabledGroup.Depth and tab.disabledGroup.Depth.Set and tab.Depth then
            tab.disabledGroup.Depth:Set(function() return tab.Depth() + 1 end)
        end
        tab.OnClick = function(self)
            if self._checkState ~= 'checked' and self.ToggleCheck then self:ToggleCheck() end
        end
        local previousOnDestroy = tab.OnDestroy
        tab.OnDestroy = function(self, ...)
            if self.disabledGroup and self.disabledGroup.Depth and self.disabledGroup.Depth.Set then
                self.disabledGroup.Depth:Set(1)
            end
            if type(previousOnDestroy) == 'function' then return previousOnDestroy(self, ...) end
        end
    end

    local root = Group(parent)
    if options.width and options.height and root.SetDimensions then
        root:SetDimensions(options.width, options.height)
    end
    local controls = { root = root, constructionGroup = root, tabs = {}, tabsByKey = {} }

    controls.minBG = Bitmap(root)
    controls.maxBG = Bitmap(root)
    controls.midBG1 = Bitmap(root)
    controls.midBG2 = Bitmap(root)
    controls.midBG3 = Bitmap(root)

    controls.choices = Grid(root, false)
    controls.choicesBGMin = Bitmap(root)
    controls.choicesBGMid = Bitmap(root)
    controls.choicesBGMax = Bitmap(root)
    controls.scrollMin = Button(controls.choices)
    controls.scrollMax = Button(controls.choices)
    controls.scrollMinIcon = Button(controls.choices)
    controls.scrollMaxIcon = Button(controls.choices)
    controls.pageMin = Button(controls.choices)
    controls.pageMax = Button(controls.choices)
    controls.pageMinIcon = Button(controls.choices)
    controls.pageMaxIcon = Button(controls.choices)

    controls.secondaryChoices = Grid(root, false)
    controls.secondaryChoicesBGMin = Bitmap(root)
    controls.secondaryChoicesBGMid = Bitmap(root)
    controls.secondaryChoicesBGMax = Bitmap(root)
    controls.secondaryScrollMin = Button(controls.secondaryChoices)
    controls.secondaryScrollMax = Button(controls.secondaryChoices)
    controls.secondaryScrollMinIcon = Button(controls.secondaryChoices)
    controls.secondaryScrollMaxIcon = Button(controls.secondaryChoices)
    controls.secondaryPageMin = Button(controls.secondaryChoices)
    controls.secondaryPageMax = Button(controls.secondaryChoices)
    controls.secondaryPageMinIcon = Button(controls.secondaryChoices)
    controls.secondaryPageMaxIcon = Button(controls.secondaryChoices)

    controls.leftBracketMin = Bitmap(root)
    controls.leftBracketMax = Bitmap(root)
    controls.leftBracketMid = Bitmap(root)
    controls.rightBracketMin = Bitmap(root)
    controls.rightBracketMax = Bitmap(root)
    controls.rightBracketMid = Bitmap(root)
    controls.extraBtn1 = Checkbox(controls.minBG)
    controls.extraBtn1.icon = Bitmap(controls.extraBtn1)
    controls.extraBtn2 = Checkbox(controls.minBG)
    controls.extraBtn2.icon = Bitmap(controls.extraBtn2)

    local createStatusBar = options.factories and options.factories.createStatusBar
    if createStatusBar then
        controls.secondaryProgress = createStatusBar(controls.secondaryChoices)
    else
        controls.secondaryProgress = StatusBar(controls.secondaryChoices, 0, 1, false, false,
            uiFile('/game/unit-over/health-bars-back-1_bmp.dds'),
            uiFile('/game/unit-over/bar01_bmp.dds'), true, 'Construction queue progress')
    end

    local tabNames = { 'construction', 'selection', 'enhancement' }
    for _, name in ipairs(tabNames) do
        local tab = Checkbox(root)
        tab.ID = name
        tab.disabledGroup = Group(root)
        controls[name .. 'Tab'] = tab
    end
    SetupMainTabs(controls)

    function controls:CreateNestedTab(kind, id)
        local key = tostring(kind) .. ':' .. tostring(id)
        local tab = self.tabsByKey[key]
        if tab then return tab, key end
        tab = Checkbox(root)
        tab.ID = id
        tab.kind = kind
        tab:Show()
        tab.disabledGroup = Group(root)
        SetTabDepth(tab, root)
        SetTabTextures(tab, id, false)
        PlaceNestedTab(self, tab, self._lastNestedTab)
        self._lastNestedTab = tab
        self.tabsByKey[key] = tab
        table.insert(self.tabs, tab)
        return tab, key
    end

    function controls:DestroyNestedTab(key)
        local tab = self.tabsByKey[key]
        if not tab then return false end
        self.tabsByKey[key] = nil
        for index, orderedTab in ipairs(self.tabs) do
            if orderedTab == tab then table.remove(self.tabs, index); break end
        end
        tab.OnCheck = nil
        if not IsDestroyed or not IsDestroyed(tab) then tab:Destroy() end
        return true
    end

    function controls:ClearNestedTabs(kind)
        for index = table.getn(self.tabs), 1, -1 do
            local tab = self.tabs[index]
            if kind == nil or tab.kind == kind then
                self:DestroyNestedTab(tostring(tab.kind) .. ':' .. tostring(tab.ID))
            end
        end
        self._lastNestedTab = nil
        return true
    end

    function controls:SetTabLayout(layout)
        if layout ~= 'left' and layout ~= 'right' and layout ~= 'mini' then return false end
        tabLayout = layout
        SetupMainTabs(self)
        local previous
        for _, tab in ipairs(self.tabs) do
            SetTabTextures(tab, tab.ID, false)
            PlaceNestedTab(self, tab, previous)
            previous = tab
        end
        self._lastNestedTab = previous
        return true
    end

    function controls:SetNestedTabTextures(tab, prefix)
        if type(prefix) ~= 'string' or prefix == '' or not tab.SetNewTextures then return false end
        tab:SetNewTextures(
            uiFile(prefix .. 'up.dds'),
            uiFile(prefix .. 'selected.dds'),
            uiFile(prefix .. 'over.dds'),
            uiFile(prefix .. 'down.dds'),
            uiFile(prefix .. 'dis.dds'),
            uiFile(prefix .. 'dis.dds')
        )
        return true
    end

    local destroyed = false
    function controls:Destroy()
        if destroyed then return end
        destroyed = true
        if self.root and self.root.Destroy then self.root:Destroy() end
        self.root = nil
        self.constructionGroup = nil
        self.tabs, self.tabsByKey = {}, {}
    end

    return controls
end
