-- Generated research-only output. Original SHA256: 15794088c693572eaa7819251cfc8e4ef317ac234dd724b218e4f4e6a0922994. Not for game execution.
local Options = ReUI.Options.Builder
local Opt = ReUI.Options.OptionValue
ReUI.Options.Mods["ReUI.Selection"] = {
  enabled = Opt(true)
}

function Main()
  local options = ReUI.Options.Mods["ReUI.Selection"]
  Options.AddOptions("ReUI.Selection", "ReUI.Selection", {
    Options.Filter("Mod enabled", options.enabled, 4)
  })
end
