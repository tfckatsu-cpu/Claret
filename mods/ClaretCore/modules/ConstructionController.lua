-- Orchestrates isolated construction presentation models and injected view callbacks.
-- It owns no game hooks, global controls, engine commands, or external selections.

local function CopyArray(source)
    local result = {}
    if type(source) == 'table' then
        for index, value in ipairs(source) do result[index] = value end
    end
    return result
end

local function CopyQueue(source)
    local result = {}
    if type(source) == 'table' then
        for index, item in ipairs(source) do
            if type(item) == 'table' then
                result[index] = {
                    type = item.type, id = item.id, unitID = item.unitID,
                    count = item.count, displayCount = item.displayCount,
                    name = item.name, icon = item.icon, enhancement = item.enhancement,
                }
            else
                result[index] = item
            end
        end
    end
    return result
end

local function SameIdentitySet(first, second)
    if table.getn(first) ~= table.getn(second) then return false end
    local members = {}
    for _, value in ipairs(first) do
        if members[value] then return false end
        members[value] = true
    end
    for _, value in ipairs(second) do
        if not members[value] then return false end
        members[value] = nil
    end
    return next(members) == nil
end

local function ValidUnitList(units)
    local seen = {}
    for _, unit in ipairs(units) do
        local unitType = type(unit)
        if (unitType ~= 'table' and unitType ~= 'userdata') or seen[unit] then return false end
        seen[unit] = true
    end
    return true
end

local function ValidBlueprintList(ids)
    local seen = {}
    for _, id in ipairs(ids) do
        if type(id) ~= 'string' or id == '' or seen[id] then return false end
        seen[id] = true
    end
    return true
end

local function SameQueue(first, second)
    if first == second then return true end
    if type(first) ~= 'table' or type(second) ~= 'table'
        or table.getn(first) ~= table.getn(second) then return false end
    for index, item in ipairs(first) do
        local other = second[index]
        if type(item) ~= 'table' or type(other) ~= 'table'
            or item.type ~= other.type or item.id ~= other.id
            or item.unitID ~= other.unitID or item.count ~= other.count
            or item.displayCount ~= other.displayCount or item.name ~= other.name
            or item.icon ~= other.icon or item.enhancement ~= other.enhancement then
            return false
        end
    end
    return true
end

