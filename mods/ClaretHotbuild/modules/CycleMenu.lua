-- Transient build-cycle preview. Does not own or advance the actual cycle.
local FadeSeconds = 0.15
local TileSize = 56
local TileStep = 62
local TierLabel = { T1 = 'T1', T2 = 'T2', T3 = 'T3' }

function Create(parent)
    local Theme=import('/mods/ClaretCore/modules/Theme.lua')
    local C=Theme.Colors
    local Group=import('/lua/maui/group.lua').Group
    local Bitmap=import('/lua/maui/bitmap.lua').Bitmap
    local UI=import('/lua/ui/uiutil.lua')
    local Helpers=import('/lua/maui/layouthelpers.lua')
    local Commands=import('/lua/ui/game/commandmode.lua')
    local scale=math.max(0.25,math.min(Helpers.GetPixelScaleFactor(),parent.Width()/800))
    local L=ReUI.UI.FloorLayouter(scale)
    local root=Group(parent); root.Depth:Set(900); root:DisableHitTest()
    local content,elapsed,activeId=nil,0,nil
    local opacity, fadingOut, layers = 0, false, {}
    local function ApplyOpacity(value)
        opacity = value
        for _, layer in ipairs(layers) do layer.control:SetAlpha(value * layer.alpha) end
    end
    local function Track(control, alpha)
        control:DisableHitTest()
        table.insert(layers, { control = control, alpha = alpha })
    end
    local view={}
    function view:Hide()
        activeId=nil
        fadingOut = true
    end
    function view:Show(name,records,selected)
        local count=table.getn(records)
        if count==0 then self:Hide(); return end
        if content then content:Destroy() end
        layers = {}
        content=Group(root); content:DisableHitTest()
        local columns=math.min(8,count)
        local rows=math.ceil(count/columns)
        local width,height=columns*TileStep-6,rows*TileStep-6
        L(root):Width(width):Height(height):AtLeftTopIn(parent,(parent.Width()/scale-width)/2,math.min(parent.Height()/scale-height-24,parent.Height()/scale*0.72))
        L(content):AtLeftTopIn(root,0,0):Width(width):Height(height)
        for i,record in ipairs(records) do
            local chosen=record.id==selected
            local x,y=math.mod(i-1,columns)*TileStep,math.floor((i-1)/columns)*TileStep
            local tile=Group(content); tile:DisableHitTest()
            L(tile):AtLeftTopIn(root,x,y):Width(TileSize):Height(TileSize)
            if chosen then
                local background=Bitmap(tile)
                background:SetSolidColor(C.canvas)
                background.Depth:Set(function() return tile.Depth()+1 end)
                L(background):AtLeftTopIn(tile,0,0):Width(TileSize):Height(TileSize)
                Track(background,0.72)
                local edges={{0,0,TileSize,2},{0,TileSize-2,TileSize,2},
                    {0,2,2,TileSize-4},{TileSize-2,2,2,TileSize-4}}
                for _, edge in ipairs(edges) do
                    local line=Bitmap(tile)
                    line:SetSolidColor(C.accentText)
                    line.Depth:Set(function() return tile.Depth()+2 end)
                    L(line):AtLeftTopIn(tile,edge[1],edge[2]):Width(edge[3]):Height(edge[4])
                    Track(line,0.9)
                end
            end
            local icon=Bitmap(tile); icon:SetTexture(UI.UIFile(record.icon,true))
            icon.Depth:Set(function() return tile.Depth()+3 end)
            Track(icon,chosen and 1 or 0.7)
            L(icon):AtLeftTopIn(tile,3,1):Width(50):Height(50)
            local tier=TierLabel[record.tech]
            if tier then
                local badge=Bitmap(tile)
                badge:SetSolidColor(C.canvas)
                badge.Depth:Set(function() return tile.Depth()+4 end)
                L(badge):AtLeftTopIn(tile,17,40):Width(22):Height(14)
                Track(badge,0.9)
                local label=UI.CreateText(badge,tier,11*scale/Helpers.GetPixelScaleFactor(),Theme.Fonts.body)
                label:SetColor(C.hudValue)
                label.Depth:Set(function() return badge.Depth()+1 end)
                L(label):AtCenterIn(badge)
                Track(label,1)
            end
        end
        elapsed=0; activeId=selected; fadingOut=false
        ApplyOpacity(opacity)
        root:Show(); root:SetNeedsFrameUpdate(true)
    end
    root.OnFrame=function(self,delta)
        elapsed=elapsed+delta
        local mode=Commands.GetCommandMode()
        if elapsed>=1.1 or mode[1]~='build' or not mode[2] or (mode[2].claretEntry or mode[2].name)~=activeId then view:Hide() end
        local step=delta/FadeSeconds
        if fadingOut then
            ApplyOpacity(math.max(0,opacity-step))
            if opacity==0 then self:SetNeedsFrameUpdate(false); self:Hide() end
        elseif opacity<1 then
            ApplyOpacity(math.min(1,opacity+step))
        end
    end
    function view:Destroy()
        root:SetNeedsFrameUpdate(false); root:Destroy()
    end
    root:Hide()
    return view
end
