-- Generated research-only output. Original SHA256: 17368758988d577b596b450a901115bd3212fc51b3659e4fea2facd51704b049. Not for game execution.
local Options = ReUI.Options.Builder
local Opt = ReUI.Options.Opt
ReUI.Options.Mods["ReUI.Construction.Templates"] = {
  templateNameLength = Opt(10),
  previewBuildTemplates = Opt(true),
  previewFactoryTemplates = Opt(true)
}

function Main()
  local options = ReUI.Options.Mods["ReUI.Construction.Templates"]
  Options.AddOptions("ReUI.Construction.Templates", "ReUI.Construction.Templates", {
    Options.Slider("Templates name length", 1, 10, 1, options.templateNameLength, 4),
    Options.Filter("Preview build templates", options.previewBuildTemplates, 4),
    Options.Filter("Preview factory templates", options.previewFactoryTemplates, 4)
  })
end
