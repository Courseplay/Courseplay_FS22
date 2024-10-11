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
    self.refillData = {
		timer = CpTemporaryObject(true),
		hasChanged = false,
		lastFillLevels = {
			[self.implement] = {
				[self.implement:getSprayerFillUnitIndex()] = -1 
			}
		}
	}
    for _, supportedSprayType in ipairs(self.sprayerSpec.supportedSprayTypes) do
        for _, src in ipairs(self.sprayerSpec.fillTypeSources[supportedSprayType]) do
            self:debug("Found additional tank for refilling: %s|%d", src.vehicle, src.fillUnitIndex)
            if not self.refillData.lastFillLevels[src.vehicle] then 
                self.refillData.lastFillLevels[src.vehicle] = {}
            end
            self.refillData.lastFillLevels[src.vehicle][src.fillUnitIndex] = -1
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
end

function SprayerController:onStartRefilling(ignore) 
	if self:needsRefilling() then 
		if self.implement.aiPrepareLoading ~= nil then
			self.implement:aiPrepareLoading(self.implement:getSprayerFillUnitIndex())
		end
        for _, supportedSprayType in ipairs(self.sprayerSpec.supportedSprayTypes) do
            for _, src in ipairs(self.sprayerSpec.fillTypeSources[supportedSprayType]) do
                if src.vehicle.aiPrepareLoading ~= nil then
                    src.vehicle:aiPrepareLoading(src.fillUnitIndex)
                end
            end
        end
	end
    ImplementUtil.hasFillLevelChanged(self.refillData.lastFillLevels, true)
    self.refillData.hasChanged = false
end

function SprayerController:onUpdateRefilling()
	if ImplementUtil.tryAndCheckRefillingFillUnits(self.refillData.lastFillLevels) or 
		ImplementUtil.hasFillLevelChanged(self.refillData.lastFillLevels) then 
        self:debugSparse("Waiting for refilling to finish ..")
		self.refillData.timer:set(false, 10 * 1000)
        self.refillData.hasChanged = true
	end
	return self.refillData.timer:get(), self.refillData.hasChanged
end

function SprayerController:onStopRefilling()
    if self.implement.aiFinishLoading ~= nil then
        self.implement:aiFinishLoading()
    end
    local spec = self.implement.spec_fillUnit
	if spec.fillTrigger.isFilling then 
		self.implement:setFillUnitIsFilling(false)
	end
    for _, supportedSprayType in ipairs(self.sprayerSpec.supportedSprayTypes) do
        for _, src in ipairs(self.sprayerSpec.fillTypeSources[supportedSprayType]) do
            if src.vehicle.aiFinishLoading ~= nil then
                src.vehicle:aiFinishLoading()
            end
            spec = src.vehicle.spec_fillUnit
            if spec.fillTrigger.isFilling then 
                src.vehicle:setFillUnitIsFilling(false)
            end
        end
    end
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