source(Courseplay.BASE_DIRECTORY .. "scripts/AIJobs/tasks/AITaskShovelLoadingBunkerSilo.lua")
source(Courseplay.BASE_DIRECTORY .. "scripts/AIJobs/tasks/AITaskShovelUnloading.lua")

--- Example AI job derived of AIJobFieldWork.
---@class AIJobShovelModeCp : AIJob
AIJobShovelModeCp = {
	START_ERROR_LIMIT_REACHED = 1,
	START_ERROR_VEHICLE_DELETED = 2,
	START_ERROR_NO_PERMISSION = 3,
	START_ERROR_VEHICLE_IN_USE = 4
}
local AIJobShovelModeCp_mt = Class(AIJobShovelModeCp, AIJob)

function AIJobShovelModeCp.new(isServer, customMt)
	local self = AIJob.new(isServer, customMt or AIJobShovelModeCp_mt)

	self.driveToBunkerSiloTask = AITaskDriveTo.new(isServer, self)
	self.shovelLoadingBunkerSiloTask = AITaskShovelLoadingBunkerSilo.new(isServer,self)
	self.driveToUnloadingTask = AITaskDriveTo.new(isServer, self)
	self.shovelUnloadingTask = AITaskShovelUnloading.new(isServer,self)

	self:addTask(self.driveToBunkerSiloTask)
	self:addTask(self.shovelLoadingBunkerSiloTask)
	self:addTask(self.driveToUnloadingTask)
	self:addTask(self.shovelUnloadingTask)

	self.vehicleParameter = AIParameterVehicle.new()
	self.loopingParameter = AIParameterLooping.new()
	self.loadingPositionAngleParameter = AIParameterPositionAngle.new(math.rad(5))
	self.unloadingPositionAngleParameter = AIParameterPositionAngle.new(math.rad(5))

	self:addNamedParameter("vehicle", self.vehicleParameter)
	self:addNamedParameter("loadingPositionAngle", self.loadingPositionAngleParameter)
	self:addNamedParameter("unloadingPositionAngle", self.unloadingPositionAngleParameter)
	self:addNamedParameter("looping", self.loopingParameter)

	local vehicleGroup = AIParameterGroup.new(g_i18n:getText("ai_parameterGroupTitleVehicle"))

	vehicleGroup:addParameter(self.vehicleParameter)

	local loadingGroup = AIParameterGroup.new(g_i18n:getText("ai_parameterGroupTitleLoadingPosition"))

	loadingGroup:addParameter(self.loadingPositionAngleParameter)

	local unloadingGroup = AIParameterGroup.new("Ent"..g_i18n:getText("ai_parameterGroupTitleLoadingPosition"))

	unloadingGroup:addParameter(self.unloadingPositionAngleParameter)

	local loopingGroup = AIParameterGroup.new(g_i18n:getText("ai_parameterGroupTitleLooping"))

	loopingGroup:addParameter(self.loopingParameter)
	table.insert(self.groupedParameters, vehicleGroup)
	table.insert(self.groupedParameters, loadingGroup)
	table.insert(self.groupedParameters, unloadingGroup)
	table.insert(self.groupedParameters, loopingGroup)

	self.silo = nil

	return self
end


function AIJobShovelModeCp:setValues()
	self:resetTasks()

	local vehicle = self.vehicleParameter:getVehicle()

	if vehicle == nil then
		return
	end

	self.driveToBunkerSiloTask :setVehicle(vehicle)
	self.shovelLoadingBunkerSiloTask:setVehicle(vehicle)
	self.driveToUnloadingTask:setVehicle(vehicle)
	self.shovelUnloadingTask:setVehicle(vehicle)


	local shovel = CpUtil.getVehicleWithSpecialization(vehicle,Shovel)
	if shovel == nil then 
		return
	end

	self.shovelLoadingBunkerSiloTask:setShovel(shovel)
	self.shovelUnloadingTask:setShovel(shovel)


	local x, z = self.unloadingPositionAngleParameter:getPosition()

	if x ~= nil then
		self.driveToUnloadingTask:setTargetPosition(x, z)
	end

	local xDir, zDir = self.unloadingPositionAngleParameter:getDirection()

	if xDir ~= nil then
		self.driveToUnloadingTask:setTargetDirection(xDir, zDir)
	end

	local x, z = self.loadingPositionAngleParameter:getPosition()
	local xDir, zDir = self.loadingPositionAngleParameter:getDirection()
	self.shovelLoadingBunkerSiloTask:setupSilo(x,z,xDir,zDir)
	self:setBunkerSiloTarget(x,z)
	local offset = 5
	self.driveToBunkerSiloTask:setTargetOffset(-offset)
	self.driveToUnloadingSiloTask:setTargetOffset(-offset)


