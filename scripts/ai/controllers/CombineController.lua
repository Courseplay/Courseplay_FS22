--- For now only handles possible silage additives, if needed.
--- TODO: Straw swath handling should be moved here.
---@class CombineController : ImplementController
CombineController = CpObject(ImplementController)
function CombineController:init(vehicle, combine)
    ImplementController.init(self, vehicle, combine)
    self.combineSpec = combine.spec_combine
    self.settings = vehicle:getCpSettings()
    self.beaconLightsActive = false
    self.hasPipe = SpecializationUtil.hasSpecialization(Pipe, combine.specializations)
    self:fixDischargeDistanceForChopper()
end

function CombineController:update()
	if self.settings.useAdditiveFillUnit:getValue() then 
		--- If the silage additive is empty, then stop the driver.
        local additives = self.combineSpec.additives
        if additives.available then 
            if self.implement:getFillUnitFillLevelPercentage(additives.fillUnitIndex) <= 0 then 
				self:debug("Stopped Cp, as the additive fill unit is empty.")
                self.vehicle:stopCurrentAIJob(AIMessageErrorOutOfFill.new())
            end
        end
    end
end

function CombineController:getDriveData()
    local maxSpeed = nil 
    maxSpeed = self:updateThreshingDuringRain()
    self:updateBeaconLightsAndFullMessage()
    return nil, nil, nil, maxSpeed
end

function CombineController:getFillLevel()
    return self.implement:getFillUnitFillLevel(self.combineSpec.fillUnitIndex)
end

function CombineController:getFillLevelPercentage()
    return 100 * self.implement:getFillUnitFillLevel(self.combineSpec.fillUnitIndex) /
            self.implement:getFillUnitCapacity(self.combineSpec.fillUnitIndex)
end

function CombineController:getCapacity()
    return self.implement:getFillUnitCapacity(self.combineSpec.fillUnitIndex)
end

function CombineController:getFillUnitIndex()
    return self.combineSpec.fillUnitIndex
end

-------------------------------------------------------------
--- Combine 
-------------------------------------------------------------

function CombineController:updateThreshingDuringRain()
    local maxSpeed = nil 
    if self.implement:getIsThreshingDuringRain() and g_Courseplay.globalSettings.stopThreshingDuringRain:getValue() then 
        maxSpeed = 0
        self:setInfoText(InfoTextManager.WAITING_FOR_RAIN_TO_FINISH)
    else 
        self:clearInfoText(InfoTextManager.WAITING_FOR_RAIN_TO_FINISH)
    end
    return maxSpeed
end

function CombineController:updateBeaconLightsAndFullMessage()
    if self.hasPipe then
        --- Updates the beacon lights and the blinking hotspot.
        local dischargeNode = self.implement:getCurrentDischargeNode()
        if dischargeNode ~= nil then
            local fillLevel = self.implement:getFillUnitFillLevel(dischargeNode.fillUnitIndex)
            local capacity = self.implement:getFillUnitCapacity(dischargeNode.fillUnitIndex)
            if fillLevel ~= nil and fillLevel ~= math.huge then
                if fillLevel > 0.8 * capacity then
                    if not self.beaconLightsActive then
                        self.vehicle:setAIMapHotspotBlinking(true)
                        self.vehicle:setBeaconLightsVisibility(true)
                        self.beaconLightsActive = true
                    end
                else
                    if self.beaconLightsActive then
                        self.vehicle:setAIMapHotspotBlinking(false)
                        self.vehicle:setBeaconLightsVisibility(false)
                        self.beaconLightsActive = false
                    end
                end
            end
        end
    end
end

--- Callback from the drive strategy, if the swath needs to be disabled.
function CombineController:isStrawSwathDisabled()
    return self.driveStrategy.isStrawSwathDisabled and self.driveStrategy:isStrawSwathDisabled()
end

function CombineController:updateStrawSwath(isOnHeadland)
    if self:isStrawSwathDisabled() then 
        if self.combineSpec.isSwathActive then
            self:debug("Straw swath force disabled.")
            self:setStrawSwath(false)
        end
        return
    end

    local strawMode = self.settings.strawSwath:getValue()
    if self.combineSpec.isSwathActive then
        if strawMode == CpVehicleSettings.STRAW_SWATH_OFF or isOnHeadland and strawMode == CpVehicleSettings.STRAW_SWATH_ONLY_CENTER then
            self:setStrawSwath(false)
            self:debug('straw swath should be off!')
        end
    else
        if strawMode ~= CpVehicleSettings.STRAW_SWATH_OFF then
            if isOnHeadland and strawMode == CpVehicleSettings.STRAW_SWATH_ONLY_CENTER then
                return
            end
            self:debug('straw swath should be on!')
            self:setStrawSwath(true)
        end
    end
end

function CombineController:setStrawSwath(enable)
    local strawSwathCanBeEnabled = false
    local fruitType = g_fruitTypeManager:getFruitTypeIndexByFillTypeIndex(self.implement:getFillUnitFillType(self:getFillUnitIndex()))
    if fruitType ~= nil and fruitType ~= FruitType.UNKNOWN then
        local fruitDesc = g_fruitTypeManager:getFruitTypeByIndex(fruitType)
        if fruitDesc.hasWindrow then
            strawSwathCanBeEnabled = true
        end
        self.implement:setIsSwathActive(enable and strawSwathCanBeEnabled)
    end
end

-------------------------------------------------------------
--- Chopper
-------------------------------------------------------------

--- Make life easier for unloaders, increase chopper discharge distance
function CombineController:fixDischargeDistanceForChopper()
    local dischargeNode = self.implement:getCurrentDischargeNode()
    if self:isChopper() and dischargeNode and dischargeNode.maxDistance then
        local safeDischargeNodeMaxDistance = 40
        if dischargeNode.maxDistance < safeDischargeNodeMaxDistance then
            self:debug('Chopper maximum throw distance is %.1f, increasing to %.1f', dischargeNode.maxDistance, safeDischargeNodeMaxDistance)
            dischargeNode.maxDistance = safeDischargeNodeMaxDistance
        end
    end
end

function CombineController:isChopper()
    return self:getCapacity() > 10000000
end

function CombineController:updateChopperFillType()
    --- Not exactly sure what this does, but without this the chopper just won't move.
    --- Copied from AIDriveStrategyCombine:update()
    -- no pipe, no discharge node
    local capacity = 0
    local dischargeNode = self.implement:getCurrentDischargeNode()

    if dischargeNode ~= nil then
        capacity = self.implement:getFillUnitCapacity(dischargeNode.fillUnitIndex)
    end

    if capacity == math.huge then
        local rootVehicle = self.implement.rootVehicle

        if rootVehicle.getAIFieldWorkerIsTurning ~= nil and not rootVehicle:getAIFieldWorkerIsTurning() then
            local trailer = NetworkUtil.getObject(self.implement.spec_pipe.nearestObjectInTriggers.objectId)

            if trailer ~= nil then
                local trailerFillUnitIndex = self.implement.spec_pipe.nearestObjectInTriggers.fillUnitIndex
                local fillType = self.implement:getDischargeFillType(dischargeNode)

                if fillType == FillType.UNKNOWN then
                    fillType = trailer:getFillUnitFillType(trailerFillUnitIndex)

                    if fillType == FillType.UNKNOWN then
                        fillType = trailer:getFillUnitFirstSupportedFillType(trailerFillUnitIndex)
                    end

                    self.implement:setForcedFillTypeIndex(fillType)
                else
                    self.implement:setForcedFillTypeIndex(nil)
                end
            end
        end
    end
end
