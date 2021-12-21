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
--	SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", CourseplaySpec)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", CourseplaySpec)
    SpecializationUtil.registerEventListener(vehicleType, "onPostLoad", CourseplaySpec)
--    SpecializationUtil.registerEventListener(vehicleType, "getStartAIJobText", CourseplaySpec)
    SpecializationUtil.registerEventListener(vehicleType, "onEnterVehicle", CourseplaySpec)
    SpecializationUtil.registerEventListener(vehicleType, "onLeaveVehicle", CourseplaySpec)

end

function CourseplaySpec.registerFunctions(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, 'getReverseDrivingDirectionNode', CourseplaySpec.getReverseDrivingDirectionNode)
    SpecializationUtil.registerFunction(vehicleType, 'getCpAdditionalHotspotDetails', CourseplaySpec.getCpAdditionalHotspotDetails)
end

function CourseplaySpec.registerOverwrittenFunctions(vehicleType)
   -- SpecializationUtil.registerOverwrittenFunction(vehicleType, "getStartAIJobText", CourseplaySpec.getStartAIJobText)
  
end
------------------------------------------------------------------------------------------------------------------------
--- Event listeners
---------------------------------------------------------------------------------------------------------------------------
function CourseplaySpec:onLoad(savegame)
	--- Register the spec: spec_courseplaySpec
    local specName = CourseplaySpec.MOD_NAME .. ".courseplaySpec"
    self.spec_courseplaySpec = self["spec_" .. specName]
    local spec = self.spec_courseplaySpec
end

function CourseplaySpec:onPostLoad(savegame)

end

function CourseplaySpec:saveToXMLFile(xmlFile, baseKey, usedModNames)
   
end

function CourseplaySpec:onEnterVehicle(isControlling)
    
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

AIDriveStrategyCollision.getCollisionCheckActive = Utils.overwrittenFunction(
        AIDriveStrategyCollision.getCollisionCheckActive, CourseplaySpec.getCollisionCheckActive
)
