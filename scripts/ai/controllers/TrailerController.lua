--- Allows unloading of a tailer.
---@class TrailerController : ImplementController
TrailerController = CpObject(ImplementController)

function TrailerController:init(vehicle, implement)
    ImplementController.init(self, vehicle, implement)
    self.trailerSpec = self.implement.spec_trailer
    self.isDischargingTimer = CpTemporaryObject(false)
end

function TrailerController:getDriveData()
	local maxSpeed
    if not self.implement:getAIHasFinishedDischarge() then 
        if self.isDischargingTimer:get() or self:isEmpty() then 
            --- Waiting until the discharging stopped or 
            --- the trailer is empty and the folding animation is playing.
            maxSpeed = 0
        end
    end
    if self:isDischarging() and self.implement:getCanDischargeToGround(self.implement:getCurrentDischargeNode())  then 
        self.isDischargingTimer:set(true, 1000)
    end
	
	return nil, nil, nil, maxSpeed
end

--- Gets the dischargeNode and offset from a selected tip side.
---@param tipSideID number
---@param isTippingToGroundNeeded boolean
---@return table dischargeNodeIndex
---@return table dischargeNode
---@return number xOffset 
function TrailerController:getDischargeNodeAndOffsetForTipSide(tipSideID, isTippingToGroundNeeded)
	local tipSide = self.trailerSpec.tipSides[tipSideID]
    if not tipSide then 
        self:info("TipSide %s not found!", tostring(tipSideID))
        return 
    end
    local dischargeNodeIndex = tipSide.dischargeNodeIndex
    local dischargeNode = self.implement:getDischargeNodeByIndex(dischargeNodeIndex)
    if not dischargeNode then 
        self:info("Discharge node %s not found!", tostring(dischargeNodeIndex))
        return 
    end
    if isTippingToGroundNeeded and not dischargeNode.canDischargeToGround then 
        self:debug("Discharge node %s can not tip to ground!", tostring(dischargeNodeIndex))
        return 
    end

    return dischargeNodeIndex, dischargeNode, self:getDischargeXOffset(dischargeNode)
end

--- Gets the x offset of the discharge node relative to the implement root.
function TrailerController:getDischargeXOffset(dischargeNode)
    local node = dischargeNode.node
    local xOffset, _ ,_ = localToLocal(node, self.implement.rootNode, 0, 0, 0)
    return xOffset
end

--- Starts AI Discharge to an object/trailer.
---@param dischargeNode table discharge node to use.
---@return boolean success
function TrailerController:startDischarge(dischargeNode)
    if self.implement:getAICanStartDischarge(dischargeNode) then        
		self.implement:startAIDischarge(dischargeNode, self)
        return true
	end
    return false
end

--- Starts discharging to the ground if possible.
function TrailerController:startDischargeToGround(dischargeNode)
    if not dischargeNode.canDischargeToGround then 
        return false
    end
    --- TODO: Check why this one is not working for every discharge node?
    ---       Maybe a raycast call is missing
    --if not self.implement:getCanDischargeToGround(dischargeNode) then 
    --    return false
    --end
    --- Custom implementation of: AIDischargeable:startAIDischarge(dischargeNode, task)
    local spec = self.implement.spec_aiDischargeable
    spec.currentDischargeNode = dischargeNode
    spec.task = self
    spec.isAIDischargeRunning = true

	local tipSide = self.trailerSpec.dischargeNodeIndexToTipSide[dischargeNode.index]
	if tipSide ~= nil then
		self.implement:setPreferedTipSide(tipSide.index)
	end
    self.implement:setDischargeState(Dischargeable.DISCHARGE_STATE_GROUND)
    return true
end

--- Callback for the drive strategy, when the unloading finished.
function TrailerController:setFinishDischargeCallback(finishDischargeCallback)
    self.finishDischargeCallback = finishDischargeCallback
end

--- Callback for ai discharge.
function TrailerController:finishedDischarge()
    self:debug("Finished unloading.")
    if self.finishDischargeCallback then 
        self.finishDischargeCallback(self.driveStrategy, self)
    end
end

function TrailerController:prepareForUnload()
    return true
end

function TrailerController:onFinished()
    self.implement:setDischargeState(Dischargeable.DISCHARGE_STATE_OFF)
end

function TrailerController:isDischarging()
    return self.implement:getDischargeState() ~= Dischargeable.DISCHARGE_STATE_OFF
end

function TrailerController:isEmpty()
    local dischargeNode = self.implement:getCurrentDischargeNode()
    return self.implement:getFillUnitFillLevelPercentage(dischargeNode.fillUnitIndex) <= 0.01    
end
