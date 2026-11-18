-- Keyboard editor UI interactions with mocked Maui controls; not a FAF rendering test.
local testLocalization = dofile('Tests/localization-test-helper.lua')
table.getn = function(t) return #t end
local controls, escapeHandlers, tooltips = {}, {}, {}
local tooltipDestroys = 0
local heldKeys={}
local function variable(value)
    return setmetatable({value=value,Set=function(self,v) self.value=v end},{__call=function(self)
        return type(self.value)=='function' and self.value() or self.value
    end})
end
local function control(parent,text)
    local c={parent=parent,text=text,visible=true,Width=variable(0),Height=variable(0),
        Depth=variable(parent and parent.Depth()+1 or 0)}
    function c:SetText(v) self.text=v end
    function c:GetStringAdvance(v) return utf8.len(v)*7 end
    function c:SetColor(v) self.textColor=v end
    function c:SetNeedsFrameUpdate(v) self.needsFrameUpdate=v end
    function c:SetSolidColor(v) self.color=v end
    function c:SetTexture(v) self.texture=v end
    function c:DisableHitTest() self.hitTestDisabled=true end
    function c:Show()
        self.visible=true
        for _,child in ipairs(controls) do if child.parent==self then child:Show() end end
    end
    function c:Hide()
        self.visible=false
        for _,child in ipairs(controls) do if child.parent==self then child:Hide() end end
    end
    function c:Destroy() self.destroyed=true; if self.OnDestroy then self:OnDestroy() end end
    function c:OnDestroy() end
    controls[#controls+1]=c
    return c
end
local function layout(c)
    local l={}
    function l:Width(v) c.Width:Set(v); return self end
    function l:Height(v) c.Height:Set(v); return self end
    function l:AtLeftTopIn(parent,x,y) c.x=x; c.y=y; return self end
    function l:AtCenterIn(parent,top) c.centered=true; c.centerOffset=top or 0; return self end
    return l
end
local modules={
    ['/lua/maui/group.lua']={Group=control},
    ['/lua/maui/bitmap.lua']={Bitmap=control},
    ['/lua/maui/edit.lua']={Edit=function(parent) local c=control(parent); function c:GetText() return self.text or '' end; return c end},
    ['/lua/maui/layouthelpers.lua']={GetPixelScaleFactor=function() return 1 end},
    ['/lua/ui/game/tooltip.lua']={
        AddAutoUpdatedControlTooltip=function(c,title,detail) tooltips[c]={title=title,detail=detail} end,
        DestroyMouseoverDisplay=function() tooltipDestroys=tooltipDestroys+1 end,
    },
    ['/lua/ui/dialogs/eschandler.lua']={
        PushEscapeHandler=function(fn) escapeHandlers[#escapeHandlers+1]=fn end,
        PopEscapeHandler=function() table.remove(escapeHandlers) end,
    },
    ['/lua/ui/uiutil.lua']={bodyFont='Arial',CreateText=control,SetupEditStd=function() end,
        CreateVertScrollbarFor=function(panel)
            assert(panel.GetScrollValues and panel.ScrollSetTop and panel.ScrollLines and panel.ScrollPages)
            panel:GetScrollValues(); return control(panel)
        end},
}
local theme=setmetatable({},{__index=_G})
theme.import=function(path) return assert(modules[path],path) end
assert(loadfile('../mods/ClaretCore/modules/Theme.lua','t',theme))()
modules['/mods/ClaretCore/modules/Theme.lua']=theme
local env=setmetatable({LOG=function() end,IsKeyDown=function(key) return heldKeys[key] or false end, ReUI={ClaretCore={Localization=testLocalization},UI={FloorLayouter=function() return function(c) return layout(c) end end}},
    import=function(path) return assert(modules[path],path) end},{__index=_G})
local editorModule=setmetatable({},{__index=env})
assert(loadfile('../mods/ClaretHotbuild/modules/KeyboardEditor.lua','t',editorModule))()

local assignments={
    {key='PageUp',modifiers={ctrl=true,shift=true},label='Preset Existing',context={'Engineer','ACU'},ref={kind='preset',id='existing'}},
    {key='PageUp',modifiers={},label='Foreign binding',foreign=true,ref={kind='foreign',id='OtherAction'}},
    {key='F1',modifiers={},label='Foreign only with a deliberately long binding name that must remain fully visible in the custom tooltip' ,foreign=true,ref={kind='foreign',id='ForeignOnly'}},
    {key='Q',modifiers={ctrl=true},label='Ctrl binding',ref={kind='action',id='action'}},
    {key='F3',modifiers={},label='Foreign only',foreign=true,ref={kind='foreign',id='another'}},
    {key='F2',modifiers={},label='Foreign',foreign=true,ref={kind='foreign',id='other'}},
    {key='F2',modifiers={},label='Claret',ref={kind='action',id='action'}},
    {key='W',modifiers={},label='Second binding',ref={kind='action',id='action'}},
    {key='Q',modifiers={},label='Claret binding',ref={kind='action',id='action'}},
    {key='B',modifiers={},label='Building · Composite',presetLabel='Building',linkedLabel='Composite',linkedRef={kind='composite',id='comp'},ref={kind='preset',id='existing'}},
}
local calls={sets={},clears={},validates={},chords={}}
local choices={
    presets={{ref={kind='preset',id='fresh'},label='Preset Fresh'},{ref={kind='preset',id='blocked'},label='Blocked Choice'},{ref={kind='preset',id='link'},label='Link Choice'}},
    composites={{ref={kind='composite',id='comp'},label='Composite Choice'}},
    actions={{ref={kind='action',id='action'},label='Select Engineer',context={'Engineer'},description='Select nearby engineers'}},
}
local service={}
function service:GetAssignments() return assignments end
function service:GetChoices() return choices end
function service:GetDoubleChoices(id) return id=='action' and {{id='all_same',label='Все такие юниты'}} or {} end
function service:GetDoubleForKey() return self.double end
function service:SetDoubleForKey(key,mods,first,second) self.double={first=first,second=second,key=key}; return true end
function service:ClearDoubleForKey() self.double=nil; return true end
function service:Validate(ref,key,mods)
    calls.validates[#calls.validates+1]={ref=ref,key=key,mods=mods}
    if ref.id=='blocked' then return false,'Чужое сочетание занято.',{kind='conflict',id='foreign'} end
    if ref.id=='link' then return false,'Связать назначения?',{kind='link',id='composite-occupant'} end
    return true
end
function service:Set(ref,key,mods,confirmed)
    calls.sets[#calls.sets+1]={ref=ref,key=key,mods=mods,confirmed=confirmed}
    table.insert(assignments,{key=key,modifiers=mods,ref=ref,label='Saved '..ref.id})
    return true,'Назначение сохранено.'
end
function service:ClearChord(key,mods)
    calls.chords[#calls.chords+1]={key=key,mods=mods}
    if self.failChord then return false,'Ошибка снятия.' end
    for i=#assignments,1,-1 do
        local a=assignments[i]
        if a.key==key and (a.modifiers.ctrl==true)==(mods.ctrl==true)
            and (a.modifiers.shift==true)==(mods.shift==true) and (a.modifiers.alt==true)==(mods.alt==true) then
            table.remove(assignments,i)
        end
    end
    return true
end
function service:Clear(ref,key,mods)
    calls.clears[#calls.clears+1]={ref=ref,key=key,mods=mods}
    if self.failClear then return false,'Симулированная ошибка очистки.' end
    for i=#assignments,1,-1 do
        local a=assignments[i]
        if a.key==key and (a.modifiers.ctrl==true)==(mods.ctrl==true)
            and (a.modifiers.shift==true)==(mods.shift==true) and (a.modifiers.alt==true)==(mods.alt==true) then
            if a.linkedRef==ref then a.linkedRef=nil; a.linkedLabel=nil
            elseif a.ref==ref then table.remove(assignments,i) end
        end
    end
    return true,'Назначение снято.'
end

local parent=control(nil)
parent.Width:Set(1080); parent.Height:Set(1050)
local requestedHeight
local frame=editorModule.Create(parent,service,{scale=0.75,setHeight=function(height) requestedHeight=height end})
assert(frame and frame.Width()==1080 and frame.Height()==920 and frame.x==0 and frame.y==0,
    'embedded editor returns a frame fitted to the inline host at requested scale')
assert(theme.Colors.keyCombo0=='ff7f8794' and theme.Colors.keyCombo1=='ff64b5f6'
    and theme.Colors.keyCombo2=='ffc792ea' and theme.Colors.keyCombo3=='ff4db6ac'
    and theme.Colors.keyCombo4=='ffffba66' and theme.Colors.keyCombo5=='ffff7785'
    and theme.Colors.keyCombo6=='ff9ccc65' and theme.Colors.keyCombo7=='ff7986cb',
    'modifier legend tokens use canonical bit order')

local function findText(value)
    for _,c in ipairs(controls) do
        local node=c; local alive=true
        while node do if node.destroyed or not node.visible then alive=false; break end; node=node.parent end
        if alive and c.text==value then return c end
    end
end
local function hasOutlineColor(control,color)
    for _,child in ipairs(controls) do if child.parent==control and child.color==color then return true end end
    return false
end
local function clickText(value)
    local text=findText(value); assert(text,'missing visible text: '..value)
    assert(text.parent and text.parent.HandleEvent,'text has no clickable control: '..value)
    text.parent:HandleEvent({Type='ButtonPress',Modifiers={Left=true}})
    return text.parent
end
local function clickButtonAtY(value,y)
    for _,c in ipairs(controls) do
        local node=c; local alive=true
        while node do if node.destroyed then alive=false; break end; node=node.parent end
        if alive and c.text==value and c.parent and c.parent.y==y and c.parent.HandleEvent then
            c.parent:HandleEvent({Type='ButtonPress',Modifiers={Left=true}})
            return c.parent
        end
    end
    assert(false,'missing button '..value..' at y='..y)
end
local function findKey(title)
    local label=findText(title)
    return label and label.parent and label.parent.HandleEvent and label.parent
end
local function pressKey(title)
    local key=findKey(title); assert(key,'missing key cell: '..title)
    key:HandleEvent({Type='ButtonPress',Modifiers={Left=true}})
    return key
end
local q=findKey('Q'); assert(q and q.color==theme.Colors.accent)
service.failChord=true; q:HandleEvent({Type='ButtonPress',Modifiers={Right=true}})
assert(q.color==theme.Colors.accent and findText('Ошибка снятия.'),'failed right-click preserves the key')
service.failChord=false; q:HandleEvent({Type='ButtonPress',Modifiers={Right=true}})
assert(q.color==theme.Colors.raised and calls.chords[#calls.chords].key=='Q','right-click clears the Claret chord')
findKey('W'):HandleEvent({Type='ButtonPress',Modifiers={Right=true}})
assert(calls.chords[#calls.chords].key=='W' and findKey('W').color==theme.Colors.raised, 'a second key can be cleared without reopening the editor')
local mixed=findKey('F2'); mixed:HandleEvent({Type='ButtonPress',Modifiers={Right=true}})
assert(mixed.color==theme.Colors.raised and calls.chords[#calls.chords].key=='F2','right-click clears both Claret and foreign assignments for the chord')
local foreignOnlyKey=findKey('F3'); foreignOnlyKey:HandleEvent({Type='ButtonPress',Modifiers={Right=true}})
assert(foreignOnlyKey.color==theme.Colors.raised and calls.chords[#calls.chords].key=='F3','right-click clears a foreign-only assignment')
assert(requestedHeight==570, 'collapsed keyboard requests compact panel height')
assert(not findText('Сочетание для назначения:') and not findKey('Num7'), 'modifier bar is removed and numpad starts collapsed')
for _,c in ipairs(controls) do assert(c.text~='Num7', 'numpad controls do not exist before expansion') end
clickText('▸ NumPad')
assert(findKey('Num7') and findText('▾ NumPad') and requestedHeight==850, 'numpad expands panel')
clickText('▾ NumPad')
assert(not findKey('Num7') and findText('▸ NumPad') and requestedHeight==570, 'numpad collapses panel again')
clickText('▸ NumPad')
pressKey('Num7'); assert(requestedHeight==920, 'chooser requests full height'); clickText('HotBuild пресет'); clickText('Preset Fresh')
assert(calls.sets[#calls.sets].key=='Num7' and requestedHeight==850, 'assignment restores expanded numpad height')
clickText('▾ NumPad'); assert(not findKey('Num7'), 'collapse destroys numpad controls')
clickText('▸ NumPad'); assert(findKey('Num7').color==theme.Colors.accent, 'recreated numpad restores saved assignment state')
calls.sets={}
local esc=findKey('Esc')
local num7,num8,num4,num1,num0=findKey('Num7'),findKey('Num8'),findKey('Num4'),findKey('Num1'),findKey('Num0')
assert(esc and esc.x==0 and findKey('F1').x>esc.x, 'Escape precedes the function row')
assert(num7.x==num4.x and num4.x==num1.x and num1.x==num0.x and num8.x>num7.x
    and num7.y<num4.y and num4.y<num1.y and num1.y<num0.y and num0.Width()>num1.Width(),
    'numpad keeps its physical arrangement below the main keyboard')
assert(findKey('F1').Width()==52 and findKey('Page Up').x+findKey('Page Up').Width()<=1032,
    'larger keys and navigation fit the available width')
assert(findKey('Page Up').x>findKey('Backspace').x and not findKey('↑') and not findKey('←')
    and not findKey('↓') and not findKey('→'), 'navigation stays separate and arrow keys are absent')
pressKey('Esc'); clickText('HotBuild пресет'); clickText('Preset Fresh')
assert(calls.sets[#calls.sets].key=='Esc' and #escapeHandlers==0, 'Escape can be assigned through its on-screen key')
calls.sets={}
local watcher
for _,c in ipairs(controls) do if c.parent==frame and c.OnFrame and c.hitTestDisabled then watcher=c end end
assert(watcher and watcher.needsFrameUpdate,'modifier polling is active while editor is visible')
local function held(code,down) heldKeys[code]=down; watcher:OnFrame() end
held(17,true); findKey('Q'):HandleEvent({Type='ButtonPress',Modifiers={Right=true}})
assert(calls.chords[#calls.chords].key=='Q' and calls.chords[#calls.chords].mods.ctrl,'right-click uses held modifiers')
held(17,false)
local key=findKey('Page Up')
assert(key,'display key title is present')
key:HandleEvent({Type='MouseEnter'})
local popupText=findText('Foreign binding')
local fafSource=findText('FAF')
assert(fafSource and fafSource.textColor=='ffffffff' and fafSource.y<popupText.y,'FAF source is white and above the binding')
assert(popupText and math.abs(popupText.x*2+popupText:GetStringAdvance(popupText.text)/0.75-popupText.parent.Width())<0.01
    and popupText.y+24<popupText.parent.Height() and popupText.parent.Width()<480,
    'tooltip centers its text and sizes its background with bottom padding')
assert(popupText and popupText.parent.hitTestDisabled and popupText.parent.Depth()>frame.Depth(),
    'custom tooltip is above the keyboard and does not intercept pointer input')
assert(popupText and not findText('Стройка: Preset Existing'),
    'custom tooltip shows only the current unmodified binding')
held(17,true)
assert(findText('Нет назначения') and not findText('Foreign binding'),
    'tooltip updates while the pointer stays over the key')
held(16,true)
-- Contexts now render through hotbuild.keyboard.contexts ('Доступно для: %s').
assert(findText('Стройка: Preset Existing') and findText('Доступно для: Engineer, ACU') and not findText('Foreign binding'),
    'tooltip shows only the selected Ctrl+Shift binding')
held(16,false)
held(17,false)
key:HandleEvent({Type='MouseExit'})
findKey('B'):HandleEvent({Type='MouseEnter'})
assert(findText('Стройка: Building') and findText('Действие: Composite')
    and findText('Claret Hotbuild').textColor==theme.Colors.accentText
    and findText('Claret · Мультифункциональные').textColor==theme.Colors.accentText
    and findText('Claret Hotbuild').y<findText('Стройка: Building').y
    and findText('Claret · Мультифункциональные').y<findText('Действие: Composite').y,
    'tooltip shows building and composite in separate typed rows')
findKey('B'):HandleEvent({Type='MouseExit'})
assert(watcher.needsFrameUpdate,'modifier polling continues after pointer leaves')
held(17,true); assert(key.color==theme.Colors.raised,'modifier state updates while pointer is outside')
frame:OnHide(true); assert(not watcher.needsFrameUpdate and key.color==theme.Colors.accent,'hiding the editor stops polling and clears held modifiers')
heldKeys[17]=false; frame:OnHide(false); assert(watcher.needsFrameUpdate,'showing the editor resumes polling')
assert(not findText('Foreign binding'),'tooltip closes on mouse exit')
assert(key.color==theme.Colors.accent,'current unmodified assignment uses the theme accent')
local hasDangerOutline=false
for _,c in ipairs(controls) do if c.parent==key and c.color==theme.Colors.danger then hasDangerOutline=true end end
assert(hasDangerOutline,'mixed foreign and Claret assignments show a danger outline')
key:HandleEvent({Type='MouseEnter'}); key:HandleEvent({Type='MouseExit'})
assert(key.color==theme.Colors.accent and hasOutlineColor(key,theme.Colors.danger),
    'key hover restores current assignment fill and foreign warning outline')
local foreignOnly=findKey('F1')
assert(foreignOnly and foreignOnly.color==theme.Colors.accent and hasOutlineColor(foreignOnly,theme.Colors.danger),'foreign assignment is filled and outlined')
foreignOnly:HandleEvent({Type='MouseEnter'})
local heading=findText('F1'); local popup
for _,c in ipairs(controls) do if c.text=='F1' and c.parent and c.parent.hitTestDisabled and not c.parent.destroyed then popup=c.parent end end
assert(popup,'unmodified tooltip heading contains only the key')
local fragments={}
for _,c in ipairs(controls) do if c.parent==popup and c.text and c.text~='F1' and c.text~='FAF' then fragments[#fragments+1]=c.text end end
assert(#fragments>1 and table.concat(fragments)==assignments[3].label,'long binding wraps without truncation')
foreignOnly:HandleEvent({Type='MouseExit'})
held(17,true)
assert(key.color==theme.Colors.raised and foreignOnly.color==theme.Colors.raised,'holding Ctrl shows only Ctrl assignments')
held(17,false)
assert(key.color==theme.Colors.accent,'releasing Ctrl restores unmodified assignments')

-- Modifier toggles are independent; selecting Page Up must pass canonical PageUp plus all three flags.
local ctrlButton=clickText('Ctrl')
clickText('Shift'); clickText('Alt')
ctrlButton:HandleEvent({Type='MouseEnter'}); ctrlButton:HandleEvent({Type='MouseExit'})
assert(ctrlButton.color==theme.Colors.selected and hasOutlineColor(ctrlButton,theme.Colors.selectedBorder),
    'modifier hover restores the selected modifier style')
ctrlButton:HandleEvent({Type='MouseEnter'})
pressKey('Page Up')
assert(findText('Стройка: пусто') and findText('Действия: пусто'), 'empty chord displays both slots')
assert(#escapeHandlers==1,'opening chooser pushes a modal Escape handler')
local modal
for _,c in ipairs(controls) do if c.Width()==760 and c.Height()==760 and c.parent and c.parent.Width()==1080 and not c.destroyed then modal=c end end
local overlay=modal and modal.parent
assert(modal and modal.needsFrameUpdate and modal.centerOffset==-8,'chooser starts above its final position')
modal:OnFrame(0.08); assert(modal.centerOffset<0 and modal.centerOffset>-8,'chooser moves toward its final position')
modal:OnFrame(0.08); assert(modal.centerOffset==0 and not modal.needsFrameUpdate,'chooser finishes and stops frame updates')
assert(modal and overlay and overlay.Depth()>frame.Depth() and modal.Depth()>overlay.Depth()
    and overlay.color==theme.Colors.transparent and overlay.HandleEvent({Type='ButtonPress'}),
    'modal overlay is transparent, hit-tests outside clicks, and sits above the keyboard')
local dialogBack
for _,c in ipairs(controls) do if c.parent==modal and c.Width()==760 and c.Height()==760 then dialogBack=c end end
assert(dialogBack and dialogBack.Depth()<modal.Depth()+2 and dialogBack.hitTestDisabled,
    'modal background sits behind interactive content and does not block its hit tests')
assert(findText('Select Engineer'), 'first tab is selected when the chooser opens')
local firstTab=clickText('Мультифункциональные'); assert(findText('Composite Choice'),'composite choices are displayed')
firstTab:HandleEvent({Type='MouseEnter'}); firstTab:HandleEvent({Type='MouseExit'})
assert(firstTab.color==theme.Colors.accent,'selected modal tab remains selected after hover exit')
local actionTab=clickText('Бинды'); assert(findText('Select Engineer'),'context action choices are displayed')
actionTab:HandleEvent({Type='MouseEnter'}); actionTab:HandleEvent({Type='MouseExit'})
assert(actionTab.color==theme.Colors.accent and firstTab.color==theme.Colors.raised,
    'modal tab selection updates and survives hover transitions')
clickText('HotBuild пресет'); assert(findText('Preset Fresh'),'preset choices are displayed')
assert(ctrlButton.color==theme.Colors.selected,'opening the modal clears keyboard hover without clearing modifier selection')
clickText('Link Choice')
assert(findText('Связать назначения?') and #calls.sets==0,'link requires confirmation')
clickText('Отмена')
assert(#calls.sets==0,'cancelling a link preserves assignments')
clickText('Link Choice'); clickText('Связать')
assert(#calls.sets==1 and calls.sets[1].confirmed=='composite-occupant','confirmed link identifies its occupant')
calls.sets={}
pressKey('Page Up')
clickText('HotBuild пресет')
clickText('Blocked Choice')
assert(findText('Хотите переназначить?') and #calls.sets==0 and #escapeHandlers==2,'collision requests confirmation')
clickText('Отмена')
assert(#calls.sets==0 and #escapeHandlers==1,'cancel preserves assignment')
clickText('Blocked Choice')
clickText('Переназначить')
assert(#calls.sets==1 and calls.sets[1].confirmed=='foreign' and #escapeHandlers==0,'confirmation passes the occupant')
calls.sets={}
pressKey('Page Up')
clickText('HotBuild пресет')
clickText('Preset Fresh')
assert(#calls.sets==1 and calls.sets[1].key=='PageUp','UI stores canonical PageUp rather than display label')
assert(calls.sets[1].mods.ctrl and calls.sets[1].mods.shift and calls.sets[1].mods.alt,
    'saved key retains all selected modifiers')
assert(#escapeHandlers==0,'saving closes modal and pops Escape handler')
assert(key.color==theme.Colors.accent, 'closing modal restores the selected combination fill')

-- Escape closes the modal; destroying the editor also tears down an open modal and tooltip state.
clickText('Ctrl'); clickText('Shift'); clickText('Alt')
pressKey('C'); clickText('Бинды'); clickText('Select Engineer')
assert(findText('Двойное нажатие') and findText('Все такие юниты') and #escapeHandlers==2,
    'eligible action immediately offers the allowed second press')
clickText('Все такие юниты')
assert(service.double and service.double.first=='action' and service.double.second=='all_same' and service.double.key=='C',
    'double action is saved for the selected chord')
assert(findText('Двойное нажатие…') and #escapeHandlers==1,'saved option can be edited again')
clickText('Двойное нажатие…'); clickText('Без повтора')
assert(not service.double,'double action can be disabled independently')
escapeHandlers[#escapeHandlers]()
pressKey('B')
assert(findText('Стройка: Building') and findText('Действия: Composite'),
    'a preset linked in another editor is displayed in the two slots')
local bAssignment
for _,a in ipairs(assignments) do if a.key=='B' and not a.foreign then bAssignment=a end end
assert(bAssignment)
service.failClear=true
clickButtonAtY('Снять действия',72)
assert(findText('Стройка: Building') and findText('Действия: Composite')
    and findText('Симулированная ошибка очистки.') and calls.clears[#calls.clears].ref==bAssignment.linkedRef,
    'failed action-slot clear preserves its ref and displayed state and reports the error')
service.failClear=false
local linkedRef=bAssignment.linkedRef
clickButtonAtY('Снять действия',72)
assert(calls.clears[#calls.clears].ref==linkedRef and calls.clears[#calls.clears].key=='B'
    and findText('Стройка: Building') and findText('Действия: пусто'),
    'action-slot clear targets linkedRef and leaves the building slot assigned')
local presetRef=bAssignment.ref
clickButtonAtY('Снять стройку',48)
assert(calls.clears[#calls.clears].ref==presetRef and calls.clears[#calls.clears].key=='B'
    and findText('Стройка: пусто') and findText('Действия: пусто'),
    'building-slot clear targets the preset ref and refreshes the open dialog')
escapeHandlers[#escapeHandlers]()
pressKey('A'); local modal
for _,c in ipairs(controls) do if c.Width()==760 and c.Height()==760 and c.parent and c.parent.Width()==1080 and not c.destroyed then modal=c end end
assert(modal and #escapeHandlers==1)
escapeHandlers[#escapeHandlers]()
assert(modal.destroyed and #escapeHandlers==0,'Escape destroys modal and removes handler')
pressKey('A'); local finalModal
for _,c in ipairs(controls) do if c.Width()==760 and c.Height()==760 and c.parent and c.parent.Width()==1080 and not c.destroyed then finalModal=c end end
assert(finalModal and #escapeHandlers==1)
local tooltipBeforeDestroy=tooltipDestroys
frame:Destroy()
assert(finalModal.destroyed and #escapeHandlers==0 and tooltipDestroys==tooltipBeforeDestroy+1,
    'destroying frame cleans modal, Escape handler and active tooltip')

-- Early warning only: LuaPlus uses a 32-upvalue limit.
local visited={}
local function checkUpvalues(fn)
    if type(fn)~='function' or visited[fn] then return end
    visited[fn]=true
    local count,index=0,0
    while true do
        local name,value=debug.getupvalue(fn,index+1)
        if not name then break end
        index=index+1
        -- Fengari (Lua 5.3) lists _ENV as an upvalue; LuaPlus 5.1 resolves globals without one.
        if name~='_ENV' then count=count+1 end
        if type(value)=='function' then checkUpvalues(value) end
    end
    assert(count<=32,'keyboard editor closure exceeds 32 captured values: '..count..' at '..tostring(debug.getinfo(fn).linedefined))
end
checkUpvalues(editorModule.Create)
for _,c in ipairs(controls) do for _,value in pairs(c) do checkUpvalues(value) end end
print('PASS: keyboard editor canonical keys, modifiers, tooltip, choices, independent slot clear, collisions, modal cleanup, scale and closure limits')

