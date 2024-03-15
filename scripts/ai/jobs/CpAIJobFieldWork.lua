--- AI job derived of CpAIJob.
---@class CpAIJobFieldWork : CpAIJob
CpAIJobFieldWork = {
    name = "FIELDWORK_CP",
    jobName = "CP_job_fieldWork",
    GenerateButton = "FIELDWORK_BUTTON",
    fieldPositionParameterText = "CP_fieldWorkJobParameters_fieldPosition_title"
}
local AIJobFieldWorkCp_mt = Class(CpAIJobFieldWork, CpAIJob)

function CpAIJobFieldWork.new(isServer, customMt)
    local self = CpAIJob.new(isServer, customMt or AIJobFieldWorkCp_mt)

    self.hasValidPosition = false
    self.foundVines = nil
    self.selectedFieldPlot = FieldPlot(true)
    self.selectedFieldPlot:setVisible(false)
    return self
end

function CpAIJobFieldWork:setupTasks(isServer)
    -- this will add a standard driveTo task to drive to the target position selected by the user
    CpAIJobFieldWork:superClass().setupTasks(self, isServer)
    -- then we add our own driveTo task to drive from the target position to the waypoint where the
    -- fieldwork starts (first waypoint or the one we worked on last)
    self.attachHeaderTask = CpAITaskAttachHeader(isServer, self)
    self.driveToFieldWorkStartTask = CpAITaskDriveTo(isServer, self)
    self.fieldWorkTask = CpAITaskFieldWork(isServer, self)
end

function CpAIJobFieldWork:onPreStart()
    CpAIJob.onPreStart(self)
    self:removeTask(self.attachHeaderTask)
    self:removeTask(self.driveToFieldWorkStartTask)
    self:removeTask(self.fieldWorkTask)
    local vehicle = self:getVehicle()
    if vehicle and (AIUtil.hasCutterOnTrailerAttached(vehicle) 
        or AIUtil.hasCutterAsTrailerAttached(vehicle)) then 
        --- Only add the attach header task, if needed.
        self:addTask(self.attachHeaderTask)
    end
    self:addTask(self.driveToFieldWorkStartTask)
    self:addTask(self.fieldWorkTask)
end

function CpAIJobFieldWork:setupJobParameters()
    CpAIJob.setupJobParameters(self)
    self:setupCpJobParameters(CpFieldWorkJobParameters(self))
end

---@param vehicle table
---@param mission Mission
---@param farmId number
---@param isDirectStart boolean disables the drive to by giants
---@param isStartPositionInvalid boolean resets the drive to target position by giants and the field position to the vehicle position.
function CpAIJobFieldWork:applyCurrentState(vehicle, mission, farmId, isDirectStart, isStartPositionInvalid)
    CpAIJobFieldWork:superClass().applyCurrentState(self, vehicle, mission, farmId, isDirectStart)

    local _
    local x, z = self.cpJobParameters.fieldPosition:getPosition()

    if x == nil or z == nil then
        x, _, z = getWorldTranslation(vehicle.rootNode)
    end

    self.cpJobParameters.fieldPosition:setPosition(x, z)

    if isStartPositionInvalid then
        local x, _, z = getWorldTranslation(vehicle.rootNode) 
        local dirX, _, dirZ = localDirectionToWorld(vehicle.rootNode, 0, 0, 1)
        local angle = MathUtil.getYRotationFromDirection(dirX, dirZ)
        
        self.cpJobParameters.startPosition:setPosition(x, z)
        self.cpJobParameters.startPosition:setAngle(angle)

        self.cpJobParameters.fieldPosition:setPosition(x, z)
    end
end

