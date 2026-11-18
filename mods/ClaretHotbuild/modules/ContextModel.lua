local function T(key, first, second, third)
    local core = ReUI and ReUI.ClaretCore
    local localization=core and core.Localization
    if localization and type(localization.Text)=='function' then return localization.Text(key, first, second, third) end
    return key
end

-- Persistent model for user-composed context action bindings.
-- Saved data is treated as untrusted profile data and never returned by reference.

local MAX_BINDINGS = 64
local MAX_ROWS = 64
local MAX_ID_LENGTH = 96
local childContexts = {acu='builder', sacu='builder', engineer='builder', land='units', air='units', navy='units', silo_tactical='missiles', silo_nuclear='missiles'}
local function Identifier(value)
    return type(value) == 'string' and string.len(value) > 0
        and string.len(value) <= MAX_ID_LENGTH
        and string.find(value, '^[%w_][%w_.%-]*$') ~= nil
end

local function IsList(value)
    if type(value) ~= 'table' then return false end
    local count, largest = 0, 0
    for key in pairs(value) do
        if type(key) ~= 'number' or key < 1 or key ~= math.floor(key) then return false end
        count = count + 1
        if key > largest then largest = key end
    end
    return count == largest
end

local function Copy(binding)
    local result = {id=binding.id, name=binding.name, absolute=binding.absolute == true, rows={}}
    for i, row in ipairs(binding.rows) do
        result.rows[i] = {context=row.context, action=row.action, mode=row.mode, quickRepeat=row.quickRepeat, fallback=row.fallback}
    end
    return result
end

local function SameRow(left, right)
    if type(left) ~= 'table' or type(right) ~= 'table' then return false end
    return left.context == right.context and left.action == right.action
        and left.mode == right.mode and left.quickRepeat == right.quickRepeat
        and left.fallback == right.fallback
end

local function Fields(value, allowed)
    for key in pairs(value) do if not allowed[key] then return false end end
    return true
