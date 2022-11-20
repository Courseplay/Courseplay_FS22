--- Controller for sprayers and fertilizer spreaders
--- Main motivation as of now is to turn the sprayer off while the vehicle is not moving
--- for whatever reason, for instance in a convoy waiting to start.
---@class SprayerController : ImplementController
SprayerController = CpObject(ImplementController)

--- Dummy placeholder for now
function SprayerController:init(vehicle, sprayer)
    self.sprayer = sprayer
    ImplementController.init(self, vehicle, self.sprayer)
end

local function processSprayerArea(sprayer, superFunc, ...)
    local rootVehicle = sprayer.rootVehicle
    if rootVehicle.getIsCpActive and rootVehicle:getIsCpActive() then
        local specSpray = sprayer.spec_sprayer
        local sprayerParams = specSpray.workAreaParameters
        --- If the vehicle is standing, them disable the sprayer.
        if rootVehicle:getLastSpeed() < 0.1 then
            sprayerParams.sprayFillLevel = 0
        end
    end
    return superFunc(sprayer, ...)
end
Sprayer.processSprayerArea = Utils.overwrittenFunction(Sprayer.processSprayerArea, processSprayerArea)