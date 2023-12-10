--[[
This file is part of Courseplay (https://github.com/Courseplay/courseplay)
Copyright (C) 2023 Courseplay Dev Team

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
---@class PalletFillerController : ImplementController
PalletFillerController = CpObject(ImplementController)

function PalletFillerController:init(vehicle, implement)
	ImplementController.init(self, vehicle, implement)
	self.palletFillerSpec = implement["spec_pdlc_premiumExpansion.palletFiller"]

end

function PalletFillerController:update()
	local canContinue, stopAI, stopReason = self.implement:getCanAIImplementContinueWork()
	if not canContinue then
		if stopAI and pdlc_premiumExpansion and 
			(stopReason:isa(pdlc_premiumExpansion.AIMessageErrorPalletsFull) or 
			stopReason:isa(pdlc_premiumExpansion.AIMessageErrorNoPalletsLoaded)) then
			self.vehicle:stopCurrentAIJob(stopReason)
		end
	end
end

---@param pallet table
---@return boolean
function PalletFillerController:isPalletLoaded(pallet)
	for i, palletSlot in ipairs(self.palletFillerSpec.palletRow.palletSlots) do
		if palletSlot.object ~= nil and palletSlot.object == pallet then 
			return true
		end
	end
end

--- Ignore loaded pallets when moving backwards
---@param object table
---@param vehicle table
---@param moveForwards boolean
---@return boolean
function PalletFillerController:ignoreProximityObject(object, vehicle, moveForwards)
    if object and not moveForwards and object.isa and object:isa(Pallet) then
        if self:isPalletLoaded(object) then
            self:debugSparse('ignoring loaded pallet')
            return true
        end
    end
end

--- Ask the proximity controller to check with us if an object is blocking, we don't want to block
--- on pallets, that are loaded
---@param proximityController ProximityController
function PalletFillerController:registerIgnoreProximityObjectCallback(proximityController)
    proximityController:registerIgnoreObjectCallback(self, self.ignoreProximityObject)
end
