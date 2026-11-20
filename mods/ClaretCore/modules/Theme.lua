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
    health = 'ff28b84a',
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
    title=22, heading=18, label=13, caption=12, glyph=20, panelRadius=8,
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
local PanelFillCorners = {
    tl = '/mods/ClaretCore/textures/ui/panel-corner-tl.png',
    tr = '/mods/ClaretCore/textures/ui/panel-corner-tr.png',
    bl = '/mods/ClaretCore/textures/ui/panel-corner-bl.png',
    br = '/mods/ClaretCore/textures/ui/panel-corner-br.png',
}
local PanelRingCorners = {
    tl = '/mods/ClaretCore/textures/ui/panel-ring-tl.png',
    tr = '/mods/ClaretCore/textures/ui/panel-ring-tr.png',
    bl = '/mods/ClaretCore/textures/ui/panel-ring-bl.png',
    br = '/mods/ClaretCore/textures/ui/panel-ring-br.png',
}

local PanelShadowCorners = {
    tl = '/mods/ClaretCore/textures/ui/panel-shadow-tl.png',
    tr = '/mods/ClaretCore/textures/ui/panel-shadow-tr.png',
    bl = '/mods/ClaretCore/textures/ui/panel-shadow-bl.png',
    br = '/mods/ClaretCore/textures/ui/panel-shadow-br.png',
}
local PanelShadowEdges = {
    top = '/mods/ClaretCore/textures/ui/panel-shadow-top.png',
    bottom = '/mods/ClaretCore/textures/ui/panel-shadow-bottom.png',
    left = '/mods/ClaretCore/textures/ui/panel-shadow-left.png',
    right = '/mods/ClaretCore/textures/ui/panel-shadow-right.png',
}local PANEL_BLUR = 16

-- Turns a solid panel into a rounded surface: the control keeps its size and hit
-- area, its own fill becomes transparent, and fills, corner masks and a soft
-- shadow draw the surface. Radius comes from Metrics.panelRadius so the whole
-- interface can be retuned in one place. Returns Resize(width, height).
function RoundedPanel(control, layout, width, height, color, borderColor, shadow)
    local Bitmap = import('/lua/maui/bitmap.lua').Bitmap
    local radius = Metrics.panelRadius or 4
    control:SetSolidColor(Colors.transparent)
    local fills, rings, edges, shadows = {}, {}, {}, {}
    local function Part(container, x, y, w, h, tint, texture, depthOffset)
        local b = Bitmap(container)
        b.Depth:Set(function() return container.Depth() + depthOffset end)
        -- Textured masks carry their colour (baked at build time): Maui has no
        -- documented way to tint a texture, and SetSolidColor on a textured
        -- bitmap would replace the image with a flat rectangle.
        if texture then b:SetTexture(texture) else b:SetSolidColor(tint) end
        b:DisableHitTest()
        layout(b):AtLeftTopIn(container, x, y):Width(w):Height(h)
        return b
    end
    if shadow then
        local b = PANEL_BLUR
        shadows[1] = Part(control, 0, -b, width, b, nil, PanelShadowEdges.top, 0)
        shadows[2] = Part(control, 0, height, width, b, nil, PanelShadowEdges.bottom, 0)
        shadows[3] = Part(control, -b, 0, b, height, nil, PanelShadowEdges.left, 0)
        shadows[4] = Part(control, width, 0, b, height, nil, PanelShadowEdges.right, 0)
        shadows[5] = Part(control, -b, -b, b, b, nil, PanelShadowCorners.tl, 0)
        shadows[6] = Part(control, width, -b, b, b, nil, PanelShadowCorners.tr, 0)
        shadows[7] = Part(control, -b, height, b, b, nil, PanelShadowCorners.bl, 0)
        shadows[8] = Part(control, width, height, b, b, nil, PanelShadowCorners.br, 0)
    end
    fills[1] = Part(control, radius, 0, width - radius * 2, height, color, nil, 1)
    fills[2] = Part(control, 0, radius, width, height - radius * 2, color, nil, 1)
    fills[3] = Part(control, 0, 0, radius * 2, radius * 2, color, PanelFillCorners.tl, 1)
    fills[4] = Part(control, width - radius * 2, 0, radius * 2, radius * 2, color, PanelFillCorners.tr, 1)
    fills[5] = Part(control, 0, height - radius * 2, radius * 2, radius * 2, color, PanelFillCorners.bl, 1)
    fills[6] = Part(control, width - radius * 2, height - radius * 2, radius * 2, radius * 2, color, PanelFillCorners.br, 1)
    if borderColor then
        edges[1] = Part(control, radius, 0, width - radius * 2, 1, borderColor, nil, 2)
        edges[2] = Part(control, radius, height - 1, width - radius * 2, 1, borderColor, nil, 2)
        edges[3] = Part(control, 0, radius, 1, height - radius * 2, borderColor, nil, 2)
        edges[4] = Part(control, width - 1, radius, 1, height - radius * 2, borderColor, nil, 2)
        rings[1] = Part(control, 0, 0, radius * 2, radius * 2, borderColor, PanelRingCorners.tl, 2)
        rings[2] = Part(control, width - radius * 2, 0, radius * 2, radius * 2, borderColor, PanelRingCorners.tr, 2)
        rings[3] = Part(control, 0, height - radius * 2, radius * 2, radius * 2, borderColor, PanelRingCorners.bl, 2)
        rings[4] = Part(control, width - radius * 2, height - radius * 2, radius * 2, radius * 2, borderColor, PanelRingCorners.br, 2)
    end
    local function Place(w, h)
        if not (w and h and w > 0 and h > 0) then return end
        if shadow then
            local b = PANEL_BLUR
            layout(shadows[1]):AtLeftTopIn(control, 0, -b):Width(w):Height(b)
            layout(shadows[2]):AtLeftTopIn(control, 0, h):Width(w):Height(b)
            layout(shadows[3]):AtLeftTopIn(control, -b, 0):Width(b):Height(h)
            layout(shadows[4]):AtLeftTopIn(control, w, 0):Width(b):Height(h)
            layout(shadows[5]):AtLeftTopIn(control, -b, -b):Width(b):Height(b)
            layout(shadows[6]):AtLeftTopIn(control, w, -b):Width(b):Height(b)
            layout(shadows[7]):AtLeftTopIn(control, -b, h):Width(b):Height(b)
            layout(shadows[8]):AtLeftTopIn(control, w, h):Width(b):Height(b)
        end
        layout(fills[1]):AtLeftTopIn(control, radius, 0):Width(math.max(0, w - radius * 2)):Height(h)
        layout(fills[2]):AtLeftTopIn(control, 0, radius):Width(w):Height(math.max(0, h - radius * 2))
        layout(fills[3]):AtLeftTopIn(control, 0, 0):Width(radius * 2):Height(radius * 2)
        layout(fills[4]):AtLeftTopIn(control, w - radius * 2, 0):Width(radius * 2):Height(radius * 2)
        layout(fills[5]):AtLeftTopIn(control, 0, h - radius * 2):Width(radius * 2):Height(radius * 2)
        layout(fills[6]):AtLeftTopIn(control, w - radius * 2, h - radius * 2):Width(radius * 2):Height(radius * 2)
        if borderColor then
            layout(edges[1]):AtLeftTopIn(control, radius, 0):Width(math.max(0, w - radius * 2)):Height(1)
            layout(edges[2]):AtLeftTopIn(control, radius, h - 1):Width(math.max(0, w - radius * 2)):Height(1)
            layout(edges[3]):AtLeftTopIn(control, 0, radius):Width(1):Height(math.max(0, h - radius * 2))
            layout(edges[4]):AtLeftTopIn(control, w - 1, radius):Width(1):Height(math.max(0, h - radius * 2))
            layout(rings[1]):AtLeftTopIn(control, 0, 0):Width(radius * 2):Height(radius * 2)
            layout(rings[2]):AtLeftTopIn(control, w - radius * 2, 0):Width(radius * 2):Height(radius * 2)
            layout(rings[3]):AtLeftTopIn(control, 0, h - radius * 2):Width(radius * 2):Height(radius * 2)
            layout(rings[4]):AtLeftTopIn(control, w - radius * 2, h - radius * 2):Width(radius * 2):Height(radius * 2)
        end
    end
    Place(width, height)
    return Place
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

