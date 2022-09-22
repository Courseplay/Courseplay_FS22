--- Combine unloader job.
---@class CpAIJobCombineUnloader : CpAIJobFieldWork
CpAIJobCombineUnloader = {
	name = "COMBINE_UNLOADER_CP",
	translations = {
		jobName = "CP_job_combineUnload"
	},
	minStartDistanceToField = 20
}
local AIJobCombineUnloaderCp_mt = Class(CpAIJobCombineUnloader, CpAIJobFieldWork)


function CpAIJobCombineUnloader.new(isServer, customMt)
	local self = CpAIJobFieldWork.new(isServer, customMt or AIJobCombineUnloaderCp_mt)

	--- Giants unload
	self.dischargeNodeInfos = {}
	return self
end

function CpAIJobCombineUnloader:setupTasks(isServer)
	CpAIJob.setupTasks(self, isServer)
	self.combineUnloaderTask = CpAITaskCombineUnloader.new(isServer, self)
	self:addTask(self.combineUnloaderTask)

	--- Giants unload
	self.driveToUnloadingTask = AITaskDriveTo.new(isServer, self)
	self.dischargeTask = AITaskDischarge.new(isServer, self)
	self:addTask(self.driveToUnloadingTask)
	self:addTask(self.dischargeTask)
end

function CpAIJobCombineUnloader:setupCpJobParameters()
	self.cpJobParameters = CpCombineUnloaderJobParameters(self)
	CpSettingsUtil.generateAiJobGuiElementsFromSettingsTable(self.cpJobParameters.settingsBySubTitle, self, self.cpJobParameters)
	self.cpJobParameters:validateSettings()
end

--- Disables course generation.
function CpAIJobCombineUnloader:getCanGenerateFieldWorkCourse()
	return false
end

--- Disables course generation.
function CpAIJobCombineUnloader:isCourseGenerationAllowed()
	return false
end

function CpAIJobCombineUnloader:getIsAvailableForVehicle(vehicle)
	return vehicle.getCanStartCpCombineUnloader and vehicle:getCanStartCpCombineUnloader()
end

function CpAIJobCombineUnloader:getCanStartJob()
	return self.hasValidPosition
end


---@param vehicle Vehicle
---@param mission Mission
---@param farmId number
---@param isDirectStart boolean disables the drive to by giants
---@param isStartPositionInvalid boolean resets the drive to target position by giants and the field position to the vehicle position.
function CpAIJobCombineUnloader:applyCurrentState(vehicle, mission, farmId, isDirectStart, isStartPositionInvalid)
	CpAIJobFieldWork:superClass().applyCurrentState(self, vehicle, mission, farmId, isDirectStart)

	local x, z

	if vehicle.getLastJob ~= nil then
		local lastJob = vehicle:getLastJob()
		if lastJob ~= nil and lastJob.cpJobParameters then
			x, z = lastJob.fieldPositionParameter:getPosition()
		end
	end
	self:copyFrom(vehicle:getCpCombineUnloaderJob())

	x, z = self.fieldPositionParameter:getPosition()

	-- no field position from the previous job, use the vehicle's current position
	if x == nil or z == nil then
		x, _, z = getWorldTranslation(vehicle.rootNode)
	end

	self.fieldPositionParameter:setPosition(x, z)
end

--- Gets the giants unload station.
function CpAIJobCombineUnloader:getUnloadingStations()
	local unloadingStations = {}
	for _, unloadingStation in pairs(g_currentMission.storageSystem:getUnloadingStations()) do
		if g_currentMission.accessHandler:canPlayerAccess(unloadingStation) and unloadingStation:isa(UnloadingStation) then
			local fillTypes = unloadingStation:getAISupportedFillTypes()

			if next(fillTypes) ~= nil then
				table.insert(unloadingStations, unloadingStation)
			end
		end
	end
	return unloadingStations
end

function CpAIJobCombineUnloader:setValues()
	CpAIJob.setValues(self)
	local vehicle = self.vehicleParameter:getVehicle()
	self.combineUnloaderTask:setVehicle(vehicle)
	self:setupGiantsUnloaderData(vehicle)
end

