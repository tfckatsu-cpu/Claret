-- Settings lifetime and data integration; this does not emulate FAF rendering.
local testLocalization = dofile('Tests/localization-test-helper.lua')
table.getn=function(t) return #t end
local controls, escapes, saved = {}, {}, 0
local scrollbarTarget,scrollbarWidget
local focused
local pixelScale,lastLayoutScale=1,nil
local postedDrag
local function var(value)
    return setmetatable({value=value,Set=function(self,v) self.value=v end},
        {__call=function(self) return self.value end})
end
local function control(parent,text)
    local c={parent=parent,text=text,Width=var(1920),Height=var(1080),Depth=var(0)}
    function c:OnDestroy() end
    function c:Destroy()
        if self.destroyed then return end
        self.destroyed=true; self:OnDestroy()
        for _,child in ipairs(controls) do if child.parent==self then child:Destroy() end end
    end
    function c:SetSolidColor(value) self.color=value end
    function c:SetTexture(value) self.texture=value end
    function c:SetColor(value) self.textColor=value end
    function c:DisableHitTest() self.hitTestDisabled=true end
    function c:EnableHitTest() self.hitTestDisabled=false end
    function c:AcquireKeyboardFocus(blocksKeyDown)
        assert(not self.hitTestDisabled and blocksKeyDown,'capture must block game key actions')
        focused=self
    end
    function c:AbandonKeyboardFocus() if focused==self then focused=nil end end
    function c:SetText(value) self.text=value end
    function c:SetFont(font,size) self.font=font; self.fontSize=size end
    function c:GetStringAdvance(value)
        -- Approximate fixed glyph width, counting UTF-8 leading bytes.
        local _,count=string.gsub(value,'[^\128-\191]','')
        return count*8
    end
    function c:SetAlpha(value) self.alpha=value end
    function c:SetNeedsFrameUpdate(value) self.needsFrameUpdate=value end
    function c:Hide() self.hidden=true end
    function c:Show() self.hidden=false end
    function c:GetTopmostDepth() return 400 end
    function c:GetRootFrame() return root end
    controls[#controls+1]=c
    return c
end
local root=control()
local function layout(c)
    local l={}
    function l:Fill() return self end
    function l:AtLeftTopIn(parent,x,y) c.x=x or 0; c.y=y or 0; return self end
    function l:AtCenterIn(parent,top,left) c.centerX=left or 0; c.centerY=top or 0; return self end
    function l:Width(v) c.Width:Set(v); return self end
    function l:Height(v) c.Height:Set(v); return self end
    return l
end
local callbacks={}
local option={value=true,OnChanged={
    Add=function(self,fn) callbacks[fn]=true end,
    Remove=function(self,fn) callbacks[fn]=nil end,
}}
function option:Get() return self.value end
function option:Set(value) self.value=value; for fn in pairs(callbacks) do fn(self,value) end end
function option:Save() self.saved=self.value end
local imports={
    ['/mods/ClaretCore/modules/Localization.lua']={Localization=testLocalization},
    ['/lua/maui/group.lua']={Group=control},
    ['/lua/maui/bitmap.lua']={Bitmap=control},
    ['/lua/maui/dragger.lua']={Dragger=function() return {Destroy=function(self) self.destroyed=true end} end},
    ['/lua/maui/layouthelpers.lua']={GetPixelScaleFactor=function() return pixelScale end},
    ['/lua/ui/game/tooltip.lua']={AddControlTooltip=function(target,definition)
        target.tooltip=definition.text
    end},
    ['/lua/ui/uiutil.lua']={CreateText=control,bodyFont='Arial',
        CreateVertScrollbarFor=function(target) scrollbarTarget=target; scrollbarWidget=control(target); return scrollbarWidget end},
    ['/lua/ui/dialogs/eschandler.lua']={
        PushEscapeHandler=function(fn) escapes[#escapes+1]=fn end,
        PopEscapeHandler=function() assert(#escapes>0); table.remove(escapes) end,
        HandleEsc=function(quitGame) assert(not quitGame); local handler=escapes[#escapes]; if handler then handler() end end,
    },
}
local env=setmetatable({ReUI={UI={FloorLayouter=function(scale) lastLayoutScale=scale; return layout end}},
    -- Keep window handoff independent of protected-call return forwarding.
    pcall=function(fn)
        local ok,err=pcall(fn)
        if not ok then return false,err end
        return true
    end,
    GetFrame=function() return root end, SavePreferences=function() saved=saved+1 end,
    PostDragger=function(frame,key,drag) postedDrag=drag end,
    WARN=function(err) error(err) end,
    import=function(path) return assert(imports[path],path) end},{__index=_G})
local inputLogs={}
env.LOG=function(line) inputLogs[#inputLogs+1]=line end
env.ReUI.Options={Mods={ClaretCore={probeEnabled={Get=function() return true end}}}}
local theme=setmetatable({},{__index=env})
assert(loadfile('../mods/ClaretCore/modules/Theme.lua','t',theme))()
imports['/mods/ClaretCore/modules/Theme.lua']=theme
assert(loadfile('../mods/ClaretCore/modules/Menu.lua','t',env))()
local menu=env.Create()
local function launcherControl()
    for _,c in ipairs(controls) do
        if not c.destroyed and c.texture==theme.Logos.wordmark then return c.parent end
    end
end
local child, closeAttempts, closedCount
closedCount=0
assert(menu:Register({id='core',title='Core',toggles={{label='Probe',option=option}},
    onMenuClosed=function() assert(not menu:IsOpen() and not focused,'close callback follows focus release'); closedCount=closedCount+1 end,
    actions={{label='Editor',open=function(parent)
        child=control(parent); closeAttempts=0
        -- Separate windows own their Escape handling above the menu (menu-rules.md).
        local handler=function() child.RequestClose() end
        escapes[#escapes+1]=handler
        child.RequestClose=function()
            closeAttempts=closeAttempts+1
            if closeAttempts==2 then
                for index=#escapes,1,-1 do if escapes[index]==handler then table.remove(escapes,index) end end
                child:Destroy()
            end
        end
        return child
    end}}}))
assert(not menu:Register({id='core',title='Duplicate'}))
assert(#controls==1,'registration must not create UI')
local function button(label)
    for _,c in ipairs(controls) do
        if not c.destroyed and c.text==label then return c.parent end
    end
    error('missing button '..label..'\n'..debug.traceback())
end
local function click(label) button(label):HandleEvent({Type='ButtonPress'}) end
local function textControl(value)
    for _,c in ipairs(controls) do
        if not c.destroyed and c.text==value then return c end
    end
end
local function advanceTransitions()
    for _,c in ipairs(controls) do
        if not c.destroyed and c.needsFrameUpdate and c.OnFrame and c.parent and c.parent.parent==root then
            c:OnFrame(0.2)
        end
    end
end
local function key(code,modifiers,testKey)
    assert(focused and not focused.destroyed,'keyboard input requires a live focus receiver')
    focused:HandleEvent({Type='KeyDown',RawKeyCode=code,Modifiers=modifiers or {},testKey=testKey})
end
menu:Open(); assert(#escapes==1 and not focused,'launcher leaves game keyboard focus alone')
local launcher=launcherControl()
assert(launcher,'launcher displays the Core wordmark')
local group=launcher.parent
local header
for _,c in ipairs(controls) do if c.parent==launcher and c.Width()==188 and c.Height()==96 then header=c end end
assert(header, 'launcher drag header exists')
header:HandleEvent({Type='ButtonPress',MouseX=100,MouseY=100,KeyCode=1,Modifiers={Left=true}})
assert(postedDrag, 'left press starts a drag')
postedDrag:OnMove(140,105)
assert(math.abs(launcher.x-40/lastLayoutScale)<0.01 and math.abs(launcher.y-5/lastLayoutScale)<0.01,
    'drag uses screen coordinates and converts to layout scale')
postedDrag:OnRelease(); assert(postedDrag.destroyed, 'release destroys dragger')
advanceTransitions()
assert(math.abs(launcher.x-40/lastLayoutScale)<0.01, 'opening transition preserves drag offset')
local count=#controls
menu:Open(); assert(#controls==count,'one menu instance')
assert(not textControl('Probe'),'launcher opens without module settings')
click('Core'); assert(not focused,'section leaves game keyboard focus alone')
local panel=textControl('Core')
-- Core uses the compact panel (Menu.lua Render -> SetPanelSize(corePanelWidth,corePanelHeight)).
for _,c in ipairs(controls) do
    if c.parent==group and c~=launcher and c.Width()==theme.Metrics.corePanelWidth then panel=c end
end
local panelHeader
-- Drag header is created at width-72 then resized to panelWidth-72 by SetPanelSize (Menu.lua:357).
for _,c in ipairs(controls) do if c.parent==panel and c.Width()==theme.Metrics.corePanelWidth-72 and c.Height()==72 then panelHeader=c end end
assert(panelHeader, 'settings drag header exists')
panelHeader:HandleEvent({Type='ButtonPress',MouseX=100,MouseY=100,KeyCode=1,Modifiers={Left=true}})
postedDrag:OnMove(80,105)
assert(math.abs(panel.x-(264-20/lastLayoutScale))<0.01 and math.abs(panel.y-5/lastLayoutScale)<0.01,
    'settings panel follows mouse independently')
assert(math.abs(launcher.x-40/lastLayoutScale)<0.01, 'settings drag leaves launcher in place')
postedDrag:OnRelease()
click('Probe')
assert(option.value==false and option.saved==false and saved==1)
assert(textControl('○'),'off state must have a visible state marker')
-- Toggles save silently; the brief status is emitted by key capture (Menu.lua:700).
click('Probe'); assert(option.value and option.saved and saved==2)
assert(textControl('●'),'on state must have a visible state marker')
click('Editor')
-- Dialogs mount in the panel content above the chrome; depth is relative (Menu.lua:432), not absolute.
assert(child.parent and child.parent.parent==panel and child.parent.Width()==384,'action dialog mounts in the resized panel content')
assert(#escapes==2,'dialog joins the Escape stack above the menu')
local topHandler=#escapes
escapes[topHandler](); assert(closeAttempts==1 and not child.destroyed and #escapes==2)
escapes[topHandler](); assert(child.destroyed and #escapes==1,'return to menu after editor confirmation')
-- Launch clears the remembered section (Menu.lua:428), so re-enter it before the close/reopen check.
click('Core'); assert(textControl('Probe'),'returning to the section drops the action window')
local bindings=0; for fn in pairs(callbacks) do bindings=bindings+1 end
assert(bindings==1,'return must not duplicate option bindings')
click('×'); assert(#escapes==1,'close waits for transition')
local fading
for _,c in ipairs(controls) do
    if not c.destroyed and c.needsFrameUpdate and c.OnFrame and c.parent and c.parent.parent==root then fading=c end
end
assert(fading,'close starts transition'); fading:OnFrame(0.08)
assert(fading.alpha and math.abs(fading.alpha-0.5)<0.001 and #escapes==1,'menu fades before destruction')
advanceTransitions(); assert(#escapes==0 and next(callbacks)==nil)
assert(closedCount==1,'menu close callback runs once after destruction')
menu:Open(); assert(#escapes==1)
assert(textControl('Probe'),'reopening restores the selected section')
local reopenedLauncher=launcherControl()
local reopenedGroup=reopenedLauncher.parent
local reopenedPanel
for _,c in ipairs(controls) do
    if c.parent==reopenedGroup and c~=reopenedLauncher and c.Width()==theme.Metrics.corePanelWidth then reopenedPanel=c end
end
assert(math.abs(reopenedLauncher.x-40/lastLayoutScale)<0.01 and math.abs(reopenedLauncher.y-5/lastLayoutScale)<0.01,
    'launcher position survives closing')
assert(reopenedPanel and math.abs(reopenedPanel.x-(264-20/lastLayoutScale))<0.01 and math.abs(reopenedPanel.y-5/lastLayoutScale)<0.01,
    'settings position survives closing independently')
local panelClose
for _,c in ipairs(controls) do
    if not c.destroyed and c.text=='×' and c.parent and c.parent.parent and c.parent.parent.Width()==theme.Metrics.corePanelWidth then panelClose=c.parent end
end
assert(panelClose,'settings close button exists')
panelClose:HandleEvent({Type='ButtonPress'})
assert(not textControl('Probe') and not focused,'closing settings returns to launcher without keyboard capture')
escapes[1](); advanceTransitions(); assert(#escapes==0 and next(callbacks)==nil)
menu:Open(); assert(not textControl('Probe'),'reopening preserves launcher-only state'); menu:Destroy()
assert(#escapes==0 and next(callbacks)==nil)
assert(not menu:Register({id='late',title='Late'}))
count=#controls; menu:Open(); assert(#controls==count)
local many=env.Create()
for i=1,8 do assert(many:Register({id='s'..i,title='Section '..i})) end
many:Open()
assert(scrollbarTarget)
scrollbarTarget:ScrollSetTop('Vert',3)
local _,_,scrollTop=scrollbarTarget:GetScrollValues(); assert(scrollTop==3)
scrollbarTarget:ScrollSetTop('Vert',1000) -- 4 placeholder sections precede the registrations (Menu.lua:22-30)
assert(button('Section 8'))
scrollbarTarget:ScrollPages('Vert',-1)
_,_,scrollTop=scrollbarTarget:GetScrollValues(); assert(scrollTop==1)
many:Destroy(); assert(#escapes==0)
local longMenu=env.Create()
local longToggles={}
for i=1,20 do longToggles[i]={label='Setting '..i,option=option} end
longMenu:Register({id='long',title='Long',toggles=longToggles})
longMenu:Open(); click('Long')
assert(textControl('Setting 1') and not textControl('Setting 20'),'long page initially renders only visible rows')
local pageScroll=scrollbarTarget
local originalScrollbar=scrollbarWidget
assert(pageScroll and pageScroll.IsScrollable and pageScroll:IsScrollable())
local seenSettings={}
for top=0,100 do
    pageScroll:ScrollSetTop('Vert',top)
    for i=1,20 do if textControl('Setting '..i) then seenSettings[i]=true end end
end
for i=1,20 do assert(seenSettings[i], 'every setting must be reachable: '..i) end
pageScroll:ScrollSetTop('Vert',0)
pageScroll:ScrollPages('Vert',1)
assert(not textControl('Setting 1'),'scroll removes rows above the viewport')
assert(scrollbarWidget==originalScrollbar and not originalScrollbar.destroyed,'scrollbar survives scrolling and can retain a drag')
pageScroll=scrollbarTarget; pageScroll:ScrollSetTop('Vert',1000)
assert(textControl('Setting 20'),'last setting is reachable through the scrollbar')
longMenu:Destroy(); assert(next(callbacks)==nil,'scrolling removes all option listeners')
local menuScale={value=125,Get=option.Get}
function menuScale:Set(value) self.value=value end
function menuScale:Save() self.saved=self.value end
local scaleMenu=env.Create(nil,menuScale)
scaleMenu:Register({id='core',title='Scale'})
for _,case in ipairs({{1920,1080,1,125},{1920,1080,1.25,100},{2560,1440,1,150},{1280,720,0.8,150},{1920,1080,1,110}}) do
    root.Width:Set(case[1]); root.Height:Set(case[2]); pixelScale=case[3]
    menuScale:Set(case[4])
    scaleMenu:Open()
    -- Fit group is launcher 248 + gap 16 + panel 1128 = 1392 wide (Menu.lua:86).
    local fit=math.min((case[1]-24)/1392,(case[2]-24)/1110)
    local factor=case[4]==100 and 0.8 or case[4]==150 and 1.2 or 1
    local expected=math.min(fit,math.min(case[3],fit)*factor)
    assert(math.abs(lastLayoutScale-expected)<0.00001,'group fits screen with UI scale applied once')
    assert(1392*lastLayoutScale<=case[1]-24 and 1110*lastLayoutScale<=case[2]-24,'both panels stay inside screen margins')
    escapes[#escapes]()
    advanceTransitions()
end
scaleMenu:Destroy(); root.Width:Set(1920); root.Height:Set(1080); pixelScale=1
local longConflict='Сочетание уже используется действием «Очень длинное русское название игрового действия для проверки сокращения сообщения без повреждения символов».'
local binding={key='Ctrl-Alt-C',writes=0}
function binding:Get() return self.key end
function binding:FromEvent(event) return event.testKey end
function binding:Validate(key) return key~='Ctrl-X',longConflict end
function binding:Set(key)
    if not self:Validate(key) then return false,longConflict end
    self.key=key; self.writes=self.writes+1; return true
end
local keyed=env.Create(binding)
assert(keyed:Register({id='core',title='Core'}))
keyed:Open()
assert(not focused and not textControl('Применить'),'launcher does not capture keyboard')
click('Core')
assert(textControl('Ctrl') and textControl('Alt') and textControl('C'),'saved combination loads as key caps')
click('Изменить'); assert(focused and keyed:IsKeyCaptureActive())
local nested=false; escapes[#escapes+1]=function() nested=true; table.remove(escapes) end
key(27); assert(nested and focused and textControl('Нажмите сочетание…'),'Escape reaches the topmost nested handler before capture')
assert(textControl('Нажмите сочетание…'))
key(75,nil,'Ctrl-K')
assert(binding.key=='Ctrl-K' and not focused and not keyed:IsKeyCaptureActive() and not textControl('Нажмите сочетание…'),'capture saves immediately and restores navigation')
local notice=assert(textControl('Сохранено'))
assert(notice.needsFrameUpdate)
notice:OnFrame(1.6)
assert(notice.text=='' and not notice.needsFrameUpdate,'saved notice expires')
click('Изменить')
key(88,nil,'Ctrl-X')
assert(binding.key=='Ctrl-K' and focused and textControl('Нажмите сочетание…'),'conflict keeps old binding and allows retry')
local conflict
for _,c in ipairs(controls) do
    if not c.destroyed and c.tooltip==longConflict then conflict=c; break end
end
assert(conflict and conflict.text~=longConflict and string.sub(conflict.text,-3)=='…','long conflict is shortened and full text stays in tooltip')
assert(utf8.len(conflict.text),'shortened Cyrillic message must remain valid UTF-8')
key(27)
assert(not focused and not keyed:IsKeyCaptureActive() and not textControl('Нажмите сочетание…') and #escapes==1,'Escape cancels capture before menu close')
click('Изменить'); key(27); assert(not focused and #escapes==1,'first Escape cancels key capture')
escapes[#escapes](); advanceTransitions(); assert(not focused and #escapes==0,'next Escape closes menu through the UI Escape stack')
keyed:Open(); assert(not focused and #escapes==1); click('Core')
click('Убрать сочетание'); assert(binding.key=='' and textControl('Не назначено'))
local writes=binding.writes
click('Убрать сочетание'); assert(binding.writes==writes,'disabled clear must not write again')
escapes[#escapes](); advanceTransitions(); assert(#escapes==0 and not focused)
keyed:Open(); click('Core')
click('Изменить'); key(27); click('×'); advanceTransitions(); assert(not focused and #escapes==0)
keyed:Open(); click('Core'); assert(not focused and textControl('Не назначено'),'cleared setting survives reopening')
click('Изменить'); assert(keyed:IsKeyCaptureActive()); keyed:Destroy()
assert(not keyed:IsKeyCaptureActive(),'destroy clears capture state')
assert(not focused and #escapes==0,'menu destruction releases keyboard focus')
local seenInput={}
for _,line in ipairs(inputLogs) do seenInput[line]=true end
assert(seenInput['[Claret][input] capture=on owner=menu_key_capture'] and seenInput['[Claret][input] capture=off owner=menu_key_capture'], 'probe logs explicit key capture lifecycle')
print('PASS: Claret menu deferred UI, singleton, section registration, option persistence, editor discard confirmation, return, Escape and cleanup')
print('PASS: immediate key persistence, capture/retry/Escape, loaded key caps, disabled clear, capture focus cleanup')

-- The separate Hotbuild entry point registers settings without opening its runtime/UI.
local inlineMenu=env.Create()
local embedded,mayLeave,inlineHost,pendingLeave,resizeInline,fitInline
inlineMenu:Register({id='core',title='Small'})
inlineMenu:Register({id='hotbuild',title='Large',inline=function(host,layout)
    inlineHost=host; resizeInline=layout.setHeight; assert(layout.scale>0)
    fitInline=layout.setSize
    embedded=control(host)
    embedded.CanLeave=function(intent,continuation)
        if mayLeave then return true end
        pendingLeave=continuation
        return false
    end
    return embedded
end})
inlineMenu:Open()
local launcher=button('×').parent
-- Launcher height follows its rows: 112+4*48 for 2 registered and 2 placeholder sections (Menu.lua:85).
assert(launcher.Width()==theme.Metrics.launcherWidth and launcher.Height()==112+4*48)
assert(not embedded, 'launcher opens alone')
click('Large')
local panel=inlineHost.parent
-- The wide Hotbuild section keeps the full panel metrics (Menu.lua:446-447).
assert(panel.Width()==theme.Metrics.panelWidth and panel.Height()==theme.Metrics.panelHeight and not panel.hidden)
resizeInline(626); assert(panel.Height()==750, 'inline editor can resize its own panel')
fitInline(224,44)
assert(panel.Width()==272 and panel.Height()==168 and inlineHost.Width()==224 and inlineHost.Height()==44,
    'compact window and inline host fit a single navigation row')
fitInline(624,300)
assert(panel.Width()==672 and panel.Height()==424 and inlineHost.Width()==624 and inlineHost.Height()==300,
    'window and inline host grow together for a taller settings page')
fitInline(624,300,{split=232,left=44,right=300})
local leftBody,rightBody
for _,item in ipairs(controls) do
    if item.parent==panel and item.y==100 and item.HandleEvent then
        if item.x==0 then leftBody=item end
        if item.x==256 then rightBody=item end
    end
end
assert(panel.hitTestDisabled and leftBody and rightBody and leftBody.Height()==68 and rightBody.Height()==324,
    'only the visible parts of independently sized columns catch input')
local decoratedFrames={}
for _,item in ipairs(controls) do
    if item.texture and item.texture:find('panel%-shadow') and item.parent.parent==panel and not item.parent.hidden then
        decoratedFrames[item.parent]=true
    end
end
local decoratedCount=0
for frame in pairs(decoratedFrames) do
    assert(frame.hitTestDisabled, 'column decoration must pass pointer input through')
    decoratedCount=decoratedCount+1
end
assert(decoratedCount==2, 'both columns retain themed shadows while expanded')
fitInline(224,44)
assert(leftBody.hidden and rightBody.hidden and not panel.hitTestDisabled,
    'collapsing restores the regular rectangular panel')
mayLeave=false; click('Small'); assert(not embedded.destroyed)
local cancelNavigation=pendingLeave; assert(cancelNavigation); cancelNavigation(false)
click('Small'); local saveNavigation=pendingLeave; assert(saveNavigation)
saveNavigation(true)
-- 'Small' is the core section, which uses the compact panel metrics (Menu.lua:446-447).
assert(embedded.destroyed and panel.Width()==theme.Metrics.corePanelWidth and panel.Height()==theme.Metrics.corePanelHeight)
click('Large'); assert(embedded and not embedded.destroyed)
mayLeave=false
local panelClose
for _,c in ipairs(controls) do
    if not c.destroyed and c.text=='×' and c.parent.parent==panel then panelClose=c.parent end
end
assert(panelClose); panelClose:HandleEvent({Type='ButtonPress'})
assert(not embedded.destroyed); pendingLeave(false)
panelClose:HandleEvent({Type='ButtonPress'}); pendingLeave(true)
assert(embedded.destroyed and panel.hidden and not launcher.hidden)
click('Large'); assert(embedded and not embedded.destroyed)
mayLeave=true; click('×'); advanceTransitions(); assert(embedded.destroyed)
inlineMenu:Destroy()
print('PASS: launcher, fixed panel and guarded navigation/independent close')
local mixedMenu=env.Create()
local mixedEditor,mixedHost,mixedOpens
mixedOpens=0
mixedMenu:Register({id='mixed',title='Mixed',toggles=longToggles,inline=function(host)
    mixedHost=host; mixedOpens=mixedOpens+1; mixedEditor=control(host)
    mixedEditor.CanLeave=function() assert(not mixedHost.hidden,'leave confirmation must be visible'); return true end
    return mixedEditor
end})
mixedMenu:Register({id='next',title='Next'})
mixedMenu:Open(); click('Mixed')
local mixedScroll=scrollbarTarget
assert(mixedHost.hidden and not mixedEditor.destroyed and mixedOpens==1,'offscreen inline editor is retained and hidden')
mixedScroll:ScrollSetTop('Vert',1000)
assert(not mixedHost.hidden and not mixedEditor.destroyed and mixedOpens==1,'scroll reveals the same inline editor')
mixedScroll:ScrollSetTop('Vert',0)
assert(mixedHost.hidden and not mixedEditor.destroyed and mixedOpens==1,'scrolling back preserves editor state')
click('Next'); assert(mixedEditor.destroyed,'switching section reveals and then destroys retained editor')
mixedMenu:Destroy()
print('PASS: mixed simple and inline content scroll without recreating editor')
local definitions, feature, posts = {}, nil, {}
local navPages, runtimeCreated, deferred, menuOpen, refreshes
refreshes=0
local addonEnv=setmetatable({
    LOG=function() end,
    math={}, -- FAF LuaPlus does not expose math.huge.
    ForkThread=function(fn) deferred=coroutine.create(fn); assert(coroutine.resume(deferred)) end,
    WaitFrames=function(n) assert(n==2); coroutine.yield() end,
    ReUI={Require=function() end, Options={Mods={ClaretHotbuild={enabled=option}}},
        ClaretCore={Localization=testLocalization,RegisterFeature=function(id,start,value) feature={id=id,start=start,value=value}; return true end,
            RegisterSettingsSection=function(value) definitions[#definitions+1]=value; return true end,
            IsMenuOpen=function() return menuOpen end},
        Core={Hook=function() end,OnPostCreateUI=function(fn) posts[#posts+1]=fn end}},
    import=function(path)
        if path=='/mods/ClaretHotbuild/modules/LocalizationStrings.lua' then return {Strings=testLocalization.Tables.hotbuild} end
        if path=='/mods/ClaretHotbuild/modules/Runtime.lua' then
            return {Create=function()
                runtimeCreated=true
                return {
                    active=true, RefreshKeys=function() refreshes=refreshes+1 end,
                    OpenKeyboardEditor=function(self,host,layout) return {kind='keyboard',host=host,scale=layout.scale} end,
                    OpenEditor=function(self,host,layout) return {kind='hotbuild',host=host,scale=layout.scale} end,
                    OpenContextEditor=function(self,host,layout) return {kind='contexts',host=host,scale=layout.scale} end,
                }
            end}
        end
        if path=='/mods/ClaretHotbuild/modules/BuildKeyLabels.lua' then return {} end
        if path=='/mods/ClaretHotbuild/modules/OpenPerf.lua' then return {Start=function() return nil end} end
        assert(path=='/mods/ClaretHotbuild/modules/Navigator.lua')
        return {Create=function(parent,layout,pages) navPages=pages; return {parent=parent,scale=layout.scale,pages=pages} end}
    end,
},{__index=_G})
addonEnv.SavePreferences=function() end
assert(loadfile('../mods/ClaretHotbuild/Main.lua','t',addonEnv))()
addonEnv.Main(false)
assert(feature.id=='hotbuild' and feature.value and feature.value.Get and feature.value.Get()==true and #posts==1)
assert(#definitions==1, 'Hotbuild must register one navigable settings section')
local byId={}
for _,definition in ipairs(definitions) do byId[definition.id]=definition end
assert(byId.hotbuild and byId.hotbuild.toggles==nil)
assert(type(byId.hotbuild.inline)=='function' and byId.hotbuild.actions==nil)
assert(not byId.hotbuild_context, 'subpages belong inside the Hotbuild section')
assert(not runtimeCreated, 'Hotbuild runtime remains deferred until the menu opens')
local host={}
local wrapper=byId.hotbuild.inline(host,{scale=0.8})
assert(runtimeCreated and wrapper.parent==host and wrapper.scale==0.8 and table.getn(navPages)==3)
byId.hotbuild.onMenuClosed(); assert(refreshes==0); assert(coroutine.resume(deferred)); assert(refreshes==1,'refresh follows frame delay')
byId.hotbuild.onMenuClosed(); menuOpen=true; assert(coroutine.resume(deferred)); assert(refreshes==1,'reopened menu cancels delayed refresh'); menuOpen=false
assert(navPages[1].id=='keyboard' and navPages[2].id=='hotbuild' and navPages[3].id=='contexts'
    and table.getn(navPages)==3)
assert(navPages[1].open(host,{scale=0.6}).kind=='keyboard')
assert(navPages[2].open(host,{scale=0.6}).kind=='hotbuild')
assert(navPages[3].open(host,{scale=0.6}).kind=='contexts')
print('PASS: standalone Hotbuild registers one navigable settings section before UI creation')
