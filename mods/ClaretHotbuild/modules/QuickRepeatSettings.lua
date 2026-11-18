-- Immediate-save setting for the global quick-repeat time window.
function Create(parent, layout, option)
    if type(parent) ~= 'userdata' and type(parent) ~= 'table' then return nil end
    if type(layout) ~= 'table' or type(layout.scale) ~= 'number' or not option then return nil end

    local Theme = import('/mods/ClaretCore/modules/Theme.lua')
    local Localization = ReUI.ClaretCore and ReUI.ClaretCore.Localization or {
        Text = function(key, first, second, third)
            if third~=nil then return string.format(key,first,second,third) end
            if second~=nil then return string.format(key,first,second) end
            if first~=nil then return string.format(key,first) end
            return key
        end,
        Subscribe = function() end,
        Unsubscribe = function() end,
    }
    local function T(key, first, second, third) return Localization.Text(key, first, second, third) end
    local C = Theme.Colors
    local Group = import('/lua/maui/group.lua').Group
    local Bitmap = import('/lua/maui/bitmap.lua').Bitmap
    local Edit = import('/lua/maui/edit.lua').Edit
    local UI = import('/lua/ui/uiutil.lua')
    local Helpers = import('/lua/maui/layouthelpers.lua')
    local scale = layout.scale
    local pixel = Helpers.GetPixelScaleFactor()
    local ratio = scale / pixel
    local L = ReUI.UI.FloorLayouter(scale)
    local root = Group(parent)
    root:DisableHitTest()
    local height = layout.height or 920

    local function Text(owner, value, x, y, size, color)
        if type(value)=='string' and string.sub(value,1,9)=='hotbuild.' then value=T(value) end
        local control = UI.CreateText(owner, value or '', size * ratio, Theme.Fonts.body)
        control:SetColor(color or C.text)
        control:DisableHitTest()
        L(control):AtLeftTopIn(owner, x, y)
        return control
    end

    local function FinitePositive(value)
        return type(value) == 'number' and value == value and value > 0
            and value - value == 0
    end

    local function Format(value)
        return string.format('%.7g', value)
    end

    local valueLabel, description, unit, status
    local statusKey, statusArgs, statusError
    local function SetStatus(key, isError, arg1, arg2, arg3)
        statusKey, statusError, statusArgs = key, isError, {arg1, arg2, arg3}
        status:SetColor(isError and C.warning or C.success)
        local message = T(key, statusArgs[1], statusArgs[2], statusArgs[3])
        local shown = message
        while status:GetStringAdvance(shown) > ((layout.width or 1080) - 48) * ratio and string.len(shown) > 0 do
            local finish = string.len(shown)
            while finish > 1 and string.byte(shown, finish) >= 128 and string.byte(shown, finish) < 192 do finish = finish - 1 end
            shown = string.sub(shown, 1, finish - 1)
        end
        if shown ~= message then
            while status:GetStringAdvance(shown .. '…') > ((layout.width or 1080) - 48) * ratio and string.len(shown) > 0 do
                local finish = string.len(shown)
                while finish > 1 and string.byte(shown, finish) >= 128 and string.byte(shown, finish) < 192 do finish = finish - 1 end
                shown = string.sub(shown, 1, finish - 1)
            end
            shown = shown .. '…'
        end
        status:SetText(shown)
    end

    local ok, err = pcall(function()
        L(root):AtLeftTopIn(parent, 0, 0):Width(layout.width or 1080):Height(height)
        valueLabel = Text(root, T('hotbuild.repeat.title'), 24, 8, 18, C.text)
        description = Text(root, T('hotbuild.repeat.description'), 24, 36, 14, C.muted)
        local field = Edit(root)
        L(field):AtLeftTopIn(root, 24, 68):Width(80):Height(Theme.Metrics.fieldHeight)
        UI.SetupEditStd(field, C.text, nil, C.text, C.surface, Theme.Fonts.body, Theme.Metrics.text * ratio, 24)
        unit = Text(root, T('hotbuild.repeat.unit'), 116, 76, 16, C.muted)
        status = Text(root, '', 24, 112, 14, C.muted)
        local updating = false
        local function ShowValue()
            updating = true
            field:SetText(Format(option:Get()))
            updating = false
        end
        local function Commit(restoreInvalid)
            local input = field:GetText()
            local value = tonumber(input)
            if not FinitePositive(value) then
                SetStatus('hotbuild.repeat.invalid', true)
                if restoreInvalid then ShowValue() end
                return
            end
            local previous = option:Get()
            if value == previous or input == Format(previous) then return end
            local saved, saveError = pcall(function()
                option:Set(value)
                option:Save()
                SavePreferences()
            end)
            if not saved then
                pcall(function() option:Set(previous); option:Save(); SavePreferences() end)
                SetStatus('hotbuild.repeat.save_failed', true, tostring(saveError))
                ShowValue()
                return
            end
            SetStatus('hotbuild.repeat.saved', false, Format(value))
        end
        field.OnTextChanged = function() if not updating then Commit(false) end end
        field.OnEnterPressed = function() Commit(true); return true end
        field.OnLoseFocus = function() Commit(true); ShowValue() end
        ShowValue()
        valueLabel:SetColor(C.text)
        description:SetColor(C.muted)
    end)
    if not ok then root:Destroy(); error(err) end
    local oldDestroy = root.OnDestroy
    root.OnDestroy = function(self)
        Localization.Unsubscribe(root)
        oldDestroy(self)
    end
    Localization.Subscribe(root,function()
        valueLabel:SetText(T('hotbuild.repeat.title'))
        description:SetText(T('hotbuild.repeat.description'))
        unit:SetText(T('hotbuild.repeat.unit'))
        if statusKey then SetStatus(statusKey,statusError,statusArgs[1],statusArgs[2],statusArgs[3]) end
    end)
    root.OnLanguageChanged = function()
        valueLabel:SetText(T('hotbuild.repeat.title'))
        description:SetText(T('hotbuild.repeat.description'))
        unit:SetText(T('hotbuild.repeat.unit'))
        if statusKey then SetStatus(statusKey,statusError,statusArgs[1],statusArgs[2],statusArgs[3]) end
    end
    return root
end
