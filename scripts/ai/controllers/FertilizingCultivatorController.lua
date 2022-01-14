---@class FertilizingCultivatorController : ImplementController
FertilizingCultivatorController = CpObject(ImplementController)

function FertilizingCultivatorController:init(vehicle,implement)
    ImplementController.init(self, vehicle, implement)
	self.cultivator = implement
end

function FertilizingCultivatorController:update()
	local maxSpeed
	if self.settings.sowingMachineFertilizerEnabled:getValue() then 
		local fillUnitIndex = self.cultivator:getSprayerFillUnitIndex()
		local fillType = self.cultivator:getFillUnitFillType(fillUnitIndex)
		if not FillLevelManager.helperBuysThisFillType(fillType) and self.cultivator:getFillUnitFillLevel(fillUnitIndex) <= 0 then 
			SpecializationUtil.raiseEvent(self.vehicle,"onCpEmpty")
			maxSpeed = 0
		end
	end
	return nil,nil,nil,maxSpeed
end


