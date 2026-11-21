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
    local width, height = 928, 584
    local padding, gap = metrics.padding, metrics.panelGap
    local contentWidth = width - padding * 2
    local pixel = LayoutHelpers.GetPixelScaleFactor()
    local scale = math.min(pixel, (parent.Width() - 48) / width, (parent.Height() - 48) / height)
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
    L(panel):AtCenterIn(root):Width(width):Height(height)
    panel.Depth:Set(root.Depth() + 2)
    Theme.RoundedPanel(panel, L, width, height, C.canvas, C.border, true)
    panel.HandleEvent = function() return true end

    local function Label(owner, value, font, size, color)
        local label = UI.CreateText(owner, value, size * ratio, font)
        label:SetColor(color)
        label.Depth:Set(function() return owner.Depth() + 3 end)
        label:DisableHitTest()
        return label
    end

    local function BindLabel(owner, key, font, size, color)
        local label = Label(owner, '', font, size, color)
        BindText(label, key)
        return label
    end

    local function Paragraph(owner, x, y, w, h, color, size)
        local paragraph = MultiLineText(owner, Theme.Fonts.body, size * ratio, color)
        L(paragraph):AtLeftTopIn(owner, x, y):Width(w):Height(h)
        paragraph:DisableHitTest()
        return paragraph
    end

    local function Surface(owner, x, y, w, h, color)
        local surface = Bitmap(owner)
        surface:SetSolidColor(color)
        surface:DisableHitTest()
        surface.Depth:Set(function() return owner.Depth() + 1 end)
        L(surface):AtLeftTopIn(owner, x, y):Width(w):Height(h)
        return surface
    end

    local function Card(x, y, w, h)
        local card = Group(panel)
        L(card):AtLeftTopIn(panel, x, y):Width(w):Height(h)
        card.Depth:Set(function() return panel.Depth() + 3 end)
        Surface(card, 0, 0, w, h, C.surface)
        Theme.Outline(card, L, w, h, C.border)
        local content = Group(card)
        L(content):Fill(card)
        content.Depth:Set(function() return card.Depth() + 2 end)
        return content
    end

    local function Button(owner, x, y, w, h, key, onPress, primary, onRightPress)
        local control = Group(owner)
        control:EnableHitTest()
        control.Depth:Set(function() return owner.Depth() + 2 end)
        L(control):AtLeftTopIn(owner, x, y):Width(w):Height(h)
        local fill = Surface(control, 1, 1, w - 2, h - 2, C.surface)
        local border = Theme.Outline(control, L, w, h, C.border)
        local label = BindLabel(control, key, primary and Theme.Fonts.heading or Theme.Fonts.body,
            metrics.buttonText, C.text)
        L(label):AtCenterIn(control)
        local selected, hovered, pressed = false, false, false
        local function Paint()
            local normal = primary and C.accent or selected and C.selected or C.raised
            local hover = primary and C.accentHover or C.hover
            local down = primary and C.accentPressed or C.pressed
            fill:SetSolidColor(pressed and down or hovered and hover or normal)
            border(selected and C.selectedBorder or hovered and C.muted or C.border)
            label:SetColor(selected and C.accentText or C.text)
        end
        control.HandleEvent = function(_, event)
            if event.Type == 'MouseEnter' then
                hovered = true
            elseif event.Type == 'MouseExit' then
                hovered, pressed = false, false
            elseif event.Type == 'ButtonRelease' then
                pressed = false
            elseif event.Type == 'ButtonPress' then
                if event.Modifiers and event.Modifiers.Right then
                    if not onRightPress then return false end
                    onRightPress()
                    return true
                end
                pressed = true
                Paint()
                onPress()
                return true
            else
                return false
            end
            Paint()
            return true
        end
        Paint()
        return function(active)
            selected = active
            Paint()
        end
    end

    local logo = Surface(panel, padding, 20, 192, 103, C.transparent)
    logo:SetTexture(Theme.Logos.wordmark)
    logo.Depth:Set(function() return panel.Depth() + 3 end)
    local title = BindLabel(panel, 'core.welcome.title', Theme.Fonts.heading, metrics.title + 6, C.text)
    L(title):AtLeftTopIn(panel, padding, 124)
    local intro = BindLabel(panel, 'core.welcome.intro', Theme.Fonts.body, metrics.text, C.muted)
    L(intro):AtLeftTopIn(panel, padding, 164)

    local communityWidth = 304
    local community = Card(width - padding - communityWidth, padding, communityWidth, 168)
    local clanBanner = Surface(community, 16, 17, 88, 35, C.transparent)
    clanBanner:SetTexture('/mods/ClaretCore/textures/branding/dpg-wordmark.png')
    clanBanner.Depth:Set(function() return community.Depth() + 2 end)
    local credit = BindLabel(community, 'core.welcome.clan_credit', Theme.Fonts.body, metrics.secondaryText, C.muted)
    L(credit):AtLeftTopIn(community, 116, 14)
    local clanName = BindLabel(community, 'core.welcome.clan_name', Theme.Fonts.heading, metrics.heading, C.text)
    L(clanName):AtLeftTopIn(community, 116, 33)
    local linkStatus = 'core.welcome.link_copy_hint'
    local linkHint = Label(community, '', Theme.Fonts.body, metrics.caption, C.muted)
    L(linkHint):AtLeftTopIn(community, 16, 151)
    local function UpdateLinkHint() linkHint:SetText(T(linkStatus)) end
    table.insert(localized, UpdateLinkHint)
    UpdateLinkHint()
    local function AddLink(key, address, y)
        Button(community, 16, y, communityWidth - 32, metrics.buttonHeight, key, function()
            -- FAF's own GitHub and Discord buttons use HTTP for the engine opener.
            OpenURL('http://' .. address, root)
        end, false, function()
            linkStatus = CopyToClipboard('https://' .. address) and 'core.welcome.link_copied'
                or 'core.welcome.link_copy_failed'
            UpdateLinkHint()
        end)
    end
    AddLink('core.welcome.project_link', 'github.com/tfckatsu-cpu/Claret', 66)
    AddLink('core.welcome.discord_link', 'discord.gg/JupcdJbu7U', 108)

    local settings = Card(padding, 208, contentWidth, 64)
    local shortcut = Paragraph(settings, 16, 18, 420, 42, C.accentText, metrics.text)
    local function UpdateShortcut() shortcut:SetText(GetMenuBindingText(keyBinding, T)) end
    table.insert(localized, UpdateShortcut)
    UpdateShortcut()
    Surface(settings, 446, 12, 1, 40, C.border)
    local languageLabel = BindLabel(settings, 'core.menu.language', Theme.Fonts.body, metrics.text, C.text)
    L(languageLabel):AtLeftTopIn(settings, 464, 21)
    local languageButtons = {}
    local function UpdateLanguageButtons()
        local selected = languageOption and languageOption:Get() or Localization.GetLanguage()
        if selected ~= 'en' and selected ~= 'ru' then selected = Localization.GetLanguage() end
        for id, paint in pairs(languageButtons) do paint(id == selected) end
    end
    local function AddLanguageButton(x, id, labelKey)
        languageButtons[id] = Button(settings, x, 14, 100, metrics.buttonHeight, labelKey, function()
            if not SetWelcomeLanguage(languageOption, id, Localization, SavePreferences) then
                WARN('[Claret] Could not save interface language')
            end
            UpdateLanguageButtons()
        end)
    end
    AddLanguageButton(contentWidth - 224, 'en', 'core.language.english')
    AddLanguageButton(contentWidth - 116, 'ru', 'core.language.russian')
    table.insert(localized, UpdateLanguageButtons)
    UpdateLanguageButtons()

    local cardWidth, cardHeight, cardTop = (contentWidth - gap) / 2, 208, 288
    local function InstructionCard(x, titleKey, descriptionKey, pathKey, warningKey)
        local card = Card(x, cardTop, cardWidth, cardHeight)
        local heading = BindLabel(card, titleKey, Theme.Fonts.heading, metrics.heading, C.text)
        L(heading):AtLeftTopIn(card, 16, 16)
        BindText(Paragraph(card, 16, 48, cardWidth - 32, 48, C.text, metrics.secondaryText), descriptionKey)
        local pathPlate = Surface(card, 16, 100, cardWidth - 32, 44, C.raised)
        BindText(Paragraph(pathPlate, 10, 5, cardWidth - 52, 36, C.muted, metrics.label), pathKey)
        if warningKey then
            BindText(Paragraph(card, 16, 154, cardWidth - 32, 46, C.warning, metrics.secondaryText), warningKey)
        end
    end
    if ShouldShowFontBlock() then
        InstructionCard(padding, 'core.welcome.nunito_title', 'core.welcome.nunito_description', 'core.welcome.nunito_path')
    end
    InstructionCard(padding + cardWidth + gap, 'core.welcome.prefs_title', 'core.welcome.prefs_description',
        'core.welcome.prefs_path', 'core.welcome.prefs_warning')

    local footerTop = height - padding - metrics.rowHeight
    local divider = Surface(panel, padding, footerTop - 12, contentWidth, 1, C.border)
    divider.Depth:Set(function() return panel.Depth() + 3 end)
    local dismissal = Card(padding, footerTop, 328, metrics.rowHeight)
    dismissal:EnableHitTest()
    local dismissalLabel = BindLabel(dismissal, 'core.welcome.dismiss', Theme.Fonts.body, metrics.text, C.text)
    L(dismissalLabel):AtLeftTopIn(dismissal, 16, 9)
    local PaintDismissal = Theme.SettingsSwitch(dismissal, L, 328, metrics.rowHeight, ratio, true)
    PaintDismissal(dismissedOption and dismissedOption:Get() == true)
    dismissal.HandleEvent = function(_, event)
        if event.Type == 'ButtonPress' and not (event.Modifiers and event.Modifiers.Right) and dismissedOption then
            if not ToggleWelcomeDismissal(dismissedOption, SavePreferences) then
                WARN('[Claret] Could not save welcome visibility')
            end
            PaintDismissal(dismissedOption:Get() == true)
        end
        return true
    end
    Button(panel, width - padding - 152, footerTop, 152, metrics.rowHeight, 'core.welcome.close', Close, true)

    Escape.PushEscapeHandler(Close)
    state.escapeBound = true
    Localization.Subscribe(root,function()
        if not state.closed then for _, update in ipairs(localized) do update() end end
    end)
    return root
end