function Create(dependencies)
    dependencies = dependencies or {}
    local state = {
        selection = {}, buildables = {}, cargo = {}, queue = {}, templates = {},
        currentTab = 'construction', techTab = 't1', lastTab = 'construction', lastTechTab = 't1',
        destroyed = false, busy = false, hasValidSelection = false, dirty = false, teardownPending = false,
    }

    local function Report(message, detail)
        if type(dependencies.onError) == 'function' then
            pcall(dependencies.onError, message, detail)
        end
    end

    local function Render(which, mode, data, detail)
        local callback = which == 'primary' and dependencies.renderPrimary or dependencies.renderSecondary
        if type(callback) ~= 'function' then
            Report(which .. ' render callback is unavailable', mode)
            return false
        end
        local view = which == 'primary' and dependencies.primaryView or dependencies.secondaryView
        local ok, result = pcall(callback, view, mode, data, detail)
        if not ok or result == false then
            Report(which .. ' render callback failed', ok and mode or result)
            return false
        end
        return true
    end

    local function Clear(which, reason)
        return Render(which, 'clear', nil, reason)
    end

    local function CargoCall(method, ...)
        local cargo = dependencies.cargoState
        if type(cargo) ~= 'table' or type(cargo[method]) ~= 'function' then
            return false, 'cargo state method unavailable: ' .. method
        end
        return pcall(cargo[method], cargo, ...)
    end

    local function ModelResult(model, method, allowEntryDiagnostics, ...)
        if type(model) ~= 'table' or type(model[method]) ~= 'function' then
            return nil, 'model method unavailable: ' .. method
        end
        local ok, result = pcall(model[method], ...)
        if not ok then return nil, result end
        if type(result) ~= 'table' then
            return nil, 'model returned malformed result'
        end
        if result.errors == nil then result.errors = {} end
        if type(result.errors) ~= 'table' then return nil, 'model returned malformed errors' end
        if table.getn(result.errors) > 0 then
            if allowEntryDiagnostics and type(result.fatalErrors) == 'table'
                and table.getn(result.fatalErrors) == 0 then
                Report('presentation omitted invalid or restricted entries', result.errors)
                return result
            end
            return nil, result.fatalErrors or result.errors
        end
        return result
    end

    local function QueueIds()
        local result, seen = {}, {}
        for _, entry in ipairs(state.queue) do
            if type(entry) == 'table' and type(entry.id) == 'string' and not seen[entry.id] then
                seen[entry.id] = true
                table.insert(result, entry.id)
            end
        end
        return result
    end

    local function PrepareChoices()
        local result, err = ModelResult(dependencies.choices, 'Build', false,
            state.buildables, state.selection, QueueIds())
        if not result then Report('construction choices unavailable', err); return nil end
        state.choiceResult = result
        return result
    end

    local function RenderQueueSecondary()
        local result, err = ModelResult(dependencies.queueModel, 'Build', false, state.queue,
            { dragging = dependencies.dragging == true })
        if not result then
            Report('construction queue unavailable', err)
            Clear('secondary', 'queue model error')
            return false
        end
        state.queueResult = result
        return Render('secondary', 'queue', result.entries, { errors = result.errors })
    end

    local function RenderCargoSecondary()
        local cargoRows = {}
        for index, unit in ipairs(state.cargo) do
            local okSelected, selected = CargoCall('IsSelected', index)
            if not okSelected then
                Report('cargo selection query failed', selected)
                Clear('secondary', 'cargo state error')
                return false
            end
            table.insert(cargoRows, { unit = unit, index = index, selected = selected })
        end
        local okSelection, ownedSelection = CargoCall('GetSelection')
        if not okSelection then
            Report('cargo selection query failed', ownedSelection)
            Clear('secondary', 'cargo state error')
            return false
        end
        return Render('secondary', 'cargo', {
            units = CopyArray(state.cargo),
            rows = cargoRows,
            ownedSelection = ownedSelection,
            state = dependencies.cargoState,
        })
    end

    local function RenderConstruction()
        local choices = PrepareChoices()
        if not choices then Clear('primary', 'choice model error'); return false end
        if state.techTab == 'templates' then
            local mobileTemplates, factoryTemplates
            if type(dependencies.getTemplates) == 'function' then
                local ok, first, second = pcall(dependencies.getTemplates, state.selection)
                if not ok then Report('template source unavailable', first); Clear('primary', 'template source error'); return false end
                mobileTemplates, factoryTemplates = first, second
            else
                mobileTemplates, factoryTemplates = dependencies.mobileTemplates, dependencies.factoryTemplates
            end
            local templates, err = ModelResult(dependencies.templatesModel, 'Build', true,
                state.selection, mobileTemplates, factoryTemplates,
                { allowCrossFaction = dependencies.allowCrossFaction == true })
            if not templates then Report('construction templates unavailable', err); Clear('primary', 'template model error'); return false end
            state.templateResult = templates
            return Render('primary', 'templates', templates.entries,
                { kind = templates.kind, limitations = templates.limitations, errors = templates.errors })
        end

        local buildables = choices.tabs and choices.tabs[state.techTab]
        if type(buildables) ~= 'table' then
            Report('unknown construction tech tab', state.techTab)
            Clear('primary', 'invalid tech tab')
            return false
        end
        local grid, err = ModelResult(dependencies.gridModel, 'Build', true, buildables,
            { selectedUnit = state.selection[1], army = dependencies.army })
        if not grid then Report('construction grid unavailable', err); Clear('primary', 'grid model error'); return false end
        state.gridResult = grid
        return Render('primary', 'construction', grid.entries,
            { techTab = state.techTab, errors = grid.errors })
    end

    local function FindEnhancementSlot(result, slotId)
        for _, slot in ipairs(result and result.slots or {}) do
            if slot.id == slotId then return slot end
        end
    end

    local function RenderEnhancementSlot(result)
        local selectedSlot = FindEnhancementSlot(result, state.enhancementSlot)
        if not selectedSlot then
            for _, slot in ipairs(result.slots or {}) do
                if table.getn(slot.entries or {}) > 0 then selectedSlot = slot; break end
            end
            if not selectedSlot then selectedSlot = result.slots and result.slots[1] end
            state.enhancementSlot = selectedSlot and selectedSlot.id or nil
        end
        local slotMetadata = {}
        for _, slot in ipairs(result.slots or {}) do
            table.insert(slotMetadata, { id = slot.id, info = slot.info })
        end
        return Render('primary', 'enhancement', selectedSlot and selectedSlot.entries or {}, {
            slots = slotMetadata,
            selectedSlot = selectedSlot and selectedSlot.id or nil,
            unitID = result.unitID,
            errors = result.errors,
        })
    end

    local function RenderEnhancements()
        state.enhancementResult = nil
        local result, err = ModelResult(dependencies.enhancementsModel, 'Build', true, state.selection)
        if not result then
            Report('enhancement presentation unavailable', err)
            Clear('primary', 'enhancement model error')
            return false
        end
        state.enhancementResult = result
        return RenderEnhancementSlot(result)
    end

    local function Redraw()
        if state.destroyed then return false end
        if table.getn(state.selection) == 0 then
            local primaryOk = Clear('primary', 'empty selection')
            local secondaryOk = Clear('secondary', 'empty selection')
            return primaryOk and secondaryOk
        end
        if state.currentTab == 'construction' then
            local primaryOk = RenderConstruction()
            local secondaryOk = RenderQueueSecondary()
            return primaryOk and secondaryOk
        elseif state.currentTab == 'selection' then
            local summary, err = ModelResult(dependencies.selectionModel, 'Build', false, state.selection,
                { separateIdleBuilders = dependencies.separateIdleBuilders == true })
            if summary then
                state.selectionResult = summary
                local primaryOk = Render('primary', 'selection', summary.entries, { errors = summary.errors })
                local secondaryOk = RenderCargoSecondary()
                return primaryOk and secondaryOk
            else
                Report('construction selection summary unavailable', err)
                Clear('primary', 'selection model error')
                Clear('secondary', 'selection model error')
                return false
            end
        elseif state.currentTab == 'enhancement' then
            local primaryOk = RenderEnhancements()
            local secondaryOk = RenderQueueSecondary()
            return primaryOk and secondaryOk
        end
        return false
    end

    local function InvalidateSelection(reason)
        state.selection, state.buildables, state.cargo = {}, {}, {}
        state.hasValidSelection = false
        if dependencies.cargoState then
            local okReset, resetError, resetComplete = CargoCall('Reset')
            local okCargo, cargoError, cargoComplete = CargoCall('SetCargo', {})
            if not okReset or not okCargo or resetComplete == false or cargoComplete == false then
                Report('cargo invalidation cleanup failed', not okReset and resetError or cargoError)
            end
        end
        local primaryOk = Clear('primary', reason)
        local secondaryOk = Clear('secondary', reason)
        return primaryOk and secondaryOk
    end

    function state:OnSelection(buildables, selection, cargo)
        if self.destroyed or self.busy or self.teardownPending then return false end
        if type(selection) ~= 'table' or type(buildables) ~= 'table' or type(cargo) ~= 'table'
            or not ValidUnitList(selection) or not ValidUnitList(cargo) or not ValidBlueprintList(buildables) then
            Report('selection update contains invalid input')
            self.busy = true
            self.dirty = not InvalidateSelection('invalid selection input')
            self.busy = false
            return false
        end
        self.busy = true
        local nextSelection = CopyArray(selection)
        local nextCargo = CopyArray(cargo)
        local changedSelection = not SameIdentitySet(self.selection, nextSelection)
        if changedSelection then self.enhancementSlot = nil end
        if changedSelection and dependencies.cargoState then
            local okReset, resetError, resetComplete = CargoCall('Reset')
            if not okReset or resetComplete == false then
                Report('cargo cleanup failed on selection change', resetError)
                InvalidateSelection('cargo cleanup error')
                self.busy = false
                return false
            end
        end
        self.selection = nextSelection
        self.buildables = CopyArray(buildables)
        self.cargo = nextCargo
        self.hasValidSelection = true
        if dependencies.cargoState then
            local okCargo, cargoError, cargoComplete = CargoCall('SetCargo', nextCargo)
            if not okCargo or cargoComplete == false then
                Report('cargo refresh failed', cargoError)
                InvalidateSelection('cargo refresh error')
                self.busy = false
                return false
            end
        end
        local rendered = Redraw()
        self.dirty = not rendered
        self.busy = false
        return rendered
    end

    function state:OnQueueChanged(queue)
        if self.destroyed or self.busy or self.teardownPending or type(queue) ~= 'table' then return false end
        if SameQueue(self.queue, queue) then
            if not self.dirty or self.currentTab == 'selection' then return false end
        end
        self.busy = true
        self.queue = CopyQueue(queue)
        local rendered = true
        if self.currentTab ~= 'selection' then
            rendered = Redraw()
            self.dirty = not rendered
        end
        self.busy = false
        return rendered
    end

    function state:SetTab(tab)
        if self.destroyed or self.busy or self.teardownPending then return false end
        if tab == 'templates' then
            self.currentTab, self.techTab = 'construction', 'templates'
        elseif tab == 'construction' or tab == 'selection' or tab == 'enhancement' then
            self.currentTab = tab
            if tab == 'construction' and self.techTab == 'templates' then self.techTab = 't1' end
        else
            return false
        end
        if not self.dirty and state.lastTab == tab and state.lastTechTab == state.techTab then return false end
        self.busy = true
        local rendered = Redraw()
        if rendered then self.lastTab, self.lastTechTab = tab, self.techTab end
        self.dirty = not rendered
        self.busy = false
        return rendered
    end

    function state:SelectTech(tab)
        if self.destroyed or self.busy or self.teardownPending or self.currentTab ~= 'construction' then return false end
        if tab ~= 't1' and tab ~= 't2' and tab ~= 't3' and tab ~= 't4' and tab ~= 'templates' then return false end
        if not self.dirty and self.techTab == tab
            and self.lastTab == 'construction' and self.lastTechTab == tab then return false end
        self.techTab = tab
        self.busy = true
        local rendered = Redraw()
        if rendered then self.lastTab, self.lastTechTab = 'construction', tab end
        self.dirty = not rendered
        self.busy = false
        return rendered
    end

    function state:SelectEnhancementSlot(slotId)
        if self.destroyed or self.busy or self.teardownPending or self.currentTab ~= 'enhancement'
            or type(self.enhancementResult) ~= 'table' then return false end
        local slot = FindEnhancementSlot(self.enhancementResult, slotId)
        if not slot then return false end
        if self.enhancementSlot == slotId and not self.dirty then return false end
        self.enhancementSlot = slotId
        self.busy = true
        local rendered = RenderEnhancementSlot(self.enhancementResult)
        self.dirty = not rendered
        self.busy = false
        return rendered
    end

    function state:AppendCargo()
        if self.destroyed or self.busy or self.teardownPending or not self.hasValidSelection
            or table.getn(self.selection) == 0 or table.getn(self.cargo) == 0
            or not dependencies.cargoState then return false end
        self.busy = true
        local okAppend, changed = CargoCall('AppendNext')
        if not okAppend then
            Report('cargo append failed', changed)
            self.busy = false
            return false
        end
        local rendered = true
        if changed and self.currentTab == 'selection' then rendered = RenderCargoSecondary() end
        self.busy = false
        return changed == true and rendered
    end

    function state:Destroy()
        if self.destroyed or self.busy then return false end
        self.busy = true
        if dependencies.cargoState then
            local okDestroy, destroyError = CargoCall('Destroy')
            if not okDestroy or destroyError == false then
                Report('cargo cleanup failed during teardown', destroyError)
                self.teardownPending = true
                self.busy = false
                return false
            end
        end
        Clear('primary', 'controller destroyed')
        Clear('secondary', 'controller destroyed')
        self.destroyed = true
        self.teardownPending = false
        self.busy = false
        return true
    end

    return state
end