end


function AIJobShovelModeCp:setBunkerSiloTarget(ax,az)
	local x,z,xDir,zDir = self.shovelLoadingBunkerSiloTask:getStartPositionAndDirection(ax,az)
	if x ~= nil then
		self.driveToBunkerSiloTask:setTargetPosition(x, z)
	end
	if xDir ~= nil then
		self.driveToBunkerSiloTask:setTargetDirection(xDir, zDir)
	end
end


function AIJobShovelModeCp:validate(farmId)
	self:setParamterValid(true)

	local isVehicleValid, vehicleErrorMessage = self.vehicleParameter:validate()

	if not isVehicleValid then
		self.vehicleParameter:setIsValid(false)
	end


	local isUnloadingPositionValid, unloadingPositionErrorMessage = self.unloadingPositionAngleParameter:validate()

	if not isUnloadingPositionValid then
		unloadingPositionErrorMessage = g_i18n:getText("ai_validationErrorNoLoadingPoint")

		self.unloadingPositionAngleParameter:setIsValid(false)
	end

	local isLoadingPositionValid, loadingPositionErrorMessage = self.loadingPositionAngleParameter:validate()

	if not isLoadingPositionValid then
		loadingPositionErrorMessage = g_i18n:getText("ai_validationErrorNoLoadingPoint")

		self.loadingPositionAngleParameter:setIsValid(false)
	end

	local isValid = isVehicleValid and isUnloadingPositionValid and isLoadingPositionValid
	local errorMessage = vehicleErrorMessage or unloadingPositionErrorMessage or loadingPositionErrorMessage

	return isValid, errorMessage
end

function AIJobShovelModeCp:applyCurrentState(vehicle, mission, farmId, isDirectStart)
	AIJobShovelModeCp:superClass().applyCurrentState(self, vehicle, mission, farmId, isDirectStart)
	self.vehicleParameter:setVehicle(vehicle)
	self.loopingParameter:setIsLooping(true)

	local x, z, angle, _ = nil

	if vehicle.getLastJob ~= nil then
		local lastJob = vehicle:getLastJob()

		if lastJob ~= nil and lastJob:isa(AIJobShovelModeCp) then
			self.unloadingStationParameter:setUnloadingStation(lastJob.unloadingStationParameter:getUnloadingStation())
			self.loopingParameter:setIsLooping(lastJob.loopingParameter:getIsLooping())

			x, z = lastJob.positionAngleParameter:getPosition()
			angle = lastJob.positionAngleParameter:getAngle()
		end
	end

	if x == nil or z == nil then
		x, _, z = getWorldTranslation(vehicle.rootNode)
	end

	if angle == nil then
		local dirX, _, dirZ = localDirectionToWorld(vehicle.rootNode, 0, 0, 1)
		angle = MathUtil.getYRotationFromDirection(dirX, dirZ)
	end

	self.positionAngleParameter:setPosition(x, z)
	self.positionAngleParameter:setAngle(angle)

	local unloadingStations = {}

	for _, unloadingStation in pairs(g_currentMission.storageSystem:getUnloadingStations()) do
		if g_currentMission.accessHandler:canPlayerAccess(unloadingStation) and unloadingStation:isa(UnloadingStation) then
			local fillTypes = unloadingStation:getAISupportedFillTypes()

			if next(fillTypes) ~= nil then
				table.insert(unloadingStations, unloadingStation)
			end
		end
	end

	self.unloadingStationParameter:setValidUnloadingStations(unloadingStations)
end

function AIJobShovelModeCp:start(farmId)
	AIJobShovelModeCp:superClass().start(self, farmId)

	if self.isServer then
		local vehicle = self.vehicleParameter:getVehicle()

		vehicle:createAgent(self.helperIndex)
		vehicle:aiJobStarted(self, self.helperIndex, farmId)
	end
