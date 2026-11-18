-- Generated research-only output. Original SHA256: bb03bdafea94ec29d35a6fbba41aae8669f1dd16c776f8f9566970c153b46e53. Not for game execution.
local ArmyViews = import("../ArmyView.lua")
local Animations = import("../Animations.lua")
local contractAnimation = Animations.contractAnimation
local expandAnimation = Animations.expandAnimation
local animationSpeed = 500

local function Clear(scoreboard, layouter)
  scoreboard._border:Destroy()
  scoreboard._border = nil
  scoreboard._bracket:Destroy()
  scoreboard._bracket = nil
  scoreboard._arrow:Destroy()
  scoreboard._arrow = nil
  if scoreboard._title then
    layouter(scoreboard._title):Width(300)
  end
  for i, armyView in scoreboard:GetArmyViews() do
    layouter(armyView):Width(armyView.isAlly and ArmyViews.allyViewWidth or ArmyViews.armyViewWidth)
  end
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
  layouter(scoreboard):AtRightIn(GetFrame(0), 25):Width(ArmyViews.allyViewWidth)
  if scoreboard._title then
    layouter(scoreboard._title):Width(scoreboard.Width)
  end
  for i, armyView in scoreboard:GetArmyViews() do
    layouter(armyView):Width(ArmyViews.allyViewWidth)
  end
  return Clear
end
