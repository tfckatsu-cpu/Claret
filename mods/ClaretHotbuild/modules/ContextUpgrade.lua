-- Context upgrades. ContextActions and Runtime deliberately remain separate.

local function LiveOwned(unit, army)
    if not unit then return false end
    local ok, alive = pcall(function() return not unit:IsDead() end)
    if not ok or not alive then return false end
    ok, alive = pcall(function() return unit:GetArmy() == army end)
    return ok and alive
end

local function UpgradeInProgress(unit)
    local focus=unit:GetFocus()
    if not focus then return false end
    local blueprint=unit:GetBlueprint()
    local upgrade=blueprint and blueprint.General and blueprint.General.UpgradesTo
    if type(upgrade)~='string' or upgrade=='' then return false end
    local focusBlueprint=focus:GetBlueprint()
    return focusBlueprint and focusBlueprint.BlueprintId==upgrade or false
end

local function UpgradeId(unit)
    if not LiveOwned(unit, GetFocusArmy()) then return nil end
    if not unit:IsInCategory('STRUCTURE') then return nil end
    local blueprint = unit:GetBlueprint()
    local upgrade = blueprint and blueprint.General and blueprint.General.UpgradesTo
    if type(upgrade) ~= 'string' or upgrade == '' then return nil end
    if UpgradeInProgress(unit) then return nil end
    local _, _, buildable = GetUnitCommandData({unit})
    if not buildable or not EntityCategoryContains(buildable, upgrade) then return nil end
    return upgrade
end

local function UpgradeableMex(unit)
    -- Exclude the target structure when the focused unit is its upgrade. A
    -- factory's ordinary production focus must not disable its own upgrade.
    if not unit or not unit:IsInCategory('MASSEXTRACTION') or UpgradeInProgress(unit) then return nil end
    return UpgradeId(unit)
end

local function MouseWorldPosition()
    local worldView = import('/lua/ui/game/worldview.lua')
    if not ((worldView.viewLeft and worldView.viewLeft.CursorOverWorld)
        or (worldView.viewRight and worldView.viewRight.CursorOverWorld)) then return nil end
    local position = GetMouseWorldPos()
    if not position or not position[1] or not position[3] then return nil end
    return position
end

local function RolloverUnit(army)
    if not MouseWorldPosition() then return nil end
    local info = GetRolloverInfo()
    if not info then return nil end
    local unit = info.userUnit
    if not unit and info.entityId then unit = GetUnitById(info.entityId) end
    if not LiveOwned(unit, army) or not UpgradeId(unit) then return nil end
    return unit
end

-- FAF's selector can discover map-wide candidates when onScreen=false. The
-- transaction restores both the exact original selection and command mode.
local function WithCandidates(category, callback)
    local original = GetSelectedUnits() or {}
    local commands = import('/lua/ui/game/commandmode.lua')
    local gameMain = import('/lua/ui/game/gamemain.lua')
    commands.CacheAndClearCommandMode()
    local ignored, ignoreError = pcall(gameMain.SetIgnoreSelection, true)
    if not ignored then
        pcall(commands.RestoreCommandMode, true)
        return false, ignoreError
    end
    local ok, result = pcall(function()
        UISelectionByCategory(category, false, false, false, true)
        return callback(GetSelectedUnits() or {})
    end)
    local restored, restoreError = pcall(SelectUnits, original)
    local reset, resetError = pcall(gameMain.SetIgnoreSelection, false)
    local modeRestored, modeError = pcall(commands.RestoreCommandMode, true)
    if not ok then return false, result end
    if not restored then return false, restoreError end
    if not reset then return false, resetError end
    if not modeRestored then return false, modeError end
    return true, result
end

local function DistanceSquared(a, b)
    local dx, dz = a[1] - b[1], a[3] - b[3]
    return dx * dx + dz * dz
end

local function FindNearestMex(reference, army, excluded)
    local selected
    local ok, result = WithCandidates('MASSEXTRACTION STRUCTURE', function(units)
        local nearestDistance
        for _, unit in ipairs(units) do
            if unit ~= excluded and LiveOwned(unit, army) and UpgradeableMex(unit) then
                local position = unit:GetPosition()
                if position then
                    local distance = reference and DistanceSquared(position, reference) or 0
                    if not nearestDistance or distance < nearestDistance then
                        selected, nearestDistance = unit, distance
                    end
                end
            end
        end
        return selected
    end)
    if not ok then return nil, result end
    return result
end

local function IssueUpgrade(unit, army)
    if not LiveOwned(unit, army) then return false end
    local upgrade = UpgradeId(unit)
    if not upgrade then return false end
    local selection = GetSelectedUnits() or {}
    local alreadySelected = table.getn(selection) == 1 and selection[1] == unit

    local commands = import('/lua/ui/game/commandmode.lua')
    local gameMain = import('/lua/ui/game/gamemain.lua')
    commands.CacheAndClearCommandMode()
    local ignored, ignoreError = pcall(gameMain.SetIgnoreSelection, true)
    if not ignored then
        pcall(commands.RestoreCommandMode, true)
        return false, ignoreError
    end
    local ok, err = pcall(function()
        if not alreadySelected then SelectUnits({unit}) end
        IssueBlueprintCommand('UNITCOMMAND_Upgrade', upgrade, 1, false)
    end)
    local restored, restoreError = pcall(SelectUnits, selection)
    local reset, resetError = pcall(gameMain.SetIgnoreSelection, false)
    local modeRestored, modeError = pcall(commands.RestoreCommandMode, true)
    if not ok then return false, err end
    if not restored then return false, restoreError end
    if not reset then return false, resetError end
    if not modeRestored then return false, modeError end
    return true