end
local function Validate(binding, actions, loading, previous)
    if type(binding) ~= 'table' or not Identifier(binding.id) then return nil, T('hotbuild.context_model.s001') end
    if not Fields(binding, {id=true,name=true,absolute=true,rows=true}) then return nil, T('hotbuild.context_model.s002') end
    if type(binding.name) ~= 'string' then return nil, T('hotbuild.context_model.s003') end
    if binding.absolute ~= nil and type(binding.absolute) ~= 'boolean' then return nil, T('hotbuild.context_model.s004') end
    local name = string.gsub(string.gsub(binding.name, '^%s+', ''), '%s+$', '')
    if name == '' or string.len(name) > 128 then return nil, T('hotbuild.context_model.s005') end
    if not IsList(binding.rows) then return nil, T('hotbuild.context_model.s006') end
    if table.getn(binding.rows) > MAX_ROWS then
        return nil, T('hotbuild.context_model.s007')
    end

    local rows, seen = {}, {}
    for i, row in ipairs(binding.rows) do
        if type(row) ~= 'table' or not Identifier(row.context) then
            return nil, T('hotbuild.context_model.s008') .. tostring(i)
        end
        if not Fields(row, {context=true,action=true,mode=true,quickRepeat=true,fallback=true}) then return nil, T('hotbuild.context_model.s009') end
        if (row.quickRepeat ~= nil and not Identifier(row.quickRepeat)) or (row.fallback ~= nil and not Identifier(row.fallback)) then return nil, T('hotbuild.context_model.s010') end
        if seen[row.context] then return nil, T('hotbuild.context_model.s011') .. row.context end
        local preserveInvalid = false
        if not loading and previous then
            for _, oldRow in ipairs(previous.rows) do
                if oldRow.context == row.context and (SameRow(oldRow, row)
                    or (oldRow.action==row.action and oldRow.quickRepeat==row.quickRepeat and oldRow.fallback==row.fallback)) then
                    preserveInvalid = true; break
                end
            end
        end
        local preservedFallback=false
        if previous and row.fallback then
            for _,oldRow in ipairs(previous.rows) do
                if oldRow.context==row.context and oldRow.fallback==row.fallback then preservedFallback=true; break end
            end
        end
        if row.fallback and not loading and not preserveInvalid and not preservedFallback then
            if not actions.IsSelection(row.action) then return nil, T('hotbuild.context_model.s012') end
            if not actions.Supports(row.fallback,row.context) then return nil, T('hotbuild.context_model.s013') .. row.context end
        end
        if not actions.Contexts[row.context] and not loading and not preserveInvalid then return nil, T('hotbuild.context_model.s014') .. row.context end
        if childContexts[row.context] or (not actions.Contexts[row.context] and row.mode ~= nil) then
            local mode = row.mode or 'own'
            if mode ~= 'own' and mode ~= 'inherit' and mode ~= 'disabled' then return nil, T('hotbuild.context_model.s015') end
            if mode == 'own' or row.action ~= nil then
                if not Identifier(row.action) then return nil, T('hotbuild.context_model.s016') end
                local action = actions.Get(row.action)
                if not loading and (not action or not actions.Supports(row.action, row.context)) and not preserveInvalid then
                    if row.context=='builder' then
                        return nil, T('hotbuild.context_model.s017') .. tostring(row.action) .. T('hotbuild.context_model.s018') .. row.context
                    end
                    return nil, T('hotbuild.context_model.s019') .. row.context
                end
                if row.quickRepeat and not loading and not actions.Supports(row.quickRepeat, row.context) and not preserveInvalid then
                    return nil, T('hotbuild.context_model.s020') .. row.context
                end
                local savedMode=row.mode
                if not loading then savedMode=mode end
            rows[i] = preserveInvalid and {context=row.context, mode=row.mode, action=row.action, quickRepeat=row.quickRepeat, fallback=row.fallback}
                or {context=row.context, mode=savedMode, action=row.action, quickRepeat=row.quickRepeat, fallback=row.fallback}
            else
                if row.quickRepeat ~= nil or row.fallback ~= nil then return nil, T('hotbuild.context_model.s021') end
                rows[i] = {context=row.context, mode=mode}
            end
        else
            if not Identifier(row.action) then return nil, T('hotbuild.context_model.s022') .. tostring(i) end
        local action = actions.Get(row.action)
        if not loading and not action and not preserveInvalid then return nil, T('hotbuild.context_model.s023') .. row.action end
        if not loading and not actions.Supports(row.action, row.context) and not preserveInvalid then
            return nil, T('hotbuild.context_model.s024') .. row.action .. T('hotbuild.context_model.s025') .. row.context
        end
            if row.quickRepeat and not loading and not actions.Supports(row.quickRepeat, row.context) and not preserveInvalid then
                return nil, T('hotbuild.context_model.s026') .. row.context
            end
            if row.mode ~= nil then return nil, T('hotbuild.context_model.s027') end
            rows[i] = {context=row.context, action=row.action, quickRepeat=row.quickRepeat, fallback=row.fallback}
        end
        seen[row.context] = true
    end
    return {id=binding.id, name=loading and binding.name or name, absolute=binding.absolute == true, rows=rows}
end

local function BuildActions(actions)
    if type(actions) ~= 'table' or type(actions.Get) ~= 'function'
        or type(actions.Supports) ~= 'function' or type(actions.Contexts) ~= 'function'
        or type(actions.List) ~= 'function' then
        return nil, T('hotbuild.context_model.s028')
    end
    local contexts, definitions = {}, {}
    for _, item in ipairs(actions.Contexts()) do
        if type(item) == 'table' and Identifier(item.id) then contexts[item.id] = true end
    end
    for _, item in ipairs(actions.List()) do
        if type(item) == 'table' and Identifier(item.id) then definitions[item.id] = true end
    end
    return {Contexts=contexts, IsSelection=function(id) return actions.IsSelection and actions.IsSelection(id) or false end, Get=function(id) if definitions[id] then return actions.Get(id) end end,
        Supports=function(id, context) return definitions[id] and actions.Supports(id, context) or false end}
