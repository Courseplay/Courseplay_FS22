

--- This file is an example specialization.
--- The existing code is from the mod: ClickToSwitch.

---@class CourseplaySpec
CourseplaySpec = {}

CourseplaySpec.MOD_NAME = g_currentModName

function CourseplaySpec.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(Drivable, specializations) 
end

function CourseplaySpec.registerEventListeners(vehicleType)	
	SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", CourseplaySpec)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", CourseplaySpec)
    SpecializationUtil.registerEventListener(vehicleType, "onDraw", CourseplaySpec)
end

function CourseplaySpec.registerFunctions(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, 'setFieldWorkCourse', CourseplaySpec.setFieldWorkCourse)
    SpecializationUtil.registerFunction(vehicleType, 'getFieldWorkCourse', CourseplaySpec.getFieldWorkCourse)
    SpecializationUtil.registerFunction(vehicleType, 'getReverseDrivingDirectionNode', CourseplaySpec.getReverseDrivingDirectionNode)
--[[
    SpecializationUtil.registerFunction(vehicleType, "isCourseplaySpecMouseActive", CourseplaySpec.isCourseplaySpecMouseActive)
    SpecializationUtil.registerFunction(vehicleType, "onCourseplaySpecToggleMouse", CourseplaySpec.onCourseplaySpecToggleMouse)
    SpecializationUtil.registerFunction(vehicleType, "setFieldWorkCourseplaySpecShowMouseCursor", CourseplaySpec.setFieldWorkCourseplaySpecShowMouseCursor)
    SpecializationUtil.registerFunction(vehicleType, "getFieldWorkCourseplaySpecLastMousePosition", CourseplaySpec.getFieldWorkCourseplaySpecLastMousePosition)
    SpecializationUtil.registerFunction(vehicleType, "enterVehicleRaycastCourseplaySpec", CourseplaySpec.enterVehicleRaycastCourseplaySpec)
    SpecializationUtil.registerFunction(vehicleType, "enterVehicleRaycastCallbackCourseplaySpec", CourseplaySpec.enterVehicleRaycastCallbackCourseplaySpec)
]]--
end

function CourseplaySpec:onLoad(savegame)
	--- Register the spec: spec_courseplaySpec
    local specName = CourseplaySpec.MOD_NAME .. ".courseplaySpec"
    self.spec_courseplaySpec = self["spec_" .. specName]
    local spec = self.spec_courseplaySpec
    --[[
    spec.texts = {}
    spec.texts.toggleMouse = g_i18n:getText("input_CLICK_TO_SWITCH_TOGGLE_MOUSE")
    spec.texts.toggleMouseAlternative = g_i18n:getText("input_CLICK_TO_SWITCH_TOGGLE_MOUSE_ALTERNATIVE")
    spec.texts.changesAssignments = g_i18n:getText("input_CLICK_TO_SWITCH_CHANGES_ASSIGNMENTS")
    spec.texts.enterVehicle = g_i18n:getText("input_CLICK_TO_SWITCH_ENTER_VEHICLE")

    spec.mouseActive = false
    spec.assignmentMode = CourseplaySpec.DEFAULT_ASSIGNMENT
    --- Creating a backup table of all camera and if they are rotatable
    spec.camerasBackup = {}
    for camIndex, camera in pairs(self.spec_enterable.cameras) do
		if camera.isRotatable then
			spec.camerasBackup[camIndex] = camera.isRotatable
		end
	end
    ]]--
end

--- Register toggle mouse state and CourseplaySpec action events
---@param isActiveForInput boolean
---@param isActiveForInputIgnoreSelection boolean
function CourseplaySpec:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
	--[[
    if self.isClient then
        local spec = self.spec_courseplaySpec
        self:clearActionEventsTable(spec.actionEvents)
        if isActiveForInputIgnoreSelection then
            --- Toggle mouse action event
            local _, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.CLICK_TO_SWITCH_TOGGLE_MOUSE, self, CourseplaySpec.actionEventToggleMouse, false, true, false, true, nil)
            g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_NORMAL)
            g_inputBinding:setActionEventText(actionEventId, spec.texts.toggleMouse)
            --- CourseplaySpec (enter vehicle by mouse button) action event
            _, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.CLICK_TO_SWITCH_TOGGLE_MOUSE_ALTERNATIVE, self, CourseplaySpec.actionEventToggleMouse, false, true, false, true, nil)
            g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_NORMAL)
            g_inputBinding:setActionEventText(actionEventId, spec.texts.toggleMouseAlternative)

            --- CourseplaySpec (enter vehicle by mouse button) action event
            _, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.CLICK_TO_SWITCH_CHANGES_ASSIGNMENTS, self, CourseplaySpec.actionEventChangeAssignments, false, true, false, true, nil)
            g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_NORMAL)
            g_inputBinding:setActionEventText(actionEventId, spec.texts.changesAssignments)

            --- CourseplaySpec (enter vehicle by mouse button) action event
            _, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.CLICK_TO_SWITCH_ENTER_VEHICLE, self, CourseplaySpec.actionEventEnterVehicle, false, true, false, true, nil)
            g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_NORMAL)
            g_inputBinding:setActionEventText(actionEventId, spec.texts.enterVehicle)

            CourseplaySpec.updateActionEventState(self)
        end
    end
    ]]--
end;

