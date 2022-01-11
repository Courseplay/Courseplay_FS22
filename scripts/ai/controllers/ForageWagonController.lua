---@class ForageWagonController : ImplementController
ForageWagonController = CpObject(ImplementController)
ForageWagonController.maxFillLevelPercentage = 0.99

function ForageWagonController:init(vehicle)
    self.forageWagon = AIUtil.getImplementOrVehicleWithSpecialization(vehicle, ForageWagon)
    ImplementController.init(self, vehicle, self.forageWagon)
end

function ForageWagonController:update()
	local maxSpeed
	local spec = self.forageWagon.spec_forageWagon
	local fillUnitIndex = spec.fillUnitIndex
	if self.forageWagon:getFillUnitFillLevelPercentage(fillUnitIndex) >= self.maxFillLevelPercentage then 
		SpecializationUtil.raiseEvent(self.vehicle,"onCpEmptyOrFull")
		maxSpeed = 0
	end
	--- Additive fill unit index
	local additiveFillUnitIndex = spec.additives.fillUnitIndex
	if additiveFillUnitIndex then 
		--- For now ignore the additive fill type
		if self.forageWagon:getFillUnitFillLevel(additiveFillUnitIndex) <= 0 then 
		--	maxSpeed = 0
		end
	end

	return nil,nil,nil,maxSpeed
end