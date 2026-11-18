local function T(key, first, second, third)
    local core = ReUI and ReUI.ClaretCore
    local localization=core and core.Localization
    if localization and type(localization.Text)=='function' then return localization.Text(key, first, second, third) end
    return key
end

-- Cross validation between Hotbuild presets and their assigned context binding.
local forbiddenContexts = { acu = true, sacu = true, engineer = true }
local ContextActions = import('/mods/ClaretHotbuild/modules/ContextActions.lua')
local function ProducedByFactory(record)
    local bp = record and record.blueprint
    if type(bp) ~= 'table' then return false end
    local function IsFactoryCategory(category)
        return type(category) == 'string' and string.find(category, '^BUILTBY.*FACTORY') ~= nil
    end
    local hash = rawget(bp, 'CategoriesHash')
    if type(hash) == 'table' then
        for category, present in pairs(hash) do
            if present and IsFactoryCategory(category) then return true end
        end
    end
    local list = rawget(bp, 'Categories')
    if type(list) == 'table' then
        for _, category in ipairs(list) do
            if IsFactoryCategory(category) then return true end
        end
    end
    return false
end

local function Message(key, fallback, first, second, third)
    local text = fallback
    if type(LOC) == 'function' then text = LOC('<LOC ' .. key .. '>' .. fallback) end
    return string.format(text, first, second, third)
end

local function PresetTraits(binding, catalog)
    local hasFactoryOutput, hasBuild = false, false
    local function CheckOutput(id)
        local record = catalog:Get(id)
        if not record then return end
        if ProducedByFactory(record) then hasFactoryOutput = true end
        -- Saved templates carry the member blueprint IDs in their geometry data.
        for i = 3, table.getn(record.templateData or {}) do
            local item = record.templateData[i]
            if type(item) == 'table' and type(item[1]) == 'string' then
                local member = catalog:Get(item[1])
                if member and ProducedByFactory(member) then hasFactoryOutput = true end
            end
        end
    end
    for _, entry in ipairs(binding.entries or {}) do
        if entry.kind == 'blueprint' then
            local record = catalog:Get(entry.id)
            local bp = record and record.blueprint
            local hash = bp and rawget(bp,'CategoriesHash')
            local structure = record and (record.kind=='STRUCTURE' or record.templateData or (hash and hash.STRUCTURE))
            for _, category in ipairs(bp and rawget(bp,'Categories') or {}) do
                if category=='STRUCTURE' then structure=true end
            end
            -- Unknown saved blueprints are treated conservatively until the catalog resolves them.
            if not record or structure then hasBuild = true end
            CheckOutput(entry.id)
        end
    end
    return hasFactoryOutput, hasBuild
end

local function ContextRows(contextBinding)
    local rows = {}
    if contextBinding then for _, row in ipairs(contextBinding.rows or {}) do rows[row.context] = row end end
    return rows
end

local function HasEffectiveAction(contextBinding, context)
    if not contextBinding then return false end
    local parent=false
    for _, row in ipairs(contextBinding.rows or {}) do
        if row.context=='builder' and row.action then parent=true; break end
    end
    for _, row in ipairs(contextBinding.rows or {}) do
        if row.context==context then
            if row.mode=='disabled' then return false end
            if row.mode=='own' or row.mode==nil then return row.action~=nil end
            return parent
        end
    end
    return parent
end

local function HasParentAction(contextBinding)
    for _,row in ipairs(contextBinding and contextBinding.rows or {}) do
        if row.context=='builder' and row.action then return true end
    end
    return false
end

local function ContextLabel(id)
    for _, context in ipairs(ContextActions.Contexts()) do
        if context.id == id then return context.label end
    end
    return id
end

