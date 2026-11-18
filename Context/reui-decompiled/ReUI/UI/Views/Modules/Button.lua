-- Generated research-only output. Original SHA256: 2b696034bf6047ce586babc26b9cfec52c431505545441009462c6ed96011138. Not for game execution.
local Bitmap = ReUI.UI.Controls.Bitmap
local _Button = import("/lua/maui/button.lua").Button
Button = ReUI.Core.Class(Bitmap)({
  __init = function(self, parent, normal, active, highlight, disabled, clickCue, rolloverCue, frameRate)
    Bitmap.__init(self, parent, normal)
    self.mNormal = normal
    self.mActive = active
    self.mHighlight = highlight
    self.mDisabled = disabled
    self.mMouseOver = false
    self.mClickCue = clickCue
    self.mRolloverCue = rolloverCue
    if frameRate then
      self:SetFrameRate(frameRate)
    end
    self:SetLoopPingPongPattern()
    self:Loop(true)
  end,
  SetNewTextures = _Button.SetNewTextures,
  ApplyTextures = _Button.ApplyTextures,
  OnDisable = _Button.OnDisable,
  OnRolloverEvent = function(self, state)
  end,
  OnEnable = _Button.OnEnable,
  HandleEvent = _Button.HandleEvent,
  OnClick = function(self, modifiers)
  end
})
