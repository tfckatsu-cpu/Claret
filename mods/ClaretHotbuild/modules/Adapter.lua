-- Small bridge to FAF's normal UI command APIs. All discovery happens on keypress.
local techTabs = {T1=1,T2=2,T3=3,T4=4,EXPERIMENTAL=4}
local LOG = LOG or function() end

local function T(key)
    local core = ReUI and ReUI.ClaretCore
    local localization = core and core.Localization
    if localization and type(localization.Text) == 'function' then return localization.Text(key) end
    return key
end

local function CurrentFactoryTechTab()
    if type(import)~='function' then return nil end
    local loaded,construction=pcall(import,'/lua/ui/game/construction.lua')
    local getter=loaded and construction and construction.GetCurrentTechTab
    if type(getter)~='function' then return nil end
    local read,tab=pcall(getter)
    if read and type(tab)=='number' then return tab end
end

local function CanPlaceBuilds(unit)
    return unit:IsInCategory('COMMAND') or unit:IsInCategory('SUBCOMMANDER')
        or unit:IsInCategory('ENGINEER')
end

local function SingleTierAssignment(record, context, catalog)
    if not context.bindingEntries or (record.kind~='LAND' and record.kind~='AIR' and record.kind~='NAVAL') then
        return false
    end
    local counts=context.bindingTierCounts
    if not counts then
        counts={}
        for _,entry in ipairs(context.bindingEntries) do
            if entry.kind=='blueprint' then
                local assigned=catalog:Get(entry.id)
                local tier=assigned and techTabs[assigned.tech]
                if tier and tier>=1 and tier<=3
                    and (assigned.kind=='LAND' or assigned.kind=='AIR' or assigned.kind=='NAVAL') then
                    local key=assigned.faction..':'..assigned.kind
                    counts[key]=(counts[key] or 0)+1
                end
            end
        end
        context.bindingTierCounts=counts
    end
    local key=record.faction..':'..record.kind
    return counts[key]==1
end

local function BuildSources(context)
    if context.sources then return context.sources end
    -- Read each unit's capability list once per press, not once per priority entry.
    local sources={}
    for _,unit in ipairs(context.selection) do
        local _,_,category=GetUnitCommandData({unit})
        local buildable={}
        if category then
            for _,buildId in ipairs(EntityCategoryGetUnitList(category) or {}) do buildable[buildId]=true end
        end
        table.insert(sources,{unit=unit,buildable=buildable})
    end
    context.sources=sources
    return sources
end

-- A queue template may start with a factory upgrade; later entries become
-- buildable only after that upgrade, so the whole queue is checked in order.
local function Queueable(record,buildable)
    local entries=record.queueData or {}
    for index=1,table.getn(entries) do
        local entry=entries[index]
        if not buildable[entry[1]] then
            local upgraded=false
            for earlier=1,index-1 do
                if entries[earlier][3] then upgraded=true; break end
            end
            if not upgraded then return false end
        end
    end
    return true
end

-- FAF's subset helper does not restore after an exception. Keep this UI
-- selection transaction explicit, with restoration on both paths.
local function WithFactorySelection(factories,context,issue)
    local same=table.getn(factories)==table.getn(context.selection)
    local selectedSet={}
    for _,unit in ipairs(context.selection) do selectedSet[unit]=true end
    for _,unit in ipairs(factories) do if not selectedSet[unit] then same=false end end
    if same then issue(); return end
    local Commands=import('/lua/ui/game/commandmode.lua')
    local GameMain=import('/lua/ui/game/gamemain.lua')
    local originalSelection=GetSelectedUnits()
    Commands.CacheAndClearCommandMode()
    local ok,err=pcall(function()
        GameMain.SetIgnoreSelection(true)
        SelectUnits(factories)
        issue()
    end)
    local restored,restoreError=pcall(SelectUnits,originalSelection)
    local ignored,ignoreError=pcall(GameMain.SetIgnoreSelection,false)
    local mode,modeError=pcall(Commands.RestoreCommandMode,true)
    if not ok then error(err) end
    if not restored then error(restoreError) end
    if not ignored then error(ignoreError) end
    if not mode then error(modeError) end
