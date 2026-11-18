-- Generated research-only output. Original SHA256: 9fafc83cd9684d96dff96756304125c6691cb36ffba8597412c6c895f86ca196. Not for game execution.
local Group = ReUI.UI.Controls.Group
OptionControl = ReUI.Core.Class(Group)({
  __init = function(self, parent, option)
    Group.__init(self, parent)
    self._option = option
    self._option.OnChanged:Add({
      self,
      self.ValueChanged
    })
  end,
  Option = ReUI.Core.Property({
    get = function(self)
      return self._option
    end
  }),
  ValueChanged = function(self, option, value)
  end,
  Destroy = function(self)
    self._option.OnChanged:Remove({
      self,
      self.ValueChanged
    })
    self._option = nil
    Group.Destroy(self)
  end
})
