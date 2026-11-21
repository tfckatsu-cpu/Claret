table.getn = function(t) return #t end
table.getsize = function(t)
    local count=0
    for _ in pairs(t) do count=count+1 end
    return count
end

local controls, selection, candidates, onScreen = {}, {}, {}, {}
local now, beat, order, paused = 0
local gameTime, discoveryCalls, commandMode = 0, 0, false
local army = 1
local layoutLog, pendingPosition, savedPosition
local function property(default)
    return setmetatable({value=default, Set=function(self, value) self.value=value end},
        {__call=function(self)
            local meta = getmetatable(self.value)
            if type(self.value) == 'function' or (meta and meta.__call) then return self.value() end
            return self.value
        end})
end
local function control(parent)
    local c = {parent=parent, Width=property(500), Height=property(500), Depth=property(0),
        Left=property(0), Top=property(0), Right=property(500), Bottom=property(500)}
    c.Right:Set(function() return c.Left() + c.Width() end)
    c.Bottom:Set(function() return c.Top() + c.Height() end)
    function c:GetRootFrame() return controls[1] end
    function c:SetFont(_, size) self.fontSize=size end
    function c:DisableHitTest() self.hitTest=false end
    function c:EnableHitTest() self.hitTest=true end
    function c:Show() self.hidden=false end
    function c:Hide() self.hidden=true end
    function c:IsHidden() return self.hidden == true end
    function c:SetHidden(v) self.hidden=v end
    function c:Destroy()
        self.destroyed=true
        for _, child in ipairs(controls) do
            if child.parent == self then child:Destroy() end
        end
    end
    function c:SetText(v) self.text=v end
    function c:SetColor(v) self.color=v end
    function c:SetAlpha(v) self.alpha=v end
    function c:SetTexture(v) self.texture=v end
    function c:SetColorMask(v) self.colorMask=v end
    function c:SetSolidColor(v) self.fill=v end
    function c:SetNeedsFrameUpdate(v) self.frames=v end
    table.insert(controls,c)
    return c
end
local status, view = control(), control()
status.Right:Set(1200)
status.Bottom:Set(900)
function view:GetScreenPos(unit) return unit.pos end
local function layouter(scale)
    local scaleVar = property(scale)
    local item = {}
    function item:ScaleVar(value) return function() return math.floor(value * self.Scale()) end end
    function item:Width(value) self.control.Width:Set(self:ScaleVar(value)); return self end
    function item:Height(value) self.control.Height:Set(self:ScaleVar(value)); return self end
    function item:AtTopCenterIn(parent, y)
        local c, dy = self.control, self:ScaleVar(y)
        c.Top:Set(function() return parent.Top() + dy() end)
        c.Left:Set(function() return parent.Left() + math.floor((parent.Width() - c.Width()) / 2) end)
        return self
    end
    function item:AtLeftTopIn(parent, x, y)
        local c = self.control
        local dx, dy = self:ScaleVar(x), self:ScaleVar(y)
        c.Left:Set(function() return parent.Left() + dx() end)
        c.Top:Set(function() return parent.Top() + dy() end)
        c.Right:Set(function() return c.Left() + c.Width() end)
        c.Bottom:Set(function() return c.Top() + c.Height() end)
        return self
    end
    return setmetatable(item, {__call=function(self,c) self.control=c; return self end,
        __index=function(self, key)
            if key == 'Scale' then return scaleVar end
            return function() return self end
        end,
        __newindex=function(self, key, value)
            if key == 'Scale' then scaleVar:Set(value) else rawset(self, key, value) end
        end})
