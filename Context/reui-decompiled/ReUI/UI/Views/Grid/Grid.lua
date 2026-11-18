-- Generated research-only output. Original SHA256: c4af382402289bbdbdda632940a5be2d3e04f7918412bc677e33ca05c1408009. Not for game execution.
Version = "1.1.0"
ReUI.Require({
  "ReUI.Core >= 1.1.0",
  "ReUI.UI.Controls >= 1.0.0",
  "ReUI.UI.Views >= 1.0.0",
  "ReUI.ECS >= 1.0.0"
})

function Main(isReplay)
  local BaseGridItem = import("Modules/BaseGridItem.lua").BaseGridItem
  local BaseGridPanel = import("Modules/BaseGridPanel.lua").BaseGridPanel
  local AItemComponent = import("Modules/AItemComponent.lua").AItemComponent
  local ASelectionHandler = import("Modules/ASelectionHandler.lua").ASelectionHandler
  return {
    Abstract = {AItemComponent = AItemComponent, ASelectionHandler = ASelectionHandler},
    BaseGridItem = BaseGridItem,
    BaseGridPanel = BaseGridPanel,
    Grid = import("Modules/Grid.lua").Grid
  }
end
