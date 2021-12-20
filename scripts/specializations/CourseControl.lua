--- High level control of the Course object in the vehicle.
--- TODO: improve relations to the courseManager

---@class CpCourseControl
CpCourseControl = {}

CpCourseControl.MOD_NAME = g_currentModName

CpCourseControl.KEY = "."..CpCourseControl.MOD_NAME..".cpCourseControl."
CpCourseControl.xmlKey = "Course"
CpCourseControl.rootKey = "AssignedCourses"
CpCourseControl.rootKeyFileManager = "Courses"
CpCourseControl.xmlKeyFileManager = "Courses.Course"

CpCourseControl.i18n = {
	["noCurrentCourse"] = "CP_courseManager_no_current_course",
	["temporaryCourse"] = "CP_courseManager_temporary_course",
}
CpCourseControl.vehicles = {}

--- generic xml course schema for saving/loading.
function CpCourseControl.registerXmlSchemaValues(schema,baseKey)
	baseKey = baseKey or ""
	schema:register(XMLValueType.STRING, baseKey .. "#name", "Course name")
	schema:register(XMLValueType.FLOAT, baseKey  .. "#workWidth", "Course work width")
	schema:register(XMLValueType.INT, baseKey .. "#numHeadlands", "Course number of headlands")
	schema:register(XMLValueType.INT, baseKey .. "#multiTools", "Course multi tools")
    schema:register(XMLValueType.BOOL, baseKey .. "#isSavedAsFile", "Course is saved as file or temporary ?",false)
	schema:register(XMLValueType.STRING, baseKey .. ".waypoints", "Course serialized waypoints")
end

function CpCourseControl.initSpecialization()
    CpCourseControl.xmlSchema = XMLSchema.new("Course")
	local schema = CpCourseControl.xmlSchema
	CpCourseControl.registerXmlSchemaValues(schema,CpCourseControl.xmlKeyFileManager .."(?)")

    local schema = Vehicle.xmlSchemaSavegame
    local key = "vehicles.vehicle(?)" .. CpCourseControl.KEY .. CpCourseControl.rootKey
---    schema:register(XMLValueType.BOOL, key .. "#hasTemporaryCourses","Are the courses a temporary and not saved?",false)
	CpCourseControl.registerXmlSchemaValues(schema,key.."(?)")
end

function CpCourseControl.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(AIFieldWorker, specializations) 
end

function CpCourseControl.registerEventListeners(vehicleType)	
--	SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", CpCourseControl)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", CpCourseControl)
    SpecializationUtil.registerEventListener(vehicleType, "onPostLoad", CpCourseControl)
    SpecializationUtil.registerEventListener(vehicleType, "onWriteStream", CpCourseControl)
    SpecializationUtil.registerEventListener(vehicleType, "onReadStream", CpCourseControl)
    SpecializationUtil.registerEventListener(vehicleType, "onCourseChange", CpCourseControl)
    SpecializationUtil.registerEventListener(vehicleType, "onPreDelete", CpCourseControl)
    SpecializationUtil.registerEventListener(vehicleType, "onDraw", CpCourseControl)
    SpecializationUtil.registerEventListener(vehicleType, "updateSignVisibility", CpCourseControl)
    SpecializationUtil.registerEventListener(vehicleType, "onEnterVehicle", CpCourseControl)
    SpecializationUtil.registerEventListener(vehicleType, "onLeaveVehicle", CpCourseControl)
end

function CpCourseControl.registerEvents(vehicleType)
    SpecializationUtil.registerEvent(vehicleType, 'updateSignVisibility', CpCourseControl.updateSignVisibility)
    SpecializationUtil.registerEvent(vehicleType, 'onCourseChange', CpCourseControl.onCourseChange)
end

