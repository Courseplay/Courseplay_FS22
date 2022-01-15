---@class FertilizingCultivatorController : ImplementController
FertilizingCultivatorController = CpObject(ImplementController)

function FertilizingCultivatorController:init(vehicle,implement)
    ImplementController.init(self, vehicle, implement)
	self.cultivator = implement
	self.settings = vehicle:getCpSettings()
end

function FertilizingCultivatorController:update()
	local maxSpeed
	if self.settings.sowingMachineFertilizerEnabled:getValue() then 
		local fillUnitIndex = self.cultivator:getSprayerFillUnitIndex()
		if not self.cultivator:getIsSprayerExternallyFilled() and self.cultivator:getFillUnitFillLevel(fillUnitIndex) <= 0 then 
			self.vehicle:stopCurrentAIJob(AIMessageErrorOutOfFill.new())
			maxSpeed = 0
		end
	end
	return nil,nil,nil,maxSpeed
end


