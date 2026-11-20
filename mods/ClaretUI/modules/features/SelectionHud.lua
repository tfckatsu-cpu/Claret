local Lifecycle = import('/mods/ClaretCore/modules/Lifecycle.lua')
local Theme = import('/mods/ClaretCore/modules/Theme.lua')
local Game = import('/lua/ui/game/gamemain.lua')
local GetEnhancements = import('/lua/enhancementcommon.lua').GetEnhancements
local GetPixelScaleFactor = import('/lua/maui/layouthelpers.lua').GetPixelScaleFactor
local Bitmap = import('/lua/maui/bitmap.lua').Bitmap
local Dragger = import('/lua/maui/dragger.lua').Dragger
local CreateText = import('/lua/ui/uiutil.lua').CreateText
local fields = import('/mods/ClaretUI/modules/SelectionHudFields.lua').Fields

local C, M, F = Theme.Colors, Theme.Metrics, Theme.Fonts
local TOP, PAD, ROW, HEADING = 76, 8, 32, 20
local PREFIX = 'claretui.selection.'
local columns = { { 'resources', 'units' }, { 'cost', 'results' }, { 'combat' } }

local function Stat(unit, key)
    local stat = unit:GetStat(key, 0)
    return stat and stat.Value or 0
end

local function ReadSelection(units)
    local available = {}
    local totals = { count = 0, massRate = 0, energyRate = 0, buildPower = 0,
        massCost = 0, energyCost = 0, massKilled = 0, massReclaimed = 0, health = 0, shield = 0,
        available = available }
    for _, unit in ipairs(units) do
        if not unit:IsDead() then
            totals.count = totals.count + 1
            local health = unit:GetHealth()
            if type(health) == 'number' then
                available.health = true
                totals.health = totals.health + health
            end
            totals.massKilled = totals.massKilled + Stat(unit, 'VetExperience')
            totals.massReclaimed = totals.massReclaimed + Stat(unit, 'ReclaimedMass')
            local rates = unit:GetEconData() or {}
            totals.massRate = totals.massRate + (rates.massProduced or 0) - (rates.massRequested or 0)
            totals.energyRate = totals.energyRate + (rates.energyProduced or 0) - (rates.energyRequested or 0)
            available.massRate = available.massRate or (rates.massProduced or 0) ~= 0 or (rates.massRequested or 0) ~= 0
            available.energyRate = available.energyRate or (rates.energyProduced or 0) ~= 0 or (rates.energyRequested or 0) ~= 0

            local bp = unit:GetBlueprint()
            if bp then
                local economy = bp.Economy or {}
                local categories = bp.CategoriesHash or {}
                available.massRate = available.massRate or (economy.ProductionPerSecondMass or 0) ~= 0
                    or (economy.MaintenanceConsumptionPerSecondMass or 0) ~= 0
                available.energyRate = available.energyRate or (economy.ProductionPerSecondEnergy or 0) ~= 0
                    or (economy.MaintenanceConsumptionPerSecondEnergy or 0) ~= 0
                local commands = bp.General and bp.General.CommandCaps
                available.massReclaimed = available.massReclaimed or categories.ENGINEER or categories.COMMAND
                    or categories.SUBCOMMANDER or (commands and commands.RULEUCC_Reclaim)
                if not available.massKilled and totals.massKilled == 0 and bp.Weapon then
                    for _, weapon in ipairs(bp.Weapon) do
                        if (weapon.Damage or 0) > 0 and not weapon.DummyWeapon and weapon.WeaponCategory ~= 'Death'
                            and weapon.Label ~= 'DeathWeapon' and weapon.DamageType ~= 'DeathExplosion' then
                            available.massKilled = true
                            break
                        end
                    end
                end
                if not categories.COMMAND then
                    totals.massCost = totals.massCost + (economy.BuildCostMass or 0)
                    totals.energyCost = totals.energyCost + (economy.BuildCostEnergy or 0)
                end
                if categories.COMMAND or categories.SUBCOMMANDER then
                    available.buildPower = available.buildPower or (economy.BuildRate or 0) > 0
                    totals.buildPower = totals.buildPower + (unit:GetBuildRate() or 0)
                elseif categories.ENGINEER or categories.FACTORY or categories.SILO then
                    totals.buildPower = totals.buildPower + (economy.BuildRate or 0)
                end

                local shield = bp.Defense and bp.Defense.Shield
                local capacity = shield and shield.ShieldMaxHealth or 0
                if bp.Enhancements then
                    local installed = GetEnhancements(unit:GetEntityId())
                    for _, name in pairs(installed or {}) do
                        local enhancement = bp.Enhancements[name]
                        if enhancement then
                            capacity = math.max(capacity, enhancement.ShieldMaxHealth or 0)
                            if (categories.COMMAND or categories.SUBCOMMANDER) and not categories[name] then
                                totals.massCost = totals.massCost + (enhancement.BuildCostMass or 0)
                                totals.energyCost = totals.energyCost + (enhancement.BuildCostEnergy or 0)
                            end
                        end
                    end
                end
                if capacity > 0 then
                    available.shield = true
                    local charge = unit:GetShieldRatio() or 0
                    totals.shield = totals.shield + math.max(0, math.min(1, charge)) * capacity
                end
            end
        end
    end
    return totals
