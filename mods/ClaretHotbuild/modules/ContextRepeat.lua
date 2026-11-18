local function T(key, first, second, third)
    local core = ReUI and ReUI.ClaretCore
    local localization=core and core.Localization
    if localization and type(localization.Text)=='function' then return localization.Text(key, first, second, third) end
    return key
end

-- Continuations belong to a particular hotkey and the selection it produced.
-- No background timer: state is checked only when a key is pressed.
function Create(actions)
    local pending
    local quick
    local self={}

    local function Snapshot(selection)
        local ids={}
        for _,unit in ipairs(selection or {}) do
            if unit:IsDead() then return nil end
            ids[unit:GetEntityId()]=true
        end
        return ids
    end

    local function SameSelection(expected, selection)
        if not expected then return false end
        local actual=Snapshot(selection)
        if not actual then return false end
        for id in pairs(expected) do if not actual[id] then return false end end
        for id in pairs(actual) do if not expected[id] then return false end end
        return true
    end

    function self:Clear() pending=nil; quick=nil end
    function self:ClearQuick() quick=nil end
    function self:TouchQuick(bindingId)
        if quick and quick.bindingId~=bindingId then quick=nil end
    end

    -- The caller supplies selection changes and either release events or
    -- mapped key actions known to fire once per physical press.
    function self:RememberQuick(bindingId, action, context, keyEventsAreEdges)
        local selected=Snapshot(GetSelectedUnits() or {})
        if not action or not selected then quick=nil; return end
        quick={bindingId=bindingId,action=action,army=context.focusArmy,selected=selected,
            absolute=context.absolute==true,resolvedContext=context.resolvedContext,
            legacyUnits=context.legacyUnits,released=keyEventsAreEdges==true}
    end

    function self:ReleaseQuick(bindingId)
        if quick and quick.bindingId==bindingId then quick.released=true end
    end

    function self:SelectionChangedQuick(selection)
        if quick and not SameSelection(quick.selected,selection) then quick=nil end
    end

    function self:ContinueQuick(bindingId, context, continuationId)
        local state=quick
        if not state then return false end
        if state.bindingId~=bindingId or context.isReplay or state.army~=context.focusArmy
            or not SameSelection(state.selected,context.selection) then
            quick=nil; return false
        end
        if not state.released then return true,false,T('hotbuild.context_repeat.s001') end
        quick=nil
        pending=nil
        local oldAbsolute,oldResolved,oldLegacy=context.absolute,context.resolvedContext,context.legacyUnits
        context.absolute=state.absolute or nil
        context.resolvedContext=state.resolvedContext
        context.legacyUnits=state.legacyUnits
        local called,result=pcall(actions.Execute,state.action,context,bindingId)
        if called and result and state.action.continuation then self:Remember(continuationId or bindingId,state.action,context) end
        if called and result then self:RememberQuick(bindingId,state.action,context,true) end
        context.absolute=oldAbsolute
        context.resolvedContext=oldResolved
        context.legacyUnits=oldLegacy
        if not called then return true,false,'Context action failed: '..tostring(result) end
        return true,result,result and state.action.id or T('hotbuild.context_repeat.s002')
    end

    function self:Remember(bindingId, action, context)
        if not action.continuation then pending=nil; return end
        local selected=GetSelectedUnits() or {}
        if table.getn(selected)==0 then pending=nil; return end
        pending={bindingId=bindingId,action=action,army=context.focusArmy,
            selected=Snapshot(selected),absolute=context.absolute==true}
    end

    function self:Continue(bindingId, context)
        local state=pending
        pending=nil
        if not state or state.bindingId~=bindingId or context.isReplay or state.army~=context.focusArmy
            or not SameSelection(state.selected,context.selection) then return false end
        context.isRepeat=true
        context.absolute=state.absolute or nil
        local called,result=pcall(actions.Execute,state.action,context,bindingId)
        context.isRepeat=nil
        if not called then return true,nil,'Context action failed: '..tostring(result) end
        if result then self:Remember(bindingId,state.action,context) end
        return true,result,result and state.action.id or T('hotbuild.context_repeat.s003')
    end
    return self
end
