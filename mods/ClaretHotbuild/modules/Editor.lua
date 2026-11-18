-- Four-faction Hotbuild editor. The profile remains owned by Runtime/Model.
local factions = {'UEF', 'AEON', 'CYBRAN', 'SERAPHIM'}
local domains = {'LAND', 'AIR', 'NAVAL', 'GATE'}
local techRank = {T1=1,T2=2,T3=3,EXPERIMENTAL=4,OTHER=5}
local unitSlotOrder = {'T1','T2','T3','T4','LEGACY'}
local visibleUnitTiers = {'T1','T2','T3'}
local LOG = LOG or function() end
local function UnitSlot(tech)
    if tech=='EXPERIMENTAL' or tech=='T4' then return 'T4' end
    if tech=='T1' or tech=='T2' or tech=='T3' then return tech end
end
local function BuildingLog(event,index,faction,id,count,visibleRows,detail)
    local reui=rawget(_G,'ReUI')
    local options=reui and reui.Options and reui.Options.Mods and reui.Options.Mods['ClaretCore']
    local probe=options and options.probeEnabled
    if not probe or not probe:Get() then return end
    LOG('[ClaretHotbuild] Building editor: event='..tostring(event)
        ..' row='..tostring(index)..' faction='..tostring(faction)
        ..' id='..tostring(id)..' rows='..tostring(count)
        ..' visible_rows='..tostring(visibleRows)
        ..(detail and (' detail='..tostring(detail)) or ''))
end
local function Fold(text)
    local folded = string.gsub(string.lower(text or ''),'\208[\129\144-\175]',function(letter)
        local b=string.byte(letter,2)
        if b==129 then return string.char(209,145) end
        if b<160 then return string.char(208,b+32) end
        return string.char(209,b-32)
    end)
    return (string.gsub(folded,'\209\145','\208\181'))
end
local function Short(s,n)
    s=tostring(s or '')
    local p,c=1,0
    while p<=string.len(s) and c<n do
        local b=string.byte(s,p); p=p+(b<128 and 1 or (b<224 and 2 or (b<240 and 3 or 4))); c=c+1
    end
    return p<=string.len(s) and string.sub(s,1,p-1)..'…' or s
end
local function Clone(value)
    if type(value)~='table' then return value end
    local out={}; for k,v in pairs(value) do out[k]=Clone(v) end; return out
end
local function Empty(row)
    for _,faction in ipairs(factions) do if row[faction] then return false end end
    return true
end
-- FAF's Lua 5.0 table.getn can use an explicit table length. Keep that
-- length synchronized whenever the editor grows or trims its row array.
local function SetArrayLength(array,length)
    if table.setn then table.setn(array,length) end
end
local function EnsureBuildingRow(buildings,index)
    local count=table.getn(buildings)
    while count<index do
        count=count+1
        buildings[count]={}
        SetArrayLength(buildings,count)
    end
    return buildings[index]
end
local function RemoveBuildingRow(buildings,index)
    local count=table.getn(buildings)
    table.remove(buildings,index)
    SetArrayLength(buildings,math.max(0,count-1))
end
local function Categories(r)
    local bp=r.blueprint or {}
    local hash=rawget(bp,'CategoriesHash') or {}
    local categories=rawget(bp,'Categories') or {}
    local function has(k)
        if hash[k] then return true end
        for _,v in ipairs(categories) do if v==k then return true end end
        return false
    end
    if r.kind~='STRUCTURE' then return 5 end
    if has('FACTORY') or has('GATE') then return 1 end
    if has('ECONOMIC') or has('MASSEXTRACTION') or has('ENERGYPRODUCTION') then return 2 end
    if has('DEFENSE') or has('DEFENCE') then return 3 end
    return 4
end
local function CatalogName(name, record, catalog)
    if catalog and type(catalog.DisplayName)=='function' then
        name=catalog:DisplayName(name,record.id,record.blueprint)
    end
    return Short(name,34)
end
local function TileName(record, catalog)
    if record.templateData then return Short(record.name,18) end
    return CatalogName(record.name,record,catalog)
end
local function ApplyPickerChoice(state,selection,record)
    local kind,index,faction,tier=selection.kind,selection.index,selection.faction,selection.tier
    local grid=state.getGrid()
    local variants=state.eq:Variants(record.id)
    local domainRow,target,old
    if kind=='STRUCTURE' then
        target=EnsureBuildingRow(grid.buildings,index); old=Clone(target)
    else
        domainRow=grid.units[kind] or {}; grid.units[kind]=domainRow
        old=Clone(domainRow)
    end
    local function UnitSlotsFor(factionId)
        local slots=domainRow[factionId]
        if type(slots)~='table' then
            local legacyId=type(slots)=='string' and slots or nil
            slots={}; if legacyId then slots.LEGACY=legacyId end
            domainRow[factionId]=slots
        end
        return slots
    end
    local applied=0
    for _,variantEntry in ipairs(variants) do
        local variant=state.catalog:Get(variantEntry.id)
        if variant and ((kind=='GATE' and variant.kind=='SACU') or (kind~='GATE' and (not tier or UnitSlot(variant.tech)==tier))) then
            applied=applied+1
            -- The clicked cell is an explicit replacement; other faction
            -- cells are only filled when their corresponding slot is empty.
            if variantEntry.faction~=faction then
                if kind=='STRUCTURE' then
                    if not target[variantEntry.faction] then target[variantEntry.faction]=variantEntry.id end
                elseif kind=='GATE' then
                    if not domainRow[variantEntry.faction] then domainRow[variantEntry.faction]=variantEntry.id end
                else
                    local assigned=domainRow[variantEntry.faction]
                    local occupied=type(assigned)=='string'
                        or (type(assigned)=='table' and assigned[tier]~=nil)
                    if not occupied then UnitSlotsFor(variantEntry.faction)[tier]=variantEntry.id end
                end
            end
        end
    end
    if kind=='STRUCTURE' then target[faction]=record.id
    elseif kind=='GATE' then domainRow[faction]=record.id
    else UnitSlotsFor(faction)[tier]=record.id end

    local seen={}
    for _,entry in ipairs(state.entries(grid)) do
        if seen[entry.id] then
            if kind=='STRUCTURE' then grid.buildings[index]=old else grid.units[kind]=old end
            if kind=='STRUCTURE' then
                BuildingLog('duplicate-rejected',index,faction,record.id,table.getn(grid.buildings),state.visibleRows,entry.id)
            end
            state.status('hotbuild.editor.status.duplicate_used',true); return
        end
        seen[entry.id]=true
    end
    state.change(); state.closePopup(); state.refresh()
    if kind=='STRUCTURE' then
        BuildingLog('chosen',index,faction,record.id,table.getn(grid.buildings),state.visibleRows)
    end
            state.status('hotbuild.editor.status.selected_variants',false,applied)
