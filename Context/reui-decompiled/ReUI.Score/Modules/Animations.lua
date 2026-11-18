-- Generated research-only output. Original SHA256: b361ad76a66f36929140d687fdedab73de1c81f3d3400e4df0ab0e4eb270f6b0. Not for game execution.
contractAnimation = ReUI.UI.Animation.Factory.Base:OnStart(function(control, state, speed, offset)
  PlaySound(Sound({
    Cue = "UI_Score_Window_Close",
    Bank = "Interface"
  }))
  return {
    speed = control.Layouter:ScaleNumber(speed),
    offset = offset
  }
end):OnFrame(function(control, delta, state)
  return control.Left() > GetFrame(0).Right() + control.Layouter:ScaleNumber(state.offset) or control.Right:Set(control.Right() + delta * state.speed)
end):OnFinish(function(control, state)
  local width = control.Width()
  control.Layouter(control):Right(function()
    return GetFrame(0).Right() + width + control.Layouter:ScaleNumber(state.offset)
  end)
end):Create()
expandAnimation = ReUI.UI.Animation.Factory.Base:OnStart(function(control, state, speed, offset)
  PlaySound(Sound({
    Cue = "UI_Score_Window_Open",
    Bank = "Interface"
  }))
  return {
    speed = control.Layouter:ScaleNumber(speed),
    offset = offset
  }
end):OnFrame(function(control, delta, state)
  return control.Right() < GetFrame(0).Right() - control.Layouter:ScaleNumber(state.offset) or control.Right:Set(control.Right() - delta * state.speed)
end):OnFinish(function(control, state)
  control.Layouter(control):AtRightIn(GetFrame(0), state.offset)
end):Create()
slideAnimation = ReUI.UI.Animation.Factory.Base:OnStart(function(control, state, speed, offset)
  local width = control.Width()
  control.Layouter(control):Right(function()
    return GetFrame(0).Right() + width + control.Layouter:ScaleNumber(offset)
  end)
  return {
    speed = control.Layouter:ScaleNumber(speed),
    offset = offset
  }
end):OnFrame(function(control, delta, state)
  return control.Right() < GetFrame(0).Right() - control.Layouter:ScaleNumber(state.offset) or control.Right:Set(control.Right() - delta * state.speed)
end):OnFinish(function(control, state)
  control.Layouter(control):AtRightIn(GetFrame(0), state.offset)
end):Create()
