--- AI job derived of AIJobFieldWork.
---@class AIJobFieldWorkCp : AIJobFieldWork
AIJobFieldWorkCp = {}
local AIJobFieldWorkCp_mt = Class(AIJobFieldWorkCp, AIJobFieldWork)

---Localization text symbols.
AIJobFieldWorkCp.translations = {
    JobName = "FIELDWORK_CP",
    GenerateButton = "FIELDWORK_BUTTON"
}

function AIJobFieldWorkCp.new(isServer, customMt)
	local self = AIJobFieldWork.new(isServer, customMt or AIJobFieldWorkCp_mt)
	self.lastPositionX, self.lastPositionZ = math.huge, math.huge
	self.hasValidPosition = false

	--- Small translation fix, needs to be removed once giants fixes it.
	local ai = 	g_currentMission.aiJobTypeManager
	ai:getJobTypeByIndex(ai:getJobTypeIndexByName("FIELDWORK_CP")).title = g_i18n:getText(AIJobFieldWorkCp.translations.JobName)

	self.cpJobParameters = CpJobParameters()

	CpSettingsUtil.generateAiJobGuiElementsFromSettingsTable(self.cpJobParameters.settingsBySubTitle,self,self.cpJobParameters)
	return self
end

function AIJobFieldWorkCp:applyCurrentState(vehicle, mission, farmId, isDirectStart)
	AIJobFieldWorkCp:superClass().applyCurrentState(self, vehicle, mission, farmId, isDirectStart)
	-- for now, always take the auto work width
	CpUtil.debugVehicle(CpDebug.DBG_HUD, vehicle, 'Setting work width parameter for course generation to %.1f', WorkWidthUtil.getAutomaticWorkWidth(vehicle))
	vehicle:getCourseGeneratorSettings().workWidth:setFloatValue(WorkWidthUtil.getAutomaticWorkWidth(vehicle))
end

--- Called when parameters change, scan field
function AIJobFieldWorkCp:validate(farmId)
	local isValid, errorMessage = AIJobFieldWork:superClass().validate(self, farmId)
	if not isValid then
		return isValid, errorMessage
	end


--	DebugUtil.printTableRecursively(self.cpJobParameters)

	-- everything else is valid, now find the field
	local tx, tz = self.positionAngleParameter:getPosition()
	if tx == self.lastPositionX and tz == self.lastPositionZ then
		CpUtil.debugFormat(CpDebug.DBG_HUD, 'Position did not change, do not generate course again')
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

	local vehicle = self.vehicleParameter:getVehicle()

	if vehicle and not vehicle:hasCpCourse() then
		return false, 'Generate a course before starting the job!'
	end
	return true, ''
end

function AIJobFieldWorkCp:getCpJobParameters()
	return self.cpJobParameters
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
	local vehicle = self.vehicleParameter:getVehicle()
	local settings = vehicle:getCourseGeneratorSettings()
	local status, ok, course = CourseGeneratorInterface.generate(self.fieldPolygon,
			{x = self.lastPositionX, z = self.lastPositionZ},
			0,
			settings.workWidth:getValue(),
			AIUtil.getTurningRadius(vehicle),
			settings.numberOfHeadlands:getValue(),
			settings.startOnHeadland:getValue(),
			settings.headlandCornerType:getValue(),
			settings.centerMode:getValue(),
			settings.rowDirection:getValue()
	)
	if not ok then
		return false, 'could not generate course'
	end

	vehicle:setFieldWorkCourse(course)
end

function AIJobFieldWorkCp:getPricePerMs()
	local modifier = g_Courseplay.globalSettings:getSettings().wageModifier:getValue()/100
	return AIJobFieldWorkCp:superClass().getPricePerMs(self) * modifier
end

--- Automatically repairs the vehicle, depending on the auto repair setting.
--- Currently repairs all AI drivers.
function AIJobFieldWorkCp:onUpdateTickWearable(...)
	if self:getIsAIActive() and self:getUsageCausesDamage() then 
	--	if self.rootVehicle then-- and self.rootVehicle.getJob and self.rootVehicle:getJob():isa(AIJobFieldWorkCp) then 
			local dx =  g_Courseplay.globalSettings:getSettings().autoRepair:getValue()
			local repairStatus = (1 - self:getDamageAmount())*100
			if repairStatus < dx then 
				self:repairVehicle()
			end		
	--	end
	end
end
Wearable.onUpdateTick = Utils.appendedFunction(Wearable.onUpdateTick, AIJobFieldWorkCp.onUpdateTickWearable)

--- for reload, messing with the internals of the job type manager so it uses the reloaded job
if g_currentMission then
	local myJobTypeIndex = g_currentMission.aiJobTypeManager:getJobTypeIndexByName('FIELDWORK_CP')
	if myJobTypeIndex then
		local myJobType = g_currentMission.aiJobTypeManager:getJobTypeByIndex(myJobTypeIndex)
		myJobType.classObject = AIJobFieldWorkCp
	end
end

AIJobTypeManager.loadMapData = Utils.appendedFunction(AIJobTypeManager.loadMapData,AIJobFieldWorkCp.registerJob)
