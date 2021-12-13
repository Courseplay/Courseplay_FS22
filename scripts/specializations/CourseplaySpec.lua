--- Cp ai driver spec

---@class CourseplaySpec
CourseplaySpec = {}

CourseplaySpec.MOD_NAME = g_currentModName

function CourseplaySpec.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(AIFieldWorker, specializations) 
end

function CourseplaySpec.registerEventListeners(vehicleType)	
--	SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", CourseplaySpec)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", CourseplaySpec)
--    SpecializationUtil.registerEventListener(vehicleType, "onDraw", CourseplaySpec)
    SpecializationUtil.registerEventListener(vehicleType, "onEnterVehicle", CourseplaySpec)
    SpecializationUtil.registerEventListener(vehicleType, "onLeaveVehicle", CourseplaySpec)
end

function CourseplaySpec.registerFunctions(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, 'setFieldWorkCourse', CourseplaySpec.setFieldWorkCourse)
    SpecializationUtil.registerFunction(vehicleType, 'getFieldWorkCourse', CourseplaySpec.getFieldWorkCourse)
    SpecializationUtil.registerFunction(vehicleType, 'getReverseDrivingDirectionNode', CourseplaySpec.getReverseDrivingDirectionNode)
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

function CourseplaySpec:onEnterVehicle(isControlling)
    g_courseDisplay:setSignsVisibility(self);
end

function CourseplaySpec:onLeaveVehicle(isControlling)
    g_courseDisplay:setSignsVisibility(self, true);
end

---@param course : Course
function CourseplaySpec:setFieldWorkCourse(course)
    self.course = course
end

---@return Course
function CourseplaySpec:getFieldWorkCourse()
    return self.course
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