end

function AIJobShovelModeCp:stop(aiMessage)
	if self.isServer then
		local vehicle = self.vehicleParameter:getVehicle()

		vehicle:deleteAgent()
		vehicle:aiJobFinished()
	end

	AIJobShovelModeCp:superClass().stop(self, aiMessage)
end

function AIJobShovelModeCp:startTask(task)
	

	AIJobShovelModeCp:superClass().startTask(self, task)
end

function AIJobShovelModeCp:getStartTaskIndex()
	return self.driveToBunkerSiloTask.taskIndex
end

function AIJobShovelModeCp:getNextTaskIndex(isSkipTask)
	local nextTaskIndex = AIJobShovelModeCp:superClass().getNextTaskIndex(self, isSkipTask)

	return nextTaskIndex
end

function AIJobShovelModeCp:canContinueWork()
	local vehicle = self.vehicleParameter:getVehicle()

	if vehicle == nil then
		return false, AIMessageErrorVehicleDeleted.new()
	end
	return true, nil
end

function AIJobShovelModeCp:getCanSkipTask()
	
	return false
end

function AIJobShovelModeCp:skipCurrentTask()
	
end

function AIJobShovelModeCp:getIsAvailableForVehicle(vehicle)
	if vehicle.createAgent == nil or vehicle.setAITarget == nil or not vehicle:getCanStartAIVehicle() then
		return false
	end
	local shovel = CpUtil.getVehicleWithSpecialization(vehicle,Shovel)
	if shovel == nil then 
		return false
	end
end

function AIJobShovelModeCp:getTitle()
	local vehicle = self.vehicleParameter:getVehicle()

	if vehicle ~= nil then
		return vehicle:getName()
	end

	return ""
end

function AIJobShovelModeCp:getIsLooping()
	return self.loopingParameter:getIsLooping()
end

function AIJobShovelModeCp:getIsStartable(connection)
	if g_currentMission.aiSystem:getAILimitedReached() then
		return false, AIJobShovelModeCp.START_ERROR_LIMIT_REACHED
	end

	local vehicle = self.vehicleParameter:getVehicle()

	if vehicle == nil then
		return false, AIJobShovelModeCp.START_ERROR_VEHICLE_DELETED
	end

	if not g_currentMission:getHasPlayerPermission("hireAssistant", connection, vehicle:getOwnerFarmId()) then
		return false, AIJobShovelModeCp.START_ERROR_NO_PERMISSION
	end

	if vehicle:getIsInUse(connection) then
		return false, AIJobShovelModeCp.START_ERROR_VEHICLE_IN_USE
	end

	return true, AIJob.START_SUCCESS
end

function AIJobShovelModeCp:getDescription()
	local desc = AIJobLoadAndDeliver:superClass().getDescription(self)
	local nextTask = self:getTaskByIndex(self.currentTaskIndex)

	if nextTask == self.driveToBunkerSiloTask then
		desc = desc .. " - " .. g_i18n:getText("driveToBunkerSiloTask")
	elseif nextTask == self.shovelLoadingBunkerSiloTask then
		desc = desc .. " - " .. g_i18n:getText("shovelLoadingBunkerSiloTask")
	elseif nextTask == self.driveToUnloadingSiloTask then
		desc = desc .. " - " .. g_i18n:getText("driveToUnloadingSiloTask")
	elseif nextTask == self.shovelUnloadingTask then
		desc = desc .. " - " .. g_i18n:getText("shovelUnloadingTask")
	end

	return desc
end

function AIJobShovelModeCp.getIsStartErrorText(state)
	if state == AIJobShovelModeCp.START_ERROR_LIMIT_REACHED then
		return g_i18n:getText("ai_startStateLimitReached")
	elseif state == AIJobShovelModeCp.START_ERROR_VEHICLE_DELETED then
		return g_i18n:getText("ai_startStateVehicleDeleted")
	elseif state == AIJobShovelModeCp.START_ERROR_NO_PERMISSION then
		return g_i18n:getText("ai_startStateNoPermission")
	elseif state == AIJobShovelModeCp.START_ERROR_VEHICLE_IN_USE then
		return g_i18n:getText("ai_startStateVehicleInUse")
	end

	return g_i18n:getText("ai_startStateSuccess")
end
