Version = '0.2.38'
-- Bump for every Claret UI code change so the loaded build is identifiable.
local BuildStamp = '20261120-41'
LOG('[Claret][build] ui='..Version..' stamp='..BuildStamp)

ReUI.Require {
    'ClaretCore >= 0.10.25',
    'ReUI.Core >= 1.7.0',
    'ReUI.UI >= 1.0.0',
    'ReUI.Options >= 1.2.0',
    enabled = true,
    version = 1,
}

function Main(isReplay)
    local Localization = ReUI.ClaretCore.Localization
    local localizationTables = import('/mods/ClaretUI/modules/LocalizationStrings.lua').Strings
    local localizationOk, localizationError = Localization.Register('claretui', localizationTables)
    if not localizationOk then error(localizationError) end
    local options = ReUI.Options.Mods['ClaretUI']
    import('/mods/ClaretUI/modules/features/AllRings.lua').Install()
    local Runtime = import('/mods/ClaretUI/modules/Runtime.lua')
    local service
    local function Ensure()
        if not service then service = Runtime.Create(isReplay, options) end
        return service
    end
    local featureOk, featureError = ReUI.ClaretCore.RegisterFeature('claretui', function(scope)
        Ensure():Start(scope)
    end, options.enabled)
    if not featureOk then error(featureError) end
    -- Fills the 'ui' placeholder section that Core reserves in the launcher.
    local UiSection = import('/mods/ClaretUI/modules/UiSection.lua')
    local sectionOk, sectionError = ReUI.ClaretCore.RegisterSettingsSection {
        id = 'ui', title = 'UI', titleKey = 'claretui.section.title', descriptionKey = 'claretui.section.description',
        inline = function(parent, layout)
            return UiSection.Create(parent, layout, options, ReUI.Options.Mods['ClaretCore'])
        end,
    }
    if not sectionOk then error(sectionError) end
end
