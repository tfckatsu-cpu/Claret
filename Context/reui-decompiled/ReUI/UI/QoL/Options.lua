-- Generated research-only output. Original SHA256: 97a13438b15cb574cc7f3a8553ce6739fddc26a640e60c06962b889bedacfe11. Not for game execution.
local Options = ReUI.Options.Builder
local Opt = ReUI.Options.OptionValue
ReUI.Options.Mods["ReUI.UI.QoL"] = {
  movableMenuPanel = Opt(true),
  multifunctionPanelCollapsed = Opt(true),
  menuPanelCollapsed = Opt(true)
}

function Main()
  local options = ReUI.Options.Mods["ReUI.UI.QoL"]
  Options.AddOptions("ReUI.UI.QoL", "ReUI.UI.QoL", {
    Options.Filter("Movable menu panel", options.movableMenuPanel, 4),
    Options.Filter("Start game with multifunction panel closed", options.multifunctionPanelCollapsed, 4),
    Options.Filter("Start game with menu panel closed", options.menuPanelCollapsed, 4)
  })
end
