-- Adds cargo items to a caller-owned FAF SpecialGrid.
-- The grid owner remains responsible for layout, scroll controls, queue data,
-- and destroying the grid. This view temporarily installs renderers and restores
-- them on Deactivate/Destroy if they are still the active renderers.

local Bitmap = import('/lua/maui/bitmap.lua').Bitmap
local UIUtil = import('/lua/ui/uiutil.lua')
local LayoutFor = ReUI.UI.FloorLayoutFor
local DiskGetFileInfo = rawget(_G, 'DiskGetFileInfo') or UIUtil.DiskGetFileInfo

local CellSize = 48

local function CopyUnits(units)
    local result, seen = {}, {}
    if type(units) == 'table' then
        for _, unit in ipairs(units) do
            if unit ~= nil and not seen[unit] then
                seen[unit] = true
                table.insert(result, unit)
            end
        end
    end
    return result
end

local function GetUnitInfo(unit)
    local ok, blueprint = pcall(function() return unit:GetBlueprint() end)
    if not ok or not blueprint then return 'land', UIUtil.UIFile('/icons/units/default_icon.dds'), nil end

    local id = blueprint.BlueprintId or 'default'
    local category = blueprint.General and blueprint.General.Icon
    if category ~= 'land' and category ~= 'air' and category ~= 'sea' and category ~= 'amph' then
        category = 'land'
    end

    local icon = UIUtil.UIFile('/icons/units/' .. id .. '_icon.dds', true)
    if not DiskGetFileInfo or not DiskGetFileInfo(icon) then
        icon = UIUtil.UIFile('/icons/units/default_icon.dds')
    end
    return category, icon, blueprint
end

local function IsCargoDisplay(data)
    if type(data) ~= 'table' then return false end
    for _, item in ipairs(data) do
        if item.type ~= 'claretCargo' then return false end
    end
    return true
end

