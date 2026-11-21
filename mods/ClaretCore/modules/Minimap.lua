-- Minimap presentation; user visibility remains owned by FAF.
function Create(autoOption, borderOption)
    local controller = {}
    local minimap = import('/lua/ui/game/minimap.lua')
    local prefs = import('/lua/user/prefs.lua')
    local hiddenByZoom = false
    local decorationApplied = false
    local desiredVisible = false
    local active = false
    local mapSize = SessionGetScenarioInfo().size
    local threshold = 600 * (math.max(mapSize[1], mapSize[2]) / 512)

    local function DecorationAlpha(alpha)
        local controls = minimap.controls
        if not controls.displayGroup or not controls.miniMap then return end
        controls.displayGroup._windowGroup:SetAlpha(alpha, true)
        for _, key in ipairs({'GlowTL', 'GlowTR', 'GlowBL', 'GlowBR', 'GlowL', 'GlowR', 'GlowT', 'GlowB',
                'DragTL', 'DragTR', 'DragBL', 'DragBR'}) do
            controls.miniMap[key]:SetAlpha(alpha, true)
        end
    end

    function controller:LayoutChanged()
        if active and borderOption:Get() then
            DecorationAlpha(0)
            decorationApplied = true
        end
    end

    function controller:ManualToggle()
        if not active then return end
        desiredVisible = prefs.GetFromCurrentProfile('stratview') == true
        hiddenByZoom = false
        self:Update()
    end

    function controller:Update()
        if not active then return end
        local display = minimap.controls.displayGroup
        local game = import('/lua/ui/game/gamemain.lua')
        if not display or game.gameUIHidden then return end
        local camera = GetCamera('WorldCamera')
        if not camera then return end
        local shouldHide = autoOption:Get() and desiredVisible and camera:GetZoom() > threshold
        if shouldHide and not hiddenByZoom then
            if not display:IsHidden() then display:Hide(); hiddenByZoom = true end
        elseif not shouldHide and hiddenByZoom then
            if desiredVisible then display:Show() end
            hiddenByZoom = false
        end
    end

    function controller:Start(owner)
        active = true
        desiredVisible = prefs.GetFromCurrentProfile('stratview') == true
        local Group = import('/lua/maui/group.lua').Group
        local ticker = Group(owner)
        ticker:DisableHitTest()
        local elapsed = 0
        ticker.OnFrame = function(self, delta)
            elapsed = elapsed + delta
            if elapsed >= 0.15 then
                elapsed = 0
                controller:Update()
                self:SetNeedsFrameUpdate(autoOption:Get() or hiddenByZoom)
            end
        end
        local autoChanged = function()
            controller:Update()
            ticker:SetNeedsFrameUpdate(autoOption:Get() or hiddenByZoom)
        end
        local borderChanged = function()
            if borderOption:Get() then
                DecorationAlpha(0)
                decorationApplied = true
            elseif decorationApplied then
                DecorationAlpha(1)
                decorationApplied = false
            end
        end
        autoOption.OnChanged:Add(autoChanged)
        borderOption.OnChanged:Add(borderChanged)
        borderChanged()
        autoChanged()
        return function()
            if hiddenByZoom and desiredVisible and minimap.controls.displayGroup then
                minimap.controls.displayGroup:Show()
            end
            hiddenByZoom = false
            if decorationApplied then DecorationAlpha(1); decorationApplied = false end
            active = false
            autoOption.OnChanged:Remove(autoChanged)
            borderOption.OnChanged:Remove(borderChanged)
            ticker:SetNeedsFrameUpdate(false)
            ticker:Destroy()
        end
    end
    return controller
end
