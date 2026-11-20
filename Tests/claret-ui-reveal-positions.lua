local created, destroyed, pending = {}, 0, nil
local now = 5
local fonts, textures = {}, {}
local requestedFont
local function option(value)
    local listeners = {}
    local obj = {value=value, OnChanged={}}
    function obj:Get() return self.value end
    function obj:Set(v) self.value=v; for _,fn in ipairs(listeners) do fn(self, v) end end
    function obj.OnChanged:Add(fn) table.insert(listeners,fn) end
    function obj.OnChanged:Remove(fn) for i,v in ipairs(listeners) do if v==fn then table.remove(listeners,i); return end end end
    return obj
end
local function prop(value)
    return setmetatable({Set=function(self, v) self.value=v end, value=value or 0}, {__call=function(self) if type(self.value)=='function' then return self.value() end; return self.value end})
end
local function control(parent)
    local c = {parent=parent, Left=prop(), Right=prop(), Top=prop(), Bottom=prop(), Width=prop(150), Height=prop(25), Depth=prop()}
    function c:EnableHitTest() end
    function c:DisableHitTest() end
    function c:SetNeedsFrameUpdate(v) self.updating=v end
    function c:SetSolidColor(value) self.color=value end
    function c:SetAlpha(value) self.alpha=value end
    function c:SetColor() end
    function c:SetDropShadow() end
    function c:SetTexture(path) self.texture=path; table.insert(textures,path) end
    function c:Destroy() destroyed=destroyed+1 end
    table.insert(created,c); return c
end
local layout = setmetatable({}, {__call=function(self, control) self.current=control; return self end,
    __index=function(_, key) return function(self, target)
        if key=='Fill' then self.current.fillTarget=target end
        return self
    end end})
local view = control()
function view:Project() return {x=20,y=30} end
local world = {viewLeft=view}
local scenario = {save='map', Options={TeamSpawn='random'}}
local markers = {ARMY_1={position={1,2,3}}, ARMY_2={position={4,5,6}}, ARMY_3={position={7,8,9}}, EXTRA={position={0,0,0}}}
local labels = {}
local env = setmetatable({
    ReUI={UI={FloorLayouter=function() return layout end}, ClaretCore={Localization={Text=function() return 'Possible start' end}}},
    import=function(path)
        if path == '/lua/maui/group.lua' then return {Group=control} end
        if path == '/lua/maui/bitmap.lua' then return {Bitmap=control} end
        if path == '/lua/ui/game/worldview.lua' then return world end
        if path == '/lua/maui/layouthelpers.lua' then return {GetPixelScaleFactor=function() return 1 end} end
        if path == '/mods/ClaretCore/modules/Theme.lua' then return {Fonts={body='font'}, Colors={canvas='dark'}, FactionIcons={AEON='aeon'}} end
        if path == '/lua/ui/uiutil.lua' then return {CreateText=function(parent, text, size, font) requestedFont=font; table.insert(labels,text); table.insert(fonts,size); local c=control(parent); c.markerText=true; c.Height:Set(12); c.Bottom:Set(function() return c.Top()+c.Height() end); return c end} end
        error(path)
    end,
    SessionGetScenarioInfo=function() return scenario end, GetFocusArmy=function() return 1 end,
    doscript=function(path,data) if path=='map' then data.Scenario={MasterChain={_MASTERCHAIN_={Markers=markers}}} end end,
    GetArmiesTable=function() return {armiesTable={[1]={name='ARMY_1'},[2]={name='ARMY_2',nickname='Enemy name',color='red',faction=1}}} end,
    IsAlly=function(a,b) return b==1 end, GetFrame=function() return view end,
    ForkThread=function(f) pending=f; return {} end, KillThread=function() end, WaitSeconds=function() end,
    GetGameTimeSeconds=function() return now end, Vector=function(x,y,z) return {x,y,z} end, WARN=function(s) error(s) end,
}, {__index=_G})
assert(loadfile('../mods/ClaretUI/modules/features/RevealPositions.lua','t',env))()
local function start(spawn)
    now=5; scenario.Options.TeamSpawn=spawn
    labels={}; fonts={}; textures={}; created={}; destroyed=0
    local cleanup, bindings = nil, {}
    local scope={Own=function(_,c) return c end, Defer=function(_,f) cleanup=f end,
        Bind=function(_,event,fn) event:Add(fn); table.insert(bindings,{event,fn}) end}
    local options={revealPositionsDuration=option(0), revealPositionsScale=option(100), revealPositionsFillTransparency=option(100)}
    env.Start(nil,scope,false,options); env.SetVisible(nil,true); pending()
    local updater=created[1]
    local function finish() cleanup(); for _,b in ipairs(bindings) do b[1]:Remove(b[2]) end end
    return options,updater,finish
