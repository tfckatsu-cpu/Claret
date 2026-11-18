-- Standalone quick-repeat settings window, opened from the Hotbuild launcher gear.
function Create(parent, scale, option)
    if (type(parent) ~= 'userdata' and type(parent) ~= 'table') or type(scale) ~= 'number' or not option then return nil end

    local Theme = import('/mods/ClaretCore/modules/Theme.lua')
    local Group = import('/lua/maui/group.lua').Group
    local Bitmap = import('/lua/maui/bitmap.lua').Bitmap
    local UI = import('/lua/ui/uiutil.lua')
    local Helpers = import('/lua/maui/layouthelpers.lua')
    local C = Theme.Colors
    local L = ReUI.UI.FloorLayouter(scale)
    local ratio = scale / Helpers.GetPixelScaleFactor()
    local width, height = 1080, 240
    local root = Group(parent)

    local ok, err = pcall(function()
        L(root):AtCenterIn(parent):Width(width):Height(height)
        local surface = Bitmap(root)
        surface:SetSolidColor(C.canvas)
        surface:DisableHitTest()
        L(surface):Fill(root)
        Theme.Outline(surface, L, width, height)

        local close = Group(root)
        L(close):AtLeftTopIn(root, width - 64, 12):Width(40):Height(40)
        local closeLabel = UI.CreateText(close, '×', 20 * ratio, Theme.Fonts.body)
        closeLabel:SetColor(C.text)
        closeLabel:DisableHitTest()
        L(closeLabel):AtCenterIn(close)
        close.HandleEvent = function(self, event)
            if event.Type == 'MouseEnter' then closeLabel:SetColor(C.accentText)
            elseif event.Type == 'MouseExit' then closeLabel:SetColor(C.text)
            elseif event.Type == 'ButtonPress' and not (event.Modifiers and event.Modifiers.Right) then root:Destroy() end
            return true
        end

        local editor = import('/mods/ClaretHotbuild/modules/QuickRepeatSettings.lua')
        editor.Create(root, { scale = scale, height = height }, option)
    end)
    if not ok then root:Destroy(); error(err) end
    root.RequestClose = function() root:Destroy() end
    return root
end
