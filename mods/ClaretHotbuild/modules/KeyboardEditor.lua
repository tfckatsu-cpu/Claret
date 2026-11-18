local function T(key, first, second, third)
    local core = ReUI and ReUI.ClaretCore
    local localization=core and core.Localization
    if localization and type(localization.Text)=='function' then return localization.Text(key, first, second, third) end
    return key
end

-- Standalone Hotbuild keyboard map. Assignment storage and conflict policy live in service.
-- Keyboard rows use logical UI units.
local keyRows = {
    {0, 0, {{'Esc','Esc'}, {'F1','F1',1,1}, {'F2','F2'}, {'F3','F3'}, {'F4','F4'}, {'F5','F5',1,0.35}, {'F6','F6'}, {'F7','F7'}, {'F8','F8'}, {'F9','F9',1,0.35}, {'F10','F10'}, {'F11','F11'}, {'F12','F12'}}},
    {0, 70, {{'~','Tilde'},{'1','1'},{'2','2'},{'3','3'},{'4','4'},{'5','5'},{'6','6'},{'7','7'},{'8','8'},{'9','9'},{'0','0'},{'-','Minus'},{'=','Equals'},{'Backspace','Backspace',2}}},
    {0, 126, {{'Tab','Tab',1.5},{'Q','Q'},{'W','W'},{'E','E'},{'R','R'},{'T','T'},{'Y','Y'},{'U','U'},{'I','I'},{'O','O'},{'P','P'},{'[','LeftBracket'},{']','RightBracket'},{'\\','Backslash',1.5}}},
    {0, 182, {{'Caps','CapsLock',1.75},{'A','A'},{'S','S'},{'D','D'},{'F','F'},{'G','G'},{'H','H'},{'J','J'},{'K','K'},{'L','L'},{';','Semicolon'},{"'",'Quote'},{'Enter','Enter',2.25}}},
    {0, 238, {{'Shift',false,2.25,0,'shift'},{'Z','Z'},{'X','X'},{'C','C'},{'V','V'},{'B','B'},{'N','N'},{'M','M'},{',','Comma'},{'.','Period'},{'/','Slash'},{'Shift',false,2.75,0,'shift'}}},
    {0, 294, {{'Ctrl',false,1.25,0,'ctrl'},{'Alt',false,1.25,1.25,'alt'},{'Space','Space',6.25},{'Alt',false,1.25,0,'alt'},{'Ctrl',false,1.25,2.5,'ctrl'}}},
    {850, 0, {{'Print','PrintScreen'},{'Scroll','ScrollLock'},{'Pause','Pause'}}},
    {850, 70, {{'Insert','Insert'},{'Home','Home'},{'Page Up','PageUp'}}},
    {850, 126, {{'Delete','Delete'},{'End','End'},{'Page Down','PageDown'}}},
    {850, 238, {{'hotbuild.keyboard.mouse5','XButton2',1.5}}},
    {850, 294, {{'hotbuild.keyboard.mouse4','XButton1',1.5}}},
    {0, 370, {{'Num Lock','NumLock'},{'/','NumSlash'},{'*','NumStar'},{'-','NumMinus'}}},
    {0, 424, {{'Num7','Num7'},{'Num8','Num8'},{'Num9','Num9'},{'+','NumPlus',1,0,false,104}}},
    {0, 478, {{'Num4','Num4'},{'Num5','Num5'},{'Num6','Num6'}}},
    {0, 532, {{'Num1','Num1'},{'Num2','Num2'},{'Num3','Num3'}}},
    {0, 586, {{'Num0','Num0',2},{'.','NumPeriod'}}},
}
local comboNames = {'','Ctrl','Shift','Ctrl+Shift','Alt','Ctrl+Alt','Shift+Alt','Ctrl+Shift+Alt'}
local function ComboIndex(m)
    local n=1
    if m and m.ctrl then n=n+1 end
    if m and m.shift then n=n+2 end
    if m and m.alt then n=n+4 end
    return n
end
local function CloneModifiers(m)
    return {ctrl=m and m.ctrl or false,shift=m and m.shift or false,alt=m and m.alt or false}
end
local function Short(s,n)
    s=tostring(s or '')
    local p,count=1,0
    while p<=string.len(s) and count<n do
        local b=string.byte(s,p); p=p+(b<128 and 1 or (b<224 and 2 or (b<240 and 3 or 4))); count=count+1
    end
    return p<=string.len(s) and string.sub(s,1,p-1)..'…' or s
end
local function Fold(text)
    local folded=string.gsub(string.lower(tostring(text or '')),'\208[\129\144-\175]',function(letter)
        local b=string.byte(letter,2)
        if b==129 then return string.char(209,145) end
        if b<160 then return string.char(208,b+32) end
        return string.char(209,b-32)
    end)
    return string.gsub(folded,'\209\145','\208\181')
end
local function FormatContext(context)
    if type(context)=='string' then return context end
    if type(context)~='table' then return '' end
    local labels={}
    for _,value in ipairs(context) do
        local raw=tostring(value)
        local key='hotbuild.context.'..raw
        local label=T(key)
        table.insert(labels,label~=key and label or raw)
    end
    return table.concat(labels,', ')
end

local function ActionSection(id)
    if id=='build_storage_nearest' or id=='build_fabs_nearest' then return 5 end
    if string.find(id,'^split_') or id=='cycle_unit_types_in_sel' then return 2 end
    if string.find(id,'^select_') or id=='cycle_idle_factories' then return 1 end
    if string.find(id,'^acu_') or id=='overcharge' or id=='teleport' then return 3 end
    if id=='dock' or id=='dock_damaged' then return 8 end
    if string.find(id,'transport') or id=='ferry' then return 4 end
    if string.find(id,'upgrade') or id=='create_template_factory' or id=='repeat_queue' or id=='remove_queue'
        or id=='reclaim' or id=='repair' or id=='capture' or id=='cap' or id=='assist'
        or id=='filter_highest_engineer_and_assist' then return 5 end
    if string.find(id,'^toggle_') or id=='shield' or id=='stealth' or id=='discharge'
        or string.find(id,'pause') then return 6 end
    return 7
end

local function T(key, first, second, third)
    local core = ReUI and ReUI.ClaretCore
    local localization=core and core.Localization
    if localization and type(localization.Text)=='function' then return localization.Text(key,first,second,third) end
    return key
end

