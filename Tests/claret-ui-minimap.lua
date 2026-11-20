table.getn = function(value) return #value end
local controls = {}
local function property()
    return setmetatable({Set = function() end}, {__call = function() return 0 end})
end
local function control(parent)
    local item = {parent = parent, Depth = property(), Width = property(), Height = property(),
        Left = property(), Right = property(), Top = property(), Bottom = property()}
    function item:DisableHitTest() end
    function item:SetSolidColor() end
    function item:SetColor() end
    function item:SetText(value) self.text = value end
    function item:SetFont() end
    function item:Destroy() if self.OnDestroy then self:OnDestroy() end end
    table.insert(controls, item)
    return item
end
local function option()
    local callbacks = {}
    local value = {value = false, saves = 0, OnChanged = {}}
    function value:Get() return self.value end
    function value:Set(v) self.value = v; for _, callback in ipairs(callbacks) do callback() end end
    function value:Save() self.saves = self.saves + 1 end
    function value.OnChanged:Add(callback) table.insert(callbacks, callback) end
    function value.OnChanged:Remove(callback)
        for i, entry in ipairs(callbacks) do if entry == callback then table.remove(callbacks, i); return end end
    end
    return value
end
local function layouter()
    return setmetatable({}, {__index = function(self) return function() return self end end})
end
local metrics = {panelGap=16, rowHeight=40, coreRowHeight=56, heading=18, secondaryText=14,
    buttonText=15, text=16, launcherText=18}
local theme = {Colors = {text='text', muted='muted', accentText='accent', surface='surface',
    canvas='canvas', border='border', hover='hover', pressed='pressed', selected='selected',
    selectedBorder='selectedBorder'}, Metrics=metrics, Fonts={body='body', heading='heading'},
    SettingsSwitch=function() return function() end end}
local env = setmetatable({ReUI={
    UI={FloorLayouter=function() return layouter end},
    ClaretCore={Localization={Text=function(key) return key end}},
}, import=function(path)
    if path == '/mods/ClaretCore/modules/Theme.lua' then return theme end
    if path == '/lua/maui/group.lua' then return {Group=control} end
    if path == '/lua/maui/bitmap.lua' then return {Bitmap=control} end
    if path == '/lua/ui/uiutil.lua' then return {CreateText=function(parent, text)
        local item=control(parent); item.text=text; return item
    end} end
    if path == '/lua/maui/layouthelpers.lua' then return {GetPixelScaleFactor=function() return 1 end} end
    if path == '/lua/maui/slider.lua' then return {} end
    error('unexpected import ' .. path)
end}, {__index=_G})
assert(loadfile('../mods/ClaretUI/modules/UiSection.lua', 't', env))()
local auto, border = option(), option()
local sized = false
local section = env.Create(control(nil), {scale=1, setSize=function() sized=true end},
    {acuHealth=option(), acuScale=option()}, {minimapAutoHide=auto, minimapBorderless=border})
local function pressLabel(label)
    for _, item in ipairs(controls) do
        if item.text == label then
            assert(item.parent.HandleEvent, 'label parent must respond to input: ' .. label)
            item.parent:HandleEvent({Type='ButtonPress'})
            return
        end
    end
    error('missing label ' .. label)
end
pressLabel('claretui.tab.minimap')
assert(sized, 'opening minimap must size the UI section')
pressLabel('claretui.setting.minimap_auto')
assert(auto:Get() and auto.saves == 1 and not border:Get(), 'auto-hide switch must save its own Core option')
pressLabel('claretui.setting.minimap_border')
assert(border:Get() and border.saves == 1, 'border switch must save its own Core option')
assert(section.CanLeave(), 'the section must permit closing')
print('PASS: minimap settings are reachable and update independent Core options')
