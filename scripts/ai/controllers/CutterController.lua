--- Raises/lowers the additional cutters, like the straw/grass pickup for harvesters.
--- Also disables the cutter, while it's waiting for unloading.
---@class CutterController : ImplementController
CutterController = CpObject(ImplementController)

function CutterController:init(vehicle, implement)
    ImplementController.init(self, vehicle, implement)
    self.cutterSpec = self.implement.spec_cutter
end

function CutterController:getDriveData()
	self:disableCutterTimer()
	--- Turns off the cutter, while the driver is waiting for unloading.
	if self.driveStrategy.isWaitingForUnload and self.driveStrategy:isWaitingForUnload() then 
		if self.implement:getIsTurnedOn() then 
			self.vehicle:aiBlock()
		end
	end
	return nil, nil, nil, nil
end

function CutterController:onLowering()
	if self.driveStrategy.isWaitingForUnload and not self.implement:getIsTurnedOn() then 
		--- Turns it back on after unloading.
		self.vehicle:aiContinue()
	end
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

function CutterController:onLowering()
    self.implement:aiImplementStartLine()
end

function CutterController:onRaising()
    self.implement:aiImplementEndLine()
end