end
local ignored, cached = false, false
local actions, descriptions, keyMap = {}, {}, {['CTRL-M']='claret_mex_select_T1_idle',M='other'}
local applied, postedDrag
local modules = {
    ['/lua/lazyvar.lua'] = {Create=property},
    ['/lua/keymap/keyactions.lua'] = {keyActions=actions},
    ['/lua/keymap/keydescriptions.lua'] = {keyDescriptions=descriptions},
    ['/lua/keymap/keymapper.lua'] = {GetCurrentKeyMap=function() return keyMap end},
    ['/mods/ClaretCore/modules/Theme.lua'] = {Colors={canvas='canvas', health='green', text='white', hudValue='white', hudDamage='red',
        muted='muted', danger='red', warning='amber', transparent='clear', border='border'}, Metrics={buttonHeight=36,rowHeight=40,glyph=20,text=16,
        caption=12,secondaryText=14,buttonText=15}, Fonts={body='body'},
        RoundedPanel=function(panel)
            return function(width) panel.backgroundWidth=width end
        end},
    ['/lua/ui/uiutil.lua'] = {CreateText=function(parent, value) local c=control(parent); c.text=value; return c end},
    ['/lua/maui/group.lua'] = {Group=control},
    ['/lua/maui/bitmap.lua'] = {Bitmap=control},
    ['/lua/maui/layouthelpers.lua'] = {GetPixelScaleFactor=function() return 1 end},
    ['/lua/maui/dragger.lua'] = {Dragger=function() return control() end},
    ['/lua/ui/game/tooltip.lua'] = {CreateMouseoverDisplay=function() end, DestroyMouseoverDisplay=function() end},
    ['/lua/ui/game/commandmode.lua'] = {
        GetCommandMode=function() return {commandMode} end,
        CacheAndClearCommandMode=function() assert(not cached); cached=true end,
        RestoreCommandMode=function(restore) assert(cached and restore); cached=false end,
    },
    ['/lua/ui/game/gamemain.lua'] = {
        GetStatusCluster=function() return status end,
        SetIgnoreSelection=function(v) ignored=v end,
        AddBeatFunction=function(fn) beat=fn end,
        RemoveBeatFunction=function(fn) assert(beat == fn); beat=nil end,
    },
    ['/lua/ui/game/worldview.lua'] = {viewLeft=view},
}
local env = setmetatable({
    ReUI={UI={FloorLayouter=layouter},
        ClaretCore={Localization={Text=function(key) return key end}}},
    import=function(path) return assert(modules[path],path) end,
    SavePreferences=function() savedPosition=pendingPosition end,
    PostDragger=function(_, _, drag) postedDrag=drag end,
    IN_AddKeyMapTable=function(mappings) applied=mappings end,
    GetSelectedUnits=function() return selection end,
    SelectUnits=function(units) selection=units end,
    GetFocusArmy=function() return army end,
    GetSystemTimeSeconds=function() return now end,
    GetGameTimeSeconds=function() return gameTime end,
    GetInputCapture=function() return false end,
    IsDestroyed=function(c) return not c or c.destroyed end,
    LOG=function(message) if message:find('mex-layout',1,true) then layoutLog=message end end,
    WARN=function(message) error(message) end,
    UISelectionByCategory=function(category,_,onlyOnScreen,_,last)
        discoveryCalls=discoveryCalls+1
        assert(ignored and cached and category == 'MASSEXTRACTION STRUCTURE' and last == false)
        selection=onlyOnScreen and onScreen or candidates
    end,
    GetIsPaused=function(units) return units[1].paused end,
    SetPaused=function(units,v)
        paused=units
        for _, unit in ipairs(units) do unit.paused=v end
    end,
    GetUnitCommandData=function() return nil,nil,'allowed' end,
    EntityCategoryContains=function(category, bp) return category == 'allowed' and (bp == 't2' or bp == 't3') end,
    IssueBlueprintCommandToUnits=function(units,command,bp,count)
        assert(command == 'UNITCOMMAND_Upgrade' and (bp == 't2' or bp == 't3') and count == 1)
        order=units
    end,
}, {__index=_G})
local function unit(id, tech, bp, upgrade)
    local u={id=id, tech=tech, fraction=1, progress=0, pos={x=100,y=200}, mass=2}
    function u:IsDead() return self.dead end
    function u:GetArmy() return 1 end
    function u:GetFractionComplete() return self.fraction end
    function u:IsInCategory(v) return v == 'MASSEXTRACTION' or v == 'STRUCTURE' or v == 'TECH' .. tostring(self.tech) end
    function u:GetBlueprint() return {BlueprintId=bp,General={UpgradesTo=upgrade},Economy={ProductionPerSecondMass=2}} end
    function u:GetFocus() return self.focus end
    function u:GetEntityId() return self.id end
    function u:GetWorkProgress() return self.progress end
    function u:GetEconData() return {massProduced=self.mass} end
    return u
end
local function option(initial)
    local signal={}
    function signal:Add(fn) self.callback=fn end
    function signal:Remove(fn) assert(self.callback == fn); self.callback=nil end
    return {value=initial, Get=function(self) return self.value end, OnChanged=signal,
        Set=function(self, value) self.value=value; self.OnChanged.callback(self, value) end}
