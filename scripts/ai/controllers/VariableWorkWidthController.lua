---@class VariableWorkWidthController : ImplementController
VariableWorkWidthController = CpObject(ImplementController)

function VariableWorkWidthController:init(vehicle)
    local implement = AIUtil.getImplementOrVehicleWithSpecialization(vehicle, VariableWorkWidth)
    ImplementController.init(self, vehicle, self.treePlanter)
end
--- Registers event listeners for lowering/raising of the pickup.
local function emptyFunction(implement,superFunc,...)
		
end
VariableWorkWidth.onAIFieldWorkerStart = Utils.overwrittenFunction(VariableWorkWidth.onAIFieldWorkerStart,emptyFunction)
VariableWorkWidth.onAIImplementStart = Utils.overwrittenFunction(VariableWorkWidth.onAIImplementStart,emptyFunction)