end

---@param catalog table
---@return table
function Create(catalog)
    local adapter = {}

    function adapter:Context(isReplay)
        local selected = {}
        for _, unit in ipairs(GetSelectedUnits() or {}) do
            if not unit:IsDead() then table.insert(selected, unit) end
        end
        local factorySelection=table.getn(selected)>0
        for _,unit in ipairs(selected) do
            if not unit:IsInCategory('FACTORY') and not unit:IsInCategory('EXTERNALFACTORY') then
                factorySelection=false; break
            end
        end
        local context = { selection = selected, isReplay = isReplay,
            orders = {}, plans = {}, focusArmy = GetFocusArmy(),
            factorySelection=factorySelection,
            factoryTechTab=factorySelection and CurrentFactoryTechTab() or nil }
        if table.getn(selected) > 0 then
            local orders = GetUnitCommandData(selected)
            for _, order in ipairs(orders or {}) do context.orders[order] = true end
        end
        return context
    end

    -- A factory queue template needs one capable factory for the whole queue.
    function adapter:TemplatePlan(record, context)
        local factories={}
        local seen={}
        for _,item in ipairs(BuildSources(context)) do
            local unit=item.unit
            if unit:IsInCategory('FACTORY') or unit:IsInCategory('EXTERNALFACTORY') then
                local source=unit
                if unit:IsInCategory('EXTERNALFACTORY') then
                    local complete=type(unit.GetFractionComplete)~='function'
                        or unit:GetFractionComplete()==1
                    source=complete and unit:GetCreator() or nil
                    if source and not source:IsInCategory('FACTORY') then source=nil end
                end
                if source and not source:IsDead() and not seen[source]
                    and Queueable(record,item.buildable) then
                    seen[source]=true
                    table.insert(factories,source)
                end
            end
        end
        if table.getn(factories)==0 then return nil end
        return {factories=factories,unitTemplate=record}
    end

    function adapter:CanBuild(id, context)
        if context.isReplay or context.focusArmy < 1 then return false end
        local record=catalog:Get(id)
        if not record then return false end
        if record.unitTemplate then
            if context.plans[id] ~= nil then return context.plans[id] ~= false end
            local plan=self:TemplatePlan(record,context)
            context.plans[id]=plan or false
            return plan ~= nil
        end
        local recordTechTab=techTabs[record.tech]
        if context.factorySelection and record.kind~='STRUCTURE' and recordTechTab
            and recordTechTab~=context.factoryTechTab then
            local singleTier=recordTechTab<=3 and context.factoryTechTab and context.factoryTechTab>=1
                and context.factoryTechTab<=3 and SingleTierAssignment(record,context,catalog)
            if not singleTier then return false end
        end
        if context.plans[id] ~= nil then return context.plans[id] ~= false end
        if record.templateData then
            -- Initialize per-unit discovery through an ordinary constituent blueprint.
            self:CanBuild(record.firstBlueprint,context)
            local capable=false
            for _,source in ipairs(context.sources or {}) do
                local unit=source.unit
                if CanPlaceBuilds(unit) then
                    local all=true
                    for i=3,table.getn(record.templateData) do
                        if not source.buildable[record.templateData[i][1]] then all=false; break end
                    end
                    if all then capable=true; break end
                end
            end
            context.plans[id]=capable and {placement=true,template=record} or false
            return capable
        end
        local sources = BuildSources(context)
        local factories = {}
        local seen = {}
        local place = false
        for _, item in ipairs(sources) do
            local unit = item.unit
            if item.buildable[id] then
                if unit:IsInCategory('FACTORY') or unit:IsInCategory('EXTERNALFACTORY') then
                    -- Structures must enter placement mode, even if a factory's
                    -- capability list happens to include the blueprint.
                    if record.kind ~= 'STRUCTURE' then
                        local source = unit
                        if unit:IsInCategory('EXTERNALFACTORY') then
                            -- Attached factories (carriers, air staging) order through the unit
                            -- that created them, as FAF's TranslateExFacUnits does. Only a
                            -- finished attachment owned by a real factory may queue units.
                            local complete = type(unit.GetFractionComplete) ~= 'function'
                                or unit:GetFractionComplete() == 1
                            source = complete and unit:GetCreator() or nil
                            if source and not source:IsInCategory('FACTORY') then source = nil end
                        end
                        if source and not source:IsDead() and not seen[source] then
                            seen[source] = true
                            table.insert(factories, source)
                        end
                    end
                elseif CanPlaceBuilds(unit) then
                    place = true
                end
            end
        end
        local plan = false
        if table.getn(factories) > 0 then plan = { factories = factories }
        elseif place then plan = { placement = true } end
        context.plans[id] = plan
        return plan ~= false
    end

    function adapter:Build(id, context)
        if not self:CanBuild(id, context) then return false, 'Not buildable by this selection' end
        local plan = context.plans[id]
        if plan.template then
            local record=plan.template
            -- Pass a fresh numeric/string-only copy: the engine may rotate its active data.
            local data={record.templateData[1],record.templateData[2]}
            for i=3,table.getn(record.templateData) do
                local item=record.templateData[i]; table.insert(data,{item[1],item[2],item[3],item[4]})
            end
            ClearBuildTemplates()
            import('/lua/ui/game/commandmode.lua').StartCommandMode('build',
                {name=record.firstBlueprint,claretEntry=id})
            SetActiveBuildTemplate(data)
            return true
        end
        if plan.unitTemplate then
            local record=plan.unitTemplate
            if context.trace then
                LOG('[Claret][keys] factory_template='..tostring(record.id)
                    ..' entries='..tostring(table.getn(record.queueData))
                    ..' unit_count='..tostring(record.unitCount)
                    ..' factories='..tostring(table.getn(plan.factories))
                    ..' selection='..tostring(table.getn(context.selection)))
            end
            WithFactorySelection(plan.factories,context,function()
                for _,entry in ipairs(record.queueData) do
                    IssueBlueprintCommand('UNITCOMMAND_BuildFactory',entry[1],entry[2])
                end
            end)
            import('/lua/ui/game/construction.lua').RefreshUI()
            return true
        end
        if plan.factories then
            -- One press queues one unit: Shift keeps its native FAF meaning.
            if context.trace then
                LOG('[Claret][keys] factory_order blueprint='..tostring(id)
                    ..' shift='..tostring(context.shiftHeld==true)
                    ..' factories='..tostring(table.getn(plan.factories))
                    ..' selection='..tostring(table.getn(context.selection)))
            end
            WithFactorySelection(plan.factories,context,function()
                IssueBlueprintCommand('UNITCOMMAND_BuildFactory', id, 1)
            end)
            import('/lua/ui/game/construction.lua').RefreshUI()
        else
            ClearBuildTemplates()
            import('/lua/ui/game/commandmode.lua').StartCommandMode('build', { name = id })
        end
        return true
    end

    return adapter
end

---@param model table
function RegisterActions(model)
    local definitions = {
        { id = 'claret.order.reclaim', labelKey = 'hotbuild.action.claret_order_reclaim.label',
            descriptionKey = 'hotbuild.action.claret_order_reclaim.description', order = 'RULEUCC_Reclaim' },
        { id = 'claret.order.assist', labelKey = 'hotbuild.action.claret_order_assist.label',
            descriptionKey = 'hotbuild.action.claret_order_assist.description', order = 'RULEUCC_Guard' },
        { id = 'claret.order.move', labelKey = 'hotbuild.action.claret_order_move.label',
            descriptionKey = 'hotbuild.action.claret_order_move.description', order = 'RULEUCC_Move' },
    }
    for _, definition in ipairs(definitions) do
        local item = definition
        model:RegisterAction {
            id = item.id, label = T(item.labelKey), description = T(item.descriptionKey),
            available = function(context)
                return not context.isReplay and context.focusArmy > 0 and context.orders[item.order] == true
            end,
            execute = function(context)
                import('/lua/ui/game/commandmode.lua').StartCommandMode('order', { name = item.order })
                return true
            end,
        }
    end
end
