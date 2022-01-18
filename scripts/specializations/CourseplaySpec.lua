--- Cp ai driver spec

---@class CourseplaySpec
CourseplaySpec = {}

CourseplaySpec.MOD_NAME = g_currentModName

CourseplaySpec.KEY = "."..CourseplaySpec.MOD_NAME..".courseplaySpec."

function CourseplaySpec.initSpecialization()
    local schema = Vehicle.xmlSchemaSavegame
end

function CourseplaySpec.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(AIFieldWorker, specializations) 
end

function CourseplaySpec.registerEventListeners(vehicleType)	
	SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", CourseplaySpec)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", CourseplaySpec)
    SpecializationUtil.registerEventListener(vehicleType, "onPostLoad", CourseplaySpec)
    SpecializationUtil.registerEventListener(vehicleType, "onUpdateTick", CourseplaySpec)
    SpecializationUtil.registerEventListener(vehicleType, "onEnterVehicle", CourseplaySpec)
    SpecializationUtil.registerEventListener(vehicleType, "onLeaveVehicle", CourseplaySpec)
    SpecializationUtil.registerEventListener(vehicleType, "onDraw", CourseplaySpec)
end

function CourseplaySpec.registerFunctions(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, 'getReverseDrivingDirectionNode', CourseplaySpec.getReverseDrivingDirectionNode)
    SpecializationUtil.registerFunction(vehicleType, 'getCpAdditionalHotspotDetails', CourseplaySpec.getCpAdditionalHotspotDetails)
    SpecializationUtil.registerFunction(vehicleType, 'cpInit', CourseplaySpec.cpInit)
end

function CourseplaySpec.registerOverwrittenFunctions(vehicleType)
   -- SpecializationUtil.registerOverwrittenFunction(vehicleType, "getStartAIJobText", CourseplaySpec.getStartAIJobText)
  
end

function CourseplaySpec:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
    --print(string.format('%s %s %s', self:getName(), isActiveForInput, isActiveForInputIgnoreSelection))
    if isActiveForInputIgnoreSelection or self == g_currentMission.controlledVehicle then
        --- Toggle mouse cursor action event
        local _, actionEventId = g_inputBinding:registerActionEvent(InputAction.CP_TOGGLE_MOUSE, self,
                CourseplaySpec.actionEventToggleMouse, false, true, false, true)

        g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_NORMAL)
        g_inputBinding:setActionEventText(actionEventId, "Toggle mouse")
        g_inputBinding:setActionEventActive(true)
    end
end

function CourseplaySpec:actionEventToggleMouse()
    local showMouseCursor = not g_inputBinding:getShowMouseCursor()
    CpUtil.debugVehicle(CpDebug.DBG_HUD, self, 'show mouse cursor %s', showMouseCursor)
    g_inputBinding:setShowMouseCursor(showMouseCursor)
    ---While mouse cursor is active, disable the camera rotations
    CpGuiUtil.setCameraRotation(self, not showMouseCursor, self.spec_courseplaySpec.savedCameraRotatableInfo)
end

------------------------------------------------------------------------------------------------------------------------
--- Event listeners
---------------------------------------------------------------------------------------------------------------------------
function CourseplaySpec:onLoad(savegame)
	--- Register the spec: spec_courseplaySpec
    local specName = CourseplaySpec.MOD_NAME .. ".courseplaySpec"
    self.spec_courseplaySpec = self["spec_" .. specName]
    local spec = self.spec_courseplaySpec
    spec.hud = CourseplayHud(self)
    self.status = CourseplayStatus(false)

end

function CourseplaySpec:onPostLoad(savegame)

end

function CourseplaySpec:saveToXMLFile(xmlFile, baseKey, usedModNames)
   
end

function CourseplaySpec:onEnterVehicle(isControlling)
    -- if the mouse cursor is shown when we enter the vehicle, disable camera rotations
    CpGuiUtil.setCameraRotation(self, not g_inputBinding:getShowMouseCursor(),
            self.spec_courseplaySpec.savedCameraRotatableInfo)
end

function CourseplaySpec:onLeaveVehicle(isControlling)
   
end

--- TODO: return all relevant values that should be displayed under the map hotspot.
function CourseplaySpec:getCpAdditionalHotspotDetails()
    --- time remaining in s
    return 60
end


function CourseplaySpec:getReverseDrivingDirectionNode()
    local spec = self.spec_courseplaySpec
    if not spec.reverseDrivingDirectionNode and SpecializationUtil.hasSpecialization(ReverseDriving, self.specializations) then
        spec.reverseDrivingDirectionNode =
            CpUtil.createNewLinkedNode(self, "realReverseDrivingDirectionNode", self:getAIDirectionNode())
        setRotation(spec.reverseDrivingDirectionNode, 0, math.pi, 0)
    end
    return spec.reverseDrivingDirectionNode
end

function CourseplaySpec:isCollisionDetectionEnabled()
    return self.collisionDetectionEnabled
end

function CourseplaySpec:enableCollisionDetection()
    self.collisionDetectionEnabled = true
end

function CourseplaySpec:disableCollisionDetection()
    self.collisionDetectionEnabled = false
end

--- This is to be able to disable the built-in AIDriveStrategyCollision check from our drive strategies
function CourseplaySpec:getCollisionCheckActive(superFunc,...)
    if self.collisionDetectionEnabled then
        return superFunc(self,...)
    else
        return false
    end
end

function CourseplaySpec:onUpdateTick()
    local strategy
    if self:getIsCpFieldWorkActive() then
        strategy = self:getCpDriveStrategy()
    end
    if strategy then
        self.spec_courseplaySpec.status = strategy:getStatus()
    else
        self.spec_courseplaySpec.status = CourseplayStatus(false)
    end
end

function CourseplaySpec:onDraw()
    self.spec_courseplaySpec.hud:draw(self.spec_courseplaySpec.status)
end

function CourseplaySpec:cpInit()
    self.spec_courseplaySpec.hud = CourseplayHud(self)
end

AIDriveStrategyCollision.getCollisionCheckActive = Utils.overwrittenFunction(
        AIDriveStrategyCollision.getCollisionCheckActive, CourseplaySpec.getCollisionCheckActive
)
