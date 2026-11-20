ReUI.Options.Mods['ClaretCore'] = {
    probeEnabled = ReUI.Options.OptionValue(false),
    selectionEnabled = ReUI.Options.OptionValue(true),
    welcomeDismissed = ReUI.Options.OptionValue(false),
    minimapAutoHide = ReUI.Options.OptionValue(false),
    minimapBorderless = ReUI.Options.OptionValue(false),
    language = ReUI.Options.OptionValue('auto'), -- Migrated once to EN/RU during startup.
}

-- Values keep their existing ReUI preference paths; UI lives in the Claret menu.
function Main() end
