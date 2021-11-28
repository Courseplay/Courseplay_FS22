--- AI job derived of AIJobFieldWork.
---@class AIJobFieldWorkCp : AIJobFieldWork
AIJobFieldWorkCp = {}
local AIJobFieldWorkCp_mt = Class(AIJobFieldWorkCp, AIJobFieldWork)

---Localization text symbols.
AIJobFieldWorkCp.translations = {
    JobName = "$l10n_FIELDWORK_CP",
    GenerateButton = "FIELDWORK_BUTTON",
	workWidth = "workWidth",
	centerMode = "centerMode",
	headlandCornerType = "headlandCornerType",
	numberOfHeadlands = "numberOfHeadlands",
	rowDirection = "rowDirection",
	startOnHeadland = "startOnHeadland",

}

AIJobFieldWorkCp.AIParameters = {
	workWidth = AIParameterWorkWidth.new,
	centerMode = AIParameterCenterMode.new,
	headlandCornerType = AIParameterHeadlandCornerType.new,
	numberOfHeadlands = AIParameterNumberOfHeadlands.new,
	rowDirection = AIParameterRowDirection.new,
	startOnHeadland = AIParameterStartOnHeadland.new,
}

function AIJobFieldWorkCp.new(isServer, customMt)
	local self = AIJobFieldWork.new(isServer, customMt or AIJobFieldWorkCp_mt)
	AIJobFieldWorkCp.enrichAIParameters(self)
	CoursePlot.getInstance():setVisible(false)
	self.lastPositionX, self.lastPositionZ = math.huge, math.huge
	self.hasValidPosition = false
	return self
end

--- Creates the necessary AI parameters and binds them to the gui.
function AIJobFieldWorkCp.enrichAIParameters(self)
	for name,class in pairs(AIJobFieldWorkCp.AIParameters) do 
		local key = name.."Parameter"
		--- Creates the parameter
		self[key] = class()
		--- Creates a name link to get this parameter later with: "self:getNamedParameter("workWidth")"
		self:addNamedParameter(name, self[key])
		--- Creates an Gui title element in the helper menu.
		local group = AIParameterGroup.new(AIJobFieldWorkCp.translations[name])
		group:addParameter(self[key])
		--- Adds this gui element to the gui table.
		table.insert(self.groupedParameters, group)
	end
end

function AIJobFieldWorkCp:applyCurrentState(vehicle, mission, farmId, isDirectStart)
	AIJobFieldWorkCp:superClass().applyCurrentState(self, vehicle, mission, farmId, isDirectStart)
	self.workWidthParameter:set(WorkWidthUtil.getAutomaticWorkWidth(vehicle))
end

--- Called when parameters change, for now, scan field and generate a default course
function AIJobFieldWorkCp:validate(farmId)
	local isValid, errorMessage = AIJobFieldWork:superClass().validate(self, farmId)
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
		self.hasValidPosition = true
	end

	self.fieldPolygon = g_fieldScanner:findContour(tx, tz)
	if not self.fieldPolygon then
		self.hasValidPosition = false
		return false, 'target not on field'
	end

	if self.course == nil then
		return false, 'Generate a course before starting the job!'
	end
	return true, ''
end

--- Registers additional jobs.
function AIJobFieldWorkCp.registerJob(self)
	self:registerJobType("FIELDWORK_CP", AIJobFieldWorkCp.translations.JobName, AIJobFieldWorkCp)
end

--- Is course generation allowed ?
function AIJobFieldWorkCp:getCanGenerateFieldWorkCourse()
	return self.hasValidPosition
end

--- Button callback to generate a field work course.
function AIJobFieldWorkCp:onClickGenerateFieldWorkCourse()
	print("onClickGenerateFieldWorkCourse")

	local status, ok
	status, ok, self.course = CourseGeneratorInterface.generate(self.fieldPolygon,
			{x = self.lastPositionX, z = self.lastPositionZ},
			0,
			self.workWidthParameter:get(),
			self.numberOfHeadlandsParameter:getValue(),
			self.startOnHeadlandParameter:getValue(),
			self.headlandCornerTypeParameter:getValue(),
			self.centerModeParameter:getValue()
	)
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

--- Adds the course generate button.
function AIJobFieldWorkCp.loadFromXmlInGameMenu(self,xmlFile, key)
	self.buttonGenerateCourse = self.buttonGotoJob:clone(self.buttonGotoJob.parent)
	self.buttonGenerateCourse:setText(g_i18n:getText(AIJobFieldWorkCp.translations.GenerateButton))
	--self.buttonGenerateCourse:setText("generator")
	self.buttonGenerateCourse:setVisible(false)
	self.buttonGenerateCourse.onClickCallback = self.onClickGenerateFieldWorkCourse
	self.buttonGotoJob.parent:invalidateLayout()
end
InGameMenuAIFrame.onLoadMapFinished = Utils.appendedFunction(InGameMenuAIFrame.onLoadMapFinished,AIJobFieldWorkCp.loadFromXmlInGameMenu)


--- Updates generate button visibility.
function AIJobFieldWorkCp.updateContextInputBarVisibilityIngameMenu(self)
	local visible = self.currentJob and self.currentJob.getCanGenerateFieldWorkCourse and self.currentJob:getCanGenerateFieldWorkCourse()
	self.buttonGenerateCourse:setVisible(visible)
end

InGameMenuAIFrame.updateContextInputBarVisibility = Utils.appendedFunction(InGameMenuAIFrame.updateContextInputBarVisibility,AIJobFieldWorkCp.updateContextInputBarVisibilityIngameMenu)

--- Button Callback.
function InGameMenuAIFrame:onClickGenerateFieldWorkCourse()
	if self.currentJob and self.currentJob.getCanGenerateFieldWorkCourse and self.currentJob:getCanGenerateFieldWorkCourse() then 
		self.currentJob:onClickGenerateFieldWorkCourse()
	end
end