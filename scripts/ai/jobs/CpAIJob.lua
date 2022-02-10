--- Basic cp job.
--- Every cp job should be derived from this job.
---@class CpAIJob : AIJob
CpAIJob = {
	name = "",
	translations = {
		jobName = ""
	}
}
local AIJobCp_mt = Class(CpAIJob, AIJob)

function CpAIJob.new(isServer, customMt)
	local self = AIJob.new(isServer, customMt or AIJobCp_mt)
	
	self.isDirectStart = false
	self:setupTasks(isServer)
	
	--- Small translation fix, needs to be removed once giants fixes it.
	local ai = g_currentMission.aiJobTypeManager
	ai:getJobTypeByIndex(ai:getJobTypeIndexByName(self.name)).title = g_i18n:getText(self.translations.jobName)

	self:setupJobParameters()

	return self
end

--- Setup all tasks.
function CpAIJob:setupTasks(isServer)
	self.driveToTask = AITaskDriveTo.new(isServer, self)
	self:addTask(self.driveToTask)
end

--- Setup all job parameters.
--- For now every job has these parameters in common.
function CpAIJob:setupJobParameters()
	self.vehicleParameter = AIParameterVehicle.new()
	self.positionAngleParameter = AIParameterPositionAngle.new(math.rad(0))

	self:addNamedParameter("vehicle", self.vehicleParameter)
	self:addNamedParameter("positionAngle", self.positionAngleParameter)

	local vehicleGroup = AIParameterGroup.new(g_i18n:getText("ai_parameterGroupTitleVehicle"))

	vehicleGroup:addParameter(self.vehicleParameter)

	local positionGroup = AIParameterGroup.new(g_i18n:getText("ai_parameterGroupTitlePosition"))

	positionGroup:addParameter(self.positionAngleParameter)
	table.insert(self.groupedParameters, vehicleGroup)
	table.insert(self.groupedParameters, positionGroup)
end

--- Optional to create custom cp job parameters.
function CpAIJob:setupCpJobParameters(configFile)
	self.cpJobParameters = CpJobParameters(self, configFile)
	CpSettingsUtil.generateAiJobGuiElementsFromSettingsTable(self.cpJobParameters.settingsBySubTitle,self,self.cpJobParameters)
	self.cpJobParameters:validateSettings()

end

--- Gets the first task to start with.
function CpAIJob:getStartTaskIndex()
	if self.isDirectStart then
		return 2
	end
	return self:isTargetReached() and 2 or 1 
end

--- Should the giants path finder job be skipped?
function CpAIJob:isTargetReached()
	local vehicle = self.vehicleParameter:getVehicle()
	local x, _, z = getWorldTranslation(vehicle.rootNode)
	local tx, tz = self.positionAngleParameter:getPosition()
	local targetReached = MathUtil.vector2Length(x - tx, z - tz) < 3

	return targetReached
end

function CpAIJob:start(farmId)
	CpAIJob:superClass().start(self, farmId)

	if self.isServer then
		local vehicle = self.vehicleParameter:getVehicle()

		vehicle:createAgent(self.helperIndex)
		vehicle:aiJobStarted(self, self.helperIndex, farmId)
	end
end

function CpAIJob:stop(aiMessage)
	if self.isServer then
		local vehicle = self.vehicleParameter:getVehicle()

		vehicle:deleteAgent()
		vehicle:aiJobFinished()
	end
	
	CpAIJob:superClass().stop(self, aiMessage)
end

--- Updates the parameter values.
function CpAIJob:applyCurrentState(vehicle, mission, farmId, isDirectStart)
	CpAIJob:superClass().applyCurrentState(self, vehicle, mission, farmId, isDirectStart)
	self.vehicleParameter:setVehicle(vehicle)

	local x, z, angle, _ = nil

	if vehicle.getLastJob ~= nil then
		local lastJob = vehicle:getLastJob()

		if not isDirectStart and lastJob ~= nil and lastJob:isa(CpAIJob) then
			x, z = lastJob.positionAngleParameter:getPosition()
			angle = lastJob.positionAngleParameter:getAngle()
		end
	end

	local snappingAngle = vehicle:getDirectionSnapAngle()
	local terrainAngle = math.pi / math.max(g_currentMission.fieldGroundSystem:getGroundAngleMaxValue() + 1, 4)
	snappingAngle = math.max(snappingAngle, terrainAngle)

	self.positionAngleParameter:setSnappingAngle(snappingAngle)

	if x == nil or z == nil then
		x, _, z = getWorldTranslation(vehicle.rootNode)
	end

	if angle == nil then
		local dirX, _, dirZ = localDirectionToWorld(vehicle.rootNode, 0, 0, 1)
		angle = MathUtil.getYRotationFromDirection(dirX, dirZ)
	end

	self.positionAngleParameter:setPosition(x, z)
	self.positionAngleParameter:setAngle(angle)
