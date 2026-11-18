-- Generated research-only output. Original SHA256: 1ac5eb7e7d16996b6e62f5bf35c53f27c57ff40683650916fca483f07aa1bf39. Not for game execution.
local ComponentContainer = import("ComponentContainer.lua").ComponentContainer
ALazyComponentContainer = Class(ComponentContainer)({
  GetComponent = function(self, name)
    local component = ComponentContainer.GetComponent(self, name)
    if component == nil then
      component = self:CreateComponent(name)
      self:AddComponent(name, component)
    end
    return component
  end,
  CreateComponent = function(self, name)
    error("'ALazyComponentContainer.CreateComponent' Must be implemented!!")
  end
})
