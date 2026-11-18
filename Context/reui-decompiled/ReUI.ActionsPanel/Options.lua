-- Generated research-only output. Original SHA256: 85d7b4859f93823c35e997be84678ec038a9541e4d3645a5963dbbf82e715608. Not for game execution.
local Options = ReUI.Options.Builder
local Opt = ReUI.Options.Opt
ReUI.Options.Mods["ReUI.ActionsPanel"] = {
  rows = Opt(2),
  columns = Opt(8),
  itemSize = Opt(48),
  space = Opt(2)
}

function Main()
  local options = ReUI.Options.Mods["ReUI.ActionsPanel"]
  Options.AddOptions("ReUI.ActionsPanel", "ReUI.ActionsPanel", {
    Options.Slider("Rows", 1, 10, 1, options.rows, 4),
    Options.Slider("Columns", 1, 10, 1, options.columns, 4),
    Options.Slider("Size", 10, 64, 1, options.itemSize, 4),
    Options.Slider("Space", 0, 10, 1, options.space, 4)
  })
  Options.AddOptions("ReUI.ActionsPanel_Ext", "ReUI.ActionsPanel Extensions", function(parent)
    local panel = ReUI.UI.Global.ActionsGrid
    if IsDestroyed(panel) then
      return
    end
    local Prefs = import("/lua/user/prefs.lua")
    local Selector = import("Modules/Selector.lua").Selector
    local extensions = panel.Extensions
    local selector = Selector(parent)
    
    function selector:OnSelect(id, enabled)
      local activeExtensions = Prefs.GetFromCurrentProfile("ReUIActionsPanel_extensions") or {}
      extensions[id].enabled = enabled
      activeExtensions[id] = enabled
      Prefs.SetToCurrentProfile("ReUIActionsPanel_extensions", activeExtensions)
    end
    
    function selector:OnClose()
      if IsDestroyed(panel) then
        return
      end
      panel:Resize()
    end
    
    selector:SetData(extensions)
    selector:CalcVisible()
    return selector
  end)
end