end
local scale = option(125)
local mode = option('static')
local locked = option(false)
local transparency = option(0)
local position = option({x=100,y=50})
function position:Set(value) self.value=value end
function position:Save() pendingPosition=self.value; self.saves=(self.saves or 0)+1 end
local options={mexPanelPosition=position,mexPanel={Get=function() return true end},mexOverlay=option(false),mexOverlayScale=option(100),mexNumbers=option(true),mexPanelScale=scale,mexPanelMode=mode,mexPanelLocked=locked,mexPanelTransparency=transparency}
assert(loadfile('../mods/ClaretUI/modules/features/Mexes.lua','t',env))()
env.InstallKeys()
assert(applied['CTRL-M'] == actions.claret_mex_select_T1_idle and not applied.M)
assert(descriptions.claret_mex_pause_active and descriptions.claret_mex_resume_best_T2_paused)
local cleanup
local a,b,c = unit(1,1,'t1','t2'),unit(2,1,'t1','t2'),unit(3,2,'t2','t3')
local target = unit(4,2,'t2','t3')
target.fraction=0.5
c.pos={x=200,y=300}
candidates={a,b,c,target}
onScreen={a,c}
local original = selection
env.Start(env,{Defer=function(_,fn) cleanup=fn end},false,options)
local panel=controls[3]
local cells, updater, backdrop={}
for _, item in ipairs(controls) do
    if item.parent == status and item.OnFrame then updater=item end
end
assert(panel.hidden and panel.Width() == 0)
for _, child in ipairs(controls) do assert(child.parent ~= panel) end
env.SetVisible(env,true)
assert(discoveryCalls == 0 and selection == original, 'startup leaves the player selection untouched')
gameTime, commandMode = 15, 'build'
beat()
assert(discoveryCalls == 0 and selection == original, 'background discovery preserves active placement')
commandMode, now = false, 0.2
beat()
for _, item in ipairs(controls) do
    if item.parent == panel and item.HandleEvent then table.insert(cells,item) end
    if item.parent == panel and not item.HandleEvent then backdrop=item end
