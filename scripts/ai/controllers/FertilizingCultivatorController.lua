--- Enables the user to activate/deactivate the fertilizer use for cultivators with a setting.
--- Also stops the driver, when the setting is active and the fertilizer tank is empty.
---@class FertilizingCultivatorController : ImplementController
FertilizingCultivatorController = CpObject(ImplementController)

function FertilizingCultivatorController:init(vehicle, cultivator)
	self.cultivator = cultivator
    ImplementController.init(self, vehicle, self.cultivator)
end

local function processCultivatorArea(sprayer,superFunc,...)
	local rootVehicle = sprayer.rootVehicle
	if not rootVehicle.getIsCpActive or not rootVehicle:getIsCpActive() then 
		return superFunc(sprayer, ...)
	end
	local specSpray = sprayer.spec_sprayer
	local sprayerParams = specSpray.workAreaParameters
	local fertilizingEnabled = rootVehicle:getCpSettings().sowingMachineFertilizerEnabled:getValue()
	if not fertilizingEnabled then 
		sprayerParams.sprayFillLevel = 0
	elseif sprayerParams.sprayFillLevel <=0 then
		CpUtil.debugVehicle(CpDebug.DBG_IMPLEMENTS,sprayer,"Stopped Cp, as the fertilizer is empty.")
		rootVehicle:stopCurrentAIJob(AIMessageErrorOutOfFill.new())
	end
	return superFunc(sprayer, ...)
end
FertilizingCultivator.processCultivatorArea = Utils.overwrittenFunction(
	FertilizingCultivator.processCultivatorArea,processCultivatorArea)

