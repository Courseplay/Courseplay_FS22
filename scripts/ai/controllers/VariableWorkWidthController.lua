---@class VariableWorkWidthController : ImplementController
VariableWorkWidthController = CpObject(ImplementController)

function VariableWorkWidthController:init(vehicle)
    local implement = AIUtil.getImplementOrVehicleWithSpecialization(vehicle, VariableWorkWidth)
    ImplementController.init(self, vehicle, self.treePlanter)

	--- Registers event listeners for lowering/raising of the pickup.
	local function emptyFunction(implement,superFunc,...)
		
	end
	self:registerOverwrittenFunction(implement,"onAIFieldWorkerStart",emptyFunction)
	self:registerOverwrittenFunction(implement,"onAIImplementStart",emptyFunction)
end
