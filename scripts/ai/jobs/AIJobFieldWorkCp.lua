--- AI job derived of AIJobFieldWork.
---@class AIJobFieldWorkCp : AIJobFieldWork
AIJobFieldWorkCp = {}
local AIJobFieldWorkCp_mt = Class(AIJobFieldWorkCp, AIJobFieldWork)

---Localization text symbols.
AIJobFieldWorkCp.translations = {
    JobName = "CP_job_fieldWork",
    GenerateButton = "FIELDWORK_BUTTON"
}

function AIJobFieldWorkCp.new(isServer, customMt)
	local self = AIJobFieldWork.new(isServer, customMt or AIJobFieldWorkCp_mt)
	
	self.fieldWorkTask = AITaskFieldWorkCp.new(isServer, self)
	-- Switches the AITaskFieldWork with AITaskFieldWorkCp.
	-- TODO: Consider deriving AIJobFieldWorkCp of AIJob and implement our own logic instead.
	local ix
	for i,task in pairs(self.tasks) do 
		if self.tasks[i]:isa(AITaskFieldWork) then 
			ix = i
			break
		end
	end
	self.fieldWorkTask.taskIndex = ix
	self.tasks[ix] = self.fieldWorkTask
	
	self.lastPositionX, self.lastPositionZ = math.huge, math.huge
	self.hasValidPosition = false

	--- Small translation fix, needs to be removed once giants fixes it.
	local ai = 	g_currentMission.aiJobTypeManager
	ai:getJobTypeByIndex(ai:getJobTypeIndexByName("FIELDWORK_CP")).title = g_i18n:getText(AIJobFieldWorkCp.translations.JobName)

	self.cpJobParameters = CpJobParameters(self)

	CpSettingsUtil.generateAiJobGuiElementsFromSettingsTable(self.cpJobParameters.settingsBySubTitle,self,self.cpJobParameters)
	return self
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
	local fieldNum = CpFieldUtil.getFieldIdAtWorldPosition(tx, tz)
	CpUtil.info('Scanning field %d on %s', fieldNum, g_currentMission.missionInfo.mapTitle)
	self.fieldPolygon = g_fieldScanner:findContour(tx, tz)
	if not self.fieldPolygon then
		self.hasValidPosition = false
		return false, g_i18n:getText("CP_error_not_on_field")
	end
	local vehicle = self.vehicleParameter:getVehicle()
	if vehicle then 
		if not vehicle:getCanStartCpBaleFinder(self.cpJobParameters) then 
			if not vehicle:hasCpCourse() then 
				return false, g_i18n:getText("CP_error_no_course")
			end
		end
	end
	self.cpJobParameters:validateSettings()
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

function AIJobFieldWorkCp:getCanStartJob()
	local vehicle = self.vehicleParameter:getVehicle()
	return vehicle and (vehicle:hasCpCourse() or
			self.cpJobParameters.startAt:getValue() == CpJobParameters.START_FINDING_BALES)
end

--- Button callback to generate a field work course.
function AIJobFieldWorkCp:onClickGenerateFieldWorkCourse()
	local vehicle = self.vehicleParameter:getVehicle()
	local settings = vehicle:getCourseGeneratorSettings()
	local status, ok, course = CourseGeneratorInterface.generate(self.fieldPolygon,
			{x = self.lastPositionX, z = self.lastPositionZ},
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
			settings.rowsPerLand:getValue(),
			settings.islandBypassMode:getValue(),
			settings.fieldMargin:getValue(),
			settings.multiTools:getValue()
	)
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

function AIJobFieldWorkCp:getPricePerMs()
	local modifier = g_Courseplay.globalSettings:getSettings().wageModifier:getValue()/100
	return AIJobFieldWorkCp:superClass().getPricePerMs(self) * modifier
end

--- Automatically repairs the vehicle, depending on the auto repair setting.
--- Currently repairs all AI drivers.
function AIJobFieldWorkCp:onUpdateTickWearable(...)
	if self:getIsAIActive() and self:getUsageCausesDamage() then 
		if self.rootVehicle and self.rootVehicle.getIsCpActive and self.rootVehicle:getIsCpActive() then 
			local dx =  g_Courseplay.globalSettings:getSettings().autoRepair:getValue()
			local repairStatus = (1 - self:getDamageAmount())*100
			if repairStatus < dx then 
				self:repairVehicle()
			end		
		end
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

function AIJobFieldWorkCp:getIsAvailableForVehicle(vehicle)
	return vehicle.getCanStartCpFieldWork and vehicle:getCanStartCpFieldWork()
end

function AIJobFieldWorkCp:resetStartPositionAngle(vehicle)
	local x, _, z = getWorldTranslation(vehicle.rootNode) 
	local dirX, _, dirZ = localDirectionToWorld(vehicle.rootNode, 0, 0, 1)

	self.positionAngleParameter:setPosition(x, z)
	local angle = MathUtil.getYRotationFromDirection(dirX, dirZ)
	self.positionAngleParameter:setAngle(angle)
end
function AIJobFieldWorkCp:getVehicle()
	return self.vehicleParameter:getVehicle() or self.vehicle
end

function AIJobFieldWorkCp:setVehicle(v)
	self.vehicle = v
end