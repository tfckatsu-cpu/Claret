-- Generated research-only output. Original SHA256: 0a687fe145924348b82cc898dd389aacabefc961a9e6562080e35ca34b670b2f. Not for game execution.
Component = ReUI.Core.Class()({
  __init = function(self, worldView, name)
    self.name = name
    self.worldView = worldView
  end,
  Init = function(self)
    self:OnInit()
    self:Enable()
  end,
  Enable = function(self)
    if self.enabled then
      return
    end
    self.enabled = true
    self:OnEnabled()
  end,
  Disable = function(self)
    if not self.enabled then
      return
    end
    self.enabled = false
    self:OnDisabled()
  end,
  OnInit = function(self)
  end,
  OnEnabled = function(self)
  end,
  OnDisabled = function(self)
  end,
  OnHandleEvent = function(self, event)
    return false
  end,
  OnFrame = function(self, delta)
  end,
  OnUpdateCursor = function(self)
  end,
  OnDestroy = function(self)
  end,
  Destroy = function(self)
    self:Disable()
    self:OnDestroy()
    self.worldView = nil
    self.name = nil
  end
})
