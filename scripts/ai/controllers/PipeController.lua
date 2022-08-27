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
    ImplementUtil.setPipeAttributes(self, self.implement)
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

function PipeController:getCanDischargeToObject()
    local dischargeNode = self:getDischargeNode()
    if dischargeNode then
        local targetObject, _ = self.implement:getDischargeTargetObject(dischargeNode)
        return targetObject
    end
    return false
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
    self.tempNode = CpUtil.createNode("tempPipeNode", 0, 0, 0)
end

function PipeController:updateMoveablePipe(dt)
    if self.hasPipeMovingTools then
        if self.pipeSpec.unloadingStates[self.pipeSpec.currentState] == true then
            for i, m in ipairs(self.validMovingTools) do
                -- Only move the base pipe rod.
                if m == self.baseMovingTool then
                    self:movePipeUp(m, dt)
                else 
                    self:moveDependedPipePart(m, dt)
                end
            end
        end
    end
end


--- TODO: might be a good idea to make this variable for the trailer min height.
function PipeController:moveDependedPipePart(tool, dt)
    local toolNode = tool.node   
    local dischargeNode = self.dischargeNode.node
    local toolDischargeDist = calcDistanceFrom(toolNode, dischargeNode)

    DebugUtil.drawDebugNode(dischargeNode, "dischargeNode")
    DebugUtil.drawDebugNode(toolNode, "toolNode")

    --- Temp node 
    local tx, ty, tz = localToWorld(dischargeNode, 0, 0, 0)
    local _, gy, _ = localToWorld(toolNode, 0, 0, 0)
    setTranslation(self.tempNode, tx, gy, tz)
    DebugUtil.drawDebugNode(self.tempNode, "tempNode")

    local toolTempDist = calcDistanceFrom(toolNode, self.tempNode)
    --- Absolute angle difference needed to be adjustment.
    local alpha = math.acos(toolTempDist/toolDischargeDist)
    --[[
    local rx, ry, rz = localRotationToLocal(toolBaseNode, toolNode, 0, 0, 0)
    self:debug("rx: %.2f, ry: %.2f, rz: %.2f",  rx, ry, rz )
    local rx, ry, rz = localRotationToLocal(toolNode, toolBaseNode, 0, 0, 0)
    self:debug("r2x: %.2f, r2y: %.2f, r2z: %.2f",  rx, ry, rz )

    local rx, ry, rz = localRotationToLocal(self.tempNode, toolNode, 0, 0, 0)
    self:debug("rx: %.2f, ry: %.2f, rz: %.2f",  rx, ry, rz )

    local rotDiff = {}

    rotDiff[1], rotDiff[2], rotDiff[3] = localRotationToLocal(toolNode, self.tempNode, 0, 0, 0)
    self:debug("r2x: %.2f, r2y: %.2f, r2z: %.2f",  rotDiff[1], rotDiff[2], rotDiff[3] )
    self:debug("oldRot: %.2f, alpha: %.2f, rotationAxis: %d", oldRot, alpha, tool.rotationAxis)
    ]]--
    local curRot = {}
    curRot[1], curRot[2], curRot[3] = getRotation(toolNode)
    local oldRot = curRot[tool.rotationAxis]
    local targetRot = 0
    if ty < gy then 
        --- Discharge node is below the tool node
        targetRot = MathUtil.clamp(oldRot + alpha, tool.rotMin, tool.rotMax)
    else 
        targetRot = MathUtil.clamp(oldRot - alpha, tool.rotMin, tool.rotMax)
    end
    ImplementUtil.moveMovingToolToRotation(self.implement, tool, dt, targetRot)
end

function PipeController:movePipeUp(tool, dt)
    local rotTarget = tool.invertAxis and tool.rotMin or tool.rotMax
    local curRot ={}
    curRot[1], curRot[2], curRot[3] = getRotation(tool.node)
    --self:debug("Move up: rotTarget: %.2f, oldRot: %.2f, rotMin: %.2f, rotMax: %.2f", rotTarget, curRot[tool.rotationAxis], tool.rotMin, tool.rotMax)
    ImplementUtil.moveMovingToolToRotation(self.implement, tool, dt, rotTarget)
end

function PipeController:delete()
    CpUtil.destroyNode(self.tempNode)
end