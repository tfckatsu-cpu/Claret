-- Client-side mex state and manual controls. The beat only reads game state.
local Theme = import('/mods/ClaretCore/modules/Theme.lua')
local C, M = Theme.Colors, Theme.Metrics
local Group = import('/lua/maui/group.lua').Group
local Bitmap = import('/lua/maui/bitmap.lua').Bitmap
local UI = import('/lua/ui/uiutil.lua')
local Helpers = import('/lua/maui/layouthelpers.lua')
local Game = import('/lua/ui/game/gamemain.lua')
local Commands = import('/lua/ui/game/commandmode.lua')
local World = import('/lua/ui/game/worldview.lua')
local Tooltip = import('/lua/ui/game/tooltip.lua')
local Dragger = import('/lua/maui/dragger.lua').Dragger
local LazyVar = import('/lua/lazyvar.lua').Create
local category = 'MASSEXTRACTION STRUCTURE'
local columns = {
    { 'T1', 'idle' }, { 'T1', 'paused' }, { 'T1', 'active' },
    { 'T2', 'idle' }, { 'T2', 'paused' }, { 'T2', 'active' },
    { 'T3', 'idle' },
}
local cellWidth = M.buttonHeight + 8
local mexIcons = '/mods/ClaretUI/textures/mexes/'
local upgradeTexture = mexIcons .. 'upgrade-arrow.png'
local pauseTexture = '/textures/ui/common/game/strategicicons/pause_rest.dds'
local session
local keyPrefix = 'claret_mex_'
local keyActions = {}

local function T(key)
    return ReUI.ClaretCore.Localization.Text('claretui.mex.' .. key)
end

local function Discover(onScreen)
    local previous = GetSelectedUnits()
    Commands.CacheAndClearCommandMode()
    Game.SetIgnoreSelection(true)
    local ok, selection = pcall(function()
        UISelectionByCategory(category, false, onScreen, false, false)
        return GetSelectedUnits() or {}
    end)
    SelectUnits(previous)
    Game.SetIgnoreSelection(false)
    Commands.RestoreCommandMode(true)
    if ok then return selection end
    WARN('[ClaretUI] Mex selection failed: ' .. tostring(selection))
    return {}
end

local function Owned(unit, army)
    return unit and not unit:IsDead() and unit:GetArmy() == army
end

-- Keep live handles through temporary gaps in FAF's selector, and retain the
-- target so a just-completed upgrade is visible before the next discovery.
local function MergeMexes(known, discovered, army)
    local units, ids = {}, {}
    local function Add(unit)
        if Owned(unit, army) then
            local id = unit:GetEntityId()
            if not ids[id] then
                ids[id] = true
                table.insert(units, unit)
            end
        end
    end
    for _, unit in ipairs(discovered) do Add(unit) end
    for _, unit in ipairs(known) do Add(unit) end
    return units, Add
end

local function Inspect(units, army, retainTarget)
    local groups, rows, targets, ordered = {}, {}, {}, {}
    for id in ipairs(columns) do groups[id] = {} end
    -- Targets discovered here are retained for the next sample only.
    local count = table.getn(units)
    for index = 1, count do
        local unit = units[index]
        if Owned(unit, army) then
            local bp = unit:GetBlueprint()
            local tech = unit:IsInCategory('TECH1') and 1
                or unit:IsInCategory('TECH2') and 2 or unit:IsInCategory('TECH3') and 3
            if tech then
                local id = unit:GetEntityId()
                local upgrade = bp.General and bp.General.UpgradesTo
                local focus = tech < 3 and unit:GetFocus()
                local state, progress = 'idle', 0
                local hasTarget = Owned(focus, army) and focus ~= unit
                    and focus:IsInCategory('MASSEXTRACTION') and focus:IsInCategory('STRUCTURE')
                if hasTarget then
                    targets[focus:GetEntityId()] = true
                    if retainTarget then retainTarget(focus) end
                end
                local complete = unit:GetFractionComplete() == 1
                if hasTarget then
                    progress = math.max(0, math.min(1, unit:GetWorkProgress() or 0))
                    state = GetIsPaused({ unit }) and 'paused' or 'active'
                end
                if complete or state ~= 'idle' then
                    table.insert(ordered, { unit = unit, id = id, tech = tech, state = state,
                        progress = progress, upgrade = upgrade })
                end
            end
        end
    end
    for _, row in ipairs(ordered) do
        if not targets[row.id] then
            rows[row.id] = row
            local offset = row.state == 'active' and 3 or row.state == 'paused' and 2 or 1
            local group = groups[(row.tech - 1) * 3 + offset]
            table.insert(group, row)
        end
    end
    for id, group in ipairs(groups) do
        if columns[id][2] ~= 'idle' then
            table.sort(group, function(a, b)
                if a.progress == b.progress then return a.id < b.id end
                return a.progress > b.progress
            end)
        end
    end
    return groups, rows