function CpCourseControl.registerFunctions(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, 'setFieldWorkCourse', CpCourseControl.setFieldWorkCourse)
    SpecializationUtil.registerFunction(vehicleType, 'getFieldWorkCourse', CpCourseControl.getFieldWorkCourse)
    SpecializationUtil.registerFunction(vehicleType, 'addCourse', CpCourseControl.addCourse)
    SpecializationUtil.registerFunction(vehicleType, 'getCourses', CpCourseControl.getCourses)
    SpecializationUtil.registerFunction(vehicleType, 'hasCourse', CpCourseControl.hasCourse)
    
    SpecializationUtil.registerFunction(vehicleType, 'appendLoadedCourse', CpCourseControl.appendLoadedCourse)
    SpecializationUtil.registerFunction(vehicleType, 'saveCourses', CpCourseControl.saveCourses)
    SpecializationUtil.registerFunction(vehicleType, 'resetCourses', CpCourseControl.resetCourses)
    SpecializationUtil.registerFunction(vehicleType, 'getCurrentCourseName', CpCourseControl.getCurrentCourseName)
    
    SpecializationUtil.registerFunction(vehicleType, 'drawCoursePlot', CpCourseControl.drawCoursePlot)
    
    SpecializationUtil.registerFunction(vehicleType, 'loadAssignedCourses', CpCourseControl.loadAssignedCourses)
    SpecializationUtil.registerFunction(vehicleType, 'saveAssignedCourses', CpCourseControl.saveAssignedCourses)

    SpecializationUtil.registerFunction(vehicleType, 'updateLegacyWaypoints', CpCourseControl.updateLegacyWaypoints)
    SpecializationUtil.registerFunction(vehicleType, 'getLegacyWaypoints', CpCourseControl.getLegacyWaypoints)
end

function CpCourseControl:onLoad(savegame)
	--- Register the spec: spec_cpCourseControl
    local specName = CpCourseControl.MOD_NAME .. ".cpCourseControl"
    self.spec_cpCourseControl = self["spec_" .. specName]
    local spec = self.spec_cpCourseControl
    self.coursePlot = CoursePlot(g_currentMission.inGameMenu.ingameMap)
 
    self.courses = {}
    
 --   TODO: make this an instance similar to course plot
 --   self.courseDisplay = CourseDisplay() 
    CpCourseControl.vehicles[self.id] = self

    spec.legacyWaypoints = {}
end

function CpCourseControl:onPostLoad(savegame)
    if savegame == nil or savegame.resetVehicles then return end
    self:loadAssignedCourses(savegame.xmlFile,savegame.key..CpCourseControl.KEY..CpCourseControl.rootKey )
end

function CpCourseControl:loadAssignedCourses(xmlFile,baseKey)
    local spec = self.spec_cpCourseControl
    local courses = {}
    xmlFile:iterate(baseKey,function (i,key)
        local course = Course.createFromXml(self,xmlFile,key)
        course:setVehicle(self)
        table.insert(courses,course)
    end)    
    if courses ~= nil and next(courses) then
        spec.courses = courses
        SpecializationUtil.raiseEvent(self,"onCourseChange",courses[1])
    end
end

function CpCourseControl:saveToXMLFile(xmlFile, baseKey, usedModNames)
    self:saveAssignedCourses(xmlFile, baseKey.."."..CpCourseControl.rootKey)
end

function CpCourseControl:saveAssignedCourses(xmlFile, baseKey,name)
    local spec = self.spec_cpCourseControl
    local courses = spec.courses
    if courses ~=nil and next(courses) then
        for i=1,#courses do 
            local key = string.format("%s(%d)",baseKey,i-1)
            local course = courses[i]
            if name then 
                course:setName(name)
            end
            course:saveToXml(xmlFile, key)
        end
    end
end

---@param course  Course
function CpCourseControl:setFieldWorkCourse(course)
    self:resetCourses()
    self:addCourse(course)   
end

function CpCourseControl:addCourse(course)
    local spec = self.spec_cpCourseControl
    course:setVehicle(self)
    table.insert(spec.courses,course)
    SpecializationUtil.raiseEvent(self,"onCourseChange",course)
end

function CpCourseControl:resetCourses()
    local spec = self.spec_cpCourseControl
    spec.courses = {}
    SpecializationUtil.raiseEvent(self,"onCourseChange")
end

---@return Course
function CpCourseControl:getFieldWorkCourse()
    local spec = self.spec_cpCourseControl
    --- TODO: For now only returns the first course.
    return spec.courses[1]
end

function CpCourseControl:getCourses()
    local spec = self.spec_cpCourseControl
    return spec.courses
