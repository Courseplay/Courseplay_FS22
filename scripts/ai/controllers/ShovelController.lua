---@class ShovelController : ImplementController
ShovelController = CpObject(ImplementController)

ShovelController.POSITIONS = {
    DEACTIVATED = 0, 
    LOADING = 1,
    TRANSPORT = 2,
    PRE_UNLOADING = 3,
    UNLOADING = 4,
}

function ShovelController:init(vehicle, implement)
    ImplementController.init(self, vehicle, implement)
    self.shovelSpec = self.implement.spec_shovel
    self.shovelNode = self.shovelSpec.shovelNodes[1]
    self.turnOnSpec = self.implement.spec_turnOnVehicle
end

function ShovelController:update()
	
end

function ShovelController:getShovelNode()
	return self.shovelNode.node
end

function ShovelController:isFull()
    return self:getFillLevelPercentage() >= 99
end

function ShovelController:isEmpty()
    return self:getFillLevelPercentage() <= 1
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

function ShovelController:getDischargeFillType()
    return self.implement:getDischargeFillType(self:getDischargeNode())
end

function ShovelController:getDischargeNode()
    return self.implement:getCurrentDischargeNode()
end

--- Checks if the shovel raycast has found an unload target.
---@param targetTrigger CpTrigger|nil
---@return boolean
function ShovelController:canDischarge(targetTrigger)
    local dischargeNode = self:getDischargeNode()
    local spec = self.implement.spec_dischargeable
	if not spec.isAsyncRaycastActive then
        local oldNode = dischargeNode.raycast.node
        dischargeNode.raycast.node = self.implement.spec_attachable.attacherJoint.node
		self.implement:updateRaycast(dischargeNode)
        dischargeNode.raycast.node = oldNode
	end
    if targetTrigger and targetTrigger:getTrigger() ~= self.implement:getDischargeTargetObject(dischargeNode) then 
        return false
    end
    return dischargeNode.dischargeHit
end

--- Is the shovel node over the trailer?
---@param refNode number
---@param margin number|nil
---@return boolean
function ShovelController:isShovelOverTrailer(refNode, margin)
    local node = self:getShovelNode()
    local _, _, distShovelToRoot = localToLocal(node, self.implement.rootVehicle:getAIDirectionNode(), 0, 0, 0)
    local _, _, distTrailerToRoot = localToLocal(refNode, self.implement.rootVehicle:getAIDirectionNode(), 0, 0, 0)
    margin = margin or 0
    if self:isHighDumpShovel() then 
        margin = margin + 1
    end
    return ( distTrailerToRoot - distShovelToRoot ) < margin
end

function ShovelController:isHighDumpShovel()
    return g_vehicleConfigurations:get(self.implement, "shovelMovingToolIx") ~= nil
end

function ShovelController:onFinished()
    if self.implement.cpResetShovelState then
        self.implement:cpResetShovelState()
    end
end

---@param pos number shovel position 1-4
---@return boolean reached? 
function ShovelController:moveShovelToPosition(pos)
    if self.turnOnSpec then
        if pos == ShovelController.POSITIONS.UNLOADING then 
            if not self.implement:getIsTurnedOn() and self.implement:getCanBeTurnedOn() then 
                self.implement:setIsTurnedOn(true)
                self:debug("Turning on the shovel.")
            end
            if not self.implement:getDischargeState() ~= Dischargeable.DISCHARGE_STATE_OBJECT then
                self.implement:setDischargeState(Dischargeable.DISCHARGE_STATE_OBJECT)
            end
            return false
        else
            if self.implement:getIsTurnedOn() then 
                self.implement:setIsTurnedOn(false)
                self:debug("turning off the shovel.")
            end
        end
    end
    if self.implement.cpSetShovelState == nil then 
        return false
    end
    self.implement:cpSetShovelState(pos)
    return self.implement:areCpShovelPositionsDirty()
end
