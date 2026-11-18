-- Safe transaction for removing the last item from a factory queue display.
local function IsFactory(unit)
    return unit and not unit:IsDead()
        and (unit:IsInCategory('FACTORY') or unit:IsInCategory('EXTERNALFACTORY'))
end

function Execute(context)
    local attemptedQueueDisplay = false
    local construction
    local ok, result = pcall(function()
        if type(context) ~= 'table' or type(context.selection) ~= 'table'
            or table.getn(context.selection) ~= 1 then return false end
        local factory = context.selection[1]
        if not IsFactory(factory) then return false end

        attemptedQueueDisplay = true
        local queue = SetCurrentFactoryForQueueDisplay(factory)
        if type(queue) ~= 'table' then return false end
        local queueSize = table.getsize(queue)
        if queueSize == 0 then return false end

        construction = import('/lua/ui/game/construction.lua')
        construction.DecreaseBuildCountInQueue(queueSize, IsKeyDown('Shift') and 5 or 1)
        return true
    end)

    -- Construction queue display state is global; always clear it, even if
    -- obtaining or modifying the queue failed.
    local cleared, clearError = true, nil
    if attemptedQueueDisplay then cleared, clearError = pcall(ClearCurrentFactoryForQueueDisplay) end
    if not ok then error(result) end
    if not cleared then error(clearError) end
    if result and construction then construction.RefreshUI() end
    return result
end
