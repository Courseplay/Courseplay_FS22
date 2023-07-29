
--- Makes sure stump cutters are lowered and raised correctly.
---@class StumpCutterController : ImplementController
StumpCutterController = CpObject(ImplementController)

function StumpCutterController:init(vehicle, implement)
    ImplementController.init(self, vehicle, implement)
    self.stumpCutterSpec = self.implement.spec_stumpCutter
	self.attacherSpec = self.implement.spec_attachable
	if not self.attacherSpec.controlledAction ~= nil then 
		--- Giants doesn't register these, so while CP is running we register them.
		self.controlledAction = vehicle.actionController:registerAction("lower", InputAction.LOWER_IMPLEMENT, 2)
		self.controlledAction:setCallback(implement, Attachable.actionControllerLowerImplementEvent)
		self.controlledAction:setFinishedFunctions(implement, implement.getIsLowered, true, false)
		self.controlledAction:addAIEventListener(implement, "onAIImplementStartLine", 1, true)
		self.controlledAction:addAIEventListener(implement, "onAIImplementEndLine", -1)
		self.controlledAction:addAIEventListener(implement, "onAIImplementPrepare", -1)
	end
end

function StumpCutterController:onLowering()
	self.implement:aiImplementStartLine()
end

function StumpCutterController:onRaising()
	self.implement:aiImplementEndLine()
end

function StumpCutterController:onFinished()
	self.implement:aiImplementEndLine()
end

function StumpCutterController:delete()
	if self.controlledAction ~= nil then
		self.controlledAction:remove()
	end
end