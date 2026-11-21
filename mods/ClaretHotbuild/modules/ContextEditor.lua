local function T(key, first, second, third)
    local core=ReUI and ReUI.ClaretCore
    local localization=core and core.Localization
    if localization and type(localization.Text)=='function' then return localization.Text(key, first, second, third) end
    return key
end
local function SearchText(key)
    local reui=rawget(_G,'ReUI')
    local core=reui and rawget(reui,'ClaretCore')
    local localization=core and core.Localization
    if localization and type(localization.SearchText)=='function' then return localization.SearchText(key) end
    return T(key)
end
local function ActionLabel(action)
    if not action then return '' end
    if action.labelKey then return T(action.labelKey) end
    if action.label then return action.label end
    return action.id or ''
end

-- Editor for saved composite context actions. Profile writes go through service.
local function Short(value, limit)
    value = tostring(value or '')
    local p, count = 1, 0
    while p <= string.len(value) and count < limit do
        local b = string.byte(value, p)
        p = p + (b < 128 and 1 or (b < 224 and 2 or (b < 240 and 3 or 4)))
        count = count + 1
    end
    return p <= string.len(value) and string.sub(value, 1, p - 1) .. '…' or value
end

local function Fold(value)
    value = string.lower(tostring(value or ''))
    local upper = {'Ё','А','Б','В','Г','Д','Е','Ж','З','И','Й','К','Л','М','Н','О','П','Р','С','Т','У','Ф','Х','Ц','Ч','Ш','Щ','Ъ','Ы','Ь','Э','Ю','Я'}
    local lower = {'ё','а','б','в','г','д','е','ж','з','и','й','к','л','м','н','о','п','р','с','т','у','ф','х','ц','ч','ш','щ','ъ','ы','ь','э','ю','я'}
    for i=1,table.getn(upper) do value=string.gsub(value,upper[i],lower[i]) end
    return value
end

