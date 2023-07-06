
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

function AttacherJointController:isAttachActive()
	return self.currentAttachImplement ~= nil
end

function AttacherJointController:getCutterJointPositionNode()
	if self.cutterAttacherJoint then 
		return self.cutterAttacherJoint.node
	end
end

function AttacherJointController:canAttachCutter()
	local info = self.attacherJointSpec.attachableInfo
	if info and info.attachable ~= nil and info.attacherVehicleJointDescIndex == self.cutterAttacherJoint.index then
		local attachAllowed, warning = info.attachable:isAttachAllowed(self.vehicle:getActiveFarm(), info.attacherVehicle)
		return attachAllowed
	end
end

function AttacherJointController:attach()
	local info = self.attacherJointSpec.attachableInfo
	if info and info.attachable ~= nil then
		local attachAllowed, warning = info.attachable:isAttachAllowed(self.vehicle:getActiveFarm(), info.attacherVehicle)
		if attachAllowed then
			self.implement:attachImplementFromInfo(info)
			self.currentAttachImplement = self.implement:getImplementByObject(info.attachable)
			return true
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
		AttacherJoints.updateVehiclesInAttachRange(self.implement, AttacherJoints.MAX_ATTACH_DISTANCE_SQ, AttacherJoints.MAX_ATTACH_ANGLE, true)
	end
	if self.currentAttachImplement ~= nil and not self.currentAttachImplement.attachingIsInProgress then 
		self.currentAttachImplement = nil
	end
end

function AttacherJointController:onStart()
    
end

function AttacherJointController:onFinished()
    
end