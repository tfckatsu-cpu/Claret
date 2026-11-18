-- Generated research-only output. Original SHA256: 713f670772c6a32bb288d835bd6fbb6e47cb1e90c1c555673754fba993e420f7. Not for game execution.
local math = math
local table = table
local TableSort = table.sort
local TableInsert = table.insert
local GetSelectedUnits = GetSelectedUnits
local BaseGridPanel = ReUI.UI.Views.Grid.BaseGridPanel
local BaseGridItem = ReUI.UI.Views.Grid.BaseGridItem
ActionsGridItem = ReUI.Core.Class(BaseGridItem)({
  __init = function(self, parent)
    BaseGridItem.__init(self, parent)
    self._grid = parent
  end,
  UpdatePanel = function(self)
    ForkThread(self._grid.Refresh, self._grid)
  end,
  OnDestroy = function(self)
    self._grid = nil
    BaseGridItem.OnDestroy(self)
  end
})
ActionsGrid = ReUI.Core.Class(BaseGridPanel)({
  ItemClass = ActionsGridItem,
  __init = function(self, parent)
    BaseGridPanel.__init(self, parent)
    self._extensions = {}
    self._currentTop = 1
    self._maxRows = 1
    self._border = ReUI.UI.Views.WindowFrame(self)
    self._rowCountText = ReUI.UI.Controls.Text(self)
  end,
  Extensions = ReUI.Core.Property({
    get = function(self)
      return self._extensions
    end
  }),
  InitLayout = function(self, layouter)
    BaseGridPanel.InitLayout(self, layouter)
    layouter(self._border):FillFixedBorder(self, -10):Under(self):DisableHitTest(true)
    layouter(self._rowCountText):Above(self, 5):DropShadow(true)
    self._rowCountText:SetFont("Arial", 12)
  end,
  LoadExtensions = function(self, extensions)
    self._selectionHandlers = {}
    self._componentClasses = {}
    local order = {}
    local i = 0
    for name, info in pairs(extensions) do
      if info.enabled then
        local handler = info.class(self)
        self._selectionHandlers[name] = handler
        order[name] = i
        self._componentClasses[name] = handler.ComponentClass
      end
      i = i + 1
    end
    
    function self._sorter(a, b)
      local oa = order[a.handler]
      local ob = order[b.handler]
      if oa == ob then
        return a.id < b.id
      end
      return oa < ob
    end
    
    self._extensions = extensions
  end,
  ReloadExtensions = function(self)
    self:LoadExtensions(self._extensions)
    local componentClasses = self:GetItemComponentClasses()
    self:IterateItemsVertically(function(grid, item, row, column)
      item.ComponentClasses = componentClasses
    end)
  end,
  GetActions = function(self, selection)
    local actions = {}
    for name, handler in pairs(self._selectionHandlers) do
      local _actions, _context = handler:Update(selection)
      if not _actions then
      else
        for i, action in _actions, nil do
          TableInsert(actions, {
            handler = name,
            action = action,
            context = _context,
            id = i
          })
        end
      end
    end
    TableSort(actions, self._sorter)
    return actions
  end,
  OnSelectionChanged = function(self, selection)
    local actions = self:GetActions(selection)
    if table.empty(actions) then
      self:DisableItems()
      self:Hide()
      return
    end
    self:Show()
    local numberActions = table.getn(actions)
    self._maxRows = math.ceil(numberActions / self.Columns)
    local maxTop = math.max(1, self._maxRows - self.Rows + 1)
    local currentTop = math.min(self._currentTop, maxTop)
    self._rowCountText:SetText(("%d / %d"):format(currentTop, maxTop))
    local index = (currentTop - 1) * self.Columns + 1
    self:IterateItemsVertically(function(grid, item, row, column)
      local actionInfo = actions[index]
      if actionInfo == nil then
        item:Disable()
        return
      end
      item:EnableComponent(actionInfo.handler, actionInfo.action, actionInfo.context)
      index = index + 1
    end)
  end,
  PositionItem = function(self, item, row, column)
    BaseGridPanel.PositionItem(self, item, row, column)
    local layouter = self.Layouter
    layouter(item):Width(layouter:ScaleVar(self._columnWidth)):Height(layouter:ScaleVar(self._rowHeight))
  end,
  OnResized = function(self)
    self:DestroyHandlers()
    self:ReloadExtensions()
    self:Refresh()
  end,
  DestroyHandlers = function(self)
    if not self._selectionHandlers then
      return
    end
    for name, handler in self._selectionHandlers, nil do
      handler:Destroy()
    end
    self._selectionHandlers = nil
  end,
  Refresh = function(self)
    self:OnSelectionChanged(GetSelectedUnits())
  end,
  GetItemComponentClasses = function(self)
    return self._componentClasses
  end,
  OnScroll = function(self, delta)
    local newTop = math.max(1, math.min(self._maxRows - self.Rows + 1, self._currentTop + delta))
    if newTop ~= self._currentTop then
      self._currentTop = newTop
      self:Refresh()
    end
  end,
  HandleEvent = function(self, event)
    if event.Type == "WheelRotation" then
      self:OnScroll(event.WheelRotation > 0 and -1 or 1)
      return true
    end
    return false
  end,
  OnDestroy = function(self)
    self:DestroyHandlers()
    self._sorter = nil
    self._border = nil
    self._rowCountText = nil
    BaseGridPanel.OnDestroy(self)
  end
})
