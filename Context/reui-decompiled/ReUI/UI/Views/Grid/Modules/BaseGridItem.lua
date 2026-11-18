-- Generated research-only output. Original SHA256: 88d7eb893fa6e5366bcd7556ceb7cd1562adf14c044c4c946cc552387e1900bc. Not for game execution.
local AGridItem = import("AGridItem.lua").AGridItem
BaseGridItem = ReUI.Core.Class(AGridItem)({
  __init = function(self, parent)
    AGridItem.__init(self, parent)
    self._componentClasses = {}
  end,
  ComponentClasses = ReUI.Core.Property({
    get = function(self)
      return self._componentClasses
    end,
    set = function(self, value)
      self._componentClasses = value
    end
  }),
  CreateComponent = function(self, name)
    local class = self._componentClasses[name]
    if class == nil then
      error(("There is no class for component '%s'"):format(name))
    end
    return class(self)
  end,
  OnDestroy = function(self)
    self._componentClasses = nil
    AGridItem.OnDestroy(self)
  end
})
