--- Raises, lowered and turns on/off silo rollers and compactor implements.
---@class BunkerSiloCompacterController : ImplementController
BunkerSiloCompacterController = CpObject(ImplementController)

function BunkerSiloCompacterController:init(vehicle, implement)
    ImplementController.init(self, vehicle, implement)
    self.spec = self.implement.spec_bunkerSiloCompacter
end

function BunkerSiloCompacterController:onLowering()
	self.implement:aiImplementStartLine()

	local inputJointDesc = self.implement.getActiveInputAttacherJoint and self.implement:getActiveInputAttacherJoint()
	if inputJointDesc ~= nil and not inputJointDesc.needsLowering then
		--- Giants doesn't lower some silage rollers for some reason...
		Attachable.actionControllerLowerImplementEvent(self.implement, 1)
	end
end

function BunkerSiloCompacterController:onRaising()
	self.implement:aiImplementEndLine()

	local inputJointDesc = self.implement.getActiveInputAttacherJoint and self.implement:getActiveInputAttacherJoint()
	if inputJointDesc ~= nil and not inputJointDesc.needsLowering then
		--- Giants doesn't raise some silage rollers for some reason...
		Attachable.actionControllerLowerImplementEvent(self.implement, -1)
	end
end
