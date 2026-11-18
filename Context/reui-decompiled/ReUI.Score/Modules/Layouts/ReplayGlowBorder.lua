-- Generated research-only output. Original SHA256: cf3b1d10f315553b9fe78232cf72b1ddc65e82bff5a24699c6ab1de0123f72c4. Not for game execution.
local Animations = import("../Animations.lua")
local contractAnimation = Animations.contractAnimation
local expandAnimation = Animations.expandAnimation
local animationSpeed = 500

local function Clear(scoreboard)
  scoreboard._border:Destroy()
  scoreboard._border = nil
  scoreboard._bracket:Destroy()
  scoreboard._bracket = nil
  scoreboard._arrow:Destroy()
  scoreboard._arrow = nil
end

local function InitialAnimation(scoreboard)
  Animations.slideAnimation:Apply(scoreboard, animationSpeed, 25)
end

function Layout(scoreboard, layouter)
  scoreboard:InitLayout(layouter)
  scoreboard.InitialAnimation = InitialAnimation
  scoreboard._bracket = ReUI.UI.Views.Brackets.FactionRight(scoreboard)
  scoreboard._border = ReUI.UI.Views.GlowBorder(scoreboard)
  scoreboard._arrow = ReUI.UI.Views.VerticalCollapseArrow(scoreboard)
  layouter(scoreboard._arrow):AtTopIn(scoreboard, 10):DefaultScale(function(_layouter)
    _layouter:AtRightIn(GetFrame(0), -3)
  end):Over(scoreboard, 20)
  
  function scoreboard._arrow.OnCheck(arrow, checked)
    if not checked then
      expandAnimation:Apply(scoreboard, animationSpeed, 25)
    else
      contractAnimation:Apply(scoreboard, animationSpeed, 25)
    end
  end
  
  layouter(scoreboard._bracket):AtTopIn(scoreboard, -13):AtBottomIn(scoreboard, -13):AtRightIn(scoreboard, -26):Over(scoreboard, 10)
  layouter(scoreboard._border):FillFixedBorder(scoreboard, -10):Over(scoreboard):DisableHitTest(true)
  layouter(scoreboard._dataPanel):Width(scoreboard.Width)
  if scoreboard._title then
    layouter(scoreboard._title):Width(scoreboard.Width)
  end
  layouter(scoreboard):AtRightIn(GetFrame(0), 25)
  return Clear
end