end
-- Keep shared helpers behind one module upvalue. The editor's UI tree has many
-- nested callbacks, and LuaPlus limits the number of upvalues per function.
local EditorShared={
    factions=factions,domains=domains,techRank=techRank,LOG=LOG,
    UnitSlot=UnitSlot,Fold=Fold,Short=Short,Clone=Clone,Empty=Empty,
    SetArrayLength=SetArrayLength,EnsureBuildingRow=EnsureBuildingRow,
    RemoveBuildingRow=RemoveBuildingRow,Categories=Categories,
    CatalogName=CatalogName,TileName=TileName,visibleUnitTiers=visibleUnitTiers,
    ApplyPickerChoice=ApplyPickerChoice,
}
function Create(parent, service, embedded, memory)
    local displayCatalog=service:Catalog()
    local Theme=import('/mods/ClaretCore/modules/Theme.lua'); local C=Theme.Colors
    local function FormatText(key,first,second,third)
        if third~=nil then return string.format(key,first,second,third) end
        if second~=nil then return string.format(key,first,second) end
        if first~=nil then return string.format(key,first) end
        return key
    end
    local Localization=ReUI.ClaretCore and ReUI.ClaretCore.Localization or {Text=FormatText}
    local function T(key,first,second,third) return Localization.Text(key,first,second,third) end
    local Group=import('/lua/maui/group.lua').Group
    local Bitmap=import('/lua/maui/bitmap.lua').Bitmap
    local Edit=import('/lua/maui/edit.lua').Edit
    local Combo=import('/lua/ui/controls/combo.lua').Combo
    local UI=import('/lua/ui/uiutil.lua')
    local Helpers=import('/lua/maui/layouthelpers.lua')
    local Tooltip=import('/lua/ui/game/tooltip.lua')
    local Escape=import('/lua/ui/dialogs/eschandler.lua')
    local compatibilityEscape,CloseCompatibilityDialog
    local frame=Group(parent); local oldDestroy=frame.OnDestroy
    frame.OnDestroy=function(self)
        if CloseCompatibilityDialog then CloseCompatibilityDialog() end
        Tooltip.DestroyMouseoverDisplay(); oldDestroy(self)
    end
    local pixel=Helpers.GetPixelScaleFactor()
    local scale=math.max(0.25,math.min(pixel,(parent.Width()-24)/1080,(parent.Height()-24)/920))
    if embedded then scale=embedded.scale end
    local ratio=scale/pixel; local L=ReUI.UI.FloorLayouter(scale)
    local setup={
        displayCatalog=displayCatalog,Theme=Theme,C=C,Group=Group,Bitmap=Bitmap,
        Edit=Edit,Combo=Combo,UI=UI,Helpers=Helpers,Tooltip=Tooltip,Escape=Escape,
        frame=frame,pixel=pixel,scale=scale,ratio=ratio,L=L,embedded=embedded,
        parent=parent,service=service,shared=EditorShared,
    }
    local ok,err=pcall(function()
        -- These aliases are locals of this function. Nested callbacks can use
        -- them without making the large pcall closure capture every helper.
        local displayCatalog=setup.displayCatalog
        local Theme,C=setup.Theme,setup.C
        local Group,Bitmap,Edit,Combo=setup.Group,setup.Bitmap,setup.Edit,setup.Combo
        local UI,Helpers=setup.UI,setup.Helpers
        local Tooltip,Escape=setup.Tooltip,setup.Escape
        local frame,pixel,scale,ratio,L=setup.frame,setup.pixel,setup.scale,setup.ratio,setup.L
        local embedded,parent,service=setup.embedded,setup.parent,setup.service
        local shared=setup.shared
        local factions,domains,techRank=shared.factions,shared.domains,shared.techRank
        local LOG,UnitSlot,Fold,Short=shared.LOG,shared.UnitSlot,shared.Fold,shared.Short
        local Clone,Empty=shared.Clone,shared.Empty
        local SetArrayLength,EnsureBuildingRow=shared.SetArrayLength,shared.EnsureBuildingRow
        local RemoveBuildingRow,Categories=shared.RemoveBuildingRow,shared.Categories
        local CatalogName,TileName=shared.CatalogName,shared.TileName
        local visibleUnitTiers=shared.visibleUnitTiers
        local ApplyPickerChoice=shared.ApplyPickerChoice
        if embedded then
            L(frame):Width(1080):Height(920):AtLeftTopIn(parent,0,0)
            frame.Depth:Set(function() return parent.Depth()+1 end)
        else
            L(frame):Width(1080):Height(920):AtCenterIn(parent)
            frame.Depth:Set(1000)
        end
        if not embedded then Theme.AnimateCentered(frame,parent,L) end
        local function Panel(owner,x,y,w,h,color)
            local p=Bitmap(owner); p:SetSolidColor(color or C.surface)
            p.Depth:Set(function() return owner.Depth()+1 end)
            L(p):AtLeftTopIn(owner,x,y):Width(w):Height(h); return p
        end
        local bg=Panel(frame,0,0,1080,920,C.canvas); bg.Depth:Set(function() return frame.Depth()+1 end); bg:DisableHitTest()
        local function Text(owner,text,x,y,size,color)
            if type(text)=='string' and string.sub(text,1,9)=='hotbuild.' then text=T(text) end
            local t=UI.CreateText(owner,text,(size or 14)*ratio,Theme.Fonts.body)
            t.Depth:Set(function() return owner.Depth()+2 end)
            t:SetColor(color or C.text); t:DisableHitTest()
            L(t):AtLeftTopIn(owner,x,y); return t
        end
        local function Button(owner,text,x,y,w,fn,primary)
            local normal=primary and C.accent or C.raised
            local h=Theme.Metrics.buttonHeight
            local b=Panel(owner,x,y,w,h,normal); local border=Theme.Outline(b,L,w,h)
            local label=Text(b,text,0,0,Theme.Metrics.buttonText); L(label):AtCenterIn(b)
            b.HandleEvent=function(self,e)
                if e.Type=='MouseEnter' then
                    self:SetSolidColor(self.saveButton and not self.saveEnabled and C.disabled or (primary and C.accentHover or C.hover))
                    border(self.saveButton and not self.saveEnabled and C.border or C.selectedBorder)
                elseif e.Type=='MouseExit' then
                    self:SetSolidColor(self.saveButton and not self.saveEnabled and C.disabled or normal); border(C.border)
                elseif e.Type=='ButtonPress' and not (e.Modifiers and e.Modifiers.Right) then
                    if self.saveButton and not self.saveEnabled then return true end
                    fn(); return true
                end
                return true
            end
            return b
        end
        local function Field(owner,x,y,w,max)
            local input=Edit(owner)
            input.Depth:Set(function() return owner.Depth()+2 end)
            L(input):AtLeftTopIn(owner,x,y):Width(w):Height(Theme.Metrics.fieldHeight)
            UI.SetupEditStd(input,C.text,nil,C.text,C.surface,Theme.Fonts.body,Theme.Metrics.text*ratio,max)
            input.OnEnterPressed=function() return true end
            return input
        end
        local function SearchField(owner,x,y,w,max)
            local plate=Panel(owner,x,y,w,Theme.Metrics.fieldHeight,C.surface)
            plate:DisableHitTest()
            local input=Edit(owner)
            input.Depth:Set(function() return owner.Depth()+2 end)
            L(input):AtLeftTopIn(owner,x+28,y):Width(w-28):Height(Theme.Metrics.fieldHeight)
            UI.SetupEditStd(input,C.text,nil,C.text,C.surface,Theme.Fonts.body,Theme.Metrics.text*ratio,max)
            input.OnEnterPressed=function() return true end
            local mark=Bitmap(owner)
            mark:SetTexture('/mods/ClaretHotbuild/textures/search-icon.dds')
            mark.Depth:Set(function() return owner.Depth()+3 end)
            mark:DisableHitTest()
            L(mark):AtLeftTopIn(owner,x+8,y+10):Width(16):Height(16)
            return input
        end
        local catalog=service:Catalog()
        local compatibility
        local compatibilityLoaded,compatibilityModule=pcall(import,'/mods/ClaretHotbuild/modules/Compatibility.lua')
        if compatibilityLoaded then compatibility=compatibilityModule end
        local eq=import('/mods/ClaretHotbuild/modules/Equivalents.lua').Create(catalog,import('/lua/keymap/unitkeygroups.lua').unitkeygroups)
        memory = type(memory)=='table' and memory or {}
        local draft,grid,dirty,loading,legacyIssue=nil,nil,false,false,nil
        local saveButton
        local buildingTop=1; local Refresh,SyncSelector,ClosePopup,SaveDraft,Load; local s
        local leaveIntent=nil
        local leaveDialog,leaveOverlay,leaveContinuation
        local compatibilityDialog,compatibilityOverlay
        local status=Text(frame,'',24,893,12,C.muted)
        local function Status(message,error,arg1,arg2,arg3)
            if type(message)=='string' and string.sub(message,1,9)=='hotbuild.' then message=T(message,arg1,arg2,arg3) end
            status:SetColor(error and C.danger or C.muted); status:SetText(Short(message,130))
        end
        local function Change()
            if not loading then
                dirty=true; leaveIntent=nil; Status(T('hotbuild.common.unsaved'))
                if saveButton then saveButton.saveEnabled=true; saveButton:SetSolidColor(C.accent) end
                if SyncSelector then SyncSelector() end
            end
        end
        local function CloseLeaveDialog()
            if leaveDialog then leaveDialog:Destroy(); leaveDialog=nil end
            if leaveOverlay then leaveOverlay:Destroy(); leaveOverlay=nil end
        end
        CloseCompatibilityDialog=function()
            if compatibilityEscape then Escape.PopEscapeHandler(); compatibilityEscape=nil end
            if compatibilityDialog then compatibilityDialog:Destroy(); compatibilityDialog=nil end
            if compatibilityOverlay then compatibilityOverlay:Destroy(); compatibilityOverlay=nil end
        end
        local function WrapMessage(message,limit)
            local lines,current={},''
            local source=tostring(message or '')
            local position=1
            while position<=string.len(source) do
                local first,last=string.find(source,'%S+',position)
                if not first then break end
                local word=string.sub(source,first,last)
                position=last+1
                local candidate=current=='' and word or (current..' '..word)
                if current~='' and Short(candidate,limit)~=candidate then
                    table.insert(lines,current); current=word
                else current=candidate end
            end
            if current~='' then table.insert(lines,current) end
            return lines,table.getn(lines)
        end
        local function ShowCompatibilityDialog(message,details)
            CloseCompatibilityDialog()
            compatibilityOverlay=Panel(frame,0,0,1080,920,C.transparent)
            compatibilityOverlay.Depth:Set(function() return frame.Depth()+90 end)
            compatibilityOverlay.HandleEvent=function() return true end
            local width=680
            local wrapped,lineCount=WrapMessage(message,76)
            local bodyHeight=math.max(22,lineCount*22)
            local height=bodyHeight+116
            compatibilityDialog=Group(frame)
            L(compatibilityDialog):AtCenterIn(frame):Width(width):Height(height)
            Theme.AnimateCentered(compatibilityDialog,frame,L)
            compatibilityDialog.Depth:Set(function() return frame.Depth()+100 end)
            local back=Panel(compatibilityDialog,0,0,width,height,C.surface)
            back.Depth:Set(compatibilityDialog.Depth)
            Theme.Outline(back,L,width,height,C.selectedBorder)
            Text(compatibilityDialog,T('hotbuild.editor.conflict_title'),24,20,20)
            for index,line in ipairs(wrapped) do
                Text(compatibilityDialog,line,24,60+(index-1)*22,14,C.text)
            end
            Escape.PushEscapeHandler(CloseCompatibilityDialog); compatibilityEscape=true
            Button(compatibilityDialog,T('hotbuild.common.close'),width-144,height-44,120,CloseCompatibilityDialog,true)
        end
        local function FinishLeave(allowed)
            local continuation=leaveContinuation
            leaveContinuation=nil
            if continuation then
                local ok,err=pcall(continuation,allowed)
                if not ok then Status(T('hotbuild.editor.status.incompatible',tostring(err)),true) end
            end
        end
        local function ShowLeaveDialog(intent,continuation)
            CloseLeaveDialog()
            leaveIntent=intent
            leaveContinuation=continuation
            leaveOverlay=Panel(frame,0,0,1080,920,C.transparent); leaveOverlay.Depth:Set(frame.Depth()+80)
            leaveOverlay.HandleEvent=function(self,e) if e.Type=='ButtonPress' then return true end; return true end
            local dialogWidth,dialogHeight=560,224
            leaveDialog=Group(frame); L(leaveDialog):AtCenterIn(frame):Width(dialogWidth):Height(dialogHeight); leaveDialog.Depth:Set(frame.Depth()+90)
            Theme.AnimateCentered(leaveDialog,frame,L)
            local back=Panel(leaveDialog,0,0,dialogWidth,dialogHeight,C.surface); back.Depth:Set(leaveDialog.Depth); Theme.Outline(back,L,dialogWidth,dialogHeight,C.selectedBorder)
            Text(leaveDialog,T('hotbuild.common.unsaved_title'),24,20,20)
            Text(leaveDialog,T('hotbuild.common.save_before_leave'),24,64,14,C.muted)
            local save=Button(leaveDialog,T('hotbuild.common.save_continue'),24,156,220,function()
                local ok=SaveDraft and SaveDraft()
                if ok then
                    CloseLeaveDialog(); leaveIntent=nil
                    if leaveContinuation then FinishLeave(true)
                    elseif intent=='close' and not embedded then frame:Destroy() end
                end
            end,true)
            Button(leaveDialog,T('hotbuild.common.discard'),260,156,140,function()
                local bindings=service.model:List()
                Load(draft and service.model:Get(draft.id) or bindings[1])
                CloseLeaveDialog(); leaveIntent=nil
                if leaveContinuation then FinishLeave(true)
                elseif intent=='close' and not embedded then frame:Destroy()
                else Status(T('hotbuild.common.discarded_retry'),false) end
            end)
            Button(leaveDialog,T('hotbuild.common.cancel'),416,156,120,function()
                CloseLeaveDialog(); leaveIntent=nil
                if leaveContinuation then FinishLeave(false) end
            end)
            Tooltip.AddAutoUpdatedControlTooltip(save,function() return T('hotbuild.common.save_draft_tooltip') end,function() return T('hotbuild.common.validate_draft_tooltip') end)
        end
        local function MayLeave(intent,continuation)
            if dirty then
                if not leaveDialog then ShowLeaveDialog(intent,continuation)
                elseif continuation then leaveContinuation=continuation end
                return false
            end
            leaveIntent=nil; return true
        end
        local function Entries(g,preferred)
            local result={}
            for _,row in ipairs(g.buildings) do for _,f in ipairs(factions) do
                if row[f] then table.insert(result,{kind='blueprint',id=row[f]}) end
            end end
            for _,domain in ipairs(domains) do local row=g.units[domain] or {}; for _,f in ipairs(factions) do
                local slots=row[f]
                if type(slots)=='string' then table.insert(result,{kind='blueprint',id=slots})
                elseif type(slots)=='table' then for _,tier in ipairs(unitSlotOrder) do
                    if slots[tier] then table.insert(result,{kind='blueprint',id=slots[tier]}) end
                end end
            end end
            if preferred then
                local byKey={}; local buildingKeys={}; local orderedBuildings={}; local ordered={}; local used={}
                for _,entry in ipairs(result) do byKey[entry.kind..':'..entry.id]=entry end
                for _,row in ipairs(g.buildings) do for _,f in ipairs(factions) do
                    local id=row[f]
                    if id then
                        local key='blueprint:'..id
                        buildingKeys[key]=true
                        table.insert(orderedBuildings,byKey[key])
                    end
                end end
                local nextBuilding=1
                for _,entry in ipairs(preferred) do
                    local key=entry.kind..':'..entry.id
                    if buildingKeys[key] and nextBuilding<=table.getn(orderedBuildings) then
                        local building=orderedBuildings[nextBuilding]
                        local buildingKey=building.kind..':'..building.id
                        if not used[buildingKey] then
                            table.insert(ordered,building); used[buildingKey]=true
                        end
                        nextBuilding=nextBuilding+1
                    elseif byKey[key] and not used[key] then
                        table.insert(ordered,byKey[key]); used[key]=true
                    end
                end
                for _,entry in ipairs(result) do
                    local key=entry.kind..':'..entry.id
                    if not used[key] then table.insert(ordered,entry) end
                end
                return ordered
            end
            return result
        end
        local function CandidateForBinding(binding,currentGrid)
            local candidate=Clone(binding)
            local candidateGrid=Clone(currentGrid)
            while table.getn(candidateGrid.buildings)>0 and Empty(candidateGrid.buildings[table.getn(candidateGrid.buildings)]) do
                RemoveBuildingRow(candidateGrid.buildings,table.getn(candidateGrid.buildings))
            end
            candidate.grid=candidateGrid; candidate.entries=Entries(candidateGrid,binding.entries)
            return candidate
        end
        local function ImportLegacy(entries)
            local result={buildings={},units={LAND={},AIR={},NAVAL={},GATE={}}}
            local issue
            for _,entry in ipairs(entries) do
                local r=entry.kind=='blueprint' and catalog:Get(entry.id)
                if not r or not (r.faction=='UEF' or r.faction=='AEON' or r.faction=='CYBRAN' or r.faction=='SERAPHIM') then
                    issue='hotbuild.editor.status.legacy_action'
                elseif r.kind=='STRUCTURE' then
                    local row=result.buildings[table.getn(result.buildings)]
                    if not row or row[r.faction] or row._key~=eq:Key(r.id) then
                        row={_key=eq:Key(r.id)}; table.insert(result.buildings,row)
                    end
                    row[r.faction]=r.id
                elseif r.kind=='SACU' then
                    local row=result.units.GATE
                    if row[r.faction] then issue='hotbuild.editor.status.legacy_duplicate'
                    else row[r.faction]=r.id end
                elseif result.units[r.kind] then
                    local tier=UnitSlot(r.tech) or 'LEGACY'
                    local slots=result.units[r.kind][r.faction] or {}
                    if slots[tier] then issue='hotbuild.editor.status.legacy_duplicate'
                    else slots[tier]=r.id; result.units[r.kind][r.faction]=slots end
                else issue='hotbuild.editor.status.legacy_unsupported' end
            end
            for _,row in ipairs(result.buildings) do row._key=nil end
            local exported=Entries(result,entries)
            if table.getn(exported)~=table.getn(entries) then issue=issue or 'hotbuild.editor.status.legacy_grid' end
            if not issue then for i,e in ipairs(exported) do
                if entries[i].kind~=e.kind or entries[i].id~=e.id then issue='hotbuild.editor.status.legacy_order'; break end
            end end
            return result,issue
        end
        local name=Field(frame,315,88,300,64)
        local nameBorder=Panel(frame,315,88,300,36,C.transparent)
        local nameOutline=Theme.Outline(nameBorder,L,300,36,C.border)
        nameBorder:DisableHitTest()
        local nameWarning=Text(frame,'',315,48,13,C.danger)
        local function InvalidName(value)
            return type(value)=='string' and string.find(value,'[^ -~]')~=nil
        end
        Load=function(binding)
            loading=true; draft=binding; dirty=false; legacyIssue=nil; buildingTop=1
            memory.bindingId=binding and binding.id or nil
            if binding then
                if binding.grid then grid=Clone(binding.grid) else grid,legacyIssue=ImportLegacy(binding.entries) end
                name:SetText(binding.name)
            else grid={buildings={},units={LAND={},AIR={},NAVAL={},GATE={}}}; name:SetText('') end
            grid.units.GATE=grid.units.GATE or {}
            for _,domain in ipairs(domains) do
                local row=grid.units[domain] or {}; grid.units[domain]=row
                for _,faction in ipairs(factions) do
                    local value=row[faction]
                    if domain~='GATE' and type(value)=='string' then
                        local record=catalog:Get(value)
                        if record and record.kind=='SACU' and not grid.units.GATE[faction] then
                            grid.units.GATE[faction]=value; row[faction]=nil; value=nil
                        end
                    end
                    if domain~='GATE' and type(value)=='table' then
                        for _,tier in ipairs(unitSlotOrder) do
                            local record=value[tier] and catalog:Get(value[tier])
                            if record and record.kind=='SACU' and not grid.units.GATE[faction] then
                                grid.units.GATE[faction]=value[tier]; value[tier]=nil
                            end
                        end
                    end
                    if type(value)=='string' and domain~='GATE' then
                        local record=catalog:Get(value); local tier=record and UnitSlot(record.tech)
                        if tier then row[faction]={[tier]=value} end
                    end
                end
            end
            loading=false
            if s then s.grid=grid; s.draft=draft; s.legacyIssue=legacyIssue; s.buildingTop=buildingTop end
            if saveButton then saveButton.saveEnabled=false; saveButton:SetSolidColor(C.disabled) end
        end
        name.OnTextChanged=function(self,value)
            nameWarning:SetText(InvalidName(value) and T('hotbuild.editor.status.invalid_name') or '')
            if draft and not loading then draft.name=value; Change() end
        end
        local function Writable()
            if not draft then Status(T('hotbuild.common.create_or_select'),true); return false end
            if legacyIssue then Status(T(legacyIssue)..' '..T('hotbuild.editor.status.create_binding'),true); return false end
            return true
        end
        Panel(frame,24,18,4,22,C.accent):DisableHitTest(); Text(frame,'Hotbuild',40,14,22)
        Text(frame,T('hotbuild.editor.binding'),24,67,14,C.muted); Text(frame,T('hotbuild.editor.name'),315,67,14,C.muted)
        local selectorButton=Button(frame,'',24,88,270,function() end)
        local selectorLabel=Text(selectorButton,'',12,7,15)
        local selectorArrow=Text(selectorButton,'▼',244,7,13,C.muted)
        local listPanel, listOverlay, listTop, deleteIntent = nil, nil, 1, nil
        local function CloseList()
            if listPanel then listPanel:Destroy(); listPanel=nil end
            if listOverlay then listOverlay:Destroy(); listOverlay=nil end
        end
        local function OpenList()
            CloseList()
            local bindings=service.model:List()
            listTop=math.max(1,math.min(listTop,math.max(1,table.getn(bindings)-7)))
            listOverlay=Panel(frame,0,0,1080,920,C.transparent)
            listOverlay.Depth:Set(function() return frame.Depth()+80 end)
            listOverlay.HandleEvent=function(self,e)
                if e.Type=='ButtonPress' then CloseList() end
                return true
            end
            listPanel=Group(frame); L(listPanel):AtLeftTopIn(frame,24,126):Width(270):Height(310)
            Theme.AnimateAnchored(listPanel,frame,L,24,126)
            listPanel.Depth:Set(function() return frame.Depth()+100 end)
            local background=Panel(listPanel,0,0,270,310,C.canvas); background.Depth:Set(listPanel.Depth)
            Theme.Outline(background,L,270,310)
            for i=1,8 do
                local binding=bindings[listTop+i-1]
                if binding then
                    local id=binding.id
                    local selectButton=Button(listPanel,Short(binding.name,25),2,2+(i-1)*38,232,function()
                        if not MayLeave('select:'..id) then return end
                        Load(service.model:Get(id)); CloseList(); SyncSelector(); Refresh()
                    end)
                    local remove=Button(listPanel,'×',236,2+(i-1)*38,32,function()
                        if dirty then Status(T('hotbuild.editor.status.save_or_confirm'),true); return end
                        if deleteIntent~=id then deleteIntent=id; Status(T('hotbuild.editor.status.delete_confirm',binding.name),true); return end
                        local saved,msg=service:Commit(nil,id); deleteIntent=nil
                        if saved then
                            if draft and draft.id==id then Load(service.model:List()[1]) end
                            CloseList(); SyncSelector(); Refresh()
                        end
                        Status(saved and T('hotbuild.editor.status.deleted') or msg,not saved)
                    end)
                    for _,button in ipairs({selectButton,remove}) do
                        local handle=button.HandleEvent
                        button.HandleEvent=function(self,e)
                            if e.Type=='WheelRotation' then
                                listTop=math.max(1,math.min(math.max(1,table.getn(bindings)-7),listTop+(e.WheelRotation>0 and -1 or 1)))
                                OpenList(); return true
                            end
                            return handle(self,e)
                        end
                    end
                    Tooltip.AddAutoUpdatedControlTooltip(remove,function() return T('hotbuild.editor.delete_binding') end,function() return binding.name end)
                end
            end
            local function ScrollList(self,e)
                if e.Type=='WheelRotation' then
                    listTop=math.max(1,math.min(math.max(1,table.getn(bindings)-7),listTop+(e.WheelRotation>0 and -1 or 1)))
                    OpenList(); return true
                end
                return true
            end
            background.HandleEvent=ScrollList
            listPanel.HandleEvent=ScrollList

        end
        local selectorButtonHandle=selectorButton.HandleEvent
        selectorButton.HandleEvent=function(self,e)
            if e.Type=='ButtonPress' and not (e.Modifiers and e.Modifiers.Right) then
                if listPanel then CloseList() else deleteIntent=nil; OpenList() end
                return true
            end
            return selectorButtonHandle(self,e)
        end
        SyncSelector=function()
            selectorLabel:SetText(draft and Short(draft.name,25)..(dirty and '  •' or '')..(service.model:Get(draft.id) and '' or ' *') or T('hotbuild.editor.no_bindings'))
        end
        Button(frame,T('hotbuild.editor.create_new'),625,88,135,function()
            if not MayLeave('new') then return end
            CloseList()
            local n=1; while service.model:Get('b'..n) do n=n+1 end
            Load({id='b'..n,name=T('hotbuild.editor.status.new_binding'),key='',entries={}}); Change(); SyncSelector(); Refresh()
        end)
        frame.RequestClose=function()
            if MayLeave('close',function() frame:Destroy() end) then frame:Destroy() end
        end
        frame.CanLeave=MayLeave
        if not embedded then Button(frame,'×',1038,8,30,frame.RequestClose) end
        Text(frame,T('hotbuild.editor.buildings'),24,136,18)
        Text(frame,T('hotbuild.editor.build_order_hint'),165,142,14,C.muted)
        for i,f in ipairs(factions) do
            local faction=f
            local texture,pixels=Theme.FactionIcon(faction,32*scale)
            local size=pixels/scale
            local icon=Bitmap(frame); icon:SetTexture(texture)
            L(icon):AtLeftTopIn(frame,190+(i-1)*247-size/2,173-size/2):Width(size):Height(size)
            Tooltip.AddAutoUpdatedControlTooltip(icon,function() return faction end,function() return '' end)
        end
        local cells,unitCells={},{}
        local visibleRows=4
        local peekHeight=14
        local viewport
        local Pick
        local function Tile(owner,x,y,kind,rowIndex,faction)
            local tile=Panel(owner,x,y,232,59,C.surface); local outline=Theme.Outline(tile,L,232,59)
            local icon=Panel(tile,8,8,42,42,C.canvas); icon:DisableHitTest()
            local title=Text(tile,'+',0,0,32,C.muted); L(title):AtCenterIn(tile)
            local labelArea=Group(tile); L(labelArea):AtLeftTopIn(tile,58,26):Width(166):Height(27); labelArea:DisableHitTest()
            local label=Text(labelArea,'',0,0,15); L(label):AtCenterIn(labelArea)
            local techArea=Group(tile); L(techArea):AtLeftTopIn(tile,58,4):Width(166):Height(23); techArea:DisableHitTest()
            local tech=UI.CreateText(techArea,'',16*ratio,Theme.Fonts.heading); tech.Depth:Set(function() return techArea.Depth()+2 end); tech:SetColor(C.accentText); tech:DisableHitTest(); L(tech):AtCenterIn(techArea)
            local badge=Panel(tile,153,4,70,18,C.selected); badge:DisableHitTest()
            local badgeOutline=Theme.Outline(badge,L,70,18,C.selectedBorder)
            local badgeText=Text(badge,T('hotbuild.editor.template'),0,0,9,C.accentText); L(badgeText):AtCenterIn(badge)
            badge:Hide()
            local data={control=tile,icon=icon,title=title,label=label,tech=tech,badge=badge,badgeOutline=badgeOutline,
                kind=kind,rowIndex=rowIndex,faction=faction,outline=outline}
            tile.HandleEvent=function(self,e)
                if e.Type=='MouseEnter' then outline(C.selectedBorder)
                elseif e.Type=='MouseExit' then outline(C.border)
                elseif e.Type=='ButtonPress' then
                    if not Writable() then return true end
                    local idx=data.kind=='STRUCTURE' and (buildingTop+data.rowIndex-1) or nil
                    local row=data.kind=='STRUCTURE' and grid.buildings[idx]
                        or (grid.units[data.kind] and grid.units[data.kind][faction])
                    if e.Modifiers and e.Modifiers.Right then
                        if data.kind=='STRUCTURE' and row and row[faction] then
                            row[faction]=nil; Change(); Refresh()
                        elseif data.kind~='STRUCTURE' and row and row[data.tier] then
                            row[data.tier]=nil; Change(); Refresh()
                        end
                    else
                        if data.kind=='STRUCTURE' then
                            BuildingLog('open',idx,faction,row and row[faction],table.getn(grid.buildings),visibleRows)
                        end
                        Pick(data.kind,idx,faction,data.tier)
                    end
                    return true
                end
                return true
            end
            Tooltip.AddAutoUpdatedControlTooltip(tile,function() return data.full or '' end,function() return '' end)
            data.kind=kind; data.rowIndex=rowIndex; data.tier=nil
            return data
        end
        local function UnitTile(owner,x,y,kind,faction)
            local tile=Panel(owner,x,y,232,72,C.canvas)
            local slots={}
            local tiers=kind=='GATE' and {'SACU'} or visibleUnitTiers
            for index,tier in ipairs(tiers) do
                local slotTier=tier
                local slotX=kind=='GATE' and 78 or (index-1)*78
                local cell=Panel(tile,slotX,0,76,72,C.surface)
                local outline=Theme.Outline(cell,L,76,72,C.border)
                local tierHeader=Group(cell)
                L(tierHeader):AtLeftTopIn(cell,0,0):Width(76):Height(14)
                local tierLabel=UI.CreateText(tierHeader,slotTier,11*ratio,Theme.Fonts.heading)
                tierLabel.Depth:Set(function() return tierHeader.Depth()+2 end)
                tierLabel:SetColor(C.muted); tierLabel:DisableHitTest(); L(tierLabel):AtCenterIn(tierHeader)
                local icon=Bitmap(cell); icon:DisableHitTest()
                L(icon):AtCenterIn(cell):Width(44):Height(44)
                local empty=Text(cell,'+',0,0,24,C.muted); L(empty):AtCenterIn(cell)
                local data={control=cell,tier=slotTier,tierLabel=tierLabel,icon=icon,empty=empty,outline=outline}
                cell.HandleEvent=function(self,e)
                    if e.Type=='MouseEnter' then
                        self:SetSolidColor(C.hover); outline(C.selectedBorder)
                    elseif e.Type=='MouseExit' then
                        self:SetSolidColor(C.surface); outline(C.border)
                    elseif e.Type=='ButtonPress' then
                        if not Writable() then return true end
                        if e.Modifiers and e.Modifiers.Right then
                            local row=grid.units[kind] or {}; local assigned=row[faction]
                            if kind=='GATE' and type(assigned)=='string' then
                                row[faction]=nil; Change(); Refresh()
                            elseif type(assigned)=='table' and assigned[slotTier] then
                                assigned[slotTier]=nil; Change(); Refresh()
                            end
                        else
                            local pickerTier
                            if kind~='GATE' then pickerTier=slotTier end
                            Pick(kind,nil,faction,pickerTier)
                        end
                        return true
                    end
                    return true
                end
                Tooltip.AddAutoUpdatedControlTooltip(cell,function() return data.full or slotTier end,function() return '' end)
                slots[slotTier]=data
            end
            return {control=tile,slots=slots,kind=kind,faction=faction}
        end
        viewport=Panel(frame,74,195,985,260+peekHeight,C.canvas)
        for row=1,6 do
            cells[row]={}
            for col,f in ipairs(factions) do cells[row][col]=Tile(viewport,0+(col-1)*247,(row-1)*65,'STRUCTURE',row,f) end
        end
        local peekMask=Panel(viewport,0,260+peekHeight,985,59-peekHeight,C.canvas)
        peekMask.Depth:Set(function() return viewport.Depth()+20 end)
        peekMask.HandleEvent=function(self,e)
            if e.Type=='WheelRotation' then return viewport.HandleEvent(viewport,e) end
            return true
        end
        local rowControls={}
        local function MoveBuildingRow(index,delta)
            local target=index+delta
            local count=table.getn(grid.buildings)
            if not Writable() or target<1 or target>count or index<1 or index>count then return end
            grid.buildings[index],grid.buildings[target]=grid.buildings[target],grid.buildings[index]
            Change(); Refresh()
        end
        local hoveredRowArrow
        local function RowArrow(owner,glyph,x,y,delta)
            local button=Panel(owner,x,y,24,24,C.raised)
            local outline=Theme.Outline(button,L,24,24)
            local label=Text(button,glyph,0,-1,18,C.muted); L(label):AtCenterIn(button)
            button.enabled=true
            local hovered=false
            local function ApplyStyle()
                button:SetSolidColor(not button.enabled and C.canvas or (hovered and C.hover or C.raised))
                outline(not button.enabled and C.canvas or (hovered and C.selectedBorder or C.border))
                label:SetColor(not button.enabled and C.disabled or (hovered and C.text or C.muted))
            end
            button.ClearHover=function()
                hovered=false
                button.hovered=false
                ApplyStyle()
            end
            button.applyStyle=ApplyStyle
            button.HandleEvent=function(self,e)
                if e.Type=='MouseEnter' and self.enabled then
                    if hoveredRowArrow and hoveredRowArrow~=button then hoveredRowArrow.ClearHover() end
                    hovered=true
                    button.hovered=true
                    hoveredRowArrow=button
                    ApplyStyle()
                elseif e.Type=='MouseExit' then
                    hovered=false
                    button.hovered=false
                    if hoveredRowArrow==button then hoveredRowArrow=nil end
                    ApplyStyle()
                elseif e.Type=='ButtonPress' and not (e.Modifiers and e.Modifiers.Right) then
                    if not self.enabled then return true end
                    local index=(s and s.buildingTop or buildingTop)+self.row
                    MoveBuildingRow(index,delta); return true
                end
                return true
            end
            Tooltip.AddAutoUpdatedControlTooltip(button,function()
                return T(delta<0 and 'hotbuild.editor.move_row_up' or 'hotbuild.editor.move_row_down')
            end,function() return '' end)
            return {control=button,label=label,outline=outline,delta=delta}
        end
        for row=1,6 do
            local num=Text(frame,'',28,195+(row-1)*65+20,13,C.muted)
            local up=RowArrow(frame,'↑',48,195+(row-1)*65+8,-1)
            local down=RowArrow(frame,'↓',48,195+(row-1)*65+34,1)
            rowControls[row]={number=num,up=up,down=down}
        end
        viewport.HandleEvent=function(self,e)
            if e.Type=='WheelRotation' then
                local max=math.max(1,table.getn(grid.buildings)-visibleRows+1)
                buildingTop=math.max(1,math.min(max,buildingTop+(e.WheelRotation>0 and -1 or 1)))
                -- Refresh reads the state stored on s; keep it in sync before redraw.
                if s then s.buildingTop=buildingTop end
                Refresh(); return true
            end
            return true
        end
        function viewport:GetScrollValues()
            local count=table.getn(grid.buildings)
            local top=s and s.buildingTop or buildingTop
            return 1,math.max(visibleRows,count),top,math.min(count,top+visibleRows-1)
        end
        function viewport:IsScrollable() return table.getn(grid.buildings)>visibleRows end
        function viewport:ScrollSetTop(axis,value)
            local count=table.getn(grid.buildings)
            local max=math.max(1,count-visibleRows+1)
            buildingTop=math.max(1,math.min(max,math.floor(value)))
            if s then s.buildingTop=buildingTop end
            Refresh()
        end
        function viewport:ScrollLines(axis,delta) self:ScrollSetTop(axis,buildingTop+delta) end
        function viewport:ScrollPages(axis,delta) self:ScrollLines(axis,delta*math.max(1,visibleRows-1)) end
        for row=1,6 do for col=1,4 do
            local tile=cells[row][col].control; local handle=tile.HandleEvent
            tile.HandleEvent=function(self,e)
                if e.Type=='WheelRotation' then return viewport.HandleEvent(viewport,e) end
                return handle(self,e)
            end
        end end
        local buildingScrollbar
        local unitHeading=Text(frame,T('hotbuild.editor.unit_orders'),24,498,18)
        unitHeading.Depth:Set(function() return viewport.Depth()+30 end)
        local unitLabels,unitFactionIcons={},{}
        for col,faction in ipairs(factions) do
            local texture,pixels=Theme.FactionIcon(faction,32*scale)
            local size=pixels/scale
            local icon=Bitmap(frame); icon:SetTexture(texture); icon:DisableHitTest()
            L(icon):AtLeftTopIn(frame,74+(col-1)*247+(232-size)/2,532-size/2):Width(size):Height(size)
            Tooltip.AddAutoUpdatedControlTooltip(icon,function() return faction end,function() return '' end)
            unitFactionIcons[col]=icon
        end
        for index,domain in ipairs(domains) do
            local y=528+(index-1)*92
            local heading=Group(frame); L(heading):AtLeftTopIn(frame,74,y):Width(973):Height(18)
            local label=UI.CreateText(heading,T('hotbuild.domain_header.'..string.lower(domain)),16*ratio,Theme.Fonts.heading)
            label.Depth:Set(function() return heading.Depth()+2 end)
            label:SetColor(C.text); label:DisableHitTest(); L(label):AtCenterIn(heading)
            heading:DisableHitTest(); unitLabels[domain]=heading
            unitCells[domain]={}
            for col,f in ipairs(factions) do
                unitCells[domain][col]=UnitTile(frame,74+(col-1)*247,y+24,domain,f)
            end
        end
        SaveDraft=function()
            if not Writable() then return end
            if not dirty then Status(T('hotbuild.common.no_changes')); return end
            if InvalidName(draft.name) then Status(T('hotbuild.common.name_ascii'),true); return end
            local candidate=CandidateForBinding(draft,grid)
            if compatibility then
                local checked,valid,message,details
                if service.ValidatePreset then checked,valid,message,details=pcall(service.ValidatePreset,service,candidate)
                else checked,valid,message,details=pcall(compatibility.ValidateBinding,candidate,service.contextModel,catalog) end
                if not checked then Status(T('hotbuild.editor.status.validate_failed'),true); return false end
                if checked and not valid then ShowCompatibilityDialog(tostring(message)); return false end
            end
            draft.grid=Clone(candidate.grid); draft.entries=Clone(candidate.entries)
            local saved,msg=service:Commit(draft)
            if saved then Load(service.model:Get(draft.id)); SyncSelector(); Refresh() end
            Status(saved and (msg or T('hotbuild.editor.status.saved_hint')) or msg,not saved)
            return saved
        end
        saveButton=Button(frame,T('hotbuild.common.save'),768,88,110,function() SaveDraft() end,true)
        saveButton.saveButton=true; saveButton.saveEnabled=false; saveButton:SetSolidColor(C.disabled)
        local keyHint=Text(frame,T('hotbuild.common.used_keys','—'),625,128,13,C.muted)
        -- Picker is created once per click and destroyed on selection/close.
        local popup, pickerOverlay
        ClosePopup=function()
            if popup then popup:Destroy(); popup=nil end
            if pickerOverlay then pickerOverlay:Destroy(); pickerOverlay=nil end
        end
        local pickerApplyState={
            eq=eq,catalog=catalog,entries=Entries,visibleRows=visibleRows,
            getGrid=function() return grid end,
            change=Change,closePopup=ClosePopup,status=Status,
            refresh=function() if Refresh then Refresh() end end,
        }
        local function PickCategory(r)
            if r.templateData then return T('hotbuild.editor.picker.templates') end
            local labels={'hotbuild.editor.picker.production','hotbuild.editor.picker.economy','hotbuild.editor.picker.defense','hotbuild.editor.picker.other_buildings','hotbuild.editor.picker.units'}
            return T(labels[Categories(r)])
        end
        Pick=function(kind,index,faction,tier)
            ClosePopup()
            local refreshTemplates=rawget(catalog,'RefreshTemplates')
            if refreshTemplates then catalog:RefreshTemplates() end
            pickerOverlay=Panel(frame,0,0,1080,920,'00000000'); pickerOverlay.Depth:Set(function() return frame.Depth()+90 end)
            pickerOverlay.HandleEvent=function(self,e)
                if e.Type=='ButtonPress' then ClosePopup() end
                return true
            end
            popup=Group(frame); L(popup):Width(720):Height(610):AtCenterIn(frame); popup.Depth:Set(function() return frame.Depth()+100 end)
            Theme.AnimateCentered(popup,frame,L)
            local backdrop=Panel(popup,0,0,720,610,C.surface); backdrop.Depth:Set(popup.Depth); backdrop.HandleEvent=function() return true end
            Theme.Outline(backdrop,L,720,610,C.selectedBorder)
            Text(popup,T('hotbuild.editor.choose_object',faction,tier and (' · '..tier) or ''),18,12,18)
            Text(popup,T(kind=='GATE' and 'hotbuild.editor.gate_hint' or 'hotbuild.editor.tier_hint'),18,39,12,C.muted)
            Button(popup,'×',682,8,30,ClosePopup)
            local search=SearchField(popup,18,64,684,80)
            local container=Panel(popup,18,105,662,478,C.canvas)
            local pool,found,top={}, {},1
            local function Render()
                local q=search.GetText and search:GetText() or ''
                local candidates=catalog:List({search='',faction=faction,kind=kind})
                found={}; q=Fold(q)
                for _,record in ipairs(candidates) do
                    if (not tier or UnitSlot(record.tech)==tier)
                        and (q=='' or string.find(Fold(TileName(record,displayCatalog)),q,1,true)
                        or string.find(Fold(record.search or record.name),q,1,true)
                        or (record.templateData and string.find(Fold(record.name),q,1,true))) then
                        table.insert(found,record)
                    end
                end
                table.sort(found,function(a,b)
                    if (a.templateData~=nil)~=(b.templateData~=nil) then return a.templateData~=nil end
                    local ta,tb=techRank[a.tech] or 5,techRank[b.tech] or 5
                    if ta~=tb then return ta<tb end
                    local ca,cb=Categories(a),Categories(b)
                    if ca~=cb then return ca<cb end
                    if a.name~=b.name then return a.name<b.name end
                    return a.id<b.id
                end)
                top=math.max(1,math.min(top,math.max(1,table.getn(found)-10)))
                for i,slot in ipairs(pool) do
                    local r=found[top+i-1]; slot.record=r
                    if r then
                        slot.control:Show(); slot.control:SetSolidColor(C.raised)
                        if slot.outline then slot.outline(r.templateData and C.accent or C.border) end
                        slot.icon:SetTexture(UI.UIFile(r.icon,true)); slot.title:SetText(TileName(r,displayCatalog))
                        slot.title:SetColor(r.templateData and C.accentText or C.text)
                        slot.meta:SetText(r.templateData and T('hotbuild.editor.template_count',table.getn(r.templateData)-2) or (r.tech..' · '..r.id))
                        slot.meta:SetColor(r.templateData and C.accentText or C.muted)
                    else slot.control:Hide() end
                end
            end
            function container:GetScrollValues(axis) return 1,math.max(11,table.getn(found)),top,top+10 end
            function container:ScrollSetTop(axis,value) top=math.floor(value); Render() end
            function container:ScrollLines(axis,delta) self:ScrollSetTop(axis,top+delta) end
            function container:ScrollPages(axis,delta) self:ScrollLines(axis,delta*11) end
            container.HandleEvent=function(self,e)
                if e.Type=='WheelRotation' then self:ScrollLines(nil,e.WheelRotation>0 and -1 or 1) end
                return true
            end
            UI.CreateVertScrollbarFor(container)
            local selection={kind=kind,index=index,faction=faction,tier=tier}
            local function Choose(record)
                ApplyPickerChoice(pickerApplyState,selection,record)
            end
            for i=1,11 do
                local slotIndex=i; local row=Panel(container,0,(i-1)*43,662,41,C.raised)
                local icon=Panel(row,4,3,35,35,C.canvas); icon:DisableHitTest()
                local title=Text(row,'',48,4,13); local meta=Text(row,'',48,23,10,C.muted)
                pool[i]={control=row,icon=icon,title=title,meta=meta,
                    outline=Theme.Outline(row,L,662,41,C.border)}
                row.HandleEvent=function(self,e)
                    if e.Type=='WheelRotation' then return container.HandleEvent(container,e) end
                    if e.Type=='MouseEnter' then self:SetSolidColor(C.hover)
                    elseif e.Type=='MouseExit' then self:SetSolidColor(C.raised)
                    elseif e.Type=='ButtonPress' and not (e.Modifiers and e.Modifiers.Right) and pool[slotIndex].record then Choose(pool[slotIndex].record); return true end
                    return true
                end
            end
            search.OnTextChanged=function() top=1; Render() end
            search:SetText(''); Render()
        end
        local function Draw(cell,id)
            local r=id and catalog:Get(id)
            cell.full=r and (r.name..' · '..r.id) or (id and T('hotbuild.common.unavailable',id) or T('hotbuild.common.empty_cell'))
            if r then
                cell.icon:SetTexture(UI.UIFile(r.icon,true)); cell.icon:Show(); cell.title:Hide()
                cell.label:SetText((r.templateData and '▧ ' or '')..TileName(r,displayCatalog)); cell.label:Show()
                if r.templateData then
                    cell.tech:Hide(); cell.badge:Show()
                else
                    cell.badge:Hide(); cell.tech:SetText(r.tech=='EXPERIMENTAL' and 'T4' or (r.tech=='OTHER' and '' or r.tech))
                    cell.tech:SetColor(C.accent); cell.tech:Show()
                end
                cell.outline(r.templateData and C.accent or C.border)
            else cell.badge:Hide(); cell.tech:Hide(); cell.label:Hide(); cell.icon:Hide(); cell.title:SetText(id and '?' or '+'); cell.title:Show() end
        end
        local function DrawUnit(cell,id)
            local record=id and catalog:Get(id)
            if record then
                cell.icon:SetTexture(UI.UIFile(record.icon,true)); cell.icon:Show(); cell.empty:Hide()
                cell.full=cell.tier..' · '..TileName(record,displayCatalog)..' · '..record.id
            else
                cell.icon:Hide(); cell.empty:SetText(id and '?' or '+'); cell.empty:Show()
                cell.full=cell.tier..' · '..(id and T('hotbuild.common.unavailable',id) or T('hotbuild.common.empty_cell'))
            end
        end
        s={tooltip=Tooltip,grid=grid,empty=Empty,visibleRows=visibleRows,peekHeight=peekHeight,buildingScrollbar=buildingScrollbar,
            layout=L,frame=frame,embedded=embedded,parent=parent,background=bg,viewport=viewport,
            unitHeading=unitHeading,unitLabels=unitLabels,unitFactionIcons=unitFactionIcons,unitCells=unitCells,unitTiers=visibleUnitTiers,
            service=service,short=Short,colors=C,compatibility=compatibility,draft=draft,keyHint=keyHint,statusText=status,
            buildingTop=buildingTop,rowControls=rowControls,writable=Writable,change=Change,draw=Draw,drawUnit=DrawUnit,
            cells=cells,domains=domains,factions=factions,name=name,nameOutline=nameOutline,invalidName=InvalidName,legacyIssue=legacyIssue,statusFn=Status}
        Refresh=function()
            s.tooltip.DestroyMouseoverDisplay()
            -- Keep exactly one trailing empty build row; additional rows appear as choices are made.
            local count=table.getn(s.grid.buildings)
            while count>1 and s.empty(s.grid.buildings[count]) do RemoveBuildingRow(s.grid.buildings,count); count=count-1 end
            if count==0 then EnsureBuildingRow(s.grid.buildings,1); count=1 end
            if not s.empty(s.grid.buildings[count]) and count<16 then EnsureBuildingRow(s.grid.buildings,count+1); count=count+1 end
            s.visibleRows=4; visibleRows=s.visibleRows
            local extra=(s.visibleRows-4)*65
            s.layout(s.frame):Height(920+extra)
            if not s.embedded then s.layout(s.frame):AtCenterIn(s.parent) end
            s.layout(s.background):Height(920+extra)
            s.layout(s.viewport):Height(s.visibleRows*65+s.peekHeight)
            s.layout(s.unitHeading):AtLeftTopIn(s.frame,24,498+extra)
            s.layout(s.keyHint):AtLeftTopIn(s.frame,625,128)
            local keyboard=s.service.keyboardBindings
            local assigned=s.draft and keyboard and keyboard.KeysFor and keyboard:KeysFor({kind='preset',id=s.draft.id}) or {}
            s.keyHint:SetText(s.short(T('hotbuild.common.used_keys',table.getn(assigned)>0 and table.concat(assigned,', ') or '—'),58))
            s.layout(s.statusText):AtLeftTopIn(s.frame,24,900+extra)
            s.buildingTop=math.max(1,math.min(s.buildingTop,math.max(1,count-s.visibleRows+1))); buildingTop=s.buildingTop
            if count>s.visibleRows then
                if s.buildingScrollbar and s.buildingScrollbar.Show then s.buildingScrollbar:Show() end
            elseif s.buildingScrollbar and s.buildingScrollbar.Hide then
                s.buildingScrollbar:Hide()
            end
            for row=1,6 do
                local data=s.grid.buildings[s.buildingTop+row-1] or {}
                local index=s.buildingTop+row-1
                local peek=row==s.visibleRows+1 and index<=16
                if row<=s.visibleRows then
                    s.layout(s.rowControls[row].number):AtLeftTopIn(s.frame,28,195+(row-1)*65+20)
                    s.rowControls[row].number:Show()
                elseif peek then
                    s.layout(s.rowControls[row].number):AtLeftTopIn(s.frame,28,195+(row-1)*65)
                    s.rowControls[row].number:Show()
                else
                    s.rowControls[row].number:Hide()
                end
                s.rowControls[row].number:SetText(string.format('%02d',index))
                s.rowControls[row].number:SetColor(s.empty(data) and s.colors.disabled or s.colors.accentText)
                local movable=row<=s.visibleRows
                for _,arrow in ipairs({s.rowControls[row].up,s.rowControls[row].down}) do
                    local target=index+arrow.delta
                    local enabled=movable and index<=table.getn(s.grid.buildings)
                        and target>=1 and target<=table.getn(s.grid.buildings)
                    local control=arrow.control
                    if movable then control:Show() else control:Hide() end
                    control.row=row-1
                    control.enabled=enabled
                    if not enabled and control==hoveredRowArrow then
                        hoveredRowArrow=nil
                        control.ClearHover()
                    end
                    control.applyStyle()
                end
                for col,f in ipairs(s.factions) do
                    if row<=s.visibleRows or peek then s.cells[row][col].control:Show(); s.draw(s.cells[row][col],data[f]) else s.cells[row][col].control:Hide() end
                end
            end
            for index,domain in ipairs(s.domains) do
                local y=528+(index-1)*92+extra
                s.layout(s.unitLabels[domain]):AtLeftTopIn(s.frame,74,y)
                for col,faction in ipairs(s.factions) do
                    local tile=s.unitCells[domain][col]
                    s.layout(tile.control):AtLeftTopIn(s.frame,74+(col-1)*247,y+24)
                    local assigned=(s.grid.units[domain] or {})[faction]
                    for _,tier in ipairs(domain=='GATE' and {'SACU'} or s.unitTiers) do
                        local slot=tile.slots[tier]
                        slot.tier=tier
                        s.drawUnit(slot,domain=='GATE' and assigned or (type(assigned)=='table' and assigned[tier] or nil))
                    end
                end
            end
            s.nameOutline(s.invalidName(s.name.GetText and s.name:GetText() or '') and s.colors.danger or s.colors.border)
            if s.legacyIssue then s.statusFn(T(s.legacyIssue)..' '..T('hotbuild.editor.status.create_binding'),true) end
        end
        local initial=memory.bindingId and service.model:Get(memory.bindingId)
        if not initial then
            local n=1; while service.model:Get('b'..n) do n=n+1 end
            initial={id='b'..n,name=T('hotbuild.editor.status.new_binding'),key='',entries={}}
        end
        Load(initial)
        buildingScrollbar=UI.CreateVertScrollbarFor(viewport)
        if buildingScrollbar and buildingScrollbar.Depth then
            buildingScrollbar.Depth:Set(function() return viewport.Depth()+3 end)
        end
        s.buildingScrollbar=buildingScrollbar
        SyncSelector(); Refresh()
        local problems=service.model:GetQuarantine()
        if table.getn(problems)>0 then
            s.statusFn(T('hotbuild.problems.summary',table.getn(problems),problems[1].reason),true)
        end
        frame.AfterParentShow=function() Refresh() end
    end)
    if not ok then frame:Destroy(); error(err) end
    return frame
end
