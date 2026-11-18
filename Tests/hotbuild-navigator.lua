-- Navigator routing and embedded-editor lifecycle; mocked Maui controls do not verify FAF rendering.
table.getn = function(t) return #t end
local objects = {}
local function variable(value)
    return setmetatable({value=value, Set=function(self,v) self.value=v end}, {__call=function(self) return self.value end})
end
local function control(parent, text)
    local c = {parent=parent, text=text, Width=variable(0), Height=variable(0), Depth=variable(0)}
    function c:SetSolidColor(value) self.color=value end
    function c:SetColor(value) self.textColor=value end
    function c:SetText(value) self.text=value end
    function c:DisableHitTest() end
    function c:OnDestroy() end
    function c:Destroy() self:OnDestroy(); self.destroyed=true end
    objects[#objects+1]=c
    return c
end
local function layout(c)
    local l={}
    function l:Width(w) c.Width:Set(w); return self end
    function l:Height(h) c.Height:Set(h); return self end
    function l:AtLeftTopIn(parent,x,y) c.x=x; c.y=y; return self end
    function l:AtCenterIn(parent) c.centered=true; return self end
    return l
end
local modules={
    ['/lua/maui/group.lua']={Group=control},
    ['/lua/maui/bitmap.lua']={Bitmap=control},
    ['/lua/maui/layouthelpers.lua']={GetPixelScaleFactor=function() return 1 end},
    ['/lua/ui/uiutil.lua']={bodyFont='Arial',CreateText=control},
}
local themeModule=setmetatable({},{__index=_G})
themeModule.import=function(path) return assert(modules[path],path) end
assert(loadfile('../mods/ClaretCore/modules/Theme.lua','t',themeModule))()
modules['/mods/ClaretCore/modules/Theme.lua']=themeModule
local env=setmetatable({
    ReUI={UI={FloorLayouter=function(scale) return function(c) return layout(c) end end}},
    import=function(path) return assert(modules[path],path) end,
},{__index=_G})
local navigatorModule=setmetatable({},{__index=env})
assert(loadfile('../mods/ClaretHotbuild/modules/Navigator.lua','t',navigatorModule))()

local parent=control(nil)
local opens, children={},{}
local function page(id)
    return {id=id,title=id,open=function(host,embedded)
        opens[#opens+1]={id=id,host=host,scale=embedded.scale,resize=embedded.setHeight}
        local child=control(host)
        child.CanLeave=function(intent,continuation)
            child.pending=continuation
            return false
        end
        children[id]=child
        return child
    end}
end
local requestedHeight
local root=navigatorModule.Create(parent,{scale=1,setHeight=function(value) requestedHeight=value end},{page('keyboard'),page('hotbuild'),page('contexts')})
assert(root and #opens==1 and opens[1].id=='keyboard','first page opens by default')
local content=opens[1].host
assert(root.Width()==1080 and root.Height()==984,'wrapper remains within inline host bounds')
assert(content.y==56 and content.Height()<=920 and content.x>=0 and content.x+content.Width()<=1080,
    'embedded viewport is centered and stays inside wrapper')
assert(920*opens[1].scale<=content.Height()+0.001,'full-height child editor fits its viewport')
opens[1].resize(570)
assert(math.abs(requestedHeight-(56+570*opens[1].scale))<0.01, 'keyboard height is forwarded with navigation spacing and scale')
local tabs={}
for _,object in ipairs(objects) do
    if object.parent==root and object.HandleEvent then tabs[#tabs+1]=object end
end
assert(#tabs==3,'three page tabs were created')

tabs[2]:HandleEvent({Type='ButtonPress'})
assert(#opens==1 and not children.keyboard.destroyed,'pending leave preserves current draft/editor')
children.keyboard.pending(true)
assert(requestedHeight==nil, 'other pages restore standard height')
assert(#opens==2 and opens[2].id=='hotbuild' and children.keyboard.destroyed,
    'approved async leave destroys old editor and opens requested page')
opens[1].resize(570); assert(requestedHeight==nil, 'old page cannot resize the active page')
tabs[3]:HandleEvent({Type='ButtonPress'})
children.hotbuild.pending(false)
assert(#opens==2 and not children.hotbuild.destroyed,'rejected leave keeps the current editor and draft')
tabs[3]:HandleEvent({Type='ButtonPress'})
children.hotbuild.pending(true)
assert(#opens==3 and opens[3].id=='contexts' and children.hotbuild.destroyed,
    'approved retry switches after preserving the draft until confirmation')

print('PASS: Hotbuild navigator default view, host bounds, embedded scale, editor lifecycle and asynchronous leave confirmation')
