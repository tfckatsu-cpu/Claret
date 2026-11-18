-- Generated research-only output. Original SHA256: 86021fe886eb0cc5662791de1f9b689fc80c9244079987c7d35dc2de4473a667. Not for game execution.
local Bitmap = ReUI.UI.Controls.Bitmap
local ALazyComponentContainer = ReUI.ECS.ALazyComponentContainer
AGridItem = ReUI.Core.Class(Bitmap, ALazyComponentContainer)({
  __init = function(self, parent)
    Bitmap.__init(self, parent)
    self._activeComponent = nil
  end,
  InitLayout = function(self, layouter)
    layouter(self):Width(0):Height(0):Color("99000000")
  end,
  EnableComponent = function(self, name, action, context)
    self:DisableComponents()
    self:SetActiveComponent(name)
    self:Enable()
    local component = self:GetActiveComponent()
    component:Enable(self, action, context)
  end,
  DisableComponents = function(self)
    local components = self:GetComponents()
    if not components then
      return
    end
    for _, component in components, nil do
      component:Disable(self)
    end
  end,
  OnDisable = function(self)
    self:DisableComponents()
  end,
  GetActiveComponent = function(self)
    return self:GetComponent(self._activeComponent)
  end,
  SetActiveComponent = function(self, name)
    self._activeComponent = name
  end,
  HandleEvent = function(self, event)
    local component = self:GetActiveComponent()
    if component then
      component:HandleEvent(self, event)
    end
  end,
  OnFrame = function(self, delta)
    local component = self:GetActiveComponent()
    if component then
      component:OnFrame(self, delta)
    end
  end,
  OnDestroy = function(self)
    self:DestroyComponents()
    Bitmap.OnDestroy(self)
  end
})
