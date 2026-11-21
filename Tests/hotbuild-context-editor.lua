-- Context editor layout, catalog refresh, embedded close and dirty deletion guard.
local testLocalization = dofile('Tests/localization-test-helper.lua')
table.getn=function(t) return #t end
local controls={}
local scrollbarTargets={}
local scrollbarWidgets={}
local configuredEditSizes={}
local function value(v) return setmetatable({v=v,Set=function(self,n) self.v=n end},{__call=function(self) return self.v end}) end
local function control(parent)
    local c={parent=parent,Width=value(1920),Height=value(1080),Depth=value(0),text=''}
    if parent then
        parent.children=parent.children or {}
        parent.children[#parent.children+1]=c
    end
    controls[#controls+1]=c
    function c:SetSolidColor(v) self.color=v end
    function c:SetTexture(v) self.texture=v end
    function c:SetNeedsFrameUpdate(v) self.needsFrameUpdate=v end
    function c:SetColor(v) self.color=v end
    function c:SetText(v) self.text=v end
    function c:SetFont(font,size,style) self.font=font; self.fontSize=size; self.fontStyle=style end
    function c:GetText() return self.text end
    function c:DisableHitTest() self.disabled=true end
    function c:Show()
        self.hidden=false
        for _,child in ipairs(self.children or {}) do child:Show() end
    end
    function c:Hide()
        self.hidden=true
        for _,child in ipairs(self.children or {}) do child:Hide() end
    end
    function c:Destroy()
        if self.destroyed then return end
        self.destroyed=true
        for _,child in ipairs(self.children or {}) do child:Destroy() end
    end
    function c:OnDestroy() end
    function c:AbandonKeyboardFocus() self.focusReleased=true end
    return c
end
local function createText(parent,text) local c=control(parent); c.text=text; return c end
local function layout(c)
    local l={}
    function l:Width(v) c.Width:Set(v); return self end
    function l:Height(v) c.Height:Set(v); return self end
    function l:AtCenterIn() return self end
    function l:AtLeftTopIn(_,x,y) c.x=x; c.y=y; return self end
    return l
end
local Theme={Fonts={body='Nunito',heading='Nunito SemiBold'},Metrics={buttonHeight=36,buttonText=15,fieldHeight=36,text=16},Colors={canvas='canvas',surface='surface',raised='raised',hover='hover',accent='accent',
    selected='selected',selectedBorder='selectedBorder',border='border',text='text',muted='muted',
    danger='danger',warning='warning',warningSurface='warningSurface',warningBorder='warningBorder',accentHover='accentHover',accentText='accentText',disabled='disabled'},
    Outline=function(control)
        return function(color) control.outline=color end
    end,
    SettingsSwitch=function(row) return function(on) row.settingEnabled=on==true end end,
    AnimateCentered=function(control) control:SetNeedsFrameUpdate(true) end,
    AnimateAnchored=function(control) control:SetNeedsFrameUpdate(true) end}
local imports={
    ['/mods/ClaretCore/modules/Theme.lua']=Theme,
    ['/lua/maui/group.lua']={Group=control}, ['/lua/maui/bitmap.lua']={Bitmap=control},
    ['/lua/maui/edit.lua']={Edit=function(parent)
        local field=control(parent); field.Width:Set(0); field.Height:Set(0); return field
    end}, ['/lua/maui/layouthelpers.lua']={GetPixelScaleFactor=function() return 1 end},
    ['/lua/ui/uiutil.lua']={bodyFont='Arial',CreateText=createText,SetupEditStd=function(field)
        assert(field.Width()>0 and field.Height()>0,'context edit geometry must be assigned before SetupEditStd')
        assert(field.Width()>0 and field.Height()>0,'context edit uses positive geometry before SetupEditStd')
        configuredEditSizes[#configuredEditSizes+1]={width=field.Width(),height=field.Height()}
    end,
        CreateVertScrollbarFor=function(target)
            scrollbarTargets[#scrollbarTargets+1]=target
            local scroll=control(target)
            scroll.visible=true
            function scroll:Show() self.visible=true end
            function scroll:Hide() self.visible=false end
            scrollbarWidgets[#scrollbarWidgets+1]=scroll
            return scroll
        end},
    ['/lua/ui/game/tooltip.lua']={DestroyMouseoverDisplay=function() end,
        AddAutoUpdatedControlTooltip=function(c,title,body) c.tooltip={title=title,body=body} end},
    ['/lua/ui/dialogs/eschandler.lua']={PushEscapeHandler=function() end,PopEscapeHandler=function() end},
}
local logs={}
local env=setmetatable({ReUI={ClaretCore={Localization=testLocalization},UI={FloorLayouter=function() return layout end}},
    LOG=function(message) logs[#logs+1]=message end,
    import=function(path) return assert(imports[path],path) end,
    math=math,string=string,table=table,ipairs=ipairs,pairs=pairs,tostring=tostring,type=type,
    pcall=pcall,error=error,assert=assert,select=select,tonumber=tonumber}, {__index=_G})
assert(loadfile('../mods/ClaretHotbuild/modules/ContextEditor.lua','t',env))()
local actionEnv=setmetatable({}, {__index=_G})
assert(loadfile('../mods/ClaretHotbuild/modules/ContextActions.lua','t',actionEnv))()
local modelEnv=setmetatable({}, {__index=_G})
assert(loadfile('../mods/ClaretHotbuild/modules/ContextModel.lua','t',modelEnv))()
local actions=actionEnv
imports['/mods/ClaretHotbuild/modules/ContextActions.lua']=actions
local compatibilityEnv=setmetatable({import=function(path) return assert(imports[path],path) end},{__index=_G})
assert(loadfile('../mods/ClaretHotbuild/modules/Compatibility.lua','t',compatibilityEnv))()
imports['/mods/ClaretHotbuild/modules/Compatibility.lua']=compatibilityEnv
local model=modelEnv.Create({version=1,bindings={{id='saved1',name='Saved',rows={{context='acu',action='move'}}}}},actions)
local commits=0
local service={contextActions=actions,contextModel=model,keyboardBindings={KeysFor=function(self,ref) assert(ref.kind=='composite'); return {'F3','Alt-K'} end}}
function service:CommitContext(binding,removeId)
    commits=commits+1
    local candidate=modelEnv.Create(model:Export(),actions)
    local ok,message
    if removeId then ok,message=candidate:Delete(removeId) else ok,message=candidate:Put(binding) end
    if not ok then return false,message end
    model=candidate; self.contextModel=model
    return true,'Сохранено'
end
local host=control()
local frame=env.Create(host,service,nil)
assert(frame.Width()>0 and frame.Height()>0)
-- Maui controls with a size but no position have a circular Left/Top chain; the
-- game reports it as a lazyvar failure and the tree breaks when a group expands.
for _,c in ipairs(controls) do
    if not c.destroyed and c.parent and c.parent~=host and c.HandleEvent and c.x==nil then
        error('interactive control created without a position')
    end
end
local hint=false
for _,c in ipairs(controls) do if c.text=='используется на клавишах: F3, Alt-K' then hint=true end end
assert(hint,'composite shows assigned keys as a read-only hint')
assert(#configuredEditSizes>=1,'context editor configures its name field after layout')
local savedPicker
for _,c in ipairs(controls) do if c.parent==frame and c.Width()==300 and c.Height()==38 then savedPicker=c end end
assert(savedPicker,'saved-set picker is present')
local function savedPickerIn(root)
    for _,c in ipairs(controls) do
        if not c.destroyed and c.parent==root and c.Width()==300 and c.Height()==38 then return c end
    end
end
local function openSaved(root)
    local picker=savedPickerIn(root)
    if picker then picker:HandleEvent({Type='ButtonPress',Modifiers={}}); return end
    for _,c in ipairs(controls) do
        if not c.destroyed and c.parent==root and c.HandleEvent and c.Width()>0
            and (c.text=='Наборы' or c.text=='Сохранённые наборы' or c.text=='Набор') then
            c:HandleEvent({Type='ButtonPress',Modifiers={}}); return
        end
    end
    -- Fallback for implementations whose picker is a compound button.
    for _,c in ipairs(controls) do
        if not c.destroyed and c.parent==root and c.HandleEvent and c.Width()>0 and c.Height()>0
            and c.Width()<root.Width() then
            c:HandleEvent({Type='ButtonPress',Modifiers={}}); return
        end
    end
    error('missing saved-set dropdown')
end
local function clickDeleteSaved(root)
    local seen={}
    for _,c in ipairs(controls) do
        local owner=c
        while owner and owner~=root do owner=owner.parent end
        if owner==root and not c.destroyed and c.HandleEvent then table.insert(seen,tostring(c.Width())..'x'..tostring(c.Height())..'@'..tostring(c.x)..':'..tostring(c.text)) end
        if not c.destroyed and owner==root and c.HandleEvent and c.Width()==34 and c.Height()==34 and c.x==314 then
            c:HandleEvent({Type='ButtonPress',Modifiers={Left=true}}); return
        end
    end
    error('missing saved-set delete control: '..table.concat(seen,' | '))
end
local function find(value)
    for _,c in ipairs(controls) do if not c.destroyed and c.text==value then return c end end
end
local function click(value)
    local c=assert(find(value),'missing control: '..value)
    local target=c.parent
    assert(target.HandleEvent,'control has no click handler: '..value)
    target:HandleEvent({Type='ButtonPress',Modifiers={}})
end
local function inside(c,root)
    local p=c
    while p do if p==root then return true end; p=p.parent end
    return false
end
local contextText={
    ['Под курсором']='cursor',['Ничего не выделено']='empty',['Войска']='units',['Строители']='builder',['Завод']='factory',
    ['Истребители']='fighter',['Бомбардировщики']='bomber',['Штурмовики']='gunship',
    ['Ракеты']='missiles',['Транспорт']='transport',['Добытчики']='mex',['Разведчики']='scout',
    ['Остальные']='other',['Наземные']='land',['Авиация']='air',['Флот']='navy',
    ['ACU']='acu',['SACU']='sacu',['Инженер']='engineer',['ТМЛ']='silo_tactical',['Ядерка']='silo_nuclear',
}
local contextDisplay={cursor='Под курсором',empty='Ничего не выделено',units='Войска',builder='Строители',factory='Завод',missiles='Ракеты',
    fighter='Истребители',bomber='Бомбардировщики',gunship='Штурмовики',transport='Транспорт',mex='Добытчики',scout='Разведчики',other='Остальные',land='Наземные',air='Авиация',navy='Флот',
    acu='ACU',sacu='SACU',engineer='Инженер',silo_tactical='ТМЛ',silo_nuclear='Ядерка'}
local contextRank={cursor=1,empty=2,units=3,builder=4,factory=5,missiles=6,mex=7,other=8}
local function contextNeedle(value) return contextText[value] or value end
local function treeButton(root,id)
    id=contextNeedle(id)
    local display=contextDisplay[id]
    for _,c in ipairs(controls) do
        local button=c.parent
        local panel=button and button.parent
        local isTitle=type(c.text)=='string' and (c.text==id or c.text==display
            or c.text=='· '..tostring(id) or c.text=='· '..tostring(display)
            or (contextRank[id] and (c.text==tostring(contextRank[id])..' · '..tostring(id)
                or c.text==tostring(contextRank[id])..' · '..tostring(display))))
        if not c.destroyed and inside(c,root) and type(c.text)=='string'
            and isTitle
            and button and button.HandleEvent and panel and panel.parent==root
            and panel.Width()==480 and panel.Height()==614 then return button
        end
    end
end
local function catalogIn(root)
    local found
    for _,c in ipairs(controls) do
        if not c.destroyed and inside(c,root) and c.ScrollSetTop and c.GetScrollValues
            and c.Width()==520 and c.Height()>300 and (not found or c.Height()<found.Height()) then found=c end
    end
    return found
end
local function selectSaved(root,name)
    local list
    for _,c in ipairs(controls) do
        if not c.destroyed and inside(c,root) and c.GetScrollValues and c.ScrollSetTop and c.parent then list=c.parent; break end
    end
    assert(list,'saved dropdown list is visible')
    for _,c in ipairs(controls) do
        if not c.destroyed and inside(c,list) and c.text==name then
            local target=c
            while target and not target.HandleEvent do target=target.parent end
            if target then target:HandleEvent({Type='ButtonPress',Modifiers={Left=true}}); return end
        end
    end
    error('missing saved profile row: '..name)
end
local function clickIn(root,text)
    local original=text
    text=contextNeedle(text)
    if contextDisplay[text] then
        local target=treeButton(root,text)
        if target then target:HandleEvent({Type='ButtonPress',Modifiers={}}); return end
    end
    for _,c in ipairs(controls) do
        if not c.destroyed and inside(c,root) and c.text==text then
            local target=c
            while target and not target.HandleEvent do target=target.parent end
            if target then target:HandleEvent({Type='ButtonPress',Modifiers={}}); return end
        end
    end
    for _,c in ipairs(controls) do
        if not c.destroyed and inside(c,root) and (c.text==text or
            (text=='Выбрать ACU' and type(c.text)=='string' and string.find(c.text,'ДВОЙНОЕ · Выбрать ACU',1,true)) or
            (type(c.text)=='string' and string.find(c.text,text,1,true)) or
            (text=='ACU' and type(c.text)=='string' and (c.text=='ACU' or string.find(c.text,' · ACU',1,true))) or
            (text=='Завод' and type(c.text)=='string' and string.find(c.text,'Завод',1,true))) then
            local target=c
            while target and not target.HandleEvent do target=target.parent end
            if target then
                target:HandleEvent({Type='ButtonPress',Modifiers={}})
                return
            end
        end
    end
    local panel=catalogIn(root)
    if panel then
            local _,maximum=panel:GetScrollValues()
            for top=2,maximum do
                panel:ScrollSetTop('Vert',top)
                for _,c in ipairs(controls) do
                    if not c.destroyed and inside(c,root) and (c.text==text or (type(c.text)=='string' and string.find(c.text,text,1,true))) then
                        local target=c.parent
                        while target and not target.HandleEvent do target=target.parent end
                        if target then target:HandleEvent({Type='ButtonPress',Modifiers={}}); return end
                    end
                end
            end
            panel:ScrollSetTop('Vert',1)
    end
    local found={}
    for _,c in ipairs(controls) do if not c.destroyed and inside(c,root) and type(c.text)=='string' and c.text~='' then table.insert(found,c.text) end end
    error('missing control in editor: '..text..' ['..table.concat(found,' | ')..']')
end
local function findIn(root,text)
    text=contextNeedle(text)
    local display=contextDisplay[text]
    for _,c in ipairs(controls) do
        if not c.destroyed and inside(c,root) and (c.text==text or
            (type(c.text)=='string' and (string.find(c.text,text,1,true) or (display and string.find(c.text,display,1,true))))) then return c end
    end
end
local function clickAcu(root)
    local target=assert(treeButton(root,'ACU'),'ACU context exists')
    assert(not target.hidden,'ACU context is visible before selection')
    target:HandleEvent({Type='ButtonPress',Modifiers={Left=true}})
end
local edit
for _,c in ipairs(controls) do if c.parent==frame and c.OnTextChanged and c.Width()==330 then edit=c end end
assert(edit,'name editor exists')
edit.text='Unsaved draft'; edit:OnTextChanged('Unsaved draft')
assert(findIn(frame,'● не сохранено'),'draft state is visible')
assert(not findIn(frame,'Всего наборов:'),'saved-set count is not displayed')
do
local savedDeleteModel=modelEnv.Create({version=3,bindings={{id='delete_me',name='Delete me',rows={{context='acu',action='move'}}}}},actions)
local deleteCalled=false
local savedDeleteService={contextActions=actions,contextModel=savedDeleteModel,
    keyboardBindings={KeysFor=function() return {'F3','Alt-K'} end}}
function savedDeleteService:CommitContext(binding,removeId,confirmed)
    assert(removeId=='delete_me' and confirmed==true,'deletion service receives explicit confirmation')
    deleteCalled=true
    local candidate=modelEnv.Create(self.contextModel:Export(),actions)
    local ok,message=candidate:Delete(removeId)
    if not ok then return false,message end
    self.contextModel=candidate
    return true,'Удалено'
end
local savedDeleteFrame=env.Create(host,savedDeleteService,nil)
openSaved(savedDeleteFrame)
local deletePickerList=false
for _,c in ipairs(controls) do if not c.destroyed and inside(c,savedDeleteFrame) and c.GetScrollValues and c.Width()==372 then deletePickerList=true end end
assert(deletePickerList,'delete fixture opens its saved-set list')
clickDeleteSaved(savedDeleteFrame)
assert(not deleteCalled and savedDeleteService.contextModel:Get('delete_me'),
    'the first click only arms deletion')
assert(findIn(savedDeleteFrame,'Удалить «Delete me»'),'the armed row names the set')
clickDeleteSaved(savedDeleteFrame)
assert(deleteCalled and not savedDeleteService.contextModel:Get('delete_me'),
    'the second click deletes the set with explicit authorization')
local stillOpen=false
for _,c in ipairs(controls) do
    if not c.destroyed and inside(c,savedDeleteFrame) and c.GetScrollValues and c.Width()==372 then stillOpen=true end
end
assert(stillOpen,'the saved-set list stays open after deletion')
savedDeleteFrame:Destroy()
end
clickIn(frame,'Новый')
assert(commits==0 and model:Get('saved1'),'dirty draft must block leaving the saved profile')
assert(find('Несохранённые изменения'),'dirty draft opens the leave confirmation')
clickIn(frame,'Не сохранять')
assert(commits==0 and model:Get('saved1'),'discarding a draft leaves the saved model unchanged')
-- Create a new set after explicitly discarding the protected draft.
clickIn(frame,'Новый')
for _,c in ipairs(controls) do if c.parent==frame and c.OnTextChanged and c.Width()==330 then c.text='First'; c:OnTextChanged('First') end end
clickIn(frame,'Войска')
assert(findIn(frame,'Войска'),'unit context is selected')
do
    local catalog
    for _,c in ipairs(controls) do
        if not c.destroyed and inside(c,frame) and c.GetScrollValues and c.Width()==520 then catalog=c end
    end
    assert(catalog,'action catalog exists')
    local rows=0
    for _,c in ipairs(controls) do
        if not c.destroyed and c.parent==catalog and c.HandleEvent then
            rows=rows+1
            assert(c.y+c.Height()<=440,'action row stays above the controls')
        end
    end
    assert(rows>9,'catalog uses available height instead of reserving a fixed nine rows')
    catalog:ScrollSetTop('Vert',9999)
    local _,maximum,top,last=catalog:GetScrollValues()
    assert(top<=maximum and last==maximum,'scrolling reaches the last action without leaving a blank page')
    catalog:ScrollSetTop('Vert',1)
end
clickIn(frame,'Под курсором')
clickIn(frame,'Улучшить структуру под курсором')
clickAcu(frame)
clickIn(frame,'Overcharge')
-- Rebuilding a grouped catalog must survive selection, filtering, and scrolling.
local search, catalog
for _,c in ipairs(controls) do
    if not c.destroyed and c.parent==frame and c.OnEscPressed then search=c end
    if not c.destroyed and inside(c,frame) and c.GetScrollValues and c.Width()==520 then catalog=c end
end
assert(search and catalog, 'search field and scrollable catalog exist')
search.text='Overcharge'; search:OnTextChanged(search.text)
assert(search:OnEscPressed(search.text)==true and search.focusReleased and search.text=='Overcharge', 'Escape releases focus without clearing the search')
search.text=''; search:OnTextChanged('')
catalog:ScrollLines('Vert',1)
local visibleRow=false
for _,c in ipairs(controls) do if not c.destroyed and c.parent==catalog and c.HandleEvent then visibleRow=true end end
assert(visibleRow, 'scrolling rebuilds visible catalog rows')
clickIn(frame,'Сохранить')
local first=model:Get('context_1')
assert(first and #first.rows==2 and first.rows[1].context=='cursor' and first.rows[1].action=='upgrade_structure_under_cursor')
assert(first.rows[2].context=='acu' and first.rows[2].action=='overcharge')
-- Create another set through the UI, replacing the ACU action in place.
clickIn(frame,'Новый')
for _,c in ipairs(controls) do if c.parent==frame and c.OnTextChanged and c.Width()==330 then c.text='Second'; c:OnTextChanged('Second') end end
clickAcu(frame)
clickIn(frame,'Реклейм')
clickIn(frame,'Сохранить')
local second=model:Get('context_2')
assert(second and #second.rows==1 and second.rows[1].context=='acu' and second.rows[1].action=='reclaim')
-- Returning to the first saved set must refresh both the context summary and selected action tile.
openSaved(frame)
selectSaved(frame,'First')
local savedUsage
local usageDebug={}
for _,c in ipairs(controls) do
    if not c.destroyed and c.parent==frame and type(c.text)=='string' and string.find(c.text,'Активно:',1,true) then
        savedUsage=c.text; table.insert(usageDebug,c.text)
    end
end
assert(savedUsage and string.find(savedUsage,'Активно: 2',1,true) and string.find(savedUsage,'переопределено: 1',1,true),
    'loading a saved selection refreshes effective and override counts: '..table.concat(usageDebug,' | '))
local firstActionColor
for _,c in ipairs(controls) do
    if c.parent and inside(c,frame) and type(c.text)=='string'
        and string.find(c.text,'Улучшить структуру под курсором',1,true) then firstActionColor=c.parent.color end
end
assert(firstActionColor=='selected','catalog selection refreshes for the first row after switching saved sets')
local function tileIn(root,text)
    if text=='ACU' then
        for _,c in ipairs(controls) do
        if not c.destroyed and inside(c,root) and type(c.text)=='string' and c.text:find('ACU',1,true) then return c.parent end
        end
    end
    for _,label in ipairs(controls) do
        if not label.destroyed and inside(label,root) and (label.text==text or (type(label.text)=='string' and string.find(label.text,text,1,true)) or
            (text=='ACU' and type(label.text)=='string' and (label.text=='ACU' or string.find(label.text,' · ACU',1,true)))) then
            local candidate=label
            while candidate and not candidate.HandleEvent do candidate=candidate.parent end
            if candidate then return candidate end
        end
    end
    error('missing tile event handler: '..text)
end
openSaved(frame)
local savedList
for _,c in ipairs(controls) do if c.parent==frame and c.GetScrollValues and not c.destroyed and c.parent then savedList=c.parent end end
local savedTile=tileIn(savedList,'First')
savedTile:HandleEvent({Type='MouseEnter'}); savedTile:HandleEvent({Type='MouseExit'})
assert(savedTile.HandleEvent~=nil,'saved profile row supports pointer interaction')
local contextTile=tileIn(frame,'ACU')
contextTile:HandleEvent({Type='ButtonPress'})
contextTile:HandleEvent({Type='MouseEnter'}); contextTile:HandleEvent({Type='MouseExit'})
assert(contextTile.color=='selected' and contextTile.outline=='selectedBorder',
    'selected context tile restores its selected fill and outline after hover')
local unselectedOccupied=tileIn(frame,'Ничего не выделено')
unselectedOccupied:HandleEvent({Type='MouseEnter'}); unselectedOccupied:HandleEvent({Type='MouseExit'})
assert(unselectedOccupied.color=='surface' and unselectedOccupied.outline=='border',
    'unassigned context tile restores its empty fill and normal outline after hover')
local activeAction=tileIn(frame,'Overcharge')
activeAction:HandleEvent({Type='MouseEnter'}); activeAction:HandleEvent({Type='MouseExit'})
assert(activeAction.color=='selected' and activeAction.outline=='selectedBorder',
    'selected action tile restores its selected fill and outline after hover')
assert(activeAction:HandleEvent({Type='UnrelatedEvent'})==false,
    'tile handlers allow unrelated events to continue propagating')
local embedded=control(host)
embedded.scale=1
local beforeEmbedded=#controls
local embeddedFrame=env.Create(host,service,embedded)
openSaved(embeddedFrame)
assert(#configuredEditSizes>=2,'embedded context editor also configures its field after layout')
local closeVisible=false
for i=beforeEmbedded+1,#controls do local c=controls[i]; if c.parent and c.parent.parent==embeddedFrame and c.text=='Закрыть' and not c.parent.hidden then closeVisible=true end end
assert(not closeVisible,'embedded editor does not own section close')
assert(#scrollbarTargets>=1,'catalogs expose native scrollbars')
local hasSavedScroll=false
for _,target in ipairs(scrollbarTargets) do if target.GetScrollValues and target.ScrollSetTop and target.Height()<200 then hasSavedScroll=true end end
assert(not hasSavedScroll,'saved dropdown omits its scrollbar for fewer than ten entries')
-- Empty profile and unselected catalog must expose a non-inverted scrollbar range.
local emptyModel=modelEnv.Create(nil,actions)
local emptyService={contextActions=actions,contextModel=emptyModel}
function emptyService:CommitContext(binding,removeId)
    local candidate=modelEnv.Create(self.contextModel:Export(),actions)
    local ok,message
    if removeId then ok,message=candidate:Delete(removeId) else ok,message=candidate:Put(binding) end
    if not ok then return false,message end
    self.contextModel=candidate
    return true,'Сохранено'
end
local emptyFrame=env.Create(host,emptyService,nil)
openSaved(emptyFrame)
assert(#configuredEditSizes>=3,'empty context editor configures its field after layout')
local emptySaved,emptyCatalog
for _,target in ipairs(scrollbarTargets) do
    if target.GetScrollValues then
        local minimum,maximum,top,bottom=target:GetScrollValues()
        assert(bottom>=top,'scrollbar range must not end before its top')
        if inside(target,emptyFrame) and target.Height()<200 then emptySaved=target end
    end
end
for _,target in ipairs(controls) do
    if not target.destroyed and inside(target,emptyFrame) and target.GetScrollValues and target.Height()>300 then emptyCatalog=target; break end
end
assert(not emptySaved and emptyCatalog,'empty editor hides the saved-list scrollbar and keeps its action panel')
local _,_,catalogTop,catalogBottom=emptyCatalog:GetScrollValues()
assert(catalogTop==1 and catalogBottom==1,'unselected action catalog keeps a valid single-position range')
assert(type(emptyCatalog.IsScrollable)=='function','action catalog exposes native scrollability')
assert(emptyCatalog:IsScrollable()==false,'unselected action catalog is not scrollable')
-- Model the stricter native lifecycle: hiding/showing a panel affects all descendants.
emptyCatalog:Hide(); emptyCatalog:Show()

-- Use the real context catalog while checking selection and action refresh.
local stableService={contextActions=actions,contextModel=emptyModel}
local stableFrame=env.Create(host,stableService,nil)
clickAcu(stableFrame)
local stableSearch
for _,c in ipairs(controls) do if not c.destroyed and c.parent==stableFrame and c.OnTextChanged and c.Width()>400 then stableSearch=c end end
assert(stableSearch,'action search is present')
stableSearch.text='ремонт'; stableSearch:OnTextChanged('ремонт')
local stableRepair=findIn(stableFrame,'Ремонт')
assert(stableRepair and not stableRepair.hidden,
    'selecting ACU refreshes the compatible action catalog')
stableSearch.text=''; stableSearch:OnTextChanged('')
stableFrame:Destroy()

local inheritedOnly=modelEnv.Create(nil,actions)
assert(inheritedOnly:Put({id='parent_only',name='Parent only',rows={{context='builder',action='move'}}}))
local inheritedFrame=env.Create(host,{contextActions=actions,contextModel=inheritedOnly},nil)
clickAcu(inheritedFrame)
local inheritedMode=findIn(inheritedFrame,'● Наследовать')
assert(inheritedMode and inheritedMode.parent and inheritedMode.parent.color=='selected',
    'child mode buttons stay visible and mark the active inherited mode')
inheritedFrame:Destroy()

clickAcu(emptyFrame)
local acuCount=0
for _,action in ipairs(actions.List()) do if not action.hidden and actions.Supports(action.id,'acu') and action.id~='soft_stop' and action.id~='load_transports' then acuCount=acuCount+1 end end
assert(acuCount>9,'ACU has enough compatible actions to exercise scrolling')
local hint,selectedTitle
for _,c in ipairs(controls) do
    if c.parent==emptyFrame and string.find(c.text,'Действий: ',1,true) then hint=c end
    if c.parent==emptyFrame and (c.text=='ACU' or c.text=='acu') then selectedTitle=c end
end
assert(selectedTitle and hint and string.find(hint.text,'Действий: '..acuCount..' ·',1,true),
    'selecting ACU updates the context title and compatible-action count hint: title='..tostring(selectedTitle and selectedTitle.text)..' hint='..tostring(hint and hint.text)..' expected='..tostring(acuCount))
local overcharge
local _,maximumTop=emptyCatalog:GetScrollValues()
for top=1,maximumTop do
    emptyCatalog:ScrollSetTop('y',top)
    overcharge=findIn(emptyFrame,'Overcharge')
    if overcharge and not overcharge.hidden then break end
end
assert(overcharge and not overcharge.hidden,'ACU selection shows the Overcharge action row')
assert(overcharge.parent and not overcharge.parent.hidden,'Overcharge row control is visible')
local overchargeText=findIn(overcharge.parent,'Overcharge')
assert(overchargeText and not overchargeText.hidden,'Overcharge row text is visible')
assert(emptyCatalog:IsScrollable()==true,'ACU catalog reports scrollability when it exceeds the viewport')
local _,_,firstVisible,lastVisible=emptyCatalog:GetScrollValues()
assert(lastVisible-firstVisible+1>0 and lastVisible-firstVisible+1<=14,
    'action catalog reports the number of visible grouped rows')
local catalogScroll
for i,target in ipairs(scrollbarTargets) do if target==emptyCatalog then catalogScroll=scrollbarWidgets[i] end end
assert(catalogScroll and catalogScroll.visible,'scrollbar appears when the action list exceeds the viewport')
local searchField
for _,c in ipairs(controls) do
    if not c.destroyed and c.parent==emptyFrame and c.OnTextChanged and c.Width()>400 then searchField=c end
end
assert(searchField,'action catalog exposes a search field')
searchField.text='overcharge'; searchField:OnTextChanged('overcharge')
local filtered=findIn(emptyFrame,'Overcharge')
assert(filtered and not filtered.hidden,'search keeps a matching action visible')
local filteredRows=0
for _,c in ipairs(controls) do if not c.destroyed and c.parent==emptyCatalog and c.HandleEvent then filteredRows=filteredRows+1 end end
assert(filteredRows==1,'search narrows the catalog to the matching action')
searchField.text=''; searchField:OnTextChanged('')
assert(emptyCatalog:IsScrollable()==true,'clearing search restores the full scrollable catalog')
local oldOvercharge=overcharge.parent
clickIn(emptyFrame,'Завод')
local factoryCount=0
for _,action in ipairs(actions.List()) do if actions.Supports(action.id,'factory') then factoryCount=factoryCount+1 end end
assert(catalogScroll.visible==emptyCatalog:IsScrollable(),
    'scrollbar visibility follows the selected catalog scrollability')
assert(oldOvercharge.destroyed,'switching context destroys stale action row controls')
assert(oldOvercharge.HandleEvent(oldOvercharge,{Type='ButtonPress'})==false,
    'destroyed action row callbacks are ignored')
local newActionRows=0
for _,c in ipairs(controls) do
    if c.parent==emptyCatalog and c.HandleEvent and not c.destroyed then newActionRows=newActionRows+1 end
end
assert(newActionRows>0,'switching context dynamically creates compatible rows')
-- Start with an empty model, create and save a set, then select its dynamically-rendered row.
clickIn(emptyFrame,'Новый')
for _,c in ipairs(controls) do
    if c.parent==emptyFrame and c.OnTextChanged and c.Width()==330 then c.text='Created empty'; c:OnTextChanged('Created empty') end
end
clickAcu(emptyFrame)
clickIn(emptyFrame,'Overcharge')
clickIn(emptyFrame,'Сохранить')
if #emptyService.contextModel:List()~=1 then
    local visible={}
    for _,c in ipairs(controls) do if c.parent==emptyFrame and c.text~='' then visible[#visible+1]=c.text end end
    error('empty profile save commits a record; visible controls: '..table.concat(visible,' | '))
end
local savedRow
for _,c in ipairs(controls) do
    if not c.destroyed and inside(c,emptyFrame) and c.text=='Created empty' then
        local candidate=c
        while candidate and not candidate.HandleEvent do candidate=candidate.parent end
        if candidate then savedRow=candidate end
    end
end
assert(savedRow,'saving into an empty profile immediately creates a clickable saved row')
savedRow:HandleEvent({Type='ButtonPress',Modifiers={}})
local emptyName
for _,c in ipairs(controls) do if c.parent==emptyFrame and c.OnTextChanged and c.Width()==330 then emptyName=c end end
assert(emptyName and emptyName.text=='Created empty','clicking the dynamically-created saved row selects that record')
clickIn(emptyFrame,'Под курсором')
clickIn(emptyFrame,'Улучшить структуру под курсором')
clickIn(emptyFrame,'Сохранить')
local withEmpty=emptyService.contextModel:Get('context_1')
local hasCursor=false
for _,row in ipairs(withEmpty.rows) do if row.context=='cursor' and row.action=='upgrade_structure_under_cursor' then hasCursor=true end end
assert(hasCursor,'selecting and saving a cursor context stores its action')
for _,c in ipairs(controls) do
    assert(c.text~='Следующий добытчик на экране' and c.text~='Следующий добытчик на карте',
        'legacy extractor cycle actions are hidden from the editor')
end
clickIn(emptyFrame,'Под курсором')
clickIn(emptyFrame,'Очистить')
clickIn(emptyFrame,'Сохранить')
local afterClear=emptyService.contextModel:Get('context_1')
hasCursor=false
for _,row in ipairs(afterClear.rows) do if row.context=='cursor' then hasCursor=true end end
assert(not hasCursor,'clear control removes a selected cursor assignment')
local emptyMessage
for _,c in ipairs(controls) do
    if inside(c,emptyCatalog) and c.text=='Для этого контекста нет совместимых действий.' and not c.hidden then emptyMessage=c end
end
assert(not emptyMessage,'nonempty catalog does not show its empty-state message')

local manyModel=modelEnv.Create(nil,actions)
for i=1,10 do
    local ok,message=manyModel:Put({id='saved_scroll_'..i,name='Saved '..i,
        rows={{context='acu',action='move'}}})
    assert(ok,message)
end
local manyService={contextActions=actions,contextModel=manyModel}
local manySaves=0
local lastManyCommit
function manyService:CommitContext(binding,removeId)
    manySaves=manySaves+1
    lastManyCommit=binding
    local candidate=modelEnv.Create(self.contextModel:Export(),actions)
    local ok,message
    if removeId then ok,message=candidate:Delete(removeId) else ok,message=candidate:Put(binding) end
    if not ok then return false,message end
    self.contextModel=candidate
    return true,'Сохранено'
end
local manyFrame=env.Create(host,manyService,nil,{bindingId='saved_scroll_1'})
openSaved(manyFrame)
assert(treeButton(manyFrame,'Строители'),'builder group remains available for child overrides')
-- The catalog lists actions for the selected draft context, so pick one before scanning headings.
clickAcu(manyFrame)
local seenGroups={}
local manyCatalog
for _,c in ipairs(controls) do
    if not c.destroyed and inside(c,manyFrame) and c.ScrollSetTop and c.Width()==520 and c.Height()>300 then manyCatalog=c end
end
assert(manyCatalog)
local _,manyMaxTop=manyCatalog:GetScrollValues()
for top=1,manyMaxTop do
    manyCatalog:ScrollSetTop('Vert',top)
    for _,heading in ipairs({'ACU','Инженеры','Армия','Авиация','Транспорт','Структуры','Приказы'}) do
        for _,c in ipairs(controls) do
            if not c.destroyed and inside(c,manyCatalog) and c.text==heading then seenGroups[heading]=true end
        end
    end
end
local headingCount=0
for _ in pairs(seenGroups) do headingCount=headingCount+1 end
assert(headingCount>=2,'compatible actions use multiple descriptive headings throughout the scrollable catalog')
manyCatalog:ScrollSetTop('Vert',1)
assert(not findIn(manyFrame,'Своё'),'own-mode button is removed from the interface')
for _,label in ipairs({'Отключить','Наследовать'}) do
    local mode=findIn(manyFrame,label)
    assert(mode and not mode.hidden,'child mode button remains visible: '..label)
end
local ownMode=findIn(manyFrame,'СВОЁ')
assert(ownMode and ownMode.parent and ownMode.parent.color=='selected',
    'an existing own-mode assignment remains active without the button')
local inheritChild
for _,c in ipairs(controls) do
    if not c.destroyed and type(c.text)=='string' and c.text:find('Наследовать',1,true)
        and inside(c,manyFrame) and c.parent and c.parent.HandleEvent then
        inheritChild=c.parent; break
    end
end
assert(inheritChild,'child context exposes an inherit mode button')
inheritChild:HandleEvent({Type='ButtonPress',Modifiers={Left=true}})
assert(findIn(manyFrame,'● Наследовать'),'inherit mode button marks the active mode')
assert(findIn(manyFrame,'НАСЛЕДУЕТ'),'reset control sets the selected child to inherit mode')
assert(findIn(manyFrame,'Активно: 0 · переопределено: 0'),
    'resetting the only child override updates the effective and override counts')
clickIn(manyFrame,'Строители')
clickIn(manyFrame,'Сохранить')
assert(manySaves==1,'saving the inherited child reaches the context profile service')
assert(lastManyCommit.rows[1].mode=='inherit','save callback receives the inherited mode draft')
local inherited=manyService.contextModel:Get('saved_scroll_1')
local inheritedMode,parentAction
for _,row in ipairs(inherited.rows) do
    if row.context=='acu' then inheritedMode=row.mode
    elseif row.context=='builder' then parentAction=row.action end
end
local retainedChildAction
for _,row in ipairs(inherited.rows) do if row.context=='acu' then retainedChildAction=row.action end end
assert(inheritedMode=='inherit' and retainedChildAction=='move' and parentAction==nil,
    'saving inherited mode preserves the child action and does not add a parent action')
assert(findIn(manyFrame,'Активно: 0 · переопределено: 0'),
    'saving the reset child preserves the updated active and override counts')
clickAcu(manyFrame)
clickIn(manyFrame,'Отключить')
assert(findIn(manyFrame,'● Отключить'),'disabled mode button marks the selected mode')
assert(findIn(manyFrame,'ОТКЛЮЧЕНО')
    and manyService.contextModel:Get('saved_scroll_1').rows[1].mode=='inherit',
    'disabling the child updates the draft while leaving the stored profile unchanged')
clickIn(manyFrame,'Наследовать')
assert(findIn(manyFrame,'● Наследовать') and findIn(manyFrame,'НАСЛЕДУЕТ'),
    'inherit mode button restores inheritance from the disabled mode')
local manySaved, manyScrollbar
for _,target in ipairs(scrollbarTargets) do
    if target.GetScrollValues and target.Width()==372 and target.Height()>300 and inside(target,manyFrame) then manySaved=target end
end
for _,widget in ipairs(scrollbarWidgets) do
    if widget.visible and inside(widget,manyFrame) then manyScrollbar=widget end
end
assert(manySaved and manySaved:IsScrollable()==true,
    'saved list reports scrollability with more than nine entries')
assert(manyScrollbar,'the saved list shows the native game scrollbar')
local conflictModel=modelEnv.Create(nil,actions)
local conflictService={contextActions=actions,contextModel=conflictModel}
local conflictMessage='В хотбилде «Тяжёлые постройки» есть постройки, а в наборе задано действие для плиток «Строители» и ACU. Очистите плитку «Строители» и плитки ACU или выберите другой набор.'
function conflictService:CommitContext() return false,conflictMessage,{kind='build_context'} end
local conflictFrame=env.Create(host,conflictService,nil)
clickIn(conflictFrame,'Новый')
for _,c in ipairs(controls) do
    if c.parent==conflictFrame and c.OnTextChanged and c.Width()==330 then c.text='Conflict draft'; c:OnTextChanged('Conflict draft') end
end
clickIn(conflictFrame,'Сохранить')
assert(#conflictModel:List()==0,'compatibility rejection does not commit the draft')
local conflictTitle,acknowledge,wrappedLines=nil,nil,{}
for _,c in ipairs(controls) do
    if not c.destroyed and inside(c,conflictFrame) then
        if c.text=='Нельзя совместить' then conflictTitle=c end
        if c.text=='Понятно' then acknowledge=c end
        if c.parent and c.parent.parent==conflictFrame and c.text~='' and c.text~='Нельзя совместить' and c.text~='Понятно' then
            table.insert(wrappedLines,c.text)
        end
    end
end
assert(conflictTitle and acknowledge,'compatibility rejection shows the requested title and single acknowledgement button')
local joined=table.concat(wrappedLines,' ')
assert(string.find(joined,'Тяжёлые постройки',1,true) and string.find(joined,'другой набор.',1,true)
    and #wrappedLines>1,'long compatibility details are fully rendered across separate lines')
acknowledge.parent:HandleEvent({Type='ButtonPress',Modifiers={}})
assert(acknowledge.destroyed and conflictTitle.destroyed,'acknowledgement closes the conflict dialog only')
clickIn(conflictFrame,'Сохранить')
assert(#conflictModel:List()==0 and findIn(conflictFrame,'Нельзя совместить'),
    'draft remains editable and retrying save still detects the conflict')
conflictFrame:Destroy()
local failedModel=modelEnv.Create(nil,actions)
local failedService={contextActions=actions,contextModel=failedModel}
function failedService:CommitContext() return false,'Не удалось сохранить профиль.' end
local failedFrame=env.Create(host,failedService,nil)
clickIn(failedFrame,'Новый')
for _,c in ipairs(controls) do
    if c.parent==failedFrame and c.OnTextChanged and c.Width()==330 then c.text='Ordinary save failure'; c:OnTextChanged('Ordinary save failure') end
end
clickIn(failedFrame,'Сохранить')
assert(find('Не удалось сохранить профиль.') and not find('Нельзя совместить'),
    'ordinary save failures remain status errors and do not use the compatibility modal')
failedFrame:Destroy()
-- Selection actions must leave other contexts available for natural chains.
local policyAction=actions.Get('select_acu_double')
local policyModel=modelEnv.Create({version=2,bindings={{id='policy',name='Policy',rows={{context='empty',action='select_acu_double'}}}}},actions)
local policyFrame=env.Create(host,{contextActions=actions,contextModel=policyModel},nil)
local factoryTile=tileIn(policyFrame,'Завод')
assert(factoryTile and factoryTile.color~='disabled','selection action does not lock factory')
factoryTile:HandleEvent({Type='ButtonPress',Modifiers={Left=true}})
assert(factoryTile.color=='selected','factory remains selectable')
policyFrame:Destroy()
do
local pickerLockModel=modelEnv.Create({version=3,bindings={{id='picker_lock',name='Picker lock',rows={{context='engineer',action='reclaim'}}}}},actions)
local pickerLockFrame=env.Create(host,{contextActions=actions,contextModel=pickerLockModel},nil,{bindingId='picker_lock'})
clickIn(pickerLockFrame,'Ничего не выделено')
local pickerSearch
for _,c in ipairs(controls) do if not c.destroyed and c.parent==pickerLockFrame and c.OnTextChanged and c.Width()>400 then pickerSearch=c end end
assert(pickerSearch,'picker exposes action search for chain conflict test')
pickerSearch:OnTextChanged('Последовательно добавить инженеров T1')
local blockedAction
for _,c in ipairs(controls) do
    if not c.destroyed and inside(c,pickerLockFrame) and type(c.text)=='string' and c.text:find('Последовательно добавить инженеров T1',1,true) then
        local candidate=c
        while candidate and not candidate.HandleEvent do candidate=candidate.parent end
        if candidate then blockedAction=candidate; break end
    end
end
assert(blockedAction and blockedAction.color=='disabled','picker blocks an engineer chain action whose result context is occupied')
assert(blockedAction.tooltip and string.find(blockedAction.tooltip.body(), 'Инженер',1,true),
    'blocked picker action tooltip explains which result context is occupied')
blockedAction:HandleEvent({Type='ButtonPress',Modifiers={Left=true}})
assert(not pickerLockModel:ResolveRow(pickerLockModel:Get('picker_lock'),'empty'),
    'a blocked picker action cannot be assigned by pressing it')
pickerLockFrame:Destroy()
end
local retainedModel=modelEnv.Create({version=2,bindings={{id='absolute_ui',name='Absolute UI',rows={
    {context='empty',action='select_bombers'}, {context='other',action='stop'},
}}}},actions)
local retainedService={contextActions=actions,contextModel=retainedModel}
function retainedService:CommitContext(binding,removeId)
    local candidate=modelEnv.Create(self.contextModel:Export(),actions)
    local ok,message
    if removeId then ok,message=candidate:Delete(removeId) else ok,message=candidate:Put(binding) end
    if not ok then return false,message end
    self.contextModel=candidate
    return true,'Сохранено'
end
local retainedFrame=env.Create(host,retainedService,nil,{bindingId='absolute_ui'})
for _,c in ipairs(controls) do
    assert(c.destroyed or not inside(c,retainedFrame) or c.text~='Абсолютный режим: выкл.', 'absolute switch is absent')
end
clickIn(retainedFrame,'Сохранить')
local retained=retainedService.contextModel:Get('absolute_ui')
assert(#retained.rows==2 and retained.rows[2].context=='other', 'saving preserves rows')
retainedFrame:Destroy()
policyAction.selectionPolicy=savedPolicy
emptyFrame:Destroy()
-- Every group uses its own parent and child modes; the visible catalog is
-- exactly the pool declared by ContextActions.Supports for that column.
local groupModel=modelEnv.Create({version=3,bindings={{id='groups',name='Groups',rows={
    {context='units',action='move'}, {context='builder',action='reclaim'},
    {context='missiles',action='stop'},
}}}},actions)
local groupService={contextActions=actions,contextModel=groupModel}
function groupService:CommitContext(binding)
    local candidate=modelEnv.Create(self.contextModel:Export(),actions)
    local ok,message=candidate:Put(binding)
    if not ok then return false,message end
    self.contextModel=candidate
    return true
end
local groupFrame=env.Create(host,groupService,{scale=0.75},{bindingId='groups'})
local function groupTile(label)
    return assert(treeButton(groupFrame,label),'missing context tree entry '..label)
end
do
local cursor,empty,units,builders,factory,missiles,mex=groupTile('Под курсором'),groupTile('Ничего не выделено'),groupTile('Войска'),groupTile('Строители'),groupTile('Завод'),groupTile('Ракеты'),groupTile('Добытчики')
assert(cursor.y<empty.y and empty.y<units.y and units.y<builders.y and builders.y<factory.y and factory.y<missiles.y and missiles.y<mex.y,
    'groups and other contexts follow priority order in the layout')
local air,navy=groupTile('air'),groupTile('navy')
local previous=air
for _,kind in ipairs({'fighter','bomber','gunship','transport','scout'}) do
    local tile=groupTile(kind)
    assert(tile.y>previous.y and tile.y<navy.y and tile.x>air.x, kind..' is nested under Air in order')
    previous=tile
end
end
local function selectGroupTile(label)
    local tile=groupTile(label)
    assert(not tile.hidden, label..' must be visible: '..tostring(tile.Width())..'x'..tostring(tile.Height())..' parent='..tostring(tile.parent and tile.parent.Width()))
    tile:HandleEvent({Type='ButtonPress',Modifiers={Left=true}})
end
for parent,children in pairs({
    units={'land','air','navy'},
    air={'fighter','bomber','gunship','transport','scout'},
    builder={'acu','sacu','engineer'},
    missiles={'silo_tactical','silo_nuclear'},
}) do
    for attempt=1,3 do
        for _,child in ipairs(children) do
            local tile=groupTile(child)
            assert(not tile.hidden and tile.y+tile.Height()<=tile.parent.Height(),
                child..' stays visible inside the tree')
        end
        if attempt<3 then selectGroupTile(parent) end
    end
end
local function assertCatalog(context)
    local expected=0
    local function obsolete(id)
        return id=='load_transports' or id=='mode' or id=='dock' or id=='set_default_target_priority' or id=='nuke' or id=='tactical'
            or id=='upgrade_structure'
            or ((id=='upgrade_structure_under_cursor' or id=='upgrade_structure_pause' or id=='upgrade_mex_select_next') and context~='cursor')
            or (id=='sacu_tech' and context=='sacu') or (id=='soft_stop' and context~='factory')
            or ((id=='attack' or id=='attack_move') and context=='transport')
            or (id=='transport_order' and context=='other') or (id=='shield' and context=='factory')
    end
    for _,action in ipairs(actions.List()) do if (not action.hidden or action.compositeOnly) and actions.Supports(action.id,context) and not obsolete(action.id) then expected=expected+1 end end
    local hint=findIn(groupFrame,'Действий: '..expected..' · колесо мыши прокручивает список')
    assert(hint,context..' catalog count must match applicability')
    local catalog
    catalog=catalogIn(groupFrame)
    for top=1,math.max(1,expected) do
        local firstNew=#controls+1
        catalog:ScrollSetTop('y',top)
        for index=firstNew,#controls do
            local c=controls[index]
            if not c.destroyed and c.parent and c.parent.parent==catalog and type(c.text)=='string' then
                local match,supportedMatch
                for _,action in ipairs(actions.List()) do
                    if c.text:find(action.label,1,true) then
                        if actions.Supports(action.id,context) and not obsolete(action.id) then supportedMatch=action end
                        if not match or #action.label>#match.label then match=action end
                    end
                end
                if match then assert(supportedMatch,match.id..' must not appear for '..context) end
            end
        end
    end
    catalog:ScrollSetTop('y',1)
end
selectGroupTile('Войска'); assertCatalog('units')
assert(not findIn(groupFrame,'Переключить сушу / флот / авиацию в выделении'),
    'retired cycle-unit-types command is absent from the context action catalog')
for _,entry in ipairs({{'Наземные','land'},{'Авиация','air'},{'Флот','navy'},
    {'Истребители','fighter'},{'Бомбардировщики','bomber'},{'Штурмовики','gunship'}}) do
    selectGroupTile(entry[1]); assertCatalog(entry[2])
end
selectGroupTile('Наземные'); clickIn(groupFrame,'Атака по площади'); clickIn(groupFrame,'Сохранить')
assert(groupService.contextModel:ResolveAction('groups','land')=='attack' and groupService.contextModel:ResolveAction('groups','air')=='move',
    'land override leaves air inheriting units: land='..tostring(groupService.contextModel:ResolveAction('groups','land'))..' air='..tostring(groupService.contextModel:ResolveAction('groups','air')))
selectGroupTile('Наземные'); clickIn(groupFrame,'Отключить'); clickIn(groupFrame,'Сохранить')
assert(groupService.contextModel:ResolveAction('groups','land')==nil,'land can be disabled')
selectGroupTile('Наземные'); clickIn(groupFrame,'Наследовать'); clickIn(groupFrame,'Сохранить')
assert(groupService.contextModel:ResolveAction('groups','land')=='move','land can return to inheritance')
selectGroupTile('Ракеты'); assertCatalog('missiles')
selectGroupTile('ТМЛ'); assertCatalog('silo_tactical')
assert(not findIn(groupFrame,'Запуск тактической ракеты'),'legacy tactical launch is hidden from the picker')
clickIn(groupFrame,'Сохранить')
assert(groupService.contextModel:ResolveAction('groups','silo_tactical')=='stop' and groupService.contextModel:ResolveAction('groups','silo_nuclear')=='stop',
    'legacy tactical launch remains absent while TML inherits missiles')
selectGroupTile('ТМЛ'); clickIn(groupFrame,'Отключить'); clickIn(groupFrame,'Сохранить')
assert(groupService.contextModel:ResolveAction('groups','silo_tactical')==nil,'TML can be disabled')
selectGroupTile('ТМЛ'); clickIn(groupFrame,'Наследовать'); clickIn(groupFrame,'Сохранить')
assert(groupService.contextModel:ResolveAction('groups','silo_tactical')=='stop','TML can return to inheritance')
selectGroupTile('Ядерка'); assertCatalog('silo_nuclear')
selectGroupTile('Строители'); assertCatalog('builder')
for _,entry in ipairs({{'ACU','acu'},{'SACU','sacu'},{'Инженер','engineer'},
    {'Завод','factory'},{'Транспорт','transport'},{'Добытчики','mex'},
    {'Разведчики','scout'},{'Остальные','other'},{'Ничего не выделено','empty'},{'Под курсором','cursor'}}) do
    selectGroupTile(entry[1]); assertCatalog(entry[2])
end
selectGroupTile('Под курсором')
for _,id in ipairs({'upgrade_structure_under_cursor','upgrade_structure_pause','upgrade_mex_select_next'}) do
    assert(actions.Supports(id,'cursor'),id..' is supported by the cursor tile')
end
assert(findIn(groupFrame,'Улучшение с паузой'), 'cursor upgrade uses the new localized action name')
selectGroupTile('Ничего не выделено')
assert(not findIn(groupFrame,'Погрузить в транспорт'),
    'load into transports is unavailable in multifunction actions')
assert(not findIn(groupFrame,'Улучшить добытчик и выбрать ближайший следующий'),
    'new select-next assignments are offered only under the cursor')
assert(not findIn(groupFrame,'Улучшить структуру под курсором'),
    'cursor-only upgrade action is absent from the empty-selection catalog')
local selectionOverrideOption=assert(findIn(groupFrame,'Сбрасывать выделение')).parent
assert(not selectionOverrideOption.settingEnabled)
selectionOverrideOption:HandleEvent({Type='ButtonPress',Modifiers={Left=true}})
clickIn(groupFrame,'Сохранить')
assert(selectionOverrideOption.settingEnabled and groupService.contextModel:Get('groups').selectionOverride==true)
selectionOverrideOption:HandleEvent({Type='ButtonPress',Modifiers={Left=true}})
clickIn(groupFrame,'Сохранить')
assert(not selectionOverrideOption.settingEnabled and not groupService.contextModel:Get('groups').selectionOverride)
groupFrame:Destroy()
local lockModel=modelEnv.Create({version=3,bindings={{id='lockctx',name='Locked',rows={}}}},actions)
local lockPreset={id='lockpreset',name='Building preset',key='K',grid={context='lockctx'},entries={{kind='blueprint',id='structure'}}}
local lockService={contextActions=actions,contextModel=lockModel,model={List=function() return {lockPreset} end}}
function lockService:Catalog() return {Get=function(_,id) return {kind='STRUCTURE',blueprint={CategoriesHash={STRUCTURE=true}}} end} end
local lockFrame=env.Create(host,lockService,nil)
clickIn(lockFrame,'Строители')
local lockedLabel=false
for _,c in ipairs(controls) do
    if not c.destroyed and inside(c,lockFrame) and type(c.text)=='string' and c.text:find('занято хотбилдом зданий',1,true) then lockedLabel=true end
end
assert(not lockedLabel,'building presets do not lock the context editor')
clickAcu(lockFrame)
local lockedAcu=false
for _,c in ipairs(controls) do
    if not c.destroyed and inside(c,lockFrame) and type(c.text)=='string' and c.text:find('занято хотбилдом зданий',1,true) then lockedAcu=true end
end
local lockOvercharge
for _,panel in ipairs(controls) do
    if not panel.destroyed and inside(panel,lockFrame) and panel.Height()>300
        and panel.GetScrollValues and panel.ScrollSetTop then
        local _,maximum=panel:GetScrollValues()
        for top=1,maximum do
            panel:ScrollSetTop('y',top)
            lockOvercharge=findIn(lockFrame,'Overcharge')
            if lockOvercharge and not lockOvercharge.hidden then break end
        end
        if lockOvercharge and not lockOvercharge.hidden then break end
    end
end
assert(not lockedAcu and lockOvercharge and not lockOvercharge.hidden,
    'ACU actions remain available in the context editor')
lockFrame:Destroy()
local suicidePicker=env.Create(host,{contextActions=actions,contextModel=modelEnv.Create(nil,actions)},nil)
clickIn(suicidePicker,'Войска'); clickIn(suicidePicker,'Наземные')
local suicideSearch
for _,c in ipairs(controls) do if not c.destroyed and c.parent==suicidePicker and c.OnTextChanged and c.Width()>400 then suicideSearch=c end end
assert(suicideSearch,'action picker search exists for suicide filtering')
suicideSearch:OnTextChanged('Самоуничтожение')
local delayedSuicideVisible=false
for _,c in ipairs(controls) do
    if not c.destroyed and inside(c,suicidePicker) and c.text=='Самоуничтожение' then delayedSuicideVisible=true end
end
assert(not delayedSuicideVisible,
    'delayed suicide is absent from the composite action picker')
suicideSearch:OnTextChanged('мгновенно')
assert(findIn(suicidePicker,'Самоуничтожение мгновенно'),
    'composite picker exposes the immediate composite-only action')
suicidePicker:Destroy()
local continuationCases={
    {'select_acu','acu',false}, {'select_acu_double','acu',false}, {'goto_acu','acu',false},
    {'select_transport_double','transport',false}, {'select_engineers_t1','engineer',true},
    {'select_engineers_t2','engineer',true}, {'select_engineers_t3','engineer',true},
    {'select_engineers_all','engineer',true},
    {'select_engineer','engineer',false}, {'select_transport','transport',false},
}
assert(not actions.Get('kill_selected_units').hidden and not actions.Get('kill_selected_units').compositeOnly,
    'instant unit destruction follows the current action catalog visibility')
for index,case in ipairs(continuationCases) do
    local actionId,targetId,shouldLock=case[1],case[2],case[3]
    local m=modelEnv.Create({version=3,bindings={{id='continuation_'..index,name=actionId,
        rows={{context='empty',action=actionId}}}}},actions)
    local fixture=m:Get('continuation_'..index)
    assert(fixture and fixture.rows[1].context=='empty' and fixture.rows[1].action==actionId,
        'continuation lock fixture is preserved: '..actionId)
    local svc={contextActions=actions,contextModel=m}
    local f=env.Create(host,svc,nil,{bindingId='continuation_'..index})
    local target=assert(treeButton(f,targetId),'continuation target exists: '..targetId)
    local lockHint=findIn(target,'занято цепочкой')
    local treeText={}
    for _,c in ipairs(controls) do if not c.destroyed and inside(c,target) and type(c.text)=='string' and c.text~='' then treeText[#treeText+1]=c.text end end
    assert((target.color=='disabled' and lockHint~=nil)==shouldLock,
        actionId..' continuation lock state for '..targetId..' color='..tostring(target.color)..' hint='..tostring(lockHint and lockHint.text)..' tile='..table.concat(treeText,'|'))
    f:Destroy()
end
-- A conflicting saved row remains in the draft and can be repaired explicitly.
local savedConflict=modelEnv.Create({version=3,bindings={{id='saved_conflict',name='Saved conflict',rows={
    {context='empty',action='select_acu_double'}, {context='acu',action='move'},
}}}},actions)
local savedConflictService={contextActions=actions,contextModel=savedConflict}
function savedConflictService:CommitContext(binding)
    local candidate=modelEnv.Create(self.contextModel:Export(),actions)
    local ok,message=candidate:Put(binding)
    if not ok then return false,message end
    self.contextModel=candidate
    return true,'Сохранено'
end
local savedConflictFrame=env.Create(host,savedConflictService,nil,{bindingId='saved_conflict'})
assert(savedConflictService.contextModel:ResolveAction('saved_conflict','acu')=='move',
    'loading a saved continuation conflict preserves the assigned child row')
local conflictingAcu=assert(treeButton(savedConflictFrame,'acu'))
clickIn(savedConflictFrame,'ACU')
assert(not findIn(savedConflictFrame,'занято цепочкой'),'retired ACU double no longer reserves the context')
clickIn(savedConflictFrame,'Очистить')
clickIn(savedConflictFrame,'Сохранить')
local repairedConflict=savedConflictService.contextModel:Get('saved_conflict')
local emptyContinuationPreserved=false
for _,row in ipairs(repairedConflict.rows) do
    if row.context=='empty' and row.action=='select_acu_double' then emptyContinuationPreserved=true end
end
assert(savedConflictService.contextModel:ResolveAction('saved_conflict','acu')==nil and emptyContinuationPreserved,
    'saved conflict can be repaired while preserving the built-in continuation')
savedConflictFrame:Destroy()
-- A locked inherited child also blocks assigning an action to its group.
local inheritedConflict=modelEnv.Create({version=3,bindings={{id='inherited_conflict',name='Inherited conflict',rows={{context='empty',action='select_acu_double'}}}}},actions)
local inheritedConflictFrame=env.Create(host,{contextActions=actions,contextModel=inheritedConflict},nil,{bindingId='inherited_conflict'})
clickIn(inheritedConflictFrame,'Строители')
clickIn(inheritedConflictFrame,'Движение')
assert(not findIn(inheritedConflictFrame,'сначала измените цепочку'),
    'a reserved ACU child does not block the parent action')
inheritedConflictFrame:Destroy()
do
    local engineerChain=modelEnv.Create({version=3,bindings={{id='engineer_parent',name='Engineer parent',
        rows={{context='empty',action='select_engineers_t3'}}}}},actions)
    local svc={contextActions=actions,contextModel=engineerChain,CommitContext=savedConflictService.CommitContext}
    local frame=env.Create(host,svc,nil,{bindingId='engineer_parent'})
    clickIn(frame,'Строители')
    clickIn(frame,'Движение')
    clickIn(frame,'Сохранить')
    assert(svc.contextModel:ResolveAction('engineer_parent','acu')=='move'
        and svc.contextModel:ResolveAction('engineer_parent','sacu')=='move'
        and svc.contextModel:ResolveAction('engineer_parent','engineer')==nil,
        'the chain locks the engineer without blocking a parent action')
    frame:Destroy()
end
local legacyModel=modelEnv.Create({version=3,bindings={{id='legacy',name='Legacy',rows={
    {context='transport',action='attack'}, {context='factory',action='shield'},
    {context='sacu',action='sacu_tech',mode='own'}, {context='mystery',action='missing_action'},
    {context='land',action='suicide'},
}}}},actions)
local legacyService={contextActions=actions,contextModel=legacyModel}
function legacyService:CommitContext(binding)
    local ok,err=self.contextModel:Put(binding); return ok,err or 'Сохранено'
end
local legacyFrame=env.Create(host,legacyService,nil,{bindingId='legacy'})
assert(findIn(legacyFrame,'устарело: Самоунич'),
    'saved delayed-suicide assignment is shown as obsolete')
clickIn(legacyFrame,'Сохранить')
local savedLegacy=legacyService.contextModel:Get('legacy')
assert(savedLegacy.rows[1].action=='attack' and savedLegacy.rows[4].action=='missing_action'
    and savedLegacy.rows[5].action=='suicide', 'saving retains obsolete assignments')
clickIn(legacyFrame,'Войска'); clickIn(legacyFrame,'Наземные')
local legacySearch
for _,c in ipairs(controls) do if not c.destroyed and c.parent==legacyFrame and c.OnEscPressed then legacySearch=c end end
assert(legacySearch,'legacy replacement search is available')
legacySearch:OnTextChanged('мгновенно')
clickIn(legacyFrame,'Самоуничтожение мгновенно'); clickIn(legacyFrame,'Сохранить')
assert(legacyService.contextModel:Get('legacy').rows[5].action=='kill_selected_units',
    'saved delayed self-destruct can be replaced with the instant action')
legacyFrame:Destroy()
local extraLegacyModel=modelEnv.Create({version=3,bindings={{id='old_extra_fields',name='Old extra fields',rows={{
    context='transport',action='select_transport_double',quickRepeat='attack',fallback='attack_move'
}}}}},actions)
local extraLegacyService={contextActions=actions,contextModel=extraLegacyModel}
function extraLegacyService:CommitContext(binding)
    local ok,err=self.contextModel:Put(binding); return ok,err or 'Сохранено'
end
local extraLegacyFrame=env.Create(host,extraLegacyService,nil,{bindingId='old_extra_fields'})
clickIn(extraLegacyFrame,'Сохранить')
local retainedExtra=extraLegacyService.contextModel:Get('old_extra_fields')
assert(retainedExtra.rows[1].quickRepeat=='attack' and retainedExtra.rows[1].fallback=='attack_move', 'saving retains legacy repeat and fallback')
extraLegacyFrame:Destroy()

local commandGroupModel=modelEnv.Create({version=3,bindings={{id='command_group',name='Command group',rows={{context='land',action='move'}}}}},actions)
local commandGroupService={contextActions=actions,contextModel=commandGroupModel}
local commandGroupFrame=env.Create(host,commandGroupService,nil)
clickIn(commandGroupFrame,'Войска')
clickIn(commandGroupFrame,'Наземные')
local modeSearch
for _,c in ipairs(controls) do
    if not c.destroyed and c.parent==commandGroupFrame and c.OnEscPressed then modeSearch=c end
end
assert(modeSearch,'catalog has search')
modeSearch:OnTextChanged('Режим огня')
assert(not findIn(commandGroupFrame,'Режим огня'),'obsolete fire mode is absent from the picker')
modeSearch:OnTextChanged('Приоритет целей')
assert(findIn(commandGroupFrame,'Приоритет целей') and findIn(commandGroupFrame,'Армия'),
    'compatible native command remains under the Army group header')
commandGroupFrame:Destroy()
local function offerScenario(rows,answer)
    local m=modelEnv.Create({version=3,bindings={{id='offer',name='Offer',rows=rows}}},actions)
    local svc={contextActions=actions,contextModel=m}
    function svc:CommitContext(binding) local ok,err=self.contextModel:Put(binding); return ok,err end
    local f=env.Create(host,svc,nil,{bindingId='offer'})
    clickAcu(f); clickIn(f,'Overcharge')
    if answer then
        assert(findIn(f,'Поставить то же для SACU?'), 'offer appears when no SACU override exists')
        clickIn(f,answer)
    else assert(not findIn(f,'Поставить то же для SACU?'), 'existing SACU override is preserved without prompting') end
    clickIn(f,'Сохранить')
    local result=svc.contextModel:Get('offer'); f:Destroy(); return result
end
local declined=offerScenario({},'Нет')
assert(#declined.rows==1 and declined.rows[1].context=='acu', 'declining does not create SACU row')
local accepted=offerScenario({},'Да')
assert(#accepted.rows==2 and accepted.rows[2].context=='sacu' and accepted.rows[2].action=='overcharge', 'accepting creates SACU override')
local overridden=offerScenario({{context='sacu',mode='own',action='move'}},nil)
assert(overridden.rows[1].action=='move', 'existing SACU action remains unchanged')
local disabled=offerScenario({{context='sacu',mode='disabled'}},nil)
assert(disabled.rows[1].mode=='disabled', 'disabled SACU override remains unchanged')
do
local function missileOffer(existingRows,choose)
    local m=modelEnv.Create({version=3,bindings={{id='missile_offer',name='Missile offer',rows=existingRows or {}}}},actions)
    local svc={contextActions=actions,contextModel=m}
    function svc:CommitContext(binding)
        local candidate=modelEnv.Create(self.contextModel:Export(),actions)
        local ok,err=candidate:Put(binding)
        if not ok then return false,err end
        self.contextModel=candidate; return true,'Сохранено'
    end
    local f=env.Create(host,svc,nil,{bindingId='missile_offer'})
    clickIn(f,'Ракеты')
    clickIn(f,'Запуск ракеты')
    assert(findIn(f,'Предложить запуск ракеты для ACU/SACU?'),'smart missile assignment offers ACU/SACU separately')
    local acuButton,sacuButton
    local acuDisabled=findIn(f,'ACU: отключено')
    for _,c in ipairs(controls) do
        if not c.destroyed and inside(c,f) and c.text=='Назначить ACU' then acuButton=c end
        if not c.destroyed and inside(c,f) and c.text=='Назначить SACU' then sacuButton=c end
    end
    if choose then for _,context in ipairs(choose) do clickIn(f,'Назначить '..string.upper(context)) end end
    clickIn(f,'Готово')
    clickIn(f,'Сохранить')
    local result=svc.contextModel:Get('missile_offer'); f:Destroy(); return result,acuButton~=nil,sacuButton~=nil,acuDisabled~=nil
end
local bothMissileTargets=missileOffer({}, {'acu','sacu'})
local missileTargetActions={}
for _,row in ipairs(bothMissileTargets.rows) do missileTargetActions[row.context]=row.action end
assert(missileTargetActions.missiles=='smart_missile' and missileTargetActions.acu=='smart_missile' and missileTargetActions.sacu=='smart_missile',
    'both independent smart-missile target choices can be selected')
local preservedMissileTarget=missileOffer({{context='sacu',mode='own',action='move'}},{'acu'})
local preservedActions={}
for _,row in ipairs(preservedMissileTarget.rows) do preservedActions[row.context]=row.action end
assert(preservedActions.acu=='smart_missile' and preservedActions.sacu=='move',
    'missile offer assigns the free ACU and preserves an occupied SACU')
local disabledMissileTarget,disabledAcuOffer,disabledSacuOffer,disabledAcuStatus=missileOffer({{context='acu',mode='disabled'}},{})
assert(not disabledAcuOffer and disabledSacuOffer and disabledAcuStatus,'disabled ACU is shown as disabled and is not offered')
local disabledTargetRow
for _,row in ipairs(disabledMissileTarget.rows) do if row.context=='acu' then disabledTargetRow=row end end
assert(disabledTargetRow and disabledTargetRow.mode=='disabled' and disabledTargetRow.action==nil,
    'missile offer preserves an explicitly disabled ACU row')
assert((function()
    local result,offered=missileOffer({{context='acu',mode='inherit'}},{'acu'})
    for _,row in ipairs(result.rows) do if row.context=='acu' then return offered and row.action=='smart_missile' end end
    return false
end)(),'an empty inherited row is offered for assignment')
local inheritedMissileTarget,inheritedAcuOffer=missileOffer({{context='acu',mode='inherit',action='reclaim'}},{})
assert(not inheritedAcuOffer,'inherited historical ACU row is not offered for replacement')
local inheritedTargetRow
for _,row in ipairs(inheritedMissileTarget.rows) do if row.context=='acu' then inheritedTargetRow=row end end
assert(inheritedTargetRow and inheritedTargetRow.mode=='inherit' and inheritedTargetRow.action=='reclaim',
    'missile offer preserves historical action data in an inherited row')
local skippedMissileTarget=missileOffer({}, {})
assert(#skippedMissileTarget.rows==1 and skippedMissileTarget.rows[1].context=='missiles',
    'missile offer can be declined for both unit contexts')
end
-- LuaPlus has a 32-upvalue limit; inspect the closures exercised by this UI
-- scenario as an early warning, alongside (not instead of) a FAF load test.
local visited={}
local function checkUpvalues(fn)
    if type(fn)~='function' or visited[fn] then return end
    visited[fn]=true
    local count=0
    while true do
        local name,value=debug.getupvalue(fn,count+1)
        if not name then break end
        count=count+1
        if type(value)=='function' then checkUpvalues(value) end
    end
    assert(count<=32,'editor closure exceeds 32 captured values: '..count)
end
checkUpvalues(env.Create)
for _,control in ipairs(controls) do
    for _,value in pairs(control) do if type(value)=='function' then checkUpvalues(value) end end
end
print('PASS: context editor layout, catalog visibility/count/scrollability, policy conflicts/repair, real model save/replace/switch, dirty deletion guard and embedded close ownership')
