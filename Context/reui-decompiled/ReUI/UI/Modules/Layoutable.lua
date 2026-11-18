-- Generated research-only output. Original SHA256: 0fcb754c83de52658f2aac71f5e5307e942845b907e5b409f85d9127751a6e7b. Not for game execution.
local Layouter = import("Layouter.lua").FloorLayoutFor
BaseLayout = Class()({
  __call = function(self, control, layouter)
    self:Apply(control, layouter)
  end,
  Apply = function(self, control, layouter)
    control:InitLayout(layouter or control.Layouter)
  end,
  Restore = function(self, control)
  end
})
local baseLayoutInstance = BaseLayout()
local SimpleLayout = ReUI.Core.Class(BaseLayout)({
  __init = function(self, layoutF)
    self._layout = layoutF
  end,
  Apply = function(self, control, layouter)
    self._clear = self._layout(control, layouter or control.Layouter)
  end,
  Restore = function(self, control)
    if self._clear then
      self._clear(control, control.Layouter)
    end
  end
})
Layoutable = ClassSimple({
  InitLayouter = function(self, parent)
    self.Layouter = parent.Layouter
  end,
  Layout = ReUI.Core.Property({
    set = function(self, layout)
      if type(layout) == "function" then
        layout = SimpleLayout(layout)
      end
      self.Layout:Restore(self)
      self._layout = layout or baseLayoutInstance
      self._layout:Apply(self)
    end,
    get = function(self)
      return self._layout or baseLayoutInstance
    end
  }),
  Layouter = ReUI.Core.Property({
    get = function(self)
      return self._layouter or Layouter
    end,
    set = function(self, value)
      self._layouter = value
    end
  }),
  AutoLayout = true,
  __post_init = function(self)
    if self.AutoLayout then
      self:Layout()
    end
  end,
  InitLayout = function(self, layouter)
  end
})
