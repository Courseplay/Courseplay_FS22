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
---@param baleWrapper table bale wrapper, if exists
function BaleToCollect.isValidBale(object, baleWrapper, baleLoader)
	-- nodeId is sometimes 0, causing issues for the BaleToCollect constructor
	if object.isa and object:isa(Bale) and object.nodeId and entityExists(object.nodeId) then
		if baleWrapper then
			-- if there is a bale wrapper, the bale must be wrappable
			return baleWrapper:getIsBaleWrappable(object)
		elseif baleLoader and baleLoader.getBaleTypeByBale then
			if baleLoader:getBaleTypeByBale(object) ~= nil then
				if baleWrapType == CpBaleFinderJobParameters.ONLY_WRAPPED_BALES then
					return object.wrappingState > 0, object.wrappingState > 0
				elseif  baleWrapType == CpBaleFinderJobParameters.ONLY_NOT_WRAPPED_BALES then
					return object.wrappingState <= 0, object.wrappingState <= 0
				end
				return true
			end
		else
			return true
		end
	end
end

function BaleToCollect:isStillValid()
	return BaleToCollect.isValidBale(self.bale)
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
	local length = self.bale.isRoundbale and self.bale.diameter or self.bale.length
	-- no matter what kind of bale, the footprint is a rectangle, get the diagonal (which, is BTW, not
	-- exact math as it depends on the angle we are approaching the bale, so add a little buffer instead of
	-- thinking about the math...
	return math.sqrt(length * length + self.bale.width * self.bale.width) / 2 + 0.2
end