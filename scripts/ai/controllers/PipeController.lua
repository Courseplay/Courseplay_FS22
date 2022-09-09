--- Open/close combine and auger wagon pipes
--- Controls moveable pipes and raises the base pipe rod to the maximum.
---@class PipeController : ImplementController
PipeController = CpObject(ImplementController)
PipeController.MAX_ROT_SPEED = 0.6
PipeController.MIN_ROT_SPEED = 0.1
-- chopper: 0= pipe folded (really? isn't this 1?), 2,= autoaiming;  combine: 1 = closed  2= open
PipeController.PIPE_STATE_MOVING = 0
PipeController.PIPE_STATE_CLOSED = 1
PipeController.PIPE_STATE_OPEN = 2

function PipeController:init(vehicle, implement)
    ImplementController.init(self, vehicle, implement)
    self.pipeSpec = self.implement.spec_pipe
    self.cylinderedSpec = self.implement.spec_cylindered
    self.dischargeSpec = self.implement.spec_dischargeable

    self:setupMoveablePipe()

    self.pipeOffsetX, self.pipeOffsetZ = 0, 0
    self.pipeOnLeftSide = true
    CpUtil.try(ImplementUtil.setPipeAttributes, self, self.implement)
end

function PipeController:update(dt)
    self:updateMoveablePipe(dt)
end

function PipeController:needToOpenPipe()
    -- some pipes are not movable (like potato harvesters)
    return self.pipeSpec.numStates > 1
end

function PipeController:openPipe()
    if self:needToOpenPipe() and
            self.pipeSpec.currentState ~= PipeController.PIPE_STATE_MOVING and
            self.pipeSpec.currentState ~= PipeController.PIPE_STATE_OPEN then
        self:debug('Opening pipe')
        self.implement:setPipeState(PipeController.PIPE_STATE_OPEN)
    end
end

---@param checkForObjectsUnderPipe boolean check if there is a trigger object (like a trailer) under the pipe and
---                                        only close if there aren't any
function PipeController:closePipe(checkForObjectsUnderPipe)
    local okToClose = self.pipeSpec.numObjectsInTriggers <= 0 or not checkForObjectsUnderPipe
    if self:needToOpenPipe() and okToClose and -- only close when there are nothing under the pipe
            self.pipeSpec.currentState ~= PipeController.PIPE_STATE_MOVING and
            self.pipeSpec.currentState ~= PipeController.PIPE_STATE_CLOSED then
        self:debug('Closing pipe')
        self.implement:setPipeState(PipeController.PIPE_STATE_CLOSED)
    end
end

function PipeController:isPipeMoving()
    return self:needToOpenPipe() and self.pipeSpec.currentState == PipeController.PIPE_STATE_MOVING
end

function PipeController:getFillType()
    local dischargeNode = self.implement:getDischargeNodeByIndex(self.implement:getPipeDischargeNodeIndex())
    if dischargeNode then
        return self.implement:getFillUnitFillType(dischargeNode.fillUnitIndex)
    end
    return nil
end


function PipeController:isFillableTrailerUnderPipe()
    for trailer, value in pairs(self.pipeSpec.objectsInTriggers) do
        if value > 0 then
            if FillLevelManager.canLoadTrailer(trailer, self:getFillType()) then
                return true
            end
        end
    end
    return false
end

function PipeController:getPipeOffset()
    return self.pipeOffsetX, self.pipeOffsetZ    
end

function PipeController:getPipeOffsetX()
    return self.pipeOffsetX
end

function PipeController:getPipeOffsetZ()
    return self.pipeOffsetZ    
end

function PipeController:isPipeOnTheLeftSide()
    return self.pipeOnLeftSide
end

function PipeController:isDischarging()
    return self.implement:getDischargeState() ~= Dischargeable.DISCHARGE_STATE_OFF
end

function PipeController:getDischargeNode()
    local ix = self.implement:getPipeDischargeNodeIndex()
	local dischargeNode = self.implement:getDischargeNodeByIndex(ix)
    return dischargeNode
end

function PipeController:getDischargeObject()
    local dischargeNode = self:getDischargeNode()
    if dischargeNode then
        local targetObject, fillUnitIndex = self.implement:getDischargeTargetObject(dischargeNode)
        return targetObject, fillUnitIndex
    end
    return false
end

function PipeController:getClosestExactFillRootNode()
    local objectId = self.pipeSpec.nearestObjectInTriggers.objectId 
	local fillUnitIndex = self.pipeSpec.nearestObjectInTriggers.fillUnitIndex
    if objectId and fillUnitIndex then 
        local object = NetworkUtil.getObject(objectId)
        return object and object:getFillUnitExactFillRootNode(fillUnitIndex)
    end
end


function PipeController:getClosestObject()
    local id = self.pipeSpec.nearestObjectInTriggers.objectId
    return id and NetworkUtil.getObject(id)
end

function PipeController:handleChopperPipe()
    local currentPipeTargetState = self.pipeSpec.targetState
    if currentPipeTargetState ~= 2 then
        self.implement:setPipeState(2)
    end
end


--------------------------------------------------------------------
--- Moveable pipe
--------------------------------------------------------------------

function PipeController:setupMoveablePipe()
    self.validMovingTools = {}
    if self.cylinderedSpec and self.pipeSpec.numAutoAimingStates <= 0 then
        for i, m in ipairs(self.cylinderedSpec.movingTools) do
            -- Gets only the pipe moving tools.
            if m.freezingPipeStates ~= nil and next(m.freezingPipeStates) ~= nil then
                table.insert(self.validMovingTools, m)
            end
        end
    end
    self.hasPipeMovingTools = #self.validMovingTools > 0
    if self.dischargeSpec then
        self.dischargeNodeIndex = self.implement:getPipeDischargeNodeIndex()
        self.dischargeNode = self.dischargeSpec.dischargeNodes[self.dischargeNodeIndex]
    end
    for i, m in ipairs(self.validMovingTools) do
        local validBaseTool = true
        for i, mm in ipairs(self.validMovingTools) do
            if m ~= mm and getParent(m.node) == mm.node then 
                validBaseTool = false
            end
        end
        if validBaseTool then 
            self.baseMovingTool = m
            break
        end
    end
    for i, m in ipairs(self.validMovingTools) do 
        if m ~= self.baseMovingTool then 
            self.baseMovingToolChild = m
        end
    end

    self.tempBaseNode = CpUtil.createNode("tempBaseNode", 0, 0, 0)
    self.tempDependedNode = CpUtil.createNode("tempDependedNode", 0, 0, 0)
end

function PipeController:updateMoveablePipe(dt)
    if self.hasPipeMovingTools then
        if self.pipeSpec.unloadingStates[self.pipeSpec.currentState] == true then
            if self.baseMovingTool and self.baseMovingToolChild then 
                self:movePipeUp( self.baseMovingTool, self.baseMovingToolChild.node, dt)
                self:moveDependedPipePart(self.baseMovingToolChild, dt)
            else
                local _, y, _ = localToWorld(self.baseMovingTool.node, 0, 0, 0)
                local _, ny, _ = localToWorld(self.implement.rootNode, 0, 0, 0)
                if math.abs(y-ny) < 2 then 
                    self:movePipeUp( self.baseMovingTool, self.dischargeNode.node, dt)
                else 
               --     DebugUtil.drawDebugNode(self.baseMovingTool.node, "baseMovingTool")
                    self:moveDependedPipePart( self.baseMovingTool, dt)
                end
            end
        end
    end
end



function PipeController:moveDependedPipePart(tool, dt)
    local toolNode = tool.node   
    local dischargeNode = self.dischargeNode.node
    local toolDischargeDist = calcDistanceFrom(toolNode, dischargeNode)
    local exactFillRootNode = self:getClosestExactFillRootNode()

    local tx, ty, tz = localToWorld(dischargeNode, 0, 0, 0)
    local _, gy, _ = localToWorld(toolNode, 0, 0, 0)
   -- DebugUtil.drawDebugNode(dischargeNode, "dischargeNode")
    setTranslation(self.tempDependedNode, tx, gy, tz)
   -- DebugUtil.drawDebugNode(self.tempDependedNode, "tempDependedNode")

    local toolTempDist = calcDistanceFrom(toolNode, self.tempDependedNode)
    --- Absolute angle difference needed to be adjustment.
    local alpha = math.acos(toolTempDist/toolDischargeDist)

    local curRot = {}
    curRot[1], curRot[2], curRot[3] = getRotation(toolNode)
    local oldRot = curRot[tool.rotationAxis]
    local targetRot = 0
    if ty < gy then 
        --- Discharge node is below the tool node
        targetRot = oldRot + alpha
        if not self.pipeOnLeftSide then
            targetRot = oldRot - alpha
        end
    else 
        targetRot = oldRot - alpha
        if not self.pipeOnLeftSide then
            targetRot = oldRot + alpha
        end
    end

    if exactFillRootNode then 
     --   DebugUtil.drawDebugNode(exactFillRootNode, "exactFillRootNode")
        local _, gyT, _ = localToWorld(exactFillRootNode, 0, 0, 0)
        gyT = gyT + 1
        if gyT > gy then
            local d = gyT - gy
            local beta = math.asin(d/toolDischargeDist)
            if self.pipeOnLeftSide then
                targetRot  = targetRot + beta
            else 
                targetRot  = targetRot - beta
            end
        end
    end
  --  if g_currentMission.controlledVehicle and g_currentMission.controlledVehicle == self.vehicle then
  --      self:debug("Move depended: rotTarget: %.2f, oldRot: %.2f, rotMin: %.2f, rotMax: %.2f", targetRot, oldRot, tool.rotMin, tool.rotMax)
  --  end
    ImplementUtil.moveMovingToolToRotation(self.implement, tool, dt, MathUtil.clamp(targetRot, tool.rotMin, tool.rotMax))
end

function PipeController:movePipeUp(tool, childToolNode, dt)
    local toolNode = tool.node   
    local toolChildToolDist = calcDistanceFrom(toolNode, childToolNode)

  --  DebugUtil.drawDebugNode(childToolNode, "childToolNode")
  --  DebugUtil.drawDebugNode(toolNode, "toolNode")

    local exactFillRootNode = self:getClosestExactFillRootNode()
   
    local tx, ty, tz = localToWorld(childToolNode, 0, 0, 0)
    local gx, gy, gz = localToWorld(toolNode, 0, 0, 0)
    setTranslation(self.tempBaseNode, gx, ty, gz)
  --  DebugUtil.drawDebugNode(self.tempBaseNode, "tempNode")

    local toolTempDist = calcDistanceFrom(toolNode, self.tempBaseNode)
    --- Absolute angle difference needed to be adjustment.
    local alpha = math.asin(toolTempDist/toolChildToolDist)
    local curRot = {}
    curRot[1], curRot[2], curRot[3] = getRotation(toolNode)
    local oldRot = curRot[tool.rotationAxis]
    local targetRot = 0
    if ty > gy then 
        --- Discharge node is below the tool node
        targetRot = oldRot + alpha
        if not self.pipeOnLeftSide then
            targetRot = oldRot - alpha
        end
    else 
        targetRot = oldRot - alpha
        if not self.pipeOnLeftSide then
            targetRot = oldRot + alpha
        end
    end

    if exactFillRootNode then 
    --    DebugUtil.drawDebugNode(exactFillRootNode, "exactFillRootNode")
        local gxT, gyT, gzT = localToWorld(exactFillRootNode, 0, 0, 0)
        gyT = gyT + 2
        local terrainHeight = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, gxT, 0, gzT) + 4
        gyT = math.max(gyT, terrainHeight)
        local offset = gyT - gy
        if gyT < ty then
            local d = math.abs(gyT - gy + offset)
            local beta = math.asin(d/toolChildToolDist)
       --     DebugUtil.drawDebugLine(gxT, gyT, gzT, gx, gy, gz, 0, 0, 1)
       --     DebugUtil.drawDebugLine(tx, ty, tz, gxT, gyT, gzT, 0, 0, 1)
            targetRot = oldRot - beta
            if not self.pipeOnLeftSide then
                targetRot = oldRot + beta
            end
        --    if g_currentMission.controlledVehicle and g_currentMission.controlledVehicle == self.vehicle then
        --        self:debug("Move up: rotTarget: %.2f, oldRot: %.2f, rotMin: %.2f, rotMax: %.2f", targetRot, oldRot, tool.rotMin, tool.rotMax)
        --    end
        end
    end
    ImplementUtil.moveMovingToolToRotation(self.implement, tool, dt, MathUtil.clamp(targetRot, tool.rotMin, tool.rotMax))
end

function PipeController:delete()
    CpUtil.destroyNode(self.tempBaseNode)
    CpUtil.destroyNode(self.tempDependedNode)
end