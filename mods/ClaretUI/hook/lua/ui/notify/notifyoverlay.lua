local previousProcessNotification = processNotification

function processNotification(sender, message)
    local infoShare = import('/mods/ClaretUI/modules/features/InfoShare.lua')
    if infoShare.ReceiveNotify(sender, message) then
        local overlay = overlays[message.data.id]
        if overlay then
            overlays[message.data.id] = nil
            overlay:Destroy()
        end
        return
    end
    previousProcessNotification(sender, message)
end
