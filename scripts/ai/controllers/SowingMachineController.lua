---@class SowingMachineController : ImplementController
SowingMachineController = CpObject(ImplementController)

function SowingMachineController:init(vehicle)
    self.sowingMachine = AIUtil.getImplementOrVehicleWithSpecialization(vehicle, SowingMachine)
    ImplementController.init(self, vehicle, self.sowingMachine)
end


function SowingMachineController:update()
	local maxSpeed
	local fillUnitIndex = self.sowingMachine:getSowingMachineFillUnitIndex()
	if self.sowingMachine:getFillUnitFillLevel(fillUnitIndex) <= 0 then 
		SpecializationUtil.raiseEvent(self.vehicle,"onCpEmpty")
		maxSpeed = 0
	end
    return nil, nil, nil, maxSpeed
end

