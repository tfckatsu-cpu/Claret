-- Generated research-only output. Original SHA256: 2c3403dd076e96acfc93bdfa9e666a6a66c72ba08b08954d4017e8b3e5883bf8. Not for game execution.
local MathFloor = math.floor
local Bitmap = ReUI.UI.Controls.Bitmap
local LF = ReUI.UI.LayoutFunctions
local LazyVar = import("/lua/lazyvar.lua").Create

local function OffsetFn(layouter, n, size, space)
  return LF.Sum(LF.Mult(n, layouter:ScaleVar(size)), LF.Mult(n, layouter:ScaleVar(space)))
end

local function SizeFn(layouter, n, size, space)
  return LF.Sum(LF.Mult(n, layouter:ScaleVar(size)), LF.Mult(LF.Diff(n, 1), layouter:ScaleVar(space)))
end

Grid = ReUI.Core.Class(Bitmap)({
  AutoWidth = true,
  AutoHeight = true,
  __init = function(self, parent)
    Bitmap.__init(self, parent)
    self._verticalSpacing = LazyVar(0)
    self._horizontalSpacing = LazyVar(0)
    self._columnWidth = LazyVar(1)
    self._rowHeight = LazyVar(1)
    self._prevRows = 0
    self._prevColumns = 0
    self._rows = LazyVar(1)
    self._columns = LazyVar(1)
    self._suppressResize = true
    
    function self._resizeFn()
      if self._suppressResize then
        return
      end
      self:Resize()
    end
    
    self._rows.OnDirty = self._resizeFn
    self._columns.OnDirty = self._resizeFn
  end,
  Rows = ReUI.Core.Property({
    get = function(self)
      return self._prevRows
    end,
    set = function(self, value)
      self._rows:Set(value)
    end
  }),
  Columns = ReUI.Core.Property({
    get = function(self)
      return self._prevColumns
    end,
    set = function(self, value)
      self._columns:Set(value)
    end
  }),
  ColumnWidth = ReUI.Core.Property({
    get = function(self)
      return self._columnWidth()
    end,
    set = function(self, value)
      self._columnWidth:Set(value)
    end
  }),
  RowHeight = ReUI.Core.Property({
    get = function(self)
      return self._rowHeight()
    end,
    set = function(self, value)
      self._rowHeight:Set(value)
    end
  }),
  HorizontalSpacing = ReUI.Core.Property({
    get = function(self)
      return self._horizontalSpacing()
    end,
    set = function(self, value)
      self._horizontalSpacing:Set(value)
    end
  }),
  VerticalSpacing = ReUI.Core.Property({
    get = function(self)
      return self._verticalSpacing()
    end,
    set = function(self, value)
      self._verticalSpacing:Set(value)
    end
  }),
  InitLayout = function(self, layouter)
    self._suppressResize = true
    self:InitSize(layouter)
    layouter(self):Color("22ffffff")
    self:Resize()
    self._suppressResize = false
  end,
  InitSize = function(self, layouter)
    if self.AutoWidth then
      self.Width.OnDirty = nil
      layouter(self):Width(SizeFn(layouter, self._columns, self._columnWidth, self._horizontalSpacing))
    else
      self.Width.OnDirty = self._resizeFn
    end
    if self.AutoHeight then
      self.Height.OnDirty = nil
      layouter(self):Height(SizeFn(layouter, self._rows, self._rowHeight, self._verticalSpacing))
    else
      self.Height.OnDirty = self._resizeFn
    end
  end,
  ComputeRows = function(self)
    if self.AutoHeight then
      return self._rows()
    end
    local layouter = self.Layouter
    local space = layouter:ScaleNumber(self.VerticalSpacing)
    local rowHeight = layouter:ScaleNumber(self.RowHeight)
    return MathFloor((self.Height() + space) / (rowHeight + space))
  end,
  ComputeColumns = function(self)
    if self.AutoWidth then
      return self._columns()
    end
    local layouter = self.Layouter
    local space = layouter:ScaleNumber(self.HorizontalSpacing)
    local columnWidth = layouter:ScaleNumber(self.ColumnWidth)
    return MathFloor((self.Width() + space) / (columnWidth + space))
  end,
  Resize = function(self)
    local rows = self:ComputeRows()
    local columns = self:ComputeColumns()
    if self._prevRows ~= rows or self._prevColumns ~= columns then
      self:ClearGrid()
      self:CreateItems(rows, columns)
    end
    self:LayoutItems()
    self:OnResized()
  end,
  CreateItem = function(self, row, column)
    error("Grid.CreateItem not implemented")
  end,
  CreateItems = function(self, rows, columns)
    self._prevRows = rows
    self._prevColumns = columns
    self._items = {}
    for x = 1, rows do
      self._items[x] = {}
      for y = 1, columns do
        self._items[x][y] = self:CreateItem(x, y)
      end
    end
  end,
  LayoutItems = function(self)
    self:IterateItemsVertically(self.PositionItem)
  end,
  PositionItem = function(self, item, row, column)
    local layouter = self.Layouter
    layouter(item):AtLeftIn(self, OffsetFn(layouter, column - 1, self._columnWidth, self._horizontalSpacing)):AtTopIn(self, OffsetFn(layouter, row - 1, self._rowHeight, self._verticalSpacing))
  end,
  IterateItemsVertically = function(self, func)
    local items = self:GetItems()
    local ncolumns = self.Columns
    local nrows = self.Rows
    for ix = 1, nrows do
      for iy = 1, ncolumns do
        func(self, items[ix][iy], ix, iy)
      end
    end
  end,
  IterateItemsHorizontally = function(self, func)
    local items = self:GetItems()
    local ncolumns = self.Columns
    local nrows = self.Rows
    for iy = 1, ncolumns do
      for ix = 1, nrows do
        func(self, items[ix][iy], ix, iy)
      end
    end
  end,
  OnResized = function(self)
  end,
  ClearGrid = function(self)
    if not self._items then
      return
    end
    self:IterateItemsVertically(function(grid, item, row, column)
      item:Destroy()
    end)
    self._prevRows = 0
    self._prevColumns = 0
    self._items = nil
  end,
  GetItems = function(self)
    return self._items
  end,
  GetItem = function(self, row, column)
    return self:GetItems()[row][column]
  end,
  OnDestroy = function(self)
    self:ClearGrid()
    self._verticalSpacing:Destroy()
    self._verticalSpacing = nil
    self._horizontalSpacing:Destroy()
    self._horizontalSpacing = nil
    self._columnWidth:Destroy()
    self._columnWidth = nil
    self._rowHeight:Destroy()
    self._rowHeight = nil
    self._rows:Destroy()
    self._rows = nil
    self._columns:Destroy()
    self._columns = nil
    Bitmap.OnDestroy(self)
  end
})
