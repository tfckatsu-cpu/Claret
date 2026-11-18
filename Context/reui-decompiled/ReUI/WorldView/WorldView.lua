-- Generated research-only output. Original SHA256: 1d5b62e353fc3f522cd3d07599d0b935527b75dda839488813417551b857443c. Not for game execution.
Version = "1.0.0"
ReUI.Require({
  "ReUI.Core >= 1.2.0",
  "ReUI.ECS >= 1.0.0"
})

function Main(isReplay)
  ReUI.Core.Hook("/lua/ui/controls/worldview.lua", "WorldView", function(WorldView, module)
    local WorldView__post_init = WorldView.__post_init
    local WorldViewHandleEvent = WorldView.HandleEvent
    local WorldViewOnFrame = WorldView.OnFrame
    local WorldViewOnUpdateCursor = WorldView.OnUpdateCursor
    local WorldViewOnDestroy = WorldView.OnDestroy
    local ReUIWorldView = Class(WorldView, ReUI.ECS.ComponentContainer)({
      __post_init = function(self, parentControl, cameraName, depth, isMiniMap, trackCamera)
        WorldView__post_init(self, parentControl, cameraName, depth, isMiniMap, trackCamera)
        local componentClasses = isMiniMap and ReUI.WorldView.MinimapComponents or ReUI.WorldView.PrimaryComponents
        for name, componentClass in componentClasses, nil do
          self:AddComponent(name, componentClass(self, name))
        end
        for _, component in self:IterateComponents() do
          component:Init()
        end
        if not isMiniMap then
          self:SetNeedsFrameUpdate(true)
        end
      end,
      HandleEvent = function(self, event)
        local result = false
        for _, component in self:IterateEnabledComponents() do
          result = component:OnHandleEvent(event) or result
        end
        return WorldViewHandleEvent(self, event) or result
      end,
      OnFrame = function(self, delta)
        for _, component in self:IterateEnabledComponents() do
          component:OnFrame(delta)
        end
        return WorldViewOnFrame(self, delta)
      end,
      OnUpdateCursor = function(self)
        for _, component in self:IterateEnabledComponents() do
          component:OnUpdateCursor()
        end
        return WorldViewOnUpdateCursor(self)
      end,
      OnDestroy = function(self)
        self:DestroyComponents()
        return WorldViewOnDestroy(self)
      end,
      GetCamera = function(self)
        local camera = self._camera
        if not camera then
          camera = GetCamera(self._cameraName)
          self._camera = camera
        end
        return camera
      end
    })
    return ReUIWorldView
  end)
  local Component = import("Modules/WorldViewComponent.lua").Component
  return {
    Component = Component,
    PrimaryComponents = {},
    MinimapComponents = {}
  }
end
