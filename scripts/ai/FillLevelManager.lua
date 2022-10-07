--[[
This file is part of Courseplay (https://github.com/Courseplay/courseplay)
Copyright (C) 2019 Peter Vaiko

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

--- Keeps track of all fill types/levels of a vehicle and attached implements
---@class FillLevelManager
FillLevelManager = CpObject()

function FillLevelManager:init(vehicle, debugChannel)
    self.vehicle = vehicle
    self.settings = vehicle:getCpSettings()
    self.debugChannel = debugChannel or CpDebug.DBG_IMPLEMENTS
    self.lastTotalFillLevel = math.huge
end

function FillLevelManager:debug(...)
    CpUtil.debugVehicle(self.debugChannel, self.vehicle, ...)
end

function FillLevelManager:debugSparse(...)
    if g_updateLoopIndex % 100 == 0 then
        self:debug(...)
    end
end

function FillLevelManager.needsRefill()
    local fillLevelInfo = {}
    FillLevelManager.getAllFillLevels(self.vehicle, fillLevelInfo)
    return FillLevelManager.areFillLevelsOk(fillLevelInfo)
end


-- is the fill level ok to continue? With fillable tools we need to stop working when we are out
-- of material (seed, fertilizer, etc.)
function FillLevelManager.areFillLevelsOk(fillLevelInfo, isWaitingForRefill)
    local self = FillLevelManager
    local allOk = true
    local hasSeeds, hasNoFertilizer = false, false
    local liquidFertilizerFillLevel,herbicideFillLevel, seedsFillLevel, fertilizerFillLevel = 0, 0, 0, 0

    if not self.settings.sowingMachineFertilizerEnabled:getValue() and AIUtil.hasAIImplementWithSpecialization(self.vehicle, FertilizingCultivator) then
        -- TODO_22 courseplay:setInfoText(self.vehicle, "skipping loading Seeds/Fertilizer and continue with Cultivator !!!")
        return true
    end
    local totalFillLevel = 0
    for fillType, info in pairs(fillLevelInfo) do
        if info.treePlanterSpec then -- is TreePlanter
            --check fillLevel of pallet on top of treePlanter or if their is one pallet
            if not info.treePlanterSpec.mountedSaplingPallet or not info.treePlanterSpec.mountedSaplingPallet:getFillUnitFillLevel(1) then
                allOk = false
            end
        else
            if self.isValidFillType(nil, fillType) and info.fillLevel == 0 and info.capacity > 0 and not self.helperBuysThisFillType(fillType) then
                allOk = false
                if fillType == FillType.FERTILIZER or fillType == FillType.LIQUIDFERTILIZER then hasNoFertilizer = true end
            else
                if fillType == FillType.SEEDS then hasSeeds = true end
            end
            if fillType == FillType.FERTILIZER or fillType == FillType.LIQUIDFERTILIZER then
                fertilizerFillLevel = fertilizerFillLevel + info.fillLevel
            elseif fillType == FillType.SEEDS then
                seedsFillLevel = seedsFillLevel + info.fillLevel
            end
            if fillType == FillType.LIQUIDFERTILIZER then liquidFertilizerFillLevel = info.fillLevel end
            if fillType == FillType.HERBICIDE then  herbicideFillLevel = info.fillLevel end
        end
        totalFillLevel = totalFillLevel + info.fillLevel
    end
    -- special handling for extra frontTanks as they seems to change their fillType random
    -- if we don't have a seeds and either liquidFertilizer or herbicide just continue until both are empty
    if not allOk and not fillLevelInfo[FillType.SEEDS] and(liquidFertilizerFillLevel > 0 or herbicideFillLevel > 0) then
        self:debugSparse('we probably have an empty front tank')
        allOk = true
    end
    -- special handling for sowing machines with fertilizer
    if not allOk and self.vehicle.cp.settings.sowingMachineFertilizerEnabled:is(false) and hasNoFertilizer and hasSeeds then
        self:debugSparse('Has no fertilizer but has seeds so keep working.')
        allOk = true
    end
    -- special check if the needed fillTypes for sowing are there but a fillUnit is empty
    if not allOk and self.vehicle.cp.settings.sowingMachineFertilizerEnabled:is(true) and fertilizerFillLevel > 0 and seedsFillLevel > 0 then
        self:debugSparse('Sowing machine has fertilizer and seeds but there is another empty fillUnit')
        allOk = true
    end
    --check if fillLevel changed, refill on Field
    if isWaitingForRefill then
        allOk = allOk and self.lastTotalFillLevel >= totalFillLevel
    end
    self.lastTotalFillLevel = totalFillLevel
    return allOk
end

--- Does the helper buy this fill unit (according to the game settings)? If yes, we don't have to stop or refill when empty.
function FillLevelManager.helperBuysThisFillType(fillType)
    if g_currentMission.missionInfo.helperBuySeeds and fillType == FillType.SEEDS then
        return true
    end
    if g_currentMission.missionInfo.helperBuyFertilizer and
            (fillType == FillType.FERTILIZER or fillType == FillType.LIQUIDFERTILIZER) then
        return true
    end
    -- Check for source as in Sprayer:getExternalFill()
    -- Source 1 - helper refill off, 2 - helper buys, > 2 - farm sources (manure heap, etc.)
    if fillType == FillType.MANURE then
        if  g_currentMission.missionInfo.helperManureSource == 2 then
            -- helper buys
            return true
        elseif g_currentMission.missionInfo.helperManureSource > 2 then
        else
            -- maure heaps
            local info = g_currentMission.manureHeaps[g_currentMission.missionInfo.helperManureSource - 2]
            if info ~= nil then -- Can be nil if pen was removed
                if info.manureHeap:getManureLevel() > 0 then
                    return true
                end
            end
            return false
        end
    elseif fillType == FillType.LIQUIDMANURE or fillType == FillType.DIGESTATE then
        if g_currentMission.missionInfo.helperSlurrySource == 2 then
            -- helper buys
            return true
        elseif g_currentMission.missionInfo.helperSlurrySource > 2 then
            --
            local info = g_currentMission.liquidManureTriggers[g_currentMission.missionInfo.helperSlurrySource - 2]
            if info ~= nil then -- Can be nil if pen was removed
                if info.silo:getFillLevel(FillType.LIQUIDMANURE) > 0 then
                    return true
                end
            end
            return true
        end
    end
    if g_currentMission.missionInfo.helperBuyFuel and self.isValidFuelType(FillLevelManager.vehicle, fillType) then
        return true
    end
    return false
end


------------------------------------------------------------------------------------------------------------------------
--- Fill Levels
---------------------------------------------------------------------------------------------------------------------------
function FillLevelManager.getAllFillLevels(object, fillLevelInfo)
    -- get own fill levels
    if object.getFillUnits then
        for _, fillUnit in pairs(object:getFillUnits()) do
            local fillType = FillLevelManager.getFillTypeFromFillUnit(fillUnit)
            local fillTypeName = g_fillTypeManager:getFillTypeNameByIndex(fillType)
            FillLevelManager:debugSparse('%s: Fill levels: %s: %.1f/%.1f', object:getName(), fillTypeName, fillUnit.fillLevel, fillUnit.capacity)
            if not fillLevelInfo[fillType] then fillLevelInfo[fillType] = {fillLevel=0, capacity=0} end
            fillLevelInfo[fillType].fillLevel = fillLevelInfo[fillType].fillLevel + fillUnit.fillLevel
            fillLevelInfo[fillType].capacity = fillLevelInfo[fillType].capacity + fillUnit.capacity
            --used to check treePlanter fillLevel
            local treePlanterSpec = object.spec_treePlanter
            if treePlanterSpec then
                fillLevelInfo[fillType].treePlanterSpec = object.spec_treePlanter
            end
        end
    end
    -- collect fill levels from all attached implements recursively
    for _,impl in pairs(object:getAttachedImplements()) do
        self:getAllFillLevels(impl.object, fillLevelInfo)
    end
end

function FillLevelManager:getFillTypeFromFillUnit(fillUnit)
    local fillType = fillUnit.lastValidFillType or fillUnit.fillType
    -- TODO: do we need to check more supported fill types? This will probably cover 99.9% of the cases
    if fillType == FillType.UNKNOWN then
        -- just get the first valid supported fill type
        for ft, valid in pairs(fillUnit.supportedFillTypes) do
            if valid then return ft end
        end
    else
        return fillType
    end
end

--- Gets the complete fill level and capacity without fuel,
---@param object table
---@return number totalFillLevel
---@return number totalCapacity
function FillLevelManager.getTotalFillLevelAndCapacity(object)

    local fillLevelInfo = {}
    FillLevelManager.getAllFillLevels(object, fillLevelInfo)

    local totalFillLevel = 0
    local totalCapacity = 0
    for fillType, data in pairs(fillLevelInfo) do
        if FillLevelManager.isValidFillType(object,fillType) then
            totalFillLevel = totalFillLevel  + data.fillLevel
            totalCapacity = totalCapacity + data.capacity
        end
    end
    return totalFillLevel,totalCapacity
end

--- Gets the complete fill level and capacity without fuel for a single fillType
---@param object table
---@param fillTypeToFilter number fillTypeIndex to check for
---@return number totalFillLevel
---@return number totalCapacity

function FillLevelManager.getTotalFillLevelAndCapacityForFillType(object, fillTypeToFilter)
    local fillLevelInfo = {}
    FillLevelManager.getAllFillLevels(object, fillLevelInfo)

    local totalFillLevel = 0
    local totalCapacity = 0
    for fillType, data in pairs(fillLevelInfo) do
        if FillLevelManager.isValidFillType(object, fillType) and fillType == fillTypeToFilter then
            totalFillLevel = totalFillLevel + data.fillLevel
            totalCapacity = totalCapacity + data.capacity
        end
    end

    return totalFillLevel, totalCapacity
end

--- Gets the total fill level percentage.
---@param object table
function FillLevelManager.getTotalFillLevelPercentage(object)
    local fillLevel,capacity = FillLevelManager.getTotalFillLevelAndCapacity(object)
    return 100 * fillLevel / capacity
end

function FillLevelManager.getTotalFillLevelAndCapacityForObject(object)
    local totalFillLevel = 0
    local totalCapacity = 0
    if object.getFillUnits then
        for index, fillUnit in pairs(object:getFillUnits()) do
            local fillType = FillLevelManager.getFillTypeFromFillUnit(fillUnit)
            if FillLevelManager.isValidFillType(object, fillType) then
                totalFillLevel = totalFillLevel + fillUnit.fillLevel
                totalCapacity = totalCapacity + fillUnit.capacity
            end
        end
    end
    return totalFillLevel, totalCapacity
end

---@param object table
---@param fillType number
function FillLevelManager.isValidFillType(object, fillType)
    --- Ignore silage additives for now. 
    --- TODO: maybe implement a setting if it is necessary to enable/disable detection.
    local spec = object.spec_combine or object.spec_forageWagon 
    if spec and spec.additives and spec.additives.fillUnitIndex then 
        local f = object:getFillUnitFillType(spec.additives.fillUnitIndex)
        if f == fillType then
            return false
        end
    end

    return not FillLevelManager.isValidFuelType(object, fillType) and fillType ~= FillType.DEF and fillType ~= FillType.AIR
end

--- Is the fill type fuel ?
---@param object table
---@param fillType number
---@param fillUnitIndex number
function FillLevelManager.isValidFuelType(object, fillType, fillUnitIndex)
    if object and object.getConsumerFillUnitIndex then
        local index = object:getConsumerFillUnitIndex(fillType)
        if fillUnitIndex ~= nil then
            return fillUnitIndex and fillUnitIndex == index
        end
        return index
    end
end

--- Gets the fill level of an mixerWagon for a fill type.
---@param object table
---@param fillType number
function FillLevelManager.getMixerWagonFillLevelForFillTypes(object, fillType)
    local spec = object.spec_mixerWagon
    if spec then
        for _, data in pairs(spec.mixerWagonFillTypes) do
            if data.fillTypes[fillType] then
                return data.fillLevel
            end
        end
    end
end

----------------------------------------------------------------------------------------------------------
--- Trailer util functions.
----------------------------------------------------------------------------------------------------------

--- Can load this fill type into the trailer?
---@param trailer table
---@param fillType number
---@return boolean true if this trailer has capacity for fill type
---@return number free capacity
---@return number fill unit index
function FillLevelManager.canLoadTrailer(trailer, fillType)
    if fillType then
        local fillUnits = trailer:getFillUnits()
        for i = 1, #fillUnits do
            local supportedFillTypes = trailer:getFillUnitSupportedFillTypes(i)
            local freeCapacity =  trailer:getFillUnitFreeCapacity(i)
            if supportedFillTypes[fillType] and freeCapacity > 0 then
                return true, freeCapacity, i
            end
        end
    end
    return false, 0
end

--- Are all trailers full?
---@param vehicle table
---@param fullThresholdPercentage number optional threshold, if fill level in percentage is greater than the threshold,
--- consider trailers full
---@return boolean
function FillLevelManager.areAllTrailersFull(vehicle, fullThresholdPercentage)
    local totalFillLevel, totalCapacity, totalFreeCapacity =  FillLevelManager.getAllTrailerFillLevels(vehicle)
    local fillLevelPercentage = 100 * totalFillLevel / totalCapacity
    return totalFreeCapacity <= 0 or fillLevelPercentage >= (fullThresholdPercentage or 100)
end

--- Gets the total fill level percentage and total fill level percentage adjusted to the max fill volume mass adjusted.
---@param vehicle table
---@return number total fill level percentage in %
---@return number total fill level percentage in % relative to max mass adjusted capacity.
function FillLevelManager.getTotalTrailerFillLevelPercentage(vehicle)
    local totalFillLevel, totalCapacity, totalCapacityMassAdjusted =  FillLevelManager.getAllTrailerFillLevels(vehicle)
    return 100 * totalFillLevel / totalCapacity, 100 * totalFillLevel / totalCapacityMassAdjusted
end

--- Gets the total fill level, capacity and mass adjusted capacity of all trailers.
---@param vehicle table
---@return number total fill level 
---@return number total capacity
---@return number total free capacity
function FillLevelManager.getAllTrailerFillLevels(vehicle)
    local totalFillLevel, totalCapacity, totalFreeCapacity = 0, 0, 0
    local trailers = AIUtil.getAllChildVehiclesWithSpecialization(vehicle, Trailer, nil)
    for i, trailer in ipairs(trailers) do 
        local fillLevel, capacity, freeCapacity = FillLevelManager.getTrailerFillLevels(trailer)
        totalFreeCapacity = totalFreeCapacity + freeCapacity
        totalFillLevel = totalFillLevel + fillLevel
        totalCapacity = totalCapacity + capacity
    end
    return totalFillLevel, totalCapacity, totalFreeCapacity
end

--- Gets the total fill level, capacity and mass adjusted capacity of a trailer.
---@param trailer table
---@return number total fill level 
---@return number total capacity
---@return number total free capacity
function FillLevelManager.getTrailerFillLevels(trailer)
    local totalFillLevel, totalCapacity, totalFreeCapacity = 0, 0, 0
    local spec = trailer.spec_dischargeable
    local fillUnitsUsed = {}
    for i, dischargeNode in pairs( spec.dischargeNodes) do 
        local fillUnitIndex = dischargeNode.fillUnitIndex
        if not fillUnitsUsed[fillUnitIndex] then
            totalFreeCapacity = totalFreeCapacity + trailer:getFillUnitFreeCapacity(fillUnitIndex)
            totalFillLevel = totalFillLevel + trailer:getFillUnitFillLevel(fillUnitIndex)
            totalCapacity = totalCapacity + trailer:getFillUnitCapacity(fillUnitIndex)
            fillUnitsUsed[fillUnitIndex] = true
        end
    end
    return totalFillLevel, totalCapacity, totalFreeCapacity
end