end

local function Run(owner, ids, action, visibleOnly)
    local army = GetFocusArmy()
    if session ~= owner or not owner.enabled or owner.replay or army < 1 then return end
    local fresh = Discover(visibleOnly == true)
    if not visibleOnly and owner.army == army then fresh = MergeMexes(owner.units, fresh, army) end
    local groups = Inspect(fresh, army)
    local units, orders = {}, {}
    for _, id in ipairs(ids) do
        local group = groups[id]
        local first, last = 1, table.getn(group)
        if action == 'best' or action == 'resumeBest' then last = math.min(last, 1) end
        if action == 'pauseWorst' then first = math.max(first, last) end
        for index = first, last do
            local row = group[index]
            if action == 'upgrade' then
                if row.upgrade then
                    local _, _, buildable = GetUnitCommandData({ row.unit })
                    if buildable and EntityCategoryContains(buildable, row.upgrade) then
                        orders[row.upgrade] = orders[row.upgrade] or {}
                        table.insert(orders[row.upgrade], row.unit)
                    end
                end
            else
                table.insert(units, row.unit)
            end
        end
    end
    if action == 'upgrade' then
        for blueprint, builders in pairs(orders) do
            IssueBlueprintCommandToUnits(builders, 'UNITCOMMAND_Upgrade', blueprint, 1, false)
        end
    elseif table.getn(units) > 0 then
        if action == 'select' or action == 'best' then
            SelectUnits(units)
        else
            SetPaused(units, action == 'pause' or action == 'pauseWorst')
        end
    end
    owner.nextDiscovery = 0
end

-- Register in FAF's in-memory action catalog, leaving existing assignments intact.
function InstallKeys()
    local actions = import('/lua/keymap/keyactions.lua').keyActions
    local descriptions = import('/lua/keymap/keydescriptions.lua').keyDescriptions
    local function Add(suffix, action, ids, tech, state)
        local id = keyPrefix .. suffix
        keyActions[id] = { ids = ids, action = action }
        actions[id] = {
            action = string.format('UI_Lua import("/mods/ClaretUI/modules/features/Mexes.lua").RunKey(%q)', id),
            category = 'Claret UI',
        }
        descriptions[id] = string.format(T('key_' .. action), tech, T('state_' .. state))
    end
    for index, column in ipairs(columns) do
        local digit, state = column[1], column[2]
        local suffix = digit .. '_' .. state
        Add('select_' .. suffix, 'select', { index }, digit, state)
        if state == 'idle' and index ~= 7 then
            Add('upgrade_' .. suffix, 'upgrade', { index }, digit, state)
        elseif state == 'active' then
            Add('pause_' .. suffix, 'pause', { index }, digit, state)
            Add('pause_worst_' .. suffix, 'pauseWorst', { index }, digit, state)
        elseif state == 'paused' then
            Add('select_best_' .. suffix, 'best', { index }, digit, state)
            Add('resume_best_' .. suffix, 'resumeBest', { index }, digit, state)
        end
    end
    Add('select_active', 'select', { 3, 6 }, 'T1/T2', 'active')
    Add('select_paused', 'select', { 2, 5 }, 'T1/T2', 'paused')
    Add('pause_active', 'pause', { 3, 6 }, 'T1/T2', 'active')

    local mapper = import('/lua/keymap/keymapper.lua')
    local ownMappings = {}
    for key, id in pairs(mapper.GetCurrentKeyMap()) do
        if keyActions[id] then ownMappings[key] = actions[id] end
    end
    if next(ownMappings) then IN_AddKeyMapTable(ownMappings) end
