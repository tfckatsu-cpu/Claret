-- Generated research-only output. Original SHA256: 7c6fae0f402a5a640edde4e274a623993dfd7ffd239ce3ab8836569a6c6a6778. Not for game execution.
local BaseGridItem = import("BaseGridItem.lua").BaseGridItem
local Grid = import("Grid.lua").Grid
BaseGridPanel = ReUI.Core.Class(Grid)({
  ItemClass = BaseGridItem,
  CreateItem = function(self, row, column)
    return self.ItemClass(self)
  end,
  CreateItems = function(self, rows, columns)
    Grid.CreateItems(self, rows, columns)
    local componentClasses = self:GetItemComponentClasses()
    self:IterateItemsVertically(function(grid, item, row, column)
      item.ComponentClasses = componentClasses
    end)
  end,
  AddItemComponent = function(self, name, class)
    self:IterateItemsVertically(function(grid, item, row, column)
      item:AddComponent(name, class(item))
    end)
  end,
  DisableItems = function(self)
    self:IterateItemsVertically(function(grid, item, row, column)
      item:Disable()
    end)
  end,
  OnResized = function(self)
    self:DisableItems()
  end,
  Refresh = function(self)
  end,
  GetItemComponentClasses = function(self)
    return {}
  end
})