local function BuilderConflicts(contextBinding)
    local contexts, labels, ownContexts = {}, {}, {}
    for _, context in ipairs({'acu', 'sacu', 'engineer'}) do
        if HasEffectiveAction(contextBinding, context) then
            table.insert(contexts, context)
            table.insert(labels, ContextLabel(context))
        end
        for _, row in ipairs(contextBinding and contextBinding.rows or {}) do
            if row.context == context and row.mode ~= 'disabled'
                and (row.mode == 'own' or row.mode == nil) and row.action then
                table.insert(ownContexts, context)
                break
            end
        end
    end
    return contexts, labels, HasParentAction(contextBinding), ownContexts
end

local function JoinLabels(labels)
    local count = table.getn(labels)
    if count < 2 then return labels[1] or '' end
    if count == 2 then return labels[1] .. T('hotbuild.compatibility.s001') .. labels[2] end
    local prefix = {}
    for i = 1, count - 1 do table.insert(prefix, labels[i]) end
    return table.concat(prefix, ', ') .. T('hotbuild.compatibility.s002') .. labels[count]
end

local function BuilderConflictMessage(binding, labels, parent, ownLabels)
    if parent then
        if table.getn(ownLabels) > 0 then
            local own = JoinLabels(ownLabels)
            if own == T('hotbuild.compatibility.s003') then own = T('hotbuild.compatibility.s004')
            elseif own == T('hotbuild.compatibility.s005') then own = T('hotbuild.compatibility.s006')
            elseif own == T('hotbuild.compatibility.s007') then own = T('hotbuild.compatibility.s008')
            elseif own == T('hotbuild.compatibility.s009') then own = T('hotbuild.compatibility.s010') end
            local tileWord = table.getn(ownLabels) == 1 and T('hotbuild.compatibility.s011') or T('hotbuild.compatibility.s012')
            return Message('claret_hotbuild_compat_build_parent_child',
                T('hotbuild.compatibility.s013'),
                binding.name, own, tileWord .. own)
        end
        return Message('claret_hotbuild_compat_build_parent',
            T('hotbuild.compatibility.s014'),
            binding.name)
    end
    local label = JoinLabels(labels)
    local phrase = label
    if label == T('hotbuild.compatibility.s015') then phrase = T('hotbuild.compatibility.s016')
    elseif label == T('hotbuild.compatibility.s017') then phrase = T('hotbuild.compatibility.s018')
    elseif label == T('hotbuild.compatibility.s019') then phrase = T('hotbuild.compatibility.s020')
    elseif label == T('hotbuild.compatibility.s021') then phrase = T('hotbuild.compatibility.s022') end
    local clearPhrase
    if table.getn(labels) == 1 then clearPhrase = T('hotbuild.compatibility.s023') .. phrase
    else clearPhrase = T('hotbuild.compatibility.s024') .. phrase end
    return Message('claret_hotbuild_compat_build_context',
        T('hotbuild.compatibility.s025'),
        binding.name, phrase, clearPhrase)
end

local function ValidateBindingImpl(binding, contextModel, catalog)
    local contextId = binding and binding.grid and binding.grid.context
    if not contextId then return true end
    local contextBinding = contextModel:Get(contextId)
    if not contextBinding then
        return false, Message('claret_hotbuild_compat_missing_context',
            T('hotbuild.compatibility.s026'),
            binding.name, tostring(contextId))
    end
    if contextBinding.absolute then
        return false, Message('claret_hotbuild_compat_absolute_context',
            T('hotbuild.compatibility.s027'),
            binding.name, contextBinding.name), {kind='absolute_link', bindings={{name=binding.name,key=binding.key,id=binding.id}}}
    end
    local hasFactoryOutput, hasBuild = PresetTraits(binding, catalog)
    local rows = ContextRows(contextBinding)
    local key = binding.key ~= '' and binding.key or Message('claret_hotbuild_compat_unassigned', T('hotbuild.compatibility.s028'))
    if hasBuild then
        local contexts, labels, parent, ownContexts = BuilderConflicts(contextBinding)
        if parent or table.getn(contexts) > 0 then
            local ownLabels = {}
            for _, context in ipairs(ownContexts) do table.insert(ownLabels, ContextLabel(context)) end
            return false, BuilderConflictMessage(binding, labels, parent, ownLabels),
                {kind='build_context', contexts=contexts, tiles=labels, parent=parent,
                    ownContexts=ownContexts}
        end
    end
    if rows.factory and hasFactoryOutput then
        return false, Message('claret_hotbuild_compat_factory',
            T('hotbuild.compatibility.s029'),
            binding.name, key, ContextLabel('factory')), {kind='factory', contexts={'factory'}, tiles={ContextLabel('factory')}}
    end
    if hasBuild and rows.other then
        for _, row in ipairs(contextBinding.rows) do
            if row.context == 'other' then
                return true, Message('claret_hotbuild_compat_mobile_warning',
                    T('hotbuild.compatibility.s030'),
                    binding.name, key, ContextLabel(row.context))
            end
        end
    end
    return true
