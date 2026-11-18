-- Generated research-only output. Original SHA256: be86ec74bc22a07c453ced54a2e6257604c3c58673726e332c3d4d090a348f00. Not for game execution.
local UIUtil = import("/lua/ui/uiutil.lua")
local LazyVar = import("/lua/lazyvar.lua").Create
local Group = ReUI.UI.Controls.Group
local Bitmap = ReUI.UI.Controls.Bitmap
FactionRightBracket = ReUI.Core.Class(Group)({
  __init = function(self, parent)
    Group.__init(self, parent)
    self.Layouter = ReUI.UI.Layouter(LazyVar(1))
    self.Layouter.Scale = parent.Layouter.Scale
    self.top = Bitmap(self, UIUtil.SkinnableFile("/game/bracket-right/bracket_bmp_t.dds"))
    self.middle = Bitmap(self, UIUtil.SkinnableFile("/game/bracket-right/bracket_bmp_m.dds"))
    self.bottom = Bitmap(self, UIUtil.SkinnableFile("/game/bracket-right/bracket_bmp_b.dds"))
  end,
  InitLayout = function(self, layouter)
    layouter(self.top):Right(self.Right):Top(self.Top):DisableHitTest()
    layouter(self.bottom):Right(self.Right):Bottom(self.Bottom):DisableHitTest()
    layouter(self.middle):AtRightIn(self, 7):Top(self.top.Bottom):Bottom(self.bottom.Top):DisableHitTest()
    layouter(self):Width(0):DisableHitTest()
  end
})
RightGlow = ReUI.Core.Class(Group)({
  __init = function(self, parent)
    Group.__init(self, parent)
    self.Layouter = ReUI.UI.Layouter(LazyVar(1))
    self.Layouter.Scale = parent.Layouter.Scale
    self.top = Bitmap(self, UIUtil.SkinnableFile("/game/bracket-right-energy/bracket_bmp_t.dds"))
    self.middle = Bitmap(self, UIUtil.SkinnableFile("/game/bracket-right-energy/bracket_bmp_m.dds"))
    self.bottom = Bitmap(self, UIUtil.SkinnableFile("/game/bracket-right-energy/bracket_bmp_b.dds"))
  end,
  InitLayout = function(self, layouter)
    layouter(self.top):Right(self.Right):Top(self.Top):DisableHitTest()
    layouter(self.bottom):Right(self.Right):Bottom(self.Bottom):DisableHitTest()
    layouter(self.middle):AtRightIn(self):Top(self.top.Bottom):Bottom(self.bottom.Top):DisableHitTest()
    layouter(self):Width(0):DisableHitTest()
  end
})
