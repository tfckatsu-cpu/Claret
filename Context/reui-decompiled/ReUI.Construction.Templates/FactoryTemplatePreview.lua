-- Generated research-only output. Original SHA256: 6e0cc367a3c9596c39cfe0e6881599ec88158b598d351e2597234d569557e5b0. Not for game execution.
local Bitmap = ReUI.UI.Controls.Bitmap
local Text = ReUI.UI.Controls.Text
local CheckBox = ReUI.UI.Controls.CheckBox
local Group = ReUI.UI.Controls.Group
local BaseGridPanel = ReUI.UI.Views.Grid.BaseGridPanel
local MAX_COLUMNS = 10
local UIUtil = import("/lua/ui/uiutil.lua")
local Icon = ReUI.Core.Class(Bitmap)({
  __init = function(self, parent)
    Bitmap.__init(self, parent)
    self.count = Text(self)
    self.count:SetFont("Arial", 20)
  end,
  InitLayout = function(self, layouter)
    layouter(self.count):Color("ffff00"):DropShadow(true):AtRightBottomIn(self, 1, 1):DisableHitTest()
  end,
  Set = function(self, data)
    self:SetTexture(UIUtil.SkinnableFile("/icons/units/" .. data.id .. "_icon.dds"))
    self.count:SetText(data.count)
  end
})
FactoryTemplatePreview = ReUI.Core.Class(BaseGridPanel)({
  ItemClass = Icon,
  __init = function(self, parent)
    BaseGridPanel.__init(self, parent)
    self._title = Text(self)
    self._title:SetFont("Arial", 16)
    self.Rows = 1
    self.Columns = 1
    self.ColumnWidth = 48
    self.RowHeight = 48
    self.HorizontalSpacing = 2
    self.VerticalSpacing = 2
  end,
  PositionItem = function(self, item, row, column)
    BaseGridPanel.PositionItem(self, item, row, column)
    local layouter = self.Layouter
    layouter(item):Width(layouter:ScaleVar(self._columnWidth)):Height(layouter:ScaleVar(self._rowHeight)):DisableHitTest()
  end,
  InitLayout = function(self, layouter)
    BaseGridPanel.InitLayout(self, layouter)
    layouter(self._title):Above(self, 2):Color(UIUtil.factionTextColor):DropShadow(true):DisableHitTest()
    layouter(self):Depth(1000):DisableHitTest(true)
  end,
  DisplayTemplate = function(self, template)
    self._title:SetText(template.name)
    local data = template.templateData
    local count = table.getn(data)
    local columns = math.min(count, MAX_COLUMNS)
    local rows = math.ceil(count / columns)
    self.Rows = rows
    self.Columns = columns
    local i = 1
    self:IterateItemsVertically(function(grid, item, row, column)
      local itemData = data[i]
      if itemData then
        item:Show()
        item:Set(itemData)
      else
        item:Hide()
      end
      i = i + 1
    end)
  end
})
