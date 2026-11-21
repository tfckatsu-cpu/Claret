table.getn = function(items) return #items end
local installed = { 'T1', 'T2', 'T3', 'Gun' }
local icons = {}
local function property()
    return { Set = function(self, value) self.value = value end }
end
local modules = {
    ['/lua/enhancementcommon.lua'] = { GetEnhancements = function() return installed end },
    ['/lua/ui/uiutil.lua'] = { UIFile = function(path) return path end },
    ['/lua/maui/bitmap.lua'] = { Bitmap = function()
        local icon = { Left = property(), Top = property(), Width = property(), Height = property(), Depth = property() }
        function icon:SetTexture(path) self.texture = path end
        function icon:DisableHitTest() end
        function icon:Destroy() self.destroyed = true end
        table.insert(icons, icon)
        return icon
    end },
}
local env = setmetatable({ import = function(path) return assert(modules[path]) end }, { __index = _G })
assert(loadfile('../mods/ClaretUI/modules/AcuUpgradeIcons.lua', 't', env))()
local blueprint = { BlueprintId = 'uel0001', Enhancements = {
    T1 = { Icon = 't1' }, T2 = { Icon = 't2', Prerequisite = 'T1' },
    T3 = { Icon = 't3', Prerequisite = 'T2' }, Gun = { Icon = 'gun' },
} }
local unit = { GetBlueprint = function() return blueprint end, GetEntityId = function() return 1 end }
local paint = env.Create({}, 200)
paint(unit)
assert(#icons == 2 and icons[1].texture:match('/uef%-enhancements/gun_btn_up%.dds$'))
assert(icons[2].texture:match('/t3_btn_up%.dds$'), 'T3 replaces every prerequisite, keeping independent upgrades')
paint(unit)
assert(#icons == 2, 'identical upgrade state reuses its icons')
paint(nil)
assert(icons[1].destroyed and icons[2].destroyed, 'clearing removes all icons')
print('PASS: ACU upgrade chains, independent upgrades, stable icons and cleanup')
