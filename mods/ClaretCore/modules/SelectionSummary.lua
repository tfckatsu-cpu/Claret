-- Reads the current visible selection only. Never changes selection or issues orders.

---@param parent Control
---@param scope table
---@param event table
function Start(parent, scope, event)
    local Localization = import('/mods/ClaretCore/modules/Localization.lua').Localization
    local Theme = import('/mods/ClaretCore/modules/Theme.lua')
    local C = Theme.Colors
    local Bitmap = import('/lua/maui/bitmap.lua').Bitmap
    local UIUtil = import('/lua/ui/uiutil.lua')
    local LayoutFor = ReUI.UI.FloorLayoutFor
    local panel = scope:Own(Bitmap(parent))
    panel:SetSolidColor(C.surface)
    panel:DisableHitTest()
    panel.Depth:Set(100)
    LayoutFor(panel):AtLeftTopIn(parent, 20, 254):Width(320):Height(64)
    local title = UIUtil.CreateText(panel, Localization.Text('core.selection.title'), 14, Theme.Fonts.body)
    local text = UIUtil.CreateText(panel, '', 13, Theme.Fonts.body)
    title:SetColor(C.text)
    text:SetColor(C.muted)
    title:DisableHitTest()
    text:DisableHitTest()
    LayoutFor(title):AtLeftTopIn(panel, 10, 8)
    LayoutFor(text):AtLeftTopIn(panel, 10, 34)
    local previous
    local lastCount, lastTypes
    local function UpdateLanguage()
        title:SetText(Localization.Text('core.selection.title'))
        if lastCount ~= nil then
            text:SetText(Localization.Text('core.selection.summary', tostring(lastCount), tostring(lastTypes)))
        end
        previous = nil
    end
    Localization.Subscribe(panel, UpdateLanguage)
    scope:Defer(function() Localization.Unsubscribe(panel) end)
    local function Refresh(units)
        local count = 0
        local types = {}
        local typeCount = 0
        for _, unit in ipairs(units) do
            if not unit:IsDead() then
                count = count + 1
                local id = unit:GetBlueprint().BlueprintId
                if id and not types[id] then
                    types[id] = true
                    typeCount = typeCount + 1
                end
            end
        end
        lastCount, lastTypes = count, typeCount
        local value = Localization.Text('core.selection.summary', tostring(count), tostring(typeCount))
        if value ~= previous then
            text:SetText(value)
            previous = value
        end
    end
    scope:Bind(event, function(sender, units) Refresh(units or {}) end)
    -- Only initial creation reads the accessor; events carry their own new selection.
    Refresh(GetSelectedUnits() or {})
end
