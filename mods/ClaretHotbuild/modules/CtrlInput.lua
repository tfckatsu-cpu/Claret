local MOVE_ORDER='RULEUCC_Move'

function Install(reui, canUse)
    local commands=import('/lua/ui/game/commandmode.lua')
    local issuedMove
    local generation=0

    reui.Core.Hook('/lua/ui/game/commandmode.lua','OnCommandIssued',function(original)
        return function(command)
            if canUse() and command.CommandType=='Move' then
                local mode=commands.GetCommandMode()
                if mode[1]=='order' and mode[2] and mode[2].name==MOVE_ORDER then
                    issuedMove=mode[2]
                end
            end
            return original(command)
        end
    end)

    commands.AddEndBehavior(function(mode,data)
        if not mode then return end
        generation=generation+1
        local ticket=generation
        local completedMove=issuedMove and issuedMove==data
        issuedMove=nil
        if not completedMove or data.claretHotbuildReplacingMove or not canUse() or not IsKeyDown('Control') then
            return
        end
        local selected=GetSelectedUnits() or {}
        local size=table.getn(selected)
        if size==0 then return end
        local units={}
        for _,unit in ipairs(selected) do units[unit]=true end
        ForkThread(function()
            WaitFrames(1)
            if ticket~=generation or not canUse() or not IsKeyDown('Control') or commands.GetCommandMode()[1] then
                return
            end
            local current=GetSelectedUnits() or {}
            if table.getn(current)~=size then return end
            for _,unit in ipairs(current) do if not units[unit] then return end end
            commands.StartCommandMode('order',{name=MOVE_ORDER})
        end)
    end)
end
