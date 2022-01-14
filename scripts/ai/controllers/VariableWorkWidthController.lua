---@class VariableWorkWidthController : ImplementController
VariableWorkWidthController = CpObject(ImplementController)

function VariableWorkWidthController:init(vehicle,implement)
    ImplementController.init(self, vehicle, implement)
end
--- Registers event listeners for lowering/raising of the pickup.
local function emptyFunction(implement,superFunc,...)
	if implement.rootVehicle and implement.rootVehicle:getIsCpActive() then 
		return
	end
	return superFunc(implement,...)
end
VariableWorkWidth.onAIFieldWorkerStart = Utils.overwrittenFunction(VariableWorkWidth.onAIFieldWorkerStart,emptyFunction)
VariableWorkWidth.onAIImplementStart = Utils.overwrittenFunction(VariableWorkWidth.onAIImplementStart,emptyFunction)