-- Visual part of a settings toggle. The host row owns input and persistence.
function SettingsSwitch(row, layout, rowWidth, rowHeight, textScale, compact)
    local Bitmap = import('/lua/maui/bitmap.lua').Bitmap
    local UI = import('/lua/ui/uiutil.lua')
    local width, height = compact and 48 or 56, compact and 28 or 32
    local thumbWidth, thumbHeight = compact and 18 or 20, compact and 20 or 24
    local x = rowWidth - 16 - width
    local switch = Bitmap(row)
    switch:DisableHitTest()
    switch.Depth:Set(function() return row.Depth() + 1 end)
    layout(switch):AtLeftTopIn(row, x, math.floor((rowHeight - height) / 2)):Width(width):Height(height)
    local paintOutline = Outline(switch, layout, width, height)

    local thumb = Bitmap(switch)
    thumb:DisableHitTest()
    thumb.Depth:Set(function() return switch.Depth() + 1 end)
    layout(thumb):Width(thumbWidth):Height(thumbHeight)

    local state = UI.CreateText(row, '', Metrics.text * textScale, Fonts.body)
    state:DisableHitTest()
    state.Depth:Set(function() return row.Depth() + 2 end)
    layout(state):AtLeftTopIn(row, x - 32, math.floor((rowHeight - Metrics.text) / 2))

    return function(on)
        state:SetText(on and '●' or '○')
        state:SetColor(on and Colors.accentText or Colors.muted)
        switch:SetSolidColor(on and Colors.accent or Colors.surface)
        paintOutline(on and Colors.selectedBorder or Colors.muted)
        layout(thumb):AtLeftTopIn(switch, on and width - thumbWidth - 4 or 4, 4)
        thumb:SetSolidColor(on and Colors.text or Colors.muted)
    end
end

