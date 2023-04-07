---@class ShovelController : ImplementController
ShovelController = CpObject(ImplementController)

function ShovelController:init(vehicle, implement)
    ImplementController.init(self, vehicle, implement)
    self.shovelSpec = self.implement.spec_shovel
    self.shovelNode = self.shovelSpec.shovelNodes[1]
end

function ShovelController:update()
	
end

function ShovelController:getShovelNode()
	return self.shovelNode.node
end

function ShovelController:isFull()
    return self:getFillLevelPercentage() >= 0.98
end

function ShovelController:isEmpty()
    return self:getFillLevelPercentage() <= 0.01
end

function ShovelController:getFillLevelPercentage()
    return self.implement:getFillUnitFillLevelPercentage(self.shovelNode.fillUnitIndex) * 100
end

function ShovelController:isTiltedForUnloading()
    return self.implement:getShovelTipFactor() >= 0
end

function ShovelController:isUnloading()
    return self:isTiltedForUnloading() and self.implement:getDischargeState() ~= Dischargeable.DISCHARGE_STATE_OFF
end

--- Gets current loading fill type.
function ShovelController:getShovelFillType()
    return self.shovelSpec.loadingFillType
end

function ShovelController:isReadyToLoad()
    return self:getShovelFillType() == FillType.UNKNOWN and self:getFillLevelPercentage() < 0.5 
end