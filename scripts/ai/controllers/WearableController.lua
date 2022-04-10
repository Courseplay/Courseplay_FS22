--- Releases the driver, if one implement or the vehicle is more broken
--- than the global threshold set.
---@class WearableController : ImplementController
WearableController = CpObject(ImplementController)
function WearableController:init(vehicle, implement)
    ImplementController.init(self, vehicle, implement)
	self.wearableSpec = implement.spec_wearable
	self.brokenThresholdSetting = g_Courseplay.globalSettings.brockenThreshold
	self.autoRepairSetting = g_Courseplay.globalSettings.autoRepair
end

function WearableController:update()
	
	if self.autoRepairSetting:getValue() == g_Courseplay.globalSettings.AUTO_REPAIR_DISABLED then
		if self:isBrokenGreaterThan(self.brokenThresholdSetting:getValue()) then 
			self.vehicle:stopCurrentAIJob(AIMessageErrorVehicleBroken.new())
		end
	else 
		self:autoRepair()
	end
end

function WearableController:autoRepair()
	if self:isBrokenGreaterThan(100-self.autoRepairSetting:getValue()) then 
		self.implement:repairVehicle()
	end
end

function WearableController:isBrokenGreaterThan(dx)
	local damageAmount = self.implement:getDamageAmount()
	if damageAmount*100 >= dx then 
		return true
	end
end
