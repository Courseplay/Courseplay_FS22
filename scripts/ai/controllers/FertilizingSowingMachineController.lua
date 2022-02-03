---@class FertilizingSowingMachineController : ImplementController
FertilizingSowingMachineController = CpObject(ImplementController)

function FertilizingSowingMachineController:init(vehicle)
	self.sowingMachine = AIUtil.getImplementOrVehicleWithSpecialization(vehicle,FertilizingSowingMachine)
    ImplementController.init(self, vehicle, self.sowingMachine)
	self.settings = vehicle:getCpSettings()
end

function FertilizingSowingMachineController:update()

end

local function processSowingMachineArea(sowingMachine,superFunc,...)
	local rootVehicle = sowingMachine.rootVehicle
	if not rootVehicle.getIsCpActive or not rootVehicle:getIsCpActive() then 
		return superFunc(sowingMachine, ...)
	end
	local specSpray = sowingMachine.spec_sprayer
	local sprayerParams = specSpray.workAreaParameters
	local fertilizingEnabled = rootVehicle:getCpSettings().sowingMachineFertilizerEnabled:getValue()
	if not fertilizingEnabled then 
		sprayerParams.sprayFillLevel = 0
	elseif sprayerParams.sprayFillLevel <=0 then
		CpUtil.debugVehicle(CpDebug.DBG_IMPLEMENTS,sowingMachine,"Stopped Cp, as the fertilizer is empty.")
		rootVehicle:stopCurrentAIJob(AIMessageErrorOutOfFill.new())
	end
	return superFunc(sowingMachine, ...)
end
FertilizingSowingMachine.processSowingMachineArea = Utils.overwrittenFunction(
	FertilizingSowingMachine.processSowingMachineArea,processSowingMachineArea)


