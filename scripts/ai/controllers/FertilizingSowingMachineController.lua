--- Enables the user to activate/deactivate the fertilizer use for sowing machines with a setting.
--- Also stops the driver, when the setting is active and the fertilizer tank is empty.
---@class FertilizingSowingMachineController : ImplementController
FertilizingSowingMachineController = CpObject(ImplementController)

function FertilizingSowingMachineController:init(vehicle, sowingMachine)
	self.sowingMachine = sowingMachine
    ImplementController.init(self, vehicle, self.sowingMachine)
end

local function processSowingMachineArea(sowingMachine,superFunc,...)
	local rootVehicle = sowingMachine.rootVehicle
	if not rootVehicle.getIsCpActive or not rootVehicle:getIsCpActive() then 
		return superFunc(sowingMachine, ...)
	end
	local specSpray = sowingMachine.spec_sprayer
	local sprayerParams = specSpray.workAreaParameters
	local fertilizingEnabled = rootVehicle:getCpSettings().sowingMachineFertilizerEnabled:getValue()
	local capacity = 1
	for fillUnitIndex, fillUnit in pairs(sowingMachine:getFillUnits()) do
		if fillUnit.fillType == sprayerParams.sprayFillType then
			capacity = sowingMachine:getFillUnitCapacity(fillUnitIndex)
			print("capacity: " .. tostring(capacity))
		end
	end
	if not fertilizingEnabled then 
		sprayerParams.sprayFillLevel = 0
	elseif capacity > 0 and sprayerParams.sprayFillLevel <= 0 then
		CpUtil.debugVehicle(CpDebug.DBG_IMPLEMENTS,sowingMachine,"Stopped Cp, as the fertilizer is empty.")
		rootVehicle:stopCurrentAIJob(AIMessageErrorOutOfFill.new())
	end
	return superFunc(sowingMachine, ...)
end
FertilizingSowingMachine.processSowingMachineArea = Utils.overwrittenFunction(
	FertilizingSowingMachine.processSowingMachineArea,processSowingMachineArea)