end

local function CurrentSelectionIs(expected)
    local current = GetSelectedUnits() or {}
    if table.getn(current) ~= table.getn(expected or {}) then return false end
    for i, unit in ipairs(expected or {}) do if current[i] ~= unit then return false end end
    return true
end

function Available(action, context)
    if type(context) ~= 'table' or context.isReplay or type(context.focusArmy) ~= 'number'
        or context.focusArmy < 1 or context.focusArmy ~= GetFocusArmy() then return false end
    local selection = context.selection or {}
    if action == 'upgrade_structure_under_cursor' or action == 'upgrade_structure_pause' then
        return CanUpgradeUnderCursor(context)
    elseif action == 'upgrade_mex_select_next' then
        if context.resolvedContext == 'cursor' then
            if not CanUpgradeUnderCursor(context) then return false end
            local unit = RolloverUnit(context.focusArmy)
            return unit ~= nil and unit:IsInCategory('MASSEXTRACTION') and UpgradeableMex(unit) ~= nil
        end
        if context.absolute then
            local mouse=MouseWorldPosition()
            return mouse ~= nil and FindNearestMex(mouse,context.focusArmy) ~= nil
        end
        if table.getn(selection) == 0 then
            return table.getn(GetSelectedUnits() or {}) == 0 and MouseWorldPosition() ~= nil
                and FindNearestMex(MouseWorldPosition(), context.focusArmy) ~= nil
        end
        return table.getn(selection) == 1 and CurrentSelectionIs(selection)
            and LiveOwned(selection[1], context.focusArmy) and UpgradeableMex(selection[1]) ~= nil
    end
    return false
end

-- Shared eligibility hook for callers that need to expose cursor upgrades.
function CanUpgradeUnderCursor(context)
    return type(context) == 'table' and not context.isReplay
        and type(context.focusArmy) == 'number' and context.focusArmy >= 1
        and context.focusArmy == GetFocusArmy()
        and CurrentSelectionIs(context.selection or {})
        and RolloverUnit(context.focusArmy) ~= nil
end

local function UpgradeRollover(context, pause)
    if not CanUpgradeUnderCursor(context) then return false end
    local unit = RolloverUnit(context.focusArmy)
    if not unit or not CurrentSelectionIs(context.selection or {}) or not LiveOwned(unit, context.focusArmy) then
        return false
    end
    -- Use FAF's own routine so its paused-upgrade behavior and user feedback stay intact.
    local upgrade = import('/lua/ui/game/hotkeys/upgrade-structure.lua')
    local ok, err = pcall(upgrade.UpgradeStructure, pause)
    return ok, err
end

function Execute(action, context)
    if not Available(action, context) then return false end
    if action == 'upgrade_structure_under_cursor' then
        return UpgradeRollover(context, false)
    elseif action == 'upgrade_structure_pause' then
        return UpgradeRollover(context, true)
    elseif action == 'upgrade_mex_select_next' then
        if context.resolvedContext ~= 'cursor' then
            local selection = context.absolute and {} or (context.selection or {})
            if table.getn(selection) == 0 then
                if not context.absolute and table.getn(GetSelectedUnits() or {}) ~= 0 then return false end
                local mouse = MouseWorldPosition()
                local mex = mouse and FindNearestMex(mouse, context.focusArmy)
                if not mex or table.getn(GetSelectedUnits() or {}) ~= 0 or not LiveOwned(mex, context.focusArmy) then
                    return false
                end
                SelectUnits({mex})
                return true
            end
            local mex = selection[1]
            if table.getn(selection) ~= 1 or not CurrentSelectionIs(selection)
                or not LiveOwned(mex, context.focusArmy) or not UpgradeableMex(mex) then return false end
            local position = mex:GetPosition()
            local ok, upgradeError = IssueUpgrade(mex, context.focusArmy)
            if not ok then return false, upgradeError end
            local nextMex, findError = FindNearestMex(position, context.focusArmy, mex)
            if findError then return false, findError end
            if nextMex and LiveOwned(nextMex, context.focusArmy) and CurrentSelectionIs({mex}) then
                SelectUnits({nextMex})
            end
            return true
        end
        local rolloverMex = RolloverUnit(context.focusArmy)
        if not rolloverMex or not rolloverMex:IsInCategory('MASSEXTRACTION')
            or not UpgradeableMex(rolloverMex) then return false end
        local position = rolloverMex:GetPosition()
        local ok, err = UpgradeRollover(context, false)
        if not ok then return false, err end
        local nextMex, findError = FindNearestMex(position, context.focusArmy, rolloverMex)
        if findError then return false, findError end
        if nextMex and LiveOwned(nextMex, context.focusArmy) then SelectUnits({nextMex}) end
        return true
    end
    return false
end