end

function Create(saved, actions)
    local actionCatalog, catalogError = BuildActions(actions)
    local bindings, byId, warnings, diagnostics = {}, {}, {}, {}
    local readable = true
    local model = {}

    local function LoadWarning(message)
        readable = false
        table.insert(warnings, message)
    end

    function model:List()
        local result = {}
        for i, binding in ipairs(bindings) do result[i] = Copy(binding) end
        return result
    end

    function model:Get(id)
        if not byId[id] then return nil end
        return Copy(byId[id])
    end

    function model:ResolveAction(bindingOrId, childContext)
        local binding = type(bindingOrId)=='table' and bindingOrId or byId[bindingOrId]
        if not binding or not childContexts[childContext] then return nil end
        local child, parent
        for _, row in ipairs(binding.rows) do
            if row.context == childContext then child=row
            elseif row.context == childContexts[childContext] then parent=row end
        end
        if child then
            local mode=child.mode or 'own'
            if mode=='disabled' then return nil end
            if mode=='own' then return child.action end
        end
        return parent and parent.action or nil
    end

    function model:ResolveRow(bindingOrId, childContext)
        local binding = type(bindingOrId)=='table' and bindingOrId or byId[bindingOrId]
        if not binding then return nil end
        local row
        if childContexts[childContext] then
            local parent
            for _, candidate in ipairs(binding.rows) do
                if candidate.context==childContext then row=candidate
                elseif candidate.context==childContexts[childContext] then parent=candidate end
            end
            if row and row.mode=='disabled' then return nil end
            if row and (row.mode or 'own')=='own' then return {context=childContext,action=row.action,quickRepeat=row.quickRepeat,fallback=row.fallback} end
            row=parent
        else
            for _, candidate in ipairs(binding.rows) do if candidate.context==childContext then row=candidate; break end end
        end
        if not row then return nil end
        return {context=childContext,action=row.action,quickRepeat=row.quickRepeat,fallback=row.fallback}
    end

    function model:EffectiveStats(bindingOrId)
        local binding = type(bindingOrId)=='table' and bindingOrId or byId[bindingOrId]
        local result={effective=0, overrides=0}
        if not binding then return result end
        for context in pairs(childContexts) do
            local action=self:ResolveAction(binding,context)
            if action then result.effective=result.effective+1 end
            for _, row in ipairs(binding.rows) do
                if row.context==context and (row.mode=='own' or row.mode=='disabled' or row.mode==nil) then
                    result.overrides=result.overrides+1
                end
            end
        end
        return result
    end

    function model:CanSave()
        return readable and actionCatalog ~= nil
    end

    function model:Put(binding)
        if not actionCatalog then return nil, catalogError end
        local valid, err = Validate(binding, actionCatalog, false, byId[binding.id])
        if not valid then return nil, err end
        if not byId[valid.id] and table.getn(bindings) >= MAX_BINDINGS then
            return nil, T('hotbuild.context_model.s029')
        end
        if byId[valid.id] then
            for i, old in ipairs(bindings) do
                if old.id == valid.id then bindings[i] = valid; break end
            end
        else
            table.insert(bindings, valid)
        end
        byId[valid.id] = valid
        return true
    end

    function model:Delete(id)
        if not byId[id] then return false end
        for i, binding in ipairs(bindings) do
            if binding.id == id then table.remove(bindings, i); break end
        end
        byId[id] = nil
        return true
    end

    function model:Export()
        if not self:CanSave() then return nil, T('hotbuild.context_model.s030') end
        return {version=3, bindings=self:List()}
    end

    function model:GetLoadWarnings()
        local result = {}
        for i, warning in ipairs(warnings) do result[i] = warning end
        return result
    end

    function model:GetDiagnostics()
        local result={}
        for i, message in ipairs(diagnostics) do result[i]=message end
        return result
    end

    if not actionCatalog then
        LoadWarning(catalogError)
    elseif saved ~= nil then
        if type(saved) ~= 'table' or not Fields(saved, {version=true,bindings=true}) or (saved.version ~= 1 and saved.version ~= 2 and saved.version ~= 3) or not IsList(saved.bindings) then
            LoadWarning('Saved context binding profile has an unknown or corrupted format')
        else
            local seen = {}
            if table.getn(saved.bindings) > MAX_BINDINGS then
                LoadWarning('Profile contains more than 64 bindings; data integrity is not confirmed')
            end
            for i, binding in ipairs(saved.bindings) do
                local err
                if i > MAX_BINDINGS then
                    err = T('hotbuild.context_model.s031')
                elseif type(binding) == 'table' and seen[binding.id] then
                    err = T('hotbuild.context_model.s032')
                else
                    local valid
                    local source=binding
                    if saved.version==1 and type(binding)=='table' and IsList(binding.rows) then
                        source={id=binding.id,name=binding.name,absolute=binding.absolute,rows={}}
                        if not Fields(binding, {id=true,name=true,absolute=true,rows=true}) then source=binding end
                        for _, row in ipairs(binding.rows) do
                            if source==binding then break end
                            if type(row)=='table' and Fields(row,{context=true,action=true,mode=true,quickRepeat=true,fallback=true}) then
                                local migrated={context=row.context,action=row.action,mode=row.mode,quickRepeat=row.quickRepeat,fallback=row.fallback}
                                if childContexts[row.context] and row.action then migrated.mode='own' end
                                table.insert(source.rows,migrated)
                            else
                                table.insert(source.rows,row)
                            end
                        end
                    end
                    valid, err = Validate(source, actionCatalog, true)
                    if valid then
                        -- Move unambiguous cursor actions; retain original rows when they
                        -- carry auxiliary fields or multiple actions need manual repair.
                        local cursorRow, candidate, candidateRow, candidateCount, ambiguous = nil, nil, nil, 0, false
                        for _, row in ipairs(valid.rows) do
                            if row.context=='cursor' then cursorRow=row end
                            if row.mode~='disabled' and row.mode~='inherit' and (row.action=='upgrade_structure_under_cursor' or row.action=='upgrade_structure_pause' or row.action=='upgrade_mex_select_next' or row.action=='upgrade_structure') then
                                local cursorAction=row.action=='upgrade_structure' and 'upgrade_structure_under_cursor' or row.action
                                candidateCount=candidateCount+1; candidateRow=row
                                if candidate and candidate~=cursorAction then ambiguous=true else candidate=cursorAction end
                            end
                        end
                        if not valid.absolute and not cursorRow and candidate and not ambiguous and table.getn(valid.rows)<MAX_ROWS then
                            if candidateCount==1 and not candidateRow.quickRepeat and not candidateRow.fallback
                                and (not candidateRow.mode or candidateRow.mode=='own') then
                                candidateRow.context='cursor'; candidateRow.action=candidate; candidateRow.mode=nil
                            else
                                table.insert(valid.rows,{context='cursor',action=candidate})
                            end
                        elseif not valid.absolute and not cursorRow and ambiguous then
                            table.insert(diagnostics,T('hotbuild.context_model.s033')..valid.id..T('hotbuild.context_model.s034'))
                        end
                        table.insert(bindings, valid)
                        byId[valid.id] = valid
                        seen[valid.id] = true
                        for _, row in ipairs(valid.rows) do
                            if not actionCatalog.Contexts[row.context] or (row.action and (not actions.Get(row.action) or not actions.Supports(row.action,row.context))) then
                                table.insert(diagnostics, T('hotbuild.context_model.s035')..valid.id..T('hotbuild.context_model.s036')..tostring(row.action)..' ('..row.context..')')
                            end
                        end
                    end
                end
                if err then LoadWarning('Binding ' .. tostring(i) .. ' was not loaded: ' .. tostring(err)) end
            end
        end
    end
    return model
end

