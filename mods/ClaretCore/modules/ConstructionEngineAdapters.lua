-- Binds the presentation/action models to stable FAF UI and UserUnit APIs.
-- Session-specific cargo, queue projection, tab state and UI event wiring stay
-- caller-owned because ReUI.Construction and stock construction.lua own them.

local function Resolve(engine, name)
    local value = engine and engine[name]
    if value ~= nil then return value end
    return _G[name]
end

local function Method(unit, name, ...)
    if unit == nil or type(unit[name]) ~= 'function' then
        return false, 'unit method unavailable: ' .. name
    end
    local ok, a, b = pcall(unit[name], unit, ...)
    if not ok then return false, a end
    return true, a, b
end

function Create(engine)
    engine = engine or {}
    local imports = engine.import or import
    local game = engine.game or imports('/lua/game.lua')
    local commandMode = engine.commandMode or imports('/lua/ui/game/commandmode.lua')
    local blueprints = engine.blueprints or engine.__blueprints or __blueprints
    local categoryTable = engine.categories or categories

    local allowedSelection, allowedCategory, allowedIds, allowedOrder = nil, nil, {}, {}

    local function Global(name, ...)
        local fn = Resolve(engine, name)
        if type(fn) ~= 'function' then error('FAF API unavailable: ' .. name) end
        return fn(...)
    end

    local function Blueprint(unitOrId)
        if type(unitOrId) == 'string' then return blueprints[unitOrId] end
        local ok, blueprint = Method(unitOrId, 'GetBlueprint')
        if ok then return blueprint end
        return nil
    end

    local function HasCategory(unitOrId, category)
        local categoryValue = categoryTable and categoryTable[category]
        if categoryValue == nil then error('FAF category unavailable: ' .. tostring(category)) end
        return Global('EntityCategoryContains', categoryValue, unitOrId)
    end

    local function SameUnits(first, second)
        if type(first) ~= 'table' or type(second) ~= 'table'
            or table.getn(first) ~= table.getn(second) then return false end
        for index, unit in ipairs(first) do
            if second[index] ~= unit then return false end
        end
        return true
    end

    local function RefreshBuildability(selection)
        local ok, _, _, buildableCategory = pcall(Global, 'GetUnitCommandData', selection)
        if not ok then allowedSelection, allowedCategory, allowedIds, allowedOrder = nil, nil, {}, {}; return false end
        allowedSelection, allowedCategory, allowedIds, allowedOrder = {}, buildableCategory, {}, {}
        for index, unit in ipairs(selection or {}) do allowedSelection[index] = unit end
        if buildableCategory then
            local listOk, ids = pcall(Global, 'EntityCategoryGetUnitList', buildableCategory)
            if listOk and type(ids) == 'table' then
                for _, id in ipairs(ids) do
                    if not allowedIds[id] then table.insert(allowedOrder, id) end
                    allowedIds[id] = true
                end
            else
                allowedCategory = nil
            end
        end
        return allowedCategory ~= nil
    end

    local function IsBuildable(id, selection)
        selection = selection or Global('GetSelectedUnits') or {}
        if not SameUnits(allowedSelection, selection) then RefreshBuildability(selection) end
        return allowedCategory ~= nil and allowedIds[id] == true
    end

    local actions = {
        getCurrentSelection = function() return Global('GetSelectedUnits') end,
        isUnitValid = function(unit)
            local ok, dead = Method(unit, 'IsDead')
            return ok and dead ~= true
        end,
        selectUnits = function(units) return Global('SelectUnits', units) end,
        getBlueprint = function(id) return blueprints[id] end,
        getUnitBlueprint = Blueprint,
        getUnitBlueprintId = function(unit)
            local blueprint = Blueprint(unit)
            return blueprint and blueprint.BlueprintId
        end,
        hasCategory = HasCategory,
        isRestricted = function(id, army)
            return game.IsRestricted(id, army or Global('GetFocusArmy'))
        end,
        isBuildable = IsBuildable,
        needsMobileBuild = function(id) return HasCategory(id, 'NEEDMOBILEBUILD') end,
        isExternalFactory = function(unit) return HasCategory(unit, 'EXTERNALFACTORY') end,
        getCreator = function(unit)
            local ok, creator = Method(unit, 'GetCreator')
            if not ok then error(creator) end
            return creator
        end,
        issueBlueprintCommand = function(...) return Global('IssueBlueprintCommand', ...) end,
        issueBlueprintCommandToUnits = function(...) return Global('IssueBlueprintCommandToUnits', ...) end,
        startCommandMode = function(...) return commandMode.StartCommandMode(...) end,
        increaseBuildCountInQueue = function(...) return Global('IncreaseBuildCountInQueue', ...) end,
        decreaseBuildCountInQueue = function(...) return Global('DecreaseBuildCountInQueue', ...) end,
        improvedDeselection = true,
    }

    -- Buildable IDs use the same FAF category calculation as the native and
    -- ReUI construction panels, then the native buildable-category enumerator.
    local function GetBuildables(selection)
        if not RefreshBuildability(selection) then return {} end
        local army = Global('GetFocusArmy')
        local result = {}
        for _, id in ipairs(allowedOrder) do
            if not game.IsRestricted(id, army) then table.insert(result, id) end
        end
        return result
    end

    -- Attached-unit list includes contents from every selected transport. Keep
    -- only live mobile passengers and collapse entities exposed more than once.
    local function GetCargo(selection)
        if type(selection) ~= 'table' or table.getn(selection) == 0 then return {} end
        if categoryTable.MOBILE == nil then error('FAF category unavailable: MOBILE') end
        local attached = Global('GetAttachedUnitsList', selection)
        if type(attached) ~= 'table' or table.getn(attached) == 0 then return {} end
        local mobile = Global('EntityCategoryFilterDown', categoryTable.MOBILE, attached)
        if type(mobile) ~= 'table' then return {} end
        local result, seen = {}, {}
        for _, unit in ipairs(mobile) do
            local unitType = type(unit)
            if not seen[unit] and (unitType == 'table' or unitType == 'userdata')
                and actions.isUnitValid(unit) then
                seen[unit] = true
                table.insert(result, unit)
            end
        end
        return result
    end

    local function Module(modules, key, path)
        if modules and modules[key] then return modules[key] end
        return imports(path)
    end

    local function CreateModels(options)
        options = options or {}
        local modules = options.modules or engine.modules
        local sources = {
            choices = { 'ConstructionChoices', '/mods/ClaretCore/modules/ConstructionChoices.lua' },
            gridModel = { 'ConstructionGridModel', '/mods/ClaretCore/modules/ConstructionGridModel.lua' },
            selectionModel = { 'ConstructionSelection', '/mods/ClaretCore/modules/ConstructionSelection.lua' },
            queueModel = { 'ConstructionQueue', '/mods/ClaretCore/modules/ConstructionQueue.lua' },
            templatesModel = { 'ConstructionTemplates', '/mods/ClaretCore/modules/ConstructionTemplates.lua' },
            enhancementsModel = { 'ConstructionEnhancements', '/mods/ClaretCore/modules/ConstructionEnhancements.lua' },
            cargoState = { 'CargoSelection', '/mods/ClaretCore/modules/CargoSelection.lua' },
        }
        local loaded = {}
        for key, source in pairs(sources) do
            local ok, module = pcall(Module, modules, source[1], source[2])
            if not ok or type(module) ~= 'table' or type(module.Create) ~= 'function' then
                return nil, 'construction model dependency unavailable: ' .. source[1] .. ': ' .. tostring(module)
            end
            loaded[key] = module
        end

        local missing, errors = {}, {}
        local function RecordMissing(name, detail)
            errors[name] = tostring(detail)
        end
        local function AddMissing(name)
            table.insert(missing, name)
        end
        local buildTemplates, factoryTemplates = engine.buildTemplates, engine.factoryTemplates
        local enhancementCommon, enhancementQueue = engine.enhancementCommon, engine.enhancementQueue

        local function LoadImport(current, key, path)
            if current then return current end
            local ok, value = pcall(imports, path)
            if not ok then RecordMissing(key, value); return nil end
            return value
        end
        local function GetMobileTemplates()
            buildTemplates = LoadImport(buildTemplates, 'build_templates', '/lua/ui/game/build_templates.lua')
            if not buildTemplates or type(buildTemplates.GetTemplates) ~= 'function' then
                RecordMissing('build_templates', 'GetTemplates API unavailable')
                return nil
            end
            local ok, result = pcall(buildTemplates.GetTemplates)
            if not ok then RecordMissing('build_templates', result); return nil end
            errors.build_templates = nil
            return result
        end
        local function GetFactoryTemplates()
            -- This API is provided by the installed template integration; it is
            -- optional and may not exist in a vanilla FAF installation.
            factoryTemplates = LoadImport(factoryTemplates, 'factory_templates', '/lua/ui/templates_factory.lua')
            if not factoryTemplates or type(factoryTemplates.GetTemplates) ~= 'function' then
                RecordMissing('factory_templates', 'templates_factory.lua:GetTemplates unavailable')
                return nil
            end
            local ok, result = pcall(factoryTemplates.GetTemplates)
            if not ok then RecordMissing('factory_templates', result); return nil end
            errors.factory_templates = nil
            return result
        end

        local function Restriction(id, armyOrUnitId)
            local army = type(armyOrUnitId) == 'number' and armyOrUnitId or nil
            return game.IsRestricted(id, army or Global('GetFocusArmy'))
        end
        local function GetInstalled(unit)
            enhancementCommon = LoadImport(enhancementCommon, 'enhancement_common', '/lua/enhancementcommon.lua')
            if not enhancementCommon or type(enhancementCommon.GetEnhancements) ~= 'function' then
                error('EnhanceCommon.GetEnhancements unavailable')
            end
            local ok, entityId = Method(unit, 'GetEntityId')
            if not ok then error(entityId) end
            return enhancementCommon.GetEnhancements(entityId) or {}
        end
        local function GetEnhancementQueue(unit)
            enhancementQueue = LoadImport(enhancementQueue, 'enhancement_queue', '/lua/ui/notify/enhancementqueue.lua')
            if not enhancementQueue or type(enhancementQueue.getEnhancementQueue) ~= 'function' then
                error('enhancementqueue.getEnhancementQueue unavailable')
            end
            local ok, entityId = Method(unit, 'GetEntityId')
            if not ok then error(entityId) end
            local allQueues = enhancementQueue.getEnhancementQueue()
            local queued = type(allQueues) == 'table' and allQueues[entityId] or nil
            local blueprint = Blueprint(unit)
            local result = {}
            for _, entry in ipairs(queued or {}) do
                if type(entry) ~= 'table' or type(entry.ID) ~= 'string' then
                    error('malformed enhancement queue entry')
                end
                local enhancementId = string.gsub(entry.ID, 'Remove$', '')
                local enhancement = blueprint and blueprint.Enhancements
                    and blueprint.Enhancements[enhancementId]
                local slot = entry.Slot or (enhancement and enhancement.Slot)
                if type(slot) ~= 'string' or slot == '' then
                    error('enhancement slot unavailable for queued enhancement ' .. entry.ID)
                end
                table.insert(result, { ID = entry.ID, Slot = slot })
            end
            return result
        end

        local models = {}
        models.choices = loaded.choices.Create({
            hasCategory = HasCategory,
            isAllowed = function(id) return IsBuildable(id) end,
            upgradeNext = function(id)
                local blueprint = blueprints[id]
                return blueprint and blueprint.General and blueprint.General.UpgradesTo
            end,
        })
        models.gridModel = loaded.gridModel.Create({
            hasCategory = HasCategory,
            getBlueprint = function(id) return blueprints[id] end,
            isRestricted = Restriction,
        })
        models.selectionModel = loaded.selectionModel.Create({
            getBlueprintId = actions.getUnitBlueprintId,
            hasCategory = HasCategory,
            getFuelRatio = function(unit)
                local ok, value = Method(unit, 'GetFuelRatio')
                if not ok then error(value) end
                return value
            end,
            isIdle = function(unit)
                local ok, value = Method(unit, 'IsIdle')
                if not ok then error(value) end
                return value
            end,
        })
        models.queueModel = loaded.queueModel.Create()
        models.templatesModel = loaded.templatesModel.Create({
            hasCategory = HasCategory,
            isBuildable = IsBuildable,
            isRestricted = Restriction,
            -- Exact factory future-tech eligibility needs predecessor-aware proof.
        })
        models.enhancementsModel = loaded.enhancementsModel.Create({
            getBlueprint = Blueprint,
            getBlueprintId = actions.getUnitBlueprintId,
            getInstalled = GetInstalled,
            getQueue = GetEnhancementQueue,
            isRestricted = Restriction,
        })

        local refreshCargo = options.onCargoChanged or engine.onCargoChanged
        if type(refreshCargo) ~= 'function' then
            AddMissing('caller-provided onCargoChanged is required to redraw cargo state')
            refreshCargo = function() end
        end
        models.cargoState = loaded.cargoState.Create({
            add = function(unit) return Global('AddToSessionExtraSelectList', unit) end,
            remove = function(unit) return Global('RemoveFromSessionExtraSelectList', unit) end,
            isQueued = function(unit)
                local ok, queued = Method(unit, 'HasUnloadCommandQueuedUp')
                if not ok then error(queued) end
                return queued == true
            end,
            refresh = refreshCargo,
        })

        models.getTemplates = function()
            return GetMobileTemplates(), GetFactoryTemplates()
        end
        models.getQueue = function()
            local selection = Global('GetSelectedUnits') or {}
            if table.getn(selection) ~= 1 then return {} end
            local unit = selection[1]
            if not (HasCategory(unit, 'FACTORY') or HasCategory(unit, 'EXTERNALFACTORY')) then return {} end
            if HasCategory(unit, 'EXTERNALFACTORY') then
                local ok, creator = Method(unit, 'GetCreator')
                if not ok then error(creator) end
                unit = creator
            end
            local raw = Global('SetCurrentFactoryForQueueDisplay', unit)
            local result = {}
            for _, item in ipairs(raw or {}) do
                if type(item) ~= 'table' or type(item.id) ~= 'string'
                    or type(item.count) ~= 'number' then error('malformed factory queue item') end
                table.insert(result, { type = 'queuestack', id = item.id,
                    count = item.count, displayCount = item.count })
            end
            return result
        end
        models.getCurrentQueue = models.getQueue
        actions.getCurrentQueue = models.getQueue
        models.capabilityErrors = errors
        models.missing = missing
        AddMissing('combined factory/enhancement queue order and progress projection is unsupported')
        AddMissing('factory template canBuildAfter proof for future tech is unsupported')
        AddMissing('shared SessionExtraSelectList ownership outside this adapter is unobservable')
        return models
    end

    return {
        actions = actions,
        getBuildables = GetBuildables,
        getCargo = GetCargo,
        getQueue = function(models) return models and models.getQueue and models.getQueue() or {} end,
        CreateModels = CreateModels,
        getSelection = actions.getCurrentSelection,
        army = function() return Global('GetFocusArmy') end,
        getBlueprintId = actions.getUnitBlueprintId,
        hasCategory = HasCategory,
        getBlueprint = actions.getBlueprint,
        isRestricted = actions.isRestricted,
        startCommandMode = actions.startCommandMode,
        issueBlueprintCommand = actions.issueBlueprintCommand,
        issueBlueprintCommandToUnits = actions.issueBlueprintCommandToUnits,
        -- These need owners/state supplied by the integrating hook layer.
        missing = {
            'getQueue/getCurrentQueue: must project the active factory and enhancement queue together',
            'getCurrentTechTab/setHotKeys: state belongs to Construction.lua/ReUI panel',
            'validateQueueReset/resetQueues: no validated stock queue-reset contract supplied',
            'selection/queue/command lifecycle subscriptions and hook ownership',
            'template source and enhancement queue/install state',
            'ownership and lifecycle of the shared SessionExtraSelectList remains unverified',
        },
    }
end
