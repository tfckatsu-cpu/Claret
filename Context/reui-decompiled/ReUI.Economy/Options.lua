-- Generated research-only output. Original SHA256: ce96a2d677d6fa9073b9a9b511248194eed31e558c48aa14fad4cd0c3c54b953. Not for game execution.
local Opt = ReUI.Options.Opt
ReUI.Options.Mods["ReUI.Economy"] = {
  scale = Opt(100),
  style = Opt("default")
}

function Main(isReplay)
  local Options = ReUI.Options.Builder
  local options = ReUI.Options.Mods["ReUI.Economy"]
  Options.AddOptions("ReUI.Economy", "ReUI.Economy", {
    Options.Slider("Scale", 50, 300, 25, options.scale, 4),
    Options.Strings("Style", ReUI.LINQ.Enumerate(ReUI.Economy.Layouts, next):Keys():ToArray(), options.style, 4)
  })
end