--- Checks the field position setting.
function CpAIJobFieldWork:validateFieldSetup(isValid, errorMessage)

    if not isValid then
        return isValid, errorMessage
    end

    local vehicle = self.vehicleParameter:getVehicle()

    -- everything else is valid, now find the field
    local tx, tz = self.cpJobParameters.fieldPosition:getPosition()
    if tx == nil or tz == nil then 
        return false, g_i18n:getText("CP_error_not_on_field")
    end
    self.hasValidPosition = false
    self.foundVines = nil
    local fieldPolygon, isCustomField = CpFieldUtil.getFieldPolygonAtWorldPosition(tx, tz)
    self:setFieldPolygon(fieldPolygon)
    if fieldPolygon then
        self.hasValidPosition = true
        self.foundVines = g_vineScanner:findVineNodesInField(fieldPolygon, tx, tz, self.customField ~= nil)
        if self.foundVines then
            CpUtil.debugVehicle(CpDebug.DBG_FIELDWORK, vehicle, "Found vine nodes, generating a vine field border.")
            fieldPolygon = g_vineScanner:getCourseGeneratorVertices(0, tx, tz)
        end
        self.selectedFieldPlot:setWaypoints(fieldPolygon)
        self.selectedFieldPlot:setVisible(true)
        self.selectedFieldPlot:setBrightColor(true)
        if isCustomField then
            CpUtil.infoVehicle(vehicle, 'disabling island bypass on custom field')
            vehicle:getCourseGeneratorSettings().islandBypassMode:setValue(Island.BYPASS_MODE_NONE)
        end
    else
        self.selectedFieldPlot:setVisible(false)
        return false, g_i18n:getText("CP_error_not_on_field")
    end

    return true, ''
end

function CpAIJobFieldWork:setValues()
    CpAIJobFieldWork:superClass().setValues(self)
    local vehicle = self.vehicleParameter:getVehicle()
    self.driveToFieldWorkStartTask:reset()
    self.driveToFieldWorkStartTask:setVehicle(vehicle)
    self.attachHeaderTask:setVehicle(vehicle)
    self.fieldWorkTask:setVehicle(vehicle)
end

--- Called when parameters change, scan field
function CpAIJobFieldWork:validate(farmId)
    local isValid, errorMessage = CpAIJobFieldWork:superClass().validate(self, farmId)
    if not isValid then
        return isValid, errorMessage
    end
    local vehicle = self.vehicleParameter:getVehicle()

    --- Only check the valid field position in the in game menu.
    if not self.isDirectStart then
        isValid, errorMessage = self:validateFieldSetup(isValid, errorMessage)
        if not isValid then
            return isValid, errorMessage
        end
        self.cpJobParameters:validateSettings()
    end

    if not vehicle:hasCpCourse() then
        return false, g_i18n:getText("CP_error_no_course")
    end
    return true, ''
end

function CpAIJobFieldWork:draw(map)
    if self.selectedFieldPlot then
        self.selectedFieldPlot:draw(map)
    end
end

function CpAIJobFieldWork:getCanGenerateFieldWorkCourse()
    return self.hasValidPosition
end

-- To pass an alignment course from the drive to fieldwork start to the fieldwork, so the
-- fieldwork strategy can continue the alignment course set up by the drive to fieldwork start strategy.
function CpAIJobFieldWork:setStartFieldWorkCourse(course, ix)
    self.startFieldWorkCourse = course
    self.startFieldWorkCourseIx = ix
end

function CpAIJobFieldWork:getStartFieldWorkCourse()
    return self.startFieldWorkCourse, self.startFieldWorkCourseIx
end

--- Is course generation allowed ?
function CpAIJobFieldWork:isCourseGenerationAllowed()
    local vehicle = self:getVehicle()
    --- Disables the course generation for bale loaders and wrappers.
    local baleFinderAllowed = vehicle and vehicle:getCanStartCpBaleFinder()
    return self:getCanGenerateFieldWorkCourse() and not baleFinderAllowed
end

function CpAIJobFieldWork:getCanStartJob()
    local vehicle = self:getVehicle()
    return vehicle and vehicle:hasCpCourse()
end

