-- Original stock-style renderer for FAF SpecialGrid construction data.
-- Command execution and game orders are deliberately left to injected callbacks.

local ButtonModule = import('/lua/maui/button.lua')
local Button = ButtonModule.FixableButton
local BaseButton = ButtonModule.Button
local Bitmap = import('/lua/maui/bitmap.lua').Bitmap
local UIUtil = import('/lua/ui/uiutil.lua')
local LayoutFor = ReUI.UI.FloorLayoutFor
local DiskGetFileInfo = rawget(_G, 'DiskGetFileInfo') or UIUtil.DiskGetFileInfo

local SupportedTypes = {
    item = true,
    unitstack = true,
    queuestack = true,
    enhancementqueue = true,
    enhancement = true,
    templates = true,
    spacer = true,
    arrow = true,
    attachedunit = true,
}

local function UnitBlueprint(id)
    local blueprints = rawget(_G, '__blueprints')
    if not blueprints or not id then return nil end
    return blueprints[id]
end

local function ExistingTexture(path)
    local texture = UIUtil.UIFile(path, true)
    if type(DiskGetFileInfo) == 'function' and DiskGetFileInfo(texture) then
        return texture
    end
    return nil
end

local function UnitCategory(id)
    local blueprint = UnitBlueprint(id)
    local icon = blueprint and blueprint.General and blueprint.General.Icon
    if icon == 'air' or icon == 'sea' or icon == 'amph' then return icon end
    return 'land'
end

local function UnitIcon(id)
    return ExistingTexture('/icons/units/' .. tostring(id or 'default') .. '_icon.dds')
        or UIUtil.UIFile('/icons/units/default_icon.dds')
end

local function UnitBackground(id)
    local prefix = '/icons/units/' .. UnitCategory(id) .. '_'
    return UIUtil.UIFile(prefix .. 'up.dds'),
        UIUtil.UIFile(prefix .. 'down.dds'),
        UIUtil.UIFile(prefix .. 'over.dds'),
        UIUtil.UIFile(prefix .. 'up.dds')
end

local function EnhancementTextures(unitID, iconID)
    local faction = type(unitID) == 'string' and string.sub(unitID, 2, 2) or ''
    local folder
    if faction == 'a' then folder = 'aeon'
    elseif faction == 'e' then folder = 'uef'
    elseif faction == 'r' then folder = 'cybran'
    elseif faction == 's' then folder = 'seraphim'
    else return nil end

    local prefix = '/game/' .. folder .. '-enhancements/' .. tostring(iconID or '')
    return ExistingTexture(prefix .. '_btn_up.dds') or UIUtil.UIFile(prefix .. '_btn_up.dds'),
        ExistingTexture(prefix .. '_btn_down.dds') or UIUtil.UIFile(prefix .. '_btn_down.dds'),
        ExistingTexture(prefix .. '_btn_over.dds') or UIUtil.UIFile(prefix .. '_btn_over.dds'),
        ExistingTexture(prefix .. '_btn_up.dds') or UIUtil.UIFile(prefix .. '_btn_up.dds'),
        ExistingTexture(prefix .. '_btn_sel.dds') or UIUtil.UIFile(prefix .. '_btn_sel.dds')
end

local function LocalizedDescription(id)
    local blueprint = UnitBlueprint(id)
    if not blueprint or not blueprint.Description then return '' end
    local localize = rawget(_G, 'LOC')
    if type(localize) == 'function' then
        local ok, result = pcall(localize, blueprint.Description)
        if ok and result then return result end
    end
    return blueprint.Description
end

local function SetCount(control, value, color)
    if value == nil or value == '' or value == 0 then
        control.Count:SetText('')
        return
    end
    control.Count:SetText(tostring(value))
    control.Count:SetColor(color or 'ffffffff')
end

local function StackCount(data)
    if data.count ~= nil then return data.count end
    if type(data.units) == 'table' and table.getn(data.units) > 1 then
        return table.getn(data.units)
    end
    return nil
end

local function ResetAuxiliary(control)
    control.tooltipID = nil
    control.BuildKey = nil
    control._constructionItemsData = nil
    control:SetOverrideEnabled(false)
    if control._constructionItemsHandleEvent then
        control.HandleEvent = control._constructionItemsHandleEvent
    end
    control.Count:SetText('')
    control.StratIcon:SetSolidColor('00000000')
    control.StratIcon:Hide()
    control.LowFuel:SetAlpha(0, true)
    control.LowFuel:SetNeedsFrameUpdate(false)
    control.LowFuelIcon:SetAlpha(0, true)
    control.LowFuelIcon:Hide()
end

