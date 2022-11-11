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
FillLevelManager = {}

------------------------------------------------------------------------------------------------------------------------
--- Fill Levels
---------------------------------------------------------------------------------------------------------------------------
function FillLevelManager.getAllFillLevels(object, fillLevelInfo)
    -- get own fill levels
    if object.getFillUnits then
        for index, fillUnit in pairs(object:getFillUnits()) do
            local supportedFillTypes = object:getFillUnitSupportedFillTypes(index)
            for fillType, _ in pairs(supportedFillTypes) do
                local fillTypeName = g_fillTypeManager:getFillTypeNameByIndex(fillType)
                --FillLevelManager:debugSparse('%s: Fill levels: %s: %.1f/%.1f', object:getName(), fillTypeName, fillUnit.fillLevel, fillUnit.capacity)
                if not fillLevelInfo[fillType] then fillLevelInfo[fillType] = {fillLevel = 0, capacity = 0} end
                fillLevelInfo[fillType].fillLevel = fillLevelInfo[fillType].fillLevel + fillUnit.fillLevel
                fillLevelInfo[fillType].capacity = fillLevelInfo[fillType].capacity + fillUnit.capacity
                --used to check treePlanter fillLevel
                local treePlanterSpec = object.spec_treePlanter
                if treePlanterSpec then
                    fillLevelInfo[fillType].treePlanterSpec = object.spec_treePlanter
                end
            end
        end
    end
    -- collect fill levels from all attached implements recursively
    for _,impl in pairs(object:getAttachedImplements()) do
        FillLevelManager.getAllFillLevels(impl.object, fillLevelInfo)
    end
end

function FillLevelManager.getFillTypeFromFillUnit(fillUnit)
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
        for _, fillUnit in pairs(object:getFillUnits()) do
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