--- Button callback to generate a field work course.
function CpAIJobFieldWork:onClickGenerateFieldWorkCourse()
    local vehicle = self.vehicleParameter:getVehicle()
    local fieldPolygon = self:getFieldPolygon()
    local settings = vehicle:getCourseGeneratorSettings()
    local tx, tz = self.cpJobParameters.fieldPosition:getPosition()
    local ok, course
    if self.foundVines then
        local vineSettings = vehicle:getCpVineSettings()
        local vertices, width, startingPoint, rowAngleDeg = g_vineScanner:getCourseGeneratorVertices(
                vineSettings.vineCenterOffset:getValue(),
                tx, tz
        )
        ok, course = CourseGeneratorInterface.generateVineCourse(vertices,
                startingPoint,
                width,
                AIUtil.getTurningRadius(vehicle),
                rowAngleDeg,
                vineSettings.vineRowsToSkip:getValue(),
                vineSettings.vineMultiTools:getValue()
        )
    else

        ok, course = CourseGeneratorInterface.generate(fieldPolygon,
                { x = tx, z = tz },
                settings.isClockwise:getValue(),
                settings.workWidth:getValue(),
                AIUtil.getTurningRadius(vehicle),
                settings.numberOfHeadlands:getValue(),
                settings.startOnHeadland:getValue(),
                settings.headlandCornerType:getValue(),
                settings.headlandOverlapPercent:getValue(),
                settings.centerMode:getValue(),
                settings.rowDirection:getValue(),
                settings.manualRowAngleDeg:getValue(),
                settings.rowsToSkip:getValue(),
                false,
                settings.rowsPerLand:getValue(),
                settings.islandBypassMode:getValue(),
                settings.fieldMargin:getValue(),
                settings.multiTools:getValue(),
                self:isPipeOnLeftSide(vehicle)
        )
    end
    if not ok then
        g_gui:showInfoDialog({
            dialogType = DialogElement.TYPE_ERROR,
            text = g_i18n:getText('CP_error_could_not_generate_course')
        })
        return false
    end

    vehicle:setFieldWorkCourse(course)
end

function CpAIJobFieldWork:isPipeOnLeftSide(vehicle)
    local pipeObject = AIUtil.getImplementOrVehicleWithSpecialization(vehicle, Pipe)
    if pipeObject and SpecializationUtil.hasSpecialization(Combine, pipeObject.specializations) then
        --- The controller measures the pipe attributes on creation.
        local controller = PipeController(vehicle, pipeObject)
        local isPipeOnLeftSide = controller:isPipeOnTheLeftSide()
        controller:delete()
        return isPipeOnLeftSide
    else
        return true
    end
end

function CpAIJobFieldWork:getIsAvailableForVehicle(vehicle)
    return vehicle.getCanStartCpFieldWork and vehicle:getCanStartCpFieldWork()
end

function CpAIJobFieldWork:resetStartPositionAngle(vehicle)
    CpAIJobFieldWork:superClass().resetStartPositionAngle(self, vehicle)
    local x, _, z = getWorldTranslation(vehicle.rootNode)
    self.cpJobParameters.fieldPosition:setPosition(x, z)
end

--- Ugly hack to fix a mp problem from giants, where the helper is not always reset correctly on the client side.
function CpAIJobFieldWork:stop(aiMessage)
    CpAIJobFieldWork:superClass().stop(self, aiMessage)

    local vehicle = self.vehicleParameter:getVehicle()
    if vehicle and vehicle.spec_aiFieldWorker.isActive then
        vehicle.spec_aiFieldWorker.isActive = false
    end
end

function CpAIJobFieldWork:hasFoundVines()
    return self.foundVines
end

function CpAIJobFieldWork:setStartPosition(startPosition)
    if self.fieldWorkTask then
        self.fieldWorkTask:setStartPosition(startPosition)
    end
end

--- Gets the additional task description shown.
function CpAIJobFieldWork:getDescription()
	local desc = CpAIJob:superClass().getDescription(self)
	local currentTask = self:getTaskByIndex(self.currentTaskIndex)
    if currentTask == self.driveToTask then
		desc = desc .. " - " .. g_i18n:getText("ai_taskDescriptionDriveToField")
	elseif currentTask == self.fieldWorkTask then
		desc = desc .. " - " .. g_i18n:getText("ai_taskDescriptionFieldWork")
	elseif currentTask == self.attachHeaderTask then
		desc = desc .. " - " .. g_i18n:getText("CP_ai_taskDescriptionAttachHeader")
	end
	return desc
end
