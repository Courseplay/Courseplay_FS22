---@class VariableWorkWidthController : ImplementController
VariableWorkWidthController = CpObject(ImplementController)

function VariableWorkWidthController:init(vehicle)
    self.treePlanter = AIUtil.getImplementOrVehicleWithSpecialization(vehicle, VariableWorkWidth)
    ImplementController.init(self, vehicle, self.treePlanter)

	--- Registers event listeners for lowering/raising of the pickup.
	local function emptyFunction(implement,superFunc,...)
		
	end
	self:registerOverwrittenFunction(VariableWorkWidth,"onAIFieldWorkerStart",emptyFunction)
	self:registerOverwrittenFunction(VariableWorkWidth,"onAIImplementStart",emptyFunction)
end
