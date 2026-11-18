-- Editor integration with mock Maui controls; verifies interactions, not game rendering.
table.getn = function(t) return #t end
math.mod = math.fmod
local objects, edits, combos = {}, {}, {}
local function variable(value)
    return setmetatable({value=value, Set=function(self,v) self.value=v end}, {__call=function(self) return self.value end})
end
local function control(parent, text)
    local c = {parent=parent, text=text, visible=true, Width=variable(1920), Height=variable(1080), Depth=variable(0)}
    function c:SetAlpha(value) self.alpha=value end
    function c:SetNeedsFrameUpdate(value) self.updating=value end
    function c:OnDestroy() end
    function c:Destroy() self:OnDestroy(); self.destroyed=true end
    function c:SetText(value) self.text=value; if self.OnTextChanged then self:OnTextChanged(value) end end
    function c:GetText() return self.text or '' end
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
for i=1,45 do records[i]={id='unit'..i,name='Unit '..i,faction='UEF',tech='T1',kind='STRUCTURE',blueprint={},icon='icon',description='Description'} end
records[46]={id='claret_template_cycle',name='Template',faction='UEF',tech='T1',kind='STRUCTURE',blueprint={},icon='icon',templateData={2,2,{'unit1',0,0,0}}}
local catalog={Get=function(self,id) for _,r in ipairs(records) do if r.id==id then return r end end end,
    List=function(self,filters)
        filters=filters or {}
        local faction=filters.faction or 'ALL'
        local search=filters.search or ''
        if faction~='ALL' and faction~='UEF' then return {} end
        local result={}
        for _,r in ipairs(records) do if search=='' or r.name:find(search,1,true) then result[#result+1]=r end end
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


local mode={false,{}}
modules['/lua/ui/game/commandmode.lua']={GetCommandMode=function() return mode end}
local menuModule=setmetatable({},{__index=env})
assert(loadfile('../mods/ClaretHotbuild/modules/CycleMenu.lua','t',menuModule))()
local parent=control()
local first=#objects+1
local menu=menuModule.Create(parent)
local preview=objects[first]
mode={'build',{name='unit1'}}
menu:Show('Test',{records[1],records[2]},'unit1')
assert(preview.visible and preview.updating)
preview:OnFrame(0.8); assert(preview.visible)
menu:Show('Test',{records[1],records[2]},'unit1')
preview:OnFrame(0.8); assert(preview.visible,'keypress resets timeout')
preview:OnFrame(0.4); assert(not preview.visible and not preview.updating)
menu:Show('Test',{records[1],records[2]},'unit1');mode={false,{}};preview:OnFrame(0.01)
assert(not preview.visible,'cancel hides preview')
menu:Destroy(); assert(preview.destroyed)
modules['/mods/ClaretHotbuild/modules/Model.lua']=modelModule
local contextActionsModule=setmetatable({},{__index=env})
assert(loadfile('../mods/ClaretHotbuild/modules/ContextActions.lua','t',contextActionsModule))()
modules['/mods/ClaretHotbuild/modules/ContextActions.lua']=contextActionsModule
local contextModelModule=setmetatable({},{__index=env})
assert(loadfile('../mods/ClaretHotbuild/modules/ContextModel.lua','t',contextModelModule))()
modules['/mods/ClaretHotbuild/modules/ContextModel.lua']=contextModelModule
local repeatModule=setmetatable({},{__index=env})
assert(loadfile('../mods/ClaretHotbuild/modules/ContextRepeat.lua','t',repeatModule))()
modules['/mods/ClaretHotbuild/modules/ContextRepeat.lua']=repeatModule
modules['/mods/ClaretHotbuild/modules/Compatibility.lua']={
 ValidateBinding=function() return true end,
 ValidateContext=function() return true end,
}
modules['/mods/ClaretHotbuild/modules/Catalog.lua']={Create=function() return catalog end}
local templateModule=setmetatable({},{__index=env})
assert(loadfile('../mods/ClaretHotbuild/modules/TemplateCatalog.lua','t',templateModule))()
modules['/mods/ClaretHotbuild/modules/TemplateCatalog.lua']=templateModule
modules['/mods/ClaretHotbuild/modules/Keys.lua']={Create=function() return {Apply=function() return true end,Stop=function() end} end}
modules['/mods/ClaretHotbuild/modules/KeyboardBindings.lua']={Create=function() return {Refresh=function() return true end,GetPairError=function() return nil end} end}
modules['/mods/ClaretHotbuild/modules/Adapter.lua']={RegisterActions=function() end,Create=function()
 return {
 Context=function() return {plans={}} end,
 CanBuild=function(self,id,context)
  if id=='unit1' or id=='unit2' or id=='claret_template_cycle' then context.plans[id]={placement=true}; return true end
  return false
 end,
 Build=function(self,id) mode={'build',{name=id=='claret_template_cycle' and 'unit1' or id,claretEntry=id=='claret_template_cycle' and id or nil}}; return true end,
 }
end}
modules['/mods/ClaretHotbuild/modules/CycleMenu.lua']=menuModule
local hotbuildPrefs={version=1,bindings={{id='b1',name='Cycle',key='',entries={{kind='blueprint',id='unit1'},{kind='blueprint',id='unit3'},{kind='blueprint',id='claret_template_cycle'},{kind='blueprint',id='unit2'}}}}}
modules['/lua/user/prefs.lua']={GetFromCurrentProfile=function(key)
 if key=='ClaretHotbuild' then return hotbuildPrefs end
 return nil
end}
env.__blueprints={}; env.LOC=function(t) return t end
env.GetFrame=function() return parent end
env.IsDestroyed=function(c) return not c or c.destroyed end
env.WARN=function(message) error(message) end
local runtime=setmetatable({},{__index=env})
assert(loadfile('../mods/ClaretHotbuild/modules/Runtime.lua','t',runtime))()
local service=runtime.Create(false)
local cleanup
service:Start({Defer=function(self,fn) cleanup=fn end})
mode={false,{}}
local ok,id=service:Execute('b1'); assert(ok and id=='unit1')
local active
for _,c in ipairs(objects) do if c.OnFrame and c.visible and not c.destroyed then active=c end end
assert(active and active.updating)
ok,id=service:Execute('b1'); assert(ok and id=='claret_template_cycle','skip unavailable and advance into template')
active:OnFrame(0.01); assert(active.visible,'template preview follows claretEntry, not first blueprint name')
ok,id=service:Execute('b1'); assert(ok and id=='unit2','advance from template into next building')
mode={false,{}};active:OnFrame(0.01);assert(not active.visible)
ok,id=service:Execute('b1');assert(ok and id=='unit1','restart after cancel')
cleanup(); assert(active.destroyed and not service.active)
service:Destroy()
print('PASS: preview timer reset, cancel, filtering, cycle order, restart and cleanup')
