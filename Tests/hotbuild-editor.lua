-- Editor integration with mock Maui controls; verifies interactions, not game rendering.
local testLocalization = dofile('Tests/localization-test-helper.lua')
table.getn = function(t) return #t end
math.mod = math.fmod
local objects, edits, combos = {}, {}, {}
local function variable(value)
    return setmetatable({value=value, Set=function(self,v) self.value=v end}, {__call=function(self) return self.value end})
end
local function control(parent, text)
    local c = {parent=parent, text=text, visible=true, Width=variable(1920), Height=variable(1080), Depth=variable(0)}
    function c:OnDestroy() end
    function c:Destroy() self:OnDestroy(); self.destroyed=true end
    function c:SetText(value) self.text=value; if self.OnTextChanged then self:OnTextChanged(value) end end
    function c:GetText() return self.text or '' end
    function c:SetColor() end
    function c:SetSolidColor(color) self.color=color end
    function c:DisableHitTest() end
    function c:SetTexture(path) self.texture=path end
    function c:SetNeedsFrameUpdate(value) self.needsFrameUpdate=value end
    function c:Show() self.visible=true end
    function c:Hide() self.visible=false end
    objects[#objects+1]=c
    return c
end
local function layout(c)
    local l = {}
    function l:Width(w) c.Width:Set(w); return self end
    function l:Height(h) c.Height:Set(h); return self end
    function l:AtLeftTopIn(parent,x,y) c.x=x; c.y=y; return self end
    function l:AtCenterIn(parent) return self end
    return l
end
local modules = {
    ['/lua/maui/group.lua']={Group=control},
    ['/lua/maui/bitmap.lua']={Bitmap=control},
    ['/lua/ui/dialogs/eschandler.lua']={PushEscapeHandler=function() end,PopEscapeHandler=function() end},
    ['/lua/maui/edit.lua']={Edit=function(parent) local c=control(parent); edits[#edits+1]=c; return c end},
    ['/lua/maui/layouthelpers.lua']={GetPixelScaleFactor=function() return 1 end},
    ['/lua/ui/game/tooltip.lua']={DestroyMouseoverDisplay=function() end,AddAutoUpdatedControlTooltip=function() end},
    -- Kept so an accidental Combo creation would still run; the editor must not create one.
    ['/lua/ui/controls/combo.lua']={Combo=function(parent)
        local c=control(parent); combos[#combos+1]=c
        function c:AddItems(items,index) self.items=items; self.selected=index end
        function c:ClearItems() self.items={} end
        function c:SetItem(index) self.selected=index end
        return c
    end},
    ['/lua/ui/uiutil.lua']={bodyFont='Arial', SetupEditStd=function() end, CreateText=control,
        UIFile=function(path) return path end,
        CreateVertScrollbarFor=function(panel)
            assert(panel.GetScrollValues and panel.ScrollSetTop and panel.ScrollLines and panel.ScrollPages)
            panel:GetScrollValues()
            return control(panel)
        end},
}
local equivalenceModule = {}
assert(loadfile('../mods/ClaretHotbuild/modules/Equivalents.lua','t',setmetatable(equivalenceModule,{__index=_G})))()
modules['/mods/ClaretHotbuild/modules/Equivalents.lua']=equivalenceModule
modules['/lua/keymap/unitkeygroups.lua']={unitkeygroups={}}
local themeModule=setmetatable({},{__index=_G})
themeModule.import=function(path) return assert(modules[path],path) end
assert(loadfile('../mods/ClaretCore/modules/Theme.lua','t',themeModule))()
modules['/mods/ClaretCore/modules/Theme.lua']=themeModule
local env=setmetatable({ReUI={ClaretCore={Localization=testLocalization},UI={FloorLayouter=function() return layout end}},import=function(path) return assert(modules[path],path) end},{__index=_G})
local records={}
for i=1,45 do records[i]={id='unit'..i,name='Unit '..i,faction='UEF',tech='T1',icon='icon',description='Description'} end
local catalog={Get=function(self,id) for _,r in ipairs(records) do if r.id==id then return r end end end,
    List=function(self,filters)
        filters=filters or {}
        local faction=filters.faction or 'ALL'
        local search=filters.search or ''
        if faction=='ALL' then faction=nil end
        local result={}
        for _,r in ipairs(records) do if (not faction or r.faction==faction) and (search=='' or r.name:find(search,1,true)) then result[#result+1]=r end end
        return result
    end}
local modelModule=setmetatable({},{__index=_G})
assert(loadfile('../mods/ClaretHotbuild/modules/Model.lua','t',modelModule))()
local model=modelModule.Create({version=1,bindings={{id='b1',name='First',key='',entries={}}}})
local service={model=model, Catalog=function() return catalog end}
function service:Commit(binding,removeId)
    if self.fail then return false,'Disk error' end
    if removeId then return model:Delete(removeId) end
    return model:Put(binding)
end
assert(loadfile('../mods/ClaretHotbuild/modules/Editor.lua','t',env))()

-- Mock controls are never garbage collected: walk the parent chain so destroyed
-- popups and dialogs cannot answer a later lookup.
local function alive(c)
    local node=c
    while node do
        if node.destroyed then return false end
        node=node.parent
    end
    return true
end
local function shown(c)
    local node=c
    while node do
        if node.visible==false then return false end
        node=node.parent
    end
    return true
end
local function hasText(text,predicate)
    for _,c in ipairs(objects) do
        if c.text==text and alive(c) and shown(c) and (not predicate or predicate(c)) then return c end
    end
end
local function press(text,predicate)
    for _,c in ipairs(objects) do
        local parent=c.parent
        if c.text==text and parent and parent.HandleEvent and alive(c) and shown(c)
            and (not predicate or predicate(parent,c)) then
            parent:HandleEvent({Type='ButtonPress',Modifiers={Left=true}})
            return parent
        end
    end
    error('missing control '..text)
end
local function clickCell(cell,right)
    assert(cell,'missing cell')
    cell:HandleEvent({Type='ButtonPress',Modifiers=right and {Right=true} or {Left=true}})
end
local function byPlacement(predicate)
    local found
    for _,c in ipairs(objects) do if alive(c) and predicate(c) then found=c end end
    return found
end
local function selectorButton() return byPlacement(function(c) return c.x==24 and c.y==88 and c.Width()==270 and c.HandleEvent~=nil end) end
local function listPanel() return byPlacement(function(c) return c.x==24 and c.Width()==372 and c.Height()==354 and c.HandleEvent~=nil end) end
local function closeButton() return byPlacement(function(c) return c.x==1038 and c.y==8 and c.Width()==30 and c.HandleEvent~=nil end) end
local function viewportControl() return byPlacement(function(c) return c.x==74 and c.y==195 and c.Width()==985 and c.HandleEvent~=nil end) end
local function buildCell(viewport,row)
    for _,c in ipairs(objects) do
        if alive(c) and c.parent==viewport and c.x==0 and c.y==(row-1)*65 and c.Width()==232 then return c end
    end
end
local function rowControl(row,glyph)
    local y=195+(row-1)*65+(glyph=='↑' and 8 or 34)
    local label=byPlacement(function(c) return c.text==glyph and c.parent and c.parent.x==48 and c.parent.y==y end)
    return label and label.parent
end
local function selectorLabel()
    return byPlacement(function(c) return c.parent and c.parent.x==24 and c.parent.y==88 and c.x==12 and c.y==7 end)
end
local function pickerSearchField()
    for i=#edits,1,-1 do
        local field=edits[i]
        if alive(field) and field.Width()==656 then return field end
    end
end
local function pickerRow(text)
    for _,c in ipairs(objects) do
        if c.text==text and alive(c) and shown(c) and c.parent and c.parent.Width()==662 and c.parent.HandleEvent then return c.parent end
    end
end
local function pickerContainer() return byPlacement(function(c) return c.x==18 and c.y==105 and c.Width()==662 and c.Height()==478 and c.HandleEvent~=nil end) end
local function pickRecord(id)
    local container=assert(pickerContainer(),'the picker opened without a catalog list')
    assert(pickerRow(id),'record '..id..' is not on the visible catalog page')
    press(id)
    return container
end

local frame=env.Create(control(),service,nil,{bindingId='b1'})
-- The current editor has one persistent field (the binding name) and builds the
-- picker search field per opening; it never creates a Maui Combo.
assert(#edits==1 and #combos==0,'editor fields: edits='..#edits..' combos='..#combos)
assert(edits[1]:GetText()=='First','the saved binding name is loaded into the name field')
-- Binding selection is a button plus a popup list instead of a Combo.
assert(not listPanel(),'the binding list stays closed until the selector is pressed')
selectorButton():HandleEvent({Type='ButtonPress'})
local list=assert(listPanel(),'the selector button opens the saved-binding list')
assert(press('First',function(parent) return parent.parent==list and parent.x==8 and parent.y==6 end),
    'the first list row is the saved binding')
assert(edits[1]:GetText()=='First','selecting the list row loads that binding')
assert(not listPanel(),'selecting a row closes the list')
selectorButton():HandleEvent({Type='ButtonPress'}); assert(listPanel(),'the selector reopens the list')
selectorButton():HandleEvent({Type='ButtonPress'}); assert(not listPanel(),'the selector closes the list again')

local viewport=assert(viewportControl(),'build viewport')
clickCell(buildCell(viewport,1))
assert(#edits==2,'opening the picker creates exactly one search field')
press('Unit 1')
assert(frame.CanLeave('section:test',function() end)==false,'an edited draft blocks navigation')
press('Отмена')
assert(#model:Get('b1').entries==0,'the draft is not persisted before saving')
clickCell(buildCell(viewport,2))
press('Unit 12')
press('Сохранить')
assert(#model:Get('b1').entries==2,'saving stores both picked entries')
assert(model:Get('b1').entries[1].id=='unit1' and model:Get('b1').entries[2].id=='unit12','entries keep pick order')
-- Build rows expose the move controls the editor creates for row priority.
assert(rowControl(1,'↑') and rowControl(1,'↓'),'build rows expose move-up and move-down controls')
rowControl(2,'↑'):HandleEvent({Type='ButtonPress',Modifiers={Left=true}})
press('Сохранить')
assert(model:Get('b1').entries[1].id=='unit12','moving the second row up promotes it')
rowControl(1,'↓'):HandleEvent({Type='ButtonPress',Modifiers={Left=true}})
press('Сохранить')
assert(model:Get('b1').entries[1].id=='unit1' and model:Get('b1').entries[2].id=='unit12','moving the first row down restores the order')
-- Wheel scrolls the picker catalog, the native scrollbar reaches the final objects.
clickCell(buildCell(viewport,3))
local container=assert(pickerContainer(),'the picker exposes a scrollable catalog')
assert(pickerRow('Unit 1'),'the first catalog page starts with the first record')
container:HandleEvent({Type='WheelRotation',WheelRotation=-1})
assert(select(3,container:GetScrollValues())==2,'the wheel scrolls the catalog one row at a time')
container:ScrollSetTop(nil,999)
assert(select(3,container:GetScrollValues())==35,'the scrollbar reaches the last page of 45 records')
assert(pickerRow('Unit 9'),'the final record becomes reachable')
-- Search filters the catalog and resets the scroll; clearing restores the list.
local search=assert(pickerSearchField(),'the picker creates its own search field')
search:SetText('Unit 4')
assert(select(3,container:GetScrollValues())==1,'search resets the catalog scroll to the top')
assert(pickerRow('Unit 4') and pickerRow('Unit 45') and not pickerRow('Unit 3'),'search narrows the catalog to matching labels')
search:SetText('')
assert(pickerRow('Unit 1'),'clearing the search restores the full catalog')
container:ScrollSetTop(nil,999)
press('Unit 9')
press('Сохранить')
assert(#model:Get('b1').entries==3 and model:Get('b1').entries[3].id=='unit9','the third row is saved in order')
-- New draft, failed save, dirty-close protection, discard, successful save.
press('Новый хотбилд')
assert(model:Get('b2')==nil,'a new draft is not persisted immediately')
assert(edits[1]:GetText()=='New binding','a new draft starts with the default binding name')
assert(selectorLabel() and selectorLabel().text=='New binding  • *','the selector marks the unsaved draft')
edits[1]:SetText('Second')
clickCell(buildCell(viewport,1))
press('Unit 1')
service.fail=true; press('Сохранить')
assert(not model:Get('b2'),'a failed save leaves the draft unsaved')
assert(not frame.destroyed,'a failed save keeps the editor open')
service.fail=false; press('Сохранить')
assert(model:Get('b2') and model:Get('b2').name=='Second','a repeated save persists the draft')
assert(model:Get('b2').entries[1].id=='unit1','the saved draft keeps its grid')
assert(selectorLabel() and selectorLabel().text=='Second','the selector shows the saved draft name')
-- A dirty draft blocks switching bindings from the list; cancel keeps it.
edits[1]:SetText('Unsaved')
selectorButton():HandleEvent({Type='ButtonPress'})
local switchList=assert(listPanel(),'the selector list opens for switching')
press('First',function(parent) return parent.parent==switchList and parent.x==8 and parent.y==6 end)
assert(edits[1]:GetText()=='Unsaved','a dirty draft cannot switch bindings from the list')
assert(hasText('Несохранённые изменения'),'the blocked switch asks about the draft')
press('Отмена')
assert(model:Get('b2').name=='Second','cancelling the switch keeps the saved binding')
assert(edits[1]:GetText()=='Unsaved','cancelling the switch keeps the draft')
-- Discarding restores the saved draft, then the same row switches for real.
press('First',function(parent) return parent.parent==switchList and parent.x==8 and parent.y==6 end)
press('Не сохранять')
assert(edits[1]:GetText()=='Second','discarding restores the saved draft name')
assert(model:Get('b2').name=='Second','discarding does not modify the saved binding')
press('First',function(parent) return parent.parent==switchList and parent.x==8 and parent.y==6 end)
assert(edits[1]:GetText()=='First','a clean draft switches to the chosen binding')
assert(not listPanel(),'switching closes the list')
-- Existing binding deletion remains available and keeps its confirmation behavior.
selectorButton():HandleEvent({Type='ButtonPress'})
local deleteList=assert(listPanel(),'the selector list opens for deletion')
local deleteBinding
for _,c in ipairs(objects) do
    if c.text=='×' and alive(c) and shown(c) and c.parent and c.parent.x==314 and c.parent.y==6 and c.parent.parent==deleteList then
        deleteBinding=c.parent
    end
end
assert(deleteBinding,'missing binding delete control')
deleteBinding:HandleEvent({Type='ButtonPress',Modifiers={Left=true}})
assert(model:Get('b1'),'the first click only arms deletion')
deleteBinding:HandleEvent({Type='ButtonPress',Modifiers={Left=true}})
assert(not model:Get('b1') and model:Get('b2'),'the second click deletes the chosen binding')
assert(edits[1]:GetText()=='Second','the editor falls back to the remaining binding')
closeButton():HandleEvent({Type='ButtonPress'})
assert(frame.destroyed,'a clean editor closes')
-- Closing a dirty editor is blocked; discarding closes it without saving.
local guarded=env.Create(control(),service,nil,{bindingId='b2'})
edits[#edits]:SetText('Dirty name')
closeButton():HandleEvent({Type='ButtonPress'})
assert(not guarded.destroyed,'closing a dirty editor is blocked')
assert(hasText('Несохранённые изменения'),'the dirty close shows the draft dialog')
press('Отмена')
assert(not guarded.destroyed,'cancelling the close confirmation keeps the editor open')
closeButton():HandleEvent({Type='ButtonPress'})
assert(hasText('Несохранённые изменения'),'the draft dialog returns on the next close')
press('Не сохранять')
assert(guarded.destroyed,'discarding closes the editor')
assert(model:Get('b2').name=='Second','discarding keeps the saved binding untouched')
print('PASS: redesigned editor creation, filtering, scroll, add/remove, save failure, dirty guard and reopen selection')

-- Cross-faction UX: one click, one visual group, single-cell removal, partial completion.
objects, edits, combos = {}, {}, {}
records = {}
local nativeGroups={T1_Air_Scout={'uea0101','uaa0101','ura0101','xsa0101'}, Land_Factory={'ueb0101','uab0101','urb0101','xsb0101'}}
local factions={'UEF','AEON','CYBRAN','SERAPHIM'}
for _,key in ipairs({'T1_Air_Scout','Land_Factory'}) do
    for i,id in ipairs(nativeGroups[key]) do
        records[#records+1]={id=id,name=id,description=key,faction=factions[i],tech='T1',kind=key=='Land_Factory' and 'STRUCTURE' or 'AIR',icon='icon'}
    end
end
modules['/lua/keymap/unitkeygroups.lua'].unitkeygroups=nativeGroups
model=modelModule.Create({version=1,bindings={{id='b1',name='Shared',key='',entries={}}}})
service.model=model
service.fail=false
local shared=env.Create(control(),service,nil,{bindingId='b1'})
local sharedViewport=assert(viewportControl(),'build viewport')
local function unitSlot(domainIndex,col,tierIndex)
    local tileX=74+(col-1)*247
    local tileY=528+(domainIndex-1)*92+24
    for _,c in ipairs(objects) do
        if alive(c) and c.Width()==76 and c.Height()==72 and c.x==(tierIndex-1)*78 and c.y==0
            and c.parent and c.parent.x==tileX and c.parent.y==tileY then return c end
    end
end
local function entryIds()
    local ids={}
    for _,entry in ipairs(model:Get('b1').entries) do ids[#ids+1]=entry.id end
    return ids
end
local function countEntry(id)
    local count=0
    for _,entry in ipairs(model:Get('b1').entries) do if entry.id==id then count=count+1 end end
    return count
end
-- domains: LAND, AIR, NAVAL, GATE; tier slots: T1 at x=0.
clickCell(unitSlot(2,1,1)); pickRecord('uea0101'); press('Сохранить')
assert(#entryIds()==4,'one click fills all four faction counterparts')
for _,id in ipairs(nativeGroups.T1_Air_Scout) do assert(countEntry(id)==1,'missing counterpart '..id) end
clickCell(unitSlot(2,2,1)); pickRecord('uaa0101'); press('Сохранить')
assert(#entryIds()==4,'an already assigned counterpart is not duplicated')
clickCell(buildCell(sharedViewport,1)); pickRecord('ueb0101'); press('Сохранить')
assert(#entryIds()==8,'the factory group adds four more cells')
local sharedGrid=model:Get('b1').grid
assert(#sharedGrid.buildings==1 and sharedGrid.buildings[1].UEF=='ueb0101' and sharedGrid.buildings[1].SERAPHIM=='xsb0101',
    'one build row holds the whole faction group')
-- Right-click clears exactly one faction cell; the editor has no group-wide mode.
clickCell(unitSlot(2,2,1),true); press('Сохранить')
assert(#entryIds()==7,'right-click removes the single assigned cell')
assert(countEntry('uaa0101')==0,'only the clicked faction cell is cleared')
assert(countEntry('uea0101')==1,'the other faction cells stay assigned')
clickCell(unitSlot(2,2,1)); pickRecord('uaa0101'); press('Сохранить')
assert(#entryIds()==8,'re-adding completes the partial group')
for _,entry in ipairs(model:Get('b1').entries) do assert(countEntry(entry.id)==1,'duplicate entry '..entry.id) end
closeButton():HandleEvent({Type='ButtonPress'})
assert(shared.destroyed,'a clean cross-faction editor closes')
print('PASS: cross-faction add, deduplication, single-cell removal and partial completion')
