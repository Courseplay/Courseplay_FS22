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
	--- TODO: WIP
	-- local type = self.settings.unloadAndRefillPallets:get()
	-- if type == CpVehicleSettings.PALLETS_UNLOAD_AND_REFILL_DISABLED then
	-- 	if not canContinue then 
	-- 		self.vehicle:stopCurrentAIJob(stopReason or AIMessageErrorUnknown.new())
	-- 	end
	-- elseif type == CpVehicleSettings.PALLETS_ONLY_UNLOAD then
	
	-- else
	-- 	if not canContinue and stopAI then 
	-- 		self.vehicle:stopCurrentAIJob(stopReason or AIMessageErrorUnknown.new())
	-- 	end
	-- end
end