---@class SprayerController : ImplementController
SprayerController = CpObject(ImplementController)

function SprayerController:init(vehicle)
    self.sprayer = AIUtil.getImplementOrVehicleWithSpecialization(vehicle, Sprayer)
    ImplementController.init(self, vehicle, self.sprayer)
end

function SprayerController:update()
	local maxSpeed
	if self.sprayer:getUseSprayerAIRequirements() then 
		local fillUnitIndex = self.sowingMachine:getSprayerFillUnitIndex()
		local fillType = self.sowingMachine:getFillUnitFillType(fillUnitIndex)
		if not FillLevelManager.helperBuysThisFillType(fillType) and self.sprayer:getFillUnitFillLevel(fillUnitIndex) <= 0 then 
			SpecializationUtil.raiseEvent(self.vehicle,"onCpEmpty")
			maxSpeed = 0
		end
	end
	return nil,nil,nil,maxSpeed
end

