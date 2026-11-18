-- Generated research-only output. Original SHA256: 4a3a85ac04d1a7a9ceee33fe3875f6b10dec3060cb705fd36e5877a3bf31ae60. Not for game execution.
Version = "1.2.0"
ReUI.Require({
  "ReUI.UI.Controls >= 1.0.0"
})

function Main(isReplay)
  local Brackets = import("Modules/Brackets.lua")
  return {
    Button = import("Modules/Button.lua").Button,
    Brackets = {
      RightGlow = Brackets.RightGlow,
      FactionRight = Brackets.FactionRightBracket
    },
    WindowFrame = import("Modules/WindowFrame.lua").WindowFrame,
    VerticalCollapseArrow = import("Modules/CollapseArrow.lua").VerticalCollapseArrow,
    HorizontalCollapseArrow = import("Modules/CollapseArrow.lua").HorizontalCollapseArrow,
    EscapeCover = import("Modules/EscapeCover.lua").EscapeCover,
    StaticScrollable = import("Modules/StaticScrollable.lua").StaticScrollable,
    DynamicScrollable = import("Modules/DynamicScrollable.lua").DynamicScrollable,
    GlowBorder = import("Modules/GlowBorder.lua").GlowBorder
  }
end
