function ShouldShowWelcome(dismissed)
    return dismissed ~= true
end

function GetMenuBindingText(keyBinding, localize)
    local localize = localize or function(key) return key end
    local key = keyBinding and keyBinding.Get and keyBinding:Get() or ''
    if type(key) ~= 'string' or key == '' then return localize('core.welcome.menu_unassigned') end
    return string.format(localize('core.welcome.menu_key'), key)
end

function ShouldShowFontBlock()
    return true
end

function ToggleWelcomeDismissal(option, savePreferences)
    if not option or not savePreferences then return false end
    local previous = option:Get()
    local saved = pcall(function()
        option:Set(not previous)
        option:Save()
        savePreferences()
    end)
    if saved then return true end
    pcall(function()
        option:Set(previous)
        option:Save()
        savePreferences()
    end)
    return false
end

function SetWelcomeLanguage(option, languageId, localization, savePreferences)
    if not option or not localization or not savePreferences then return false end
    if languageId ~= 'en' and languageId ~= 'ru' then return false end
    local previous = option:Get()
    local previousLanguage = localization.GetLanguage()
    if previous == 'en' or previous == 'ru' then previousLanguage = previous end
    local saved = pcall(function()
        option:Set(languageId)
        option:Save()
        savePreferences()
    end)
    if saved then
        localization.SetLanguage(languageId)
        return true
    end
    pcall(function()
        option:Set(previous)
        option:Save()
        savePreferences()
    end)
    localization.SetLanguage(previousLanguage)
    return false
end

