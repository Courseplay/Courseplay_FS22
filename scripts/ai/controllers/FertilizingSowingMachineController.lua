---@class FertilizingSowingMachineController : ImplementController
FertilizingSowingMachineController = CpObject(ImplementController)

function FertilizingSowingMachineController:init(vehicle)
	self.sowingMachine = AIUtil.getImplementOrVehicleWithSpecialization(vehicle,FertilizingSowingMachine)
    ImplementController.init(self, vehicle, self.sowingMachine)
	self.settings = vehicle:getCpSettings()
end

function FertilizingSowingMachineController:update()
	local maxSpeed
	if self.settings.sowingMachineFertilizerEnabled:getValue() then 
		local fillUnitIndex = self.sowingMachine:getSprayerFillUnitIndex()
		if not self.sowingMachine:getIsSprayerExternallyFilled() and self.sowingMachine:getFillUnitFillLevel(fillUnitIndex) <= 0 then 
			self.vehicle:stopCurrentAIJob(AIMessageErrorOutOfFill.new())
			maxSpeed = 0
		end
	end
	return nil,nil,nil,maxSpeed
end

local function processSowingMachineArea(sowingMachine,superFunc,...)
	local rootVehicle = sowingMachine.rootVehicle
	if not rootVehicle:getIsCpActive() then 
		return superFunc(sowingMachine, ...)
	end
	local fertilizingEnabled = rootVehicle:getCpSettings().sowingMachineFertilizerEnabled:getValue()
	if not fertilizingEnabled then 
		local specSpray = sowingMachine.spec_sprayer
		local sprayerParams = specSpray.workAreaParameters
		sprayerParams.sprayFillLevel = 0
	end
	return superFunc(sowingMachine, ...)
end
FertilizingSowingMachine.processSowingMachineArea = Utils.overwrittenFunction(
	FertilizingSowingMachine.processSowingMachineArea,processSowingMachineArea)


