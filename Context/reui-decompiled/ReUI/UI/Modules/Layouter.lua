-- Generated research-only output. Original SHA256: 8f30fca56234197c2116f12a809363acb7ce8cf0db26af0c173d2baa022a5911. Not for game execution.
local LazyVar = import("/lua/lazyvar.lua").Create
local LayoutHelpers = import("/lua/maui/layouthelpers.lua")
local Functions = import("LayoutFunctions.lua")
local defaultScale = LayoutHelpers.GetPixelScaleFactor()
Layouter = ReUI.Core.Class()({
  __init = function(self, scale)
    self.c = false
    if scale == nil then
      self._scale = false
    else
      self._scale = LazyVar(0)
      self._scale:Set(scale)
    end
  end,
  Scale = ReUI.Core.Property({
    get = function(self)
      return self._scale or defaultScale
    end,
    set = function(self, value)
      assert(type(self._scale) == "table", "No scale LazyVar provided during contruction!")
      self._scale:Set(value)
    end
  }),
  __call = function(self, control)
    self.c = control or false
    return self
  end,
  PerformLayout = function(self, useLayouter)
    local control = self.c
    local layout = control.Layout
    assert(layout, "Attempt to perform layout on Control with no Layout")
    if useLayouter then
      layout(control, self)
    else
      layout(control)
    end
    self.c = control
    return self
  end,
  AtCenterOffset = function(self, base, baseLen, len, offset)
    return Functions.AtCenterOffset(base, baseLen, len, offset, self.Scale)
  end,
  ScaleVar = function(self, value)
    return Functions.Mult(value, self.Scale)
  end,
  ScaleNumber = function(self, value)
    local scale = self.Scale
    if iscallable(scale) then
      return scale() * value
    end
    return scale * value
  end,
  Sum = function(self, n1, n2)
    return Functions.Sum(n1, n2, self.Scale)
  end,
  Diff = function(self, n1, n2)
    return Functions.Diff(n1, n2, self.Scale)
  end,
  Max = function(self, n1, n2)
    return Functions.Max(n1, n2, self.Scale)
  end,
  Min = function(self, n1, n2)
    return Functions.Min(n1, n2, self.Scale)
  end,
  _ScaleValue = function(self, value)
    if iscallable(value) then
      return value
    else
      return self:ScaleVar(value)
    end
  end,
  Left = function(self, left)
    local control = self.c
    control.Left:Set(left)
    self.c = control
    return self
  end,
  Right = function(self, right)
    local control = self.c
    control.Right:Set(right)
    self.c = control
    return self
  end,
  Top = function(self, top)
    local control = self.c
    control.Top:Set(top)
    self.c = control
    return self
  end,
  Bottom = function(self, bottom)
    local control = self.c
    control.Bottom:Set(bottom)
    self.c = control
    return self
  end,
  Width = function(self, width)
    local control = self.c
    control.Width:Set(self:_ScaleValue(width))
    self.c = control
    return self
  end,
  Height = function(self, height)
    local control = self.c
    control.Height:Set(self:_ScaleValue(height))
    self.c = control
    return self
  end,
  Depth = function(self, depth)
    local control = self.c
    control.Depth:Set(depth)
    self.c = control
    return self
  end,
  Over = function(self, parent, depth)
    return self:Depth(Functions.Sum(parent.Depth, depth or 1))
  end,
  Under = function(self, parent, depth)
    return self:Depth(Functions.Diff(parent.Depth, depth or 1))
  end,
  AtLeftIn = function(self, parent, leftOffset)
    return self:Left(self:Sum(parent.Left, leftOffset or 0))
  end,
  AtTopIn = function(self, parent, topOffset)
    return self:Top(self:Sum(parent.Top, topOffset or 0))
  end,
  AtRightIn = function(self, parent, rightOffset)
    return self:Right(self:Diff(parent.Right, rightOffset or 0))
  end,
  AtBottomIn = function(self, parent, bottomOffset)
    return self:Bottom(self:Diff(parent.Bottom, bottomOffset or 0))
  end,
  AnchorToLeft = function(self, parent, padding)
    return self:Right(self:Diff(parent.Left, padding or 0))
  end,
  AnchorToTop = function(self, parent, padding)
    return self:Bottom(self:Diff(parent.Top, padding or 0))
  end,
  AnchorToRight = function(self, parent, padding)
    return self:Left(self:Sum(parent.Right, padding or 0))
  end,
  AnchorToBottom = function(self, parent, padding)
    return self:Top(self:Sum(parent.Bottom, padding or 0))
  end,
  FillHorizontally = function(self, parent)
    return self:AtLeftIn(parent):AtRightIn(parent)
  end,
  FillVertically = function(self, parent)
    return self:AtTopIn(parent):AtBottomIn(parent)
  end,
  Fill = function(self, parent)
    return self:FillHorizontally(parent):FillVertically(parent)
  end,
  AtLeftTopIn = function(self, parent, left, top)
    return self:AtLeftIn(parent, left):AtTopIn(parent, top)
  end,
  AtRightTopIn = function(self, parent, right, top)
    return self:AtRightIn(parent, right):AtTopIn(parent, top)
  end,
  AtRightBottomIn = function(self, parent, right, bottom)
    return self:AtRightIn(parent, right):AtBottomIn(parent, bottom)
  end,
  AtLeftBottomIn = function(self, parent, left, bottom)
    return self:AtLeftIn(parent, left):AtBottomIn(parent, bottom)
  end,
  OffsetIn = function(self, parent, left, top, right, bottom)
    return self:AtLeftTopIn(parent, left, top):AtRightBottomIn(parent, right, bottom)
  end,
  FillFixedBorder = function(self, parent, offset)
    return self:OffsetIn(parent, offset, offset, offset, offset)
  end,
  AtVerticalCenterIn = function(self, parent, topOffset)
    return self:Top(self:AtCenterOffset(parent.Top, parent.Height, self.c.Height, topOffset or 0))
  end,
  AtHorizontalCenterIn = function(self, parent, leftOffset)
    return self:Left(self:AtCenterOffset(parent.Left, parent.Width, self.c.Width, leftOffset or 0))
  end,
  AtCenterIn = function(self, parent, top, left)
    return self:AtHorizontalCenterIn(parent, left):AtVerticalCenterIn(parent, top)
  end,
  LeftOf = function(self, parent, padding)
    return self:AnchorToLeft(parent, padding):AtTopIn(parent)
  end,
  RightOf = function(self, parent, padding)
    return self:AnchorToRight(parent, padding):AtTopIn(parent)
  end,
  Above = function(self, parent, padding)
    return self:AtLeftIn(parent):AnchorToTop(parent, padding)
  end,
  Below = function(self, parent, padding)
    return self:AtLeftIn(parent):AnchorToBottom(parent, padding)
  end,
  AtLeftCenterIn = function(self, parent, leftOffset, topOffset)
    return self:AtLeftIn(parent, leftOffset):AtVerticalCenterIn(parent, topOffset)
  end,
  AtTopCenterIn = function(self, parent, topOffset, leftOffset)
    return self:AtTopIn(parent, topOffset):AtHorizontalCenterIn(parent, leftOffset)
  end,
  AtRightCenterIn = function(self, parent, rightOffset, topOffset)
    return self:AtRightIn(parent, rightOffset):AtVerticalCenterIn(parent, topOffset)
  end,
  AtBottomCenterIn = function(self, parent, bottomOffset, leftOffset)
    return self:AtBottomIn(parent, bottomOffset):AtHorizontalCenterIn(parent, leftOffset)
  end,
  ResetLeft = function(self)
    return self:Left(Functions.Diff(self.c.Right, self.c.Width))
  end,
  ResetTop = function(self)
    return self:Top(Functions.Diff(self.c.Bottom, self.c.Height))
  end,
  ResetRight = function(self)
    return self:Right(Functions.Sum(self.c.Left, self.c.Width))
  end,
  ResetBottom = function(self)
    return self:Bottom(Functions.Sum(self.c.Top, self.c.Height))
  end,
  ResetWidth = function(self)
    return self:Width(Functions.Diff(self.c.Right, self.c.Left))
  end,
  ResetHeight = function(self)
    return self:Height(Functions.Diff(self.c.Bottom, self.c.Top))
  end,
  ResetLayout = function(self)
    return self:ResetTop():ResetLeft():ResetRight():ResetBottom():ResetWidth():ResetHeight()
  end,
  ResetPosition = function(self)
    return self:ResetTop():ResetLeft():ResetRight():ResetBottom()
  end,
  NoScale = function(self, callback)
    local scale = self._scale
    self._scale = 1
    callback(self)
    self._scale = scale
    return self
  end,
  DefaultScale = function(self, callback)
    local scale = self._scale
    self._scale = false
    callback(self)
    self._scale = scale
    return self
  end,
  Color = function(self, color)
    local control = self.c
    if type(color) == "string" and string.len(color) == 6 then
      color = "ff" .. color
    end
    if control.SetSolidColor then
      control:SetSolidColor(color)
    elseif control.SetColor then
      control:SetColor(color)
    else
      error("Unable to set color for control")
    end
    self.c = control
    return self
  end,
  DropShadow = function(self, state)
    self.c:SetDropShadow(state)
    return self
  end,
  Texture = function(self, texture, border)
    self.c:SetTexture(texture, border)
    return self
  end,
  EnableHitTest = function(self, recursive)
    self.c:EnableHitTest(recursive)
    return self
  end,
  DisableHitTest = function(self, recursive)
    self.c:DisableHitTest(recursive)
    return self
  end,
  NeedsFrameUpdate = function(self, state)
    self.c:SetNeedsFrameUpdate(state)
    return self
  end,
  Alpha = function(self, alpha, applyToChildren)
    self.c:SetAlpha(alpha, applyToChildren)
    return self
  end,
  Disable = function(self)
    self.c:Disable()
    return self
  end,
  Hide = function(self)
    self.c:Hide()
    return self
  end
})
local FuncFloor = Functions.Floor
FloorLayouter = ReUI.Core.Class(Layouter)({
  AtCenterOffset = function(self, base, baseLen, len, offset)
    return FuncFloor(Layouter.AtCenterOffset(self, base, baseLen, len, offset))
  end,
  ScaleVar = function(self, value)
    return FuncFloor(Layouter.ScaleVar(self, value))
  end,
  ScaleNumber = function(self, value)
    return FuncFloor(Layouter.ScaleNumber(self, value))
  end,
  Sum = function(self, n1, n2)
    return FuncFloor(Layouter.Sum(self, n1, n2))
  end,
  Diff = function(self, n1, n2)
    return FuncFloor(Layouter.Diff(self, n1, n2))
  end,
  Max = function(self, n1, n2)
    return FuncFloor(Layouter.Max(self, n1, n2))
  end,
  Min = function(self, n1, n2)
    return FuncFloor(Layouter.Min(self, n1, n2))
  end
})
local FuncRound = Functions.Round
RoundLayouter = ReUI.Core.Class(Layouter)({
  AtCenterOffset = function(self, base, baseLen, len, offset)
    return FuncRound(Layouter.AtCenterOffset(self, base, baseLen, len, offset))
  end,
  ScaleVar = function(self, value)
    return FuncRound(Layouter.ScaleVar(self, value))
  end,
  ScaleNumber = function(self, value)
    return FuncRound(Layouter.ScaleNumber(self, value))
  end,
  Sum = function(self, n1, n2)
    return FuncRound(Layouter.Sum(self, n1, n2))
  end,
  Diff = function(self, n1, n2)
    return FuncRound(Layouter.Diff(self, n1, n2))
  end,
  Max = function(self, n1, n2)
    return FuncRound(Layouter.Max(self, n1, n2))
  end,
  Min = function(self, n1, n2)
    return FuncRound(Layouter.Min(self, n1, n2))
  end
})
FloorLayoutFor = FloorLayouter()
RoundLayoutFor = RoundLayouter()
