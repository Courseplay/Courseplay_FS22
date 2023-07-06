---@class AttachableController : ImplementController
AttachableController = CpObject(ImplementController)

function AttachableController:init(vehicle, implement)
	ImplementController.init(self, vehicle, implement)
	self.attachableSpec = implement.spec_attachable	
	for i, joint in ipairs(implement:getInputAttacherJoints()) do 
		if joint.jointType == AttacherJoints.JOINTTYPE_CUTTER or 
			joint.jointType == AttacherJoints.JOINTTYPE_CUTTERHARVESTER then 
			self.cutterInputAttacherJoint = joint
			break
		end
	end
end

function AttachableController:isDetachActive()
	return self.attachableSpec.detachingInProgress
end

function AttachableController:isAttachActive()
	if self.cutterInputAttacherJoint then
		local cutterImplement = self.implement:getImplementByJointDescIndex(self.cutterInputAttacherJoint.index)
		return cutterImplement.attachingIsInProgress
	end
end

function AttachableController:detach()
	local detachAllowed, warning, showWarning = self.implement:isDetachAllowed()
	if detachAllowed then
		self.implement:startDetachProcess()
		return true
	end
end

function AttachableController:update()
	
end

function AttachableController:getDriveData()
	local maxSpeed = nil
    return nil, nil, nil, maxSpeed
end

function AttachableController:onStart()
    
end

function AttachableController:onFinished()
    
end