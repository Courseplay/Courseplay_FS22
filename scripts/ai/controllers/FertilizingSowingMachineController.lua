--- Enables the user to activate/deactivate the fertilizer use for sowing machines with a setting.
--- Also stops the driver, when the setting is active and the fertilizer tank is empty.
---@class FertilizingSowingMachineController : ImplementController
FertilizingSowingMachineController = CpObject(ImplementController)

function FertilizingSowingMachineController:init(vehicle, sowingMachine)
	self.sowingMachine = sowingMachine
    ImplementController.init(self, vehicle, self.sowingMachine)
end

local function onStartWorkAreaProcessing(sowingMachine, superFunc, ...)
	superFunc(sowingMachine, ...)
	if not sowingMachine.spec_fertilizingSowingMachine then 
		return
	end	
	local rootVehicle = sowingMachine.rootVehicle
	if not rootVehicle.getIsCpActive or not rootVehicle:getIsCpActive() then
		return
	end
	local specSpray = sowingMachine.spec_sprayer
	local sprayerParams = specSpray.workAreaParameters
	local fertilizingEnabled = rootVehicle:getCpSettings().sowingMachineFertilizerEnabled:getValue()
	if not fertilizingEnabled then 
		sprayerParams.sprayFillLevel = 0
	elseif sprayerParams.sprayFillLevel <=0 and not sowingMachine:getIsSprayerExternallyFilled() then
		CpUtil.debugImplement(CpDebug.DBG_IMPLEMENTS,sowingMachine,"Stopped Cp, as the fertilizer for sowing machine is empty.")
		rootVehicle:stopCurrentAIJob(AIMessageErrorOutOfFill.new())
	end
	return superFunc(sowingMachine, ...)
end
FertilizingSowingMachine.processSowingMachineArea = Utils.overwrittenFunction(FertilizingSowingMachine.processSowingMachineArea, onStartWorkAreaProcessing)