end

local function BindPlacement(scope, panel, backdrop, frame, layout, positionScale, options)
    local position, locked = options.selectionPosition, options.selectionLocked
    local pendingDrag

    local function Place(left, top)
        local minX, minY = frame.Left(), frame.Top()
        panel.Left:Set(math.max(minX, math.min(left, frame.Right() - panel.Width())))
        panel.Top:Set(math.max(minY, math.min(top, frame.Bottom() - panel.Height())))
    end

    local function Restore()
        if pendingDrag then return end
        local saved = position:Get()
        if type(saved) == 'table' and type(saved.x) == 'number' and type(saved.y) == 'number'
            and saved.x - saved.x == 0 and saved.y - saved.y == 0 then
            Place(frame.Left() + saved.x * positionScale, frame.Top() + saved.y * positionScale)
        else
            layout(panel):AtHorizontalCenterIn(frame)
            panel.Top:Set(function() return frame.Top() + math.floor(TOP * positionScale) end)
        end
    end

    local function CancelDrag()
        if pendingDrag then
            local drag = pendingDrag
            pendingDrag = nil
            drag:Destroy()
            Restore()
        end
    end

    local previous = panel.HandleEvent
    panel.HandleEvent = function(self, event)
        if event.Type ~= 'ButtonPress' or not (event.Modifiers and event.Modifiers.Left)
            or locked:Get() or pendingDrag then
            return previous and previous(self, event) or false
        end
        local x, y = event.MouseX, event.MouseY
        if type(x) ~= 'number' or type(y) ~= 'number' then return false end
        local left, top = panel.Left(), panel.Top()
        local drag = Dragger()
        pendingDrag = drag
        function drag:OnMove(newX, newY)
            if pendingDrag == self then Place(left + newX - x, top + newY - y) end
        end
        function drag:OnRelease(newX, newY)
            if pendingDrag ~= self then return end
            if type(newX) == 'number' and type(newY) == 'number' then self:OnMove(newX, newY) end
            local newLeft, newTop = panel.Left(), panel.Top()
            pendingDrag = nil
            self:Destroy()
            if newLeft ~= left or newTop ~= top then
                position:Set({ x = (newLeft - frame.Left()) / positionScale,
                    y = (newTop - frame.Top()) / positionScale })
                position:Save()
                SavePreferences()
            end
        end
        drag.OnCancel = CancelDrag
        PostDragger(frame, event.KeyCode, drag)
        return true
    end

    local function ApplyLock()
        if locked:Get() then
            CancelDrag()
            panel:DisableHitTest()
        else
            panel:EnableHitTest()
        end
    end
    local function ApplyTransparency()
        local value = options.selectionTransparency:Get()
        if type(value) ~= 'number' or value ~= value then value = 0 end
        backdrop:SetAlpha(1 - math.max(0, math.min(100, value)) / 100)
    end
    scope:Defer(CancelDrag)
    scope:Bind(locked.OnChanged, ApplyLock)
    scope:Bind(options.selectionTransparency.OnChanged, ApplyTransparency)
    ApplyLock()
    ApplyTransparency()
    return Restore, CancelDrag
end

