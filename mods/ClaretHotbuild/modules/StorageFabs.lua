local MAX_MEX_MOUSE_DISTANCE = 3

local function GetAxis(position, index, axis)
    return position[index] or position[axis]
end

local function IsNearMouse(unit, mousePosition)
    local position = unit:GetPosition()
    return VDist2(
        GetAxis(position, 1, 'x'),
        GetAxis(position, 3, 'z'),
        GetAxis(mousePosition, 1, 'x'),
        GetAxis(mousePosition, 3, 'z')
    ) <= MAX_MEX_MOUSE_DISTANCE
end

local function GetNearestIdleMexs()
    local mousePosition = GetMouseWorldPos()
    if not mousePosition then
        return {}
    end

    ConExecute('UI_SelectByCategory +nearest +idle +inview MASSEXTRACTION')
    local selectedMexs = GetSelectedUnits() or {}
    local nearbyMexs = {}
    for _, mex in selectedMexs do
        if IsNearMouse(mex, mousePosition) then
            table.insert(nearbyMexs, mex)
        end
    end
    return nearbyMexs
end

local function PrepareBuild(fabs)
    local selection = GetSelectedUnits()
    if not selection then
        return nil
    end

    local engineers
    if fabs then
        engineers = EntityCategoryFilterDown(categories.ENGINEER - (categories.COMMAND + categories.TECH1), selection)
    else
        engineers = EntityCategoryFilterDown(categories.ENGINEER - categories.COMMAND, selection)
    end
    if not engineers or table.getn(engineers) == 0 then
        return nil
    end

    local mexs = GetNearestIdleMexs()
    SelectUnits(engineers)
    if table.getn(mexs) == 0 then
        return nil
    end

    return { fabs=fabs, engineers=engineers, mexs=mexs }
end

local function IssueBuild(build)
    ForkThread(function()
        local originalSelection = GetSelectedUnits() or {}
        local gameMain = import('/lua/ui/game/gamemain.lua')
        local ignoreSet = false
        local ok, err = pcall(function()
            gameMain.SetIgnoreSelection(true)
            ignoreSet = true
            SelectUnits(build.engineers)
            for _, mex in build.mexs do
                if build.fabs then
                    SimCallback({ Func = 'RingWithFabricators', Args = { target = mex:GetEntityId(), allFabricators = true } }, true)
                else
                    SimCallback({ Func = 'RingWithStorages', Args = { target = mex:GetEntityId() } }, true)
                end
                WaitSeconds(0.1)
            end
        end)
        local restored, restoreError = pcall(SelectUnits, originalSelection)
        if ignoreSet then
            local reset, resetError = pcall(gameMain.SetIgnoreSelection, false)
            if not reset then error(resetError) end
        end
        if not ok then error(err) end
        if not restored then error(restoreError) end
    end)
end

local function BuildNearest(fabs)
    local build = PrepareBuild(fabs)
    if not build then
        return false
    end
    IssueBuild(build)
    return true
end

function buildStorageNearest()
    return BuildNearest(false)
end

function buildFabsNearest()
    return BuildNearest(true)
end
