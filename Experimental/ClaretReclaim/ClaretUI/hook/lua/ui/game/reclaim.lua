local Feed = import('/mods/ClaretUI/modules/ReclaimFeed.lua')
local Capture = not Feed.Conflicts()
local PreviousUpdateReclaim = UpdateReclaim
local PreviousSetPlayableArea = SetPlayableArea
local PreviousToggleReclaim = ToggleReclaim
local PreviousCommandGraph = OnCommandGraphShow

function UpdateReclaim(points)
    if Capture then Feed.Receive(points) end
    return PreviousUpdateReclaim(points)
end

function SetPlayableArea(rect)
    if Capture then Feed.SetArea(rect) end
    return PreviousSetPlayableArea(rect)
end

function ToggleReclaim()
    if not Feed.Toggle() then return PreviousToggleReclaim() end
end

function OnCommandGraphShow(shown)
    if not Feed.CommandGraph(shown) then return PreviousCommandGraph(shown) end
end

-- The overlay owns only the presentation while it is enabled.
function ClaretReleaseNativeReclaim()
    PreviousCommandGraph(false)
    ShowReclaim(false)
end

function ClaretRestoreNativeReclaim(pinned)
    if pinned then
        ShowReclaim(true)
    elseif Feed.State().graph then
        PreviousCommandGraph(true)
    end
end