local function CreateHud(scope, options)
    local parent = Game.GetStatusCluster()
    local frame = GetFrame(0)
    local pixel = GetPixelScaleFactor()
    local maxHeight = 4 * ROW + 2 * (HEADING + PAD) + PAD * 2
    local maxScale = math.min(frame.Width() / 480, frame.Height() / (TOP + maxHeight + PAD))
    local positionScale = math.min(pixel, maxScale)
    local function ReadScale()
        local value = options.selectionScale:Get()
        if type(value) ~= 'number' or value ~= value or value < 50 or value > 200 then value = 100 end
        return math.min(pixel * value / 100, maxScale)
    end
    local scale = ReadScale()
    local layout = ReUI.UI.FloorLayouter(scale)
    local localization = ReUI.ClaretCore.Localization
    local panel = scope:Own(Bitmap(parent))
    panel:SetSolidColor(C.transparent)
    panel.Depth:Set(function() return parent.Depth() + 80 end)
    layout(panel):AtTopCenterIn(frame, TOP):Width(PAD * 2):Height(ROW)
    local backdrop = Bitmap(panel)
    backdrop:SetSolidColor(C.surface)
    backdrop.Depth:Set(function() return panel.Depth() + 1 end)
    backdrop:DisableHitTest()
    layout(backdrop):Fill(panel)
    local RestorePosition, CancelDrag = BindPlacement(scope, panel, backdrop, frame, layout, positionScale, options)
    panel:Hide()

    local fonts = {}
    local function Text(size, font, color)
        local text = CreateText(panel, '', size * scale / pixel, font)
        table.insert(fonts, { control = text, size = size, font = font })
        text:SetColor(color)
        text:DisableHitTest()
        text.Depth:Set(function() return panel.Depth() + 2 end)
        return text
    end

    local groups = {}
    for _, column in ipairs(columns) do
        for _, key in ipairs(column) do
            groups[key] = { rows = {}, heading = key ~= 'units' and Text(M.secondaryText, F.heading, C.muted) }
        end
    end
    local rows = {}
    for _, field in ipairs(fields) do
        local row = { field = field, option = options['selection_' .. field.key],
            label = Text(M.caption, F.body, C.muted), value = Text(M.title + 4, F.heading, C[field.color]) }
        table.insert(rows, row)
        table.insert(groups[field.group].rows, row)
    end

    local totals
    local function Paint()
        if not totals or totals.count == 0 then
            CancelDrag()
            panel:Hide()
            return
        end
        local labels = options.selectionLabels:Get()
        local dynamic = options.selectionDynamic:Get()
        local function PaintGroup(key, x, y)
            local group = groups[key]
            local valueWidth, labelWidth, count = 0, 0, 0
            for _, row in ipairs(group.rows) do
                local field = row.field
                local value = totals[field.key]
                row.visible = row.option:Get() and (not dynamic or totals.available[field.key] or value ~= 0)
                if row.visible then
                    local text = field.rate and string.format('%+.1f', value) or string.format('%.0f', value)
                    row.value:SetText(text)
                    valueWidth = math.max(valueWidth, row.value:GetStringAdvance(text) / scale)
                    if labels then
                        local label = localization.Text(PREFIX .. field.key)
                        row.label:SetText(label)
                        labelWidth = math.max(labelWidth, PAD + row.label:GetStringAdvance(label) / scale)
                    end
                    count = count + 1
                end
            end
            local width = valueWidth + labelWidth
            if group.heading then
                if labels and count > 0 then
                    local text = localization.Text(PREFIX .. key)
                    group.heading:SetText(text)
                    layout(group.heading):AtLeftTopIn(panel, x, y)
                    group.heading:Show()
                    width = math.max(width, group.heading:GetStringAdvance(text) / scale)
                    y = y + HEADING
                else
                    group.heading:Hide()
                end
            end
            for _, row in ipairs(group.rows) do
                if row.visible then
                    layout(row.value):AtLeftTopIn(panel, x, y)
                    row.value:Show()
                    if labels then
                        layout(row.label):AtLeftTopIn(panel, x + valueWidth + PAD, y + 12)
                        row.label:Show()
                    else
                        row.label:Hide()
                    end
                    y = y + ROW
                else
                    row.label:Hide()
                    row.value:Hide()
                end
            end
            return math.ceil(width), y
        end

        panel:Show()
        local x, height = PAD, 0
        for _, column in ipairs(columns) do
            local y, width = PAD, 0
            for _, key in ipairs(column) do
                local groupWidth, bottom = PaintGroup(key, x, y)
                if groupWidth > 0 then
                    width = math.max(width, groupWidth)
                    y = bottom + PAD
                end
            end
            if width > 0 then
                x = x + width + PAD * 2
                height = math.max(height, y)
            end
        end
        if height == 0 then
            CancelDrag()
            panel:Hide()
        else
            layout(panel):Width(x - PAD):Height(height)
            RestorePosition()
        end
    end

    localization.Subscribe(panel, Paint)
    scope:Defer(function() localization.Unsubscribe(panel) end)
    scope:Bind(options.selectionLabels.OnChanged, Paint)
    scope:Bind(options.selectionDynamic.OnChanged, Paint)
    scope:Bind(options.selectionScale.OnChanged, function()
        local nextScale = ReadScale()
        if nextScale == scale then return end
        CancelDrag()
        scale = nextScale
        layout.Scale = scale
        for _, text in ipairs(fonts) do
            text.control:SetFont(text.font, text.size * scale / pixel)
        end
        Paint()
    end)
    for _, row in ipairs(rows) do scope:Bind(row.option.OnChanged, Paint) end
    ReUI.ClaretCore.UseSelectionHud(scope, function(units)
        totals = ReadSelection(units)
        Paint()
    end)
end

function Start(_, scope, _isReplay, options)
    local hud = Lifecycle.Create(function(hudScope) CreateHud(hudScope, options) end, function(message)
        WARN('[ClaretUI] selection HUD: ' .. tostring(message))
    end)
    local option = options.selectionHud
    scope:Defer(function() hud:Destroy() end)
    scope:Bind(option.OnChanged, function(_, value) hud:SetEnabled(value) end)
    hud:SetEnabled(option:Get())
end