end

function RunKey(id)
    local entry = keyActions[id]
    if entry and session then Run(session, entry.ids, entry.action, false) end
end


local function Text(parent, value, size, scale)
    local label = UI.CreateText(parent, value, size * scale / Helpers.GetPixelScaleFactor(), Theme.Fonts.body)
    label.Depth:Set(function() return parent.Depth() + 2 end)
    label:DisableHitTest()
    return label
end

local function Fill(parent, color)
    local box = Bitmap(parent)
    local depth = parent.Depth
    box.Depth:Set(function() return depth() + 1 end)
    box:SetSolidColor(color)
    box:DisableHitTest()
    return box
end

local function MakeArrow(plate, layout, x, y)
    local arrow = Bitmap(plate)
    arrow:SetTexture(upgradeTexture)
    arrow:DisableHitTest()
    arrow.Depth:Set(function() return plate.Depth() + 2 end)
    layout(arrow):AtLeftTopIn(plate, x, y):Width(14):Height(15)
    return arrow
end

local function MakePanel(owner, parent, scale)
    local L = ReUI.UI.FloorLayouter(scale)
    local panel = Group(parent)
    panel:DisableHitTest()
    local width, height, gap = cellWidth, M.rowHeight + 32, 4
    L(panel):Width(0):Height(height + gap * 2)
    local position = owner.options.mexPanelPosition:Get()
    local x, y = 100, 50
    if type(position) == 'table' and type(position.x) == 'number' and type(position.y) == 'number'
        and position.x - position.x == 0 and position.y - position.y == 0 then
        x, y = position.x, position.y
        LOG(string.format('[ClaretUI][mex-diag] loaded position x=%.2f y=%.2f', x, y))
    end
    ReUI.UI.FloorLayouter(owner.scale)(panel):AtLeftTopIn(parent, x, y)
    panel.Depth:Set(function() return parent.Depth() + 20 end)
    local backdrop
    local function ResizePanel(width, height)
        if width == 0 then
            if backdrop then backdrop:Destroy() end
            backdrop = nil
            owner.backdrop = nil
            return
        end
        if not backdrop then
            backdrop = Bitmap(panel)
            backdrop:DisableHitTest()
            backdrop.Depth:Set(function() return panel.Depth() + 1 end)
            backdrop:SetSolidColor(C.canvas)
            backdrop:SetAlpha(owner.backgroundAlpha)
            owner.backdrop = backdrop
        end
        L(backdrop):AtLeftTopIn(panel, 0, 0):Width(width):Height(height)
    end
    local function CreateCell(id, x, scale)
        local column = columns[id]
        local state = column[2]
        local cell = Bitmap(panel)
        local item = { cell = cell, count = 0, bars = {}, icons = {} }
        L(cell):Width(width):Height(height):AtLeftTopIn(panel, x, gap)
        cell.Depth:Set(function() return panel.Depth() + 10 end)
        cell:SetSolidColor(owner.backgroundAlpha == 1 and C.surface or C.transparent)
        cell:EnableHitTest()
        local icon = Bitmap(cell)
        icon:SetTexture(mexIcons .. 'icon_structure' .. string.sub(column[1], 2) .. '_mass_rest.dds')
        icon:DisableHitTest()
        icon.Depth:Set(function() return cell.Depth() + 1 end)
        L(icon):Width(36):Height(36):AtTopCenterIn(cell, 13)
        item.icons[1] = icon
        if state ~= 'idle' then
            local arrow = MakeArrow(cell, L, 27, 30)
            item.icons[2] = arrow
            if state == 'paused' then
                local pause = Bitmap(cell)
                pause:SetTexture(pauseTexture)
                pause:DisableHitTest()
                pause.Depth:Set(function() return cell.Depth() + 4 end)
                L(pause):Width(40):Height(40)
                -- Align the visible red mark to the green core of each DDS.
                local coreX, coreY = 18 / 34, 18 / 40
                if column[1] == 'T2' then coreX, coreY = 18 / 36, 17 / 40 end
                pause.Left:Set(function()
                    return math.floor(icon.Left() + icon.Width() * coreX - pause.Width() * (15.5 / 32) + 0.5)
                end)
                pause.Top:Set(function()
                    return math.floor(icon.Top() + icon.Height() * coreY - pause.Height() * (7.5 / 32) + 0.5)
                end)
                pause:SetAlpha(1)
            end
        end
        for _, mark in ipairs(item.icons) do mark:SetAlpha(0.35, true) end
        item.label = Text(cell, '', M.buttonText, scale)
        item.label:SetAlpha(1)
        L(item.label):AtTopCenterIn(cell, 2)
        if state ~= 'idle' then
            for index = 1, 10 do
                local track = Fill(cell, C.border)
                track:SetAlpha(1)
                L(track):Width(width - 8):Height(2):AtLeftTopIn(cell, 4, 48 + (index - 1) * 2)
                track:Hide()
                local bar = Fill(track, state == 'paused' and C.warning or C.health)
                bar:SetAlpha(1)
                local trackWidth, trackLeft = track.Width, track.Left
                local progress = LazyVar(0)
                bar.Left:Set(trackLeft)
                bar.Top:Set(track.Top)
                bar.Bottom:Set(track.Bottom)
                bar.Width:Set(function() return math.floor(trackWidth() * progress()) end)
                item.bars[index] = { track = track, fill = bar, progress = progress }
            end
        end
        function item:Paint()
            if owner.backgroundAlpha < 1 then
                self.cell:SetSolidColor(C.transparent)
            else
                self.cell:SetSolidColor(self.count == 0 and C.surface
                    or self.pressed and C.pressed or self.hover and C.hover or C.raised)
            end
        end
        function item:ResetInput()
            if self.hover then Tooltip.DestroyMouseoverDisplay() end
            self.hover, self.pressed = false, false
            if not IsDestroyed(self.cell) then self:Paint() end
        end
        local hint = state == 'idle' and (id == 7 and 'hint_final' or 'hint_idle')
            or (state == 'paused' and 'hint_paused' or 'hint_active')
        local function Activate(modifiers)
            if item.count == 0 or IsDestroyed(cell) then return end
            local action = 'select'
            if state == 'idle' then
                if modifiers.Ctrl and id ~= 7 then action = 'upgrade' end
            elseif modifiers.Right then
                if state == 'paused' then action = modifiers.Ctrl and 'resumeBest' or 'resume'
                else action = modifiers.Ctrl and 'pauseWorst' or 'pause' end
            elseif modifiers.Ctrl then
                action = 'best'
            end
            Run(owner, { id }, action, state == 'idle' and modifiers.Right)
        end

        local function StartDrag(event, modifiers)
            local startX, startY = event.MouseX, event.MouseY
            if owner.drag or owner.options.mexPanelLocked:Get()
                or type(startX) ~= 'number' or type(startY) ~= 'number' then return false end

            local startLeft, startTop = panel.Left(), panel.Top()
            local frame = cell:GetRootFrame()
            local drag = Dragger()
            local moved = false
            local threshold = math.max(3, 4 * owner.scale)
            owner.drag = drag
            item.pressed = true
            item:Paint()
            Tooltip.DestroyMouseoverDisplay()

            local function Move(x, y)
                if owner.options.mexPanelLocked:Get() then return end
                local dx, dy = x - startX, y - startY
                if not moved and dx * dx + dy * dy < threshold * threshold then return end
                moved = true
                local maxX = math.max(frame.Left(), frame.Right() - panel.Width())
                local maxY = math.max(frame.Top(), frame.Bottom() - panel.Height())
                panel.Left:Set(math.max(frame.Left(), math.min(maxX, startLeft + dx)))
                panel.Top:Set(math.max(frame.Top(), math.min(maxY, startTop + dy)))
            end
            local function Finish(self)
                owner.drag = nil
                self:Destroy()
                if not IsDestroyed(cell) then item:ResetInput() end
            end
            drag.OnMove = function(_, x, y) Move(x, y) end
            drag.OnRelease = function(self, x, y)
                if type(x) == 'number' and type(y) == 'number' then Move(x, y) end
                Finish(self)
                if moved then
                    local option = owner.options.mexPanelPosition
                    local x = (panel.Left() - parent.Left()) / owner.scale
                    local y = (panel.Top() - parent.Top()) / owner.scale
                    local previous = option:Get()
                    if type(previous) ~= 'table' or previous.x ~= x or previous.y ~= y then
                        option:Set({ x = x, y = y })
                        option:Save()
                        SavePreferences()
                        LOG(string.format('[ClaretUI][mex-diag] saved position x=%.2f y=%.2f', x, y))
                    end
                else
                    Activate(modifiers)
                end
            end
            drag.OnCancel = Finish
            PostDragger(frame, event.KeyCode, drag)
            return true
        end

        local prior = cell.HandleEvent
        cell.HandleEvent = function(control, event)
            if event.Type == 'MouseEnter' then
                Tooltip.CreateMouseoverDisplay(control, { text = column[1], body = T(hint) }, nil, true, 300)
            elseif event.Type == 'MouseExit' and item.hover then
                Tooltip.DestroyMouseoverDisplay()
            end
            local modifiers = event.Modifiers or {}
            if event.Type == 'ButtonPress' and modifiers.Left and not modifiers.Ctrl then
                if StartDrag(event, modifiers) then return true end
            end
            if event.Type == 'MouseEnter' or event.Type == 'MouseExit' then
                item.hover = event.Type == 'MouseEnter'
                item.pressed = false
                item:Paint()
            elseif item.count > 0 then
                if event.Type == 'ButtonPress' and (modifiers.Left or modifiers.Right) then
                    item.pressed = { Left = modifiers.Left, Right = modifiers.Right, Ctrl = modifiers.Ctrl }
                    item:Paint()
                    return true
                elseif event.Type == 'ButtonRelease' and item.pressed then
                    modifiers = item.pressed
                    item.pressed = false
                    item:Paint()
                    Activate(modifiers)
                    return true
                elseif event.Type == 'ButtonDClick' then
                    return true
                end
            end
            if prior then return prior(control, event) end
        end
        return item
    end
    return panel, CreateCell, L, ResizePanel, width, height, gap
