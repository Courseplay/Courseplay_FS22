---@class SowingMachineController : ImplementController
SowingMachineController = CpObject(ImplementController)

function SowingMachineController:init(vehicle,implement)
    ImplementController.init(self, vehicle, implement)
	self.sowingMachine = implement
end


function SowingMachineController:update()
	local maxSpeed
	local fillUnitIndex = self.sowingMachine:getSowingMachineFillUnitIndex()
	if not g_currentMission.missionInfo.helperBuySeeds and self.sowingMachine:getFillUnitFillLevel(fillUnitIndex) <= 0 then 
		SpecializationUtil.raiseEvent(self.vehicle,"onCpEmpty")
		maxSpeed = 0
	end
    return nil, nil, nil, maxSpeed
end

