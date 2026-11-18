-- Generated research-only output. Original SHA256: 8a9352be311827235b9d8c2815d0ab850da43c98a93227b01e002f79c550fe4c. Not for game execution.
local Group = ReUI.UI.Controls.Group
local Bitmap = ReUI.UI.Controls.Bitmap
local Text = ReUI.UI.Controls.Text
local ColoredIntegerSlider = import("Views/ColoredSlider.lua").ColoredIntegerSlider
local options = ReUI.Options.Mods["ReUI.Score"]
local obsTextFont = options.observer.font:Raw()
local obsTextSize = 12
local bgColor = options.player.color.bg:Raw()
local sliderColor = options.observer.color.line:Raw()
local width = 300
local height = 20
ObserverPanel = ReUI.Core.Class(Group)({
  __init = function(self, parent)
    Group.__init(self, parent)
    self._bg = Bitmap(self)
    self._slider = ColoredIntegerSlider(self, false, -10, 10, 1, sliderColor, "ffeeee00", "ffffff00", "ffffbb00", 2)
    
    function self._slider.OnValueSet(slider, newValue)
      ConExecute("WLD_GameSpeed " .. tostring(newValue))
    end
    
    self._speed = Text(self)
    self._speed:SetFont(obsTextFont, obsTextSize)
    
    function self._slider.OnValueChanged(slider, newValue)
      self._speed:SetText(tostring(newValue))
    end
    
    self._slider:SetValue(0)
    self._observerText = Text(self)
    self._observerText:SetText(LOC("<LOC score_0003>Observer"))
    self._observerText:SetFont(obsTextFont, obsTextSize)
  end,
  InitLayout = function(self, layouter)
    layouter(self._bg):Fill(self):Color(bgColor):DisableHitTest()
    layouter(self._observerText):AtLeftTopIn(self, 10, 2):Over(self, 10):DisableHitTest()
    layouter(self._slider):AtVerticalCenterIn(self):AtRightIn(self, 25):RightOf(self._observerText, 5):Height(height - 4):Over(self, 10)
    layouter(self._speed):AtVerticalCenterIn(self):RightOf(self._slider, 5):Over(self, 10):DisableHitTest()
    layouter(self):Width(layouter:Min(self:GetParent().Width, width)):Height(height)
  end,
  SetGameSpeed = function(self, newSpeed)
    self._slider:SetValue(newSpeed)
  end,
  HandleEvent = function(self, event)
    if event.Type == "ButtonPress" and not event.Modifiers.Shift and not event.Modifiers.Ctrl then
      ConExecute("SetFocusArmy -1")
    end
  end
})