end

local function UpdatePanel(owner, groups)
    for id, item in pairs(owner.cells) do
        local group = groups[id]
        local count = table.getn(group)
        if count ~= item.count then
            item.count = count
            if count == 0 then item.pressed = false end
            item.label:SetText(count > 0 and tostring(count) or '')
            item:Paint()
            for _, icon in ipairs(item.icons) do icon:SetAlpha(count > 0 and 1 or 0.35) end
        end
        for index, bar in ipairs(item.bars) do
            local row = group[index]
            if row then
                local progress = row.progress
                if progress ~= bar.progress() then bar.progress:Set(progress) end
                if bar.track:IsHidden() then bar.track:Show() end
            elseif not bar.track:IsHidden() then
                bar.track:Hide()
            end
        end
    end
end

local function ClampPanel(panel)
    local frame = panel:GetRootFrame()
    local maxX = math.max(frame.Left(), frame.Right() - panel.Width())
    local maxY = math.max(frame.Top(), frame.Bottom() - panel.Height())
    local x, y = panel.Left(), panel.Top()
    local left = math.max(frame.Left(), math.min(maxX, x))
    local top = math.max(frame.Top(), math.min(maxY, y))
    if x ~= left then panel.Left:Set(left) end
    if y ~= top then panel.Top:Set(top) end
