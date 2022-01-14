---@class TreePlanterController : ImplementController
TreePlanterController = CpObject(ImplementController)

function TreePlanterController:init(vehicle)
    self.treePlanter = AIUtil.getImplementOrVehicleWithSpecialization(vehicle, TreePlanter)
    ImplementController.init(self, vehicle, self.treePlanter)
end

function TreePlanterController:update()
	local maxSpeed

	local spec = self.treePlanter.spec_treePlanter
	if not g_currentMission.missionInfo.helperBuySeeds and spec.mountedSaplingPallet == nil then 
		SpecializationUtil.raiseEvent(self.vehicle,"onCpEmpty")
	end

	return nil,nil,nil,maxSpeed
end


