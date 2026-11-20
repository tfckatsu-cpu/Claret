local previousOnCommandIssued = OnCommandIssued

function OnCommandIssued(command)
    local data = GetCommandMode()[2]
    local blueprint, army, count
    if command.CommandType == 'BuildMobile' and command.Units and not command.Units[1]
        and data and data.cheat and not data.callback and not data.prop and not data.MeshOnly then
        blueprint, army, count = data.unit or command.Blueprint, data.army, data.count
    end
    local result = previousOnCommandIssued(command)
    if blueprint then
        import('/mods/ClaretUI/modules/features/Notifications.lua').RecordCheatSpawn(army, blueprint, count)
    end
    return result
end
