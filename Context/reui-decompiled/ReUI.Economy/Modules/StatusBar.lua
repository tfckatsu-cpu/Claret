-- Generated research-only output. Original SHA256: ce2c0ed01a36baa5b858caaa61784365f4ba3150d3a6c1fa2deaea58942daf65. Not for game execution.
local LazyVar = import("/lua/lazyvar.lua").Create
local Group = ReUI.UI.Controls.Group
local Bitmap = ReUI.UI.Controls.Bitmap
local Text = ReUI.UI.Controls.Text
StatusBar = ReUI.Core.Class(Bitmap)({
  __init = function(self, parent)
    Bitmap.__init(self, parent)
    self._min = LazyVar(0)
    self._max = LazyVar(1)
    self._value = LazyVar(0)
    self._bar = Bitmap(self)
  end,
  Percent = ReUI.Core.Property({
    get = function(self)
      local min = self._min()
      local max = self._max()
      local range = max - min
      if range == 0 then
        return 0
      end
      local value = self._value()
      return (value - min) / range
    end
  }),
  Value = ReUI.Core.Property({
    get = function(self)
      return self._value()
    end,
    set = function(self, value)
      self._value:Set(math.clamp(value, self._min(), self._max()))
    end
  }),
  Max = ReUI.Core.Property({
    get = function(self)
      return self._max()
    end,
    set = function(self, value)
      self._max:Set(value)
    end
  }),
  Min = ReUI.Core.Property({
    get = function(self)
      return self._min()
    end,
    set = function(self, value)
      self._min:Set(value)
    end
  }),
  BarColor = ReUI.Core.Property({
    set = function(self, color)
      self._bar:SetSolidColor(color)
    end
  }),
  InitLayout = function(self, layouter)
    layouter(self._bar):Left(self.Left):Top(self.Top):Bottom(self.Bottom):Width(function()
      return self.Percent * self.Width()
    end)
    layouter(self):Color("ff000000")
  end
})
