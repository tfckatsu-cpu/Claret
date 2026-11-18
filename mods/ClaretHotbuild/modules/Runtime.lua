local function T(key, first, second, third)
    local core = ReUI and ReUI.ClaretCore
    local localization=core and core.Localization
    if localization and type(localization.Text)=='function' then return localization.Text(key, first, second, third) end
    return key
end

local Model = import('/mods/ClaretHotbuild/modules/Model.lua')
local Catalog = import('/mods/ClaretHotbuild/modules/Catalog.lua')
local Adapter = import('/mods/ClaretHotbuild/modules/Adapter.lua')
local Keys = import('/mods/ClaretHotbuild/modules/Keys.lua')
local ContextActions = import('/mods/ClaretHotbuild/modules/ContextActions.lua')
local ContextModel = import('/mods/ClaretHotbuild/modules/ContextModel.lua')
local Compatibility = import('/mods/ClaretHotbuild/modules/Compatibility.lua')
local KeyboardBindings = import('/mods/ClaretHotbuild/modules/KeyboardBindings.lua')
local current

local function IsKeyCaptureActive()
    local core=ReUI.ClaretCore
    return core and core.IsKeyCaptureActive and core.IsKeyCaptureActive() or false
end

-- Diagnostic wrapper: the game action IDs encode the underlying model IDs.
local function Dispatch(method,prefix,id,kind,chord,shiftHeld)
    local options=ReUI.Options and ReUI.Options.Mods and ReUI.Options.Mods['ClaretCore']
    local probe=options and options.probeEnabled
    local tracing=probe and probe:Get()
    local action
    if tracing then
        action=prefix..string.gsub(tostring(id),'.',function(c) return string.format('%02X',string.byte(c)) end)
        LOG('[Claret][keys] invoke action='..action..' kind='..tostring(kind)..' shift='..tostring(shiftHeld))
    end
    if not current then
        if tracing then LOG('[Claret][keys] dispatch action='..action..' result=skipped:no_session') end
        return false
    end
    local status
    if tracing then
        if not current.active then status='skipped:inactive'
        elseif current.isReplay then status='skipped:replay'
        elseif IsKeyCaptureActive() then status='skipped:key_capture'
        elseif kind=='preset' and not current.model:Get(id) then status='unknown_id'
        elseif kind=='composite' and not current.contextModel:Get(id) then status='unknown_id'
        elseif kind=='action' and not ContextActions.Get(id) then status='unknown_id'
        elseif type(current[method])~='function' then status='no_handler' end
    end
    if type(current[method])~='function' then
        if tracing then LOG('[Claret][keys] dispatch action='..action..' result=no_handler') end
        return false,'no_handler'
    end
    if current.active and not current.isReplay and not IsKeyCaptureActive() then
        local quickId
        if kind=='pair' then quickId='keyboard:pair:'..id
        elseif chord then quickId='keyboard:pair:'..chord
        elseif kind=='action' then quickId='keyboard:action:'..id
        elseif method=='ExecuteAbsolute' then quickId='absolute:'..id
        elseif method=='ExecuteKeyboardComposite' then quickId='keyboard:composite:'..id
        else quickId=id end
        current:TouchQuick(quickId)
    end
    local result,message
    if method=='Execute' then
        result,message=current[method](current,id,nil,nil,nil,shiftHeld)
    elseif method=='ExecuteKeyboardPair' then
        result,message=current[method](current,id,shiftHeld)
    else
        result,message=current[method](current,id,chord)
    end
    if tracing then
        status=status or (result and 'handled' or 'skipped:unavailable')
        if kind=='preset' and not result and status=='skipped:unavailable' then
            local diagnostic=current.unavailableDiagnostic
            LOG('[Claret][keys] unavailable reason='..(diagnostic and diagnostic.reason or 'execution_unavailable')
                ..' details=execution_unavailable')
        end
        LOG('[Claret][keys] dispatch action='..action..' result='..status)
    end
    return result,message
end
function Execute(id,shiftHeld) return Dispatch('Execute','ClaretHotbuild_',id,'preset',nil,shiftHeld) end
function ExecuteMappedPreset(id,chord) return Dispatch('ExecuteMappedPreset','ClaretHotbuild_',id,'preset',chord) end
function ExecuteMappedAbsolute(id,chord) return Dispatch('ExecuteMappedAbsolute','ClaretHotbuildAbsolute_',id,'composite',chord) end
function ExecuteMappedComposite(id,chord) return Dispatch('ExecuteMappedComposite','ClaretHotkeyComposite_',id,'composite',chord) end
function ExecuteAbsolute(id,chord) return Dispatch('ExecuteAbsolute','ClaretHotbuildAbsolute_',id,'composite',chord) end
function ExecuteKeyboardAction(id,chord) return Dispatch('ExecuteKeyboardAction','ClaretHotkeyContext_',id,'action',chord) end
function ExecuteKeyboardComposite(id,chord) return Dispatch('ExecuteKeyboardComposite','ClaretHotkeyComposite_',id,'composite',chord) end
function ExecuteKeyboardPair(chord,shiftHeld) return Dispatch('ExecuteKeyboardPair','ClaretHotkeyPair_',chord,'pair',nil,shiftHeld) end
function ExecuteFactoryShift(chord,nativeAction)
    if current and type(current.ExecuteFactoryShift)=='function' then
        return current:ExecuteFactoryShift(chord,nativeAction)
    end
    if type(nativeAction)=='string' and type(ConExecute)=='function' then ConExecute(nativeAction); return true end
    return false
