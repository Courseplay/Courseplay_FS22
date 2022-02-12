--- Raises/lowers the pickup.
---@class CutterController : ImplementController
CutterController = CpObject(ImplementController)

function CutterController:init(vehicle, implement)
    ImplementController.init(self, vehicle, implement)
    self.cutterSpec = self.implement.spec_cutter
end

function CutterController:getDriveData()
	self:disableCutterTimer()
	return nil, nil, nil, nil
end

--- The Giants Cutter class has a timer to stop the AI job if there is no fruit being processed for 5 seconds.
--- This prevents us from driving for instance on a connecting track or longer turns (and also testing), so
--- we just reset that timer here in every update cycle.
--- Consider setting Cutter:getAllowCutterAIFruitRequirements() to false
function CutterController:disableCutterTimer()
	if self.cutterSpec.aiNoValidGroundTimer then 
		self.cutterSpec.aiNoValidGroundTimer = 0
	end
end