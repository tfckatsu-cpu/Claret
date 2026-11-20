local Group = import('/lua/maui/group.lua').Group
local Bitmap = import('/lua/maui/bitmap.lua').Bitmap
local UI = import('/lua/ui/uiutil.lua')
local Helpers = import('/lua/maui/layouthelpers.lua')
local Theme = import('/mods/ClaretCore/modules/Theme.lua')
local World = import('/lua/ui/game/worldview.lua')
local session
local hidden = { random = true, balanced = true, balanced_flex = true }
local factions = { [0] = 'UEF', [1] = 'AEON', [2] = 'CYBRAN', [3] = 'SERAPHIM' }
local revealed = { random_reveal = true, balanced_reveal = true, balanced_flex_reveal = true }

local function Collect()
    local scenario = SessionGetScenarioInfo()
    if not scenario or not scenario.save then return {} end
    local mode = scenario.Options and scenario.Options.TeamSpawn
    if mode and revealed[mode] then return {} end
    local focus = GetFocusArmy()
    if not focus or focus <= 0 then return {} end
    local data = {}
    doscript('/lua/dataInit.lua', data)
    doscript(scenario.save, data)
    local chain = data.Scenario and data.Scenario.MasterChain
    local master = chain and chain['_MASTERCHAIN_']
    local points = master and master.Markers or {}
    local rows = {}
    if mode and hidden[mode] then
        for name, marker in pairs(points) do
            if string.match(name, '^ARMY_%d+$') and marker.position then
                table.insert(rows, { id = name, pos = marker.position, anonymous = true })
            end
        end
    else
        local armies = GetArmiesTable()
        for index, army in pairs(armies and armies.armiesTable or {}) do
            local marker = points[army.name]
            if not army.civilian and not IsAlly(focus, index) and marker and marker.position then
                table.insert(rows, { id = army.name, pos = marker.position, name = army.nickname,
                    color = army.color, faction = army.faction })
            end
        end
    end
    return rows
end

local function Clear(owner)
    for _, entry in pairs(owner.controls) do entry.control:Destroy() end
    owner.controls = {}
    owner.updater:SetNeedsFrameUpdate(false)
end

local function FillAlpha(option)
    local value = option:Get()
    if type(value) ~= 'number' or value ~= value or value < 0 or value > 100 then value = 100 end
    return 1 - value / 100
end

local function CreateMarker(owner, row, view)
    local pixel = Helpers.GetPixelScaleFactor()
    local size = owner.options.revealPositionsScale:Get()
    if type(size) ~= 'number' or size ~= size or size < 50 or size > 200 then size = 100 end
    local scale = pixel * size / 100
    local L = ReUI.UI.FloorLayouter(scale)
    local iconSize = math.max(1, math.floor(22 * scale + 0.5))
    local iconGap = math.floor(4 * scale + 0.5)
    local iconInset = iconSize + iconGap
    local lineGap = math.floor(2 * scale + 0.5)
    local box = Group(view)
    box:EnableHitTest()
    box.Depth:Set(function() return view.Depth() + 2 end)
    L(box):Height(25)
    local faction = factions[row.faction]
    local name = row.anonymous and ReUI.ClaretCore.Localization.Text('claretui.positions.unknown') or (row.name or '')
    local text = UI.CreateText(box, name, 12 * scale / pixel, Theme.Fonts.body)
    text.Depth:Set(function() return box.Depth() + 2 end)
    text:SetColor('ffffffff')
    text:SetDropShadow(true)
    text:DisableHitTest()
    box.Width:Set(function() return text.Width() + (faction and iconInset or 0) end)
    text.Left:Set(function() return box.Left() + (faction and iconInset or 0) end)
    text.Top:Set(function() return math.floor(box.Top() + (box.Height() - text.Height()) / 2 + 0.5) end)
    local line = Bitmap(box)
    line.Depth:Set(function() return box.Depth() + 2 end)
    line:SetSolidColor(row.color or 'ffffffff')
    line:DisableHitTest()
    line.Left:Set(text.Left); line.Right:Set(text.Right)
    line.Top:Set(function() return math.floor(text.Bottom() + lineGap) end)
    line.Height:Set(math.max(1, math.floor(2 * scale)))
    local background = Bitmap(box)
    background:SetSolidColor(Theme.Colors.canvas)
    background:SetAlpha(FillAlpha(owner.options.revealPositionsFillTransparency))
    background:DisableHitTest()
    background.Depth:Set(function() return box.Depth() + 1 end)
    background.Left:Set(text.Left); background.Right:Set(box.Right)
    background.Top:Set(box.Top); background.Bottom:Set(box.Bottom)
    if faction then
        local icon = Bitmap(box)
        icon.Depth:Set(function() return box.Depth() + 2 end)
        icon:SetTexture('/mods/ClaretUI/textures/factionmarks/' .. string.lower(faction) .. '.dds')
        icon:SetAlpha(1)
        icon:DisableHitTest()
        icon.Width:Set(iconSize); icon.Height:Set(iconSize)
        icon.Right:Set(function() return text.Left() - iconGap end)
        icon.Top:Set(function() return math.floor(text.Top() + (text.Height() - icon.Height()) / 2 + 0.5) end)
    end
    box.HandleEvent = function(control, event)
        if event.Type == 'ButtonPress' and not (event.Modifiers and event.Modifiers.Right) then
            owner.dismissed[row.id] = true
            owner.controls[row.id] = nil
            control:Destroy()
            if not next(owner.controls) then owner.updater:SetNeedsFrameUpdate(false) end
            return true
        end
        return false
    end
    return { control = box, background = background, position = Vector(row.pos[1], row.pos[2], row.pos[3]) }