end

--- Can the vehicle be used for this job?
function CpAIJob:getIsAvailableForVehicle(vehicle)
	return true
end

--- Target for the giants drive task.
function CpAIJob:getTarget()
	local angle = 0

	if self.driveToTask.dirX ~= nil then
		angle = MathUtil.getYRotationFromDirection(self.driveToTask.dirX, self.driveToTask.dirZ)
	end

	return self.driveToTask.x, self.driveToTask.z, angle
end

function CpAIJob:getTitle()
	local vehicle = self.vehicleParameter:getVehicle()

	if vehicle ~= nil then
		return vehicle:getName()
	end

	return ""
end

--- Applies the parameter values to the tasks.
function CpAIJob:setValues()
	self:resetTasks()

	local vehicle = self.vehicleParameter:getVehicle()

	self.driveToTask:setVehicle(vehicle)

	local angle = self.positionAngleParameter:getAngle()
	local x, z = self.positionAngleParameter:getPosition()
	local dirX, dirZ = MathUtil.getDirectionFromYRotation(angle)

	self.driveToTask:setTargetDirection(dirX, dirZ)
	self.driveToTask:setTargetPosition(x, z)
end

--- Is the job valid?
function CpAIJob:validate(farmId)
	self:setParamterValid(true)

	local isValid, errorMessage = self.vehicleParameter:validate()

	if not isValid then
		self.vehicleParameter:setIsValid(false)
	end

	return isValid, errorMessage
end

function CpAIJob:getDescription()
	local desc = CpAIJob:superClass().getDescription(self)
	local nextTask = self:getTaskByIndex(self.currentTaskIndex)

	if nextTask == self.driveToTask then
		desc = desc .. " - " .. g_i18n:getText("ai_taskDescriptionDriveToField")
	elseif nextTask == self.fieldWorkTask then
		desc = desc .. " - " .. g_i18n:getText("ai_taskDescriptionFieldWork")
	end

	return desc
end

function CpAIJob:getIsStartable(connection)
	if g_currentMission.aiSystem:getAILimitedReached() then
		return false, AIJobFieldWork.START_ERROR_LIMIT_REACHED
	end

	local vehicle = self.vehicleParameter:getVehicle()

	if vehicle == nil then
		return false, AIJobFieldWork.START_ERROR_VEHICLE_DELETED
	end

	if not g_currentMission:getHasPlayerPermission("hireAssistant", connection, vehicle:getOwnerFarmId()) then
		return false, AIJobFieldWork.START_ERROR_NO_PERMISSION
	end

	if vehicle:getIsInUse(connection) then
		return false, AIJobFieldWork.START_ERROR_VEHICLE_IN_USE
	end

	return true, AIJob.START_SUCCESS
end

function CpAIJob.getIsStartErrorText(state)
	if state == AIJobFieldWork.START_ERROR_LIMIT_REACHED then
		return g_i18n:getText("ai_startStateLimitReached")
	elseif state == AIJobFieldWork.START_ERROR_VEHICLE_DELETED then
		return g_i18n:getText("ai_startStateVehicleDeleted")
	elseif state == AIJobFieldWork.START_ERROR_NO_PERMISSION then
		return g_i18n:getText("ai_startStateNoPermission")
	elseif state == AIJobFieldWork.START_ERROR_VEHICLE_IN_USE then
		return g_i18n:getText("ai_startStateVehicleInUse")
	end

	return g_i18n:getText("ai_startStateSuccess")
end


function CpAIJob:writeStream(streamId, connection)
	CpAIJob:superClass().writeStream(self, streamId, connection)
	if self.cpJobParameters then
		self.cpJobParameters:writeStream(streamId, connection)
	end
end