local function CreateView(parent, cargoState, options)
    if not parent then error('ConstructionCargoView.Create requires a parent control') end
    if not cargoState then error('ConstructionCargoView.Create requires cargoState') end
    options = options or {}
    local grid = options.grid
    if not grid then error('ConstructionCargoView.Create requires options.grid (a caller-owned FAF SpecialGrid)') end
    if type(grid.CreateElement) ~= 'function' or type(grid.SetControlToType) ~= 'function' then
        error('ConstructionCargoView requires a SpecialGrid with CreateElement and SetControlToType configured')
    end

    local state = {
        parent = parent,
        grid = grid,
        cargoState = cargoState,
        units = {},
        displayData = {},
        active = false,
        destroyed = false,
    }

    local baseCreateElement
    local baseSetControlToType
    local baseVertical
    local cargoCreateElement
    local cargoSetControlToType

    local function RenderCargo(cell, data)
        if not cell.Icon then
            cell.Icon = Bitmap(cell)
            cell.Icon:DisableHitTest()
            LayoutFor(cell.Icon):AtCenterIn(cell):Width(CellSize):Height(CellSize)
        end
        local category, icon, blueprint = GetUnitInfo(data.unit)
        local prefix = '/icons/units/' .. category .. '_'
        local up = UIUtil.UIFile(prefix .. 'up.dds')
        local down = UIUtil.UIFile(prefix .. 'down.dds')
        local over = UIUtil.UIFile(prefix .. 'over.dds')
        LayoutFor(cell):Width(CellSize):Height(CellSize)
        LayoutFor(cell.Icon):AtCenterIn(cell):Width(CellSize):Height(CellSize)
        if cell.SetSolidColor then cell:SetSolidColor('00000000') end
        if cell.Icon.SetSolidColor then cell.Icon:SetSolidColor('ffffffff') end
        if cell.Count then cell.Count:SetText('') end
        cell.tooltipID = blueprint and blueprint.Description or nil
        cell.BuildKey = nil
        cell._constructionItemsData = nil
        if cell.StratIcon then
            local strategicName = blueprint and blueprint.StrategicIconName
            local strategicPath = strategicName
                and ('/textures/ui/common/game/strategicicons/' .. strategicName .. '_rest.dds')
            if strategicPath and DiskGetFileInfo and DiskGetFileInfo(strategicPath) then
                cell.StratIcon:SetSolidColor('ffffffff')
                cell.StratIcon:SetTexture(strategicPath)
                LayoutFor(cell.StratIcon)
                    :Width(cell.StratIcon.BitmapWidth())
                    :Height(cell.StratIcon.BitmapHeight())
                cell.StratIcon:Show()
            else
                cell.StratIcon:SetSolidColor('00000000')
                cell.StratIcon:Hide()
            end
        end
        if cell.LowFuel then
            cell.LowFuel:SetAlpha(0, true)
            cell.LowFuel:SetNeedsFrameUpdate(false)
        end
        if cell.LowFuelIcon then
            cell.LowFuelIcon:SetAlpha(0, true)
            cell.LowFuelIcon:Hide()
        end
        cell:SetNewTextures(up, down, over, up)
        cell:Enable()
        cell.Icon:SetTexture(icon)
        cell.OnClick = function(self, modifiers)
            if not state.active or state.destroyed then return end
            local index = self.Data.index
            if modifiers and modifiers.Shift and cargoState.AddRange then
                cargoState:AddRange(index)
            elseif cargoState.Toggle then
                cargoState:Toggle(index)
            end
            state:Refresh()
        end

        local selected = cargoState.IsSelected and cargoState:IsSelected(data.index) or false
        if selected then
            cell:SetOverrideTexture(down)
            cell:SetOverrideEnabled(true)
        else
            cell:SetOverrideEnabled(false)
        end
    end

    local function InstallRenderers()
        if state.active then return end
        baseCreateElement = grid.CreateElement
        baseSetControlToType = grid.SetControlToType
        baseVertical = grid._vertical

        cargoCreateElement = function()
            local cell = baseCreateElement()
            cell._claretBaseOnClick = cell.OnClick
            return cell
        end
        cargoSetControlToType = function(cell, itemType)
            if itemType == 'claretCargo' then
                RenderCargo(cell, cell.Data)
                return
            end

            -- SpecialGrid reuses Items across data modes. Restore the original
            -- click callback before delegating queue/action rendering.
            if cell._claretBaseOnClick then
                cell.OnClick = cell._claretBaseOnClick
            end
            baseSetControlToType(cell, itemType)
            if cell.OnClick ~= nil then
                cell._claretBaseOnClick = cell.OnClick
            end
        end

        grid.CreateElement = cargoCreateElement
        grid.SetControlToType = cargoSetControlToType
        if grid.SetToVertical then
            grid:SetToVertical(false)
        end
        state.active = true
    end

    local function RestoreRenderers()
        if not state.active then return end
        if grid.CreateElement == cargoCreateElement then
            grid.CreateElement = baseCreateElement
        end
        if grid.SetControlToType == cargoSetControlToType then
            grid.SetControlToType = baseSetControlToType
        end
        state.active = false
    end

    local function RestoreOrientation(preserveViewport)
        if grid._vertical == false and baseVertical ~= nil and baseVertical ~= false and grid.SetToVertical then
            local previousTop = grid.top or 1
            grid:SetToVertical(baseVertical)
            if preserveViewport and previousTop > 1 and grid.ScrollLines then
                grid:ScrollLines(previousTop - 1)
            end
        end
    end

    function state:Activate(units)
        if self.destroyed then return false end
        InstallRenderers()
        if units ~= nil then return self:SetUnits(units) end
        return true
    end

    function state:SetUnits(units)
        if self.destroyed or not self.active then return false end
        if cargoState.SetCargo then
            cargoState:SetCargo(units)
            if cargoState.cargo then units = cargoState.cargo end
        end
        self.units = CopyUnits(units)
        self.displayData = {}
        for index, unit in ipairs(self.units) do
            table.insert(self.displayData, { type = 'claretCargo', unit = unit, index = index })
        end
        grid:Refresh(self.displayData)
        return true
    end

    function state:Refresh()
        if self.destroyed or not self.active then return end
        -- FAF SpecialGrid:Refresh resets top to 1; CalcVisible refreshes the
        -- current viewport without moving it during selection-state changes.
        grid:CalcVisible()
    end

    function state:Deactivate(nextDisplayData)
        if self.destroyed or not self.active then return false end
        local ownsDisplay = grid.DisplayData == self.displayData and IsCargoDisplay(grid.DisplayData)
        if ownsDisplay then
            grid:ClearItems()
            -- Replace our data while the cargo renderer is still installed, so
            -- orientation/layout recalculation cannot send cargo rows to the
            -- caller's original renderer.
            grid:Refresh(nextDisplayData or {})
        end
        RestoreRenderers()
        RestoreOrientation(not ownsDisplay)
        return true
    end

    function state:Destroy()
        if self.destroyed then return end
        self:Deactivate()
        self.destroyed = true
        self.units = {}
        self.displayData = {}
    end

    return state
end

function Create(parent, cargoState, options)
    return CreateView(parent, cargoState, options)
end