end
assert(#cells == 7)
local function hasIcon(cell, filename, alpha)
    for _, child in ipairs(controls) do
        if child.parent == cell and child.texture and child.texture:sub(-#filename) == filename
            and child.alpha == alpha then return child end
    end
end
assert(hasIcon(cells[1], 'icon_structure1_mass_rest.dds', 1))
local pauseIcon = assert(hasIcon(cells[2], 'pause_rest.dds', 1))
local mexIcon = assert(hasIcon(cells[2], 'icon_structure1_mass_rest.dds', 0.35))
assert(mexIcon.texture == '/mods/ClaretUI/textures/mexes/icon_structure1_mass_rest.dds')
assert(pauseIcon.Height() == 50 and mexIcon.Height() == 45 and pauseIcon.Depth() > mexIcon.Depth())
local function assertPauseCentered(pause, mex, coreX, coreY)
    assert(math.abs(pause.Left() + pause.Width() * 15.5 / 32 - mex.Left() - mex.Width() * coreX) <= 0.5)
    assert(math.abs(pause.Top() + pause.Height() * 7.5 / 32 - mex.Top() - mex.Height() * coreY) <= 0.5)
end
local pauseT2 = assert(hasIcon(cells[5], 'pause_rest.dds', 1))
local mexT2 = assert(hasIcon(cells[5], 'icon_structure2_mass_rest.dds', 0.35))
assertPauseCentered(pauseIcon, mexIcon, 18 / 34, 18 / 40)
assertPauseCentered(pauseT2, mexT2, 18 / 36, 17 / 40)
assert(hasIcon(cells[2], 'upgrade-arrow.png', 0.35))
assert(hasIcon(cells[4], 'icon_structure2_mass_rest.dds', 1))
assert(hasIcon(cells[7], 'icon_structure3_mass_rest.dds', 0.35))
assert(not panel.hidden and updater.frames and not updater.hitTest and selection == original and not ignored and not cached)
assert(backdrop and not backdrop.hitTest and backdrop.Depth() + 2 < cells[1].Depth())
local countLabel
for _, child in ipairs(controls) do
    if child.parent == cells[1] and child.text == '2' then countLabel=child end
end
assert(countLabel and countLabel.Top() == cells[1].Top() + 2)
assert(cells[1].Height() == 90 and panel.Height() == 100)
transparency:Set(75)
assert(backdrop.alpha == 0.25 and backdrop.fill == 'canvas' and cells[1].fill == 'clear' and countLabel.alpha == 1)
for _, child in ipairs(controls) do assert(child.parent ~= backdrop) end
transparency:Set(100)
assert(backdrop.alpha == 0 and cells[1].fill == 'clear' and countLabel.alpha == 1)
transparency:Set(0)
assert(backdrop.alpha == 1 and cells[1].fill ~= 'clear')
transparency:Set(75)
assert(hasIcon(cells[1], 'icon_structure1_mass_rest.dds', 1))
local function click(index, modifiers)
    local cell=cells[index]
    assert(not panel.hidden and not cell.hidden and cell.hitTest)
    assert(cell:HandleEvent({Type='ButtonPress',Modifiers=modifiers}))
    assert(cell:HandleEvent({Type='ButtonRelease'}))
end
local function holdLeft(index)
    local cell = cells[index]
    postedDrag = nil
    local x, y = cell.Left() + 3, cell.Top() + 3
    assert(cell:HandleEvent({Type='ButtonPress', Modifiers={Left=true}, MouseX=x, MouseY=y, KeyCode=1}))
    return postedDrag, x, y
end
local left, top = panel.Left(), panel.Top()
local drag, x, y = holdLeft(1)
assert(drag)
drag:OnRelease(x + 1, y + 1)
assert(#selection == 2 and panel.Left() == left and drag.destroyed and not position.saves)
selection = {c}
drag, x, y = holdLeft(1)
drag:OnMove(x + 40, y + 30)
drag:OnRelease(x + 40, y + 30)
assert(panel.Left() == left + 40 and panel.Top() == top + 30 and selection[1] == c)
assert(position.saves == 1 and savedPosition.x == 140 and savedPosition.y == 80)
locked:Set(true)
assert(not holdLeft(1))
assert(cells[1]:HandleEvent({Type='ButtonRelease'}))
assert(#selection == 2 and panel.Left() == left + 40)
locked:Set(false)
drag = holdLeft(1)
locked:Set(true)
assert(drag.destroyed)
locked:Set(false)
panel.Left:Set(left)
panel.Top:Set(top)
selection = original

local function advance(delta)
    now=now+delta
    beat()
    updater:OnFrame(0.1)
end
local function arrow()
    for _, item in ipairs(controls) do
        local plate=item.parent
        if plate and plate.parent == view and not item.hidden and not item.destroyed and not plate.hidden and not plate.destroyed
            and item.texture == '/mods/ClaretUI/textures/mexes/upgrade-arrow.png' then
            return plate
        end
    end
end
local function marker(tier, color)
    local texture='/mods/ClaretUI/textures/engineers/tier-' .. tostring(tier) .. '.png'
    for _, plate in ipairs(controls) do
        if plate.parent == view and not plate.hidden and not plate.destroyed
            and plate.texture == texture and (not color or color == plate.colorMask) then
            return plate
        end
    end
end
assert(not arrow())
env.RunKey('claret_mex_select_T1_idle')
assert(#selection == 2)
click(1,{Right=true})
assert(#selection == 1 and selection[1] == a)
local selected=selection
click(1,{Right=true,Ctrl=true})
assert(#order == 1 and order[1] == a and selection == selected)
assert(not a.paused)
env.RunKey('claret_mex_select_T3_idle')
assert(selection == selected)
a.focus,a.progress,a.fraction=target,0,0.7
candidates={b,c}
advance(1)
local icon = assert(arrow())
for _, child in ipairs(controls) do
    if child.parent == icon and child.texture == '/mods/ClaretUI/textures/mexes/upgrade-arrow.png' then
        assert(child.Left() == icon.Left() + 13 and child.Top() == icon.Top() - 3)
    end
end
assert(icon.fill == 'clear')
for _, item in ipairs(controls) do
    assert(item.parent ~= icon or item.text == nil)
end
local x = icon.Left()
a.pos.x = a.pos.x + 7
updater:OnFrame(0.01)
assert(icon.Left() == x + 7)
a.fraction=1
a.progress=0.4
advance(0.3)
assert(arrow())
local targetB=unit(5,2,'t2','t3')
targetB.fraction=0.2
b.focus,b.progress=targetB,0.2
advance(0.3)
local progressWidths={}
for _, track in ipairs(controls) do
    if track.parent == cells[3] and track.hidden == false and track.fill == 'border' then
        for _, fill in ipairs(controls) do
            if fill.parent == track then table.insert(progressWidths,fill.Width()) end
        end
    end
end
assert(#progressWidths == 2 and progressWidths[1] == 18 and progressWidths[2] == 9)
click(3,{Left=true,Ctrl=true})
assert(#selection == 1 and selection[1] == a, 'Ctrl+left selects the most progressed')
click(3,{Right=true,Ctrl=true})
assert(#paused == 1 and paused[1] == b and not a.paused, 'Ctrl+right pauses the least progressed')
b.focus,b.progress,b.paused=nil,0,false
click(3,{Right=true})
assert(#paused == 1 and paused[1] == a and a.paused)
advance(0.3)
assert(arrow())
click(2,{Right=true,Ctrl=true})
assert(not a.paused)
b.pos=nil
options.mexOverlay.value=true
advance(0.3)
assert(marker(1,'red') and marker(2,'white') and not marker(2,'red'))
local panelWidth = panel.Width()
options.mexOverlayScale.value = 200
updater:OnFrame(0.01)
assert(marker(1,'red').Width() == 36 and panel.Width() == panelWidth)
options.mexOverlayScale.value = 50
updater:OnFrame(0.01)
assert(marker(1,'red').Width() == 9)
options.mexOverlayScale.value = 100
updater:OnFrame(0.01)
local fill, activePlate
activePlate=marker(1,'red')
assert(activePlate == arrow())
a.paused=true
advance(0.3)
assert(marker(1,'red') == activePlate, 'a paused upgrade keeps its red tier digit')
a.paused=false
advance(0.3)
options.mexNumbers.value=false
updater:OnFrame(0.01)
assert(not arrow() and marker(1,'red') == activePlate and marker(2,'white'))
options.mexOverlay.value=false
updater:OnFrame(0.01)
assert(not arrow() and not marker(1))
options.mexNumbers.value=true
updater:OnFrame(0.01)
assert(arrow() and not marker(1))
options.mexOverlay.value=true
updater:OnFrame(0.01)
activePlate=assert(marker(1,'red'))
assert(activePlate == arrow())
options.mexOverlay.value=false
updater:OnFrame(0.01)
assert(arrow() and activePlate.destroyed and not marker(1))
options.mexOverlay.value=true
updater:OnFrame(0.01)
activePlate=assert(marker(1,'red'))
for _, control in ipairs(controls) do
    if control.parent == activePlate and control.fill == 'green' then fill=control end
end
assert(activePlate.Height() == 18 and fill.Height() == 2 and fill.Top() == activePlate.Bottom())
assert(fill.Width() == 7 and not fill.hidden, 'progress fills the bar below the badge')
panel.Left:Set(830)
panel.Top:Set(80)
scale:Set(200)
assert(panel.Width() == 680 and panel.Left() == 520 and panel.Top() == 80)
assert(cells[1].Width() == 88 and activePlate.Width() == 18)
assertPauseCentered(pauseIcon, mexIcon, 18 / 34, 18 / 40)
assertPauseCentered(pauseT2, mexT2, 18 / 36, 17 / 40)
local track, progress
for _, child in ipairs(controls) do
    if child.parent == cells[3] and not child.hidden then
        for _, fill in ipairs(controls) do
            if fill.parent == child and fill.fill == 'green' then track,progress=child,fill end
        end
    end
end
assert(track and progress and hasIcon(cells[3], 'icon_structure1_mass_rest.dds', 1))
assert(progress.Left() == track.Left() and progress.Right() - progress.Left() == 28)
assert(progress.Right() <= track.Right() and track.Right() <= cells[3].Right())
scale:Set(50)
assert(panel.Width() == 170 and panel.Left() == 520 and panel.Top() == 80)
assert(progress.Right() - progress.Left() == 7 and progress.Right() <= track.Right())

order=nil
click(4,{Left=true,Ctrl=true})
assert(#order == 1 and order[1] == c, 'an uncapped T2 mex accepts a manual upgrade')
c.mass=3
advance(0.3)
assert(marker(2,'white') and not marker(2,'red'))
click(4,{Left=true,Ctrl=true})
assert(#order == 1 and order[1] == c, 'a capped T2 mex accepts a manual upgrade')
a.focus,a.progress=nil,0.9
advance(0.3)
assert(marker(1,'white') == activePlate and not arrow() and fill.hidden and track.hidden)
a.focus,a.progress=target,0.9
advance(0.3)
assert(marker(1,'red') == activePlate)
a.dead=true
target.fraction=1
c.pos=nil
advance(1)
assert(not marker(1))
local newTier = assert(marker(2,'white'))
assert(newTier.Left() == target.pos.x - newTier.Width() / 2)
target.dead=true
c.pos=nil
advance(1)
assert(not marker(2))

-- Enter dynamic mode while the feature is live. Only the populated tiers
-- stay visible, and the cells keep their own input and progress.
b.dead=true
advance(1)
scale:Set(100)
local function assertLayout(visible)
    local current, currentBackdrop = {}, nil
    for _, item in ipairs(controls) do
        if not item.destroyed and item.parent == panel then
            if item.HandleEvent then table.insert(current,item) else currentBackdrop=item end
        end
    end
    table.sort(current,function(a,b) return a.Left() < b.Left() end)
    local count, slots = 0, ''
    for id = 1, 7 do
        if visible[id] then
            count = count + 1
            slots = slots .. tostring(id)
            local cell = assert(current[count])
            cells[id] = cell
            assert(not cell.hidden and cell.hitTest)
            assert(cell.Left() == panel.Left() + 4 + (count - 1) * 48)
        else
            assert(not cells[id] or cells[id].destroyed)
            cells[id] = nil
        end
    end
    assert(#current == count and layoutLog:find('slots=' .. slots,1,true))
    if count == 0 then
        assert(panel.hidden and panel.Width() == 0 and updater.frames and not currentBackdrop)
    else
        local width = 4 + count * 48
        assert(not panel.hidden and panel.Width() == width)
        assert(currentBackdrop.Width() == width and currentBackdrop.fill == 'canvas' and currentBackdrop.alpha == 0.25)
    end
end
mode:Set('dynamic')
assertLayout({[4]=true,[5]=true,[6]=true})
click(4,{Left=true})
assert(#selection == 1 and selection[1] == c)
c.dead=true
advance(1)
assertLayout({})

local newMex, newTarget = unit(6,1,'t1','t2'), unit(7,2,'t2','t3')
newTarget.fraction=0.25
newMex.focus,newMex.progress=newTarget,0.25
candidates={newMex}
advance(1)
assertLayout({true,true,true})
assert(arrow())
click(3,{Right=true})
assert(newMex.paused)
advance(0.2)
assertLayout({true,true,true})
click(2,{Right=true})
assert(not newMex.paused)

local t3=unit(8,3,'t3')
candidates={newMex,t3}
advance(1)
assertLayout({true,true,true,[7]=true})
newMex.dead=true
newTarget.fraction=1
advance(0.2)
assertLayout({[4]=true,[5]=true,[6]=true,[7]=true})
newTarget.dead=true
advance(0.2)
assertLayout({[7]=true})
click(7,{Left=true})
assert(#selection == 1 and selection[1] == t3)

t3.dead=true
advance(0.2)
assertLayout({})
mode:Set('static')
assertLayout({true,true,true,true,true,true,true})
mode:Set('dynamic')
assertLayout({})
env.SetVisible(env,false)
mode:Set('static')
env.SetVisible(env,true)
assertLayout({true,true,true,true,true,true,true})


env.SetVisible(env,false)
assert(panel.hidden and not updater.frames and not marker(1))
cleanup()
assert(panel.destroyed and updater.destroyed and not beat and not scale.OnChanged.callback and not mode.OnChanged.callback and not locked.OnChanged.callback and not transparency.OnChanged.callback)
local newPanelIndex = #controls + 1
options.mexPanelPosition = option(savedPosition)
env.Start(env,{Defer=function(_,fn) cleanup=fn end},false,options)
env.SetVisible(env,true)
local restored = controls[newPanelIndex]
assert(restored.Left() == 140 and restored.Top() == 80 and position.saves == 1)
cleanup()
print('Mex panel visibility, restored drag location, actions and marker transitions passed')
