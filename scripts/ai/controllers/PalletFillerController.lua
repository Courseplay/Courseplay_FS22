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

function PalletFillerController:handlePallets(stopReason)
	local unloadAndRefill = self.settings.unloadAndRefillPallets:get()
	if stopReason:isa(pdlc_premiumExpansion.AIMessageErrorPalletsFull) and unloadAndRefill >= CpVehicleSettings.PALLETS_ONLY_UNLOAD then 
		if self.palletFillerSpec.state == PalletFiller.STATE.IDLE then 
			if self.implement:getCanChangePalletFillerState(PalletFiller.STATE.UNLOADING) then 
				self.implement:setPalletFillerState(PalletFiller.STATE.UNLOADING)
				self:debug("Pallet filler starting to unload.")
				return
			end
		else 
			self:debugSparse("Pallet filler is unloading.")
			return
		end
	elseif stopReason:isa(pdlc_premiumExpansion.AIMessageErrorNoPalletsLoaded) and unloadAndRefill >= CpVehicleSettings.PALLETS_UNLOAD_AND_REFILL then 
		if self.implement:getCanBuyPalletFillerPallets() then
			self.implement:buyPalletFillerPallets()
			self:debug("Buying new pallets.")
			return
		end
	end
	self.vehicle:stopCurrentAIJob(stopReason)
end

function PalletFillerController:update()
	local canContinue, stopAI, stopReason = self.implement:getCanAIImplementContinueWork()
	if not canContinue then
		if stopAI then 
			if pdlc_premiumExpansion then
				self:handlePallets()
			else
				self.vehicle:stopCurrentAIJob(stopReason)
			end
		end
	end
end