end

function RefreshKeys()
    if current then return current:RefreshKeys() end
end

---@param isReplay boolean
function Create(isReplay)
    local Prefs = import('/lua/user/prefs.lua')
    local service = { active = false, editor = nil, isReplay = isReplay }
    local saved = Prefs.GetFromCurrentProfile('ClaretHotbuild')
    if saved == nil then
        saved = { version = 1, bindings = {
            { id = 'b1', name = 'T1 air scout', key = '', entries = {
                { kind = 'blueprint', id = 'uea0101' }, { kind = 'blueprint', id = 'uaa0101' },
                { kind = 'blueprint', id = 'ura0101' }, { kind = 'blueprint', id = 'xsa0101' },
            } },
            { id = 'b2', name = 'Context: reclaim / assist / move', key = '', entries = {
                { kind = 'action', id = 'claret.order.reclaim' },
                { kind = 'action', id = 'claret.order.assist' },
                { kind = 'action', id = 'claret.order.move' },
            } },
        } }
    end
    service.model = Model.Create(saved)
    service.contextActions = ContextActions
    service.contextModel = ContextModel.Create(Prefs.GetFromCurrentProfile('ClaretHotbuildContexts'), ContextActions)
    local keyboardBindings=KeyboardBindings.Create(service)
    service.keyboardBindings=keyboardBindings
    Adapter.RegisterActions(service.model)
    local catalog
    function service:Catalog()
        if not catalog then
            local base=Catalog.Create(__blueprints,LOC)
            catalog=import('/mods/ClaretHotbuild/modules/TemplateCatalog.lua').Create(base,function()
                return Prefs.GetFromCurrentProfile('build_templates')
            end,import('/lua/keymap/unitkeygroups.lua').unitkeygroups)
        end
        return catalog
    end
    local cycleMenu
    local lastPlacementBinding
    local adapter
    local keys = Keys.Create()
    local holdModule
    local continuation = import('/mods/ClaretHotbuild/modules/ContextRepeat.lua').Create(ContextActions)

    function service:QuickSelectionChanged(selection)
        continuation:SelectionChangedQuick(selection)
    end
    function service:BreakQuick() continuation:ClearQuick() end
    function service:TouchQuick(id) continuation:TouchQuick(id) end

    local function RememberQuick(binding,kind,id,context)
        local row=binding and service.contextModel:ResolveRow(binding,kind)
        local main=row and row.action and ContextActions.Get(row.action)
        local action=row and row.quickRepeat and ContextActions.Get(row.quickRepeat)
        if main and main.continuation then continuation:ClearQuick(); return end
        local original=context.absolute
        context.absolute=original or kind=='empty'
        continuation:RememberQuick(id,action,context,true)
        context.absolute=original
    end

    local groups = {{'land','air','navy'},{'acu','sacu','engineer'}, {'silo_tactical','silo_nuclear'}}
    local function ResolveContext(binding, selection, unitsOnly)
        local function rowAction(kind)
            for _,row in ipairs(binding.rows or {}) do if row.context==kind then return row.action end end
        end
        local function group(children)
            local actionId, winningKind
            for _,kind in ipairs(children) do
                if ContextActions.MatchesContext(selection,kind) then
                    local id=service.contextModel:ResolveAction(binding,kind)
                    if id then
                        if not ContextActions.Supports(id,kind) then return true,nil,kind end
                        if actionId and actionId~=id then return true,nil,kind end
                        actionId=id; winningKind=kind
                    end
                end
            end
            return actionId~=nil,actionId,winningKind
        end
        local matched,id,kind=group(groups[1])
        if matched then return matched,id,kind end
        if unitsOnly then return false end
        if ContextActions.MatchesContext(selection,'empty') then
            id=rowAction('empty'); if id then return true,id,'empty' end
        end
        matched,id,kind=group(groups[2]); if matched then return matched,id,kind end
        if ContextActions.MatchesContext(selection,'factory') then
            id=rowAction('factory'); if id then return true,id,'factory' end
        end
        matched,id,kind=group(groups[3]); if matched then return matched,id,kind end
        for _,name in ipairs({'transport','mex','scout','other'}) do
            if ContextActions.MatchesContext(selection,name) or (name=='other' and ContextActions.MatchesContext(selection,'units')) then
                id=rowAction(name); if id then return true,id,name,name=='other' and ContextActions.MatchesContext(selection,'units') end
            end
        end
        return false
    end

    local function ExecuteRow(binding,kind,action,context,id)
        local row=service.contextModel:ResolveRow(binding,kind)
        if not row or not row.fallback or not ContextActions.IsSelection(action.id) then
            return ContextActions.Execute(action,context,id)
        end
        local result,outcome=ContextActions.ExecuteWithOutcome(action,context,id)
        if outcome~='not_found' then return result end
        local fallback=ContextActions.Get(row.fallback)
        if not fallback or not ContextActions.Supports(row.fallback,kind) then return result end
        local fresh=adapter:Context(service.isReplay)
        fresh.absolute=context.absolute or kind=='empty'
        fresh.legacyUnits=context.legacyUnits
        fresh.resolvedContext=kind
        local fallbackResult=ContextActions.Execute(fallback,fresh,id)
        return fallbackResult or result
    end

    local function RunResolved(binding,context,id,unitsOnly,quickId)
        local matched,actionId,kind,legacyUnits=ResolveContext(binding,context.selection,unitsOnly)
        if not matched then return false end
        local action=actionId and ContextActions.Get(actionId)
        context.legacyUnits=legacyUnits
        context.resolvedContext=kind
        if not action or not ContextActions.Supports(actionId,kind) or not ContextActions.Available(action,context) then
            return true,false,T('hotbuild.runtime.s001')
        end
        local called,result=pcall(ExecuteRow,binding,kind,action,context,id)
        if not called then return true,false,tostring(result) end
        if result then
            continuation:Remember(id,action,context)
            RememberQuick(binding,kind,quickId or id,context)
        end
        return true,result,result and actionId or T('hotbuild.runtime.s002')
    end

    local function RunCursor(binding,context,id)
        if not binding or binding.absolute then return false end
        local row=service.contextModel:ResolveRow(binding,'cursor')
        local action=row and row.action and ContextActions.Get(row.action)
        if not action or not ContextActions.Supports(action.id,'cursor') then return false end
        local previous=context.resolvedContext
        context.resolvedContext='cursor'
        local available,eligible=pcall(ContextActions.Available,action,context)
        if not available or not eligible then context.resolvedContext=previous; return false end
        continuation:Clear()
        local called,result=pcall(ExecuteRow,binding,'cursor',action,context,id)
        context.resolvedContext=previous
        if not called then return true,false,tostring(result) end
        return true,result,result and action.id or T('hotbuild.runtime.s003')
    end

    function service:RefreshKeys()
        local ok, message = true, nil
        if self.model:CanWrite() then
            ok, message = keys:Apply(self.model:List(), self.model:GetQuarantinedIds())
        end
        if type(keys.ApplyAbsolute)=='function' and self.contextModel:CanSave() then
            local contextKeysOk, contextKeysMessage = keys:ApplyAbsolute(self.contextModel:List())
            if not contextKeysOk then ok, message = contextKeysOk, contextKeysMessage end
        end
        if not keyboardBindings:GetPairError() then keyboardBindings:Refresh() end
        if not ok then WARN('[ClaretHotbuild] ' .. tostring(message)) end
        return ok, message
    end

    function service:Start(scope)
        scope:Defer(function()
            self.active = false
            if holdModule then holdModule.StopAll() end
            continuation:Clear()
            if cycleMenu then cycleMenu:Destroy(); cycleMenu=nil end
            keys:Stop()
        end)
        self.active = true
        self:RefreshKeys()
    end

    function service:Execute(id, pairedContext, chord, quickChord, shiftHeld)
        if shiftHeld==nil then
            local ok,down=pcall(IsKeyDown,16)
            shiftHeld=ok and down==true
        end
        self.unavailableDiagnostic=nil
        if not self.active or self.isReplay or IsKeyCaptureActive() then return false end
        self:Catalog():RefreshTemplates()
        if not adapter then adapter = Adapter.Create(self:Catalog()) end
        local contextOk, context = pcall(adapter.Context, adapter, self.isReplay)
        if not contextOk then
            WARN('[ClaretHotbuild] Selection context failed: ' .. tostring(context))
            self.unavailableDiagnostic={reason='context_error',details=tostring(context)}
            return false, tostring(context)
        end
        local options=ReUI.Options and ReUI.Options.Mods and ReUI.Options.Mods['ClaretCore']
        local probe=options and options.probeEnabled
        context.trace=probe and probe:Get() or false
        local activeBinding=self.model:Get(id)
        context.bindingEntries=activeBinding and activeBinding.entries or nil
        context.shiftHeld=shiftHeld==true
        local activeContext=pairedContext
        if not chord and keyboardBindings:GetPairError() then
            activeContext=activeBinding and activeBinding.grid and activeBinding.grid.context
        end
        local dispatchId=chord and ('keyboard:pair:'..chord) or id
        local quickId=quickChord and ('keyboard:pair:'..quickChord) or dispatchId
        local composite=activeContext and self.contextModel:Get(activeContext)
        local cursorMatched,cursorResult,cursorMessage=RunCursor(composite,context,dispatchId)
        if cursorMatched then return cursorResult,cursorMessage end
        local quickHandled,quickResult,quickMessage=continuation:ContinueQuick(quickId,context,dispatchId)
        if quickHandled then return quickResult,quickMessage end
        for _,row in ipairs(composite and composite.rows or {}) do
            local action=row.context=='empty' and row.action and ContextActions.Get(row.action)
            if action and action.continuation=='accumulate' and action.special and string.find(action.special,'^next_engineer_') then
                local key=chord and keys:HeldChord(chord) or keys:HeldKey(id)
                if key and not holdModule then holdModule=import('/mods/ClaretHotbuild/modules/EngineerHold.lua') end
                local hold=key and holdModule
                if hold and hold.Active(key) then return true,action.id end
                continuation:Clear()
                local called,result=pcall(ExecuteRow,composite,'empty',action,context,dispatchId)
                if not called then return nil,'Context action failed: '..tostring(result) end
                if result then RememberQuick(composite,'empty',quickId,context) end
                if hold and self.active and not IsKeyCaptureActive() then
                    hold.Start(key,function()
                        if not self.active or IsKeyCaptureActive() or self.isReplay then hold.Stop(key); return end
                        local fresh=adapter:Context(self.isReplay)
                        ContextActions.Execute(action,fresh,dispatchId)
                    end)
                end
                return result,result and action.id or T('hotbuild.runtime.s005')
            end
        end
        local continued, continuationResult, continuationMessage = continuation:Continue(dispatchId, context)
        if continued then return continuationResult, continuationMessage end
        local commandMode = import('/lua/ui/game/commandmode.lua').GetCommandMode()
        local afterBlueprint
        if lastPlacementBinding == dispatchId and commandMode[1] == 'build' and commandMode[2] then
            afterBlueprint = commandMode[2].claretEntry or commandMode[2].name
        end
        local binding = self.model:Get(id)
        local contextId = activeContext
        local kind = contextId and ContextActions.Classify(context.selection)
        local function RunContext(unitsOnly)
            if not contextId then return false end
            local composite = self.contextModel:Get(contextId)
            if not composite then return true, nil, T('hotbuild.runtime.s006')..tostring(contextId) end
            return RunResolved(composite,context,dispatchId,unitsOnly,quickId)
        end
        local matched, ok, message
        local hotbuildPriority = false
        if ContextActions.HasOrdinaryBuilder(context.selection) and binding then
            local builderContext={selection=ContextActions.OrdinaryBuilders(context.selection),isReplay=context.isReplay,
                focusArmy=context.focusArmy,orders=context.orders,plans={},sources=nil,
                bindingEntries=binding.entries}
            for _, entry in ipairs(binding.entries or {}) do
                if entry.kind == 'blueprint' then
                    local ok,canBuild=pcall(adapter.CanBuild,adapter,entry.id,builderContext)
                    if ok and canBuild then hotbuildPriority=true; break end
                end
            end
        end
        matched, ok, message = RunContext(true)
        local mobileFactoryPriority = ContextActions.HasMobileFactory(context.selection)
        if not matched and mobileFactoryPriority and not hotbuildPriority then matched, ok, message = RunContext() end
        if not matched and hotbuildPriority then
            ok, message = self.model:Execute(id, context, adapter, afterBlueprint)
        elseif not matched then
            matched, ok, message = RunContext()
            if not matched then ok, message = self.model:Execute(id, context, adapter, afterBlueprint) end
        end
        local newMode = import('/lua/ui/game/commandmode.lua').GetCommandMode()
        if ok and newMode[1] == 'build' and newMode[2] and (newMode[2].claretEntry or newMode[2].name) == message then
            lastPlacementBinding = dispatchId
            -- Presentation failures must never suppress a successful build command.
            local shown,showError=pcall(function()
                local binding=self.model:Get(id)
                local records={}
                for _,entry in ipairs(binding.entries) do
                    if entry.kind=='blueprint' and adapter:CanBuild(entry.id,context) then
                        local plan=context.plans[entry.id]
                        if plan and plan.placement then table.insert(records,self:Catalog():Get(entry.id)) end
                    end
                end
                if not cycleMenu then cycleMenu=import('/mods/ClaretHotbuild/modules/CycleMenu.lua').Create(GetFrame(0)) end
                cycleMenu:Show(binding.name,records,message)
            end)
            if not shown then WARN('[ClaretHotbuild] Cycle preview failed: '..tostring(showError)) end
        else
            lastPlacementBinding = nil
            if cycleMenu then cycleMenu:Hide() end
        end
        if ok == nil then WARN('[ClaretHotbuild] ' .. tostring(message)) end
        if not ok then
            local options=ReUI.Options and ReUI.Options.Mods and ReUI.Options.Mods['ClaretCore']
            local probe=options and options.probeEnabled
            if probe and probe:Get() then
                local entries=binding and binding.entries or {}
                local parts={}
                local blueprintCount, missingCount, unbuildableCount=0,0,0
                for _,entry in ipairs(entries) do
                    if entry.kind=='blueprint' then
                        blueprintCount=blueprintCount+1
                        local present=self:Catalog():Get(entry.id)~=nil
                        if not present then missingCount=missingCount+1 end
                        local plan=context.plans[entry.id]
                        if plan==false then unbuildableCount=unbuildableCount+1 end
                        table.insert(parts,entry.id..':'..(not present and 'catalog_missing' or
                            (plan==false and 'not_buildable' or (plan and 'buildable' or 'unchecked'))))
                    else table.insert(parts,'action:'..entry.id) end
                end
                local reason
                if ok==nil then reason='execution_error'
                elseif matched then reason='context_unavailable'
                elseif not binding then reason='unknown_id'
                elseif table.getn(entries)==0 then reason='empty_preset'
                elseif table.getn(context.selection)==0 then reason='no_selection'
                elseif context.focusArmy < 1 then reason='no_focus_army'
                elseif blueprintCount>0 and missingCount==blueprintCount and blueprintCount==table.getn(entries) then reason='catalog_missing'
                elseif blueprintCount>0 and unbuildableCount+missingCount==blueprintCount and blueprintCount==table.getn(entries) then reason='not_buildable'
                else reason='no_applicable_entry' end
                self.unavailableDiagnostic={reason=reason,details='id='..tostring(id)..',selection='..tostring(table.getn(context.selection))
                    ..',focus='..tostring(context.focusArmy)..',entries='..table.concat(parts,'|')..',message='..tostring(message or 'none')}
            end
        end
        return ok, message
    end

    function service:ExecuteAbsolute(id,chord,quickChord)
        if not self.active or self.isReplay or IsKeyCaptureActive() then return false end
        local composite=self.contextModel:Get(id)
        if not composite or not composite.absolute then return false, T('hotbuild.runtime.s007') end
        local actionId
        for _,row in ipairs(composite.rows or {}) do
            if row.context=='empty' then actionId=row.action; break end
        end
        local action=actionId and ContextActions.Get(actionId)
        if not action then return false, T('hotbuild.runtime.s008') end
        local continuationId=chord and ('keyboard:pair:'..chord) or ('absolute:'..id)
        local quickId=quickChord and ('keyboard:pair:'..quickChord) or continuationId
        local contextOk,context=pcall(function()
            if not adapter then adapter=Adapter.Create(self:Catalog()) end
            return adapter:Context(self.isReplay)
        end)
        if not contextOk then return false, tostring(context) end
        context.absolute=true
        local actual=context
        local quickHandled,quickResult,quickMessage=continuation:ContinueQuick(quickId,actual,continuationId)
        if quickHandled then return quickResult,quickMessage end
        if action.continuation=='accumulate' and action.special and string.find(action.special,'^next_engineer_') then
            local key=chord and keys:HeldChord(chord) or (type(keys.HeldAbsoluteKey)=='function' and keys:HeldAbsoluteKey(id) or nil)
            if key and not holdModule then holdModule=import('/mods/ClaretHotbuild/modules/EngineerHold.lua') end
            local hold=key and holdModule
            if hold and hold.Active(key) then return true,action.id end
            continuation:Clear()
            local called,result=pcall(ExecuteRow,composite,'empty',action,actual,continuationId)
            if not called then return nil,'Absolute context action failed: '..tostring(result) end
            if hold and self.active and not IsKeyCaptureActive() then
                hold.Start(key,function()
                    if not self.active or IsKeyCaptureActive() or self.isReplay then hold.Stop(key); return end
                    local fresh=adapter:Context(self.isReplay); fresh.absolute=true
                    ContextActions.Execute(action,fresh,continuationId)
                end)
            end
            if result then continuation:Remember(continuationId,action,actual); RememberQuick(composite,'empty',quickId,actual) end
            return result,result and action.id or T('hotbuild.runtime.s009')
        end
        local continued,result,message=continuation:Continue(continuationId,actual)
        if continued then return result,message end
        local called,executed=pcall(ExecuteRow,composite,'empty',action,actual,continuationId)
        if not called then return nil,'Absolute context action failed: '..tostring(executed) end
        if executed then continuation:Remember(continuationId,action,actual); RememberQuick(composite,'empty',quickId,actual) end
        return executed,executed and action.id or T('hotbuild.runtime.s010')
    end

    function service:KeyboardAssignments() return keyboardBindings:GetAssignments() end
    function service:KeyboardChoices() return keyboardBindings:GetChoices() end
    function service:SetKeyboardAssignment(ref,key,mods)
        local ok,message=keyboardBindings:Set(ref,key,mods)
        if ok then continuation:Clear(); keyboardBindings:Refresh() end
        return ok,message
    end
    function service:ClearKeyboardAssignment(ref,key,mods)
        local ok,message=keyboardBindings:Clear(ref,key,mods)
        if ok then continuation:Clear(); keyboardBindings:Refresh() end
        return ok,message
    end
    function service:ValidateKeyboardAssignment(ref,key,mods) return keyboardBindings:Validate(ref,key,mods) end
    function service:GetDoubleForKey(key,mods) return keyboardBindings:GetDoubleForKey(key,mods) end
    function service:GetDoubleChoices(actionId) return keyboardBindings:GetDoubleChoices(actionId) end
    function service:SetDoubleForKey(key,mods,first,second)
        local ok,message=keyboardBindings:SetDoubleForKey(key,mods,first,second)
        if ok then continuation:Clear(); keyboardBindings:Refresh() end
        return ok,message
    end
    function service:ClearDoubleForKey(key,mods)
        local ok,message=keyboardBindings:ClearDoubleForKey(key,mods)
        if ok then continuation:Clear(); keyboardBindings:Refresh() end
        return ok,message
    end

    function service:ExecuteMappedPreset(id,chord) return self:Execute(id,nil,nil,chord) end
    function service:ExecuteMappedAbsolute(id,chord) return self:ExecuteAbsolute(id,nil,chord) end
    function service:ExecuteMappedComposite(id,chord) return self:ExecuteKeyboardComposite(id,nil,chord) end

    function service:ExecuteKeyboardAction(actionId,chord)
        if not self.active or self.isReplay or IsKeyCaptureActive() then return false end
        local action=ContextActions.Get(actionId)
        if not action then return false,T('hotbuild.runtime.s011') end
        local good,context=pcall(function()
            if not adapter then adapter=Adapter.Create(self:Catalog()) end
            return adapter:Context(self.isReplay)
        end)
        if not good then return false,tostring(context) end
        if ContextActions.Supports(actionId,'empty') then context.absolute=true end
        local id='keyboard:action:'..actionId
        local quickId=chord and ('keyboard:pair:'..chord) or id
        local quickHandled,quickResult,quickMessage=continuation:ContinueQuick(quickId,context,id)
        if quickHandled then return quickResult,quickMessage end
        if not ContextActions.Available(action,context) then return false,T('hotbuild.runtime.s012') end
        local continued,result,message=continuation:Continue(id,context)
        if continued then return result,message end
        local called,executed=pcall(ContextActions.Execute,action,context,id)
        if not called then return false,tostring(executed) end
        if executed then
            continuation:Remember(id,action,context)
            local double=chord and keyboardBindings:GetDouble(chord)
            local second=double and double.first==actionId and ContextActions.Get(double.second)
            if second then
                continuation:RememberQuick(quickId,second,context,true)
            end
        end
        return executed,executed and actionId or T('hotbuild.runtime.s013')
    end

    function service:ExecuteKeyboardComposite(compositeId,chord,quickChord)
        if not self.active or self.isReplay or IsKeyCaptureActive() then return false end
        local composite=self.contextModel:Get(compositeId)
        if not composite then return false,T('hotbuild.runtime.s014') end
        if composite.absolute then return self:ExecuteAbsolute(compositeId,chord,quickChord) end
        local good,context=pcall(function()
            if not adapter then adapter=Adapter.Create(self:Catalog()) end
            return adapter:Context(self.isReplay)
        end)
        if not good then return false,tostring(context) end
        local continuationId=chord and ('keyboard:pair:'..chord) or ('keyboard:composite:'..compositeId)
        local quickId=quickChord and ('keyboard:pair:'..quickChord) or continuationId
        local cursorMatched,cursorResult,cursorMessage=RunCursor(composite,context,continuationId)
        if cursorMatched then return cursorResult,cursorMessage end
        local quickHandled,quickResult,quickMessage=continuation:ContinueQuick(quickId,context,continuationId)
        if quickHandled then return quickResult,quickMessage end
        local continued,continueResult,continueMessage=continuation:Continue(continuationId,context)
        if continued then return continueResult,continueMessage end
        local matched,result,message=RunResolved(composite,context,continuationId,false,quickId)
        if matched then return result,message end
        return false,T('hotbuild.runtime.s015')
    end

    function service:ExecuteKeyboardPair(chord,shiftHeld)
        if shiftHeld==nil then
            local ok,down=pcall(IsKeyDown,16)
            shiftHeld=ok and down==true
        end
        local pair=keyboardBindings:GetPair(chord)
        if not pair then return false,T('hotbuild.runtime.s016') end
        if pair.preset and not pair.action then return self:Execute(pair.preset,pair.composite,chord,nil,shiftHeld) end
        if pair.preset then
            self:Catalog():RefreshTemplates()
            local binding=self.model:Get(pair.preset)
            local eligible=false
            if not adapter then adapter=Adapter.Create(self:Catalog()) end
            local contextOk,context=pcall(adapter.Context,adapter,self.isReplay)
            if binding and contextOk and ContextActions.HasOrdinaryBuilder(context.selection) then
                local builders={selection=ContextActions.OrdinaryBuilders(context.selection),isReplay=context.isReplay,
                    focusArmy=context.focusArmy,orders=context.orders,plans={},sources=nil,
                    bindingEntries=binding.entries}
                for _,entry in ipairs(binding.entries or {}) do
                    if entry.kind=='blueprint' then
                        local ok,canBuild=pcall(adapter.CanBuild,adapter,entry.id,builders)
                        if ok and canBuild then eligible=true; break end
                    end
                end
            end
            if eligible then return self:Execute(pair.preset,pair.composite,chord,nil,shiftHeld) end
        end
        local first=pair.action and pair.action==pair.doubleFirst and ContextActions.Get(pair.action)
        local second=pair.doubleSecond and ContextActions.Get(pair.doubleSecond)
        if first and second and ContextActions.Supports(first.id,'empty') then
            local good,context=pcall(function()
                if not adapter then adapter=Adapter.Create(self:Catalog()) end
                return adapter:Context(self.isReplay)
            end)
            if not good then return false,tostring(context) end
            local selectedTarget=false
            if second.id=='load_transports' then
                selectedTarget=ContextActions.MatchesContext(context.selection,'transport')
                    and (ContextActions.MatchesContext(context.selection,'land')
                        or ContextActions.MatchesContext(context.selection,'air')
                        or ContextActions.MatchesContext(context.selection,'navy'))
            else
                for _,kind in ipairs(second.contexts or {}) do
                    if kind~='empty' and ContextActions.MatchesContext(context.selection,kind) then
                        selectedTarget=true; break
                    end
                end
            end
            if not selectedTarget and (first.id=='select_transport' or first.id=='select_transport_nearest')
                and ContextActions.MatchesContext(context.selection,'transport') then
                selectedTarget=true
            end
            local action=selectedTarget and second or first
            if action==first or ContextActions.Supports(action.id,'empty') then context.absolute=true end
            if not ContextActions.Available(action,context) then return false,T('hotbuild.runtime.s013') end
            local called,result=pcall(ContextActions.Execute,action,context,'keyboard:pair:'..chord)
            if not called then return false,tostring(result) end
            return result,result and action.id or T('hotbuild.runtime.s013')
        end
        if pair.action then return self:ExecuteKeyboardAction(pair.action,chord) end
        if pair.preset then return self:Execute(pair.preset,pair.composite,chord,nil,shiftHeld) end
        if pair.composite then return self:ExecuteKeyboardComposite(pair.composite,chord) end
        return false,T('hotbuild.runtime.s017')
    end

    function service:ExecuteFactoryShift(chord,nativeAction)
        if self.active and not self.isReplay and not IsKeyCaptureActive() then
            if not adapter then adapter=Adapter.Create(self:Catalog()) end
            local ok,context=pcall(adapter.Context,adapter,self.isReplay)
            local pair=keyboardBindings:GetPair(chord)
            if ok and context.factorySelection and pair and pair.preset then
                local options=ReUI.Options and ReUI.Options.Mods and ReUI.Options.Mods['ClaretCore']
                local probe=options and options.probeEnabled
                if probe and probe:Get() then
                    LOG('[Claret][keys] factory_shift_intercept chord='..chord..' active=true')
                end
                return self:Execute(pair.preset,pair.composite,chord,nil,true)
            end
        end
        if type(nativeAction)=='string' and type(ConExecute)=='function' then
            ConExecute(nativeAction)
            return true
        end
        return false
    end

    function service:ValidatePreset(binding)
        if not self.model:CanWrite() then return false, T('hotbuild.runtime.s018') end
        local candidate=Model.Create(self.model:Export())
        local ok,message=candidate:Put(binding)
        if not ok then return false,message end
        local previous=self.model:Get(binding.id)
        if previous and table.getn(previous.entries)==table.getn(binding.entries or {}) then
            local unchanged=true
            for index,entry in ipairs(previous.entries) do
                local nextEntry=binding.entries[index]
                if not nextEntry or entry.kind~=nextEntry.kind or entry.id~=nextEntry.id then unchanged=false; break end
            end
            if unchanged then return true end
        end
        local warning
        for _,paired in ipairs(keyboardBindings:PairedBindings(candidate)) do
            if paired.id==binding.id then
                local valid,why,details=Compatibility.ValidateBinding(paired,self.contextModel,self:Catalog())
                if not valid then return false,why,details end
                warning=warning or why
            end
        end
        return true,warning
    end

    -- Save only after validation of the entire proposed configuration.
    function service:Commit(binding, removeId)
        if not self.model:CanWrite() then return false, T('hotbuild.runtime.s018') end
        if not removeId and binding and type(binding.name)=='string' and string.find(binding.name, '[^ -~]') then
            return false, T('hotbuild.runtime.s019')
        end
        local candidate = Model.Create(self.model:Export())
        local ok, message
        if removeId then ok, message = candidate:Delete(removeId)
        else ok, message = candidate:Put(binding) end
        if not ok then return false, message end
        local compatibilityMessage
        if binding then
            local compatible,message=self:ValidatePreset(binding)
            if not compatible then return false,message end
            compatibilityMessage=message
        end
        ok, message = keys:Validate(candidate:List())
        if not ok then return false, message end
        local before = self.model:Export()
        local exported = candidate:Export()
        ok, message = pcall(function()
            Prefs.SetToCurrentProfile('ClaretHotbuild', exported)
            SavePreferences()
        end)
        if not ok then
            Prefs.SetToCurrentProfile('ClaretHotbuild', before)
            return false, 'Could not save: ' .. tostring(message)
        end
        if removeId and not keyboardBindings:GetPairError() then
            local cleared,clearMessage=keyboardBindings:ClearPresetAssignments(removeId)
            if not cleared then
                pcall(function()
                    Prefs.SetToCurrentProfile('ClaretHotbuild',before)
                    SavePreferences()
                end)
                return false,clearMessage
            end
        end
        if removeId then self.model:Delete(removeId) else self.model:Put(binding) end
        continuation:Clear()
        self:RefreshKeys()
        return true, compatibilityMessage or T('hotbuild.runtime.s021')
    end

    function service:RegisterAction(definition)
        return self.model:RegisterAction(definition)
    end

    function service:CommitContext(binding, removeId, confirmedDelete)
        if not self.contextModel:CanSave() then return false, T('hotbuild.runtime.s022') end
        if removeId then
            if keyboardBindings:HasDirectAssignment({kind='composite',id=removeId}) and confirmedDelete~=true then
                return false,T('hotbuild.runtime.s025')
            end
        end
        local before=Prefs.GetFromCurrentProfile('ClaretHotbuildContexts')
        local candidate=ContextModel.Create(self.contextModel:Export(),ContextActions)
        local ok,message
        if removeId then ok,message=candidate:Delete(removeId) else ok,message=candidate:Put(binding) end
        if not ok then return false,message end
        local compatibilityMessage
        if binding then
            local compatible, message, details = Compatibility.ValidateContext(candidate:Get(binding.id), keyboardBindings:PairedBindings(self.model), self:Catalog())
            if not compatible then return false, message, details end
            compatibilityMessage=message
        end
        ok,message=pcall(function()
            Prefs.SetToCurrentProfile('ClaretHotbuildContexts',candidate:Export())
            SavePreferences()
        end)
        if not ok then
            Prefs.SetToCurrentProfile('ClaretHotbuildContexts',before)
            return false,T('hotbuild.runtime.s026')..tostring(message)
        end
        if removeId and not keyboardBindings:GetPairError() then
            local cleared,clearMessage=keyboardBindings:ClearCompositeAssignments(removeId)
            if not cleared then
                pcall(function()
                    Prefs.SetToCurrentProfile('ClaretHotbuildContexts',before)
                    SavePreferences()
                end)
                return false,clearMessage
            end
        end
        self.contextModel=candidate
        continuation:Clear()
        self:RefreshKeys()
        return true,compatibilityMessage or T('hotbuild.runtime.s027')
    end

    function service:OpenContextEditor(parent,layout,memory)
        if self.editor and not IsDestroyed(self.editor) then return self.editor end
        if holdModule then holdModule.StopAll() end
        continuation:Clear()
        if cycleMenu then cycleMenu:Hide() end
        keys:Stop()
        local window
        local ok,err=pcall(function()
            window=import('/mods/ClaretHotbuild/modules/ContextEditor.lua').Create(parent,self,layout,memory)
        end)
        if not ok then self:RefreshKeys(); error(err) end
        self.editor=window
        local oldDestroy=window.OnDestroy
        window.OnDestroy=function(control)
            self.editor=nil
            oldDestroy(control)
            self:RefreshKeys()
        end
        return window
    end

    function service:OpenEditor(parent, layout, memory)
        if self.editor and not IsDestroyed(self.editor) then return self.editor end
        if holdModule then holdModule.StopAll() end
        continuation:Clear()
        if cycleMenu then cycleMenu:Hide() end
        keys:Stop()
        self:Catalog():RefreshTemplates()
        local Editor = import('/mods/ClaretHotbuild/modules/Editor.lua')
        local window
        local ok, openError = pcall(function() window = Editor.Create(parent, self, layout, memory) end)
        if not ok then self:RefreshKeys(); error(openError) end
        self.editor = window
        local oldDestroy = window.OnDestroy
        window.OnDestroy = function(control)
            self.editor = nil
            oldDestroy(control)
            self:RefreshKeys()
        end
        return window
    end

    function service:OpenKeyboardEditor(parent,layout,perf)
        if self.editor and not IsDestroyed(self.editor) then return self.editor end
        local prepareStart=perf and perf:Now()
        if holdModule then holdModule.StopAll() end
        continuation:Clear()
        if cycleMenu then cycleMenu:Hide() end
        keys:Stop()
        if perf then perf:Add('runtime_prepare',prepareStart); perf:Emit('runtime_prepare') end
        local window
        local ok,err=pcall(function()
            window=import('/mods/ClaretHotbuild/modules/KeyboardEditor.lua').Create(parent,keyboardBindings,layout,perf)
        end)
        if not ok then self:RefreshKeys(); error(err) end
        self.editor=window
        local oldDestroy=window.OnDestroy
        window.OnDestroy=function(control)
            self.editor=nil
            oldDestroy(control)
            local measuring=perf and perf:Enabled()
            local closeStart=measuring and perf:Now()
            self:RefreshKeys()
            if measuring then perf:Add('close_refresh',closeStart); perf:Emit('close_refresh') end
        end
        return window
    end

    function service:Destroy()
        self.active = false
        if holdModule then holdModule.StopAll() end
        continuation:Clear()
        if self.editor and not IsDestroyed(self.editor) then self.editor:Destroy() end
        self.editor = nil
        if cycleMenu then cycleMenu:Destroy(); cycleMenu=nil end
        keys:Stop()
        if current == self then current = nil end
    end

    for _, warning in ipairs(service.model:GetLoadWarnings()) do WARN('[ClaretHotbuild] ' .. warning) end
    for _, warning in ipairs(service.contextModel:GetLoadWarnings()) do WARN('[ClaretHotbuild] ' .. warning) end
    current = service
    service:RefreshKeys()
    return service
end
