-- Generated research-only output. Original SHA256: 70e972daa97583dde0631195338b0cba78c9a62f8f38087b5cd4ac773f62e4f2. Not for game execution.
Version = "1.4.0"
ReUI.Require({
  "ReUI.Core >= 1.0.0"
})

function Main(isReplay)
  local LayoutFunctions = import("Modules/LayoutFunctions.lua")
  local LayouterModule = import("Modules/Layouter.lua")
  local Layoutable = import("Modules/Layoutable.lua").Layoutable
  local BaseLayout = import("Modules/Layoutable.lua").BaseLayout
  return {
    Layouter = LayouterModule.Layouter,
    FloorLayouter = LayouterModule.FloorLayouter,
    RoundLayouter = LayouterModule.RoundLayouter,
    FloorLayoutFor = LayouterModule.FloorLayoutFor,
    RoundLayoutFor = LayouterModule.RoundLayoutFor,
    Layoutable = Layoutable,
    LayoutFunctions = LayoutFunctions,
    BaseLayout = BaseLayout,
    Global = ReUI.Core.Weak.Value({})
  }
end
