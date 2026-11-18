-- Generated research-only output. Original SHA256: 503a6be91d4f0d892b295b64df5135c132e2683f7303e0f4dccee1ea1eb671ba. Not for game execution.
local Group = ReUI.UI.Controls.Group
local Bitmap = ReUI.UI.Controls.Bitmap
local Text = ReUI.UI.Controls.Text
local LazyVar = import("/lua/lazyvar.lua").Create
Overlay = ReUI.Core.Class(Bitmap)({
  __init = function(self, parent, unit, worldView)
    Bitmap.__init(self, parent)
    self._worldView = worldView
    self.id = unit:GetEntityId()
    self.unit = unit
    self.offsetX = 0
    self.offsetY = 0
    self.PosX = LazyVar()
    self.PosY = LazyVar()
  end,
  InitLayout = function(self, layouter)
    local worldView = self._worldView
    self.Left:Set(function()
      return worldView.Left() + self.PosX() - self.Width() * 0.5 + self.offsetX
    end)
    self.Top:Set(function()
      return worldView.Top() + self.PosY() - self.Height() * 0.5 + self.offsetY
    end)
    self:Hide()
    self:DisableHitTest()
    self:SetNeedsFrameUpdate(true)
  end,
  GetUnitPosition = function(self)
    return self._worldView:GetScreenPos(self.unit)
  end,
  Update = function(self)
    local pos = self:GetUnitPosition()
    if pos then
      self.PosX:Set(pos.x)
      self.PosY:Set(pos.y)
      self:Show()
    else
      self:Hide()
    end
  end,
  OnDestroy = function(self)
    if self.PosX then
      self.PosX:Destroy()
      self.PosX = nil
    end
    if self.PosY then
      self.PosY:Destroy()
      self.PosY = nil
    end
    self.id = nil
    self.unit = nil
    self.offsetX = nil
    self.offsetY = nil
    self._worldView = nil
    Bitmap.OnDestroy(self)
  end
})
