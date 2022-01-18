---@class HudButton
HudOverlayButton = {}
local HudOverlayButton_mt = Class(HudOverlayButton, Overlay)

function HudOverlayButton.new(overlayFilename, x, y, width, height, customMt)
    if customMt == nil then
        customMt = HudOverlayButton_mt
    end
    local self = Overlay.new(overlayFilename, x, y, width, height, customMt)
    return self
end