function Create(parent, keyBinding, dismissedOption, languageOption)
    local Localization = import('/mods/ClaretCore/modules/Localization.lua').Localization
    local function T(key, first, second, third) return Localization.Text(key, first, second, third) end
    local Theme = import('/mods/ClaretCore/modules/Theme.lua')
    local Group = import('/lua/maui/group.lua').Group
    local Bitmap = import('/lua/maui/bitmap.lua').Bitmap
    local MultiLineText = import('/lua/maui/multilinetext.lua').MultiLineText
    local UI = import('/lua/ui/uiutil.lua')
    local LayoutHelpers = import('/lua/maui/layouthelpers.lua')
    local Escape = import('/lua/ui/dialogs/eschandler.lua')
    local C = Theme.Colors
    local metrics = Theme.Metrics
    local showFontBlock = ShouldShowFontBlock()
    local width = 960
    local height = showFontBlock and 836 or 604
    local pixel = LayoutHelpers.GetPixelScaleFactor()
    local scale = math.min(pixel, (parent.Width() - 32) / width, (parent.Height() - 32) / height)
    local ratio = scale / pixel
    local L = ReUI.UI.FloorLayouter(scale)
    local root = Group(parent)
    L(root):Fill(parent)
    local screen = GetFrame(0)
    root.Depth:Set(screen:GetTopmostDepth() + 20)

    local state = { closed = false, escapeBound = false }
    local localized = {}
    local function BindText(control, key)
        local function Update()
            local value = T(key)
            control:SetText(value)
        end
        table.insert(localized, Update)
        Update()
        return control
    end
    local function Close()
        if state.closed then return false end
        state.closed = true
        if state.escapeBound then
            Escape.PopEscapeHandler()
            state.escapeBound = false
        end
        root:Destroy()
        return true
    end

    local oldDestroy = root.OnDestroy
    root.OnDestroy = function(self)
        state.closed = true
        if state.escapeBound then
            Escape.PopEscapeHandler()
            state.escapeBound = false
        end
        Localization.Unsubscribe(root)
        oldDestroy(self)
    end

    local outside = Bitmap(root)
    outside:SetSolidColor(C.transparent)
    L(outside):Fill(root)
    outside:EnableHitTest()
    outside.Depth:Set(root.Depth() + 1)
    outside.HandleEvent = function(self, event)
        if event.Type == 'ButtonPress' then Close() end
        return false
    end

    local panel = Bitmap(root)
    panel:SetSolidColor(C.canvas)
    L(panel):AtCenterIn(root):Width(width):Height(height)
    panel.Depth:Set(root.Depth() + 2)
    Theme.Outline(panel, L, width, height, C.border)
    panel.HandleEvent = function() return true end

    local function Label(owner, value, font, size, color)
        local label = UI.CreateText(owner, value, size * ratio, font)
        label:SetColor(color)
        label:DisableHitTest()
        return label
    end

    local function BindLabel(owner, key, font, size, color)
        local label = Label(owner, '', font, size, color)
        BindText(label, key)
        return label
    end

    local function Paragraph(value, x, y, paragraphHeight, color, size)
        local paragraph = MultiLineText(panel, Theme.Fonts.body, (size or metrics.text) * ratio, color or C.text)
        L(paragraph):AtLeftTopIn(panel, x, y):Width(width - 64):Height(paragraphHeight)
        paragraph:DisableHitTest()
        -- An empty value makes MultiLineText remove its initial text line.
        if value ~= '' then paragraph:SetText(value) end
        return paragraph
    end

    local logo = Bitmap(panel)
    logo:SetTexture(Theme.Logos.wordmark)
    logo:DisableHitTest()
    L(logo):AtLeftTopIn(panel, (width - 280) / 2, 16):Width(280):Height(150)

    local clanBanner = Bitmap(panel)
    clanBanner:SetTexture('/mods/ClaretCore/textures/branding/dpg-wordmark.png')
    clanBanner:DisableHitTest()
    L(clanBanner):AtLeftTopIn(panel, 76, 49):Width(168):Height(67)

    local clanCredit = Group(panel)
    clanCredit:DisableHitTest()
    L(clanCredit):AtLeftTopIn(panel, 24, 132):Width(272):Height(54)
    local credit = BindLabel(clanCredit, 'core.welcome.clan_credit', Theme.Fonts.heading, 20, C.text)
    L(credit):AtCenterIn(clanCredit, -12)
    local clanName = BindLabel(clanCredit, 'core.welcome.clan_name', Theme.Fonts.heading, 24, C.text)
    L(clanName):AtCenterIn(clanCredit, 13)

    local function AddLink(key, url, y)
        local link = Group(panel)
        L(link):AtLeftTopIn(panel, 24, y):Width(272):Height(20)
        local label = BindLabel(link, key, Theme.Fonts.body, 14, C.accentText)
        L(label):AtCenterIn(link)
        link.HandleEvent = function(_, event)
            if event.Type == 'MouseEnter' then
                label:SetColor(C.text)
            elseif event.Type == 'MouseExit' then
                label:SetColor(C.accentText)
            elseif event.Type == 'ButtonPress' and not (event.Modifiers and event.Modifiers.Right) then
                OpenURL(url)
                return true
            end
            return false
        end
    end
    AddLink('core.welcome.project_link', 'https://github.com/tfckatsu-cpu/Claret', 185)
    AddLink('core.welcome.discord_link', 'https://discord.gg/JupcdJbu7U', 205)

    local titleBox = Group(panel)
    L(titleBox):AtLeftTopIn(panel, 32, 176):Width(width - 64):Height(36)
    titleBox:DisableHitTest()
    local title = BindLabel(titleBox, 'core.welcome.title', Theme.Fonts.heading, 24, C.text)
    L(title):AtCenterIn(titleBox)

    local intro = Paragraph('',32,225,48)
    BindText(intro,'core.welcome.intro')

    local languageLabel = BindLabel(panel, 'core.menu.language', Theme.Fonts.body, 16, C.text)
    L(languageLabel):AtLeftTopIn(panel, 32, 290)
    local languageButtons = {}
    local function UpdateLanguageButtons()
        local selected = languageOption and languageOption:Get() or Localization.GetLanguage()
        if selected ~= 'en' and selected ~= 'ru' then selected = Localization.GetLanguage() end
        for _, choice in ipairs(languageButtons) do
            local active = choice.id == selected
            choice.fill:SetSolidColor(active and C.selected or C.surface)
            choice.setBorder(active and C.selectedBorder or C.border)
            choice.text:SetColor(active and C.accentText or C.text)
        end
    end
    local function AddLanguageButton(x, id, labelKey)
        local button = Group(panel)
        L(button):AtLeftTopIn(panel, x, 278):Width(108):Height(36)
        local fill = Bitmap(button)
        fill:SetSolidColor(C.surface)
        fill:DisableHitTest()
        L(fill):AtLeftTopIn(button, 1, 1):Width(106):Height(34)
        local setBorder = Theme.Outline(button, L, 108, 36, C.border)
        local text = BindLabel(button, labelKey, Theme.Fonts.body, 16, C.text)
        L(text):AtCenterIn(button)
        button.HandleEvent = function(self, event)
            if event.Type == 'MouseEnter' then
                if not languageOption or languageOption:Get() ~= id then fill:SetSolidColor(C.hover) end
            elseif event.Type == 'MouseExit' then
                UpdateLanguageButtons()
            elseif event.Type == 'ButtonPress' then
                if not SetWelcomeLanguage(languageOption, id, Localization, SavePreferences) then
                    WARN('[Claret] Could not save interface language')
                end
                UpdateLanguageButtons()
            end
            return true
        end
        table.insert(languageButtons, {id = id, fill = fill, setBorder = setBorder, text = text})
    end
    AddLanguageButton(width - 256, 'en', 'core.language.english')
    AddLanguageButton(width - 136, 'ru', 'core.language.russian')
    table.insert(localized, UpdateLanguageButtons)
    UpdateLanguageButtons()

    local keyText = Label(panel, '', Theme.Fonts.heading, 18, C.accentText)
    local function UpdateKeyText() keyText:SetText(GetMenuBindingText(keyBinding,T)) end
    table.insert(localized,UpdateKeyText); UpdateKeyText()
    L(keyText):AtLeftTopIn(panel, 32, 330)

    local prefsTop = 496
    if showFontBlock then
        local fontTitle = BindLabel(panel, 'core.welcome.nunito_title', Theme.Fonts.heading, 18, C.text)
        L(fontTitle):AtLeftTopIn(panel, 32, 370)
        local fontDescription = Paragraph('',32,400,52)
        BindText(fontDescription,'core.welcome.nunito_description')
        local fontPath = Paragraph('',32,456,28,C.muted,18)
        BindText(fontPath,'core.welcome.nunito_path')
    end

    local prefsTitle = BindLabel(panel, 'core.welcome.prefs_title', Theme.Fonts.heading, 18, C.text)
    L(prefsTitle):AtLeftTopIn(panel, 32, prefsTop)
    local prefsDescription = Paragraph('',32,prefsTop+30,72)
    BindText(prefsDescription,'core.welcome.prefs_description')
    local prefsPath = Paragraph('',32,prefsTop+106,42,C.muted,18)
    BindText(prefsPath,'core.welcome.prefs_path')
    local prefsWarning = Paragraph('',32,prefsTop+152,72,C.warning)
    BindText(prefsWarning,'core.welcome.prefs_warning')

    local checkbox = Group(panel)
    L(checkbox):AtLeftTopIn(panel, 32, height - 64):Width(360):Height(48)
    local box = Bitmap(checkbox)
    L(box):AtLeftTopIn(checkbox, 0, 12):Width(24):Height(24)
    local setBoxBorder = Theme.Outline(box, L, 24, 24, C.border)
    local checkboxText = BindLabel(checkbox, 'core.welcome.dismiss', Theme.Fonts.body, 18, C.text)
    L(checkboxText):AtLeftTopIn(checkbox, 36, 11)
    local function UpdateCheckbox()
        local checked = dismissedOption and dismissedOption:Get() == true
        box:SetSolidColor(checked and C.accent or C.surface)
        setBoxBorder(checked and C.accentText or C.border)
    end
    UpdateCheckbox()
    checkbox.HandleEvent = function(self, event)
        if event.Type == 'ButtonPress' and dismissedOption then
            if not ToggleWelcomeDismissal(dismissedOption, SavePreferences) then
                WARN('[Claret] Could not save welcome visibility')
            end
            UpdateCheckbox()
        end
        return true
    end

    local buttonWidth, buttonHeight = 168, 48
    local button = Group(panel)
    L(button):AtLeftTopIn(panel, (width - buttonWidth) / 2, height - 64):Width(buttonWidth):Height(buttonHeight)
    local fill = Bitmap(button)
    fill:SetSolidColor(C.accent)
    fill:DisableHitTest()
    L(fill):AtLeftTopIn(button, 2, 2):Width(buttonWidth - 4):Height(buttonHeight - 4)
    local setBorder = Theme.Outline(button, L, buttonWidth, buttonHeight, C.border)
    local buttonText = BindLabel(button, 'core.welcome.close', Theme.Fonts.body, 20, C.text)
    L(buttonText):AtCenterIn(button)
    button.HandleEvent = function(self, event)
        if event.Type == 'MouseEnter' then
            fill:SetSolidColor(C.accentHover)
            setBorder(C.accentText)
        elseif event.Type == 'MouseExit' then
            fill:SetSolidColor(C.accent)
            setBorder(C.border)
        elseif event.Type == 'ButtonPress' then
            fill:SetSolidColor(C.pressed)
            Close()
        end
        return true
    end

    Escape.PushEscapeHandler(Close)
    state.escapeBound = true
    Localization.Subscribe(root,function()
        if not state.closed then for _, update in ipairs(localized) do update() end end
    end)
    return root
end
