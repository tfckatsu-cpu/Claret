local cinema = import('/mods/ClaretCinema/modules/Runtime.lua')
local previousCreateUI = CreateUI

function CreateUI(isReplay)
    local dispose = cinema.Start(isReplay)
    if dispose then AddOnUIDestroyedFunction(dispose) end
    return previousCreateUI(isReplay)
end
