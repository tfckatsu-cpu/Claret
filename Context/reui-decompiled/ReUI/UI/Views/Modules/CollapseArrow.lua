-- Generated research-only output. Original SHA256: b88074e5bcdbe19cab4d4752b4d61ab77fb014b566a64f06cb7d0bfe2feb54fb. Not for game execution.
local Checkbox = ReUI.UI.Controls.CheckBox
local UIUtil = import("/lua/ui/uiutil.lua")
VerticalCollapseArrow = ReUI.Core.Class(Checkbox)({
  __init = function(self, parent)
    Checkbox.__init(self, parent)
    self:SetNewTextures(UIUtil.SkinnableFile("/game/tab-r-btn/tab-close_btn_up.dds"), UIUtil.SkinnableFile("/game/tab-r-btn/tab-open_btn_up.dds"), UIUtil.SkinnableFile("/game/tab-r-btn/tab-close_btn_over.dds"), UIUtil.SkinnableFile("/game/tab-r-btn/tab-open_btn_over.dds"), UIUtil.SkinnableFile("/game/tab-r-btn/tab-close_btn_dis.dds"), UIUtil.SkinnableFile("/game/tab-r-btn/tab-open_btn_dis.dds"))
  end
})
HorizontalCollapseArrow = ReUI.Core.Class(Checkbox)({
  __init = function(self, parent)
    Checkbox.__init(self, parent)
    self:SetNewTextures(UIUtil.SkinnableFile("/game/tab-t-btn/tab-close_btn_up.dds"), UIUtil.SkinnableFile("/game/tab-t-btn/tab-open_btn_up.dds"), UIUtil.SkinnableFile("/game/tab-t-btn/tab-close_btn_over.dds"), UIUtil.SkinnableFile("/game/tab-t-btn/tab-open_btn_over.dds"), UIUtil.SkinnableFile("/game/tab-t-btn/tab-close_btn_dis.dds"), UIUtil.SkinnableFile("/game/tab-t-btn/tab-open_btn_dis.dds"))
  end
})
