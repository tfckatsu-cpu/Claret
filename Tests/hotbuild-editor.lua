-- Editor integration with mock Maui controls; verifies interactions, not game rendering.
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
    function c:SetColor() end
    function c:SetSolidColor(color) self.color=color end
    function c:DisableHitTest() end
    function c:SetTexture(path) self.texture=path end
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
    ['/lua/maui/edit.lua']={Edit=function(parent) local c=control(parent); edits[#edits+1]=c; return c end},
    ['/lua/maui/layouthelpers.lua']={GetPixelScaleFactor=function() return 1 end},
    ['/lua/ui/game/tooltip.lua']={DestroyMouseoverDisplay=function() end,AddAutoUpdatedControlTooltip=function() end},
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
local env=setmetatable({ReUI={UI={FloorLayouter=function() return layout end}},import=function(path) return assert(modules[path],path) end},{__index=_G})
local records={}
for i=1,45 do records[i]={id='unit'..i,name='Unit '..i,faction='UEF',tech='T1',icon='icon',description='Description'} end
local catalog={Get=function(self,id) for _,r in ipairs(records) do if r.id==id then return r end end end,
    List=function(self,filters)
        if filters.faction~='ALL' and filters.faction~='UEF' then return {} end
        local result={}
        for _,r in ipairs(records) do if filters.search=='' or r.name:find(filters.search,1,true) then result[#result+1]=r end end
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
local frame=env.Create(control(),service)
local function press(text)
    for _,c in ipairs(objects) do
        if c.text==text and c.parent and c.parent.HandleEvent and not c.parent.destroyed then
            c.parent:HandleEvent({Type='ButtonPress'}); return
        end
    end
    error('missing control '..text)
end
local function shown(text)
    for _,c in ipairs(objects) do if c.text==text and c.parent and c.parent.visible then return c.parent end end
end
assert(#edits==2 and #combos==5)
assert(combos[1].items[1]=='First')
press('Unit 1')
assert(not frame.MayLeave())
press('Unit 2')
press('Сохранить бинд')
assert(#model:Get('b1').entries==2)
-- Row rearrangement controls are absent; right-click removal remains available.
for _,c in ipairs(objects) do assert(c.text~='↑' and c.text~='↓','row move controls must not be present') end
-- Existing binding deletion remains available and keeps its confirmation behavior.
local deleteBinding
for _,c in ipairs(objects) do if c.text=='×' and c.parent and c.parent.x==236 then deleteBinding=c.parent; break end end
assert(deleteBinding,'missing binding delete control')
deleteBinding:HandleEvent({Type='ButtonPress',Modifiers={Left=true}})
deleteBinding:HandleEvent({Type='ButtonPress',Modifiers={Left=true}})
assert(not model:Get('b1'))
-- Wheel scrolls the grid, native scrollbar can reach the final objects.
frame.catalogScroll:HandleEvent({Type='WheelRotation',WheelRotation=-120})
assert(frame.catalogScroll.top==2)
frame.catalogScroll:ScrollSetTop(nil,999)
assert(frame.catalogScroll.top==12 and shown('Unit 45'))
press('Unit 45'); press('Сохранить бинд')
assert(model:Get('b1').entries[2].id=='unit45')
-- Filters and search reset the scroll and preserve the chosen label.
combos[2]:OnClick(3)
assert(combos[2].selected==3 and frame.catalogScroll.total==0)
combos[2]:OnClick(1)
edits[2]:SetText('Unit 45')
assert(frame.catalogScroll.total==1 and shown('Unit 45'))
-- New draft, failed save, dirty-close protection, discard, successful save.
press('+ Новый бинд'); edits[1]:SetText('Second'); press('Unit 45')
service.fail=true; press('Сохранить бинд')
assert(not model:Get('b2')); press('Закрыть'); assert(not frame.destroyed)
service.fail=false; press('Сохранить бинд'); assert(model:Get('b2').name=='Second')
edits[1]:SetText('Unsaved'); combos[1]:OnClick(1)
assert(not frame.MayLeave())
press('Отменить'); assert(model:Get('b2').name=='Second')
combos[1]:OnClick(1); assert(edits[1].text=='First')
press('Закрыть'); assert(frame.destroyed)
print('PASS: redesigned editor creation, filtering, scroll, add/remove, save failure, dirty guard and reopen selection')

-- Cross-faction UX: one click, one visual group, atomic reorder/removal, partial completion.
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
local shared=env.Create(control(),service)
press('uea0101'); press('Сохранить бинд')
assert(#model:Get('b1').entries==4)
press('uaa0101'); press('Сохранить бинд')
assert(#model:Get('b1').entries==4, 'no duplicate counterparts')
press('ueb0101'); press('Сохранить бинд')
assert(#model:Get('b1').entries==8)
for _,c in ipairs(objects) do assert(c.text~='↑' and c.text~='↓','row move controls must not be present') end
local remove
for _,c in ipairs(objects) do if c.text=='×' and c.parent and c.parent.x==236 then remove=c.parent; break end end
assert(remove,'missing binding delete control')
remove:HandleEvent({Type='ButtonPress',Modifiers={Left=true}}); press('Сохранить бинд')
assert(#model:Get('b1').entries==4 and model:Get('b1').entries[1].id=='uea0101','remove whole group')
local remove
for _,c in ipairs(objects) do if c.text=='×' and c.parent and c.parent.x==236 then remove=c.parent; break end end
assert(remove,'missing binding delete control')
remove:HandleEvent({Type='ButtonPress',Modifiers={Left=true}}); press('Сохранить бинд')
combos[5]:OnClick(2); press('uea0101'); press('Сохранить бинд')
assert(#model:Get('b1').entries==1)
combos[5]:OnClick(1); press('uaa0101'); press('Сохранить бинд')
assert(#model:Get('b1').entries==4,'complete partial group without duplicate')
press('Закрыть')
print('PASS: cross-faction add, deduplication, removal, single mode and partial completion')
