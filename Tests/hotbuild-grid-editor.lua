-- Editor integration with mock Maui controls; verifies interactions, not game rendering.
local testLocalization = dofile('Tests/localization-test-helper.lua')
-- Model FAF's Lua 5.0 explicit array length, which can stay stale after a
-- direct write at count+1. This catches row growth that only works via #.
local explicitLengths=setmetatable({},{__mode='k'})
table.getn = function(t) return explicitLengths[t] or #t end
table.setn = function(t,n) explicitLengths[t]=n end
math.mod = math.fmod
local objects, edits, combos, escapeHandlers = {}, {}, {}, {}
local configuredEditSizes = {}
local function variable(value)
    return setmetatable({value=value, Set=function(self,v) self.value=v end}, {__call=function(self) return self.value end})
end
local function control(parent, text)
    local c = {parent=parent, text=text, visible=true, Width=variable(1920), Height=variable(1080), Depth=variable(0)}
    function c:OnDestroy() end
    function c:Destroy() self:OnDestroy(); self.destroyed=true end
    function c:SetText(value) self.text=value; if self.OnTextChanged then self:OnTextChanged(value) end end
    function c:GetText() return self.text or '' end
    function c:SetColor() end
    function c:SetNeedsFrameUpdate(v) self.needsFrameUpdate=v end
    function c:SetSolidColor(color) self.color=color end
    function c:DisableHitTest() end
    function c:SetTexture(path) self.texture=path end
    function c:Show() self.visible=true end
    function c:Hide() self.visible=false end
    objects[#objects+1]=c
    return c
end
local function layout(c)
    local l = {}
    function l:Width(w) c.Width:Set(w); return self end
    function l:Height(h) c.Height:Set(h); return self end
    function l:AtLeftTopIn(parent,x,y) c.x=x; c.y=y; return self end
    function l:AtCenterIn(parent) return self end
    return l
end
local modules = {
    ['/lua/ui/dialogs/eschandler.lua']={
        PushEscapeHandler=function(handler) table.insert(escapeHandlers,handler) end,
        PopEscapeHandler=function() table.remove(escapeHandlers) end,
    },
    ['/lua/maui/group.lua']={Group=control},
    ['/lua/maui/bitmap.lua']={Bitmap=control},
    ['/lua/maui/edit.lua']={Edit=function(parent)
        local c=control(parent); c.Width:Set(0); c.Height:Set(0); edits[#edits+1]=c; return c
    end},
    ['/lua/maui/layouthelpers.lua']={GetPixelScaleFactor=function() return 1 end},
    ['/lua/ui/game/tooltip.lua']={DestroyMouseoverDisplay=function() end,AddAutoUpdatedControlTooltip=function() end},
    ['/lua/ui/controls/combo.lua']={Combo=function(parent)
        local c=control(parent); combos[#combos+1]=c
        function c:AddItems(items,index) self.items=items; self.selected=index end
        function c:ClearItems() self.items={} end
        function c:SetItem(index) self.selected=index end
        return c
    end},
    ['/lua/ui/uiutil.lua']={bodyFont='Arial', SetupEditStd=function(field)
        assert(field.Width()>0 and field.Height()>0,'editor field geometry must be assigned before SetupEditStd')
        assert(field.Height()==36 and (field.Width()==300 or field.Width()==684),
            'editor field uses its requested geometry before SetupEditStd')
        configuredEditSizes[#configuredEditSizes+1]={width=field.Width(),height=field.Height()}
    end, CreateText=control,
        UIFile=function(path) return path end,
        CreateVertScrollbarFor=function(panel)
            assert(panel.GetScrollValues and panel.ScrollSetTop and panel.ScrollLines and panel.ScrollPages)
            panel:GetScrollValues()
            return control(panel)
        end},
}
local equivalenceModule = {}
assert(loadfile('../mods/ClaretHotbuild/modules/Equivalents.lua','t',setmetatable(equivalenceModule,{__index=_G})))()
modules['/mods/ClaretHotbuild/modules/Equivalents.lua']=equivalenceModule
modules['/lua/keymap/unitkeygroups.lua']={unitkeygroups={}}
local themeModule=setmetatable({},{__index=_G})
themeModule.import=function(path) return assert(modules[path],path) end
assert(loadfile('../mods/ClaretCore/modules/Theme.lua','t',themeModule))()
modules['/mods/ClaretCore/modules/Theme.lua']=themeModule
local env=setmetatable({ReUI={ClaretCore={Localization=testLocalization},UI={FloorLayouter=function() return layout end}},import=function(path) return assert(modules[path],path) end},{__index=_G})
local diagnostics={}
local probeEnabled=false
env._G=env
env.ReUI.Options={Mods={ClaretCore={probeEnabled={Get=function() return probeEnabled end}}}}
env.LOG=function(message) diagnostics[#diagnostics+1]=message end
local records={}
for i=1,45 do records[i]={id='unit'..i,name='Unit '..i,faction='UEF',tech='T1',kind='STRUCTURE',blueprint={},icon='icon',description='Description'} end
records[46]={id='claret_template_test',name='Template saved',faction='UEF',tech='T2',kind='STRUCTURE',blueprint={},icon='templateIcon',templateData={2,2,{'unit1',0,0,0}}}
local catalog={Get=function(self,id) for _,r in ipairs(records) do if r.id==id then return r end end end,
    List=function(self,filters)
        if filters.faction~='ALL' and filters.faction~='UEF' then return {} end
        local result={}
        for _,r in ipairs(records) do if filters.search=='' or r.name:find(filters.search,1,true) then result[#result+1]=r end end
        return result
    end}
local modelModule=setmetatable({},{__index=_G})
assert(loadfile('../mods/ClaretHotbuild/modules/Model.lua','t',modelModule))()
local model=modelModule.Create({version=1,bindings={
    {id='b1',name='First',key='',grid={context='ctxSaved',buildings={},units={LAND={},AIR={},NAVAL={}}},entries={}},
    {id='legacy',name='Old record',key='',entries={{kind='blueprint',id='unit2'}}},
}})
local compatibilityMessage,compatibilityDetails
modules['/mods/ClaretHotbuild/modules/Compatibility.lua']={
    ValidateBinding=function() if compatibilityMessage then return false,compatibilityMessage,compatibilityDetails end; return true end,
}
local contextRecords={{id='ctxSaved',name='Saved context',rows={
    {context='builder',action='move'}, {context='engineer',mode='own',action='reclaim'},
    {context='acu',mode='own',action='move'}, {context='factory',action='unit_cycle'},
    {context='empty',action='select_acu'},
}}}
local service={model=model, keyboardBindings={KeysFor=function(self,ref) assert(ref.kind=='preset'); return {'F2','Ctrl-K'} end}, Catalog=function() return catalog end,
    contextModel={List=function() return contextRecords end,Get=function(self,id)
        for _,item in ipairs(contextRecords) do if item.id==id then return item end end
    end}}
function service:Commit(binding,removeId)
    if compatibilityMessage then return false,compatibilityMessage end
    if self.fail then return false,'Disk error' end
    if removeId then return model:Delete(removeId) end
    local ok,err=model:Put(binding)
    if ok then self.persisted=model:Export() end
    return ok,err
end
function service:CommitContext(binding)
    if self.contextFail then return false,self.contextFail end
    for i,item in ipairs(contextRecords) do if item.id==binding.id then contextRecords[i]=binding; return true,'Saved context' end end
    return false,'Missing context'
end
assert(loadfile('../mods/ClaretHotbuild/modules/Editor.lua','t',env))()

local frame=env.Create(control(),service)
local hint=false
for _,c in ipairs(objects) do if c.text=='используется на клавишах: F2, Ctrl-K' then hint=true end end
assert(hint,'preset shows assigned keys as a read-only hint')
assert(#configuredEditSizes==1 and configuredEditSizes[1].width==300,
    'editor name field is configured only after its layout is assigned')
local viewport,visibleBuildRows
for _,c in ipairs(objects) do
 if c.x==74 and c.Width()==985 then viewport=c end
end
assert(viewport and viewport.Height()==274,'build viewport shows four rows and a partial fifth row')
visibleBuildRows=0
for _,c in ipairs(objects) do if c.parent==viewport and c.Width()==232 and c.visible then visibleBuildRows=visibleBuildRows+1 end end
assert(visibleBuildRows==20,'four full faction rows and the peek row are exposed')
local peekMask=false
for _,c in ipairs(objects) do
 if c.parent==viewport and c.x==0 and c.y==274 and c.Width()==985 and c.Height()==45 then peekMask=true end
end
assert(peekMask,'the mask leaves only the edge of the fifth row visible')
for _,c in ipairs(objects) do
 assert(c.text~='↑' and c.text~='↓','build row move controls must not be present')
end
local function globalX(c)
 local x=c.x or 0; local p=c.parent
 while p do x=x+(p.x or 0); p=p.parent end
 return x
end
local buildColumns,unitColumns={},{}
for _,c in ipairs(objects) do
 if c.Width()==232 and c.parent==viewport then buildColumns[#buildColumns+1]=globalX(c) end
 if c.Width()==232 and c.parent==frame and c.y and c.y>=500 then unitColumns[#unitColumns+1]=globalX(c) end
end
for col=1,4 do
 assert(buildColumns[col]==unitColumns[col], 'building and unit faction columns must share x alignment: '..tostring(buildColumns[col])..' / '..tostring(unitColumns[col]))
end
local function click(label,right)
 for _,c in ipairs(objects) do
  local parent=c.parent; local alive=true
  while parent do if parent.destroyed then alive=false; break end; parent=parent.parent end
  if alive and c.text==label and c.parent and c.parent.HandleEvent and c.parent.visible then
   c.parent:HandleEvent({Type='ButtonPress',Modifiers=right and {Right=true} or {Left=true}});return
  end
 end
 error('missing: '..label)
end
click('+')
assert(#configuredEditSizes==2 and configuredEditSizes[2].width==684,
    'catalog search field is configured only after its layout is assigned')
edits[table.getn(edits)]:SetText('Template saved'); click('Template saved'); click('Сохранить')
assert(model:Get('b1').grid.buildings[1].UEF=='claret_template_test')
local compactBadge
for _,c in ipairs(objects) do if c.text=='ШАБЛОН' and c.parent and c.parent.Width()==70 then compactBadge=c.parent end end
assert(compactBadge,'template cells render a compact badge')
local templateTile
for _,c in ipairs(objects) do if c.texture=='templateIcon' and c.parent and c.parent.HandleEvent and not c.parent.destroyed then templateTile=c.parent; break end end
assert(templateTile)
templateTile:HandleEvent({Type='ButtonPress',Modifiers={Right=true}}); click('Сохранить')
click('+'); click('Unit 1'); click('Сохранить')
assert(model:Get('b1').grid.buildings[1].UEF=='unit1')
-- Filling row two must reveal row three; save/reload must retain row priority.
local secondRowTile
for _,c in ipairs(objects) do
 if c.parent==viewport and c.y==65 and c.Width()==232 and c.HandleEvent and not c.destroyed then secondRowTile=c; break end
end
assert(secondRowTile and secondRowTile.visible,'second building row must appear after row one is filled')
assert(#diagnostics==0,'building editor diagnostics are disabled by default')
probeEnabled=true
secondRowTile:HandleEvent({Type='ButtonPress',Modifiers={Left=true}})
assert(diagnostics[#diagnostics] and diagnostics[#diagnostics]:find('event=open row=2',1,true),
    'opening a building cell logs its row index')
edits[table.getn(edits)]:SetText('Unit 2')
click('Unit 2')
assert(diagnostics[#diagnostics] and diagnostics[#diagnostics]:find('event=chosen row=2',1,true)
    and diagnostics[#diagnostics]:find('id=unit2',1,true)
    and diagnostics[#diagnostics]:find('rows=3',1,true)
    and diagnostics[#diagnostics]:find('visible_rows=4',1,true),
    'choosing a building logs ID and post-refresh row counts')
local thirdRowTile
for _,c in ipairs(objects) do
 if c.parent==viewport and c.y==130 and c.Width()==232 and c.HandleEvent and not c.destroyed then thirdRowTile=c; break end
end
assert(thirdRowTile and thirdRowTile.visible,'filling row two must expose row three')
click('Сохранить')
local twoRow=model:Get('b1').grid.buildings
assert(twoRow[1].UEF=='unit1' and twoRow[2].UEF=='unit2' and twoRow[3]==nil,
    'saving retains the second row in order and omits the empty trailing row')
assert(modelModule.Create(service.persisted):Get('b1').grid.buildings[2].UEF=='unit2',
    'second row survives profile reload')
-- Populate beyond the four-row viewport, scrolling between rows five and six.
local function chooseVisibleRow(y,id)
 local tile
 for _,c in ipairs(objects) do
  if c.parent==viewport and c.y==y and c.x==0 and c.Width()==232 and c.visible then tile=c; break end
 end
 assert(tile,'missing visible build cell at y='..y)
 tile:HandleEvent({Type='ButtonPress',Modifiers={Left=true}})
 edits[table.getn(edits)]:SetText(id)
 click(id)
end
chooseVisibleRow(130,'Unit 3')
chooseVisibleRow(195,'Unit 4')
viewport:HandleEvent({Type='WheelRotation',WheelRotation=-1})
chooseVisibleRow(195,'Unit 5')
viewport:HandleEvent({Type='WheelRotation',WheelRotation=-1})
chooseVisibleRow(195,'Unit 6')
click('Сохранить')
local sixRows=model:Get('b1').grid.buildings
for i=1,6 do assert(sixRows[i] and sixRows[i].UEF=='unit'..i,'row '..i..' survives six-row save') end
assert(viewport.y==195 or viewport.Height()==260,'viewport remains present after scrolling')
for _,c in ipairs(objects) do if c.texture=='icon' and c.parent and c.parent.parent==viewport and c.parent.x==0 and c.parent.y==0 then c.parent:HandleEvent({Type='ButtonPress',Modifiers={Right=true}}); break end end
click('Сохранить')
assert(model:Get('b1').grid.buildings[1].UEF==nil and model:Get('b1').grid.buildings[2].UEF=='unit2')

-- Editing preserves the historical reference without exposing its selector.
assert(model:Get('b1').grid.context=='ctxSaved','historical reference survives editing')
assert(modelModule.Create(service.persisted):Get('b1').grid.context=='ctxSaved','historical reference survives reload')
for _,c in ipairs(objects) do
 assert(c.text~='Старый выбор составного бинда' and c.text~='+ Выбрать составной бинд'
     and c.text~='Без составного бинда','legacy assignment controls are absent')
end
assert(model:Get('legacy').grid==nil and model:Get('legacy').entries[1].id=='unit2',
    'legacy entries without grid metadata remain intact')

-- The list deletes the requested saved binding only after a second click.
click('Новый хотбилд'); edits[1]:SetText('Русское имя'); click('Сохранить')
assert(not model:Get('b2'), 'non-ASCII binding name must not be saved')
local warned=false
for _,c in ipairs(objects) do if c.text=='Только английские буквы, цифры и знаки ASCII.' then warned=true end end
assert(warned, 'missing binding name warning')
edits[1]:SetText('Second'); click('Сохранить')
assert(model:Get('b2'))
local conflictMessage='Группа Строители занята: бинд «Second draft» (клавиша F2), плитки «Строители» и «Инженер» конфликтуют со строительным пресетом.'
compatibilityMessage=conflictMessage
compatibilityDetails={kind='build_context',contexts={'acu','engineer'},ownContexts={'acu','engineer'},parent=true,tiles={'ACU','Инженер'}}
edits[1]:SetText('Second draft')
click('Сохранить')
assert(model:Get('b2').name=='Second' and edits[1]:GetText()=='Second draft',
    'compatibility rejection preserves the saved binding and draft')
local conflictTitle,clearButton
for _,c in ipairs(objects) do
 if c.text=='Нельзя совместить' and c.parent and not c.parent.destroyed then conflictTitle=c end
 if c.text=='Очистить плитку' and c.parent and not c.parent.destroyed then clearButton=c end
end
assert(conflictTitle and not clearButton,'compatibility dialog cannot alter a composite')
assert(#escapeHandlers>0,'compatibility dialog registers Escape')
escapeHandlers[#escapeHandlers]()
compatibilityMessage=nil; compatibilityDetails=nil
click('Сохранить')
assert(model:Get('b2').name=='Second draft','draft saves after resolving compatibility')
click('Second draft')
local overlay
for _,c in ipairs(objects) do if c.color=='00000000' and c.HandleEvent and not c.destroyed then overlay=c end end
assert(overlay, 'missing outside-click overlay')
overlay:HandleEvent({Type='ButtonPress',Modifiers={Left=true}})
assert(overlay.destroyed, 'outside click did not close list')
click('Second draft')
local remove
for _,c in ipairs(objects) do
 if c.text=='×' and c.parent and c.parent.x==236 and c.parent.y==2 then remove=c.parent; break end
end
assert(remove, 'missing row delete button')
remove:HandleEvent({Type='ButtonPress',Modifiers={Left=true}}); assert(model:Get('b1'))
remove:HandleEvent({Type='ButtonPress',Modifiers={Left=true}}); assert(not model:Get('b1') and model:Get('b2'))
-- Leaving a dirty draft presents an explicit save / discard / cancel choice.
edits[1]:SetText('Changed'); click('Новый хотбилд'); assert(edits[1]:GetText()=='Changed')
click('Отмена'); assert(edits[1]:GetText()=='Changed')
click('Новый хотбилд'); click('Не сохранять'); click('Новый хотбилд')
assert(edits[1]:GetText()=='New binding')
edits[1]:SetText('Continuation draft')
local continued
assert(frame.CanLeave('section:test',function(allowed) continued=allowed end)==false)
click('Не сохранять'); assert(continued==true,'discard resumes deferred navigation')
edits[1]:SetText('Cancelable draft')
local canceled
frame.CanLeave('section:test',function(allowed) canceled=allowed end)
click('Отмена'); assert(canceled==false,'cancel rejects deferred navigation: '..tostring(canceled))
edits[1]:SetText('Save continuation')
local savedContinuation
frame.CanLeave('section:test',function(allowed) savedContinuation=allowed end)
click('Сохранить и продолжить'); assert(savedContinuation==true,'successful save resumes deferred navigation')
print('PASS: grid editing, deletion confirmation and save/discard/cancel draft dialog')
