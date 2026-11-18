-- Multifunction shell is isolated: callbacks belong to the caller and no
-- stock command, preference, minimap, or overlay API is invoked by the shell.
local function node(kind, parent)
    local item = {
        kind = kind, parent = parent, children = {}, textures = {}, destroyed = false,
        Width = {}, Height = {}, Left = {}, Right = {}, Top = {}, Bottom = {}, Depth = {},
    }
    for _, field in ipairs({ 'Width', 'Height', 'Left', 'Right', 'Top', 'Bottom', 'Depth' }) do
        item[field].Set = function(self, value) self.value = value end
    end
    item.Width.value, item.Height.value = 320, 48
    item.Depth.value = function() return 1 end
    if parent and parent.children then table.insert(parent.children, item) end
    function item:SetTexture(texture) self.texture = texture end
    function item:SetNewTextures(...) self.newTextures = { ... } end
    function item:SetCheck(value, silent) self.checked, self.silent = value, silent end
    function item:Disable() self.disabled = true end
    function item:Enable() self.disabled = false end
    function item:Destroy() self.destroyed = true end
    return item
end

local parent = node('shared-cluster')
local created = {}
local function factory(kind)
    return function(p)
        local item = node(kind, p)
        table.insert(created, item)
        return item
    end
end
local usedFiles = {}
local uiUtil = { UIFile = function(path) usedFiles[path] = true; return 'ui:' .. path end }
local layout = {}
for _, method in ipairs({ 'AtLeftTopIn', 'AnchorToLeft', 'AtTopIn', 'AtLeftIn', 'AnchorToRight', 'AtBottomIn', 'AtLeftBottomIn', 'RightOf' }) do
    layout[method] = function(...) end
end
local tooltips = {
    AddCheckboxTooltip = function(control, key) control.checkboxTooltip = key end,
    AddButtonTooltip = function(control, key) control.buttonTooltip = key end,
}
local env = setmetatable({
    import = function(path)
        error('unexpected FAF import: ' .. path)
    end,
    GetFrame = function() return node('frame') end,
    math = math,
    table = table,
}, { __index = _G })
assert(loadfile('../mods/ClaretCore/modules/MultifunctionShell.lua', 't', env))()

local seen = { overlays = {}, pings = {}, collapse = {}, minimap = {} }
local callbacks = {
    onOverlay = function(data, checked, index, control)
        table.insert(seen.overlays, { data = data, checked = checked, index = index, control = control })
        if data.id == 'teamcolor' then return false end
    end,
    onPing = function(data, modifiers, index, control)
        table.insert(seen.pings, { data = data, modifiers = modifiers, index = index, control = control })
    end,
    onCollapse = function(value, controls) table.insert(seen.collapse, { value = value, controls = controls }); return false end,
    onMinimapToggle = function(value, controls) table.insert(seen.minimap, { value = value, controls = controls }); return false end,
}
local controls = env.Create(parent, callbacks, {
    factories = { group = factory('group'), bitmap = factory('bitmap'), checkbox = factory('checkbox'), button = factory('button') },
    uiUtil = uiUtil,
    tooltip = tooltips,
    layoutHelpers = layout,
    layout = false,
})

assert(controls.root.parent == parent and controls.bg.parent == controls.root)
assert(controls.panel.parent == controls.bg and controls.collapseArrow.parent == controls.root)
assert(#controls.overlayButtons == 4 and #controls.pingButtons == 4)
assert(controls.pingButtons[1].kind == 'button', 'native ping cells use push buttons')
assert(controls.overlayButtons[1].ID == 'mapoptions' and controls.overlayButtons[4].ID == 'military')
assert(controls.pingButtons[1].ID == 'alert' and controls.pingButtons[4].ID == 'marker')
assert(controls.pingButtons[2].Cursor == 'RULEUCC_Move')
assert(controls.overlayButtons[1].checkboxTooltip == 'mfd_strat_view')
assert(controls.pingButtons[1].buttonTooltip == 'mfd_alert_ping')
assert(controls.collapseArrow.newTextures[1] == 'ui:/game/tab-l-btn/tab-close_btn_up.dds')

controls.overlayButtons[3].OnCheck(controls.overlayButtons[3], true)
controls.overlayButtons[2]:SetCheck(true)
controls.overlayButtons[2].OnCheck(controls.overlayButtons[2], true)
local modifiers = { Shift = true }
controls.pingButtons[2].OnClick(controls.pingButtons[2], modifiers)
controls.collapseArrow:SetCheck(true)
controls.collapseArrow.OnCheck(controls.collapseArrow, true)
assert(controls:RequestMinimapToggle(false) == false and controls.minimapEnabled == true)
assert(#seen.overlays == 2 and seen.overlays[1].data.id == 'economy' and seen.overlays[1].checked
    and seen.overlays[2].data.id == 'teamcolor')
assert(#seen.pings == 1 and seen.pings[1].data.id == 'move' and seen.pings[1].modifiers == modifiers)
assert(seen.collapse[1].value and seen.collapse[1].controls == controls)
assert(seen.minimap[1].value == false and seen.minimap[1].controls == controls)
assert(not controls.overlayButtons[2].checked and not controls.overlayButtons[2]._claretChecked,
    'rejected overlay check rolls back without recursively invoking OnCheck')
assert(not controls.collapsed and not controls.collapseArrow.checked,
    'rejected collapse check restores prior UI state')
assert(controls:RequestMinimapToggle(true) == false and controls.minimapEnabled == true,
    'rejected minimap request restores local state')
controls:SetCollapsed(false)
assert(not controls.collapsed and controls.collapseArrow.silent)

controls:ApplyLayout()
assert(usedFiles['/game/filter-ping-panel/filter-ping-panel02_bmp.dds'])
assert(usedFiles['/game/mfd_btn/ping-move_btn_up.dds'])
assert(controls.bg.Width.value == controls.panel.Width and controls.root.Height.value == controls.bg.Height)
assert(parent.children[1] == controls.root, 'shell is attached under, and does not replace, the caller-owned cluster')

controls:Destroy()
assert(controls.root == nil and controls.parent == nil)
assert(parent.children[1].destroyed, 'destroy delegates cleanup to the owned root')
controls:Destroy()
assert(parent.children[1] == controls.root or parent.children[1].destroyed,
    'repeated destroy is harmless and leaves parent ownership intact')
assert(seen.overlays[1] and seen.pings[1], 'only explicit callbacks receive actions')
print('PASS: multifunction shell stock assets, callbacks, parent ownership and cleanup')