end

local function ApplyPanelLayout(owner, groups)
    local adaptive = owner.options.mexPanelMode and owner.options.mexPanelMode:Get() == 'dynamic'
    local tiers, signature, count = {}, '', 0
    for id, column in ipairs(columns) do
        if not adaptive or table.getn(groups[id]) > 0 then tiers[column[1]] = true end
    end
    for id, column in ipairs(columns) do
        if tiers[column[1]] then
            signature = signature .. tostring(id)
            count = count + 1
        end
    end

    local panel = owner.panel
    if adaptive == owner.adaptive and signature == owner.layoutSignature
        and (count == 0 or not panel:IsHidden()) then return end
    owner.adaptive = adaptive
    owner.layoutSignature = signature
    LOG('[ClaretUI][mex-layout] mode=' .. (adaptive and 'adaptive' or 'static') .. ' cells=' .. tostring(count) .. ' slots=' .. signature)

    local L, gap, width = owner.layout, owner.gap, owner.cellWidth
    local height = owner.cellHeight + 2 * gap
    if count == 0 then
        panel:Hide()
        L(panel):Width(0)
        owner.resizePanel(0, height)
    else
        local totalWidth = count * (width + gap) + gap
        L(panel):Width(totalWidth)
        owner.resizePanel(totalWidth, height)
        if panel:IsHidden() then panel:Show() end
        ClampPanel(panel)
    end

    local x = gap
    for id, column in ipairs(columns) do
        local item = owner.cells[id]
        if tiers[column[1]] then
            if item then
                L(item.cell):AtLeftTopIn(panel, x, gap)
            else
                owner.cells[id] = owner.createCell(id, x, owner.panelScale)
            end
            x = x + width + gap
        elseif item then
            item:ResetInput()
            item.cell:Destroy()
            owner.cells[id] = nil
        end
    end
