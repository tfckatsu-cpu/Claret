local Theme = import('/mods/ClaretCore/modules/Theme.lua')
local Group = import('/lua/maui/group.lua').Group
local Bitmap = import('/lua/maui/bitmap.lua').Bitmap
local UI = import('/lua/ui/uiutil.lua')
local Helpers = import('/lua/maui/layouthelpers.lua')
local Borders = import('/lua/ui/game/borders.lua')
local C, M = Theme.Colors, Theme.Metrics
local motionIn = 0.3
local motionOut = 0.25
local queueLimit = 12
local compactLimit = 3
local compactBottom = 168
local gap = 8
local textPrefix = 'claretui.notifications.'

function Create(scope, options)
    local parent = Borders.GetMapGroup()
    local pixel = Helpers.GetPixelScaleFactor()
    local localization = ReUI.ClaretCore.Localization
    local root = scope:Own(Group(parent))
    ReUI.UI.FloorLayouter(pixel)(root):Fill(parent)
    root.Depth:Set(function() return parent.Depth() + 80 end)
    root:DisableHitTest()

    local active, pending = {}, {}
    local center = options.notificationsMode:Get() == 'center'
    local display = {}

    local function Text(key)
        return localization.Text(textPrefix .. key)
    end

    local function UpgradeMessage(upgrade)
        local key = textPrefix .. 'upgrade.'
        if upgrade.unitId then
            local unitKey = key .. string.lower(upgrade.unitId) .. '.' .. upgrade.id
            local message = localization.Text(unitKey)
            if message and message ~= unitKey then return message end
        end
        key = key .. upgrade.id
        local message = localization.Text(key)
        if message and message ~= key then return message end
        return string.format(Text('acu'), LOC(upgrade.name))
    end

    local function NewCard(event)
        local card = Group(root)
        card:DisableHitTest()
        card.Depth:Set(function() return root.Depth() + 1 end)

        local background, accent, icon, iconFrame
        local parts = {}
        if not center then
            background = Bitmap(card)
            accent = Bitmap(card)
            background:SetSolidColor(C.surface)
            accent:SetSolidColor((event.kind == 'nuke' or event.kind == 'smd') and C.warning or C.accent)
            parts = { background, accent }
        end
        if event.icon then
            if event.iconFrame then
                iconFrame = Bitmap(card)
                iconFrame:SetTexture(event.iconFrame)
                table.insert(parts, iconFrame)
            end
            icon = Bitmap(card)
            icon:SetTexture(event.icon)
            table.insert(parts, icon)
        end
        local label = UI.CreateText(card, '', M.heading, Theme.Fonts.heading)
        label:SetColor(C.text)
        if center then label:SetDropShadow(true) end
        table.insert(parts, label)
        for index, control in ipairs(parts) do
            local depth = index
            control:DisableHitTest()
            control.Depth:Set(function() return card.Depth() + depth end)
        end
        return { control = card, background = background, accent = accent, label = label, icon = icon, iconFrame = iconFrame,
            parts = parts, event = event, age = 0 }
    end

    local function Configure(item)
        local size = options.notificationsScale:Get()
        if type(size) ~= 'number' or size ~= size or size < 50 or size > 200 then size = 100 end
        local height = center and 64 or 44
        local padding = center and M.padding or M.panelGap
        local iconSize = center and 40 or 28
        local iconSpace = item.icon and iconSize + gap or 0
        local insets = 2 * padding + iconSpace
        local availableWidth = math.max(1, root.Width() - 2 * M.padding)
        local availableHeight = root.Height() - 2 * M.padding
        local stackHeight = height
        if not center then
            availableHeight = availableHeight - compactBottom * pixel
            stackHeight = compactLimit * height + (compactLimit - 1) * gap
        end
        local scale = math.max(0.1, math.min(pixel * (center and 1 or size / 100),
            availableWidth / (insets + M.text), availableHeight / stackHeight))
        local layout = ReUI.UI.FloorLayouter(scale)
        local label = item.label
        local font = (center and M.title + 4 or M.text) * scale / pixel
        local event = item.event
        local text
        if event.kind == 'acu' then
            text = UpgradeMessage(event.value)
        elseif event.kind == 'smd' then
            text = string.format(Text('smd'), event.value.added, event.value.stock)
        elseif event.kind == 'experimental' then
            text = string.format(Text('experimental'), LOC(event.value))
        else
            text = Text(event.textKey or event.kind)
            if event.value then text = string.format(text, event.value) end
        end
        text = string.gsub(text, '[\r\n]+', ' ')
        label:SetText(text)
        label:SetFont(Theme.Fonts.heading, font)
        local textWidth = label:GetStringAdvance(text)
        local textLimit = math.max(1, availableWidth - insets * scale)
        while textWidth > textLimit and font > 1 do
            font = math.max(1, math.floor(font * textLimit / textWidth))
            label:SetFont(Theme.Fonts.heading, font)
            textWidth = label:GetStringAdvance(text)
        end
        local width = math.min(availableWidth / scale, math.ceil(textWidth / scale + insets))
        local card = item.control
        item.layout, item.height, item.scale = layout, height, scale
        layout(card):Width(width):Height(height)
        if item.background then
            layout(item.background):Fill(card)
            layout(item.accent):AtLeftTopIn(card, 0, 0):Width(4):Height(height)
        end
        if item.icon then
            layout(item.icon):Width(iconSize):Height(iconSize):AtLeftCenterIn(card, padding)
        end
        if item.iconFrame then
            layout(item.iconFrame):Fill(item.icon)
        end
        layout(label):AtLeftCenterIn(card, padding + iconSpace)
    end

    local function Paint(item, index)
        local duration = center and 2.6 or 4
        local entering = math.max(0, 1 - item.age / motionIn)
        local leaving = math.max(0, (item.age - (duration - motionOut)) / motionOut)
        local alpha = math.min(1 - entering * entering * entering, 1 - leaving)
        local offset = (center and 40 or 12) * entering * entering * entering - 12 * leaving * leaving
        if center then
            item.layout(item.control):AtCenterIn(root, offset, 0)
        else
            item.layout(item.control):AtBottomIn(root,
                compactBottom * pixel / item.scale + (index - 1) * (item.height + gap) - offset)
                :AtHorizontalCenterIn(root)
        end
        for _, control in ipairs(item.parts) do control:SetAlpha(alpha) end
    end

    local function Fill()
        local limit = center and 1 or compactLimit
        while table.getn(active) < limit and table.getn(pending) > 0 do
            local item = NewCard(table.remove(pending, 1))
            table.insert(active, item)
            Configure(item)
            Paint(item, table.getn(active))
        end
        root:SetNeedsFrameUpdate(table.getn(active) > 0)
    end

    local previousOnFrame = root.OnFrame
    root.OnFrame = function(control, elapsed)
        if previousOnFrame then previousOnFrame(control, elapsed) end
        local duration = center and 2.6 or 4
        local reposition = false
        for index = table.getn(active), 1, -1 do
            local item = active[index]
            item.age = item.age + elapsed
            if item.age >= duration then
                item.control:Destroy()
                table.remove(active, index)
                reposition = true
            end
        end
        for index, item in ipairs(active) do
            if reposition or item.age - elapsed <= motionIn or item.age >= duration - motionOut then
                Paint(item, index)
            end
        end
        if reposition then Fill() end
    end

    function display:Show(kind, textKey, value, icon, iconFrame)
        if table.getn(pending) >= queueLimit then table.remove(pending, 1) end
        table.insert(pending, { kind = kind, textKey = textKey, value = value, icon = icon, iconFrame = iconFrame })
        Fill()
    end

    function display:Clear()
        for _, item in ipairs(active) do item.control:Destroy() end
        active, pending = {}, {}
        root:SetNeedsFrameUpdate(false)
    end

    local function Dismiss(kind)
        for index = table.getn(pending), 1, -1 do
            if pending[index].kind == kind then table.remove(pending, index) end
        end
        for index = table.getn(active), 1, -1 do
            if active[index].event.kind == kind then
                active[index].control:Destroy()
                table.remove(active, index)
            end
        end
        for index, item in ipairs(active) do Paint(item, index) end
        Fill()
    end

    local function Refresh()
        for index, item in ipairs(active) do
            Configure(item)
            Paint(item, index)
        end
    end

    scope:Bind(options.notificationsMode.OnChanged, function()
        center = options.notificationsMode:Get() == 'center'
        for index = table.getn(active), 1, -1 do
            local item = active[index]
            item.control:Destroy()
            table.insert(pending, 1, item.event)
        end
        active = {}
        Fill()
    end)
    scope:Bind(options.notificationsScale.OnChanged, Refresh)
    for kind, option in pairs({ hq = options.notificationsHQ, acu = options.notificationsACU,
        nuke = options.notificationsNuke, experimental = options.notificationsExperimental, smd = options.notificationsSmd }) do
        local eventKind = kind
        scope:Bind(option.OnChanged, function(_, enabled)
            if not enabled then Dismiss(eventKind) end
        end)
    end
    localization.Subscribe(root, Refresh)
    scope:Defer(function() localization.Unsubscribe(root) end)
    return display
end
