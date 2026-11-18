-- Generated research-only output. Original SHA256: 1799507f30292f1c7141b4f3e7e080cef3220b06330ab2bc90af8041cadc8a8d. Not for game execution.
Version = "1.0.0"
ReUI.Require({
  "ReUI.Core >= 1.0.0",
  "ReUI.UI >= 1.4.0",
  "ReUI.ECS >= 1.0.0"
})

function Main(isReplay)
  local Group = ReUI.UI.Controls.Group
  local Bitmap = ReUI.UI.Controls.Bitmap
  local Text = ReUI.UI.Controls.Text
  local Widget = ReUI.Core.Class(Group, ReUI.ECS.ComponentContainer)({
    __init = function(self, parent, name)
      Group.__init(self, parent)
      self._name = name
    end,
    InitLayout = function(self, layouter)
    end,
    Name = ReUI.Core.Property({
      get = function(self)
        return self._name
      end,
      set = function(self, value)
      end
    })
  })
  return {Widget = Widget}
end