function Create(parent, service, embedded, memory)
    local ContinuationTargets=service.contextActions.ContinuationTargets
    local Theme = import('/mods/ClaretCore/modules/Theme.lua')
    local C = Theme.Colors
    local Group = import('/lua/maui/group.lua').Group
    local Bitmap = import('/lua/maui/bitmap.lua').Bitmap
    local Edit = import('/lua/maui/edit.lua').Edit
    local UI = import('/lua/ui/uiutil.lua')
    local Helpers = import('/lua/maui/layouthelpers.lua')
    local Tooltip = import('/lua/ui/game/tooltip.lua')
    local Escape = import('/lua/ui/dialogs/eschandler.lua')
    local pixel = Helpers.GetPixelScaleFactor()
    local scale = embedded and embedded.scale or math.max(0.25, math.min(pixel,
        (parent.Width() - 24) / 1080, (parent.Height() - 24) / 920))
    local ratio = scale / pixel
    local L = ReUI.UI.FloorLayouter(scale)
    local frame = Group(parent)
    local CloseConflictDialog
    local oldDestroy = frame.OnDestroy
    frame.OnDestroy = function(self)
        if CloseConflictDialog then CloseConflictDialog() end
        Tooltip.DestroyMouseoverDisplay()
        oldDestroy(self)
    end

    local ok, err = pcall(function()
        L(frame):Width(1080):Height(920):AtCenterIn(parent)
        if embedded then
            L(frame):AtLeftTopIn(parent, 0, 0)
            frame.Depth:Set(function() return parent.Depth()+1 end)
        else frame.Depth:Set(1000) end
        if not embedded then Theme.AnimateCentered(frame,parent,L) end
        local function Panel(owner, x, y, w, h, color)
            local p = Bitmap(owner); p:SetSolidColor(color or C.surface)
            p.Depth:Set(function() return owner.Depth()+1 end)
            local panelLayout=L(p)
            if x~=nil and y~=nil then panelLayout:AtLeftTopIn(owner,x,y) end
            panelLayout:Width(w):Height(h)
            return p
        end
        local function Text(owner, value, x, y, size, color)
            if type(value)=='string' and string.sub(value,1,9)=='hotbuild.' then value=T(value) end
            local t = UI.CreateText(owner, value or '', (size or 14) * ratio, Theme.Fonts.body)
            t.Depth:Set(function() return owner.Depth()+2 end)
            t:SetColor(color or C.text); t:DisableHitTest(); L(t):AtLeftTopIn(owner, x, y)
            return t
        end
        local function Fit(text, value, width)
            value=tostring(value or '')
            if not text.GetStringAdvance then text:SetText(Short(value,math.floor(width/7))); return end
            local shown=value
            while text:GetStringAdvance(shown..'…')>width*ratio and string.len(shown)>0 do
                local finish=string.len(shown)
                while finish>1 and string.byte(shown,finish)>=128 and string.byte(shown,finish)<192 do finish=finish-1 end
                shown=string.sub(shown,1,finish-1)
            end
            if text:GetStringAdvance(value)<=width*ratio then shown=value else shown=shown..'…' end
            text:SetText(shown)
        end
        local function Button(owner, label, x, y, w, callback, primary)
            local normal = primary and C.accent or C.raised
            local selected = false
            local hovered = false
            local h = Theme.Metrics.buttonHeight
            local b = Panel(owner, x, y, w, h, normal)
            local outline = Theme.Outline(b, L, w, h)
            local title = Text(b, label, 4, 0, Theme.Metrics.buttonText); L(title):AtCenterIn(b)
            local function Paint()
                if hovered then
                    b:SetSolidColor(b.pressed and (primary and C.accentPressed or C.pressed) or (primary and C.accentHover or C.hover))
                    outline(C.selectedBorder)
                else
                    b:SetSolidColor(selected and C.selected or normal)
                    outline(selected and C.selectedBorder or C.border)
                end
            end
            b.HandleEvent = function(self, e)
                if e.Type == 'MouseEnter' then hovered = true; Paint()
                elseif e.Type == 'MouseExit' then hovered = false; self.pressed = false; Paint()
                elseif e.Type == 'ButtonRelease' then self.pressed = false; Paint()
                elseif e.Type == 'ButtonPress' and not (e.Modifiers and e.Modifiers.Right) then
                    self.pressed = true; Paint(); callback(); return true
                end
                return true
            end
            function b:SetLabel(value) title:SetText(value) end
            function b:SetSelected(value)
                selected=value
                self:SetSolidColor(selected and C.selected or normal)
                outline(selected and C.selectedBorder or C.border)
                title:SetText((selected and '● ' or '')..label)
            end
            return b
        end
        local function Field(owner, x, y, w, max)
            local field = Edit(owner)
            field.Depth:Set(function() return owner.Depth()+2 end)
            L(field):AtLeftTopIn(owner, x, y):Width(w):Height(Theme.Metrics.fieldHeight)
            UI.SetupEditStd(field, C.text, nil, C.text, C.surface, Theme.Fonts.body, Theme.Metrics.text * ratio, max)
            field.OnEnterPressed = function() return true end
            return field
        end
        local function SearchField(owner, x, y, w, max)
            local plate = Panel(owner, x, y, w, Theme.Metrics.fieldHeight, C.surface)
            plate:DisableHitTest()
            local field = Edit(owner)
            field.Depth:Set(function() return owner.Depth()+2 end)
            L(field):AtLeftTopIn(owner, x + 28, y):Width(w - 28):Height(Theme.Metrics.fieldHeight)
            UI.SetupEditStd(field, C.text, nil, C.text, C.surface, Theme.Fonts.body, Theme.Metrics.text * ratio, max)
            field.OnEnterPressed = function() return true end
            local mark = Bitmap(owner)
            mark:SetTexture('/mods/ClaretHotbuild/textures/search-icon.dds')
            mark.Depth:Set(function() return owner.Depth()+3 end)
            mark:DisableHitTest()
            L(mark):AtLeftTopIn(owner, x + 8, y + 10):Width(16):Height(16)
            return field
        end
        local bg = Panel(frame, 0, 0, 1080, 920, C.canvas)
        bg.Depth:Set(frame.Depth); bg.HandleEvent = function() return true end
        Panel(frame, 24, 20, 4, 24, C.accent):DisableHitTest()
        Text(frame, 'hotbuild.page.contexts.title', 40, 16, Theme.Metrics.title)
        Text(frame, 'hotbuild.context_editor.s002', 24, 54, Theme.Metrics.secondaryText, C.muted)

        memory = type(memory)=='table' and memory or {}
        local draft, dirty, loading = nil, false, false
        local saveButton
        local selectedContext, leaveIntent, leaveDialog, leaveOverlay, leaveContinuation, leaveEscape, deleteIntent
        local conflictDialog, conflictOverlay, conflictEscape
        local catalogTop, savedTop = 1, 1
        local RefreshRows, RefreshCatalog, RefreshSaved
        local name
        local nameWarning
        local Load, SaveDraft
        local draftStatus
        local status = Text(frame, '', 24, 900, 13, C.muted)
        local function Status(message, isError)
            status:SetText(Short(message, 150)); status:SetColor(isError and C.danger or C.muted)
        end
        local function Change()
            if not loading then
                dirty = true; leaveIntent = nil
                Status(T('hotbuild.context_editor.s003'))
                if draftStatus then draftStatus:SetText(T('hotbuild.context_editor.s004')); draftStatus:SetColor(C.muted) end
                if RefreshSaved then RefreshSaved() end
                if saveButton then saveButton:SetSolidColor(C.accent) end
            end
        end
        local function CloseLeaveDialog()
            if leaveEscape then Escape.PopEscapeHandler(); leaveEscape=nil end
            if leaveDialog then leaveDialog:Destroy(); leaveDialog=nil end
            if leaveOverlay then leaveOverlay:Destroy(); leaveOverlay=nil end
        end
        CloseConflictDialog=function()
            if conflictEscape then Escape.PopEscapeHandler(); conflictEscape=nil end
            if conflictDialog then conflictDialog:Destroy(); conflictDialog=nil end
            if conflictOverlay then conflictOverlay:Destroy(); conflictOverlay=nil end
        end
        local function WrapMessage(message, limit)
            local lines, current = {}, ''
            local source, position = tostring(message or ''), 1
            while position <= string.len(source) do
                local first, last = string.find(source, '%S+', position)
                if not first then break end
                local word = string.sub(source, first, last)
                position = last + 1
                local candidate = current == '' and word or (current .. ' ' .. word)
                if current ~= '' and Short(candidate, limit) ~= candidate then
                    table.insert(lines, current); current = word
                else current = candidate end
            end
            if current ~= '' then table.insert(lines, current) end
            return lines
        end
        local function ShowConflictDialog(message)
            CloseConflictDialog()
            Status('', false)
            conflictOverlay=Panel(frame,0,0,1080,920,C.transparent); conflictOverlay.Depth:Set(function() return frame.Depth()+80 end)
            conflictOverlay.HandleEvent=function() return true end
            local dialogWidth=680
            local lines=WrapMessage(message,76)
            local bodyHeight=math.max(22,table.getn(lines)*22)
            local dialogHeight=96+bodyHeight
            conflictDialog=Group(frame); L(conflictDialog):AtCenterIn(frame):Width(dialogWidth):Height(dialogHeight); conflictDialog.Depth:Set(function() return frame.Depth()+90 end)
            Theme.AnimateCentered(conflictDialog,frame,L)
            Escape.PushEscapeHandler(function() CloseConflictDialog() end); conflictEscape=true
            local back=Panel(conflictDialog,0,0,dialogWidth,dialogHeight,C.surface); back.Depth:Set(conflictDialog.Depth)
            Theme.Outline(back,L,dialogWidth,dialogHeight,C.selectedBorder)
            Text(conflictDialog,T('hotbuild.context_editor.s005'),24,20,20)
            for index,line in ipairs(lines) do Text(conflictDialog,line,24,58+(index-1)*22,14,C.text) end
            Button(conflictDialog,T('hotbuild.context_editor.s006'),dialogWidth-172,dialogHeight-44,148,function() CloseConflictDialog() end,true)
        end
        local function FinishLeave(accepted)
            local continuation=leaveContinuation; leaveContinuation=nil
            if continuation then
                local ok,err=pcall(continuation,accepted)
                if not ok then Status(T('hotbuild.context_editor.s007')..tostring(err),true) end
            end
        end
        local function ShowLeaveDialog(intent,continuation)
            CloseLeaveDialog(); leaveIntent=intent; leaveContinuation=continuation
            leaveOverlay=Panel(frame,0,0,1080,920,C.transparent); leaveOverlay.Depth:Set(function() return frame.Depth()+80 end)
            leaveOverlay.HandleEvent=function() return true end
            local dialogWidth,dialogHeight=560,224
            leaveDialog=Group(frame); L(leaveDialog):AtCenterIn(frame):Width(dialogWidth):Height(dialogHeight); leaveDialog.Depth:Set(function() return frame.Depth()+90 end)
            Theme.AnimateCentered(leaveDialog,frame,L)
            Escape.PushEscapeHandler(function()
                CloseLeaveDialog(); leaveIntent=nil
                if leaveContinuation then FinishLeave(false) end
            end); leaveEscape=true
            local back=Panel(leaveDialog,0,0,dialogWidth,dialogHeight,C.surface); back.Depth:Set(leaveDialog.Depth)
            Theme.Outline(back,L,dialogWidth,dialogHeight,C.selectedBorder)
            Text(leaveDialog,T('hotbuild.context_editor.s008'),24,20,20)
            Text(leaveDialog,T('hotbuild.context_editor.s009'),24,64,14,C.muted)
            Button(leaveDialog,T('hotbuild.context_editor.s010'),24,156,160,function()
                local saved=SaveDraft and SaveDraft()
                if saved then
                    CloseLeaveDialog(); leaveIntent=nil
                    if leaveContinuation then FinishLeave(true)
                    elseif intent=='close' and not embedded then frame:Destroy() end
                end
            end,true)
            Button(leaveDialog,T('hotbuild.context_editor.s011'),200,156,160,function()
                local current=draft and service.contextModel:Get(draft.id)
                Load(current or service.contextModel:List()[1])
                CloseLeaveDialog(); leaveIntent=nil
                if leaveContinuation then FinishLeave(true)
                elseif intent=='close' and not embedded then frame:Destroy() end
            end)
            Button(leaveDialog,T('hotbuild.context_editor.s012'),376,156,160,function()
                CloseLeaveDialog(); leaveIntent=nil
                if leaveContinuation then FinishLeave(false) end
            end)
        end
        local function MayLeave(intent,continuation)
            if dirty then
                if not leaveDialog then ShowLeaveDialog(intent,continuation)
                elseif continuation then leaveContinuation=continuation end
                return false
            end
            leaveIntent=nil; return true
        end
        local contexts = service.contextActions.Contexts()
        local actions = service.contextActions.List()
        local keyHint=Text(frame,'',344,154,12,C.muted)
        draftStatus=Text(frame,'',344,174,12,C.muted)
        Load=function(binding)
            loading = true
            draft = binding
            memory.bindingId = binding and binding.id or nil
            dirty = false; leaveIntent = nil; deleteIntent = nil; selectedContext = nil
            if draftStatus then draftStatus:SetText('') end
            if draft then
                for _, row in ipairs(draft.rows) do selectedContext = row.context; break end
                name:SetText(draft.name)
            else name:SetText('') end
            local keyboard=service.keyboardBindings
            local keys=draft and keyboard and keyboard.KeysFor and keyboard:KeysFor({kind='composite',id=draft.id}) or {}
            keyHint:SetText(T('hotbuild.context_editor.s013')..(table.getn(keys)>0 and table.concat(keys,', ') or '—'))
            loading = false
            if saveButton then saveButton:SetSolidColor(dirty and C.accent or C.disabled) end
            if RefreshCatalog then RefreshCatalog() end
        end
        name = Field(frame, 344, 112, 330, 128)
        nameWarning = Text(frame, '', 344, 72, 13, C.danger)
        name.OnTextChanged = function(self, value)
            nameWarning:SetText(string.find(value, '[^ -~]') and T('hotbuild.editor.status.invalid_name') or '')
            if draft and not loading then draft.name = value; Change() end
        end
        Text(frame, T('hotbuild.context_editor.s014'), 24, 91, 12, C.muted)
        Text(frame, T('hotbuild.context_editor.s015'), 344, 91, 12, C.muted)
        local savedStatus = Text(frame, '', 24, 154, 12, C.muted)
        local savedPicker = Panel(frame, 24, 112, 300, 38, C.raised)
        local savedPickerOutline = Theme.Outline(savedPicker, L, 300, 38)
        local savedPickerLabel = Text(savedPicker, '', 12, 0, 13)
        L(savedPickerLabel):AtCenterIn(savedPicker)
        local savedList, savedOverlay, savedEscape
        local savedTop, deleteIntent = 1, nil
        local function CloseSavedList()
            deleteIntent=nil
            if savedEscape then Escape.PopEscapeHandler(); savedEscape=nil end
            if savedList then savedList:Destroy(); savedList=nil end
            if savedOverlay then savedOverlay:Destroy(); savedOverlay=nil end
        end
        local function OpenSavedList()
            CloseSavedList()
            local list=service.contextModel:List()
            savedOverlay=Panel(frame,0,0,1080,920,C.transparent); savedOverlay.Depth:Set(function() return frame.Depth()+80 end)
            savedOverlay.HandleEvent=function(self,e) if e.Type=='ButtonPress' then CloseSavedList() end; return true end
            local visibleRows=9
            local listHeight=12+visibleRows*38
            savedList=Group(frame); L(savedList):AtLeftTopIn(frame,24,152):Width(372):Height(listHeight)
            Theme.AnimateAnchored(savedList,frame,L,24,152)
            savedList.Depth:Set(function() return frame.Depth()+90 end)
            local back=Panel(savedList,0,0,372,listHeight,C.canvas); back.Depth:Set(savedList.Depth)
            Theme.Outline(back,L,372,listHeight)
            local savedScrollbar
            local slots={}
            local function MaxTop() return math.max(1,table.getn(list)-visibleRows+1) end
            local function PaintDelete(slot)
                local armed=slot.record and deleteIntent==slot.record.id
                slot.delete:SetSolidColor(armed and C.selected or C.danger)
                slot.deleteOutline(armed and C.accentText or C.border)
                slot.deleteLabel:SetColor(armed and C.accentText or C.text)
            end
            local function PaintSelect(slot,hovered)
                local selected=slot.record and draft and draft.id==slot.record.id
                if hovered then slot.button:SetSolidColor(C.hover); slot.outline(C.selectedBorder)
                else
                    slot.button:SetSolidColor(selected and C.selected or C.raised)
                    slot.outline(selected and C.selectedBorder or C.border)
                end
            end
            local function RenderSaved()
                savedTop=math.max(1,math.min(savedTop,MaxTop()))
                for i,slot in ipairs(slots) do
                    local item=list[savedTop+i-1]; slot.record=item
                    if item then
                        slot.button:Show(); slot.label:SetText(Short(item.name,52))
                        slot.delete:Show(); PaintSelect(slot,false); PaintDelete(slot)
                    else
                        slot.button:Hide(); slot.delete:Hide()
                    end
                end
            end
            local function MoveTop(delta)
                savedTop=math.max(1,math.min(MaxTop(),savedTop+delta))
                RenderSaved()
            end
            back.HandleEvent=function(self,e) if e.Type=='WheelRotation' then MoveTop(e.WheelRotation>0 and -1 or 1) end; return true end
            function savedList:GetScrollValues() return 1,math.max(visibleRows,table.getn(list)),savedTop,math.max(savedTop,math.min(table.getn(list),savedTop+visibleRows-1)) end
            function savedList:IsScrollable() return table.getn(list)>visibleRows end
            function savedList:ScrollSetTop(axis,value) savedTop=math.max(1,math.min(MaxTop(),math.floor(value))); RenderSaved() end
            function savedList:ScrollLines(axis,delta) self:ScrollSetTop(axis,savedTop+delta) end
            function savedList:ScrollPages(axis,delta) self:ScrollSetTop(axis,savedTop+delta*visibleRows) end
            local function SyncScrollbar()
                if table.getn(list)>visibleRows then
                    if not savedScrollbar then
                        savedScrollbar=UI.CreateVertScrollbarFor(savedList,-20)
                        if savedScrollbar.Depth then savedScrollbar.Depth:Set(function() return savedList.Depth()+4 end) end
                    end
                    if savedScrollbar.Show then savedScrollbar:Show() end
                elseif savedScrollbar and savedScrollbar.Hide then
                    savedScrollbar:Hide()
                end
            end
            for i=1,visibleRows do
                local slot={}; local n=i
                slot.button=Panel(savedList,8,6+(i-1)*38,300,34,C.raised)
                slot.outline=Theme.Outline(slot.button,L,300,34)
                slot.label=Text(slot.button,'',10,0,Theme.Metrics.secondaryText); L(slot.label):AtCenterIn(slot.button)
                slot.delete=Panel(savedList,314,6+(i-1)*38,34,34,C.danger)
                slot.deleteOutline=Theme.Outline(slot.delete,L,34,34)
                slot.deleteLabel=Text(slot.delete,'×',0,0,19); L(slot.deleteLabel):AtCenterIn(slot.delete)
                slot.delete:Hide()
                slot.delete.HandleEvent=function(self,e)
                    local record=slot.record
                    if not record then return true end
                    if e.Type=='MouseEnter' then
                        self:SetSolidColor(deleteIntent==record.id and C.selected or C.hover)
                        slot.deleteOutline(C.selectedBorder)
                    elseif e.Type=='MouseExit' then
                        PaintDelete(slot)
                    elseif e.Type=='ButtonPress' or e.Type=='DoubleClick' then
                        if dirty then Status(T('hotbuild.editor.status.save_or_confirm'),true); return true end
                        local recordId=record.id
                        if deleteIntent~=recordId then
                            deleteIntent=recordId
                            RenderSaved()
                            Status(T('hotbuild.context_editor.s023')..record.name..'»',true)
                            return true
                        end
                        local success,message=service:CommitContext(nil,recordId,true)
                        deleteIntent=nil
                        if success then
                            if draft and draft.id==recordId then Load(nil) end
                            RefreshSaved(); RefreshRows()
                        else
                            RenderSaved()
                        end
                        Status(success and T('hotbuild.context_editor.s022') or message,not success)
                    end
                    return true
                end
                Tooltip.AddAutoUpdatedControlTooltip(slot.delete,function() return slot.record and (T('hotbuild.context_editor.s023')..slot.record.name..'»') or T('hotbuild.context_editor.s024') end,function()
                    local keyboard=service.keyboardBindings
                    local keys=slot.record and keyboard and keyboard.KeysFor and keyboard:KeysFor({kind='composite',id=slot.record.id}) or {}
                    return table.getn(keys)>0 and (T('hotbuild.context_editor.s025')..table.concat(keys,', ')) or T('hotbuild.context_editor.s026')
                end)
                slot.button.HandleEvent=function(self,e)
                    if e.Type=='MouseEnter' then PaintSelect(slot,true)
                    elseif e.Type=='MouseExit' then PaintSelect(slot,false)
                    elseif e.Type=='WheelRotation' then MoveTop(e.WheelRotation>0 and -1 or 1)
                    elseif e.Type=='ButtonPress' and slot.record then
                        local record=slot.record
                        local function SelectSaved(accepted)
                            if accepted then Load(service.contextModel:Get(record.id)); CloseSavedList(); RefreshSaved(); RefreshRows() end
                        end
                        if MayLeave('select:'..record.id,SelectSaved) then SelectSaved(true) end
                        return true
                    end
                    return true
                end
                Tooltip.AddAutoUpdatedControlTooltip(slot.button,function() return slot.record and slot.record.name or '' end,function() return T('hotbuild.context_editor.s027') end)
                slots[i]=slot
            end
            Escape.PushEscapeHandler(function() CloseSavedList() end); savedEscape=true
            RenderSaved()
            SyncScrollbar()
        end
        savedPicker.HandleEvent=function(self,e)
            if e.Type=='KeyDown' and e.RawKeyCode==27 and savedList then CloseSavedList(); return true end
            if e.Type=='MouseEnter' then self:SetSolidColor(C.hover); savedPickerOutline(C.selectedBorder)
            elseif e.Type=='MouseExit' then self:SetSolidColor(C.raised); savedPickerOutline(C.border)
            elseif e.Type=='ButtonPress' then if savedList then CloseSavedList() else OpenSavedList() end; return true end
            return true
        end
        frame.HandleEvent=function(self,e)
            if e.Type=='KeyDown' and e.RawKeyCode==27 and savedList then CloseSavedList(); return true end
            return false
        end
        Tooltip.AddAutoUpdatedControlTooltip(savedPicker,function() return draft and draft.name or T('hotbuild.context_editor.s028') end,function() return T('hotbuild.context_editor.s029') end)
        RefreshSaved=function()
            local list = service.contextModel:List()
            savedTop = math.max(1, math.min(savedTop, math.max(1, table.getn(list) - 8)))
            savedPickerLabel:SetText(draft and (Short(draft.name,28)..(dirty and '  •' or '')..'  ▼') or (table.getn(list)==0 and T('hotbuild.context_editor.s030') or T('hotbuild.context_editor.s031')) .. '  ▼')
            savedStatus:SetText(table.getn(list)==0 and T('hotbuild.context_editor.s032') or '')
            if savedList then OpenSavedList() end
        end
        Button(frame,T('hotbuild.context_editor.s033'),690,112,110,function()
            local function CreateNew(accepted)
                if not accepted then return end
                CloseSavedList()
                local i=1; while service.contextModel:Get('context_'..i) do i=i+1 end
                Load({id='context_'..i,name=T('hotbuild.context_editor.s140'),rows={}}); Change(); RefreshSaved(); RefreshRows()
            end
            if MayLeave('new',CreateNew) then CreateNew(true) end
        end,true)
        SaveDraft=function()
            if not draft then Status(T('hotbuild.context_editor.s034'),true); return end
            if not dirty then Status(T('hotbuild.context_editor.s035')); return true end
            if string.find(draft.name, '[^ -~]') then
                Status(T('hotbuild.editor.status.invalid_name'),true); return false
            end
            local success,message,compatibilityDetails=service:CommitContext(draft)
            if success then Load(service.contextModel:Get(draft.id)); RefreshSaved(); RefreshRows() end
            if not success and compatibilityDetails then
                ShowConflictDialog(message)
            else
                Status(success and (message or T('hotbuild.context_editor.s036')) or message,not success)
            end
            return success
        end
        saveButton=Button(frame,T('hotbuild.context_editor.s037'),808,112,110,function() SaveDraft() end,true)
        saveButton:SetSolidColor(C.disabled)
        local saveHandle=saveButton.HandleEvent
        saveButton.HandleEvent=function(self,e)
            local handled=saveHandle(self,e)
            if not dirty and e.Type~='ButtonPress' then self:SetSolidColor(C.disabled)
            elseif dirty and e.Type=='MouseExit' then self:SetSolidColor(C.accent) end
            return handled
        end

        Text(frame,T('hotbuild.context_editor.s038'),24,220,18)
        Text(frame,T('hotbuild.context_editor.s039'),24,246,12,C.muted)
        local usageText=Text(frame,T('hotbuild.context_editor.s040'),24,266,12,C.muted)
        local contextPanel=Panel(frame,24,282,480,614,C.canvas)
        local contextButtons={}
        local function ApplyContextTileStyle(item)
            local color
            if item.hovered and not item.blocked then color=C.hover
            elseif item.contextSelected then color=C.selected
            elseif item.blocked then color=C.disabled
            elseif item.isBuilder then color=C.raised
            elseif item.hasAction then color=C.raised
            else color=C.surface end
            local outlineColor
            if item.contextSelected or (item.hovered and not item.blocked) then outlineColor=C.selectedBorder
            elseif item.blocked then outlineColor=C.warningBorder
            else outlineColor=C.border end
            item.button:SetSolidColor(color)
            item.outline(outlineColor)
        end
        local hoveredContextTile
        local function SetContextTileHover(item, hovered)
            if hovered then
                if hoveredContextTile and hoveredContextTile~=item then
                    hoveredContextTile.hovered=false
                    ApplyContextTileStyle(hoveredContextTile)
                end
                hoveredContextTile=item
                item.hovered=true
                ApplyContextTileStyle(item)
            elseif hoveredContextTile==item then
                hoveredContextTile=nil
                item.hovered=false
                ApplyContextTileStyle(item)
            end
        end
        local RowsFor
        local function CurrentRow(context)
            if draft then for i,row in ipairs(draft.rows) do if row.context==context then return row,i end end end
        end
        local function ContextLabel(id)
            for _,c in ipairs(contexts) do if c.id==id then return c.labelKey and T(c.labelKey) or c.label end end
            return id
        end
        local function Obsolete(context, id)
            return id and ((id=='load_transports') or (id=='suicide') or id=='mode' or id=='dock' or id=='set_default_target_priority' or id=='nuke' or id=='tactical' or id=='upgrade_structure' or (id=='sacu_tech' and context=='sacu')
                or ((id=='upgrade_structure_under_cursor' or id=='upgrade_structure_pause' or id=='upgrade_mex_select_next') and context~='cursor')
                or (id=='soft_stop' and context~='factory')
                or (id=='attack' and context=='transport')
                or (id=='remove_queue' and context=='factory')
                or (id=='transport_order' and context=='other')
                or (id=='shield' and context=='factory')
                or (service.contextActions.Get(id) or {}).obsolete
                or not service.contextActions.Get(id) or not service.contextActions.Supports(id,context))
        end
        local function CatalogGroup(action,context)
            local id=action.id or ''
            if string.find(id,'^select_.*_factories_') then return 6 end
            if id=='overcharge' or string.find(id,'^acu_') or string.find(id,'^sacu_') or string.find(id,'select_acu') then return 1 end
            if action.order then return 7 end
            if context=='acu' or context=='sacu' then return 1 end
            if context=='engineer' or string.find(id,'engineer') then return 2 end
            if string.find(id,'air_experimentals') then return 4 end
            if context=='units' or context=='land' or context=='navy'
                or string.find(id,'land_army') or string.find(id,'naval_army') or string.find(id,'experimentals') then return 3 end
            if context=='air' or context=='scout' or string.find(id,'scout') or string.find(id,'bomber')
                or string.find(id,'fighter') or string.find(id,'gunship') or string.find(id,'air_experimentals') then return 4 end
            if context=='transport' or string.find(id,'transport') then return 5 end
            if context=='factory' or context=='mex' or context=='missiles' or context=='silo_tactical'
                or context=='silo_nuclear' or string.find(id,'radar') or string.find(id,'sensor')
                or string.find(id,'silo') or string.find(id,'structure') or string.find(id,'mex') then return 6 end
            return 7
        end
        local childParents={land='units',air='units',navy='units',acu='builder',sacu='builder',engineer='builder',silo_tactical='missiles',silo_nuclear='missiles'}
        local function TileLock(id)
            for _,row in ipairs(draft and draft.rows or {}) do
                local action=row.action and service.contextActions.Get(row.action)
                if id=='engineer' and row.context=='empty' and action
                    and action.continuation=='accumulate' and action.special
                    and string.find(action.special,'^next_engineer_') then
                    return T('hotbuild.context_editor.s041')..ActionLabel(action)
                end
                if row.context~='cursor' and row.context~=id and row.action and row.mode~='inherit' and row.mode~='disabled' then
                    for _,target in ipairs(ContinuationTargets(action)) do
                        if target==id then return T('hotbuild.context_editor.s041')..ActionLabel(action) end
                    end
                end
            end
        end
        local function HasReservedAssignment(target)
            if childParents[target] then
                local row=CurrentRow(target)
                return row and row.action and row.mode~='inherit' and row.mode~='disabled'
            end
            return service.contextModel:ResolveRow(draft,target)~=nil
        end
        local function ActionLock(action)
            if selectedContext=='cursor' then return nil end
            for _,target in ipairs(ContinuationTargets(action)) do
                if target~=selectedContext and HasReservedAssignment(target) then
                    return T('hotbuild.context_editor.s042')..ContextLabel(target)..T('hotbuild.context_editor.s043')
                end
            end
        end
        local function ConflictsWithEmpty() return false end
        local function EmptySelectionPolicy() return nil end
        local function RowIsActive(row) return row and row.action ~= nil and row.mode ~= 'disabled' and row.mode ~= 'inherit' end
        local function PolicyDescription(policy)
            if policy == 'double' then return T('hotbuild.context_editor.s044') end
            if policy == 'accumulate' then return T('hotbuild.context_editor.s045') end
        end
        local priorityRank={cursor=1,empty=2,units=3,builder=4,factory=5,missiles=6,transport=7,mex=8,scout=9,other=10}
        local selectedContextTitle=Text(frame,'',552,282,14,C.accentText)
        local catalogHint=Text(frame,T('hotbuild.context_editor.s046'),552,306,12,C.muted)
        local editTarget='action'
        local disableChildButton,resetChildButton,clearContextButton
        RefreshRows=function()
            local treeY=4
            for i,item in ipairs(contextButtons) do
                local showContext=not (draft and draft.absolute and item.context~='empty')
                if showContext then
                    if item.displayY~=treeY then
                        L(item.button):AtLeftTopIn(contextPanel,item.treeX,treeY)
                        item.displayY=treeY
                    end
                    treeY=treeY+34
                    item.button:Show()
                else item.button:Hide() end
                local row=CurrentRow(item.context)
                local isChild=item.child==true
                local effective
                if isChild then
                    local mode=row and (row.mode or 'own') or 'inherit'
                    local parent=CurrentRow(childParents[item.context])
                    effective=mode=='own' and row.action or (mode=='inherit' and parent and parent.action or nil)
                    item.mode:SetText(mode=='inherit' and T('hotbuild.context_editor.s047') or (mode=='disabled' and T('hotbuild.context_editor.s048') or T('hotbuild.context_editor.s049')))
                    item.mode:SetColor(mode=='inherit' and C.disabledText or C.accentText)
                else effective=row and row.action end
                if isChild then
                    effective=draft and service.contextModel:ResolveAction(draft,item.context) or nil
                end
                local locked=TileLock(item.context)
                local blocked=locked~=nil
                item.blocked=blocked
                item.contextSelected=selectedContext==item.context
                item.hasAction=effective~=nil
                ApplyContextTileStyle(item)
                if not item.isBuilder and not item.other then item.mark:SetText(blocked and '!' or (effective and '●' or '○')) end
                item.name:SetText((item.rank and (tostring(item.rank)..' · ') or (item.child and '· ' or ''))..Short(ContextLabel(item.context),28))
                local action=effective and service.contextActions.Get(effective)
                item.action:SetText(action and ActionLabel(action) or '—')
                if not isChild then item.action:SetColor(C.muted) end
                if isChild and (not row or row.mode=='inherit') and action then
                    item.action:SetText(T('hotbuild.context_editor.s050'))
                    item.action:SetColor(C.disabledText)
                elseif isChild then item.action:SetColor(C.muted) end
                if item.isBuilder then
                    local overrides=0
                    for _,id in ipairs(item.children) do
                        local child=CurrentRow(id)
                        if child and (child.mode=='own' or child.mode=='disabled' or (child.mode==nil and child.action)) then overrides=overrides+1 end
                    end
                item.action:SetText(action and ActionLabel(action) or '—')
                end
                local staleId=row and row.action or effective
                local display=action and ActionLabel(action) or '—'
                if isChild and (not row or row.mode=='inherit') and action then display=T('hotbuild.context_editor.s051') end
                if staleId and Obsolete(item.context,staleId) then display=T('hotbuild.context_editor.s052')..((service.contextActions.Get(staleId) or {}).label or staleId) end
                if locked then display=locked; item.action:SetColor(C.warning) end
                Fit(item.action,display,isChild and 150 or (item.isBuilder and 220 or 260))
                if blocked then item.mark:SetColor(C.muted) end
                item.outline(selectedContext==item.context and C.selectedBorder or (blocked and C.warningBorder or C.border))
            end
            local stats=draft and service.contextModel:EffectiveStats(draft) or {effective=0,overrides=0}
            local effectiveTotal=stats.effective
            for _,item in ipairs(contextButtons) do
                if not item.child and not item.isBuilder then
                    local row=CurrentRow(item.context)
                    if row and row.action then effectiveTotal=effectiveTotal+1 end
                end
            end
            usageText:SetText(Short(T('hotbuild.context_editor.s053')..effectiveTotal..T('hotbuild.context_editor.s054')..stats.overrides,44))
            local selectedChild=childParents[selectedContext]~=nil
            local selectedRow=selectedContext and CurrentRow(selectedContext)
            if draft and selectedChild then
                local mode=selectedRow and (selectedRow.mode or 'own') or 'inherit'
                disableChildButton:Show()
                resetChildButton:Show()
                resetChildButton:SetSelected(mode=='inherit')
                disableChildButton:SetSelected(mode=='disabled')
                if selectedRow then clearContextButton:Show() else clearContextButton:Hide() end
            else
                disableChildButton:Hide(); resetChildButton:Hide()
                if draft and selectedContext and selectedRow then clearContextButton:Show()
                else clearContextButton:Hide() end
            end
        end
        local function SelectContext(id,repair)
            if type(id)~='string' or id=='' then Status(T('hotbuild.context_editor.s055'),true); return end
            if draft and draft.absolute and id~='empty' and not repair then Status(T('hotbuild.context_editor.s056'),true); return end
            if ConflictsWithEmpty(id,EmptySelectionPolicy()) and not RowIsActive(CurrentRow(id)) then
                Status(T('hotbuild.context_editor.s057'),true); return
            end
            selectedContext=id; editTarget='action'; catalogTop=1; Status(''); RefreshRows(); RefreshCatalog()
        end
        local function SetChildMode(contextId,mode)
            if mode~='disabled' and TileLock(contextId) then Status(TileLock(contextId)..T('hotbuild.context_editor.s058'),true); return end
            local row=CurrentRow(contextId)
            if (row and (row.mode or 'own') or 'inherit')==mode then return end
            if not row then row={context=contextId}; table.insert(draft.rows,row) end
            row.mode=mode
            Change(); RefreshRows(); RefreshCatalog()
        end
        disableChildButton=Button(frame,T('hotbuild.context_editor.s059'),552,832,108,function()
            if childParents[selectedContext] then
                SetChildMode(selectedContext,'disabled')
            end
        end)
        resetChildButton=Button(frame,T('hotbuild.context_editor.s060'),664,832,108,function()
            if childParents[selectedContext] then
                SetChildMode(selectedContext,'inherit')
            end
        end)
        clearContextButton=Button(frame,T('hotbuild.context_editor.s061'),776,832,112,function()
            local index
            if selectedContext then local row; row,index=CurrentRow(selectedContext) end
            if draft and index then
                table.remove(draft.rows,index); Change(); RefreshRows(); RefreshCatalog()
                Status(T('hotbuild.context_editor.s062'))
            end
        end)
        disableChildButton:Hide(); resetChildButton:Hide(); clearContextButton:Hide()
        local function CreateContextTile(index, contextId, child, x, y, w, h)
            -- Always give a position: a size-only Maui control has a circular
            -- Left/Top chain until one anchor exists.
            local button=Panel(contextPanel,x,y,w,h,C.surface)
            local border=Theme.Outline(button,L,w,h)
            local mark=Text(button,'○',8,5,14,C.accentText)
            local title=Text(button,Short(ContextLabel(contextId),22),28,0,14)
            local mode=child and Text(button,'',188,0,11,C.muted) or nil
            local action=Text(button,'',child and 276 or 188,0,12,C.muted)
            local item={context=contextId,child=child,button=button,mark=mark,name=title,action=action,mode=mode,outline=border,treeX=x,treeY=y,displayY=y}
            button.HandleEvent=function(self,e)
                if e.Type=='MouseEnter' then SetContextTileHover(item,true)
                elseif e.Type=='MouseExit' then SetContextTileHover(item,false)
                elseif e.Type=='ButtonPress' then SelectContext(contextId); return true end
                return false
            end
            Tooltip.AddAutoUpdatedControlTooltip(button,function() return ContextLabel(contextId) end,function()
                local lock=TileLock(contextId)
                if lock then return lock..T('hotbuild.context_editor.s063') end
                local row=CurrentRow(contextId)
                local parent=child and CurrentRow(childParents[contextId])
                local actionId
                if child then
                    if row and row.mode=='disabled' then actionId=nil
                    elseif row and (row.mode=='own' or row.mode==nil) then actionId=row.action
                    else actionId=parent and parent.action end
                else actionId=row and row.action end
                local action=actionId and service.contextActions.Get(actionId)
                local detail=child and (row and row.mode=='disabled' and T('hotbuild.context_editor.s064') or (row and (row.mode=='own' or row.mode==nil) and T('hotbuild.context_editor.s065') or (T('hotbuild.context_editor.s066')..ContextLabel(childParents[contextId])..'»'))) or T('hotbuild.context_editor.s067')
                return action and (detail..': '..ActionLabel(action)..(item.context=='empty' and PolicyDescription(action.selectionPolicy) and (' · '..PolicyDescription(action.selectionPolicy)) or '')) or detail
            end)
            contextButtons[index]=item
        end
        local function CreatePriorityTile(contextId, rank, x, y, w)
            local button=Panel(contextPanel,x,y,w,30,C.surface)
            local border=Theme.Outline(button,L,w,30)
            local mark=Text(button,tostring(rank or '—'),8,2,13,C.accentText)
            local title=Text(button,Short(ContextLabel(contextId),22),30,0,14)
            local action=Text(button,'—',188,0,12,C.muted)
            local item={context=contextId,button=button,mark=mark,name=title,action=action,outline=border,priority=true,treeX=x,treeY=y,displayY=y}
            contextButtons[table.getn(contextButtons)+1]=item
            button.HandleEvent=function(self,e)
                if e.Type=='MouseEnter' then SetContextTileHover(item,true)
                elseif e.Type=='MouseExit' then SetContextTileHover(item,false)
                elseif e.Type=='ButtonPress' then SelectContext(contextId); return true end
                return false
            end
            Tooltip.AddAutoUpdatedControlTooltip(button,function() return ContextLabel(contextId) end,function()
                local lock=TileLock(contextId)
                if lock then return lock..T('hotbuild.context_editor.s068') end
                local row=CurrentRow(contextId)
                local action=row and row.action and service.contextActions.Get(row.action)
                local detail=rank and (T('hotbuild.context_editor.s069')..rank..T('hotbuild.context_editor.s070')) or T('hotbuild.context_editor.s071')
                return action and (detail..': '..ActionLabel(action)) or detail
            end)
        end
        local function CreateOtherTile(contextId,x,y,w)
            local button=Panel(contextPanel,x,y,w,30,C.surface)
            local border=Theme.Outline(button,L,w,30)
            local title=Text(button,Short(ContextLabel(contextId),20),8,0,14)
            local action=Text(button,'—',188,0,12,C.muted)
            local item={context=contextId,button=button,mark=title,name=title,action=action,outline=border,other=true,rank=priorityRank[contextId],treeX=x,treeY=y,displayY=y}
            contextButtons[table.getn(contextButtons)+1]=item
            button.HandleEvent=function(self,e)
                if e.Type=='MouseEnter' then SetContextTileHover(item,true)
                elseif e.Type=='MouseExit' then SetContextTileHover(item,false)
                elseif e.Type=='ButtonPress' then SelectContext(contextId); return true end
                return false
            end
            Tooltip.AddAutoUpdatedControlTooltip(button,function() return ContextLabel(contextId) end,function()
                local lock=TileLock(contextId)
                if lock then return lock..T('hotbuild.context_editor.s072') end
                local row=CurrentRow(contextId)
                local action=row and row.action and service.contextActions.Get(row.action)
                return action and ActionLabel(action) or T('hotbuild.context_editor.s073')
            end)
        end
        -- Selection hierarchy is presented as a single vertical tree.
        CreatePriorityTile('cursor',nil,8,8,456)
        CreatePriorityTile('empty',nil,8,42,456)
        local function CreateGroup(id,children,x,y,width,childHeight,step)
            local header=Panel(contextPanel,x,y,width,30,C.raised)
            local label=Text(header,ContextLabel(id),8,0,15)
            local action=Text(header,'',math.floor(width*0.5),0,11,C.muted)
            local item={context=id,button=header,mark=label,name=label,action=action,outline=function() end,isBuilder=true,children=children,rank=priorityRank[id],treeX=x,treeY=y,displayY=y}
            contextButtons[table.getn(contextButtons)+1]=item
            for i,childId in ipairs(children) do
                local index=table.getn(contextButtons)+1
                CreateContextTile(index,childId,true,x+22,y+30+(i-1)*step,width-22,childHeight)
            end
            header.HandleEvent=function(self,e)
                if e.Type=='MouseEnter' then SetContextTileHover(item,true)
                elseif e.Type=='MouseExit' then SetContextTileHover(item,false)
                elseif e.Type=='ButtonPress' then
                    if draft and draft.absolute then return true end
                    SelectContext(id); return true
                end
                return false
            end
            Tooltip.AddAutoUpdatedControlTooltip(header,function() return ContextLabel(id) end,function()
                local row=CurrentRow(id)
                local action=row and row.action and service.contextActions.Get(row.action)
                return action and (T('hotbuild.context_editor.s074')..ActionLabel(action)) or T('hotbuild.context_editor.s075')
            end)
        end
        CreateGroup('units',{'land','air','navy'},8,76,456,30,30)
        CreateGroup('builder',{'acu','sacu','engineer'},8,200,456,30,30)
        CreateOtherTile('factory',8,324,456)
        CreateGroup('missiles',{'silo_tactical','silo_nuclear'},8,358,456,30,30)
        local otherIds={'transport','mex','scout','other'}
        for i,id in ipairs(otherIds) do CreateOtherTile(id,8,448+(i-1)*32,456) end
        local catalogPanel=Panel(frame,536,364,520,498,C.canvas)
        local catalogScrollbar
        local actionSlots={}
        local groupHeaders={}
        local visibleActions=1
        local catalogMaxTop=1
        local searchField=SearchField(frame,552,326,488,128)
        local searchText=''
        searchField.OnTextChanged=function(self,value)
            searchText=Fold(value); catalogTop=1; RefreshCatalog()
        end
        searchField.OnEscPressed=function(self)
            self:AbandonKeyboardFocus()
            return true
        end
        local AddAction
        RowsFor=function(context)
            if context=='__obsolete' then
                local result={}
                for _,row in ipairs(draft and draft.rows or {}) do
                    for _,field in ipairs({'action','fallback'}) do
                        local id=row[field]
                        if Obsolete(row.context,id) then
                            local action=service.contextActions.Get(id)
                            local fieldLabel=field=='action' and T('hotbuild.context_editor.s076')
                                or 'fallback'
                            table.insert(result,{id=id,label=T('hotbuild.context_editor.s078')..fieldLabel..' · '..ContextLabel(row.context)..' · '..(action and ActionLabel(action) or id),obsoleteContext=row.context,obsoleteField=field})
                        end
                    end
                end
                return result
            end
            local groups={{items={}},{items={}},{items={}},{items={}},{items={}},{items={}},{items={}}}
            for _,action in ipairs(actions) do
                local cursorOnly=action.id=='upgrade_structure_under_cursor' or action.id=='upgrade_structure_pause' or action.id=='upgrade_mex_select_next'
                if action.id~='load_transports' and (not action.hidden or action.compositeOnly) and service.contextActions.Supports(action.id,context)
                    and (context=='cursor' or not cursorOnly) and not Obsolete(context,action.id) then
                    local group=CatalogGroup(action,context)
                    table.insert(groups[group].items,action)
                end
            end
            local compatible={}
            for _,group in ipairs(groups) do for _,action in ipairs(group.items) do
                local searchable={tostring(action.id or ''),tostring(ActionLabel(action))}
                if action.labelKey then table.insert(searchable,SearchText(action.labelKey)) end
                for _,key in ipairs(action.searchKeys or {}) do table.insert(searchable,SearchText(key)) end
                if searchText=='' or string.find(Fold(table.concat(searchable,' ')),searchText,1,true) then table.insert(compatible,action) end
            end end
            return compatible
        end
        local groupNames={'ACU',T('hotbuild.context_editor.s079'),T('hotbuild.context_editor.s080'),T('hotbuild.context_editor.s081'),T('hotbuild.context_editor.s082'),T('hotbuild.context_editor.s083'),T('hotbuild.context_editor.s084')}
        local function GroupFor(action) return CatalogGroup(action,selectedContext) end
        local emptyCatalogText=Text(catalogPanel,'',24,190,14,C.muted)
        local function DestroyActionRows()
            if table.getn(actionSlots)>0 then Tooltip.DestroyMouseoverDisplay() end
            for i=table.getn(actionSlots),1,-1 do
                actionSlots[i].button:Destroy()
                actionSlots[i]=nil
            end
            for i=table.getn(groupHeaders),1,-1 do groupHeaders[i].control:Destroy(); groupHeaders[i]=nil end
        end
        local function CreateActionRow(y,action)
            local button=Panel(catalogPanel,8,y,484,34,C.raised)
            button.Depth:Set(function() return catalogPanel.Depth()+2 end)
            local border=Theme.Outline(button,L,484,34)
            local effective=draft and service.contextModel:ResolveRow(draft,selectedContext)
            local active=effective and effective.action==action.id
            local blocked=ActionLock(action)
            button:SetSolidColor(blocked and C.disabled or (active and C.selected or C.raised))
            local mark=Text(button,blocked and '!' or (active and '●' or '·'),12,8,16,blocked and C.warning or (active and C.accentText or C.muted))
            local label=Text(button,Short(ActionLabel(action),48),32,8,14,blocked and C.muted or C.text)
            mark.Depth:Set(function() return button.Depth()+1 end)
            label.Depth:Set(function() return button.Depth()+1 end)
            border(active and C.selectedBorder or C.border)
            button.HandleEvent=function(self,e)
                if self.destroyed then return false end
                if e.Type=='WheelRotation' then catalogTop=math.max(1,catalogTop+(e.WheelRotation>0 and -1 or 1)); RefreshCatalog(); return true end
                if e.Type=='MouseEnter' and not ActionLock(action) then self:SetSolidColor(C.hover); border(C.selectedBorder)
                elseif e.Type=='MouseExit' then
                    local current=draft and service.contextModel:ResolveRow(draft,selectedContext)
                    local selected=current and current.action==action.id
                    local blockedNow=ActionLock(action)
                    self:SetSolidColor(blockedNow and C.disabled or (selected and C.selected or C.raised))
                    border(blockedNow and C.warningBorder or (selected and C.selectedBorder or C.border))
                elseif e.Type=='ButtonPress' then
                    local blockedNow=ActionLock(action)
                    if blockedNow then Status(blockedNow,true); return true end
                    if action.obsoleteContext then
                        SelectContext(action.obsoleteContext,true)
                        editTarget=action.obsoleteField or 'action'
                        RefreshRows(); RefreshCatalog()
                    else AddAction(action) end
                    return true end
                return false
            end
            Tooltip.AddAutoUpdatedControlTooltip(button,function() return ActionLabel(action) end,function()
                local policy=selectedContext=='empty' and PolicyDescription(action.selectionPolicy)
                return (ActionLock(action) or action.description or T('hotbuild.context_editor.s085'))..(policy and (' '..policy) or '')
            end)
            return {button=button,label=label,mark=mark,outline=border,action=action}
        end
        RefreshCatalog=function()
            local locked=selectedContext and TileLock(selectedContext)
            local available=selectedContext and not locked and RowsFor(selectedContext) or {}
            if selectedContext then
                local current=CurrentRow(selectedContext)
                local staleField=editTarget=='fallback' and current and Obsolete(selectedContext,current.fallback)
                catalogHint:SetText((locked and (locked..T('hotbuild.context_editor.s086')))
                    or (staleField and (T('hotbuild.context_editor.s087')..tostring(editTarget)..T('hotbuild.context_editor.s088')))
                    or (current and Obsolete(selectedContext,current.action) and (T('hotbuild.context_editor.s089')..current.action..T('hotbuild.context_editor.s090')))
                    or (T('hotbuild.context_editor.s091')..table.getn(available)..T('hotbuild.context_editor.s092')))
                selectedContextTitle:SetText((selectedContext=='__obsolete' and T('hotbuild.context_editor.s093') or ContextLabel(selectedContext))..(selectedContext=='builder' and T('hotbuild.context_editor.s094') or ''))
            else
                catalogHint:SetText(T('hotbuild.context_editor.s095'))
                selectedContextTitle:SetText('')
            end
            if selectedContext and editTarget=='fallback' then
                local row=CurrentRow(selectedContext)
                local main=row and row.action and service.contextActions.Get(row.action)
                catalogHint:SetText(main and service.contextActions.IsSelection(row.action)
                    and row.mode~='inherit' and row.mode~='disabled'
                    and T('hotbuild.context_editor.s098')
                    or T('hotbuild.context_editor.s099'))
                if not main or not service.contextActions.IsSelection(row.action) or row.mode=='inherit' or row.mode=='disabled' then available={} end
            end
            if selectedContext and table.getn(available)==0 then
                emptyCatalogText:SetText(locked or T('hotbuild.context_editor.s100'))
                emptyCatalogText:Show()
            else
                emptyCatalogText:Hide()
            end
            -- Reserve a full heading for every group on the last page.
            local count=table.getn(available)
            local used,lastGroup=0,nil
            catalogMaxTop=math.max(1,count)
            for i=count,1,-1 do
                local group=GroupFor(available[i])
                local height=34+(group~=lastGroup and 24 or 0)
                if used+height>432 then break end
                used=used+height; lastGroup=group; catalogMaxTop=i
            end
            catalogTop=math.max(1,math.min(catalogTop,catalogMaxTop))
            if catalogMaxTop>1 then
                if not catalogScrollbar then catalogScrollbar=UI.CreateVertScrollbarFor(catalogPanel) end
                if catalogScrollbar and catalogScrollbar.Show then catalogScrollbar:Show() end
            elseif catalogScrollbar and catalogScrollbar.Hide then catalogScrollbar:Hide() end
            DestroyActionRows()
            local y,lastGroup=8,nil
            visibleActions=0
            for index=catalogTop,count do
                local action=available[index]
                local group=GroupFor(action)
                local headingHeight=group~=lastGroup and 24 or 0
                if y+headingHeight+34>440 then break end
                if group~=lastGroup then
                    local heading=Panel(catalogPanel,8,y,484,24,C.canvas)
                    Text(heading,groupNames[group],4,4,13,C.muted)
                    groupHeaders[table.getn(groupHeaders)+1]={control=heading}
                    y=y+24
                end
                visibleActions=visibleActions+1
                actionSlots[visibleActions]=CreateActionRow(y,action)
                lastGroup=group
                y=y+34
            end
            if not selectedContext then Status(T('hotbuild.context_editor.s101'))
            elseif table.getn(available)==0 and not locked then Status(T('hotbuild.context_editor.s102'),true) end
        end
        AddAction=function(action)
            if not draft then Status(T('hotbuild.context_editor.s103'),true); return end
            if editTarget=='fallback' then
                local row=CurrentRow(selectedContext)
                if not row or row.mode=='inherit' or row.mode=='disabled' or not row.action
                    or not service.contextActions.IsSelection(row.action) then
                    Status(T('hotbuild.context_editor.s107'),true); return
                end
                if not service.contextActions.Supports(action.id,selectedContext) then
                    Status(T('hotbuild.context_editor.s108'),true); return
                end
                row.fallback=action.id; editTarget='action'; Change(); RefreshRows(); RefreshCatalog()
                Status(T('hotbuild.context_editor.s109')..ActionLabel(action)); return
            end
            if TileLock(selectedContext) then Status(TileLock(selectedContext),true); return end
            if draft.absolute and selectedContext~='empty' then Status(T('hotbuild.context_editor.s110'),true); return end
            local old=CurrentRow(selectedContext)
            if old and old.action==action.id and (not childParents[selectedContext] or old.mode==nil or old.mode=='own') then return end
            local actionLock=ActionLock(action)
            if actionLock then Status(actionLock,true); return end
            local policy=selectedContext=='empty' and action.selectionPolicy or EmptySelectionPolicy()
            if selectedContext~='empty' and ConflictsWithEmpty(selectedContext,policy) then
                Status(T('hotbuild.context_editor.s115')..ActionLabel(action)..T('hotbuild.context_editor.s116')..ContextLabel(selectedContext)..T('hotbuild.context_editor.s117'),true)
                return
            end
            for _,row in ipairs(draft.rows) do
                if RowIsActive(row) and ConflictsWithEmpty(row.context,policy) then
                    local emptyRow=CurrentRow('empty')
                    local otherAction=row.context=='empty' and action or (emptyRow and emptyRow.action and service.contextActions.Get(emptyRow.action))
                    local policyName=policy=='exclusive' and T('hotbuild.context_editor.s118') or (policy=='accumulate' and T('hotbuild.context_editor.s119') or T('hotbuild.context_editor.s120'))
                    Status(T('hotbuild.context_editor.s121')..ActionLabel(action)..'»: '..policyName..T('hotbuild.context_editor.s122')..ContextLabel(row.context)..'» ('..(otherAction and ActionLabel(otherAction) or T('hotbuild.context_editor.s123'))..T('hotbuild.context_editor.s124'),true)
                    return
                end
            end
            local row,index=CurrentRow(selectedContext)
            if row then
                row.action=action.id
            else
                row={context=selectedContext,action=action.id}
                if childParents[selectedContext] then row.mode='own' end
                table.insert(draft.rows,row)
            end
            if childParents[selectedContext] then row.mode='own' end
            Change(); RefreshRows(); RefreshCatalog()
                Status(T('hotbuild.context_editor.s125')..ActionLabel(action))
            if selectedContext=='missiles' and action.id=='smart_missile' then
                CloseConflictDialog()
                conflictOverlay=Panel(frame,0,0,1080,920,C.transparent); conflictOverlay.Depth:Set(function() return frame.Depth()+80 end)
                conflictOverlay.HandleEvent=function() return true end
                conflictDialog=Group(frame); L(conflictDialog):AtCenterIn(frame):Width(560):Height(270); conflictDialog.Depth:Set(function() return frame.Depth()+90 end)
                Theme.AnimateCentered(conflictDialog,frame,L)
                Escape.PushEscapeHandler(function() CloseConflictDialog() end); conflictEscape=true
                local back=Panel(conflictDialog,0,0,560,270,C.surface); back.Depth:Set(conflictDialog.Depth)
                Theme.Outline(back,L,560,270,C.selectedBorder)
                Text(conflictDialog,T('hotbuild.context_editor.s126'),24,18,18)
                Text(conflictDialog,T('hotbuild.context_editor.s127'),24,48,13,C.muted)
                local function OfferTarget(context,y)
                    local stored=CurrentRow(context)
                    local effective=service.contextModel:ResolveAction(draft,context)
                    local hasStored=stored and (stored.mode~='inherit' or stored.action or stored.quickRepeat or stored.fallback)
                    if hasStored or effective then
                        local occupied=(stored and stored.action and service.contextActions.Get(stored.action))
                            or (effective and service.contextActions.Get(effective))
                        local reason=stored and stored.mode=='disabled' and T('hotbuild.context_editor.s128')
                            or (stored and stored.mode=='inherit' and T('hotbuild.context_editor.s129')
                            or (occupied and occupied.label or T('hotbuild.context_editor.s130')))
                        Text(conflictDialog,ContextLabel(context)..': '..reason,24,y+6,13,C.warning)
                    else
                        local button
                        button=Button(conflictDialog,T('hotbuild.context_editor.s131')..string.upper(context),24,y,190,function()
                            local storedNow=CurrentRow(context)
                            local effectiveNow=service.contextModel:ResolveAction(draft,context)
                            local hasStoredNow=storedNow and (storedNow.mode~='inherit' or storedNow.action or storedNow.quickRepeat or storedNow.fallback)
                            if hasStoredNow or effectiveNow then
                                local occupiedAction=(storedNow and storedNow.action and service.contextActions.Get(storedNow.action))
                                    or (effectiveNow and service.contextActions.Get(effectiveNow))
                                Status(ContextLabel(context)..T('hotbuild.context_editor.s132')..(occupiedAction and occupiedAction.label or T('hotbuild.context_editor.s133')),true)
                                return
                            end
                            local current=CurrentRow(context)
                            if not current then current={context=context}; table.insert(draft.rows,current) end
                            current.mode='own'; current.action='smart_missile'
                            button:SetLabel('✓ '..string.upper(context))
                            Change(); RefreshRows(); RefreshCatalog()
                        end,true)
                    end
                end
                OfferTarget('acu',82); OfferTarget('sacu',126)
                Button(conflictDialog,T('hotbuild.context_editor.s134'),424,214,112,function() CloseConflictDialog() end,true)
            end
            local sacu=CurrentRow('sacu')
            if selectedContext=='acu' and action.id=='overcharge' and (not sacu or sacu.mode=='inherit') then
                CloseConflictDialog()
                conflictOverlay=Panel(frame,0,0,1080,920,C.transparent); conflictOverlay.Depth:Set(function() return frame.Depth()+80 end)
                conflictOverlay.HandleEvent=function() return true end
                conflictDialog=Group(frame); L(conflictDialog):AtCenterIn(frame):Width(560):Height(176); conflictDialog.Depth:Set(function() return frame.Depth()+90 end)
                Theme.AnimateCentered(conflictDialog,frame,L)
                Escape.PushEscapeHandler(function() CloseConflictDialog() end); conflictEscape=true
                local back=Panel(conflictDialog,0,0,560,176,C.surface); back.Depth:Set(conflictDialog.Depth)
                Theme.Outline(back,L,560,176,C.selectedBorder)
                Text(conflictDialog,T('hotbuild.context_editor.s135'),24,24,20)
                Button(conflictDialog,T('hotbuild.context_editor.s136'),208,112,148,function()
                    local current=CurrentRow('sacu')
                    if not current then current={context='sacu'}; table.insert(draft.rows,current) end
                    if current.mode=='inherit' or not current.mode then
                        current.mode='own'; current.action='overcharge'
                        Change(); RefreshRows(); RefreshCatalog()
                    end
                    CloseConflictDialog()
                end,true)
                Button(conflictDialog,T('hotbuild.context_editor.s137'),368,112,148,function() CloseConflictDialog() end)
            end
        end
        catalogPanel.HandleEvent=function(self,e)
            if e.Type=='WheelRotation' then catalogTop=math.max(1,catalogTop+(e.WheelRotation>0 and -1 or 1)); RefreshCatalog(); return true end
            return false
        end
        function catalogPanel:GetScrollValues()
            local n=selectedContext and not TileLock(selectedContext) and table.getn(RowsFor(selectedContext)) or 0
            return 1,math.max(1,n),catalogTop,math.max(catalogTop,math.min(n,catalogTop+visibleActions-1))
        end
        function catalogPanel:IsScrollable(axis)
            return catalogMaxTop>1
        end
        function catalogPanel:ScrollSetTop(axis,value) catalogTop=math.floor(value); RefreshCatalog() end
        function catalogPanel:ScrollLines(axis,delta) self:ScrollSetTop(axis,catalogTop+delta) end
        function catalogPanel:ScrollPages(axis,delta) self:ScrollLines(axis,delta*math.max(1,visibleActions)) end
        local closeButton=Button(frame,T('hotbuild.context_editor.s138'),914,868,142,function()
            local function Close(accepted) if accepted and not embedded then frame:Destroy() end end
            if MayLeave('close',Close) then Close(true) end
        end)
        if embedded then closeButton:Hide() end
        frame.RequestClose=function()
            local function Close(accepted) if accepted and not embedded then frame:Destroy() end end
            if MayLeave('close',Close) then Close(true) end
        end
        frame.CanLeave=MayLeave
        RefreshRows(); RefreshSaved(); RefreshCatalog()
        local first=memory.bindingId and service.contextModel:Get(memory.bindingId)
        if not first then
            local i=1; while service.contextModel:Get('context_'..i) do i=i+1 end
            first={id='context_'..i,name=T('hotbuild.context_editor.s140'),rows={}}
        end
        Load(first); RefreshRows(); RefreshSaved(); RefreshCatalog()
        local problems=service.contextModel:GetQuarantine()
        if table.getn(problems)>0 then
            Status(T('hotbuild.problems.summary',table.getn(problems),problems[1].reason),true)
        end
    end)
    if not ok then frame:Destroy(); error(err) end
    return frame
end

