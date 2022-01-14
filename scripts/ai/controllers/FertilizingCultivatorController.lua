---@class FertilizingCultivatorController : ImplementController
FertilizingCultivatorController = CpObject(ImplementController)

function FertilizingCultivatorController:init(vehicle)
    self.cultivator = AIUtil.getImplementOrVehicleWithSpecialization(vehicle, FertilizingCultivator)
    ImplementController.init(self, vehicle, self.cultivator)
end

function FertilizingCultivatorController:update()
	local maxSpeed
	if self.settings.sowingMachineFertilizerEnabled:getValue() then 
		local fillUnitIndex = self.cultivator:getSprayerFillUnitIndex()
		local fillType = self.sowingMachine:getFillUnitFillType(fillUnitIndex)
		if not FillLevelManager.helperBuysThisFillType(fillType) and self.cultivator:getFillUnitFillLevel(fillUnitIndex) <= 0 then 
			SpecializationUtil.raiseEvent(self.vehicle,"onCpEmpty")
			maxSpeed = 0
		end
	end
	return nil,nil,nil,maxSpeed
end


