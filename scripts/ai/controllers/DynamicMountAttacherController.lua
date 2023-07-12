--- Controls trailer, which can mount objects/implements 
--- Only works with cutters/ harvester headers for now.
---@class DynamicMountAttacherController : ImplementController
DynamicMountAttacherController = CpObject(ImplementController)

function DynamicMountAttacherController:init(vehicle, implement)
	ImplementController.init(self, vehicle, implement)
	self.dynamicMountAttacherSpec = self.implement.spec_dynamicMountAttacher
end

function DynamicMountAttacherController:getCutterJointPositionNode()
	local implement = next(self.dynamicMountAttacherSpec.dynamicMountedObjects)
	for i, joint in ipairs(implement:getInputAttacherJoints()) do 
		if joint.jointType == AttacherJoints.JOINTTYPE_CUTTER or 
			joint.jointType == AttacherJoints.JOINTTYPE_CUTTERHARVESTER then 
			return joint.node
		end
	end
end

function DynamicMountAttacherController:getMountedImplement()
	return next(self.dynamicMountAttacherSpec.dynamicMountedObjects)
end

function DynamicMountAttacherController:getDriveData()
	local maxSpeed = nil
    return nil, nil, nil, maxSpeed
end

function DynamicMountAttacherController:update()

end

function DynamicMountAttacherController:onStart()
    
end

function DynamicMountAttacherController:onFinished()
    
end