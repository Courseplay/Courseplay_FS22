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
	local capacity = 0
	local sprayFillUnit = sowingMachine:getSprayerFillUnitIndex()
	for fillType, _ in pairs(sowingMachine:getFillUnitSupportedFillTypes(sprayFillUnit)) do
		local _, capacityOfFillType = FillLevelManager.getTotalFillLevelAndCapacityForFillType(rootVehicle, fillType)
		capacity = math.max(capacityOfFillType, capacity)
	end
	if not fertilizingEnabled then
		sprayerParams.sprayFillLevel = 0
	elseif capacity > 0 and sprayerParams.sprayFillLevel <= 0 then
		CpUtil.debugVehicle(CpDebug.DBG_IMPLEMENTS,sowingMachine,"Stopped Cp, as the fertilizer is empty.")
		rootVehicle:stopCurrentAIJob(AIMessageErrorOutOfFill.new())
	end
	return superFunc(sowingMachine, ...)
end

FertilizingSowingMachine.processSowingMachineArea = Utils.overwrittenFunction(FertilizingSowingMachine.processSowingMachineArea, processSowingMachineArea)


