-- Transient build-cycle preview. Does not own or advance the actual cycle.
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
    local view={}
    function view:Hide()
        root:SetNeedsFrameUpdate(false); root:Hide(); activeId=nil
    end
    function view:Show(name,records,selected)
        if content then content:Destroy() end
        content=Group(root); content:DisableHitTest()
        local count=table.getn(records)
        if count==0 then self:Hide(); return end
        local columns=math.min(8,count)
        local rows=math.ceil(count/columns)
        local width,height=columns*54-6,rows*54-6
        L(root):Width(width):Height(height):AtLeftTopIn(parent,(parent.Width()/scale-width)/2,math.min(parent.Height()/scale-height-24,parent.Height()/scale*0.72))
        for i,record in ipairs(records) do
            local chosen=record.id==selected
            local x,y=math.mod(i-1,columns)*54,math.floor((i-1)/columns)*54
            local tile=Group(content); tile:DisableHitTest()
            L(tile):AtLeftTopIn(root,x,y):Width(48):Height(48)
            local icon=Bitmap(tile); icon:SetTexture(UI.UIFile(record.icon,true)); icon:DisableHitTest()
            icon:SetAlpha(chosen and 1 or 0.45)
            L(icon):AtLeftTopIn(tile,2,2):Width(44):Height(44)
            if chosen then Theme.Outline(tile,L,48,48,C.accentText) end
        end
        elapsed=0; activeId=selected; root:Show(); root:SetNeedsFrameUpdate(true)
    end
    root.OnFrame=function(self,delta)
        elapsed=elapsed+delta
        local mode=Commands.GetCommandMode()
        if elapsed>=1.1 or mode[1]~='build' or not mode[2] or (mode[2].claretEntry or mode[2].name)~=activeId then view:Hide() end
    end
    function view:Destroy()
        root:SetNeedsFrameUpdate(false); root:Destroy()
    end
    view:Hide()
    return view
end
