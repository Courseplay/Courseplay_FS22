--- Makes sure the vine harvester is stop, once it's full.
--- The vine harvester isn't using the combine drive strategy, as there is some bug.
---@class VineCutterController : ImplementController
VineCutterController = CpObject(ImplementController)

function VineCutterController:init(vehicle, vineCutter)
    ImplementController.init(self, vehicle, vineCutter)
	self.vineCutterSpec = vineCutter.spec_vineCutter
	self.combine = AIUtil.getAllChildVehiclesWithSpecialization(vehicle, Combine)[1]
	self.combineSpec = self.combine.spec_combine
end

function VineCutterController:getIsFull()
	return self.combine:getFillUnitFreeCapacity(self.combineSpec.fillUnitIndex) <= 0
end

function VineCutterController:update()
	if self:getIsFull() then 
		self.vehicle:stopCurrentAIJob(AIMessageErrorIsFull.new())
	end
end

--- Waits while it's full or unloading finished.
function VineCutterController:getDriveData()
	local maxSpeed
	if self:getIsFull() then 
		maxSpeed = 0
	end

	return nil, nil, nil, maxSpeed
end
