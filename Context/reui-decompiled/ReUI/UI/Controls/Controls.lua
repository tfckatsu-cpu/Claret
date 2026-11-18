-- Generated research-only output. Original SHA256: 38a68a4ecffb597309c0e24d5b14344f116c0ae18a89ce034b2a1a7d29eb7e29. Not for game execution.
Version = "1.0.0"
ReUI.Require({
  "ReUI.UI >= 1.0.0"
})

function Main(isReplay)
  local _Bitmap = import("/lua/maui/bitmap.lua").Bitmap
  local _Group = import("/lua/maui/group.lua").Group
  local _Text = import("/lua/maui/text.lua").Text
  local _Checkbox = import("/lua/maui/checkbox.lua").Checkbox
  local Bitmap = ReUI.Core.Class(_Bitmap, ReUI.UI.Layoutable)({
    OnInit = function(self)
      self:InitLayouter(self:GetParent())
      _Bitmap.OnInit(self)
    end,
    ResetLayout = function(self)
      self.Layouter(self):ResetPosition():Width(self.Layouter:ScaleVar(self.BitmapWidth)):Height(self.Layouter:ScaleVar(self.BitmapHeight))
    end
  })
  local Group = ReUI.Core.Class(_Group, ReUI.UI.Layoutable)({
    OnInit = function(self)
      self:InitLayouter(self:GetParent())
      _Group.OnInit(self)
    end
  })
  local Text
  Text = ReUI.Core.Class(_Text, ReUI.UI.Layoutable)({
    Create = function(parent, family, pointsize)
      local t = Text(parent)
      t:SetFont(family, pointsize)
      return t
    end,
    OnInit = function(self)
      self:InitLayouter(self:GetParent())
      _Text.OnInit(self)
    end,
    SetFont = function(self, family, pointsize)
      if self._font then
        self._lockFontChanges = true
        self._font._pointsize:Set(self.Layouter:ScaleVar(pointsize))
        self._font._family:Set(family)
        self._lockFontChanges = false
        self:_internalSetFont()
      end
    end
  })
  local CheckBox = ReUI.Core.Class(_Checkbox, ReUI.UI.Layoutable)({
    OnInit = Bitmap.OnInit,
    ResetLayout = Bitmap.ResetLayout
  })
  return {
    Group = Group,
    Bitmap = Bitmap,
    Text = Text,
    CheckBox = CheckBox
  }
end