function CpAIJob:readStream(streamId, connection)
	CpAIJob:superClass().readStream(self, streamId, connection)
	if self.cpJobParameters then
		self.cpJobParameters:readStream(streamId, connection)
	end
end

function CpAIJob:getCpJobParameters()
	return self.cpJobParameters
end

--- Can the job be started?
function CpAIJob:getCanStartJob()
	return true
end

--- Applies the global wage modifier. 
function CpAIJob:getPricePerMs()
	local modifier = g_Courseplay.globalSettings:getSettings().wageModifier:getValue()/100
	return CpAIJob:superClass().getPricePerMs(self) * modifier
end

--- Resets the position parameters, if the menu was opened by the hud.
function CpAIJob:resetStartPositionAngle(vehicle)
	local x, _, z = getWorldTranslation(vehicle.rootNode) 
	local dirX, _, dirZ = localDirectionToWorld(vehicle.rootNode, 0, 0, 1)

	self.positionAngleParameter:setPosition(x, z)
	local angle = MathUtil.getYRotationFromDirection(dirX, dirZ)
	self.positionAngleParameter:setAngle(angle)
end

function CpAIJob:getVehicle()
	return self.vehicleParameter:getVehicle() or self.vehicle
end

--- Makes sure that the keybinding/hud job has the vehicle.
function CpAIJob:setVehicle(v)
	self.vehicle = v
end

--- Automatically repairs the vehicle, depending on the auto repair setting.
function CpAIJob.onUpdateTickWearable(object, ...)
	if object:getIsAIActive() and object:getUsageCausesDamage() then 
		if object.rootVehicle and object.rootVehicle.getIsCpActive and object.rootVehicle:getIsCpActive() then 
			local dx =  g_Courseplay.globalSettings:getSettings().autoRepair:getValue()
			local repairStatus = (1 - object:getDamageAmount())*100
			if repairStatus < dx then 
				object:repairVehicle()
			end		
		end
	end
end
Wearable.onUpdateTick = Utils.appendedFunction(Wearable.onUpdateTick, CpAIJob.onUpdateTickWearable)


--- Ugly hack to fix a mp problem from giants, where the job class can not be found.
function CpAIJob.getJobTypeIndex(aiJobTypeManager, superFunc, job)
	local ret = superFunc(aiJobTypeManager, job)
	if ret == nil then 
		if job.name then 
			return aiJobTypeManager.nameToIndex[job.name]
		end
	end
	return ret
end
AIJobTypeManager.getJobTypeIndex = Utils.overwrittenFunction(AIJobTypeManager.getJobTypeIndex ,CpAIJob.getJobTypeIndex)

--- Registers additional jobs.
function CpAIJob.registerJob(AIJobTypeManager)
	AIJobTypeManager:registerJobType(CpAIJobFieldWork.name, CpAIJobFieldWork.translations.jobName, CpAIJobFieldWork)
	AIJobTypeManager:registerJobType(CpAIJobBaleFinder.name, CpAIJobBaleFinder.translations.jobName, CpAIJobBaleFinder)
end


--- for reload, messing with the internals of the job type manager so it uses the reloaded job
if g_currentMission then
	local myJobTypeIndex = g_currentMission.aiJobTypeManager:getJobTypeIndexByName(AIJob.name)
	if myJobTypeIndex then
		local myJobType = g_currentMission.aiJobTypeManager:getJobTypeByIndex(myJobTypeIndex)
		myJobType.classObject = AIJob
	end
	local myJobTypeIndex = g_currentMission.aiJobTypeManager:getJobTypeIndexByName(CpAIJobFieldWork.name)
	if myJobTypeIndex then
		local myJobType = g_currentMission.aiJobTypeManager:getJobTypeByIndex(myJobTypeIndex)
		myJobType.classObject = CpAIJobFieldWork
	end
	local myJobTypeIndex = g_currentMission.aiJobTypeManager:getJobTypeIndexByName(CpAIJobBaleFinder.name)
	if myJobTypeIndex then
		local myJobType = g_currentMission.aiJobTypeManager:getJobTypeByIndex(myJobTypeIndex)
		myJobType.classObject = CpAIJobBaleFinder
	end
end

AIJobTypeManager.loadMapData = Utils.appendedFunction(AIJobTypeManager.loadMapData,CpAIJob.registerJob)

