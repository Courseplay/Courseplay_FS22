--[[
This file is part of Courseplay (https://github.com/Courseplay/courseplay)
Copyright (C) 2021 Peter Vaiko

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

--[[

A wrapper :) for the standard Bale object

--]]

---@class BaleToCollect
BaleToCollect = CpObject()

---@param baleObject : Bale
function BaleToCollect:init(baleObject)
	self.bale = baleObject
	local x, _, z = getWorldTranslation(self.bale.nodeId)
	-- TODO_22: this does not find bales on merged fields, but finds them if they are on the
	-- field border too (just off the field)
	self.fieldId = CpFieldUtil.getFieldIdAtWorldPosition(x, z)
end

--- Call this before attempting to construct a BaleToCollect to check the validity of the object
---@param object table Bale
---@param baleWrapper table bale wrapper, if exists
---@param baleLoader table bale loader, if exists
---@param baleWrapType number bale wrap type for the bale loader
function BaleToCollect.isValidBale(object, baleWrapper, baleLoader, baleWrapType)
	-- nodeId is sometimes 0, causing issues for the BaleToCollect constructor
	if object.isa and object:isa(Bale) and object.nodeId and entityExists(object.nodeId) then
		if baleWrapper then
			-- if there is a bale wrapper, the bale must be wrappable
			return baleWrapper:getIsBaleWrappable(object)
		elseif baleLoader and baleLoader.getBaleTypeByBale then
			local baleType = baleLoader:getBaleTypeByBale(object)
			local spec = baleLoader.spec_baleLoader
			if spec and baleType ~= nil then 
				local isValid = true
				--- Avoid bale types, that can't be loaded.
				if baleType ~= spec.currentBaleType and baleLoader:getFillUnitFillLevel(spec.currentBaleType.fillUnitIndex) ~= 0 then
					isValid = false
				end
				if baleWrapType == CpBaleFinderJobParameters.ONLY_WRAPPED_BALES then
					return isValid and object.wrappingState > 0, object.wrappingState > 0
				elseif baleWrapType == CpBaleFinderJobParameters.ONLY_NOT_WRAPPED_BALES then
					return isValid and object.wrappingState <= 0, object.wrappingState <= 0
				end	
				return isValid		
			end		
			return false
		else
			return true
		end
	end
end

function BaleToCollect:isStillValid()
	return BaleToCollect.isValidBale(self.bale) and not self:isLocked()
end

function BaleToCollect:isLoaded()
	return self.bale.mountObject or
	--- Loaded by this mod: FS22_aPalletAutoLoader from Achimobil: https://bitbucket.org/Achimobil79/ls22_palletautoloader/src/master/
	self.bale.currentlyLoadedOnAPalletAutoLoaderId ~= nil
end

function BaleToCollect:getFieldId()
	return self.fieldId
end

function BaleToCollect:getId()
	return self.bale.id
end

function BaleToCollect:getFillType()
	return self.bale:getFillType()
end

function BaleToCollect:getIsFermenting()
	return self.bale:getIsFermenting()
end

function BaleToCollect:getFillTypeInfo(...)
	return self.bale:getFillTypeInfo(...)
end

function BaleToCollect:getBaleObjectId()
	return NetworkUtil.getObjectId(self.bale)
end

function BaleToCollect:getBaleObject()
	return self.bale
end

function BaleToCollect:isLocked()
	return not g_baleToCollectManager:isValidBale(self.bale)
end

function BaleToCollect:getPosition()
	return getWorldTranslation(self.bale.nodeId)
end

---@return number, number, number, number x, z, direction from node, distance from node
function BaleToCollect:getPositionInfoFromNode(node)
	local xb, _, zb = self:getPosition()
	local x, _, z = getWorldTranslation(node)
	local dx, dz = xb - x, zb - z
	local yRot = MathUtil.getYRotationFromDirection(dx, dz)
	return xb, zb, yRot, math.sqrt(dx * dx + dz * dz)
end

function BaleToCollect:getPositionAsState3D()
	local xb, _, zb = self:getPosition()
	local _, yRot, _ = getWorldRotation(self.bale.nodeId)
	return State3D(xb, -zb, CourseGenerator.fromCpAngle(yRot))
end

--- Minimum distance from the bale's center (node) to avoid hitting the bale
--- when driving by in any direction
function BaleToCollect:getSafeDistance()
	-- round bales don't have length, just diameter
	local length = self.bale.isRoundBale and self.bale.diameter or self.bale.length
	-- no matter what kind of bale, the footprint is a rectangle, get the diagonal (which, is BTW, not
	-- exact math as it depends on the angle we are approaching the bale, so add a little buffer instead of
	-- thinking about the math...
	return math.sqrt(length * length + self.bale.width * self.bale.width) / 2 + 0.2
end

--- This Manager makes sure that bale finders on the same field
--- are not picking the same target bales or trying to load bales 
--- from another autoload trailer, 
--- as these bale are not automatically locked, 
--- like the base game bale collector wagons.  
---@class BaleToCollectManager
BaleToCollectManager = CpObject()
BaleToCollectManager.lockTimeOutMs = 500 -- 500 ms

function BaleToCollectManager:init()
	self.temporarilyLeasedBales = {}
	self.lockedBales = {}
end

function BaleToCollectManager:update(dt)
	for bale, time in pairs(self.temporarilyLeasedBales) do 
		if time < (g_time + self.lockTimeOutMs) then 
			self.temporarilyLeasedBales[bale] = nil
		end
	end
end

function BaleToCollectManager:draw()
	
end

--- Disables the bale object temporarily.
---@param bale table
function BaleToCollectManager:temporarilyLeaseBale(bale)
	self.temporarilyLeasedBales[bale] = g_time
end

--- Disables the bale until it is released.
---@param bale table
function BaleToCollectManager:lockBale(bale, driver)
	self.lockedBales[bale] = driver
end

---@param bale table
function BaleToCollectManager:unlockBale(bale)
	self.lockedBales[bale] = nil
end

---@param driver table
function BaleToCollectManager:unlockBalesByDriver(driver)
	for bale, d in pairs(self.lockedBales) do 
		if driver == d then 
			self.lockedBales[bale] = nil
		end
	end
end

--- Is the bale not leased or locked by another driver? 
---@param bale table
function BaleToCollectManager:isValidBale(bale)
	return not self.temporarilyLeasedBales[bale] and not self.lockedBales[bale]
end

function BaleToCollectManager:getBales()
	return g_currentMission.slotSystem.objectLimits[SlotSystem.LIMITED_OBJECT_BALE].objects
end

g_baleToCollectManager = BaleToCollectManager()