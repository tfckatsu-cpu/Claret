table.getn=function(t) return #t end
math.mod=math.fmod
local M=setmetatable({},{__index=_G})
assert(loadfile('../mods/ClaretHotbuild/modules/Model.lua','t',M))()
local model=M.Create({version=1,bindings={{id='b1',name='Old',key='',entries={{kind='action',id='custom.action'},{kind='blueprint',id='ueb0101'}}}}})
assert(model:Get('b1').entries[1].id=='custom.action' and not model:Get('b1').grid)
local b={id='b2',name='Grid',key='',entries={{kind='blueprint',id='ueb0101'},{kind='blueprint',id='uab0101'},{kind='blueprint',id='uea0101'}}, grid={buildings={{UEF='ueb0101',AEON='uab0101'},{}},units={AIR={UEF='uea0101'}}}}
assert(model:Put(b)); b.grid.buildings[1].UEF='bad'
assert(model:Get('b2').grid.buildings[1].UEF=='ueb0101')
local copy=model:Get('b2');copy.grid.units.AIR.UEF='bad'
assert(model:Get('b2').grid.units.AIR.UEF=='uea0101')
local reloaded=M.Create(model:Export());assert(reloaded:Get('b2').grid.buildings[1].AEON=='uab0101')
copy=model:Get('b2');copy.grid.units.AIR.UEF='missing';assert(not model:Put(copy))
copy=model:Get('b2');copy.grid.units.AIR.UEF='ueb0101';assert(not model:Put(copy))
copy=model:Get('b2');copy.grid.units.SPACE={};assert(not model:Put(copy))
assert(reloaded:Get('b1').entries[1].kind=='action')
print('PASS: grid persistence, deep copies, invalid and duplicate cells rejected, legacy preserved')
