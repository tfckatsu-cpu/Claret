-- Generated research-only output. Original SHA256: 07b6e67a89e4f45bd0c01cf69e1fbed373e1c4eb80779b572dc3d59114af5668. Not for game execution.
local AItemComponent = ReUI.UI.Views.Grid.Abstract.AItemComponent
local ASelectionHandler = ReUI.UI.Views.Grid.Abstract.ASelectionHandler
local ExampleContext = ReUI.Core.Class()({})
ExampleHandler = ReUI.Core.Class(ASelectionHandler)({
  Name = "ExampleHandler",
  OnInit = function(self)
    self._context = ExampleContext()
  end,
  Update = function(self, context)
  end,
  OnDestroy = function(self)
  end,
  ComponentClass = ReUI.Core.Class(AItemComponent)({
    Create = function(self, item)
    end,
    HandleEvent = function(self, item, event)
    end,
    OnFrame = function(self, item, delta)
    end,
    Enable = function(self, item, action, context)
    end,
    Disable = function(self, item)
    end,
    Destroy = function(self)
    end
  })
})