end

function CpCourseControl:hasCourse()
    local spec = self.spec_cpCourseControl
    return next(spec.courses) ~= nil
end


function CpCourseControl:updateSignVisibility()
    g_courseDisplay:updateWaypointSigns(self)
 --   self.courseDisplay:updateWaypointSigns(self)
end

function CpCourseControl:onEnterVehicle(isControlling)
    g_courseDisplay:setSignsVisibility(self);
    
end

function CpCourseControl:onLeaveVehicle(isControlling)
    g_courseDisplay:setSignsVisibility(self, true);
   
end

function CpCourseControl:onCourseChange(newCourse)
    if newCourse then 
        -- we have course, show the course plot on the AI helper screen
        self.coursePlot:setWaypoints(newCourse.waypoints)
        self.coursePlot:setVisible(true)
    else 
        self.coursePlot:setVisible(false)
    end
    if g_client then
        g_courseDisplay:updateWaypointSigns(self)
    --    self.courseDisplay:updateWaypointSigns(self)
	end

    self:updateLegacyWaypoints()
end

function CpCourseControl:drawCoursePlot(map)
    if self:hasCourse() then
        self.coursePlot:draw(map)
    end
end

function CpCourseControl:onDraw()
--    self.courseDisplay:draw()
end

function CpCourseControl:onReadStream(streamId)

end

function CpCourseControl:onWriteStream(streamId)
	
end

function CpCourseControl:onPreDelete()
    CpCourseControl.vehicles[self.id] = nil
    self:resetCourses()
end

------------------------------------------------------------------------
-- Interaction between the course manager frame and the vehicle courses.
------------------------------------------------------------------------

function CpCourseControl:getCurrentCourseName()
    if self:hasCourse() then 
        local courses = self:getCourses()
        local name =  CpCourseControl.getCourseName(courses[1])
        for i = 2,#courses do 
            name = string.format("%s + %s",name,CpCourseControl.getCourseName(courses[i]))
        end  
        name = string.format("%s (%d)",name,#courses)
        return name
    end
    return g_i18n:getText(CpCourseControl.i18n.noCurrentCourse)
end

function CpCourseControl.getCourseName(course)
	local name = course:getName()
    local isSavedAsFile = course:isSavedAsFile()
    if not isSavedAsFile or name == "" then 
        g_i18n:getText(CpCourseControl.i18n.temporaryCourse)
    end
    return name
end

function CpCourseControl:appendLoadedCourse(file)
    file:load(CpCourseControl.xmlSchema,CpCourseControl.xmlKeyFileManager,
    CpCourseControl.loadAssignedCourses,self)
end

function CpCourseControl:saveCourses(file,text)
    file:save(CpCourseControl.rootKeyFileManager,CpCourseControl.xmlSchema,
    CpCourseControl.xmlKeyFileManager,CpCourseControl.saveAssignedCourses,self,text)
end

function CpCourseControl.getValidVehicles()
    return CpCourseControl.vehicles
end

function CpCourseControl:appendCourse(course)

end

function CpCourseControl:getFieldworkCourseLegacy(vehicle)
	for _, course in ipairs(self:getCourses()) do
		if course:isFieldworkCourse() then
			CpUtil.debugVehicle(CpDebug.DBG_COURSES,vehicle, 'getting fieldwork course %s', course:getName())
			return course
		end
	end
end

--- For backwards compatibility, create all waypoints of all loaded courses for this vehicle, as it
--- used to be stored in the terrible global Waypoints variable
--- Update all the legacy (as usual global) data structures related to a vehicle's loaded course
-- TODO: once someone has the time and motivation, refactor those legacy structures
function CpCourseControl:updateLegacyWaypoints()
    local spec = self.spec_cpCourseControl
	spec.legacyWaypoints = {}
	local n = 1
	for _, course in ipairs(self:getCourses()) do
		for i = 1, course:getNumberOfWaypoints() do
			table.insert(spec.legacyWaypoints, Waypoint(course:getWaypoint(i), n))
			n = n +1
		end
	end
end

function CpCourseControl:getLegacyWaypoints()
    local spec = self.spec_cpCourseControl
	return spec.legacyWaypoints
end