local function SetStrategicIcon(control, id)
    local blueprint = UnitBlueprint(id)
    local name = blueprint and blueprint.StrategicIconName
    if not name then
        control.StratIcon:SetSolidColor('00000000')
        control.StratIcon:Hide()
        return
    end
    local path = '/textures/ui/common/game/strategicicons/' .. name .. '_rest.dds'
    if type(DiskGetFileInfo) == 'function' and DiskGetFileInfo(path) then
        control.StratIcon:SetSolidColor('ffffffff')
        control.StratIcon:SetTexture(path)
        local width = control.StratIcon.BitmapWidth()
        local height = control.StratIcon.BitmapHeight()
        LayoutFor(control.StratIcon):Width(width):Height(height)
        control.StratIcon:Show()
    else
        control.StratIcon:SetSolidColor('00000000')
        control.StratIcon:Hide()
    end
end

local function SetUnitIcon(control, id)
    control.Icon:SetSolidColor('ffffffff')
    control.Icon:SetTexture(UnitIcon(id))
    SetStrategicIcon(control, id)
end

local function SetEnhancement(control, data, queued)
    local up, down, over, disabled, selected = EnhancementTextures(data.unitID, data.icon)
    if not up then
        up, down, over, disabled = UnitBackground(nil)
        selected = down
        control:SetNewTextures(up, down, over, disabled)
        control:SetOverrideEnabled(false)
        control.Icon:SetSolidColor('00000000')
        control:Enable()
        return
    end

    control:SetNewTextures(up, down, over, disabled)
    control:SetOverrideTexture(queued and up or selected)
    control:SetOverrideEnabled(not queued and data.Selected == true)
    control.Icon:SetSolidColor('00000000')
    control.StratIcon:SetSolidColor('00000000')
    control.StratIcon:Hide()
    if not queued and data.Disabled and not data.Selected then
        control.Icon:SetSolidColor('aa000000')
    end
    control.tooltipID = queued and (data.name or '')
        or (data.enhTable and data.enhTable.Name) or ''
    control:Enable()
end

local function RenderControl(control, itemType, data, grid, callbacks)
    ResetAuxiliary(control)
    control._constructionItemsData = data
    control:SetSolidColor('00000000')
    control.Icon:SetSolidColor('00000000')

    if itemType == 'spacer' or itemType == 'arrow' then
        local vertical = grid._vertical == true
        local width = vertical and 48 or 20
        local height = vertical and 20 or 48
        LayoutFor(control):Width(width):Height(height)
        if itemType == 'spacer' then
            local path = vertical and '/game/c-q-e-panel/divider_horizontal_bmp.dds'
                or '/game/c-q-e-panel/divider_bmp.dds'
            control.Icon:SetTexture(UIUtil.UIFile(path))
        else
            local path = vertical and '/game/c-q-e-panel/arrow_vert_bmp.dds'
                or '/game/c-q-e-panel/arrow_bmp.dds'
            control.Icon:SetTexture(UIUtil.UIFile(path))
            LayoutFor(control.Icon):Width(vertical and 48 or 30):Height(height)
        end
        control.Icon:SetSolidColor('ffffffff')
        control.Count:SetText('')
        control.StratIcon:SetSolidColor('00000000')
        control:Disable()
        return
    end

    LayoutFor(control):Width(48):Height(48)
    LayoutFor(control.Icon):Width(48):Height(48)
    control.Icon:Show()
    control:Enable()

    if itemType == 'item' or itemType == 'unitstack' or itemType == 'queuestack' or itemType == 'attachedunit' then
        local id = data.id
        local up, down, over, disabled = UnitBackground(id)
        control:SetNewTextures(up, down, over, disabled)
        SetUnitIcon(control, id)
        control.tooltipID = LocalizedDescription(id)
        if itemType == 'item' then
            control.BuildKey = data.BuildKey or data.key
            SetCount(control, control.BuildKey or data.count, 'ffff9000')
        else
            SetCount(control, StackCount(data), 'ffffffff')
        end
        if data.lowFuel == true then
            control.LowFuel:SetAlpha(0.25, true)
            control.LowFuelIcon:SetAlpha(1, true)
            control.LowFuelIcon:Show()
        end
        return
    end

    if itemType == 'enhancementqueue' then
        SetEnhancement(control, data, true)
        control.Count:SetText('')
        return
    end

    if itemType == 'enhancement' then
        SetEnhancement(control, data, false)
        control.Count:SetText('')
        return
    end

    if itemType == 'templates' then
        local template = data.template or {}
        local id = template.icon
        local up, down, over, disabled = UnitBackground(id)
        control:SetNewTextures(up, down, over, disabled)
        if id then
            SetUnitIcon(control, id)
        else
            control.Icon:SetSolidColor('ffffffff')
            control.Icon:SetTexture(UIUtil.UIFile('/icons/units/default_icon.dds'))
        end
        control.tooltipID = template.name or ''
        control.BuildKey = template.key
        if template.key then
            local ok, key = pcall(string.char, template.key)
            SetCount(control, ok and key or '', 'ffff9000')
        end
        return
    end

    control:Disable()
end

