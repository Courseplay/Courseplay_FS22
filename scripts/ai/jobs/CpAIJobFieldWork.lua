--- AI job derived of CpAIJob.
---@class CpAIJobFieldWork : CpAIJob
CpAIJobFieldWork = {
	name = "FIELDWORK_CP",
	translations = {
		jobName = "CP_job_fieldWork",
		GenerateButton = "FIELDWORK_BUTTON"
	}
}
local AIJobFieldWorkCp_mt = Class(CpAIJobFieldWork, CpAIJob)

function CpAIJobFieldWork.new(isServer, customMt)
	local self = CpAIJob.new(isServer, customMt or AIJobFieldWorkCp_mt)
		
	self.lastPositionX, self.lastPositionZ = math.huge, math.huge
	self.hasValidPosition = false
	self.foundVines = nil
	self.selectedFieldPlot = FieldPlot(g_currentMission.inGameMenu.ingameMap)
	self.selectedFieldPlot:setVisible(false)
	return self
end

function CpAIJobFieldWork:setupTasks(isServer)
	-- this will add a standard driveTo task to drive to the target position selected by the user
	CpAIJobFieldWork:superClass().setupTasks(self, isServer)
	-- then we add our own driveTo task to drive from the target position to the waypoint where the
	-- fieldwork starts (first waypoint or the one we worked on last)
	self.driveToFieldWorkStartTask = CpAITaskDriveTo.new(isServer, self)
	self:addTask(self.driveToFieldWorkStartTask)
	self.fieldWorkTask = CpAITaskFieldWork.new(isServer, self)
	self:addTask(self.fieldWorkTask)
end

function CpAIJobFieldWork:setupJobParameters()
	CpAIJobFieldWork:superClass().setupJobParameters(self)

	-- Adds field position parameter
	self.fieldPositionParameter = AIParameterPosition.new()
	self.fieldPositionParameter.setValue = function (self, x, z)
		self:setPosition(x, z)		
	end
	self.fieldPositionParameter.isCpFieldPositionTarget = true

	self:addNamedParameter("fieldPosition", self.fieldPositionParameter )
	local positionGroup = AIParameterGroup.new(g_i18n:getText("CP_jobParameters_fieldPosition_title"))
	positionGroup:addParameter(self.fieldPositionParameter )
	table.insert(self.groupedParameters, positionGroup)

	self:setupCpJobParameters(nil)
end

function CpAIJobFieldWork:applyCurrentState(vehicle, mission, farmId, isDirectStart)
	CpAIJobFieldWork:superClass().applyCurrentState(self, vehicle, mission, farmId, isDirectStart)
	
	local x, z = nil

	if vehicle.getLastJob ~= nil then
		local lastJob = vehicle:getLastJob()

		if not isDirectStart and lastJob ~= nil and lastJob.cpJobParameters then
			x, z = lastJob.fieldPositionParameter:getPosition()
		end
	end

	if x == nil or z == nil then
		x, _, z = getWorldTranslation(vehicle.rootNode)
	end

	self.fieldPositionParameter:setPosition(x, z)
end

--- Checks the field position setting.
function CpAIJobFieldWork:validateFieldSetup(isValid, errorMessage)
	
	if not isValid then 
		return isValid, errorMessage
	end

	local vehicle = self.vehicleParameter:getVehicle()

	-- everything else is valid, now find the field
	local tx, tz = self.fieldPositionParameter:getPosition()
	self.hasValidPosition = false
	self.foundVines = nil
	local isCustomField
	self.fieldPolygon, isCustomField = CpFieldUtil.getFieldPolygonAtWorldPosition(tx, tz)

	if self.fieldPolygon then
		self.hasValidPosition = true
		self.foundVines = g_vineScanner:findVineNodesInField(self.fieldPolygon, tx, tz, self.customField~=nil)
		if self.foundVines then 
			self.fieldPolygon = g_vineScanner:getCourseGeneratorVertices(0, tx, tz)
		end
		
		self.selectedFieldPlot:setWaypoints(self.fieldPolygon)
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
	self.fieldWorkTask:setVehicle(vehicle)
end