local function OrganizeChoices(choices)
    local names={'hotbuild.keyboard.group.selection','hotbuild.keyboard.group.split','hotbuild.keyboard.group.acu','hotbuild.keyboard.group.transport',
        'hotbuild.keyboard.group.build','hotbuild.keyboard.group.toggle','hotbuild.keyboard.group.orders','hotbuild.keyboard.group.air'}
    local sections={{},{},{},{},{},{},{},{}}
    for _,choice in ipairs(choices) do
        local ref=choice.ref or choice
        table.insert(sections[ActionSection(ref.id or '')],choice)
    end
    local result={}
    for i,items in ipairs(sections) do
        table.sort(items,function(a,b) return (a.label or '')<(b.label or '') end)
        if table.getn(items)>0 then
            table.insert(result,{heading=T(names[i])})
            for _,item in ipairs(items) do table.insert(result,item) end
        end
    end
    return result
end

function Create(parent, service, embedded, perf)
    local shellStart=perf and perf:Now()
    local Theme=import('/mods/ClaretCore/modules/Theme.lua'); local C=Theme.Colors
    local Group=import('/lua/maui/group.lua').Group
    local Bitmap=import('/lua/maui/bitmap.lua').Bitmap
    local UI=import('/lua/ui/uiutil.lua')
    local Helpers=import('/lua/maui/layouthelpers.lua')
    local Tooltip=import('/lua/ui/game/tooltip.lua')
    local Escape=import('/lua/ui/dialogs/eschandler.lua')
    local pixel=Helpers.GetPixelScaleFactor()
    local scale=embedded and embedded.scale or math.max(0.25,math.min(pixel,(parent.Width()-24)/1080,(parent.Height()-24)/920))
    local ratio=scale/pixel; local L=ReUI.UI.FloorLayouter(scale)
    local frame=Group(parent)
    frame:DisableHitTest()
    local uiState={dialog=nil,overlay=nil,dialogEscape=nil,confirmation=nil}
    local keyButtons,modifierButtons={},{}
    local CloseDialog,UpdateHeight
    local oldDestroy=frame.OnDestroy
    frame.OnDestroy=function(self)
        if uiState.confirmation then Escape.PopEscapeHandler(); uiState.confirmation=nil end
        if uiState.dialogEscape then Escape.PopEscapeHandler(); uiState.dialogEscape=nil end
        if uiState.dialog then uiState.dialog:Destroy(); uiState.dialog=nil end
        if uiState.overlay then uiState.overlay:Destroy(); uiState.overlay=nil end
        Tooltip.DestroyMouseoverDisplay(); oldDestroy(self)
    end
    local ok,err=pcall(function()
        local Edit=import('/lua/maui/edit.lua').Edit
        L(frame):Width(1080):Height(920):AtCenterIn(parent)
        if embedded then
            L(frame):AtLeftTopIn(parent,0,0)
            frame.Depth:Set(function() return parent.Depth()+1 end)
        else frame.Depth:Set(1000) end
        if not embedded then Theme.AnimateCentered(frame,parent,L) end
        local function Panel(owner,x,y,w,h,color)
            local p=Bitmap(owner); p:SetSolidColor(color or C.surface); L(p):AtLeftTopIn(owner,x,y):Width(w):Height(h)
            p.Depth:Set(function() return owner.Depth()+1 end)
            if uiState.dialog then
                local ancestor=owner
                while ancestor and ancestor~=uiState.dialog do ancestor=ancestor.GetParent and ancestor:GetParent() or ancestor.parent end
                if ancestor==uiState.dialog then
                    if owner==uiState.dialog then p.Depth:Set(function() return uiState.dialog.Depth()+2 end)
                    else p.Depth:Set(function() return owner.Depth()+1 end) end
                end
            end
            return p
        end
        local function Text(owner,value,x,y,size,color)
            if type(value)=='string' and string.sub(value,1,9)=='hotbuild.' then value=T(value) end
            local t=UI.CreateText(owner,value or '',(size or 14)*ratio,Theme.Fonts.body); t:SetColor(color or C.text); t:DisableHitTest(); L(t):AtLeftTopIn(owner,x,y)
            t.Depth:Set(function() return owner.Depth()+2 end)
            if uiState.dialog then
                local ancestor=owner
                while ancestor and ancestor~=uiState.dialog do ancestor=ancestor.GetParent and ancestor:GetParent() or ancestor.parent end
                if ancestor==uiState.dialog then
                    if owner==uiState.dialog then t.Depth:Set(function() return uiState.dialog.Depth()+2 end)
                    else t.Depth:Set(function() return owner.Depth()+1 end) end
                end
            end
            return t
        end
        local function Button(owner,value,x,y,w,h,callback,primary,hoverColor)
            local normal=primary and C.accent or C.raised
            local b=Panel(owner,x,y,w,h,normal); local border=Theme.Outline(b,L,w,h,primary and C.selectedBorder or C.border)
            local title=Text(b,value,4,0,Theme.Metrics.buttonText); L(title):AtCenterIn(b)
            local baseColor,baseBorder=normal,primary and C.selectedBorder or C.border
            local hovered=false
            local function Restore()
                b:SetSolidColor(baseColor); border(baseBorder)
            end
            b.HandleEvent=function(self,e)
                if e.Type=='MouseEnter' then hovered=true; self:SetSolidColor(hoverColor or (primary and C.accentHover or C.hover)); border(C.selectedBorder)
                elseif e.Type=='MouseExit' then hovered=false; Restore()
                elseif e.Type=='ButtonPress' and not (e.Modifiers and e.Modifiers.Right) then callback(); return true end
                return true
            end
            function b:SetBaseStyle(color,outline)
                baseColor,baseBorder=color,outline or C.border
                if not hovered then Restore() end
            end
            function b:SetTextColor(color) title:SetColor(color) end
            function b:SetLabel(value) title:SetText(value) end
            function b:ResetHover() hovered=false; Restore() end
            return b
        end
        local function Field(owner,x,y,w,max)
            local input=Edit(owner)
            L(input):AtLeftTopIn(owner,x,y):Width(w):Height(Theme.Metrics.fieldHeight)
            UI.SetupEditStd(input,C.text,nil,C.text,C.surface,Theme.Fonts.body,Theme.Metrics.text*ratio,max)
            input.OnEnterPressed=function() return true end
            return input
        end
        local function SearchField(owner,x,y,w,max)
            local plate=Panel(owner,x,y,w,Theme.Metrics.fieldHeight,C.surface)
            plate:DisableHitTest()
            local input=Edit(owner)
            input.Depth:Set(function() return owner.Depth()+2 end)
            L(input):AtLeftTopIn(owner,x+28,y):Width(w-28):Height(Theme.Metrics.fieldHeight)
            UI.SetupEditStd(input,C.text,nil,C.text,C.surface,Theme.Fonts.body,Theme.Metrics.text*ratio,max)
            input.OnEnterPressed=function() return true end
            local mark=Bitmap(owner)
            mark:SetTexture('/mods/ClaretHotbuild/textures/search-icon.dds')
            mark.Depth:Set(function() return owner.Depth()+3 end)
            mark:DisableHitTest()
            L(mark):AtLeftTopIn(owner,x+8,y+10):Width(16):Height(16)
            return input
        end
        local status=Text(frame,'',24,540,13,C.muted)
        local function Status(message,isError,arg1,arg2,arg3)
            if type(message)=='string' and string.sub(message,1,9)=='hotbuild.' then message=T(message,arg1,arg2,arg3) end
            status:SetText(Short(message,140)); status:SetColor(isError and C.danger or C.muted)
        end
        Text(frame,'hotbuild.keyboard.title',24,16,22)
        Text(frame,'hotbuild.keyboard.instructions',24,54,15,C.muted)
        local modifier={ctrl=false,shift=false,alt=false}
        local manual={ctrl=false,shift=false,alt=false}
        local held={ctrl=false,shift=false,alt=false}
        local assignments={}; local keys={}
        local Refresh
        local choiceEnv
        local hoverKey,hoverPopup
        local function LoadAssignments()
            local assignmentStart=perf and perf:Now()
            assignments=service:GetAssignments(perf) or {}; keys={}
            if choiceEnv then choiceEnv.assignments=assignments end
            if perf then perf:Add('assignments',assignmentStart); perf:Emit('assignments') end
            for _,row in ipairs(keyRows) do for _,key in ipairs(row[3]) do if key[2] then keys[key[2]]=true end end end
            for _,a in ipairs(assignments) do if a.key then keys[a.key]=true end end
        end
        local function ShowKeyTooltip(key)
            if hoverPopup then hoverPopup:Destroy(); hoverPopup=nil end
            if not key or uiState.dialog then return end
            local button=keyButtons[key]
            if not button then return end
            local lines={}
            local function Add(value,color) table.insert(lines,{text=value,color=color or C.text}) end
            for _,a in ipairs(assignments) do
                if a.key==key and ComboIndex(a.modifiers)==ComboIndex(modifier) then
                    local ref=a.ref or {}
                    local detail=tostring(a.label or ref.id or T('hotbuild.keyboard.no_assignment'))
                    local suffix=(a.legacy or ref.legacy) and T('hotbuild.keyboard.legacy') or ''
                    local context=FormatContext(a.context)
                    if ref.kind=='preset' then
                        Add(T('hotbuild.keyboard.claret_hotbuild'),C.accentText)
                        Add(T('hotbuild.keyboard.building',tostring(a.presetLabel or detail)..suffix))
                        if a.linkedLabel then
                            local kind=a.linkedRef and a.linkedRef.kind=='action' and T('hotbuild.keyboard.bindings') or T('hotbuild.keyboard.multifunction')
                            Add(T('hotbuild.keyboard.claret_prefix',kind),C.accentText)
                            Add(T('hotbuild.keyboard.action',a.linkedLabel))
                        end
                    elseif ref.kind=='action' then
                        Add(T('hotbuild.keyboard.action',detail..suffix))
                    elseif ref.kind=='composite' then
                        Add(T('hotbuild.keyboard.claret_multi'),C.accentText)
                        Add(T('hotbuild.keyboard.action',detail..suffix))
                    else
                        Add('FAF','ffffffff')
                        Add(detail..suffix)
                    end
                    if a.doubleLabel then Add(T('hotbuild.keyboard.repeat',a.doubleLabel)) end
                    if context~='' then Add(T('hotbuild.keyboard.contexts',context),C.muted) end
                end
            end
            if table.getn(lines)==0 then Add(T('hotbuild.keyboard.no_assignment')) end
            -- Measure the actual font at the shared UI scale; split at UTF-8 boundaries.
            local measure=Text(frame,'',0,0,13,C.text); measure:Hide()
            local wrapped={}
            for _,entry in ipairs(lines) do
                local line=entry.text
                local part=''; local pos=1
                while pos<=string.len(line) do
                    local byte=string.byte(line,pos)
                    local size=byte<128 and 1 or (byte<224 and 2 or (byte<240 and 3 or 4))
                    local char=string.sub(line,pos,pos+size-1); pos=pos+size
                    if part~='' and measure:GetStringAdvance(part..char)>456*ratio then
                        table.insert(wrapped,{text=part,color=entry.color}); part=''
                    end
                    part=part..char
                end
                if part~='' then table.insert(wrapped,{text=part,color=entry.color}) end
            end
            local contentWidth=0
            for _,line in ipairs(wrapped) do contentWidth=math.max(contentWidth,measure:GetStringAdvance(line.text)/ratio) end
            measure:Destroy()
            local combo=comboNames[ComboIndex(modifier)]
            local title=button.display..(combo~='' and (' · '..combo) or '')
            local titleMeasure=Text(frame,'',0,0,14,C.text); titleMeasure:Hide()
            contentWidth=math.max(contentWidth,titleMeasure:GetStringAdvance(title)/ratio)
            titleMeasure:Destroy()
            local width=math.max(200,math.min(480,math.ceil(contentWidth)+32))
            local count=table.getn(wrapped)
            local height=52+count*24
            local x=math.min(1056-width,24+button.x)
            local y=148+button.y+button.height+6
            if y+height>890 then y=math.max(0,148+button.y-height-6) end
            hoverPopup=Group(frame); L(hoverPopup):AtLeftTopIn(frame,x,y):Width(width):Height(height)
            hoverPopup.Depth:Set(function() return frame.Depth()+60 end)
            hoverPopup:DisableHitTest()
            local back=Panel(hoverPopup,0,0,width,height,C.surface); back:DisableHitTest()
            Theme.Outline(hoverPopup,L,width,height,C.border)
            local titleText=Text(hoverPopup,title,0,12,14,C.accentText)
            L(titleText):AtLeftTopIn(hoverPopup,(width-titleText:GetStringAdvance(title)/ratio)/2,12)
            for i=1,count do
                local line=Text(hoverPopup,wrapped[i].text,0,38+(i-1)*24,13,wrapped[i].color)
                L(line):AtLeftTopIn(hoverPopup,(width-line:GetStringAdvance(wrapped[i].text)/ratio)/2,38+(i-1)*24)
            end
        end
        CloseDialog=function()
            local hadDialog=uiState.dialog~=nil
            Tooltip.DestroyMouseoverDisplay()
            if uiState.confirmation then Escape.PopEscapeHandler(); uiState.confirmation=nil end
            if uiState.dialogEscape then Escape.PopEscapeHandler(); uiState.dialogEscape=nil end
            if uiState.dialog then uiState.dialog:Destroy(); uiState.dialog=nil end
            if uiState.overlay then uiState.overlay:Destroy(); uiState.overlay=nil end
            for _,button in pairs(keyButtons) do
                button.cell:SetSolidColor(button.fill); button.label:SetColor(button.textColor)
                button.outline(button.hasForeign and C.danger or button.outlineColor)
            end
            for _,button in ipairs(modifierButtons or {}) do if button.ResetHover then button:ResetHover() end end
            if hadDialog and UpdateHeight then UpdateHeight() end
        end
        choiceEnv={
            CloseDialog=CloseDialog, ShowKeyTooltip=ShowKeyTooltip, CloneModifiers=CloneModifiers,
            modifier=modifier, embedded=embedded, Panel=Panel, frame=frame, C=C, Group=Group,
            L=L, Theme=Theme, comboNames=comboNames, ComboIndex=ComboIndex, Text=Text,
            ReUI=ReUI, assignments=assignments, service=service, Escape=Escape,
            LoadAssignments=LoadAssignments, Refresh=function() if Refresh then Refresh() end end,
            Status=Status, UpdateHeight=function() if UpdateHeight then UpdateHeight() end end,
            keyButtons=keyButtons, modifierButtons=modifierButtons,
            OrganizeChoices=OrganizeChoices, Short=Short, FormatContext=FormatContext,
            Fold=Fold, uiState=uiState,
        }
        local function OpenChoices(key)
            local env=choiceEnv
            local CloseDialog,ShowKeyTooltip,CloneModifiers=env.CloseDialog,env.ShowKeyTooltip,env.CloneModifiers
            local modifier,embedded,Panel,frame,C,Group=env.modifier,env.embedded,env.Panel,env.frame,env.C,env.Group
            local L,Theme,comboNames,ComboIndex,Text=env.L,env.Theme,env.comboNames,env.ComboIndex,env.Text
            local ReUI,assignments,service,Escape=env.ReUI,env.assignments,env.service,env.Escape
            local Refresh=env.Refresh
            local function LoadAssignments()
                env.LoadAssignments()
                assignments=env.assignments
            end
            local Status,UpdateHeight=env.Status,env.UpdateHeight
            local keyButtons,modifierButtons=env.keyButtons,env.modifierButtons
            local OrganizeChoices,Short,FormatContext,Fold=env.OrganizeChoices,env.Short,env.FormatContext,env.Fold
            CloseDialog()
            hoverKey=nil; ShowKeyTooltip(nil)
            local chosenModifier=CloneModifiers(modifier)
            if embedded and embedded.setHeight then embedded.setHeight(920) end
            env.uiState.overlay=Panel(frame,0,0,1080,920,C.transparent); env.uiState.overlay.Depth:Set(function() return frame.Depth()+80 end)
            env.uiState.overlay.HandleEvent=function() return true end
            local box=Group(env.uiState.overlay); env.uiState.dialog=box; L(box):Width(760):Height(760):AtCenterIn(env.uiState.overlay)
            Theme.AnimateCentered(box,env.uiState.overlay,L)
            box.Depth:Set(function() return env.uiState.overlay.Depth()+1 end)
            local dialogBack=Panel(box,0,0,760,760,C.canvas); dialogBack.Depth:Set(function() return box.Depth()+1 end)
            dialogBack:DisableHitTest(); Theme.Outline(box,L,760,760,C.border)
            local combo=comboNames[ComboIndex(chosenModifier)]
            Text(box,ReUI.ClaretCore.Localization.Text('hotbuild.keyboard_editor.s001')..key..(combo~='' and (' · '..combo) or ''),24,18,20)
            local modalStatus=Text(box,'',24,724,12,C.muted)
            local function DialogStatus(message,isError) modalStatus:SetText(Short(message,48)); modalStatus:SetColor(isError and C.danger or C.muted) end
            local buildingText=Text(box,'',24,52,13,C.muted)
            local actionsText=Text(box,'',24,72,13,C.muted)
            local buildingRef,actionsRef,doubleButton
            local function UpdateSlots()
                local building,actions,other=ReUI.ClaretCore.Localization.Text('hotbuild.keyboard_editor.s002'),ReUI.ClaretCore.Localization.Text('hotbuild.keyboard_editor.s003'),{}
                buildingRef,actionsRef=nil,nil
                for _,assignment in ipairs(assignments) do
                    if assignment.key==key and ComboIndex(assignment.modifiers)==ComboIndex(chosenModifier) then
                        local ref=assignment.ref or {}
                        if ref.kind=='preset' then
                            building=assignment.presetLabel or assignment.label
                            buildingRef=assignment.ref
                            if assignment.linkedLabel then
                                actions=assignment.linkedLabel
                                actionsRef=assignment.linkedRef
                            end
                        elseif ref.kind=='composite' or ref.kind=='action' then
                            actions=assignment.label
                            actionsRef=assignment.ref
                        else table.insert(other,tostring(assignment.label or ref.id)) end
                        if assignment.doubleLabel then actions=actions..ReUI.ClaretCore.Localization.Text('hotbuild.keyboard_editor.s004')..assignment.doubleLabel end
                    end
                end
                buildingText:SetText(Short(ReUI.ClaretCore.Localization.Text('hotbuild.keyboard_editor.s005')..building,74))
                actionsText:SetText(Short(ReUI.ClaretCore.Localization.Text('hotbuild.keyboard_editor.s006')..actions..(table.getn(other)>0 and (ReUI.ClaretCore.Localization.Text('hotbuild.keyboard_editor.s007')..table.concat(other,', ')) or ''),74))
                if doubleButton then
                    local options=actionsRef and actionsRef.kind=='action' and service:GetDoubleChoices(actionsRef.id) or {}
                    if table.getn(options)>0 then doubleButton:Show() else doubleButton:Hide() end
                end
            end
            UpdateSlots()
            local function OpenDouble(ref)
                local options=service:GetDoubleChoices(ref.id) or {}
                if table.getn(options)==0 then return false end
                local shield=Panel(box,0,0,760,760,C.transparent); shield.Depth:Set(function() return box.Depth()+25 end)
                shield.HandleEvent=function() return true end
                local popup=Group(shield); env.uiState.confirmation=shield
                local height=160+table.getn(options)*40
                L(popup):Width(600):Height(height):AtCenterIn(shield)
                popup.Depth:Set(function() return shield.Depth()+1 end)
                local back=Panel(popup,0,0,600,height,C.surface); back:DisableHitTest()
                Theme.Outline(popup,L,600,height,C.border)
                Text(popup,ReUI.ClaretCore.Localization.Text('hotbuild.keyboard_editor.s008'),24,20,20)
                Text(popup,ReUI.ClaretCore.Localization.Text('hotbuild.keyboard_editor.s009'),24,54,14,C.muted)
                local current=service:GetDoubleForKey(key,chosenModifier)
                local function Cancel() Escape.PopEscapeHandler(); env.uiState.confirmation=nil; shield:Destroy() end
                for i,option in ipairs(options) do
                    local choice=option
                    local selected=current and current.first==ref.id and current.second==choice.id
                    Button(popup,(selected and '✓ ' or '')..choice.label,24,76+(i-1)*40,552,34,function()
                        local saved,message=service:SetDoubleForKey(key,chosenModifier,ref.id,choice.id)
                        if saved==false then DialogStatus(message or ReUI.ClaretCore.Localization.Text('hotbuild.keyboard_editor.s010'),true); return end
                        Cancel(); LoadAssignments(); Refresh(); UpdateSlots(); DialogStatus(ReUI.ClaretCore.Localization.Text('hotbuild.keyboard_editor.s011'))
                    end,selected)
                end
                Button(popup,ReUI.ClaretCore.Localization.Text('hotbuild.keyboard_editor.s012'),24,height-48,160,32,function()
                    local saved,message=service:ClearDoubleForKey(key,chosenModifier)
                    if saved==false then DialogStatus(message or ReUI.ClaretCore.Localization.Text('hotbuild.keyboard_editor.s013'),true); return end
                    Cancel(); LoadAssignments(); Refresh(); UpdateSlots(); DialogStatus(ReUI.ClaretCore.Localization.Text('hotbuild.keyboard_editor.s014'))
                end,false)
                Button(popup,ReUI.ClaretCore.Localization.Text('hotbuild.keyboard_editor.s015'),464,height-48,112,32,Cancel,false)
                Escape.PushEscapeHandler(Cancel)
                return true
            end
            local function ClearSlot(which)
                local ref=which=='building' and buildingRef or actionsRef
                if not ref then DialogStatus(ReUI.ClaretCore.Localization.Text('hotbuild.keyboard_editor.s016'),false); return end
                local cleared,message=service:Clear(ref,key,CloneModifiers(chosenModifier))
                if cleared==false then DialogStatus(message or ReUI.ClaretCore.Localization.Text('hotbuild.keyboard_editor.s017'),true); return end
                LoadAssignments(); Refresh(); UpdateSlots()
                DialogStatus(message or ReUI.ClaretCore.Localization.Text('hotbuild.keyboard_editor.s018'),false)
                Status(message or ReUI.ClaretCore.Localization.Text('hotbuild.keyboard_editor.s019'))
            end
            Button(box,ReUI.ClaretCore.Localization.Text('hotbuild.keyboard_editor.s020'),608,48,128,24,function() ClearSlot('building') end,false)
            Button(box,ReUI.ClaretCore.Localization.Text('hotbuild.keyboard_editor.s021'),608,72,128,24,function() ClearSlot('actions') end,false)
            doubleButton=Button(box,ReUI.ClaretCore.Localization.Text('hotbuild.keyboard_editor.s022'),412,684,236,28,function()
                if actionsRef and actionsRef.kind=='action' then OpenDouble(actionsRef) end
            end,false)
            UpdateSlots()
            local choices=service:GetChoices() or {presets={},composites={},actions={}}
            for _,items in ipairs({choices.presets or {},choices.composites or {}}) do
                table.sort(items,function(a,b) return (a.label or '')<(b.label or '') end)
            end
            local groups={{ReUI.ClaretCore.Localization.Text('hotbuild.keyboard_editor.s023'),OrganizeChoices(choices.actions or {})},{ReUI.ClaretCore.Localization.Text('hotbuild.keyboard_editor.s024'),choices.composites or {}},{ReUI.ClaretCore.Localization.Text('hotbuild.keyboard_editor.s025'),choices.presets or {}}}
            local selectedGroup=1; local top=1; local visible=13; local currentChoices={}; local rangeLabel; local DrawChoices
            local search=SearchField(box,24,142,712,96)
            local searchText=''
            local list=Group(box); L(list):AtLeftTopIn(box,24,180):Width(712):Height(500)
            list.Depth:Set(function() return box.Depth()+2 end)
            local scrollBg=Panel(list,0,0,712,500,C.surface); scrollBg.Depth:Set(function() return list.Depth()+1 end)
            scrollBg:DisableHitTest()
            function list:GetScrollValues(axis) return 1,math.max(visible,table.getn(currentChoices)),top,top+visible-1 end
            function list:ScrollSetTop(axis,value) top=math.floor(value); DrawChoices() end
            function list:ScrollLines(axis,value) self:ScrollSetTop(axis,top+value) end
            function list:ScrollPages(axis,value) self:ScrollLines(axis,value*visible) end
            list.HandleEvent=function(self,e)
                if e.Type=='WheelRotation' then self:ScrollLines(nil,e.WheelRotation>0 and -1 or 1) end
                return true
            end
            local scrollbar=UI.CreateVertScrollbarFor(list)
            if scrollbar and scrollbar.Depth then scrollbar.Depth:Set(function() return list.Depth()+3 end) end
            local rows,shiftButtons={},{}
            for i=1,visible do
                local y=(i-1)*37
                rows[i]=Button(list,'',8,y+6,676,34,function() end,false)
            end
            local function FilterChoices(items)
                if searchText=='' then return items end
                local filtered,heading={},nil
                for _,choice in ipairs(items) do
                    if choice.heading then
                        heading=choice
                    else
                        local ref=choice.ref or choice
                        local values={choice.label or '',choice.searchLabel or '',ref.id or ''}
                        if type(choice.context)=='table' then
                            for _,context in ipairs(choice.context) do table.insert(values,context) end
                        elseif choice.context then table.insert(values,choice.context) end
                        local searchable=Fold(table.concat(values,' '))
                        if string.find(searchable,searchText,1,true) then
                            if heading then table.insert(filtered,heading); heading=nil end
                            table.insert(filtered,choice)
                        end
                    end
                end
                return filtered
            end
            local SaveChoice
            local function ConfirmChoiceConflict(message,onConfirm)
                local shield=Panel(box,0,0,760,760,C.transparent); shield.Depth:Set(function() return box.Depth()+25 end)
                shield.HandleEvent=function() return true end
                local confirm=Group(shield); env.uiState.confirmation=shield; L(confirm):Width(600):Height(180):AtCenterIn(shield)
                confirm.Depth:Set(function() return shield.Depth()+1 end)
                local back=Panel(confirm,0,0,600,180,C.surface); back:DisableHitTest()
                Theme.Outline(confirm,L,600,180,C.border)
                Text(confirm,ReUI.ClaretCore.Localization.Text('hotbuild.keyboard_editor.s032'),24,20,20)
                Text(confirm,Short(message or ReUI.ClaretCore.Localization.Text('hotbuild.keyboard_editor.s033'),72),24,60,14,C.text)
                local function Cancel() Escape.PopEscapeHandler(); env.uiState.confirmation=nil; shield:Destroy() end
                Button(confirm,ReUI.ClaretCore.Localization.Text('hotbuild.keyboard_editor.s037'),280,120,132,36,Cancel,false)
                Button(confirm,ReUI.ClaretCore.Localization.Text('hotbuild.keyboard_editor.s039'),424,120,152,36,function()
                    Cancel(); onConfirm()
                end,true)
                Escape.PushEscapeHandler(Cancel)
            end
            SaveChoice=function(ref,confirmed,addShift,stage,shiftConfirmed)
                stage=stage or 1
                local targetModifier=CloneModifiers(chosenModifier)
                if addShift and stage==2 then targetModifier.shift=true end
                if addShift and stage==1 then
                    local valid,message,details=service:Validate(ref,key,targetModifier)
                    if not valid then
                        if details and details.kind=='conflict' and details.id~=confirmed then
                            ConfirmChoiceConflict(message,function() SaveChoice(ref,details.id,true,1,shiftConfirmed) end)
                        else DialogStatus(message or ReUI.ClaretCore.Localization.Text('hotbuild.keyboard_editor.s026'),true) end
                        return
                    end
                    local shiftedModifier=CloneModifiers(targetModifier); shiftedModifier.shift=true
                    valid,message,details=service:Validate(ref,key,shiftedModifier)
                    if not valid then
                        if details and details.kind=='conflict' and details.id~=shiftConfirmed then
                            ConfirmChoiceConflict(message,function() SaveChoice(ref,confirmed,true,1,details.id) end)
                        else DialogStatus(message or ReUI.ClaretCore.Localization.Text('hotbuild.keyboard_editor.s026'),true) end
                        return
                    end
                end
                local confirmedForTarget=stage==2 and shiftConfirmed or confirmed
                local saved,saveMessage=service:Set(ref,key,targetModifier,confirmedForTarget)
                if saved==false then DialogStatus(saveMessage or ReUI.ClaretCore.Localization.Text('hotbuild.keyboard_editor.s026'),true); return end
                LoadAssignments(); Refresh(); UpdateSlots(); Status(saveMessage or ReUI.ClaretCore.Localization.Text('hotbuild.keyboard_editor.s027'))
                DrawChoices()
                if addShift and stage==1 then
                    SaveChoice(ref,nil,true,2,shiftConfirmed)
                elseif not addShift and ref.kind=='action' and OpenDouble(ref) then
                    return
                else
                    CloseDialog()
                end
            end
            DrawChoices=function()
                currentChoices=FilterChoices(groups[selectedGroup][2] or {})
                local count=table.getn(currentChoices)
                top=math.max(1,math.min(top,math.max(1,count-visible+1)))
                for i=1,visible do
                    local choice=currentChoices[top+i-1]; local row=rows[i]
                    if choice and choice.heading then
                        if shiftButtons[i] then shiftButtons[i]:Destroy(); shiftButtons[i]=nil end
                        row:Destroy()
                        rows[i]=Button(list,choice.heading,8,(i-1)*37+6,676,34,function() end,false)
                        rows[i]:SetBaseStyle(C.surface,C.border)
                        rows[i]:SetTextColor(C.accentText)
                        rows[i].Depth:Set(function() return list.Depth()+2 end)
                        rows[i]:DisableHitTest()
                    elseif choice then
                        if shiftButtons[i] then shiftButtons[i]:Destroy(); shiftButtons[i]=nil end
                        local selectedChoice=choice
                        local ref=choice.ref or choice
                        local assigned=false
                        for _,assignment in ipairs(assignments) do
                            local own=assignment.ref
                            local linked=assignment.linkedRef
                            if not assignment.foreign and ((own and own.kind==ref.kind and own.id==ref.id)
                                or (linked and linked.kind==ref.kind and linked.id==ref.id)) then
                                assigned=true; break
                            end
                        end
                        row:Show(); local label=choice.label or (choice.ref and choice.ref.id) or ReUI.ClaretCore.Localization.Text('hotbuild.keyboard_editor.s028')
                        if choice.legacy then label=ReUI.ClaretCore.Localization.Text('hotbuild.keyboard_editor.s029')..label end
                        -- Labels are immutable controls; replace the row with a fresh one when its item changes.
                        row:Destroy()
                        rows[i]=Button(list,Short(label,66),8,(i-1)*37+6,588,34,function()
                            local ref=selectedChoice.ref or selectedChoice
                            local valid,message,details=service:Validate(ref,key,CloneModifiers(chosenModifier))
                            if valid==false then
                                if not details or (details.kind~='conflict' and details.kind~='link') then DialogStatus(message or ReUI.ClaretCore.Localization.Text('hotbuild.keyboard_editor.s030'),true); return end
                                local shield=Panel(box,0,0,760,760,C.transparent); shield.Depth:Set(function() return box.Depth()+25 end)
                                shield.HandleEvent=function() return true end
                                local confirm=Group(shield); env.uiState.confirmation=shield; L(confirm):Width(600):Height(210):AtCenterIn(shield)
                                confirm.Depth:Set(function() return shield.Depth()+1 end)
                                local back=Panel(confirm,0,0,600,210,C.surface); back:DisableHitTest()
                                Theme.Outline(confirm,L,600,210,C.border)
                                Text(confirm,details.kind=='link' and ReUI.ClaretCore.Localization.Text('hotbuild.keyboard_editor.s031') or ReUI.ClaretCore.Localization.Text('hotbuild.keyboard_editor.s032'),24,20,20)
                                Text(confirm,Short(message or ReUI.ClaretCore.Localization.Text('hotbuild.keyboard_editor.s033'),72),24,60,14,C.text)
                                if details.kind=='link' then
                                    Text(confirm,details.previous and Short(ReUI.ClaretCore.Localization.Text('hotbuild.keyboard_editor.s034')..details.previous,70) or ReUI.ClaretCore.Localization.Text('hotbuild.keyboard_editor.s035'),24,84,13,C.muted)
                                    Text(confirm,ReUI.ClaretCore.Localization.Text('hotbuild.keyboard_editor.s036'),24,104,13,C.muted)
                                end
                                local function Cancel() Escape.PopEscapeHandler(); env.uiState.confirmation=nil; shield:Destroy() end
                                Button(confirm,ReUI.ClaretCore.Localization.Text('hotbuild.keyboard_editor.s037'),280,162,132,36,Cancel,false)
                                Button(confirm,details.kind=='link' and ReUI.ClaretCore.Localization.Text('hotbuild.keyboard_editor.s038') or ReUI.ClaretCore.Localization.Text('hotbuild.keyboard_editor.s039'),424,162,152,36,function() Cancel(); SaveChoice(ref,details.id,false,1) end,true)
                                Escape.PushEscapeHandler(Cancel)
                                return
                            end
                            SaveChoice(ref,nil,false)
                        end,false)
                        local shiftButton=Button(list,ReUI.ClaretCore.Localization.Text('hotbuild.keyboard_editor.s047'),604,(i-1)*37+6,72,34,function()
                            if chosenModifier.shift then
                                DialogStatus(ReUI.ClaretCore.Localization.Text('hotbuild.keyboard_editor.s048'),false)
                                return
                            end
                            SaveChoice(selectedChoice.ref or selectedChoice,nil,true)
                        end,false,C.accent)
                        shiftButtons[i]=shiftButton
                        shiftButton.Depth:Set(function() return list.Depth()+2 end)
                    if assigned then rows[i]:SetTextColor(C.muted) end
                    rows[i].Depth:Set(function() return list.Depth()+2 end)
                    local rowHandler=rows[i].HandleEvent
                    rows[i].HandleEvent=function(self,e)
                        if e.Type=='WheelRotation' then return list.HandleEvent(list,e) end
                        return rowHandler(self,e)
                    end
                        Tooltip.AddAutoUpdatedControlTooltip(rows[i],function() return label end,function()
                            local context=FormatContext(selectedChoice.context)
                            return context~='' and T('hotbuild.keyboard.contexts',context) or (selectedChoice.description or '')
                        end)
                    else
                        row:Hide()
                        if shiftButtons[i] then shiftButtons[i]:Hide() end
                    end
                end
                local range=count==0 and ReUI.ClaretCore.Localization.Text('hotbuild.keyboard_editor.s040') or (top..'–'..math.min(count,top+visible-1)..ReUI.ClaretCore.Localization.Text('hotbuild.keyboard_editor.s041')..count)
                rangeLabel:SetText(range)
            end
            search.OnTextChanged=function(self,value)
                searchText=Fold(value or (self.GetText and self:GetText()) or '')
                top=1; DrawChoices()
            end
            rangeLabel=Text(box,'',24,694,12,C.muted)
            search:SetText('')
            local groupButtons={}
            local function PickGroup(index)
                selectedGroup=index; top=1
                for i,button in ipairs(groupButtons) do
                    button:SetBaseStyle(i==index and C.accent or C.raised,i==index and C.selectedBorder or C.border)
                end
                DrawChoices()
            end
            for i,g in ipairs(groups) do
                local groupIndex=i
                groupButtons[i]=Button(box,g[1],24+(i-1)*238,100,226,36,function() PickGroup(groupIndex) end,i==selectedGroup)
            end
            Button(box,ReUI.ClaretCore.Localization.Text('hotbuild.keyboard_editor.s042'),638,12,98,32,function() CloseDialog() end,false)
            DrawChoices()
            env.uiState.dialogEscape=function() CloseDialog(); return true end
            Escape.PushEscapeHandler(env.uiState.dialogEscape)
        end
        local function DrawModifiers()
            for _,b in ipairs(modifierButtons) do
                local selected=modifier[b.modifierField]
                b:SetBaseStyle(selected and C.selected or C.raised,selected and C.selectedBorder or C.border)
            end
        end
        local keyboard=Group(frame); keyboard:DisableHitTest(); L(keyboard):AtLeftTopIn(frame,24,148):Width(1032):Height(640)
        local numpad,BuildNumpad
        local numpadOpen=service.keyboardNumpadOpen==true
        local legend=Text(frame,T('hotbuild.keyboard_editor.s043'),24,510,13,C.muted)
        UpdateHeight=function()
            local desired=numpadOpen and 850 or 570
            L(legend):AtLeftTopIn(frame,24,numpadOpen and 800 or 510)
            L(status):AtLeftTopIn(frame,24,numpadOpen and 824 or 540)
            if embedded and embedded.setHeight then embedded.setHeight(desired) end
        end
        local toggleNumpad
        toggleNumpad=Button(frame,T('hotbuild.keyboard.numpad_closed'),24,92,160,36,function()
            numpadOpen=not numpadOpen
            service.keyboardNumpadOpen=numpadOpen
            if numpadOpen then
                BuildNumpad()
                Refresh()
            else
                hoverKey=nil; ShowKeyTooltip(nil)
                numpad:Destroy(); numpad=nil
                for _,row in ipairs(keyRows) do
                    if row[2]>=370 then for _,spec in ipairs(row[3]) do keyButtons[spec[2]]=nil end end
                end
            end
            toggleNumpad:SetLabel(numpadOpen and T('hotbuild.keyboard.numpad_open') or T('hotbuild.keyboard.numpad_closed'))
            UpdateHeight()
        end,false)
        local function DrawKey(owner,key,x,y,w,display,height)
            local h=height or 50; local cell=Panel(owner,x,y,w,h,C.raised); local outline=Theme.Outline(cell,L,w,h,C.border)
            local caption=display or key
            if type(caption)=='string' and string.sub(caption,1,9)=='hotbuild.' then caption=T(caption) end
            local label=Text(cell,caption,0,9,string.len(caption)>6 and 11 or 14,C.text); L(label):AtCenterIn(cell)
            cell.HandleEvent=function(self,e)
                local state=keyButtons[key]
                if e.Type=='MouseEnter' then hoverKey=key; ShowKeyTooltip(key); self:SetSolidColor(C.hover); label:SetColor(C.text); outline(C.selectedBorder)
                elseif e.Type=='MouseExit' then
                    if hoverKey==key then hoverKey=nil; ShowKeyTooltip(nil) end
                    self:SetSolidColor(state.fill); label:SetColor(state.textColor); outline(state.hasForeign and C.danger or state.outlineColor)
                elseif e.Type=='ButtonPress' then
                    if e.Modifiers and e.Modifiers.Right then
                        LOG('[Claret][keyboard-clear] key='..tostring(key)..' combo='..tostring(ComboIndex(modifier))..' event=right')
                        local assigned=false
                        for _,assignment in ipairs(assignments) do
                            if assignment.key==key
                                and ComboIndex(assignment.modifiers)==ComboIndex(modifier) then assigned=true; break end
                        end
                        if not assigned then
                            LOG('[Claret][keyboard-clear] key='..tostring(key)..' result=no_assignment')
                            Status(T('hotbuild.keyboard_editor.s044'),false); return true
                        end
                        local cleared,message=service:ClearChord(key,CloneModifiers(modifier))
                        if not cleared then
                            LOG('[Claret][keyboard-clear] key='..tostring(key)..' result=failed reason='..tostring(message))
                            Status(message or T('hotbuild.keyboard_editor.s045'),true); return true
                        end
                        LOG('[Claret][keyboard-clear] key='..tostring(key)..' result=cleared')
                        LoadAssignments(); Refresh(); Status(T('hotbuild.keyboard_editor.s046'),false)
                    else OpenChoices(key) end
                    return true
                end
                return true
            end
            keyButtons[key]={cell=cell,label=label,outline=outline,x=x,y=y,height=h,display=caption,fill=C.raised,textColor=C.text,outlineColor=C.border,hasForeign=false}
        end
        if perf then perf:Add('frame_shell',shellStart); perf:Emit('frame_shell') end
        local keysStart=perf and perf:Now()
        local function DrawRows(wantNumpad,owner)
            for _,row in ipairs(keyRows) do
                if (row[2]>=370)==wantNumpad then
                    local x=row[1]
                    for _,spec in ipairs(row[3]) do
                        local display,key,units,offset,field=spec[1],spec[2],spec[3] or 1,spec[4] or 0,spec[5]
                        x=x+offset*56
                        local width=units*56-4
                        if key then
                            DrawKey(owner,key,x,row[2],width,display,spec[6])
                        else
                            local button=Button(owner,display,x,row[2],width,50,function()
                                manual[field]=not manual[field]; modifier[field]=manual[field] or held[field]
                                DrawModifiers(); Refresh()
                            end,false)
                            button.modifierField=field
                            table.insert(modifierButtons,button)
                        end
                        x=x+units*56
                    end
                end
            end
        end
        BuildNumpad=function()
            numpad=Group(keyboard); numpad:DisableHitTest(); L(numpad):AtLeftTopIn(keyboard,0,0):Width(1032):Height(640)
            DrawRows(true,numpad)
        end
        if numpadOpen then
            BuildNumpad()
            toggleNumpad:SetLabel(T('hotbuild.keyboard.numpad_open'))
        end
        DrawRows(false,keyboard)
        if perf then perf:Add('key_controls',keysStart); perf:Emit('key_controls') end
        UpdateHeight()
        Refresh=function()
            for _,button in pairs(keyButtons) do
                button.fill=C.raised; button.textColor=C.text; button.outlineColor=C.border; button.hasForeign=false
            end
            for _,a in ipairs(assignments) do
                local button=keyButtons[a.key]
                if button and ComboIndex(a.modifiers)==ComboIndex(modifier) then
                    button.fill=C.accent
                    button.textColor=C.text; button.outlineColor=C.selectedBorder
                    if a.foreign then button.hasForeign=true; button.outlineColor=C.danger end
                end
            end
            for _,button in pairs(keyButtons) do
                button.cell:SetSolidColor(button.fill); button.label:SetColor(button.textColor); button.outline(button.outlineColor)
            end
            if hoverKey then ShowKeyTooltip(hoverKey) end
        end
        -- Poll while the editor is visible without taking keyboard focus.
        local watcher=Group(frame)
        watcher:DisableHitTest()
        local function UpdateHeld(ctrl,shift,alt)
            if held.ctrl==ctrl and held.shift==shift and held.alt==alt then return end
            held.ctrl,held.shift,held.alt=ctrl,shift,alt
            modifier.ctrl=manual.ctrl or ctrl; modifier.shift=manual.shift or shift; modifier.alt=manual.alt or alt
            DrawModifiers(); Refresh()
        end
        watcher.OnFrame=function()
            UpdateHeld(IsKeyDown(17),IsKeyDown(16),IsKeyDown(18))
        end
        local oldHide=frame.OnHide
        frame.OnHide=function(self,hidden)
            watcher:SetNeedsFrameUpdate(not hidden)
            if hidden then UpdateHeld(false,false,false) else watcher:OnFrame() end
            if oldHide then return oldHide(self,hidden) end
        end
        watcher:SetNeedsFrameUpdate(true)
        watcher:OnFrame()
        LoadAssignments()
        local paintStart=perf and perf:Now()
        Refresh(); DrawModifiers()
        if perf then perf:Add('initial_paint',paintStart); perf:Emit('initial_paint'); perf=nil end
    end)
    if not ok then frame:Destroy(); error(err) end
    frame.RequestClose=function()
        if CloseDialog then CloseDialog() elseif not embedded then frame:Destroy() end
    end
    frame.CanLeave=function(intent,allowTransition)
        if CloseDialog then CloseDialog() end
        return true
    end
    return frame
end
