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
    self.goalNode = CpUtil.createNode("goalPipeNode", 0, 0, 0)
end

function PipeController:update(dt)
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
    local toolBaseNode = getParent(tool.node)   

 
  --  local l1 = calcDistanceFrom(toolNode, toolBaseNode)
    local toolDischargeDist = calcDistanceFrom(toolNode, dischargeNode)

    DebugUtil.drawDebugNode(dischargeNode, "dischargeNode")
    DebugUtil.drawDebugNode(toolNode, "toolNode")
   -- DebugUtil.drawDebugNode(toolBaseNode, "toolBaseNode")

    local curRot = {}
    curRot[1], curRot[2], curRot[3] = getRotation(toolNode)
    local oldRot = curRot[tool.rotationAxis]

    local dx, dy, dz = localToLocal(dischargeNode, toolNode, 0, 0, 0)
    --- Goal position of the tool
    local gx, _, gz = localToWorld(toolNode, dx, 0, dz)
    local _, gy, _ = localToWorld(toolNode, 0, 0, 0)
    setTranslation(self.goalNode, gx, gy, gz)
    DebugUtil.drawDebugNode(self.goalNode, "goalNode")
   
    --- Temp node 
    local tx, ty, tz = localToWorld(dischargeNode, 0, 0, 0)
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
    local rx, ry, rz = localRotationToLocal(toolBaseNode, toolNode, 0, 0, alpha)
    self:debug("rx: %.2f, ry: %.2f, rz: %.2f",  rx, ry, rz )
    local rx, ry, rz = localRotationToLocal(toolNode, toolBaseNode, 0, 0, alpha)
    self:debug("r2x: %.2f, r2y: %.2f, r2z: %.2f",  rx, ry, rz )
    self:debug("oldRot: %.2f, alpha: %.2f", oldRot, alpha)
    ]]--
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
