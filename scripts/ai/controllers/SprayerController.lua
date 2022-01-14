---@class SprayerController : ImplementController
SprayerController = CpObject(ImplementController)

function SprayerController:init(vehicle,implement)
    ImplementController.init(self, vehicle, implement)
	self.sprayer = implement
end

function SprayerController:update()
	local maxSpeed
	if self.sprayer:getUseSprayerAIRequirements() then 
		local fillUnitIndex = self.sprayer:getSprayerFillUnitIndex()
		local fillType = self.sprayer:getFillUnitFillType(fillUnitIndex)
		if not self.sprayer:getIsSprayerExternallyFilled() and self.sprayer:getFillUnitFillLevel(fillUnitIndex) <= 0 then 
			SpecializationUtil.raiseEvent(self.vehicle,"onCpEmpty")
			maxSpeed = 0
		end
	end
	return nil,nil,nil,maxSpeed
end

