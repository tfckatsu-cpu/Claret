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
    if path == '/mods/ClaretUI/modules/SelectionHudFields.lua' then
        local fields = {}
        assert(loadfile('..' .. path, 't', fields))()
        return fields
    end
    if path == '/lua/maui/group.lua' then return {Group=control} end
    if path == '/lua/maui/bitmap.lua' then return {Bitmap=control} end
    if path == '/lua/ui/uiutil.lua' then return {SkinnableFile=function(p) return p end, CreateText=function(parent, text)
        local item=control(parent); item.text=text; return item
    end} end
    if path == '/lua/maui/layouthelpers.lua' then return {GetPixelScaleFactor=function() return 1 end} end
    if path == '/lua/maui/slider.lua' then return {IntegerSlider=function(parent, _, min, max, step)
        assert(((min == 50 and max == 200) or (min == 0 and max == 100)) and step == 5)
        local c=control(parent)
        c._background=control(c)
        c._thumb=control(c)
        function c:SetValue(v) self.value=v end
        function c:GetValue() return self.value end
        return c
    end} end
    error('unexpected import ' .. path)
end}, {__index=_G})
assert(loadfile('../mods/ClaretUI/modules/UiSection.lua', 't', env))()
env.ReUI.Options = {OptionValue=option, Mods=setmetatable({}, {__newindex=function(self, key, values)
    for _, field in ipairs(env.import('/mods/ClaretUI/modules/SelectionHudFields.lua').Fields) do
        assert(values['selection_' .. field.key], 'ReUI loads saved options at registration')
    end
    rawset(self, key, values)
end})}
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
pressLabel('claretui.positions.title')
assert(not options.revealPositions:Get())
pressLabel('claretui.positions.enabled')
assert(options.revealPositions:Get() and options.revealPositions.saves == 1)
local durationRow = assert(findLabel('claretui.positions.duration')).parent
pressLabel('claretui.positions.five_minutes', durationRow)
assert(options.revealPositionsDuration:Get() == 300 and options.revealPositionsDuration.saves == 1)
pressLabel('claretui.positions.ten_minutes', durationRow)
assert(options.revealPositionsDuration:Get() == 600)
pressLabel('claretui.positions.one_minute', durationRow)
assert(options.revealPositionsDuration:Get() == 60)
pressLabel('claretui.positions.never', durationRow)
assert(options.revealPositionsDuration:Get() == 0)
local positionScaleRow = assert(findLabel('claretui.positions.scale')).parent
for _, item in ipairs(controls) do
    if item.parent == positionScaleRow and item.OnValueSet then item:OnValueSet(150) end
end
assert(options.revealPositionsScale:Get() == 150 and options.revealPositionsScale.saves == 1)
assert(options.revealPositionsFillTransparency:Get() == 100)
local fillRow = assert(findLabel('claretui.positions.fill_transparency')).parent
for _, item in ipairs(controls) do
    if item.parent == fillRow and item.OnValueChanged then item:OnValueChanged(45); item:OnValueSet(45) end
end
assert(options.revealPositionsFillTransparency:Get() == 45 and options.revealPositionsFillTransparency.saves == 1)
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

pressLabel('claretui.tab.commander')
assert(not options.acuLocked:Get())
pressLabel('claretui.setting.acu_locked')
assert(options.acuLocked:Get() and options.acuLocked.saves == 1 and options.acuScale:Get() == 100)

pressLabel('claretui.mex.title')
assert(not options.mexPanel:Get() and options.mexOverlay:Get() and not options.mexNumbers:Get())
pressLabel('claretui.mex.panel')
pressLabel('claretui.mex.numbers')
pressLabel('claretui.mex.panel_locked')
assert(options.mexPanelLocked:Get() and options.mexPanelLocked.saves == 1)
assert(options.mexPanel:Get() and options.mexPanel.saves == 1)
assert(options.mexNumbers:Get() and options.mexNumbers.saves == 1 and options.mexOverlay.saves == 0)
local sliderRow = assert(findLabel('claretui.mex.panel_scale')).parent
local slider
for _, item in ipairs(controls) do
    if item.parent == sliderRow and item.OnValueSet then slider=item end
end
assert(slider and slider:GetValue() == 100)
slider:OnValueChanged(125)
assert(options.mexPanelScale:Get() == 125 and options.mexPanelScale.saves == 0)
slider:OnValueSet(150)
assert(options.mexPanelScale:Get() == 150 and options.mexPanelScale.saves == 1)
local transparencyRow = assert(findLabel('claretui.mex.panel_transparency')).parent
for _, item in ipairs(controls) do
    if item.parent == transparencyRow and item.OnValueSet then slider=item end
end
assert(slider:GetValue() == 0)
slider:OnValueChanged(75)
assert(options.mexPanelTransparency:Get() == 75 and options.mexPanelTransparency.saves == 0)
slider:OnValueSet(100)
assert(options.mexPanelTransparency:Get() == 100 and options.mexPanelTransparency.saves == 1)
print('PASS: Mass extractor panel sliders preview and save independent values')

pressLabel('claretui.selection.title')
assert(not options.selectionHud:Get())
pressLabel('claretui.selection.enabled')
assert(options.selectionHud:Get() and options.selectionHud.saves == 1)
assert(options.selectionDynamic:Get())
pressLabel('claretui.selection.dynamic')
assert(not options.selectionDynamic:Get() and options.selectionDynamic.saves == 1)
local selectionCollapsedHeight = height
assert(not findLabel('claretui.selection.massRate'))
pressLabel('claretui.selection.advanced')
assert(height > selectionCollapsedHeight and height + 124 <= 1110)
pressLabel('claretui.selection.massRate')
assert(not options.selection_massRate:Get() and options.selection_massRate.saves == 1)
assert(options.selection_energyRate:Get() and options.selectionHud:Get())
pressLabel('claretui.selection.advanced')
assert(height == selectionCollapsedHeight and not findLabel('claretui.selection.massRate'))
pressLabel('claretui.selection.advanced')
assert(findLabel('claretui.selection.massRate') and not options.selection_massRate:Get())
pressLabel('claretui.selection.advanced')
pressLabel('claretui.selection.labels')
pressLabel('claretui.mex.panel_locked')
assert(not options.selectionLabels:Get() and options.selectionLabels.saves == 1)
assert(options.selectionLocked:Get() and options.selectionLocked.saves == 1)
local selectionTransparencyRow = assert(findLabel('claretui.mex.panel_transparency')).parent
for _, item in ipairs(controls) do
    if item.parent == selectionTransparencyRow and item.OnValueSet then item:OnValueSet(80) end
end
assert(options.selectionTransparency:Get() == 80 and options.selectionTransparency.saves == 1)
local selectionScaleRow = assert(findLabel('claretui.mex.panel_scale')).parent
for _, item in ipairs(controls) do
    if item.parent == selectionScaleRow and item.OnValueSet then
        assert(item:GetValue() == 100)
        item:OnValueChanged(125)
        assert(options.selectionScale:Get() == 125 and options.selectionScale.saves == 0)
        item:OnValueSet(175)
    end
end
assert(options.selectionScale:Get() == 175 and options.selectionScale.saves == 1)
assert(not findLabel('claretui.selection.typeCount') and not findLabel('claretui.selection.unitName'))
assert(height + 124 <= 1110)
pressLabel('claretui.selection.enabled')
assert(not options.selectionHud:Get() and options.selectionHud.saves == 2)
print('PASS: Selection Info switches fit the menu and save independent settings')