end
local opts,updater,finish=start('random')
assert(#labels==3 and labels[1]=='Possible start' and labels[2]=='Possible start' and labels[3]=='Possible start')
local anonymousBackgrounds=0
opts.revealPositionsFillTransparency:Set(50)
for _, c in ipairs(created) do
    if c.color=='dark' then
        anonymousBackgrounds=anonymousBackgrounds+1
        assert(c.alpha==0.5 and c.Right.value==c.parent.Right, 'each background is attached to its marker')
    end
end
assert(anonymousBackgrounds==3)
env.SetVisible(nil,false); assert(destroyed==3 and not updater.updating); finish()
opts,updater,finish=start('fixed')
assert(#labels==1 and labels[1]=='Enemy name' and textures[1]=='/mods/ClaretUI/textures/factionmarks/aeon.dds' and #textures==1)
assert(fonts[1]==12 and requestedFont=='font', 'marker uses the shared theme font')
local underline
for _, c in ipairs(created) do if c.color=='red' then underline=c end end
assert(underline and underline.Height()==2, 'army-color underline is two pixels at default scale')
local background, label, icon
for _, c in ipairs(created) do
    if c.color=='dark' and c.alpha ~= nil then background=c end
    if c.markerText then label=c end
    if c.texture then icon=c end
end
assert(background and label and icon)
assert(background.alpha==0 and background.Left.value==label.Left and background.Right.value==background.parent.Right, 'background begins at the label and excludes the icon')
assert(icon.Width()==22 and icon.Height()==22 and icon.alpha==1, 'faction icon is larger and fully opaque')
opts.revealPositionsFillTransparency:Set(50)
assert(background.alpha==0.5 and icon.alpha==1 and destroyed==0, 'transparency updates existing background')
opts.revealPositionsFillTransparency:Set(0)
assert(background.alpha==1 and icon.alpha==1)
opts.revealPositionsFillTransparency:Set(100)
assert(background.alpha==0)
opts.revealPositionsScale:Set(150)
assert(fonts[2]==18 and destroyed==1, 'scale must recreate marker at new size')
for _, c in ipairs(created) do if c.color=='red' then underline=c end end
assert(underline.Height()==3, 'underline scales with the marker')
opts.revealPositionsDuration:Set(60)
now=59; updater.OnFrame(); assert(updater.updating)
now=60; updater.OnFrame(); assert(not updater.updating and destroyed==3, 'hide at one minute')
env.SetVisible(nil,false); env.SetVisible(nil,true); assert(not updater.updating, 'expired marker must not reappear')
opts.revealPositionsDuration:Set(300); assert(updater.updating, 'longer duration restores non-dismissed markers')
now=300; updater.OnFrame(); assert(not updater.updating)
opts.revealPositionsDuration:Set(600); assert(updater.updating)
now=600; updater.OnFrame(); assert(not updater.updating)
opts.revealPositionsDuration:Set(0); assert(updater.updating, 'never restores markers')
opts.revealPositionsScale:Set(50); assert(fonts[#fonts]==6)
opts.revealPositionsScale:Set(200); assert(fonts[#fonts]==24)
opts.revealPositionsScale:Set(135)
local markerText, markerIcon, markerLine
for _, c in ipairs(created) do
    if c.markerText then markerText=c end
    if c.texture=='/mods/ClaretUI/textures/factionmarks/aeon.dds' then markerIcon=c end
    if c.color=='red' then markerLine=c end
end
assert(markerText and markerIcon and markerLine)
assert(markerText.Left()==math.floor(markerText.Left()) and markerText.Top()==math.floor(markerText.Top()), 'text position is pixel-aligned')
assert(markerIcon.Right()==math.floor(markerIcon.Right()) and markerIcon.Top()==math.floor(markerIcon.Top()), 'icon position is pixel-aligned')
assert(markerLine.Top()==math.floor(markerLine.Top()), 'underline is pixel-aligned')
local marker
for _, item in ipairs(created) do if item.HandleEvent then marker=item end end
assert(marker and marker:HandleEvent({Type='ButtonPress'}))
assert(not updater.updating, 'dismissed last marker stops updates')
opts.revealPositionsScale:Set(100)
assert(not updater.updating, 'scaling does not restore dismissed markers')
finish()
opts,updater,finish=start('random_reveal'); assert(#labels==0); finish()
print('PASS: marker privacy, scaling, faction texture, durations and teardown')
