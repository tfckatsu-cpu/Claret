local previousReceiveChat = ReceiveChat

function ReceiveChat(sender, data)
    previousReceiveChat(sender, data)
    if type(data) ~= 'table' then return end
    if data.NotifyOverlay == true or data.Chat == true and data.to == 'notify' then
        import('/mods/ClaretUI/modules/features/InfoShare.lua').ReceiveNotify(sender, data)
    end
end
