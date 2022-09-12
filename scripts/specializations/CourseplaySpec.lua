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

function CourseplaySpec.registerEvents(vehicleType)	
    SpecializationUtil.registerEvent(vehicleType, "onCpUnitChanged")
    SpecializationUtil.registerEvent(vehicleType, "onCpDrawHudMap")
end

function CourseplaySpec.registerFunctions(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, 'getReverseDrivingDirectionNode', CourseplaySpec.getReverseDrivingDirectionNode)
end

function CourseplaySpec.registerOverwrittenFunctions(vehicleType)
  
end


function CourseplaySpec:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)

end



------------------------------------------------------------------------------------------------------------------------
--- Event listeners
---------------------------------------------------------------------------------------------------------------------------
function CourseplaySpec:onLoad(savegame)
	--- Register the spec: spec_courseplaySpec
    local specName = CourseplaySpec.MOD_NAME .. ".courseplaySpec"
    self.spec_courseplaySpec = self["spec_" .. specName]
    g_messageCenter:subscribe(MessageType.SETTING_CHANGED[GameSettings.SETTING.USE_MILES], CourseplaySpec.onUnitChanged, self)
    g_messageCenter:subscribe(MessageType.SETTING_CHANGED[GameSettings.SETTING.USE_ACRE], CourseplaySpec.onUnitChanged, self)
end

function CourseplaySpec:onUnitChanged()
    SpecializationUtil.raiseEvent(self,"onCpUnitChanged")
end

function CourseplaySpec:onPostLoad(savegame)
  
end

function CourseplaySpec:saveToXMLFile(xmlFile, baseKey, usedModNames)
   
end

function CourseplaySpec:onEnterVehicle(isControlling)
    
end

function CourseplaySpec:onLeaveVehicle(wasEntered)
   
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

--- Enriches the status data for the hud here.
function CourseplaySpec:onUpdateTick()
  
end

function CourseplaySpec:onDraw()
    
end


AIDriveStrategyCollision.getCollisionCheckActive = Utils.overwrittenFunction(
        AIDriveStrategyCollision.getCollisionCheckActive, CourseplaySpec.getCollisionCheckActive
)