end

local function Expired(owner)
    local duration = owner.options.revealPositionsDuration:Get()
    return (duration == 60 or duration == 300 or duration == 600) and GetGameTimeSeconds() >= duration
end

local function Show(owner)
    Clear(owner)
    local view = World.viewLeft
    if not owner.enabled or not owner.ready or not view or Expired(owner) then return end
    for _, row in ipairs(owner.rows) do
        if not owner.dismissed[row.id] then owner.controls[row.id] = CreateMarker(owner, row, view) end
    end
    owner.view = view
    owner.updater:SetNeedsFrameUpdate(next(owner.controls) ~= nil)
end

function Start(self, scope, isReplay, options)
    if isReplay then return end
    local root = GetFrame(0)
    if not root then return end
    local owner = { rows = {}, controls = {}, dismissed = {}, enabled = false, ready = false, options = options }
    owner.updater = scope:Own(Group(root))
    owner.updater:DisableHitTest()
    owner.updater.OnFrame = function()
        if Expired(owner) then Clear(owner); return end
        if World.viewLeft ~= owner.view then Show(owner); return end
        for _, entry in pairs(owner.controls) do
            local point = owner.view:Project(entry.position)
            if point then
                entry.control.Left:Set(math.floor(owner.view.Left() + point.x - entry.control.Width() / 2))
                entry.control.Top:Set(math.floor(owner.view.Top() + point.y - entry.control.Height() / 2))
            end
        end
    end
    session = owner
    scope:Bind(options.revealPositionsDuration.OnChanged, function() Show(owner) end)
    scope:Bind(options.revealPositionsScale.OnChanged, function() Show(owner) end)
    scope:Bind(options.revealPositionsFillTransparency.OnChanged, function()
        local alpha = FillAlpha(options.revealPositionsFillTransparency)
        for _, entry in pairs(owner.controls) do
            if entry.background then entry.background:SetAlpha(alpha) end
        end
    end)
    local thread
    thread = ForkThread(function()
        WaitSeconds(5)
        while GetGameTimeSeconds() < 5 do WaitSeconds(0.1) end
        local ok, rows = pcall(Collect)
        if ok then owner.rows = rows else WARN('[ClaretUI] start positions unavailable: ' .. tostring(rows)) end
        owner.ready = true
        thread = nil
        Show(owner)
    end)
    scope:Defer(function()
        session = nil
        if thread then KillThread(thread) end
        Clear(owner)
    end)
end

function SetVisible(self, visible)
    if not session then return end
    session.enabled = visible
    Show(session)
end