--- Called when parameters change, scan field
function CpAIJobFieldWork:validate(farmId)
	local isValid, errorMessage = CpAIJobFieldWork:superClass().validate(self, farmId)
	if not isValid then
		return isValid, errorMessage
	end
	self.cpJobParameters:validateSettings()
	local vehicle = self.vehicleParameter:getVehicle()

	--- Only check the valid field position in the in game menu.
	if not self.isDirectStart then
		isValid, errorMessage = self:validateFieldSetup(isValid, errorMessage)
		if not isValid then
			return isValid, errorMessage
		end
	end

	if not vehicle:hasCpCourse() then 
		return false, g_i18n:getText("CP_error_no_course")
	end
	return true, ''
end

function CpAIJobFieldWork:drawSelectedField(map)
	if self.selectedFieldPlot then
		self.selectedFieldPlot:draw(map)
	end
end

function CpAIJobFieldWork:getFieldPositionTarget()
	return self.fieldPositionParameter:getPosition()
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
	return self:getCanGenerateFieldWorkCourse()
end

function CpAIJobFieldWork:getCanStartJob()
	local vehicle = self:getVehicle()
	return vehicle and vehicle:hasCpCourse()
end

--- Button callback to generate a field work course.
function CpAIJobFieldWork:onClickGenerateFieldWorkCourse()
	local vehicle = self.vehicleParameter:getVehicle()
	local settings = vehicle:getCourseGeneratorSettings()
	local tx, tz = self.fieldPositionParameter:getPosition()
	local status, ok, course
	if self.foundVines then 
		local vineSettings = vehicle:getCpVineSettings()
		local vertices, width, startingPoint, rowAngleDeg = g_vineScanner:getCourseGeneratorVertices(
			vineSettings.vineCenterOffset:getValue(),
			tx, tz
		)
		status, ok, course = CourseGeneratorInterface.generateVineCourse(vertices,
			startingPoint,
			width,
			AIUtil.getTurningRadius(vehicle),
			rowAngleDeg,
			vineSettings.vineRowsToSkip:getValue(),
			vineSettings.vineMultiTools:getValue()
		)
	else 

		status, ok, course = CourseGeneratorInterface.generate(self.fieldPolygon,
			{x = tx, z = tz},
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
	CpUtil.debugFormat(CpDebug.DBG_COURSES, 'Course generator returned status %s, ok %s, course %s', status, ok, course)
	if not status then
		g_gui:showInfoDialog({
			dialogType = DialogElement.TYPE_ERROR,
			text = g_i18n:getText('CP_error_could_not_generate_course')
		})
		return false
	end

	vehicle:setFieldWorkCourse(course)
end

function CpAIJobFieldWork:isPipeOnLeftSide(vehicle)
	if AIUtil.getImplementOrVehicleWithSpecialization(vehicle, Combine) then
		local pipeAttributes = {}
		local combine = ImplementUtil.findCombineObject(vehicle)
		ImplementUtil.setPipeAttributes(pipeAttributes, vehicle, combine)
		return pipeAttributes.pipeOnLeftSide
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
	self.fieldPositionParameter:setPosition(x, z)
end

--- Ugly hack to fix a mp problem from giants, where the helper is not always reset correctly on the client side.
function CpAIJobFieldWork:stop(aiMessage)	
	CpAIJobFieldWork:superClass().stop(self, aiMessage)

	local vehicle = self.vehicleParameter:getVehicle()
	if vehicle and vehicle.spec_aiFieldWorker.isActive then 
		vehicle.spec_aiFieldWorker.isActive = false
	end
end

function CpAIJobFieldWork:getCourseGeneratorSettings()
	local vehicle = self:getVehicle()
	if self.foundVines then 
		return vehicle, vehicle:getCpVineSettingsTable(), CpCourseGeneratorSettings.getVineSettingSetup(vehicle)
	end
	return vehicle, vehicle:getCourseGeneratorSettingsTable(), CpCourseGeneratorSettings.getSettingSetup(vehicle)
end

function CpAIJobFieldWork:setStartPosition(startPosition)
	if self.fieldWorkTask then
		self.fieldWorkTask:setStartPosition(startPosition)
	end
end