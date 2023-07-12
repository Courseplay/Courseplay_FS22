--- This controller is for attachable implements.
--- Controls the detaching of the implement
--- and gives information's where the where the attacher joints
--- can be attached.
--- Only implemented for cutter for now.
---
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

function AttachableController:getCutterJointPositionNode()
	if self.cutterInputAttacherJoint then 
		return self.cutterInputAttacherJoint.node
	end
end

function AttachableController:isDetachActive()
	return self.attachableSpec.detachingInProgress
end

--- Tries to detach the implement if possible.
---@return boolean
function AttachableController:detach()
	local detachAllowed, warning, showWarning = self.implement:isDetachAllowed()
	if detachAllowed then
		self.implement:startDetachProcess()
		return true
	else 
		self:debug("Failed to detach with warning: %s!", warning)
	end
	return false
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