--- Updates toggle mouse state and CourseplaySpec action events visibility and usability 
---@param self table vehicle
function CourseplaySpec.updateActionEventState(self)
    --- Activate/deactivate the CourseplaySpec action event 
    local spec = self.spec_courseplaySpec

    local actionEvent = spec.actionEvents[InputAction.CLICK_TO_SWITCH_ENTER_VEHICLE]
    g_inputBinding:setActionEventActive(actionEvent.actionEventId, self:isCourseplaySpecMouseActive())

    actionEvent = spec.actionEvents[InputAction.CLICK_TO_SWITCH_CHANGES_ASSIGNMENTS]
    g_inputBinding:setActionEventActive(actionEvent.actionEventId, not self:isCourseplaySpecMouseActive())

    actionEvent = spec.actionEvents[InputAction.CLICK_TO_SWITCH_TOGGLE_MOUSE]
    g_inputBinding:setActionEventActive(actionEvent.actionEventId, spec.assignmentMode == CourseplaySpec.DEFAULT_ASSIGNMENT)

    actionEvent = spec.actionEvents[InputAction.CLICK_TO_SWITCH_TOGGLE_MOUSE_ALTERNATIVE]
    g_inputBinding:setActionEventActive(actionEvent.actionEventId, spec.assignmentMode == CourseplaySpec.ADVANCED_ASSIGNMENT)
end

--- Action event for turning the mouse on/off
---@param self table vehicle
---@param actionName string
---@param inputValue number
---@param callbackState number
---@param isAnalog boolean
function CourseplaySpec.actionEventToggleMouse(self, actionName, inputValue, callbackState, isAnalog)
    self:setFieldWorkCourseplaySpecShowMouseCursor(not self:isCourseplaySpecMouseActive())
end

--- Action event for entering a vehicle by mouse click
---@param self table vehicle
---@param actionName string
---@param inputValue number
---@param callbackState number
---@param isAnalog boolean
function CourseplaySpec.actionEventEnterVehicle(self, actionName, inputValue, callbackState, isAnalog)
    if self:isCourseplaySpecMouseActive() then
        local x,y = self:getFieldWorkCourseplaySpecLastMousePosition()
        self:enterVehicleRaycastCourseplaySpec(x,y)
    end
end

function CourseplaySpec.actionEventChangeAssignments(self, actionName, inputValue, callbackState, isAnalog)
    local spec = self.spec_courseplaySpec
    spec.assignmentMode = CourseplaySpec.DEFAULT_ASSIGNMENT and CourseplaySpec.ADVANCED_ASSIGNMENT or CourseplaySpec.DEFAULT_ASSIGNMENT
    CourseplaySpec.updateActionEventState(self)
end

function CourseplaySpec:onCourseplaySpecToggleMouse()
    local spec = self.spec_courseplaySpec
    spec.mouseActive = not spec.mouseActive
    CourseplaySpec.updateActionEventState(self)
end

--- Is the mouse visible/active
function CourseplaySpec:isCourseplaySpecMouseActive()
    local spec = self.spec_courseplaySpec
    return spec.mouseActive
end

--- Active/disable the mouse cursor
---@param show boolean
function CourseplaySpec:setFieldWorkCourseplaySpecShowMouseCursor(show)
    local spec = self.spec_courseplaySpec
	g_inputBinding:setShowMouseCursor(show)
    self:onCourseplaySpecToggleMouse()
    ---While mouse cursor is active, disable the camera rotations
	for camIndex,_ in pairs(spec.camerasBackup) do
		self.spec_enterable.cameras[camIndex].isRotatable = not show
	end
end

--- Gets the last mouse cursor screen positions
---@return number posX
---@return number posY
function CourseplaySpec:getFieldWorkCourseplaySpecLastMousePosition()
    return g_inputBinding.mousePosXLast,g_inputBinding.mousePosYLast 
end

--- Creates a raycast relative to the current camera and the mouse click 
---@param mouseX number
---@param mouseY number
function CourseplaySpec:enterVehicleRaycastCourseplaySpec(posX, posY)
    local activeCam = getCamera()
    if activeCam ~= nil then
        local hx, hy, hz, px, py, pz = RaycastUtil.getCameraPickingRay(posX, posY, activeCam)
        raycastClosest(hx, hy, hz, px, py, pz, "enterVehicleRaycastCallbackCourseplaySpec", 1000, self, 371)
    end
end

--- Check and enters a vehicle.
---@param hitObjectId number
---@param x number world x hit position
---@param y number world y hit position
---@param z number world z hit position
---@param distance number distance at which the cast hit the object
---@return bool was the correct object hit?
function CourseplaySpec:enterVehicleRaycastCallbackCourseplaySpec(hitObjectId, x, y, z, distance)
    if hitObjectId ~= nil then
        local object = g_currentMission:getNodeObject(hitObjectId)    
        if object ~= nil then
            -- check if the object is a implement or trailer then get the rootVehicle 
            local rootVehicle = object.rootVehicle
            local targetObject = object.spec_enterable and object or rootVehicle~=nil and rootVehicle.spec_enterable and rootVehicle
            if targetObject then 
                -- this is a valid vehicle, so enter it
                g_currentMission:requestToEnterVehicle(targetObject)
                self:setFieldWorkCourseplaySpecShowMouseCursor(false)
                return false
            end                
        end
    end
    return true
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

function CourseplaySpec:onDraw(isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
    if self.course and self.course:isTemporary() and CpDebug:isChannelActive(CpDebug.DBG_COURSES) then
        self.course:draw()
    end
end
