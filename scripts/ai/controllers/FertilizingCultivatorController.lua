---@class FertilizingCultivatorController : ImplementController
FertilizingCultivatorController = CpObject(ImplementController)

function FertilizingCultivatorController:init(vehicle)
	self.cultivator = AIUtil.getImplementOrVehicleWithSpecialization(vehicle,FertilizingCultivator)
    ImplementController.init(self, vehicle, self.cultivator)
	self.settings = vehicle:getCpSettings()
end

function FertilizingCultivatorController:update()
	if self.settings.sowingMachineFertilizerEnabled:getValue() then 
		local fillUnitIndex = self.cultivator:getSprayerFillUnitIndex()
		if not self.cultivator:getIsSprayerExternallyFilled() and self.cultivator:getFillUnitFillLevel(fillUnitIndex) <= 0 then 
			self:debug("Stopped Cp, as the fertilizer is empty.")
			self.vehicle:stopCurrentAIJob(AIMessageErrorOutOfFill.new())
		end
	end
end


