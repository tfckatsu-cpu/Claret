-- Generated research-only output. Original SHA256: 21c7f4c60e4c9c91048a0663299521c7167c6cb623933ae2f0aaf9ac8ef6a711. Not for game execution.
local LazyVar = import("/lua/lazyvar.lua").Create
ReactiveOption = ReUI.Core.Class()({
  OnChanged = ReUI.Core.Events.EventProperty(),
  OnSaved = ReUI.Core.Events.EventProperty(),
  Value = ReUI.Core.Property({
    get = function(self)
      return self:Get()
    end,
    set = function(self, value)
      self:Set(value)
    end
  }),
  IsChanged = ReUI.Core.Property({
    get = function(self)
      return self._prev ~= nil
    end
  }),
  Name = ReUI.Core.Property({
    get = function(self)
      return self._ref:GetPath(2)
    end
  }),
  __init = function(self, ref, default)
    self._ref = ref
    local val = self._ref:Get(default)
    self._var = LazyVar(val)
    self._prev = nil
  end,
  Raw = function(self)
    return self._var
  end,
  Get = function(self)
    return self._var()
  end,
  Prev = function(self)
    return self._prev
  end,
  Set = function(self, value)
    if self._prev == nil then
      self._prev = self:Get()
    end
    self._var:Set(value)
    self.OnChanged:Invoke(self, value)
  end,
  Restore = function(self)
    if self._prev ~= nil then
      self:Set(self._prev)
      self._prev = nil
    end
  end,
  Save = function(self)
    local value = self:Get()
    self._ref:Set(value)
    self.OnSaved:Invoke(self, value)
    self._prev = nil
  end,
  Destroy = function(self)
    self.OnChanged = nil
    self.OnSaved = nil
    self._prev = nil
    self._var:Destroy()
    self._var = nil
    self._ref = nil
  end
})
DeprecatedOption = ReUI.Core.Class(ReactiveOption)({
  __call = function(self)
    WARN(("ReUI.Options: [%s] call operator is deprecated, use '.Value' or ':Get()'"):format(self.Name))
    return self:Get()
  end,
  Bind = function(self, f)
    WARN(("ReUI.Options: [%s] ':Bind()' is deprecated, use 'OnChanged' event"):format(self.Name))
    self.OnChange = f
    f(self)
  end,
  OnChange = ReUI.Core.Property({
    get = function(self)
      WARN(("ReUI.Options: [%s] '.OnChange' is deprecated, use 'OnChanged' event"):format(self.Name))
      return self._onChange
    end,
    set = function(self, value)
      WARN(("ReUI.Options: [%s] '.OnChange' is deprecated, use 'OnChanged' event"):format(self.Name))
      local prevOnChange = self._onChange
      if prevOnChange then
        self.OnChanged:Remove(prevOnChange)
      end
      self.OnChanged:Add(value)
      self._onChange = value
    end
  })
})
