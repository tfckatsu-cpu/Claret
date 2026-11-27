Version = '0.1.10'

ReUI.Require {
    'ClaretCore >= 0.10.41',
    'ReUI.UI >= 1.0.0',
    enabled = true,
}

function Main(isReplay)
    local core = ReUI.ClaretCore
    local localization = import('/mods/ClaretCinema/modules/Localization.lua').Strings
    local ok, message = core.Localization.Register('cinema', localization)
    if not ok then error(message) end
    local memory = {}
    ok, message = core.RegisterSettingsSection {
        id = 'cinema',
        title = 'Cinema',
        inline = function(parent, layout)
            return import('/mods/ClaretCinema/modules/KeyboardEditor.lua').Create(parent, layout, memory)
        end,
    }
    if not ok then error(message) end
    ReUI.Core.OnPostCreateUI(function()
        local runtime = import('/mods/ClaretCinema/modules/Runtime.lua')
        local director = runtime.GetDirector()
        if director then
            import('/mods/ClaretCinema/modules/Drawer.lua').Create(GetFrame(0), director, runtime)
            LOG('[ClaretCinema] Shooting drawer ready')
        end
    end)
    LOG('[ClaretCinema ' .. Version .. '] Keyboard settings registered')
end
