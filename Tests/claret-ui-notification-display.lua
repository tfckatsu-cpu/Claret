table.getn = table.getn or function(value) return #value end
local callbacks, children = {}, {}
local env = setmetatable({ LOC = function(text) return text end }, { __index = _G })
local function Control(parent)
    local control = { parent = parent, Depth = { Set = function() end } }
    function control:DisableHitTest() self.clickThrough = true end
    function control:SetSolidColor(color) self.fill = color end
    function control:SetTexture(path) self.texture = path end
    function control:SetDropShadow(value) self.shadow = value end
    function control:SetColor() end
    function control:SetAlpha(alpha) self.alpha = alpha end
    function control:SetFont(_, size) self.size = size end
    function control:SetText(text) self.text = text end
    function control:GetStringAdvance(text) return string.len(text) * (self.size or 14) / 2 end
    function control:SetNeedsFrameUpdate(value) self.updates = value end
    function control:Destroy() self.destroyed = true end
    table.insert(children, control)
    return control
end

local screen = { Width = function() return 1280 end, Height = function() return 1024 end }
local function Layouter(scale)
    return function(control)
        local layout = {}
        function layout:Fill(parent)
            control.Width, control.Height = parent.Width, parent.Height
            return self
        end
        function layout:Width(width) control.Width = function() return math.floor(width * scale) end; return self end
        function layout:Height(height) control.height = height * scale; return self end
        function layout:AtCenterIn(_, top, left) control.y, control.x = top * scale, left * scale; return self end
        function layout:AtBottomIn(_, offset) control.bottom = offset * scale; return self end
        function layout:AtHorizontalCenterIn() return self end
        function layout:AtLeftCenterIn(_, offset) control.x = offset * scale; return self end
        function layout:AtLeftTopIn() return self end
        return layout
    end
end
assert(loadfile('../mods/ClaretUI/modules/LocalizationStrings.lua', 't', env))()
local strings = env.Strings.en
local exports = {
    ['/mods/ClaretCore/modules/Theme.lua'] = env,
    ['/lua/maui/group.lua'] = { Group = Control },
    ['/lua/maui/bitmap.lua'] = { Bitmap = Control },
    ['/lua/ui/uiutil.lua'] = { CreateText = Control },
    ['/lua/maui/layouthelpers.lua'] = { GetPixelScaleFactor = function() return 1.25 end },
    ['/lua/ui/game/borders.lua'] = { GetMapGroup = function() return screen end },
}
assert(loadfile('../mods/ClaretCore/modules/Theme.lua', 't', env))()
env.import = function(path) return exports[path] end
local onLanguageChanged
env.ReUI = { UI = { FloorLayouter = Layouter }, ClaretCore = { Localization = {
    Text = function(key) return strings[key] or key end,
    Subscribe = function(_, refresh) onLanguageChanged = refresh end,
    Unsubscribe = function() end,
} } }
local scope = {
    Own = function(_, control) return control end,
    Defer = function() end,
    Bind = function(_, event, callback) callbacks[event] = callback end,
}
local function Option(value)
    local option = { OnChanged = {} }
    function option:Get() return value end
    function option:Set(newValue)
        value = newValue
        callbacks[self.OnChanged](self, value)
    end
    return option
end
local options = { notificationsMode = Option('compact'), notificationsScale = Option(100),
    notificationsHQ = Option(true), notificationsACU = Option(true), notificationsNuke = Option(true) }
assert(loadfile('../mods/ClaretUI/modules/NotificationDisplay.lua', 't', env))()
local display = env.Create(scope, options)
local root = children[1]
local function Cards()
    local cards = {}
    for _, control in ipairs(children) do
        if control.parent == root and not control.destroyed then table.insert(cards, control) end
    end
    return cards
end

local function Parts(card)
    local parts = {}
    for _, control in ipairs(children) do
        if control.parent == card then table.insert(parts, control) end
    end
    return parts
end

