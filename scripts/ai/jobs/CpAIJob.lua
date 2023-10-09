--[[
This file is part of Courseplay (https://github.com/Courseplay/Courseplay_FS22)
Copyright (C) 2022 - 2023 Courseplay Dev Team

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

--- Basic cp job.
--- Every cp job should be derived from this job.
---@class CpAIJob : AIJob
---@field jobTypeIndex number
---@field addTask function
---@field getIsLooping function
---@field currentTaskIndex number
---@field tasks table
CpAIJob = {
	name = "",
	jobName = "",
	targetPositionParameterText = "ai_parameterGroupTitlePosition"
}
local AIJobCp_mt = Class(CpAIJob, AIJob)

function CpAIJob.new(isServer, customMt)
	local mt = customMt or AIJobCp_mt
	mt.__tostring = function(_self)
		CpUtil.info("Job: %s", g_currentMission.aiJobTypeManager:getJobTypeByIndex(_self.jobTypeIndex).name)
		return string.format("%d Job parameters", tostring(_self.cpJobParameters))
	end

	local self = AIJob.new(isServer, mt)
	self.isDirectStart = false
	
	--- Small translation fix, needs to be removed once giants fixes it.
	local ai = g_currentMission.aiJobTypeManager
	ai:getJobTypeByIndex(ai:getJobTypeIndexByName(self.name)).title = g_i18n:getText(self.jobName)

	self:setupJobParameters()

	self.debugChannel = CpDebug.DBG_FIELDWORK
	self:setupTasks(isServer)
	
	return self
end

--- Setup all tasks.
function CpAIJob:setupTasks(isServer)
	self.driveToTask = AITaskDriveTo.new(isServer, self)
	self:addTask(self.driveToTask)
end


---@param task CpAITask
function CpAIJob:removeTask(task)
	if task.taskIndex then
		table.remove(self.tasks, task.taskIndex)
		for i = #self.tasks, task.taskIndex, -1 do 
			self.tasks[i].taskIndex = self.tasks[i].taskIndex - 1
		end
	end
	task.taskIndex = nil
end

--- Setup all job parameters.
--- For now every job has these parameters in common.
function CpAIJob:setupJobParameters()
	self.vehicleParameter = AIParameterVehicle.new()
	self:addNamedParameter("vehicle", self.vehicleParameter)
	local vehicleGroup = AIParameterGroup.new(g_i18n:getText("ai_parameterGroupTitleVehicle"))
	vehicleGroup:addParameter(self.vehicleParameter)
	table.insert(self.groupedParameters, vehicleGroup)
end

--- Optional to create custom cp job parameters.
function CpAIJob:setupCpJobParameters(jobParameters)
	self.cpJobParameters = jobParameters
	CpSettingsUtil.generateAiJobGuiElementsFromSettingsTable(self.cpJobParameters.settingsBySubTitle,self,self.cpJobParameters)
	self.cpJobParameters:validateSettings()
end

--- Gets the first task to start with.
function CpAIJob:getStartTaskIndex()
	if self.currentTaskIndex ~= 0 or self.isDirectStart or self:isTargetReached() then
		-- skip Giants driveTo
		-- TODO: this isn't very nice as we rely here on the derived classes to add more tasks
		return 2
	end
	return 1
end

function CpAIJob:getNextTaskIndex()
	if self:getIsLooping() and self.currentTaskIndex >= #self.tasks then 
		--- Makes sure the giants task is skipped
		return self:getStartTaskIndex()
	end
	return AIJob.getNextTaskIndex(self)
end

--- Should the giants path finder job be skipped?
function CpAIJob:isTargetReached()
	if not self.cpJobParameters or not self.cpJobParameters.startPosition then 
		return true
	end
	local vehicle = self.vehicleParameter:getVehicle()
	local x, _, z = getWorldTranslation(vehicle.rootNode)
	local tx, tz = self.cpJobParameters.startPosition:getPosition()
	if tx == nil or tz == nil then 
		return true
	end
	local targetReached = MathUtil.vector2Length(x - tx, z - tz) < 3

	return targetReached
end

function CpAIJob:onPreStart()
	--- override
end

function CpAIJob:start(farmId)
	self:onPreStart()
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
	if not self.cpJobParameters or not self.cpJobParameters.startPosition then 
		return
	end

	local x, z, _ = self.cpJobParameters.startPosition:getPosition()
	local angle = self.cpJobParameters.startPosition:getAngle()

	local snappingAngle = vehicle:getDirectionSnapAngle()
	local terrainAngle = math.pi / math.max(g_currentMission.fieldGroundSystem:getGroundAngleMaxValue() + 1, 4)
	snappingAngle = math.max(snappingAngle, terrainAngle)

	self.cpJobParameters.startPosition:setSnappingAngle(snappingAngle)

	if x == nil or z == nil then
		x, _, z = getWorldTranslation(vehicle.rootNode)
	end

	if angle == nil then
		local dirX, _, dirZ = localDirectionToWorld(vehicle.rootNode, 0, 0, 1)
		angle = MathUtil.getYRotationFromDirection(dirX, dirZ)
	end
	
	self.cpJobParameters.startPosition:setPosition(x, z)
	self.cpJobParameters.startPosition:setAngle(angle)

end

--- Can the vehicle be used for this job?
function CpAIJob:getIsAvailableForVehicle(vehicle)
	return true
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

	local angle = self.cpJobParameters.startPosition:getAngle()
	local x, z = self.cpJobParameters.startPosition:getPosition()
	if angle ~= nil and x ~= nil then
		local dirX, dirZ = MathUtil.getDirectionFromYRotation(angle)
		self.driveToTask:setTargetDirection(dirX, dirZ)
		self.driveToTask:setTargetPosition(x, z)
	end
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
		self.cpJobParameters:validateSettings()
		self.cpJobParameters:readStream(streamId, connection)
		self:setValues()
	end
end

function CpAIJob:saveToXMLFile(xmlFile, key, usedModNames)
	CpAIJob:superClass().saveToXMLFile(self, xmlFile, key, usedModNames)
	if self.cpJobParameters then
		self.cpJobParameters:saveToXMLFile(xmlFile, key)
	end
	return true
end

function CpAIJob:loadFromXMLFile(xmlFile, key)
	CpAIJob:superClass().loadFromXMLFile(self, xmlFile, key)
	if self.cpJobParameters then
		self.cpJobParameters:validateSettings()
		self.cpJobParameters:loadFromXMLFile(xmlFile, key)
	end
end

function CpAIJob:getCpJobParameters()
	return self.cpJobParameters
end

--- Can the job be started?
function CpAIJob:getCanStartJob()
	return true
end

function CpAIJob:copyFrom(job)
	self.cpJobParameters:copyFrom(job.cpJobParameters)
end

--- Applies the global wage modifier. 
function CpAIJob:getPricePerMs()
	local modifier = g_Courseplay.globalSettings:getSettings().wageModifier:getValue()/100
	return CpAIJob:superClass().getPricePerMs(self) * modifier
end

--- Fix for precision farming ...
function CpAIJob.getPricePerMs_FixPrecisionFarming(vehicle, superFunc, ...)
	if vehicle then 
		return superFunc(vehicle, ...)
	end
	--- Only if the vehicle/self of AIJobFieldWork:getPricePerMs() us nil,
	--- then the call was from precision farming and needs to be fixed ...
	--- Sadly the call on their end is not dynamic ...
	local modifier = g_Courseplay.globalSettings:getSettings().wageModifier:getValue()/100
	return superFunc(vehicle, ...) * modifier
end

AIJobFieldWork.getPricePerMs = Utils.overwrittenFunction(AIJobFieldWork.getPricePerMs, CpAIJob.getPricePerMs_FixPrecisionFarming)


--- Fruit Destruction
local function updateWheelDestructionAdjustment(vehicle, superFunc, ...)
	if g_Courseplay.globalSettings.fruitDestruction:getValue() == g_Courseplay.globalSettings.AI_FRUIT_DESTRUCTION_OFF then 
		--- AI Fruit destruction is disabled.
		superFunc(vehicle, ...)
		return
	end
	if g_Courseplay.globalSettings.fruitDestruction:getValue() == g_Courseplay.globalSettings.AI_FRUIT_DESTRUCTION_ONLY_CP 
		and (not vehicle.rootVehicle.getIsCpActive or not vehicle.rootVehicle:getIsCpActive()) then 
		--- AI Fruit destruction is disabled for other helpers than CP.
		superFunc(vehicle, ...)
		return
	end
	--- This hack enables AI Fruit destruction.
	local oldFunc = vehicle.getIsAIActive
	vehicle.getIsAIActive = function()
		return false
	end
	superFunc(vehicle, ...)
	vehicle.getIsAIActive = oldFunc
end
Wheels.onUpdate = Utils.overwrittenFunction(Wheels.onUpdate, updateWheelDestructionAdjustment)


function CpAIJob:getVehicle()
	return self.vehicleParameter:getVehicle() or self.vehicle
end

--- Makes sure that the keybinding/hud job has the vehicle.
function CpAIJob:setVehicle(v, isHudJob)
	self.vehicle = v
	self.isHudJob = isHudJob
	if self.cpJobParameters then 
		self.cpJobParameters:validateSettings()
	end
end

function CpAIJob:getIsHudJob()
	return self.isHudJob
end

function CpAIJob:showNotification(aiMessage)
	if g_Courseplay.globalSettings.infoTextHudActive:getValue() == g_Courseplay.globalSettings.DISABLED then 
		CpAIJob:superClass().showNotification(self, aiMessage)
		return
	end
	local releaseMessage, hasFinished, event = g_infoTextManager:getInfoTextDataByAIMessage(aiMessage)
	local vehicle = self:getVehicle()
	--- Makes sure the message is shown, when a player is in the vehicle.
	if releaseMessage and vehicle:getIsEntered() then 
		g_currentMission:showBlinkingWarning(releaseMessage:getText(), 5000)
	end
end

function CpAIJob:getCanGenerateFieldWorkCourse()
	return false
end

function CpAIJob:debug(...)
	local vehicle = self:getVehicle()
	if vehicle then 
		CpUtil.debugVehicle(self.debugChannel, vehicle, ...)
	else 
		CpUtil.debugFormat(self.debugChannel, ...)
	end
end


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
	AIJobTypeManager:registerJobType(CpAIJobBaleFinder.name, CpAIJobBaleFinder.jobName, CpAIJobBaleFinder)
	AIJobTypeManager:registerJobType(CpAIJobFieldWork.name, CpAIJobFieldWork.jobName, CpAIJobFieldWork)
	AIJobTypeManager:registerJobType(CpAIJobCombineUnloader.name, CpAIJobCombineUnloader.jobName, CpAIJobCombineUnloader)
	AIJobTypeManager:registerJobType(CpAIJobSiloLoader.name, CpAIJobSiloLoader.jobName, CpAIJobSiloLoader)
	AIJobTypeManager:registerJobType(CpAIJobBunkerSilo.name, CpAIJobBunkerSilo.jobName, CpAIJobBunkerSilo)
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
	local myJobTypeIndex = g_currentMission.aiJobTypeManager:getJobTypeIndexByName(CpAIJobBunkerSilo.name)
	if myJobTypeIndex then
		local myJobType = g_currentMission.aiJobTypeManager:getJobTypeByIndex(myJobTypeIndex)
		myJobType.classObject = CpAIJobBunkerSilo
	end
	local myJobTypeIndex = g_currentMission.aiJobTypeManager:getJobTypeIndexByName(CpAIJobSiloLoader.name)
	if myJobTypeIndex then
		local myJobType = g_currentMission.aiJobTypeManager:getJobTypeByIndex(myJobTypeIndex)
		myJobType.classObject = CpAIJobSiloLoader
	end
end

AIJobTypeManager.loadMapData = Utils.appendedFunction(AIJobTypeManager.loadMapData,CpAIJob.registerJob)

