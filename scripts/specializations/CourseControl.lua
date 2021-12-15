--- High level control of the Course object in the vehicle.
--- TODO: improve relations to the courseManager

---@class CpCourseControl
CpCourseControl = {}

CpCourseControl.MOD_NAME = g_currentModName

CpCourseControl.KEY = "."..CpCourseControl.MOD_NAME..".cpCourseControl."
CpCourseControl.assignedCoursesKey = CpCourseControl.KEY.."Assignment"
CpCourseControl.xmlKey = "Course"

CpCourseControl.i18n = {
	["noCurrentCourse"] = "CP_courseManager_no_current_course",
	["temporaryCourse"] = "CP_courseManager_temporary_course",
}

--- generic xml course schema for saving/loading.
function CpCourseControl.registerXmlSchemaValues(schema,baseKey)
	baseKey = baseKey or ""
	schema:register(XMLValueType.STRING, baseKey .. CpCourseControl.xmlKey .. "#name", "Course name")
	schema:register(XMLValueType.FLOAT, baseKey .. CpCourseControl.xmlKey .. "#workWidth", "Course work width")
	schema:register(XMLValueType.INT, baseKey .. CpCourseControl.xmlKey .. "#numHeadlands", "Course number of headlands")
	schema:register(XMLValueType.INT, baseKey .. CpCourseControl.xmlKey .. "#multiTools", "Course multi tools")
	schema:register(XMLValueType.STRING, baseKey .. CpCourseControl.xmlKey .. ".waypoints", "Course serialized waypoints")
end

function CpCourseControl.initSpecialization()
    CpCourseControl.xmlSchema = XMLSchema.new("Course")
	local schema = CpCourseControl.xmlSchema
	CpCourseControl.registerXmlSchemaValues(schema,"")

    local schema = Vehicle.xmlSchemaSavegame
    local key = "vehicles.vehicle(?)" .. CpCourseControl.assignedCoursesKey
    schema:register(XMLValueType.INT, key .. "#id","assigned id")
    schema:register(XMLValueType.BOOL, key .. "#isSaved","assigned isSaved",false)
	CpCourseControl.registerXmlSchemaValues(schema,key..".Courses(?).")
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
    SpecializationUtil.registerFunction(vehicleType, 'hasCourse', CpCourseControl.hasCourse)
    SpecializationUtil.registerFunction(vehicleType, 'loadCourse', CpCourseControl.loadCourse)
    SpecializationUtil.registerFunction(vehicleType, 'saveCourse', CpCourseControl.saveCourse)
    SpecializationUtil.registerFunction(vehicleType, 'resetCourse', CpCourseControl.resetCourse)
    SpecializationUtil.registerFunction(vehicleType, 'getCourseName', CpCourseControl.getCourseName)
    SpecializationUtil.registerFunction(vehicleType, 'drawCoursePlot', CpCourseControl.drawCoursePlot)
end

function CpCourseControl:onLoad(savegame)
	--- Register the spec: spec_cpCourseControl
    local specName = CpCourseControl.MOD_NAME .. ".cpCourseControl"
    self.spec_cpCourseControl = self["spec_" .. specName]
    local spec = self.spec_cpCourseControl
    self.coursePlot = CoursePlot(g_currentMission.inGameMenu.ingameMap)
 --   TODO: make this an instance similar to course plot
 --   self.courseDisplay = CourseDisplay() 
end

function CpCourseControl:onPostLoad(savegame)
    CpCourseControl.loadAssignedCourses(self,savegame)
end

function CpCourseControl:loadAssignedCourses(savegame)
    if savegame == nil or savegame.resetVehicles then return end
    local spec = self.spec_cpCourseControl
    local courses = {}
    local baseKey = savegame.key..CpCourseControl.assignedCoursesKey
    local id = savegame.xmlFile:getValue(baseKey.."#id")
    local isSaved = savegame.xmlFile:getValue(baseKey.."#isSaved",false)
    savegame.xmlFile:iterate(baseKey..".Courses",function (i,key)
        local course = CourseUtil.createFromXml(self,savegame.xmlFile,key..".Course")
        table.insert(courses,course)
    end)
    if courses ~= nil and next(courses) then
        self.course = courses[1]
        self.course:setVehicle(self)
        g_courseManager:setAssignedCourseFromSaveGame(self, id ,courses,isSaved)
        SpecializationUtil.raiseEvent(self,"onCourseChange",courses[1])
    end
end

function CpCourseControl:saveToXMLFile(xmlFile, baseKey, usedModNames)
    CpCourseControl.saveAssignedCourses(self,xmlFile, baseKey, usedModNames)
end

function CpCourseControl:saveAssignedCourses(xmlFile, baseKey, usedModNames)
    local ix,assignment = g_courseManager:getAssignment(self)
    local courses = assignment.courses
    if courses ~=nil and next(courses) then
        local baseKey = baseKey..".Assignment"
        if ix ~= nil then
            xmlFile:setValue(baseKey.."#id",ix)
            xmlFile:setValue(baseKey.."#isSaved",assignment.isSaved)
        end
        for i=1,#courses do 
            local key = string.format("%s.Courses(%d).Course",baseKey,i-1)
            local course = courses[i]
            CourseUtil.saveToXml(course,xmlFile, key)
        end
    end
end

---@param course  Course
function CpCourseControl:setFieldWorkCourse(course)
    self:resetCourse()
    self.course = course
	g_courseManager:loadGeneratedCourse(self, self.course)
    self.course:setVehicle(self)
    SpecializationUtil.raiseEvent(self,"onCourseChange",self.course)
end

function CpCourseControl:resetCourse()
    self.course = nil
    g_courseManager:unloadAllCoursesFromVehicle(self, self.course)
    SpecializationUtil.raiseEvent(self,"onCourseChange")
end

---@return Course
function CpCourseControl:getFieldWorkCourse()
    return self.course
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
end

function CpCourseControl:drawCoursePlot(map)
    self.coursePlot:draw(map)
end

function CpCourseControl:onDraw()
--    self.courseDisplay:draw()
end

function CpCourseControl:onReadStream(streamId)

end

function CpCourseControl:onWriteStream(streamId)
	
end

function CpCourseControl:hasCourse()
    return self.course ~= nil
end

function CpCourseControl:getCourseName()
    if self:hasCourse() then 
        local name = g_courseManager:getCourseName(self)
        return name or g_i18n:getText(CpCourseControl.i18n.temporaryCourse)
    end
    return g_i18n:getText(CpCourseControl.i18n.noCurrentCourse)
end

function CpCourseControl:loadCourse(ix)
    self.course = g_courseManager:loadCourseSelectedInHud(self,ix)
    SpecializationUtil.raiseEvent(self,"onCourseChange",self.course)
end

function CpCourseControl:saveCourse(ix,text)
    g_courseManager:saveCourseFromVehicle(ix, self, text)
end

function CpCourseControl:onPreDelete()
    self:resetCourse()
end