display:Show('hq', 'hq_air', '2', 'air-hq.dds', 'air-frame.dds')
root:OnFrame(1)
local upgrade = 'Система распределения ресурсов'
local customUpgrade = { id = 'ModUpgrade', name = upgrade }
display:Show('acu', nil, customUpgrade, 'upgrade.dds')
local cards = Cards()
assert(#cards == 2 and cards[1].bottom < cards[2].bottom, 'Compact cards should form a stack above the HUD')
assert(cards[1].clickThrough, 'Cards should pass through map input')
local parts = Parts(cards[1])
assert(#parts == 5 and parts[1].fill and parts[3].texture == 'air-frame.dds' and parts[4].texture == 'air-hq.dds'
    and parts[5].text == 'T2 Air HQ ready.', 'Compact HQ should use a framed portrait and a single line')
parts = Parts(cards[2])
local label = parts[4]
assert(parts[3].texture == 'upgrade.dds' and label.text == upgrade .. ' ready.', 'Compact ACU should show the full title')
local width = cards[1].Width()
assert(cards[2].Width() > width and label.x + label:GetStringAdvance(label.text) < cards[2].Width(),
    'A longer title should widen its own card and fit beside the icon')
options.notificationsScale:Set(200)
assert(cards[1].Width() > width and cards[1].bottom == 210, 'Compact size should grow around the same bottom anchor')
assert(label.text == upgrade .. ' ready.' and label.x + label:GetStringAdvance(label.text) < cards[2].Width(),
    'At 200% the title must still fit without truncation')
root:OnFrame(3.1)
assert(#Cards() == 1, 'Expiring the first card should preserve the second card')
display:Clear()

options.notificationsMode:Set('center')
display:Show('hq', 'hq_air', '3', 'air-hq.dds', 'air-frame.dds')
display:Show('nuke')
cards = Cards()
assert(#cards == 1 and cards[1].x == 0 and cards[1].y > 0,
    'Center display should start below center and ignore compact size')
parts = Parts(cards[1])
assert(#parts == 3 and parts[1].texture == 'air-frame.dds' and parts[2].texture == 'air-hq.dds'
    and parts[3].text == 'T3 Air HQ ready.' and parts[3].shadow and parts[3].size == 26,
    'Center mode should draw only the framed icon and legible text at its own scale')
assert(parts[2].x < parts[3].x and parts[2].Width() == 50 and parts[2].height == 50,
    'Center mode should position a square HQ portrait to the left of the text')
root:OnFrame(0.4)
assert(cards[1].y == 0, 'Opening motion should settle at center')
root:OnFrame(2.3)
assert(#Cards() == 1 and Cards()[1] ~= cards[1], 'The next center alert should start after 2.6 seconds')
parts = Parts(Cards()[1])
assert(#parts == 1 and parts[1].text == 'Strategic missile ready.', 'Center nuke alert should have only the readiness line')
options.notificationsNuke:Set(false)
assert(#Cards() == 0 and not root.updates, 'Disabling the active event should dismiss it and stop frame updates')

local rootWidth = root.Width
root.Width = function() return 650 end
strings = env.Strings.ru
display:Show('acu', nil, customUpgrade, 'upgrade.dds')
local narrowCard = Cards()[1]
label = Parts(narrowCard)[2]
assert(label.text == 'Улучшение «' .. upgrade .. '» установлено.' and label.size < 26,
    'A long Russian fallback should fit the viewport and use neutral wording')
assert(label.x + label:GetStringAdvance(label.text) < narrowCard.Width() and narrowCard.Width() <= 602,
    'The complete center title and icon should fit inside the viewport')
root.Width = rootWidth
display:Clear()

display:Show('acu', nil, { id = 'DamageStabilization', unitId = 'UEL0001', name = 'Repair system' })
label = Parts(Cards()[1])[1]
assert(label.text == 'Нано — готово.', 'The UEF upgrade should use the approved Russian noun and neuter form')
strings = env.Strings.en
onLanguageChanged()
assert(label.text == 'Nano ready.', 'An active notification should pick up the current Claret language')
display:Clear()
display:Show('acu', nil, { id = 'DamageStabilization', unitId = 'xsl0001', name = 'Repair system' })
assert(Parts(Cards()[1])[1].text == 'Repair system ready.', 'The Seraphim upgrade with the same ID should use its game name')
display:Clear()
display:Show('acu', nil, { id = 'ResourceAllocation', unitId = 'xsl0001', name = 'Resource allocation system' })
label = Parts(Cards()[1])[1]
assert(label.text == 'RAS ready.', 'Shared upgrades should use the common short label')
strings = env.Strings.ru
onLanguageChanged()
assert(label.text == 'RAS — готов.', 'RAS should be spelled identically in English and Russian')

display:Clear()
display:Show('acu', nil, { id = 'TacticalNukeMissile', unitId = 'uel0001', name = 'Billy' })
assert(Parts(Cards()[1])[1].text == 'Билли нюка — готова.', 'The Billy upgrade should use the feminine form')
display:Clear()
display:Show('acu', nil, { id = 'NaniteTorpedoTube', unitId = 'url0001', name = 'Torpedo launcher' })
assert(Parts(Cards()[1])[1].text == 'Торпеды — готовы.', 'Torpedoes should use the plural form')

print('PASS: Claret UI notification display scales, animates, and expires each card independently')
