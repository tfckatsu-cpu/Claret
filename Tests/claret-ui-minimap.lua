table.getn = function(value) return #value end
local controls = {}
local function property()
    return setmetatable({Set = function() end}, {__call = function() return 0 end})
end
local function control(parent)
    local item = {parent = parent, Depth = property(), Width = property(), Height = property(),
        Left = property(), Right = property(), Top = property(), Bottom = property()}
    function item:DisableHitTest() end
    function item:EnableHitTest() end
    function item:SetSolidColor() end
    function item:SetColor() end
    function item:SetText(value) self.text = value end
    function item:SetFont() end
    function item:Destroy()
        self.destroyed = true
        for _, child in ipairs(controls) do
            if child.parent == self and not child.destroyed then child:Destroy() end
        end
        if self.OnDestroy then self:OnDestroy() end
    end
    table.insert(controls, item)
    return item
end
local function option(initial)
    local callbacks = {}
    local value = {value = initial, saves = 0, OnChanged = {}}
    function value:Get() return self.value end
    function value:ListenerCount() return #callbacks end
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
    buttonText=15, text=16, launcherText=18, label=13, caption=12}
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
env.ReUI.Options = {OptionValue=option, Mods={}}
assert(loadfile('../mods/ClaretUI/Options.lua', 't', env))()
local options = env.ReUI.Options.Mods.ClaretUI
local auto, border = option(false), option(false)
local height
local section = env.Create(control(nil), {scale=1, setSize=function(width, h) height=h end},
    options, {minimapAutoHide=auto, minimapBorderless=border})
local function findLabel(label, ancestor)
    for _, item in ipairs(controls) do
        if not item.destroyed and item.text == label then
            if not ancestor then return item end
            local parent = item.parent
            while parent do
                if parent == ancestor then return item end
                parent = parent.parent
            end
        end
    end
end
local function pressLabel(label, ancestor)
    local item = assert(findLabel(label, ancestor), 'missing label ' .. label)
    assert(item.parent.HandleEvent, 'label parent must respond to input: ' .. label)
    item.parent:HandleEvent({Type='ButtonPress'})
end
pressLabel('claretui.tab.minimap')
assert(height, 'opening minimap must size the UI section')
pressLabel('claretui.setting.minimap_auto')
assert(auto:Get() and auto.saves == 1 and not border:Get(), 'auto-hide switch must save its own Core option')
pressLabel('claretui.setting.minimap_border')
assert(border:Get() and border.saves == 1, 'border switch must save its own Core option')
assert(section.CanLeave(), 'the section must permit closing')
print('PASS: minimap settings are reachable and update independent Core options')
pressLabel('claretui.tab.rings')
local collapsedHeight = height
local attackRow = assert(findLabel('claretui.setting.rings_attack_key')).parent
local buildRow = assert(findLabel('claretui.setting.rings_build_key')).parent
assert(findLabel('claretui.key.shift', attackRow) and findLabel('claretui.key.shift', buildRow))
assert(not findLabel('claretui.setting.rings_sonar'), 'advanced settings start collapsed')
pressLabel('claretui.setting.rings_enabled')
assert(options.allRings:Get() and options.allRings.saves == 1)
pressLabel('claretui.key.control', attackRow)
assert(options.ringSelectionKey:Get() == 'CONTROL' and options.ringSelectionKey.saves == 1)
pressLabel('claretui.key.control', attackRow)
assert(options.ringSelectionKey.saves == 1, 'pressing the active key leaves the saved choice alone')
assert(options.ringBuildKey:Get() == 'SHIFT')
pressLabel('claretui.key.control', buildRow)
assert(options.ringBuildKey:Get() == 'CONTROL' and options.ringBuildKey.saves == 1)
pressLabel('claretui.setting.rings_advanced')
assert(height > collapsedHeight and height + 124 <= 1110, 'expanded settings must fit inside the menu shell')
assert(not findLabel('claretui.setting.rings_hover_key'))
pressLabel('claretui.setting.rings_sonar')
assert(not options.ringsSonar:Get() and options.ringsRadar:Get())
pressLabel('claretui.setting.rings_advanced')
assert(height == collapsedHeight and not findLabel('claretui.setting.rings_sonar'))
assert(options.ringsSonar:ListenerCount() == 0)
assert(options.ringSelectionKey:ListenerCount() == 1 and options.ringBuildKey:ListenerCount() == 1)
print('PASS: All Rings expands, fits the shell, and saves independent shortcuts and filters')
