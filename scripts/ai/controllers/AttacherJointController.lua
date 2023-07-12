--- Controls the Attacher joints of a vehicle, 
--- for attaching implements.
--- Currently only implemented for cutters.
--- 
---@class AttacherJointController : ImplementController
AttacherJointController = CpObject(ImplementController)

function AttacherJointController:init(vehicle, implement)
	ImplementController.init(self, vehicle, implement)
	self.attacherJointSpec = implement.spec_attacherJoints	
	for i, joint in ipairs(implement:getAttacherJoints()) do 
		if joint.jointType == AttacherJoints.JOINTTYPE_CUTTER or 
			joint.jointType == AttacherJoints.JOINTTYPE_CUTTERHARVESTER then 
			self.cutterAttacherJoint = joint
			break
		end
	end
	self.currentAttachImplement = nil
end

--- Is an implement being attached and an animation is playing.
function AttacherJointController:isAttachActive()
	return self.currentAttachImplement ~= nil
end

function AttacherJointController:getCutterJointPositionNode()
	if self.cutterAttacherJoint then 
		return self.cutterAttacherJoint.rootNode
	end
end

--- Is attaching of a cutter currently possible?
function AttacherJointController:canAttachCutter()
	local info = self.attacherJointSpec.attachableInfo
	if info and info.attachable ~= nil and info.attacherVehicleJointDescIndex == self.cutterAttacherJoint.index then
		local attachAllowed, warning = info.attachable:isAttachAllowed(self.vehicle:getActiveFarm(), info.attacherVehicle)
		return attachAllowed
	end
end

--- Tries to attach the first possible implement.
---@return boolean attach was successfully
function AttacherJointController:attach()
	local info = self.attacherJointSpec.attachableInfo
	if info and info.attachable ~= nil then
		local attachAllowed, warning = info.attachable:isAttachAllowed(self.vehicle:getActiveFarm(), info.attacherVehicle)
		if attachAllowed then
			self.implement:attachImplementFromInfo(info)
			self.currentAttachImplement = self.implement:getImplementByObject(info.attachable)
			return true
		else 
			self:debug("Failed to attach %s with warning: %s", CpUtil.getName(info.attachable), warning)
		end
	end
	return false
end

function AttacherJointController:detach()
	
end

function AttacherJointController:isAttachingAllowed()
	return true
end

function AttacherJointController:getDriveData()
	local maxSpeed = nil
	if self:canAttachCutter() then 
		return 0	
	end
    return nil, nil, nil, maxSpeed
end

function AttacherJointController:update()
	if self:isAttachingAllowed() then 
		--- Searches for possible implements to attach.
		AttacherJoints.updateVehiclesInAttachRange(self.implement, AttacherJoints.MAX_ATTACH_DISTANCE_SQ, AttacherJoints.MAX_ATTACH_ANGLE, true)
	end
	if self.currentAttachImplement ~= nil and not self.currentAttachImplement.attachingIsInProgress then 
		--- Keep a reference to the last attached implement, to measure the attachment animation.
		self.currentAttachImplement = nil
	end
end

function AttacherJointController:onStart()
    
end

function AttacherJointController:onFinished()
    
end