local function EnsureComponents(control)
    if not control.Icon then
        control.Icon = Bitmap(control)
        control.Icon:DisableHitTest()
        LayoutFor(control.Icon):AtCenterIn(control):Width(48):Height(48)
    end
    if not control.StratIcon then
        control.StratIcon = Bitmap(control.Icon)
        control.StratIcon:DisableHitTest()
        LayoutFor(control.StratIcon):AtLeftTopIn(control.Icon, 4, 4):Width(20):Height(20)
    end
    if not control.Count then
        control.Count = UIUtil.CreateText(control.Icon, '', 20, UIUtil.bodyFont)
        control.Count:SetColor('ffffffff')
        control.Count:SetDropShadow(true)
        control.Count:DisableHitTest()
        LayoutFor(control.Count):AtBottomIn(control, 4):AtRightIn(control, 3)
    end
    if not control.LowFuel then
        control.LowFuel = Bitmap(control)
        control.LowFuel:SetSolidColor('ffff0000')
        control.LowFuel:DisableHitTest()
        LayoutFor(control.LowFuel):Fill(control)
        control.LowFuel:SetAlpha(0, true)
        control.LowFuel:SetNeedsFrameUpdate(false)
    end
    if not control.LowFuelIcon then
        control.LowFuelIcon = Bitmap(control.LowFuel, UIUtil.UIFile('/game/unit_view_icons/fuel.dds'))
        control.LowFuelIcon:DisableHitTest()
        LayoutFor(control.LowFuelIcon):AtLeftBottomIn(control, 4, 4)
        control.LowFuelIcon:SetAlpha(0, true)
        control.LowFuelIcon:Hide()
    end
end

local function CreateView(grid, options)
    if not grid then error('ConstructionItemsView.Create requires a caller-owned SpecialGrid') end
    if type(grid.CreateElement) ~= 'function' or type(grid.SetControlToType) ~= 'function' then
        error('ConstructionItemsView requires configured SpecialGrid CreateElement and SetControlToType')
    end
    options = options or {}
    local onClick = options.OnClick
    local onRollover = options.OnRollover
    local state = { grid = grid, destroyed = false, lastDisplayData = nil }
    local baseCreateElement = grid.CreateElement
    local baseSetControlToType = grid.SetControlToType
    local baseDisplayData = grid.DisplayData
    local createdElement
    local renderedType

    local function NewElement()
        local control = baseCreateElement()
        if not control then
            control = Button(grid)
        end
        EnsureComponents(control)
        control._constructionItemsBaseOnClick = control.OnClick
        local baseHandleEvent = control.HandleEvent
        control.HandleEvent = function(self, event)
            local data = self._constructionItemsData
            if data and type(onRollover) == 'function' then
                if event.Type == 'MouseEnter' then onRollover(data, true)
                elseif event.Type == 'MouseExit' then onRollover(data, false) end
            end
            if baseHandleEvent then return baseHandleEvent(self, event) end
            if BaseButton and BaseButton.HandleEvent then return BaseButton.HandleEvent(self, event) end
        end
        control._constructionItemsHandleEvent = control.HandleEvent
        return control
    end

    createdElement = function()
        return NewElement()
    end

    local function AdaptData(data)
        if type(options.AdaptData) == 'function' then
            local adapted = options.AdaptData(data)
            if adapted then return adapted end
        end
        return data
    end

    renderedType = function(control, itemType)
        local originalData = control.Data
        local data = AdaptData(originalData)
        local renderType = data and data.type or itemType
        if SupportedTypes[renderType] then
            if not control.Icon or not control.Count or not control.LowFuel then EnsureComponents(control) end
            control.OnClick = function(self, modifiers)
                if not state.destroyed and type(onClick) == 'function' then
                    onClick(self.Data, modifiers)
                end
            end
            state.lastDisplayData = grid.DisplayData
            RenderControl(control, renderType, data, grid, options)
            control._constructionItemsData = originalData
            return
        end

        control._constructionItemsData = nil
        if control._constructionItemsBaseOnClick then
            control.OnClick = control._constructionItemsBaseOnClick
        end
        control:SetOverrideEnabled(false)
        if control._constructionItemsHandleEvent then
            control.HandleEvent = control._constructionItemsHandleEvent
        end
        baseSetControlToType(control, itemType)
        if control.OnClick ~= nil then
            control._constructionItemsBaseOnClick = control.OnClick
        end
    end

    grid.CreateElement = createdElement
    grid.SetControlToType = renderedType

    local function DisplayIsOwned(data)
        if type(data) ~= 'table' or data ~= state.lastDisplayData then return false end
        for _, item in ipairs(data) do
            local adapted = AdaptData(item)
            if not adapted or not SupportedTypes[adapted.type] then return false end
        end
        return true
    end

    function state:Destroy(replacementData)
        if self.destroyed then return true end
        if grid.CreateElement ~= createdElement or grid.SetControlToType ~= renderedType then
            return false, 'SpecialGrid renderers are wrapped or replaced; deactivate dependent views first'
        end

        if DisplayIsOwned(grid.DisplayData) then
            grid:ClearItems()
            grid:Refresh(replacementData or {})
        end
        grid.CreateElement = baseCreateElement
        grid.SetControlToType = baseSetControlToType
        self.destroyed = true
        return true
    end

    return state
end

function Create(grid, options)
    return CreateView(grid, options)
end
