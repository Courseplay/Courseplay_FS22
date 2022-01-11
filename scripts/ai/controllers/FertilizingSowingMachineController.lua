---@class FertilizingSowingMachineController : ImplementController
FertilizingSowingMachineController = CpObject(ImplementController)

function FertilizingSowingMachineController:init(vehicle)
    self.sowingMachine = AIUtil.getImplementOrVehicleWithSpecialization(vehicle, FertilizingSowingMachine)
    ImplementController.init(self, vehicle, self.sowingMachine)

	self.oldProcessSowingMachineAreaFunc = self.sowingMachine.processSowingMachineArea
	local function processSowingMachineArea(sowingMachine,superFunc,...)
		local rootVehicle = sowingMachine.rootVehicle
		local fertilizingEnabled = rootVehicle:getCpSettings() and rootVehicle:getCpSettings().sowingMachineFertilizerEnabled:getValue()
		if not fertilizingEnabled then 
			sowingMachine.spec_sprayer.workAreaParameters.sprayFillLevel = 0
		end
		return superFunc(sowingMachine, ...)
	end
	self:registerOverwrittenFunction(self.sowingMachine,"processSowingMachineArea",processSowingMachineArea)
end

function FertilizingSowingMachineController:update()
	local maxSpeed
	if self.settings.sowingMachineFertilizerEnabled:getValue() then 
		local fillUnitIndex = self.sowingMachine:getSprayerFillUnitIndex()
		if self.sowingMachine:getFillUnitFillLevel(fillUnitIndex) <= 0 then 
			SpecializationUtil.raiseEvent(self.vehicle,"onCpEmptyOrFull")
			maxSpeed = 0
		end
	end
	return nil,nil,nil,maxSpeed
end


