-- Generated research-only output. Original SHA256: 68323faa4acc809f87a2a40f1bd98251e7cd73ac88b6b8626ddb38cb330dd6c8. Not for game execution.
local next = next

local function EnabledComponentsIterator(components, key)
  if components then
    for name, component in next, components do
      if component.enabled then
        return name, component
      end
    end
  end
  return nil, nil
end

local function ComponentsIterator(components, key)
  if components then
    return next(components, key)
  end
  return nil, nil
end

ComponentContainer = Class()({
  GetComponents = function(self)
    return self._components
  end,
  IterateComponents = function(self)
    return ComponentsIterator, self._components, nil
  end,
  IterateEnabledComponents = function(self)
    return EnabledComponentsIterator, self._components, nil
  end,
  GetComponent = function(self, name)
    return self._components[name]
  end,
  AddComponent = function(self, name, component)
    if self._components == nil then
      self._components = {}
    end
    if self._components[name] ~= nil then
      error(("Component '%s' already exists"):format(name))
    end
    self._components[name] = component
  end,
  RemoveComponent = function(self, name)
    local components = self._components
    if components == nil then
      return
    end
    local component = components[name]
    if component == nil then
      return
    end
    component:Destroy()
    components[name] = nil
  end,
  DestroyComponents = function(self)
    if self._components == nil then
      return
    end
    for _, component in self._components, nil do
      component:Destroy()
    end
    self._components = nil
  end
})
