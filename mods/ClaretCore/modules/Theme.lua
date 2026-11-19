Fonts = { body = 'Nunito', heading = 'Nunito SemiBold' }
-- Claret visual tokens. ARGB colours; shared by every Claret UI module.
Colors = {
    canvas = 'ff080c0a',
    surface = 'ff141416',
    raised = 'ff1b1b20',
    hover = 'ff27232a',
    pressed = 'ff3b3039',
    scrim = '78000000',
    transparent = '00000000',
    border = 'ff343638',
    text = 'ffe8e8e6',
    muted = 'ff929394',
    accent = 'ff7a1f30',
    accentHover = 'ff962a43',
    accentPressed = 'ff57131f',
    selected = 'ff32171f',
    selectedBorder = 'ff743043',
    accentText = 'ffe5a1b0',
    danger = 'fff06b7a',
    success = 'ff99bd69',
    warning = 'fff0b64d',
    warningSurface = 'ff342817',
    warningBorder = 'ff80602e',
    lock = 'ffb6b1bc',
    lockSurface = 'ff1b1b20',
    lockBorder = 'ff55515b',
    disabled = 'ff605d65',
    disabledText = 'ff8a8792',
    keyCombo0 = 'ff7f8794', -- no modifier
    keyCombo1 = 'ff64b5f6', -- Ctrl
    keyCombo2 = 'ffc792ea', -- Shift
    keyCombo3 = 'ff4db6ac', -- Ctrl + Shift
    keyCombo4 = 'ffffba66', -- Alt
    keyCombo5 = 'ffff7785', -- Ctrl + Alt
    keyCombo6 = 'ff9ccc65', -- Shift + Alt
    keyCombo7 = 'ff7986cb', -- Ctrl + Shift + Alt
}
-- Logical units, before the shared FloorLayouter scale.
Metrics = { launcherWidth=248, launcherHeight=400, panelWidth=1128, panelHeight=1110,
    corePanelWidth=552, corePanelHeight=408, coreCardWidth=520, coreRowHeight=56,
    coreRowStep=64, coreControlHeight=56,
    panelGap=16, padding=24, text=16, secondaryText=14, buttonText=15, launcherText=18,
    title=22, heading=18, label=13, caption=12, glyph=20,
    rowHeight=40, buttonHeight=36, fieldHeight=36 }
-- Flat faction marks, rasterized from the SVG masters in textures/factions.
FactionIcons = {
    UEF = '/mods/ClaretCore/textures/factions/uef-32.dds',
    AEON = '/mods/ClaretCore/textures/factions/aeon-32.dds',
    CYBRAN = '/mods/ClaretCore/textures/factions/cybran-32.dds',
    SERAPHIM = '/mods/ClaretCore/textures/factions/seraphim-32.dds',
}
Logos = {
    mark = '/mods/ClaretCore/textures/branding/claret-mark.dds',
    wordmark = '/mods/ClaretCore/textures/branding/claret-wordmark.dds',
}
-- Choose a native raster size; the caller places it at that many screen pixels.
function FactionIcon(faction, preferredSize)
    local size=24
    for _,candidate in ipairs({32,48}) do
        if math.abs(candidate-preferredSize)<math.abs(size-preferredSize) then size=candidate end
    end
    return '/mods/ClaretCore/textures/factions/'..string.lower(faction)..'-'..size..'.dds',size
end
-- Short, bounded opening motion; reposition only, preserving per-control alpha.
function AnimateOpening(control, position)
    local elapsed=0
    position(-8)
    control.OnFrame=function(self,delta)
        elapsed=math.min(0.16,elapsed+delta)
        local remaining=1-elapsed/0.16
        position(-8*remaining*remaining)
        if elapsed>=0.16 then self:SetNeedsFrameUpdate(false) end
    end
    control:SetNeedsFrameUpdate(true)
end
function AnimateCentered(control, parent, layout)
    AnimateOpening(control,function(offset) layout(control):AtCenterIn(parent,offset,0) end)
end
function AnimateAnchored(control, parent, layout, x, y)
    AnimateOpening(control,function(offset) layout(control):AtLeftTopIn(parent,x,y+offset) end)
end
-- Borders are four static strips, independent of faction-specific UI textures.
function Outline(control, layout, width, height, color)
    local Bitmap = import('/lua/maui/bitmap.lua').Bitmap
    local lines = {}
    local positions = {{0,0,width,1},{0,height-1,width,1},{0,1,1,height-2},{width-1,1,1,height-2}}
    for _, p in ipairs(positions) do
        local line = Bitmap(control)
        line.Depth:Set(function() return control.Depth() + 1 end)
        line:SetSolidColor(color or Colors.border)
        line:DisableHitTest()
        layout(line):AtLeftTopIn(control,p[1],p[2]):Width(p[3]):Height(p[4])
        table.insert(lines,line)
    end
    local function Resize(w,h)
        local pos={{0,0,w,1},{0,h-1,w,1},{0,1,1,h-2},{w-1,1,1,h-2}}
        for i,line in ipairs(lines) do
            local p=pos[i]; layout(line):AtLeftTopIn(control,p[1],p[2]):Width(p[3]):Height(p[4])
        end
    end
    return function(value)
        for _, line in ipairs(lines) do line:SetSolidColor(value) end
    end, Resize
end

