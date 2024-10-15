--- Controller for sprayers and fertilizer spreaders
--- Main motivation as of now is to turn the sprayer off while the vehicle is not moving
--- for whatever reason, for instance in a convoy waiting to start.
---@class SprayerController : ImplementController
SprayerController = CpObject(ImplementController)

--- Dummy placeholder for now
function SprayerController:init(vehicle, sprayer)
    self.sprayer = sprayer
    self.sprayerSpec = sprayer.spec_sprayer
    ImplementController.init(self, vehicle, self.sprayer)
    self:addRefillImplementAndFillUnit(self.implement, self.implement:getSprayerFillUnitIndex())
    for _, supportedSprayType in ipairs(self.sprayerSpec.supportedSprayTypes) do
        for _, src in ipairs(self.sprayerSpec.fillTypeSources[supportedSprayType]) do
            self:debug("Found additional tank for refilling: %s|%d", src.vehicle, src.fillUnitIndex)
            self:addRefillImplementAndFillUnit(src.vehicle, src.fillUnitIndex)
        end
    end
end

-------------------------
--- Refill handling
-------------------------

function SprayerController:needsRefilling()
    if self.sprayerSpec.isSlurryTanker and g_currentMission.missionInfo.helperSlurrySource > 1 or 
        self.sprayerSpec.isManureSpreader and g_currentMission.missionInfo.helperManureSource > 1 or 
        self.sprayerSpec.isFertilizerSprayer and g_currentMission.missionInfo.helperBuyFertilizer then 
             
        return false
    end
    ImplementUtil.hasFillLevelChanged(self.refillData.lastFillLevels)
    for implement, data in pairs(self.refillData.lastFillLevels) do 
        for fillUnitIndex, fillLevel in pairs(data) do
            if fillLevel <= 0 then 
                return true
            end
        end
    end
    return false
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