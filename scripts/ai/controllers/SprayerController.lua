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
		if self.sprayer:getFillUnitFillLevel(fillUnitIndex) <= 0 then 
			SpecializationUtil.raiseEvent(self.vehicle,"onCpEmptyOrFull")
			maxSpeed = 0
		end
	end
	return nil,nil,nil,maxSpeed
end

