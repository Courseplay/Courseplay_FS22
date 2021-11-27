--- Example AI job derived of AIJobFieldWork.
---@class AIJobFieldWorkCp : AIJobFieldWork
AIJobFieldWorkCp = {}
local AIJobFieldWorkCp_mt = Class(AIJobFieldWorkCp, AIJobFieldWork)

function AIJobFieldWorkCp.new(isServer, customMt)
	local self = AIJobFieldWork.new(isServer, customMt or AIJobFieldWorkCp_mt)
	--- Creates a custom parameter.
	self.workWidthParameter = AIParameterWorkWidth.new()
	--- Creates a name link to get this parameter later with: "self:getNamedParameter("workWidth")"
	self:addNamedParameter("workWidth", self.workWidthParameter)
	--- Creates an Gui element in the helper menu.
	local workWidthGroup = AIParameterGroup.new(g_i18n:getText("work width"))
	workWidthGroup:addParameter(self.workWidthParameter)
	--- Adds this gui element to the gui table.
	table.insert(self.groupedParameters, workWidthGroup)
	CoursePlot.getInstance():setVisible(false)
	self.lastPositionX = 0
	self.lastPositionZ = 0
	return self
end

--- Called when parameters change, for now, scan field and generate a default course
function AIJobFieldWorkCp:validate()
	local isValid, errorMessage = AIJobFieldWork:superClass().validate(self)
	if not isValid then
		return isValid, errorMessage
	end

	-- everything else is valid, now find the field and generate a course
	local tx, tz = self.positionAngleParameter:getPosition()
	if tx == self.lastPositionX and tz == self.lastPositionZ then
		CpUtil.debugFormat(1, 'Position did not change, do not generate course again')
		return isValid, errorMessage
	else
		self.lastPositionX, self.lastPositionZ = tx, tz
	end

	self.fieldPolygon = g_fieldScanner:findContour(tx, tz)
	if not self.fieldPolygon then
		return false, 'target not on field'
	end

	local status, ok
	status, ok, self.course = CourseGeneratorInterface.generate(self.fieldPolygon, {x = tx, z = tz}, 0, 6, 1, true)
	if not ok then
		return false, 'could not generate course'
	end
	-- we have course, show the course plot on the AI helper screen
	CoursePlot.getInstance():setWaypoints(self.course.waypoints)
	CoursePlot.getInstance():setVisible(true)
	-- save the course on the vehicle for the strategy to use later
	local vehicle = self.vehicleParameter:getVehicle()
	self.course:setVehicle(vehicle)
	vehicle:setFieldWorkCourse(self.course)
	return true, ''
end

--- Registers additional jobs.
function AIJobFieldWorkCp.registerJob(self)
	self:registerJobType("FIELDWORK_CP", "CP Fieldwork", AIJobFieldWorkCp)
end

--- for reload, messing with the internals of the job type manager so it uses the reloaded job
if g_currentMission then
	local myJobTypeIndex = g_currentMission.aiJobTypeManager:getJobTypeIndexByName('FIELDWORK_CP')
	if myJobTypeIndex then
		local myJobType = g_currentMission.aiJobTypeManager:getJobTypeByIndex(myJobTypeIndex)
		myJobType.classObject = AIJobFieldWorkCp
	end
end

AIJobTypeManager.loadMapData = Utils.appendedFunction(AIJobTypeManager.loadMapData,AIJobFieldWorkCp.registerJob)