end


local function MakeMarker(view, scale, numbered)
    local plate = Bitmap(view)
    plate.Left:Set(view.Left)
    plate.Top:Set(view.Top)
    plate:DisableHitTest()
    plate:Hide()
    local size = numbered and 18 or M.glyph
    plate.Width:Set(math.floor(size * scale))
    plate.Height:Set(math.floor(size * scale))
    plate.Depth:Set(function() return view.Depth() + 2 end)
    local marker = { plate = plate, size = size }
    if numbered then
        local bar = Fill(plate, C.health)
        bar.Left:Set(plate.Left)
        bar.Top:Set(plate.Bottom)
        bar.Width:Set(0)
        bar.Height:Set(math.max(1, math.floor(2 * scale)))
        bar:Hide()
        marker.bar = bar
    else
        plate:SetSolidColor(C.transparent)
    end
    return marker
end


local function ClearMarkers(owner)
    for _, marker in pairs(owner.markers) do
        if not IsDestroyed(marker.plate) then marker.plate:Destroy() end
    end
    owner.markers = {}
end

local function UpdateMarkers(owner)
    local view = World.viewLeft
    if view ~= owner.view then
        ClearMarkers(owner)
        owner.view = view
    end
    local showArrows = owner.options.mexNumbers:Get()
    local numbered = owner.options.mexOverlay:Get()
    if (not showArrows and not numbered) or not view or IsDestroyed(view) or view:IsHidden() then
        if next(owner.markers) then ClearMarkers(owner) end
        return
    end
    local percent = numbered and owner.options.mexOverlayScale:Get() or 100
    if type(percent) ~= 'number' or percent ~= percent or percent < 50 or percent > 200 then percent = 100 end
    local scale = owner.scale * percent / 100
    if numbered ~= owner.numbered or scale ~= owner.markerScale then
        ClearMarkers(owner)
        owner.numbered, owner.markerScale = numbered, scale
    end
    for id, row in pairs(owner.rows) do
        local marker = owner.markers[id]
        local pos
        local showArrow = showArrows and row.state ~= 'idle'
        if Owned(row.unit, owner.army) and (numbered or showArrow) then
            pos = view:GetScreenPos(row.unit)
        end
        if pos then
            if not marker then
                marker = MakeMarker(view, scale, numbered)
                owner.markers[id] = marker
            end
            local plate = marker.plate
            local x = math.floor(view.Left() + pos.x - plate.Width() / 2)
            local y = math.floor(view.Top() + pos.y - plate.Height() / 2)
            if x ~= marker.x then marker.x = x; plate.Left:Set(x) end
            if y ~= marker.y then marker.y = y; plate.Top:Set(y) end
            if showArrow and not marker.arrow then
                marker.arrow = MakeArrow(plate, ReUI.UI.FloorLayouter(scale), marker.size - 7, -3)
            elseif not showArrow and marker.arrow then
                marker.arrow:Destroy()
                marker.arrow = nil
            end
            if numbered then
                if row.tech ~= marker.tech then
                    marker.tech = row.tech
                    plate:SetTexture('/mods/ClaretUI/textures/engineers/tier-' .. tostring(row.tech) .. '.png', 0)
                    marker.color = nil
                end
                local color = row.state == 'idle' and C.hudValue or C.hudDamage
                if color ~= marker.color then
                    marker.color = color
                    plate:SetColorMask(color)
                end
                local width = math.floor(row.progress * plate.Width())
                if width ~= marker.progressWidth then
                    marker.progressWidth = width
                    marker.bar.Width:Set(width)
                    marker.bar:SetHidden(width == 0)
                end
            end
            if plate:IsHidden() then plate:Show() end
        elseif marker then
            marker.plate:Hide()
        end
    end
    for id, marker in pairs(owner.markers) do
        if not owner.rows[id] then
            marker.plate:Destroy()
            owner.markers[id] = nil
        end
    end