end

local function ValidateContextImpl(contextBinding, hotbuilds, catalog)
    if not contextBinding then return true end
    if contextBinding.absolute then
        local linked = {}
        for _, binding in ipairs(hotbuilds or {}) do
            if binding.grid and binding.grid.context == contextBinding.id then
                table.insert(linked, {name=binding.name, key=binding.key, id=binding.id})
            end
        end
        if table.getn(linked) > 0 then
            local names = {}
            for _, item in ipairs(linked) do
                table.insert(names, '«' .. item.name .. '» (' .. (item.key ~= '' and item.key or T('hotbuild.compatibility.s031')) .. ')')
            end
            return false, T('hotbuild.compatibility.s032') .. table.concat(names, ', ') .. T('hotbuild.compatibility.s033'),
                {kind='absolute_link', bindings=linked}
        end
    end
    local warning
    for _, binding in ipairs(hotbuilds or {}) do
        if binding.grid and binding.grid.context == contextBinding.id then
            local ok, message, details = ValidateBindingImpl(binding, {Get=function(_, id) if id == contextBinding.id then return contextBinding end end}, catalog)
            if not ok then return false, message, details end
            if message then warning = warning or message end
        end
    end
    return true, warning
end

local function TileWarning(contextId, contextBindingId, hotbuilds, catalog, contextBinding)
    if contextId ~= 'builder' and contextId ~= 'acu' and contextId ~= 'sacu' and contextId ~= 'engineer' and contextId ~= 'factory' then return nil end
    for _, binding in ipairs(hotbuilds or {}) do
        if binding.grid and binding.grid.context == contextBindingId then
            local hasFactoryOutput, hasBuild = PresetTraits(binding, catalog)
            local key = binding.key ~= '' and binding.key or Message('claret_hotbuild_compat_unassigned', T('hotbuild.compatibility.s034'))
            if contextId == 'factory' and hasFactoryOutput then
                return Message('claret_hotbuild_compat_factory_tooltip',
                    T('hotbuild.compatibility.s035'),
                    binding.name, key, ContextLabel(contextId))
            elseif (contextId=='builder' or forbiddenContexts[contextId]) and hasBuild then
                return T('hotbuild.compatibility.s036')..binding.name..'» ('..key..')'
            end
        end
    end
    return nil
end

function ValidateBinding(binding, contextModel, catalog)
    return ValidateBindingImpl(binding, contextModel, catalog)
end

function ValidateContext(contextBinding, hotbuilds, catalog)
    return ValidateContextImpl(contextBinding, hotbuilds, catalog)
end

function GetTileWarning(contextId, contextBindingId, hotbuilds, catalog, contextBinding)
    return TileWarning(contextId, contextBindingId, hotbuilds, catalog, contextBinding)
end

return { ValidateBinding = ValidateBinding, ValidateContext = ValidateContext, GetTileWarning = GetTileWarning }
