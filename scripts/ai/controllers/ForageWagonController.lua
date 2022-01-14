---@class ForageWagonController : ImplementController
ForageWagonController = CpObject(ImplementController)
ForageWagonController.maxFillLevelPercentage = 0.99

function ForageWagonController:init(vehicle,implement)
    ImplementController.init(self, vehicle, implement)
	self.forageWagon = implement
end

function ForageWagonController:update()
	local maxSpeed
	local spec = self.forageWagon.spec_forageWagon
	local fillUnitIndex = spec.fillUnitIndex
	if self.forageWagon:getFillUnitFillLevelPercentage(fillUnitIndex) >= self.maxFillLevelPercentage then 
		SpecializationUtil.raiseEvent(self.vehicle,"onCpFull")
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