--- Allows unloading of a tailer.
---@class TrailerController : ImplementController
TrailerController = CpObject(ImplementController)

function TrailerController:init(vehicle, implement)
    ImplementController.init(self, vehicle, implement)
    self.trailerSpec = self.implement.spec_trailer
    self.isDischargingTimer = CpTemporaryObject(false)
    self.isDischargingToGround = false
    self.dischargeData = {}
end

function TrailerController:getDriveData()
	local maxSpeed
    if self.isDischargingToGround then
        if self.isDischargingTimer:get() then
            --- Waiting until the discharging stopped or 
            --- the trailer is empty and the folding animation is playing.
            maxSpeed = 0
        else 
            --- Small unload speed
            maxSpeed = 5
        end
        if self.trailerSpec.tipState == Trailer.TIPSTATE_OPENING then 
            --- Trailer not yet ready to unload.
            maxSpeed = 0
        end
    end
	
	return nil, nil, nil, maxSpeed
end

function TrailerController:update(dt)
    if self.isDischargingToGround then
        if self:isEmpty() then 
            if self:isDischarging() then
                self.implement:setDischargeState(Dischargeable.DISCHARGE_STATE_OFF)
            end
            if self.implement:getAIHasFinishedDischarge(self.dischargeData.dischargeNode) then 
                self:finishedDischarge()
            end
            return
        end
        if self.implement:getCanDischargeToGround(self.dischargeData.dischargeNode) then 
            --- Update discharge timer
            self.isDischargingTimer:set(true, 500)
            if not self:isDischarging() then 
                self.implement:setDischargeState(Dischargeable.DISCHARGE_STATE_GROUND)
            end
        end
    end
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
    self.isDischargingToGround = true
    self.dischargeData = {
        dischargeNode = dischargeNode,
    }
	local tipSide = self.trailerSpec.dischargeNodeIndexToTipSide[dischargeNode.index]
	if tipSide ~= nil then
		self.implement:setPreferedTipSide(tipSide.index)
	end
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
    return self.implement:getFillUnitFillLevelPercentage(dischargeNode.fillUnitIndex) <= 0    
end


---------------------------------------------
--- Debug
---------------------------------------------
function TrailerController:printDischargeableDebug()
    local dischargeNode = self.implement:getCurrentDischargeNode()
    CpUtil.infoImplement(self.implement, "Discharge node fill unit index: %d, emptySpeed: %s", 
        dischargeNode.fillUnitIndex, self.implement:getDischargeNodeEmptyFactor(dischargeNode))
    CpUtil.infoImplement(self.implement, "canDischargeToGround %s, canDischargeToObject: %s",
        dischargeNode.canDischargeToGround, dischargeNode.canDischargeToObject)
    CpUtil.infoImplement(self.implement, "canStartDischargeAutomatically %s, canStartGroundDischargeAutomatically: %s",
        dischargeNode.canStartDischargeAutomatically, dischargeNode.canStartGroundDischargeAutomatically)
    CpUtil.infoImplement(self.implement, "stopDischargeIfNotPossible %s, canDischargeToGroundAnywhere: %s",
        dischargeNode.stopDischargeIfNotPossible, dischargeNode.canDischargeToGroundAnywhere)
    CpUtil.infoImplement(self.implement, "getCanDischargeToObject() %s, getCanDischargeToGround: %s",
        self.implement:getCanDischargeToObject(dischargeNode), self.implement:getCanDischargeToGround(dischargeNode))
end