end

local function Trace(message)
    LOG('[ClaretUI][mex-diag] ' .. message)
end

function Start(self, scope, isReplay, options)
    local parent = Game.GetStatusCluster()
    local ready = parent and not IsDestroyed(parent) or false
    Trace('start replay=' .. tostring(isReplay) .. ' statusCluster=' .. tostring(ready))
    if isReplay or not ready then return end
    local owner = { options = options, enabled = false, scale = Helpers.GetPixelScaleFactor(),
        markers = {}, rows = {}, units = {}, nextDiscovery = 0, nextSample = 0 }
    local scaleOption, modeOption = options.mexPanelScale, options.mexPanelMode
    local function PanelScale()
        local value = scaleOption:Get()
        if type(value) ~= 'number' or value ~= value or value < 50 or value > 200 then value = 100 end
        return owner.scale * value / 100
    end
    local panel, createCell, layout, resizePanel, cellWidthValue, cellHeightValue, gap = MakePanel(owner, parent, PanelScale())
    owner.panel, owner.cells, owner.layout, owner.resizePanel = panel, {}, layout, resizePanel
    owner.createCell = createCell
    owner.cellWidth, owner.cellHeight, owner.gap = cellWidthValue, cellHeightValue, gap
    local function ApplyPanelScale()
        if IsDestroyed(panel) then return end
        local scale = PanelScale()
        owner.panelScale = scale
        local fontScale = scale / Helpers.GetPixelScaleFactor()
        layout.Scale = scale
        for _, item in pairs(owner.cells) do
            item.label:SetFont(Theme.Fonts.body, M.buttonText * fontScale)
        end
        ClampPanel(panel)
    end
    ApplyPanelScale()
    panel:Hide()

    function owner:Sample()
        local army = GetFocusArmy()
        if army ~= self.tracedArmy then
            self.tracedArmy = army
            Trace('sample army=' .. tostring(army))
        end
        if army < 1 then
            self.army, self.groups, self.rows, self.units = nil, nil, {}, {}
            self:DismissInput()
            panel:Hide()
            self.resizePanel(0)
            ClearMarkers(self)
            return
        end
        local now = GetSystemTimeSeconds()
        local fresh = {}
        if army ~= self.army then
            self.army, self.units, self.nextDiscovery = army, {}, 0
        end
        -- Background discovery briefly changes the engine's selection.
        if now >= self.nextDiscovery and GetGameTimeSeconds() >= 15
            and not Commands.GetCommandMode()[1] and not GetInputCapture() then
            fresh = Discover(false)
            self.nextDiscovery = now + 1
        end
        local units, retainTarget = MergeMexes(self.units, fresh, army)
        self.units = units
        local groups, rows = Inspect(units, army, retainTarget)
        self.groups, self.rows = groups, rows
        local tiers = { 0, 0, 0 }
        for id, group in ipairs(groups) do
            local tier = math.floor((id - 1) / 3) + 1
            tiers[tier] = tiers[tier] + table.getn(group)
        end
        local census = string.format('known=%d T1=%d T2=%d T3=%d', table.getn(units), tiers[1], tiers[2], tiers[3])
        local changed = census ~= self.tracedCensus
        if changed then
            self.tracedCensus = census
            Trace('sample ' .. census)
        end
        ApplyPanelLayout(self, groups)
        UpdatePanel(self, groups)
        if changed then
            Trace('applied cells=' .. tostring(table.getsize(self.cells)) .. ' hidden=' .. tostring(panel:IsHidden()))
        end
    end
    local function ApplyPanelMode()
        Trace('mode changed to ' .. tostring(modeOption:Get()) .. ' enabled=' .. tostring(owner.enabled))
        if owner.enabled and owner.groups and not IsDestroyed(panel) then
            ApplyPanelLayout(owner, owner.groups)
            UpdatePanel(owner, owner.groups)
        end
    end
    local tracedBeat = false
    local function Beat()
        if not tracedBeat then
            tracedBeat = true
            Trace('first beat enabled=' .. tostring(owner.enabled) .. ' panelDestroyed=' .. tostring(IsDestroyed(panel)))
        end
        if owner.enabled and not IsDestroyed(panel) then
            local now = GetSystemTimeSeconds()
            if now >= owner.nextSample then
                owner.nextSample = now + 0.1
                owner:Sample()
            end
        end
    end
    -- Map markers keep their own frame updates while the panel is hidden.
    local updater = Group(parent)
    updater:DisableHitTest()
    layout(updater):AtLeftTopIn(parent, 0, 0):Width(0):Height(0)
    owner.updater = updater
    updater.OnFrame = function()
        UpdateMarkers(owner)
    end
    function owner:DismissInput()
        for _, item in pairs(self.cells) do item:ResetInput() end
        if self.drag then
            self.drag:Destroy()
            self.drag = nil
        end
    end
    local transparency = options.mexPanelTransparency
    local function ApplyTransparency()
        local value = transparency:Get()
        if type(value) ~= 'number' or value ~= value then value = 0 end
        owner.backgroundAlpha = 1 - math.max(0, math.min(100, value)) / 100
        if owner.backdrop and not IsDestroyed(owner.backdrop) then
            owner.backdrop:SetAlpha(owner.backgroundAlpha)
        end
        for _, item in pairs(owner.cells) do
            item:Paint()
        end
    end
    ApplyTransparency()
    transparency.OnChanged:Add(ApplyTransparency)
    local lockOption = options.mexPanelLocked
    local function ApplyPanelLock()
        if lockOption:Get() then owner:DismissInput() end
    end
    lockOption.OnChanged:Add(ApplyPanelLock)
    scope:Defer(function()
        lockOption.OnChanged:Remove(ApplyPanelLock)
        transparency.OnChanged:Remove(ApplyTransparency)
        session = nil
        Game.RemoveBeatFunction(Beat)
        scaleOption.OnChanged:Remove(ApplyPanelScale)
        if modeOption then modeOption.OnChanged:Remove(ApplyPanelMode) end
        owner:DismissInput()
        ClearMarkers(owner)
        if not IsDestroyed(updater) then updater:Destroy() end
        if not IsDestroyed(panel) then panel:Destroy() end
    end)
    scaleOption.OnChanged:Add(ApplyPanelScale)
    if modeOption then modeOption.OnChanged:Add(ApplyPanelMode) end
    Game.AddBeatFunction(Beat)
    session = owner
    Trace('ready option=' .. tostring(options.mexPanel:Get()) .. ' mode=' .. tostring(modeOption and modeOption:Get()))
end

function SetVisible(self, visible)
    local owner = session
    Trace('visibility=' .. tostring(visible) .. ' session=' .. tostring(owner ~= nil))
    if not owner or IsDestroyed(owner.panel) then return end
    owner.tracedCensus, owner.tracedArmy = nil, nil
    owner.enabled = visible
    owner.updater:SetNeedsFrameUpdate(visible)
    if visible then
        owner.nextDiscovery, owner.nextSample = 0, 0
        owner:Sample()
        UpdateMarkers(owner)
    else
        owner:DismissInput()
        owner.panel:Hide()
        owner.resizePanel(0)
        owner.layoutSignature = nil
        owner.groups, owner.units, owner.rows = nil, {}, {}
        ClearMarkers(owner)
    end
end
