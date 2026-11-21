local Bitmap = import('/lua/maui/bitmap.lua').Bitmap
local UI = import('/lua/ui/uiutil.lua')
local GetEnhancements = import('/lua/enhancementcommon.lua').GetEnhancements
local factions = { a = 'aeon', e = 'uef', r = 'cybran', s = 'seraphim' }

function Create(panel, baseWidth)
    local icons, previous = {}, nil
    return function(unit)
        local names, definitions, faction = {}, nil, nil
        if unit then
            local bp = unit:GetBlueprint()
            definitions = bp.Enhancements or {}
            faction = factions[string.sub(bp.BlueprintId or '', 2, 2)]
            local installed, superseded = {}, {}
            for _, name in pairs(GetEnhancements(unit:GetEntityId()) or {}) do
                if definitions[name] then
                    installed[name] = true
                    local visited = { [name] = true }
                    local ancestor = definitions[name].Prerequisite
                    while definitions[ancestor] and not visited[ancestor] do
                        visited[ancestor], superseded[ancestor] = true, true
                        ancestor = definitions[ancestor].Prerequisite
                    end
                end
            end
            for name in pairs(installed) do
                if not superseded[name] and definitions[name].Icon then table.insert(names, name) end
            end
            table.sort(names)
        end
        local signature = (faction or '') .. ':' .. table.concat(names, ',')
        if signature == previous then return end
        previous = signature
        for _, icon in ipairs(icons) do icon:Destroy() end
        icons = {}
        if not faction then return end
        local function Scaled(value) return math.floor(value * panel.Width() / baseWidth) end
        for _, name in ipairs(names) do
            local texture = UI.UIFile('/game/' .. faction .. '-enhancements/' .. definitions[name].Icon .. '_btn_up.dds', true)
            if texture then
                local offset = table.getn(icons) * 24
                local icon = Bitmap(panel)
                icon.Left:Set(function() return panel.Left() + Scaled(offset) end)
                icon.Top:Set(function() return panel.Bottom() + Scaled(2) end)
                icon.Width:Set(function() return Scaled(22) end)
                icon.Height:Set(icon.Width)
                icon.Depth:Set(function() return panel.Depth() + 2 end)
                icon:SetTexture(texture)
                icon:DisableHitTest()
                table.insert(icons, icon)
            end
        end
    end
end
