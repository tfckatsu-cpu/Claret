-- Session-owned Claret settings. Registration creates no Maui controls.
function TraceInput(enabled,owner)
    local options=ReUI.Options and ReUI.Options.Mods and ReUI.Options.Mods['ClaretCore']
    local probe=options and options.probeEnabled
    if probe and probe:Get() then LOG('[Claret][input] capture='..(enabled and 'on' or 'off')..' owner='..owner) end
end
function Create(keyBinding, scaleOption)
    local sections, ids = {}, {}
    local sectionOrder={core=1,hotbuild=2,ui=3,cinema=4}
    local function InsertSection(definition)
        local rank=sectionOrder[definition.id]
        if not rank then table.insert(sections,definition); return end
        local index=1
        while index<=table.getn(sections) do
            local currentRank=sectionOrder[sections[index].id]
            if currentRank and currentRank>rank then break end
            if not currentRank then break end
            index=index+1
        end
        table.insert(sections,index,definition)
    end
    for _,definition in ipairs({
        {id='core',title='Core',placeholder=true},
        {id='hotbuild',title='Hotbuild',placeholder=true},
        {id='ui',title='UI',placeholder=true},
        {id='cinema',title='Cinema',placeholder=true},
    }) do
        ids[definition.id]=true
        InsertSection(definition)
    end
    local window, editor, disposed
    local memory={launcher={x=0,y=0},panel={x=0,y=0}}
    local menu = {}
    local capturing = false
    function menu:Register(definition)
        if disposed then return false, 'Claret session is disposed' end
        if type(definition)~='table' or type(definition.id)~='string'
            or type(definition.title)~='string' then return false,'Settings ID and title required' end
        if ids[definition.id] then
            local existing
            for index,section in ipairs(sections) do
                if section.id==definition.id then existing=index; break end
            end
            if not existing or not sections[existing].placeholder then
                return false,'Settings already registered: '..definition.id
            end
            sections[existing]=definition
            return true
        end
        ids[definition.id]=true; InsertSection(definition); return true
    end
    function menu:Open(initialSection)
        if disposed or window then return end
        local Localization = import('/mods/ClaretCore/modules/Localization.lua').Localization
        local function T(key) return Localization.Text(key) end
        local Theme=import('/mods/ClaretCore/modules/Theme.lua')
        local C=Theme.Colors
        local Group=import('/lua/maui/group.lua').Group
        local Bitmap=import('/lua/maui/bitmap.lua').Bitmap
        local UI=import('/lua/ui/uiutil.lua')
        local Helpers=import('/lua/maui/layouthelpers.lua')
        local Escape=import('/lua/ui/dialogs/eschandler.lua')
        local Tooltip=import('/lua/ui/game/tooltip.lua')
        local parent=GetFrame(0)
        -- Fit the shared layout to the largest section; Core can use a compact panel inside it.
        local metrics=Theme.Metrics
        local height=metrics.panelHeight
        local width=metrics.panelWidth
        local launcherWidth,gap=metrics.launcherWidth,metrics.panelGap
        local hasMod={}
        local activeMods=rawget(_G,'__active_mods')
        if type(activeMods)=='table' then
            for _,mod in ipairs(activeMods) do
                if type(mod)=='table' and type(mod.name)=='string' then hasMod[mod.name]=true end
            end
        end
        local missingMods={}
        if hasMod['ReUI'] then
            if not hasMod['ReUI.Construction'] then table.insert(missingMods,'ReUI.Construction') end
            if not hasMod['ReUI.Construction.Templates'] then
                table.insert(missingMods,'ReUI.Construction.Templates')
            end
        end
        local visibleSections=math.max(1,math.min(6,table.getn(sections)))
        local launcherHeight=math.min(metrics.launcherHeight,112+visibleSections*48)
        local groupWidth=launcherWidth+gap+width
        local pixel=Helpers.GetPixelScaleFactor()
        local fit=math.min((parent.Width()-24)/groupWidth,(parent.Height()-24)/height)
        local percent=scaleOption and scaleOption:Get()
        if percent~=100 and percent~=150 then percent=125 end
        -- 125% is the original fitted size, so 100% reduces it even on a smaller screen.
        local scale=math.min(fit,math.min(pixel,fit)*(percent/125))
        local L=ReUI.UI.FloorLayouter(scale)
        local ratio=scale/pixel
        local root=Group(parent); window=root
        initialSection=initialSection or memory.section
        memory.section=initialSection
        local state={selected=nil,top=1,bindings={},navItems={},contentItems={},leaveSerial=0,
            panelWidth=width,panelHeight=height}
        local function Focus(item)
            if state.focused then state.focused.focused=false; state.focused.paint() end
            state.focused=item
            if item then item.focused=true; item.paint() end
        end
        local function CancelCapture(silent)
            if not state.capture then return false end
            local active=state.capture; state.capture=nil; capturing=false
            if state.receiver then
                state.receiver:AbandonKeyboardFocus(); state.receiver:Destroy(); state.receiver=nil
            end
            TraceInput(false,'menu_key_capture')
            if not silent then active.cancel() end
            return true
        end
        local function Unbind()
            CancelCapture(true)
            for _,binding in ipairs(state.bindings) do binding.option.OnChanged:Remove(binding.callback) end
            state.bindings={}
        end
        local oldDestroy=root.OnDestroy
        root.OnDestroy=function(self)
            Unbind()
            Localization.Unsubscribe(root)
            if state.escapeBound then Escape.PopEscapeHandler(); state.escapeBound=false end
            local inlineHost=state.inlineHost
            state.inlineHost=nil
            if inlineHost then
                state.inlineEditor=nil
                editor=nil
                inlineHost:Destroy()
            end
            window=nil; editor=nil; oldDestroy(self)
            if not disposed then
                for _,section in ipairs(sections) do
                    if section.onMenuClosed then section.onMenuClosed() end
                end
            end
        end
        local buildContext={
            Localization=Localization,T=T,Theme=Theme,C=C,Group=Group,Bitmap=Bitmap,UI=UI,
            Helpers=Helpers,Escape=Escape,Tooltip=Tooltip,parent=parent,metrics=metrics,
            height=height,width=width,launcherWidth=launcherWidth,gap=gap,
            visibleSections=visibleSections,launcherHeight=launcherHeight,groupWidth=groupWidth,
            pixel=pixel,scale=scale,L=L,ratio=ratio,root=root,initialSection=initialSection,
            state=state,Focus=Focus,CancelCapture=CancelCapture,Unbind=Unbind,
            sections=sections,memory=memory,oldDestroy=oldDestroy,
            getWindow=function() return window end,
            setCapturing=function(value) capturing=value end,
            isDisposed=function() return disposed end,
        }
        local ok,err=pcall(function()
            local ctx=buildContext
            local Localization,T,Theme,C,Group,Bitmap,UI=ctx.Localization,ctx.T,ctx.Theme,ctx.C,ctx.Group,ctx.Bitmap,ctx.UI
            local Helpers,Escape,Tooltip,parent,metrics=ctx.Helpers,ctx.Escape,ctx.Tooltip,ctx.parent,ctx.metrics
            local height,width,launcherWidth,gap=ctx.height,ctx.width,ctx.launcherWidth,ctx.gap
            local visibleSections,launcherHeight,groupWidth=ctx.visibleSections,ctx.launcherHeight,ctx.groupWidth
            local pixel,scale,L,ratio=ctx.pixel,ctx.scale,ctx.L,ctx.ratio
            local root,initialSection,state=ctx.root,ctx.initialSection,ctx.state
            local Focus,CancelCapture,Unbind=ctx.Focus,ctx.CancelCapture,ctx.Unbind
            local sections,memory,oldDestroy=ctx.sections,ctx.memory,ctx.oldDestroy
            L(root):Fill(parent); root.Depth:Set(parent:GetTopmostDepth()+20); root:DisableHitTest()
            local function Surface(owner,x,y,w,h,color)
                local b=Bitmap(owner); b:SetSolidColor(color or C.surface)
                b.Depth:Set(function() return owner.Depth()+1 end)
                L(b):AtLeftTopIn(owner,x,y):Width(w):Height(h); return b
            end
            local function Text(owner,value,x,y,color)
                local t=UI.CreateText(owner,value,metrics.text*ratio,Theme.Fonts.body)
                t.Depth:Set(function() return owner.Depth()+2 end)
                t:SetColor(color or C.text); t:DisableHitTest()
                L(t):AtLeftTopIn(owner,x,y); return t
            end
            local function Interactive(owner,x,y,w,h,action,list,normal,transparent)
                local b=Group(owner); L(b):AtLeftTopIn(owner,x,y):Width(w):Height(h)
                b.Depth:Set(function() return owner.Depth()+1 end)
                local fills={Surface(b,2,0,w-4,h,normal or C.raised),Surface(b,0,2,w,h-4,normal or C.raised)}
                local borders={Surface(b,2,0,w-4,1,C.border),Surface(b,2,h-1,w-4,1,C.border),
                    Surface(b,0,2,1,h-4,C.border),Surface(b,w-1,2,1,h-4,C.border),
                    Surface(b,1,1,1,1,C.border),Surface(b,w-2,1,1,1,C.border),
                    Surface(b,1,h-2,1,1,C.border),Surface(b,w-2,h-2,1,1,C.border)}
                for _,part in ipairs(fills) do part:DisableHitTest() end
                for _,part in ipairs(borders) do part:DisableHitTest() end
                local item={control=b,enabled=true,normal=normal or C.raised,action=action}
                function item.paint()
                    local fill=not item.enabled and C.surface or item.pressed and C.pressed
                        or item.hover and C.hover or item.normal
                    local edge=transparent and C.transparent or item.focused and C.accentText or item.selected and C.selectedBorder or C.border
                    for _,part in ipairs(fills) do part:SetSolidColor(fill) end
                    for _,part in ipairs(borders) do part:SetSolidColor(edge) end
                    if item.label then item.label:SetColor(item.enabled and C.text or C.disabledText) end
                end
                function item:SetEnabled(value) self.enabled=value; self.paint() end
                b.HandleEvent=function(self,event)
                    if state.closing then return true end
                    if event.Type=='WheelRotation' and owner==state.navigation then
                        state.scroll:ScrollLines(nil,event.WheelRotation>0 and -1 or 1)
                    elseif event.Type=='WheelRotation' and owner==state.content and state.maxContentTop and state.maxContentTop>0 then
                        state.panel:ScrollLines(nil,event.WheelRotation>0 and -1 or 1)
                    elseif event.Type=='MouseEnter' then item.hover=true; item.paint()
                    elseif event.Type=='MouseExit' then item.hover=false; item.pressed=false; item.paint()
                    elseif event.Type=='ButtonRelease' then item.pressed=false; item.paint()
                    elseif event.Type=='ButtonPress' and not (event.Modifiers and event.Modifiers.Right) then
                        if item.enabled then Focus(item); item.pressed=true; item.paint(); action() end
                    end
                    return true
                end
                table.insert(list,item); return item
            end
            local function Button(owner,label,x,y,w,action,list)
                local item=Interactive(owner,x,y,w,metrics.buttonHeight,action,list)
                item.label=Text(item.control,label,0,0); L(item.label):AtCenterIn(item.control)
                return item
            end
            local function Status(owner,x,y,width)
                local text=Text(owner,'',x,y,C.muted)
                return function(message,isError,brief)
                    message=message or ''
                    local shown=message
                    while text:GetStringAdvance(shown)>(width or 640)*ratio and string.len(shown)>0 do
                        local finish=string.len(shown)
                        while finish>1 and string.byte(shown,finish)>=128 and string.byte(shown,finish)<192 do finish=finish-1 end
                        shown=string.sub(shown,1,finish-1)
                    end
                    if shown~=message then
                        local finish=string.len(shown)
                        while finish>1 and string.byte(shown,finish)>=128 and string.byte(shown,finish)<192 do finish=finish-1 end
                        shown=string.sub(shown,1,finish-1)..'…'
                    end
                    text:SetText(shown); text:SetColor(isError and C.danger or C.muted)
                    text:EnableHitTest()
                    text.HandleEvent=function(self,event)
                        if owner.HandleEvent then return owner:HandleEvent(event) end
                        return true
                    end
                    Tooltip.AddControlTooltip(text,{text=message},0,640)
                    text:SetNeedsFrameUpdate(false)
                    if brief then
                        local elapsed=0
                        text.OnFrame=function(self,delta)
                            elapsed=elapsed+delta
                            if elapsed>=1.5 then self:SetText(''); self:SetNeedsFrameUpdate(false) end
                        end
                        text:SetNeedsFrameUpdate(true)
                    end
                end
            end
            local RequestClose
            local AttemptLeave
            local group=Group(root); L(group):Width(groupWidth):Height(height):AtCenterIn(root)
            group.Depth:Set(function() return root.Depth()+1 end)
            group:DisableHitTest()
            local transition={elapsed=0,closing=false}
            local launcherPosition={x=memory.launcher.x,y=memory.launcher.y,baseX=0,width=launcherWidth,saved=memory.launcher}
            local panelPosition={x=memory.panel.x,y=memory.panel.y,baseX=launcherWidth+gap,width=width,saved=memory.panel}
            local function MoveTransition(progress)
                local offset=-8*(1-progress)*(1-progress)
                L(group):AtCenterIn(root,0,offset)
            end
            local function PlacePanel(owner,position,openingOffset)
                L(owner):AtLeftTopIn(group,position.baseX+position.x/scale,position.y/scale+(openingOffset or 0))
            end
            local function ClampPosition(position)
                local originX=(parent.Width()-groupWidth*scale)/2+position.baseX*scale
                position.x=math.max(-originX,math.min(parent.Width()-position.width*scale-originX,position.x))
                position.y=math.max(-(parent.Height()-height*scale)/2,math.min((parent.Height()+height*scale)/2-72*scale,position.y))
                position.saved.x,position.saved.y=position.x,position.y
            end
            local function DragHeader(owner,headerWidth,position,headerHeight)
                local header=Group(owner); L(header):AtLeftTopIn(owner,0,0):Width(headerWidth):Height(headerHeight or 72)
                header.Depth:Set(function() return owner.Depth()+3 end)
                header.HandleEvent=function(self,event)
                    if state.closing or event.Type~='ButtonPress' or (event.Modifiers and event.Modifiers.Right) then return true end
                    if state.RaiseWindow then state.RaiseWindow(owner) end
                    local Dragger=import('/lua/maui/dragger.lua').Dragger
                    local drag=Dragger()
                    local startX,startY=event.MouseX,event.MouseY
                    local initialX,initialY=position.x,position.y
                    drag.OnMove=function(_,x,y)
                        if ctx.getWindow()~=root or state.closing then return end
                        position.x,position.y=initialX+x-startX,initialY+y-startY
                        ClampPosition(position)
                        PlacePanel(owner,position)
                    end
                    drag.OnRelease=function(self) self:Destroy() end
                    drag.OnCancel=function(self) self:Destroy() end
                    PostDragger(self:GetRootFrame(),event.KeyCode,drag)
                    return true
                end
                return header
            end
            group.OnFrame=function(self,delta)
                transition.elapsed=math.min(0.16,transition.elapsed+delta)
                local progress=transition.elapsed/0.16
                MoveTransition(transition.closing and 1-progress or progress)
                -- Fade only while closing: recursively changing alpha during normal use
                -- would overwrite individual opacity states in embedded editors.
                if transition.closing then self:SetAlpha(1-progress,true) end
                if not transition.closing then state.launcher:SetAlpha(progress,true) end
                if progress>=1 then
                    self:SetNeedsFrameUpdate(false)
                    if transition.closing and ctx.getWindow()==root then root:Destroy() end
                end
            end
            MoveTransition(0); group:SetNeedsFrameUpdate(true)
            local function AnimateClose()
                if transition.closing then return end
                transition.closing=true; state.closing=true; transition.elapsed=0
                group:SetNeedsFrameUpdate(true)
            end
            state.launcher=Surface(group,0,0,launcherWidth,launcherHeight,C.canvas)
            state.frontWindow='launcher'
            state.RaiseWindow=function(owner)
                if owner==state.launcher then state.frontWindow='launcher'
                elseif owner==state.panel then state.frontWindow='panel' end
            end
            state.launcher.Depth:Set(function() return group.Depth()+(state.frontWindow=='launcher' and 1000 or 0) end)
            ClampPosition(launcherPosition); PlacePanel(state.launcher,launcherPosition)
            state.launcher.HandleEvent=function() return true end
            Theme.RoundedPanel(state.launcher,L,launcherWidth,launcherHeight,C.canvas,C.border,true)
            DragHeader(state.launcher,launcherWidth-60,launcherPosition,96)
            local launcherLogo=Bitmap(state.launcher)
            launcherLogo.Depth:Set(function() return state.launcher.Depth()+2 end)
            launcherLogo:SetTexture(Theme.Logos.wordmark)
            launcherLogo:DisableHitTest()
            L(launcherLogo):AtLeftTopIn(state.launcher,(launcherWidth-144)/2,3):Width(144):Height(77)
            state.closeItem=Button(state.launcher,'×',launcherWidth-44,16,36,function() RequestClose() end,{})
            if table.getn(missingMods)>0 then
                local noteY=112+visibleSections*48+8
                local noteHeight=48+table.getn(missingMods)*24
                local note=Surface(state.launcher,0,noteY,launcherWidth,noteHeight,C.surface)
                note.Depth:Set(function() return state.launcher.Depth()+1 end)
                Theme.Outline(note,L,launcherWidth,noteHeight,C.warningBorder)
                local accent=Surface(note,0,0,3,noteHeight,C.warning)
                accent:DisableHitTest()
                local heading=Text(note,T('core.menu.recommended_mods'),16,12,C.warning)
                heading:SetFont(Theme.Fonts.heading,metrics.buttonText*ratio)
                for index,modName in ipairs(missingMods) do
                    local dependency=Text(note,modName,16,38+(index-1)*24,C.text)
                    dependency:SetFont(Theme.Fonts.body,metrics.secondaryText*ratio)
                end
            end
            local closePanel
            state.panel=Surface(group,launcherWidth+gap,0,width,height,C.canvas)
            state.panel.Depth:Set(function() return group.Depth()+(state.frontWindow=='panel' and 1000 or 0) end)
            ClampPosition(panelPosition); PlacePanel(state.panel,panelPosition)
            state.panel.HandleEvent=function(self,event)
                if event.Type=='WheelRotation' and state.maxContentTop and state.maxContentTop>0 then
                    self:ScrollLines(nil,event.WheelRotation>0 and -1 or 1)
                end
                return true
            end
            state.panel:SetSolidColor(C.transparent)
            local panelBackdrop=Surface(state.panel,0,0,width,height,C.canvas)
            panelBackdrop.Depth:Set(function() return state.panel.Depth() end)
            panelBackdrop:DisableHitTest()
            local resizePanelOutline=Theme.RoundedPanel(panelBackdrop,L,width,height,C.canvas,C.border,true)
            local function SetPanelBackdrop(columns)
                if not columns then
                    if state.panelParts then
                        for _,part in ipairs(state.panelParts) do part:Hide() end
                        for _,frame in ipairs(state.columnFrames) do frame.control:Hide() end
                        state.columnJoin:Hide()
                        state.columnTop:Hide()
                        state.panel:EnableHitTest()
                        if state.content then state.content:EnableHitTest() end
                        panelBackdrop:Show()
                    end
                    return
                end
                if not state.panelParts then
                    state.panelParts={}
                    for index=1,3 do
                        local part=Surface(state.panel,0,0,1,1,C.transparent)
                        part.HandleEvent=function(self,event) return state.panel:HandleEvent(event) end
                        state.panelParts[index]=part
                    end
                    state.columnFrames={}
                    for index=1,2 do
                        local frame=Surface(state.panel,0,0,width,height,C.canvas)
                        frame.Depth:Set(function() return state.panel.Depth()-3 end)
                        frame:DisableHitTest()
                        state.columnFrames[index]={control=frame,resize=Theme.RoundedPanel(frame,L,width,height,C.canvas,C.border,true)}
                    end
                    state.columnJoin=Surface(state.panel,0,0,1,1,C.canvas)
                    state.columnTop=Surface(state.panel,0,0,1,1,C.border)
                    state.columnJoin:DisableHitTest()
                    state.columnTop:DisableHitTest()
                end
                panelBackdrop:Hide()
                state.panel:DisableHitTest()
                if state.content then state.content:DisableHitTest() end
                local split=24+columns.split
                local headerHeight=100
                local bottom=state.panelHeight-headerHeight
                local leftHeight=math.min(bottom,columns.left+24)
                local rightHeight=math.min(bottom,columns.right+24)
                L(state.panelParts[1]):AtLeftTopIn(state.panel,0,0):Width(state.panelWidth):Height(headerHeight)
                L(state.panelParts[2]):AtLeftTopIn(state.panel,0,headerHeight):Width(split):Height(leftHeight)
                L(state.panelParts[3]):AtLeftTopIn(state.panel,split,headerHeight):Width(state.panelWidth-split):Height(rightHeight)
                local left,right=state.columnFrames[1],state.columnFrames[2]
                local rightWidth=state.panelWidth-split
                L(left.control):AtLeftTopIn(state.panel,0,0):Width(split):Height(headerHeight+leftHeight)
                L(right.control):AtLeftTopIn(state.panel,split,0):Width(rightWidth):Height(headerHeight+rightHeight)
                left.resize(split,headerHeight+leftHeight)
                right.resize(rightWidth,headerHeight+rightHeight)
                left.control:Show()
                right.control:Show()
                -- Cover the internal edges where the two rounded surfaces share a header and body.
                local joinHalf=2*metrics.panelRadius
                L(state.columnJoin):AtLeftTopIn(state.panel,split-joinHalf,1):Width(2*joinHalf)
                    :Height(headerHeight+math.min(leftHeight,rightHeight)-metrics.panelRadius-1)
                L(state.columnTop):AtLeftTopIn(state.panel,split-joinHalf,0):Width(2*joinHalf):Height(1)
                state.columnJoin:Show()
                state.columnTop:Show()
                for _,part in ipairs(state.panelParts) do part:Show() end
            end
            local function SetPanelSize(panelWidth,panelHeight,minHeight,minWidth,columns)
                state.panelWidth=math.max(minWidth or metrics.corePanelWidth,math.min(width,panelWidth or width))
                state.panelHeight=math.max(minHeight or 400,math.min(height,panelHeight or height))
                panelPosition.width=state.panelWidth
                L(state.panel):Width(state.panelWidth):Height(state.panelHeight)
                L(panelBackdrop):Width(state.panelWidth):Height(state.panelHeight)
                resizePanelOutline(state.panelWidth,state.panelHeight)
                SetPanelBackdrop(columns)
                -- The scroll viewport must follow the panel: an oversized container
                -- swallows clicks in the empty band below a shrunk window.
                if state.content and state.contentInset then L(state.content):AtLeftTopIn(state.panel,state.contentInset,88):Width(state.panelWidth-state.contentInset*2):Height(state.panelHeight-112) end
                if state.inlineHost then
                    L(state.inlineHost):Width(state.panelWidth-48)
                    if state.inlineEditor and state.inlineEditor.OnResize then
                        local resized,resizeError=pcall(state.inlineEditor.OnResize,state.inlineEditor,state.panelWidth-48,state.panelHeight-124)
                        if not resized then WARN('[Claret] Inline resize failed: '..tostring(resizeError)) end
                    end
                end
                if state.headerDivider then L(state.headerDivider):Width(state.panelWidth-48) end
                if state.panelClose then L(state.panelClose.control):AtLeftTopIn(state.panel,state.panelWidth-64,16) end
                if state.panelDragHeader then L(state.panelDragHeader):Width(state.panelWidth-72) end
                local originY=(parent.Height()-height*scale)/2
                local maxY=parent.Height()-originY-state.panelHeight*scale
                if panelPosition.y>maxY then panelPosition.y=maxY end
                ClampPosition(panelPosition); PlacePanel(state.panel,panelPosition)
            end
            local function SetPanelHeight(value)
                SetPanelSize(state.panelWidth,value)
            end
            state.panelDragHeader=DragHeader(state.panel,width-72,panelPosition)
            local function SetPanelWidth(value)
                SetPanelSize(value or width,state.panelHeight)
            end
            state.title=Text(state.panel,'',24,20)
            state.title:SetFont(Theme.Fonts.heading,metrics.title*ratio)
            state.panelClose=Button(state.panel,'×',width-64,16,40,function() closePanel() end,{})
            state.headerDivider=Surface(state.panel,24,72,width-48,1,C.border); state.headerDivider:DisableHitTest()
            state.panel:Hide()
            AttemptLeave=function(intent,action)
                if not (editor and editor.CanLeave) then action(); return end
                -- A hidden embedded editor may present its leave confirmation itself.
                -- Reveal it before asking, so its dialog cannot open offscreen.
                if editor==state.inlineEditor and state.inlineHost and not state.inlineVisible then
                    state.contentTop=state.maxContentTop or 0
                    state.Render()
                end
                state.leaveSerial=state.leaveSerial+1
                local serial=state.leaveSerial
                local pendingEditor=editor
                local completed=false
                local function Continue(allowed)
                    if completed then return end
                    completed=true
                    if allowed==false or serial~=state.leaveSerial or ctx.getWindow()~=root or editor~=pendingEditor or ctx.isDisposed() then return end
                    action()
                end
                local allowed
                local success=pcall(function() allowed=editor.CanLeave(intent,Continue) end)
                if not success then
                    state.leaveSerial=state.leaveSerial+1
                    WARN('[Claret] Leave check failed: '..tostring(allowed))
                    return
                end
                if allowed then Continue(true) end
            end
            RequestClose=function()
                if transition.closing then return end
                if CancelCapture() then return end
                if editor and editor.CanLeave then
                    AttemptLeave('close',function() if ctx.getWindow()==root then AnimateClose() end end)
                elseif editor then editor.RequestClose() else AnimateClose() end
            end
            closePanel=function()
                if CancelCapture() then return end
                AttemptLeave('close',function()
                    Unbind(); Focus(nil); SetPanelSize(width,height)
                    if state.content then state.content:Destroy(); state.content=nil end
                    if state.inlineHost then state.inlineHost:Destroy(); state.inlineHost=nil end
                    state.inlineVisible=false
                    state.inlineEditor=nil; editor=nil; state.selected=nil; state.accessory=nil; memory.section=nil; state.title:SetText(''); state.panel:Hide()
                    state.RenderNavigation()
                end)
            end
            root.RequestClose=RequestClose
            local function Launch(action)
                CancelCapture()
                AttemptLeave('section',function()
                    local openingPanel=not state.selected and not state.accessory
                    Unbind(); Focus(nil)
                    if state.content then state.content:Destroy(); state.content=nil end
                    if state.inlineHost then state.inlineHost:Destroy(); state.inlineHost=nil end
                    if state.contentScrollbar then state.contentScrollbar:Destroy(); state.contentScrollbar=nil end
                    state.maxContentTop=0
                    state.inlineVisible=false; state.inlineEditor=nil; editor=nil
                    state.selected=nil; state.accessory=action; memory.section=nil
                    SetPanelSize(384,232,232,384)
                    state.title:SetText(action.titleKey and T(action.titleKey) or action.title or '')
                    state.contentInset=nil
                    state.content=Group(state.panel)
                    state.content.Depth:Set(function() return state.panel.Depth()+1 end)
                    L(state.content):AtLeftTopIn(state.panel,0,88):Width(state.panelWidth):Height(state.panelHeight-88)
                    local child
                    local success,openError=pcall(function() child=action.open(state.content,{scale=scale,width=state.panelWidth,height=state.panelHeight-88}) end)
                    if not success or not child then WARN('[Claret] Settings window failed: '..tostring(openError)) end
                    state.RaiseWindow(state.panel)
                    state.panel:Show(); state.RenderNavigation()
                    if openingPanel then Theme.AnimateOpening(state.panel,function(offset) PlacePanel(state.panel,panelPosition,offset) end) end
                end)
            end
            state.Render=function()
                Unbind(); Focus(nil); state.contentItems={}
                if state.content then state.content:Destroy(); state.content=nil end
                local section=sections[state.selected]
                SetPanelSize(section and section.id=='core' and metrics.corePanelWidth or width,
                    section and section.id=='core' and metrics.corePanelHeight or height)
                local compactCore=section and section.id=='core'
                local contentInset=compactCore and 16 or 24
                state.contentInset=contentInset
                state.content=Group(state.panel); L(state.content):AtLeftTopIn(state.panel,contentInset,88):Width(state.panelWidth-contentInset*2):Height(state.panelHeight-112)
                state.content.Depth:Set(function() return state.panel.Depth()+1 end)
                if not section then Text(state.content,T('core.menu.no_sections'),0,0,C.muted); return end
                local cardWidth=compactCore and metrics.coreCardWidth or 672
                local optionHeight=compactCore and metrics.coreRowHeight or 76
                local optionStep=compactCore and metrics.coreRowStep or 88
                local controlHeight=compactCore and metrics.coreControlHeight or 64
                local controlStep=compactCore and controlHeight+8 or 76
                state.title:SetText(section.titleKey and T(section.titleKey) or section.title)
                -- Simple registered settings are virtualized as whole rows. Inline editors
                -- own their own scrollable content and remain mounted while they are active.
                local contentHeight=state.panelHeight-112
                local rowCount=table.getn(section.toggles or {})+table.getn(section.selectors or {})
                local totalHeight=(rowCount>0 and 28 or 0)+rowCount*optionStep
                if (section.id=='core' and keyBinding) or table.getn(section.actions or {})>0 then totalHeight=totalHeight+20 end
                if section.id=='core' and keyBinding then totalHeight=totalHeight+controlStep end
                if compactCore and keyBinding then totalHeight=totalHeight-(controlStep-controlHeight) end
                totalHeight=totalHeight+table.getn(section.actions or {})*48
                local simpleHeight=totalHeight
                if section.inline then totalHeight=totalHeight+12+984 end
                local maxTop=math.max(0,math.ceil((totalHeight-contentHeight)/44))
                state.maxContentTop=maxTop
                state.contentTop=math.max(0,math.min(state.contentTop or 0,maxTop))
                local offset=math.min(state.contentTop*44,math.max(0,totalHeight-contentHeight))
                local function Visible(top,rowHeight)
                    return top>=offset and top+rowHeight<=offset+contentHeight
                end
                if maxTop>0 then
                    function state.panel:GetScrollValues()
                        local visibleUnits=math.max(1,math.floor(contentHeight/44))
                        return 0,state.maxContentTop+visibleUnits,state.contentTop,state.contentTop+visibleUnits
                    end
                    function state.panel:IsScrollable() return state.maxContentTop>0 end
                    function state.panel:ScrollSetTop(axis,value)
                        local nextTop=math.max(0,math.min(state.maxContentTop,math.floor(value)))
                        if nextTop~=state.contentTop then state.contentTop=nextTop; state.Render() end
                    end
                    function state.panel:ScrollLines(axis,delta) self:ScrollSetTop(axis,state.contentTop+delta) end
                    function state.panel:ScrollPages(axis,delta) self:ScrollLines(axis,delta*math.max(1,math.floor(contentHeight/44)-1)) end
                    if not state.contentScrollbar then
                        state.contentScrollbar=UI.CreateVertScrollbarFor(state.panel,0,nil,24,88)
                    end
                elseif state.contentScrollbar then
                    state.contentScrollbar:Destroy(); state.contentScrollbar=nil
                end
                local y=0
                if rowCount>0 then
                    if Visible(y,20) then Text(state.content,T('core.menu.options'),0,y-offset,C.muted) end
                    y=y+28
                end
                for _,toggle in ipairs(section.toggles or {}) do
                    if Visible(y,optionHeight) then
                    local option=toggle.option
                    local update,status
                    local item=Interactive(state.content,0,y-offset,cardWidth,optionHeight,function()
                        local previous=option:Get()
                        local saved=pcall(function()
                            option:Set(not previous); option:Save(); SavePreferences()
                        end)
                        if not saved then
                            local restored=pcall(function() option:Set(previous); option:Save(); SavePreferences() end)
                            if not restored then WARN('[Claret] Could not restore toggle after failed save') end
                            status(T('core.menu.save_failed'),true)
                        end
                        update()
                    end,state.contentItems,C.surface)
                    local label=Text(item.control,toggle.labelKey and T(toggle.labelKey) or toggle.label or '',16,12)
                    if toggle.centerLabel then L(label):AtCenterIn(item.control,0,compactCore and -48 or -56) end
                    local description=toggle.descriptionKey and T(toggle.descriptionKey) or toggle.description
                    if description and description~='' then Text(item.control,description,16,compactCore and 32 or 36,C.muted) end
                    local paintSwitch=Theme.SettingsSwitch(item.control,L,cardWidth,optionHeight,ratio,compactCore)
                    status=Status(item.control,compactCore and 12 or 416,compactCore and 38 or 54,compactCore and cardWidth-24 or 240)
                    update=function()
                        paintSwitch(option:Get())
                    end
                    option.OnChanged:Add(update); table.insert(state.bindings,{option=option,callback=update}); update()
                    end
                    y=y+optionStep
                end
                for _,selector in ipairs(section.selectors or {}) do
                    if Visible(y,optionHeight) then
                        local option=selector.option
                        local values=selector.values or {}
                        local function FindIndex(value)
                            for index,item in ipairs(values) do if item.id==value then return index end end
                            return 1
                        end
                        local current=selector.getLabel and selector.getLabel() or ''
                        if current=='' then
                            local selected=values[FindIndex(option:Get())]
                            current=selected and (selected.labelKey and T(selected.labelKey) or selected.label) or ''
                        end
                        local update,status
                        local item=Interactive(state.content,0,y-offset,cardWidth,optionHeight,function()
                            if selector.segmented then return end
                            local previous=option:Get()
                            local index=FindIndex(previous)
                            local nextValue=values[math.mod(index,table.getn(values))+1]
                            if not nextValue then return end
                            local saved=pcall(function()
                                option:Set(nextValue.id); option:Save(); SavePreferences()
                            end)
                            if not saved then
                                pcall(function() option:Set(previous); option:Save(); SavePreferences() end)
                                status(T('core.menu.save_failed'),true)
                            else
                                status(T('core.menu.saved'),false,true)
                            end
                            update()
                        end,state.contentItems,C.surface)
                        local selectorLabel=Text(item.control,selector.labelKey and T(selector.labelKey) or selector.label or '',16,12)
                        if selector.segmented then L(selectorLabel):AtLeftTopIn(item.control,16,compactCore and 18 or 24) end
                        local description=selector.descriptionKey and T(selector.descriptionKey) or selector.description
                        if description and description~='' then
                            Text(item.control,description,16,selector.segmented and 44 or 36,C.muted)
                        end
                        if selector.segmented then
                            local choices={}
                            local function AddChoiceButton(index,choice)
                                local choiceId=choice.id
                                local buttonWidth=compactCore and 48 or 56
                                local buttonHeight=compactCore and 28 or 32
                                local buttonGap=4
                                local x=cardWidth-16-(table.getn(values)*buttonWidth+(table.getn(values)-1)*buttonGap)+(index-1)*(buttonWidth+buttonGap)
                                local button=Interactive(item.control,x,compactCore and 14 or 16,buttonWidth,buttonHeight,function()
                                    local previous=option:Get()
                                    if previous==choiceId then return end
                                    local saved,saveError=pcall(function()
                                        option:Set(choiceId); option:Save(); SavePreferences()
                                    end)
                                    if not saved then
                                        pcall(function() option:Set(previous); option:Save(); SavePreferences() end)
                                        WARN('[Claret] Could not save menu setting: '..tostring(saveError))
                                        status(T('core.menu.save_failed'),true)
                                    else
                                        status(T(selector.savedKey or 'core.menu.saved'),false,true)
                                    end
                                    update()
                                end,state.contentItems,C.surface)
                                button.label=Text(button.control,choice.shortLabel or choice.label or '',0,0)
                                L(button.label):AtCenterIn(button.control)
                                table.insert(choices,{id=choiceId,button=button})
                            end
                            for index,choice in ipairs(values) do
                                AddChoiceButton(index,choice)
                            end
                            status=Status(item.control,16,compactCore and 38 or 54,compactCore and cardWidth-32 or 480)
                            update=function()
                                for _,choice in ipairs(choices) do
                                    choice.button.selected=option:Get()==choice.id
                                    choice.button.normal=choice.button.selected and C.selected or C.surface
                                    choice.button.paint()
                                end
                            end
                        else
                            local valueLabel=Text(item.control,current,compactCore and 320 or 468,compactCore and 20 or 28,C.accentText)
                            status=Status(item.control,compactCore and 264 or 416,compactCore and 38 or 54,compactCore and cardWidth-280 or 240)
                            update=function()
                                if selector.getLabel then valueLabel:SetText(selector.getLabel())
                                else
                                    local selected=values[FindIndex(option:Get())]
                                    valueLabel:SetText(selected and (selected.labelKey and T(selected.labelKey) or selected.label) or '')
                                end
                            end
                        end
                        option.OnChanged:Add(update); table.insert(state.bindings,{option=option,callback=update}); update()
                    end
                    y=y+optionStep
                end
                if (section.id=='core' and keyBinding) or table.getn(section.actions or {})>0 then
                    if Visible(y,20) then Text(state.content,T('core.menu.controls'),0,y-offset,C.muted) end
                    y=y+20
                end
                if section.id=='core' and keyBinding then
                    if Visible(y,controlHeight) then
                    local rowWidth=compactCore and cardWidth or 672
                    local row=Surface(state.content,0,y-offset,rowWidth,controlHeight,C.surface)
                    local outline=Theme.Outline(row,L,rowWidth,controlHeight)
                    Text(row,T('core.menu.open_menu'),compactCore and 12 or 16,compactCore and 18 or 22)
                    local caps
                    local clear
                    local status=Status(row,compactCore and 12 or 16,compactCore and 38 or 46)
                    local function Keys(value,listening)
                        if caps then caps:Destroy() end
                        local capsX=compactCore and 140 or 168
                        local capsWidth=compactCore and 112 or 196
                        local capsHeight=compactCore and 32 or 40
                        caps=Group(row); L(caps):AtLeftTopIn(row,capsX,compactCore and 14 or 12):Width(capsWidth):Height(capsHeight)
                        caps.Depth:Set(function() return row.Depth()+1 end)
                        caps:EnableHitTest(); caps.HandleEvent=function() return true end
                        Tooltip.AddControlTooltip(caps,{text=listening and T('core.menu.press_combo_cancel') or (value~='' and value or T('core.menu.unassigned'))},0,480)
                        if listening or value=='' then Text(caps,listening and T('core.menu.press_combo_ellipsis') or T('core.menu.unassigned'),0,compactCore and 5 or 8,C.muted); return end
                        local x,start=0,1
                        while start<=string.len(value) do
                            local a,b,part=string.find(value,'([^%-]+)',start)
                            if not a then break end
                            local capSpacing=compactCore and 8 or 12
                            local width=compactCore and math.max(24,string.len(part)*6+8) or math.max(28,string.len(part)*7+12)
                            local capHeight=compactCore and 28 or 32
                            local capTextY=compactCore and 5 or 8
                            if x+width>capsWidth then Text(caps,'…',x,capTextY,C.muted); break end
                            if x>0 then Text(caps,'+',x-capSpacing,capTextY,C.muted) end
                            local cap=Surface(caps,x,0,width,capHeight,C.raised); cap:DisableHitTest()
                            Theme.Outline(cap,L,width,capHeight,C.muted)
                            local label=Text(cap,part,0,0); L(label):AtCenterIn(cap)
                            x=x+width+capSpacing; start=b+1
                        end
                    end
                    local function Refresh()
                        local value=keyBinding:Get(); Keys(value,false)
                        if clear then clear:SetEnabled(value~='') end
                        outline(C.border); row:SetSolidColor(C.surface)
                    end
                    local function StartCapture()
                        CancelCapture()
                        outline(C.accentText); row:SetSolidColor(C.selected); Keys('',true)
                        status(T('core.menu.save_now'))
                        state.receiver=Group(row); L(state.receiver):AtLeftTopIn(row,0,0):Width(1):Height(1)
                        state.receiver.Depth:Set(function() return row.Depth()+2 end)
                        state.receiver:EnableHitTest()
                        state.receiver.HandleEvent=function(self,event)
                            if event.Type~='KeyDown' or not state.capture then return true end
                            if event.RawKeyCode==27 then Escape.HandleEsc(false); return true end
                            local key=keyBinding:FromEvent(event)
                            if key then state.capture.accept(key) end
                            return true
                        end
                        ctx.setCapturing(true)
                        TraceInput(true,'menu_key_capture')
                        state.capture={cancel=function() Refresh(); status(T('core.menu.change_cancelled'),false,true) end,
                            accept=function(key)
                                local success,message=keyBinding:Set(key)
                                if not success then
                                    status(message,true); return
                                end
                                CancelCapture(true); Refresh(); status(T('core.menu.saved'),false,true)
                            end}
                        state.receiver:AcquireKeyboardFocus(true)
                    end
                    local buttonY=compactCore and 10 or 16
                    Button(row,T('core.menu.edit'),compactCore and 268 or 376,buttonY,compactCore and 84 or 104,StartCapture,state.contentItems)
                    clear=Button(row,T('core.menu.clear_combo'),compactCore and 360 or 488,buttonY,compactCore and 144 or 168,function()
                        CancelCapture(true)
                        local success,message=keyBinding:Set('')
                        Refresh(); status(success and T('core.menu.saved_f10') or message,not success,success)
                    end,state.contentItems)
                    Refresh()
                    end
                    y=y+controlStep
                end
                for _,action in ipairs(section.actions or {}) do
                    if Visible(y,metrics.buttonHeight) then
                        local selectedAction=action
                        Button(state.content,selectedAction.label,0,y-offset,672,function() Launch(selectedAction) end,state.contentItems)
                    end
                    y=y+48
                end
                if section.inline then
                    if not state.inlineHost then
                        state.inlineHost=Group(state.panel)
                        state.inlineHost.Depth:Set(function() return state.panel.Depth()+1 end)
                        state.inlineHost:DisableHitTest()
                        L(state.inlineHost):AtLeftTopIn(state.panel,24,100):Width(1080):Height(984)
                        local success,openError=pcall(function() state.inlineEditor=section.inline(state.inlineHost,{scale=scale,setWidth=function(inlineWidth) SetPanelWidth(inlineWidth and (48+inlineWidth) or width) end,setHeight=function(inlineHeight)
                                SetPanelHeight(inlineHeight and (100+inlineHeight+24) or height)
                            end,setSize=function(inlineWidth,inlineHeight,columns)
                                SetPanelSize(inlineWidth+48,inlineHeight+124,124,48,columns)
                                L(state.inlineHost):Height(state.panelHeight-124)
                            end}) end)
                        if not success or not state.inlineEditor then
                            WARN('[Claret] Inline editor failed: '..tostring(openError))
                            state.inlineHost:Destroy(); state.inlineHost=nil
                            Text(state.content,T('core.menu.load_failed'),0,0,C.danger)
                        else editor=state.inlineEditor end
                    end
                    if state.inlineHost then
                        local inlineTop=simpleHeight+12
                        if Visible(inlineTop,984) then
                            L(state.inlineHost):AtLeftTopIn(state.panel,24,88+inlineTop-offset)
                            local becomingVisible=not state.inlineVisible
                            state.inlineHost:Show(); state.inlineVisible=true
                            if becomingVisible and state.inlineEditor and state.inlineEditor.AfterParentShow then
                                local success,refreshError=pcall(state.inlineEditor.AfterParentShow,state.inlineEditor)
                                if not success then WARN('[Claret] Inline editor refresh after show failed: '..tostring(refreshError)) end
                            end
                        else
                            state.inlineHost:Hide(); state.inlineVisible=false
                        end
                    end
                end
            end
            state.RenderNavigation=function()
                Focus(nil); state.navItems={}
                if state.navigation then state.navigation:Destroy() end
                state.navigation=Group(state.scroll); L(state.navigation):AtLeftTopIn(state.scroll,0,0):Width(launcherWidth-24):Height(visibleSections*48)
                state.navigation.Depth:Set(function() return state.scroll.Depth()+1 end)
                for index=state.top,math.min(table.getn(sections),state.top+5) do
                    local sectionIndex=index
                    local section=sections[index]
                    local hasAccessory=section.accessory and type(section.accessory.open)=='function'
                    local item=Interactive(state.navigation,0,(index-state.top)*48,launcherWidth-24,40,function()
                        if section.placeholder then return end
                        if sectionIndex==state.selected then return end
                    AttemptLeave('section',function()
                            if ctx.getWindow()==root then
                                if state.inlineHost then state.inlineHost:Destroy(); state.inlineHost=nil end
                                SetPanelSize(width,height)
                                state.inlineVisible=false
                                local openingPanel=not state.selected and not state.accessory
                                state.inlineEditor=nil; editor=nil; state.accessory=nil; state.selected=sectionIndex; state.contentTop=0; memory.section=sectionIndex
                                state.RaiseWindow(state.panel); state.panel:Show(); state.RenderNavigation(); state.Render()
                                if openingPanel then
                                    Theme.AnimateOpening(state.panel,function(offset)
                                        PlacePanel(state.panel,panelPosition,offset)
                                    end)
                                end
                            end
                        end)
                    end,state.navItems,index==state.selected and C.selected or C.canvas)
                    if section.placeholder then item:SetEnabled(false) end
                    item.selected=index==state.selected
                    item.label=Text(item.control,section.titleKey and T(section.titleKey) or section.title,0,0)
                    item.label:SetFont(Theme.Fonts.body,metrics.launcherText*ratio)
                    L(item.label):AtCenterIn(item.control)
                    item.paint()
                    if hasAccessory then
                        -- Keep the row's full visual background but reserve the right edge for the gear.
                        L(item.control):Width(launcherWidth-24-40)
                        L(item.label):AtCenterIn(item.control,0,20)
                        local iconButton=Interactive(state.navigation,launcherWidth-24-40,(index-state.top)*48+2,36,36,function()
                            if ctx.getWindow()==root then Launch(section.accessory) end
                        end,state.navItems,C.transparent,true)
                        iconButton.label=Text(iconButton.control,'⚙',0,0,C.muted)
                        L(iconButton.label):AtCenterIn(iconButton.control)
                        iconButton.label:SetFont(Theme.Fonts.body,metrics.glyph*ratio)
                        local paint=iconButton.paint
                        iconButton.paint=function()
                            paint()
                            iconButton.label:SetColor(iconButton.hover and C.text or C.muted)
                        end
                        iconButton.paint()
                    end
                    if item.selected then Surface(item.control,0,0,4,40,C.accent):DisableHitTest()
                    else item.paint() end
                    item.paint()
                end
            end
            state.scroll=Surface(state.launcher,12,96,launcherWidth-24,visibleSections*48,C.canvas)
            function state.scroll:GetScrollValues() return 1,math.max(6,table.getn(sections)),state.top,state.top+5 end
            function state.scroll:ScrollSetTop(axis,value)
                state.top=math.max(1,math.min(math.max(1,table.getn(sections)-5),math.floor(value)))
                state.RenderNavigation()
            end
            function state.scroll:ScrollLines(axis,delta) self:ScrollSetTop(axis,state.top+delta) end
            function state.scroll:ScrollPages(axis,delta) self:ScrollSetTop(axis,state.top+delta*6) end
            state.scroll.HandleEvent=function(self,event)
                if event.Type=='WheelRotation' then self:ScrollLines(nil,event.WheelRotation>0 and -1 or 1) end
                return true
            end
            state.RenderNavigation()
            if initialSection then
                state.selected=initialSection; state.panel:Show(); state.RenderNavigation(); state.Render()
            end
            if table.getn(sections)>6 then UI.CreateVertScrollbarFor(state.scroll) end
            state.launcher:SetAlpha(0,true)
            Escape.PushEscapeHandler(RequestClose); state.escapeBound=true
        end)
        if not ok then root:Destroy(); error(err) end
        state.OnLanguageChanged=function()
            if not state.closing then
                state.RenderNavigation()
                if state.selected then state.Render() end
                if state.accessory then state.title:SetText(state.accessory.titleKey and T(state.accessory.titleKey) or state.accessory.title or '') end
                if state.inlineEditor and state.inlineEditor.OnLanguageChanged then state.inlineEditor.OnLanguageChanged() end
            end
        end
        Localization.Subscribe(root,state.OnLanguageChanged)
    end
    function menu:IsOpen() return window~=nil end
    function menu:IsKeyCaptureActive() return capturing end
    function menu:Toggle()
        if window then
            if window.RequestClose then window.RequestClose() end
        else
            self:Open()
        end
    end
    function menu:Destroy()
        disposed=true
        if window then window:Destroy() end
        sections,ids={},{}
    end
    return menu
end