--- Sets static data for the giants unload. 
function CpAIJobCombineUnloader:setupGiantsUnloaderData(vehicle)
	self.dischargeNodeInfos = {}
	if vehicle.getAIDischargeNodes ~= nil then
		for _, dischargeNode in ipairs(vehicle:getAIDischargeNodes()) do
			local _, _, z = vehicle:getAIDischargeNodeZAlignedOffset(dischargeNode, vehicle)

			table.insert(self.dischargeNodeInfos, {
				dirty = true,
				vehicle = vehicle,
				dischargeNode = dischargeNode,
				offsetZ = z
			})
		end
	end

	local childVehicles = vehicle:getChildVehicles()

	for _, childVehicle in ipairs(childVehicles) do
		if childVehicle.getAIDischargeNodes ~= nil then
			for _, dischargeNode in ipairs(childVehicle:getAIDischargeNodes()) do
				local _, _, z = childVehicle:getAIDischargeNodeZAlignedOffset(dischargeNode, vehicle)

				table.insert(self.dischargeNodeInfos, {
					dirty = true,
					vehicle = childVehicle,
					dischargeNode = dischargeNode,
					offsetZ = z
				})
			end
		end
	end
	self.driveToUnloadingTask:setVehicle(vehicle)
	self.dischargeTask:setVehicle(vehicle)
	if #self.dischargeNodeInfos > 0 then 
		table.sort(self.dischargeNodeInfos, function (a, b)
			return b.offsetZ < a.offsetZ
		end)
		local maxOffset = self.dischargeNodeInfos[#self.dischargeNodeInfos].offsetZ

		self.driveToUnloadingTask:setTargetOffset(-maxOffset)

	end
	local unloadingStation = self.cpJobParameters.unloadingStation:getUnloadingStation()
	local x, z, dirX, dirZ, trigger = unloadingStation:getAITargetPositionAndDirection(FillType.UNKNOWN)

	if trigger ~= nil then
		self.driveToUnloadingTask:setTargetPosition(x, z)
		self.driveToUnloadingTask:setTargetDirection(dirX, dirZ)
		self.dischargeTask:setUnloadTrigger(trigger)
	end

end

--- Called when parameters change, scan field
function CpAIJobCombineUnloader:validate(farmId)
	local isValid, errorMessage = CpAIJob.validate(self, farmId)
	if not isValid then
		return isValid, errorMessage
	end
	local vehicle = self.vehicleParameter:getVehicle()
	if vehicle then 
		vehicle:applyCpCombineUnloaderJobParameters(self)
	end

	isValid, errorMessage = self:validateFieldSetup(isValid, errorMessage)	
	self.combineUnloaderTask:setFieldPolygon(self.fieldPolygon)

	if isValid and self.isDirectStart then 
		--- Checks the distance for starting with the hud, as a safety check.
		--- Alternative consider using the start position marker and not the root vehicle.
		local x, _, z = getWorldTranslation(vehicle.rootNode)
		isValid = CpMathUtil.isPointInPolygon(self.fieldPolygon, x, z) or 
				  CpMathUtil.getClosestDistanceToPolygonEdge(self.fieldPolygon, x, z) < self.minStartDistanceToField
		if not isValid then 
			return false, g_i18n:getText("CP_error_unloader_to_far_away_from_field")
		end
	end

	--- Giants unload 
	if self.cpJobParameters.useGiantsUnload:getValue() then 
		isValid, errorMessage = self.cpJobParameters.unloadingStation:validateUnloadingStation()
		
		if not isValid then
			return false, errorMessage
		end

		if not AIJobDeliver.getIsAvailableForVehicle(self, vehicle) then 
			return false, g_i18n:getText("CP_error_giants_unloader_not_available")
		end
	end
	return isValid, errorMessage

end

function CpAIJobCombineUnloader:readStream(streamId, connection)
	if streamReadBool(streamId) then
		self.fieldPolygon = CustomField.readStreamVertices(streamId, connection)
		self.combineUnloaderTask:setFieldPolygon(self.fieldPolygon)
	end
	CpAIJobCombineUnloader:superClass().readStream(self, streamId, connection)
end

function CpAIJobCombineUnloader:writeStream(streamId, connection)
	if self.fieldPolygon then
		streamWriteBool(streamId, true)
		CustomField.writeStreamVertices(self.fieldPolygon, streamId, connection)
	else
		streamWriteBool(streamId, false)
	end
	CpAIJobCombineUnloader:superClass().writeStream(self, streamId, connection)
end


function CpAIJobCombineUnloader:saveToXMLFile(xmlFile, key, usedModNames)
	CpAIJobCombineUnloader:superClass().saveToXMLFile(self, xmlFile, key)
	self.cpJobParameters:saveToXMLFile(xmlFile, key)

	return true
end

function CpAIJobCombineUnloader:loadFromXMLFile(xmlFile, key)
	CpAIJobCombineUnloader:superClass().loadFromXMLFile(self, xmlFile, key)
	self.cpJobParameters:loadFromXMLFile(xmlFile, key)
end
function CpAIJobCombineUnloader:getNextTaskIndex(isSkipTask)
	--- Giants unload, sets the correct dischargeNode and vehicle.
	if self.currentTaskIndex == self.driveToUnloadingTask.taskIndex or self.currentTaskIndex == self.dischargeTask.taskIndex then

		for _, dischargeNodeInfo in ipairs(self.dischargeNodeInfos) do
			if dischargeNodeInfo.dirty then
				local vehicle = dischargeNodeInfo.vehicle
				local fillUnitIndex = dischargeNodeInfo.dischargeNode.fillUnitIndex
				if vehicle:getFillUnitFillLevel(fillUnitIndex) > 1 then
					self.dischargeTask:setDischargeNode(vehicle, dischargeNodeInfo.dischargeNode, dischargeNodeInfo.offsetZ)

					dischargeNodeInfo.dirty = false

					return self.dischargeTask.taskIndex
				end

				dischargeNodeInfo.dirty = false
			end
		end
	end

	local nextTaskIndex = AIJobDeliver:superClass().getNextTaskIndex(self, isSkipTask)

	return nextTaskIndex
end

function CpAIJobCombineUnloader:canContinueWork()
	local canContinueWork, errorMessage = CpAIJobCombineUnloader:superClass().canContinueWork(self)
	if not canContinueWork then 
		return canContinueWork, errorMessage
	end
	--- Giants unload, checks if the unloading station is still available and not full.
	if self.cpJobParameters.useGiantsUnload:getValue() then 
		local unloadingStation = self.cpJobParameters.unloadingStation:getUnloadingStation()

		if unloadingStation == nil then
			return false, AIMessageErrorUnloadingStationDeleted.new()
		end
		if self.currentTaskIndex == self.driveToUnloadingTask.taskIndex then
			local hasSpace = false
	
			for _, dischargeNodeInfo in ipairs(self.dischargeNodeInfos) do
				local dischargeVehicle = dischargeNodeInfo.vehicle
				local fillUnitIndex = dischargeNodeInfo.dischargeNode.fillUnitIndex
	
				if dischargeVehicle:getFillUnitFillLevel(fillUnitIndex) > 1 then
					local fillTypeIndex = dischargeVehicle:getFillUnitFillType(fillUnitIndex)
	
					if unloadingStation:getFreeCapacity(fillTypeIndex, self.startedFarmId) > 0 then
						hasSpace = true
	
						break
					end
				end
			end
	
			if not hasSpace then
				return false, AIMessageErrorUnloadingStationFull.new()
			end
		end
	end

	return true, nil
end

function CpAIJobCombineUnloader:startTask(task)
	--- Giants unload, reset the discharge nodes before unloading.
	if task == self.driveToUnloadingTask then
		for _, dischargeNodeInfo in ipairs(self.dischargeNodeInfos) do
			dischargeNodeInfo.dirty = true
		end
	end
	CpAIJobCombineUnloader:superClass().startTask(self, task)
end

function CpAIJobCombineUnloader:getStartTaskIndex()
	if not self.cpJobParameters.useGiantsUnload:getValue() then 
		return CpAIJobCombineUnloader:superClass().getStartTaskIndex(self)
	end
	local vehicle = self:getVehicle()
	local fillLevelPercentage = FillLevelManager.getTotalTrailerFillLevelPercentage(vehicle)

	local readyToDriveUnloading = self.cpJobParameters.fullThreshold:getValue() < fillLevelPercentage
	
	local vehicle = self.vehicleParameter:getVehicle()
	local x, _, z = getWorldTranslation(vehicle.rootNode)
	local tx, tz = self.positionAngleParameter:getPosition()
	local targetReached = math.abs(x - tx) < 1 and math.abs(z - tz) < 1

	if targetReached then
		if readyToDriveUnloading then
			self.combineUnloaderTask:skip()
		end
		return self.combineUnloaderTask.taskIndex
	end

	if readyToDriveUnloading then
		self.driveToTask:skip()
		self.combineUnloaderTask:skip()
	end

	return self.driveToTask.taskIndex
end

--- Callback by the drive strategy, when the trailer is full.
function CpAIJobCombineUnloader:onTrailerFull(vehicle, driveStrategy)
	if self.cpJobParameters.useGiantsUnload:getValue() then 
		--- Giants unload
		self.combineUnloaderTask:skip()
	else 
		vehicle:stopCurrentAIJob(AIMessageErrorIsFull.new())
	end
end

function CpAIJobCombineUnloader:getIsLooping()
	return true
end

function CpAIJobCombineUnloader:copyFrom(job)
	self.cpJobParameters:copyFrom(job.cpJobParameters)
	local x, z = job:getFieldPositionTarget()
	if x ~=nil then
		self.fieldPositionParameter:setValue(x, z)
	end
	local x, z = job.positionAngleParameter:getPosition()
	if x ~= nil then
		self.positionAngleParameter:setPosition(x, z)
	end
	local angle = job.positionAngleParameter:getAngle()
	if angle ~= nil then
		self.positionAngleParameter:setAngle(angle)
	end
end