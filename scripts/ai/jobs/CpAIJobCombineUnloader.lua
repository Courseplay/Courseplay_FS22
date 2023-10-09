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

--- Combine unloader job.
---@class CpAIJobCombineUnloader : CpAIJob
CpAIJobCombineUnloader = {
	name = "COMBINE_UNLOADER_CP",
	jobName = "CP_job_combineUnload",
	minStartDistanceToField = 20,
	minFieldUnloadDistanceToField = 20,
	maxHeapLength = 150
}

local AIJobCombineUnloaderCp_mt = Class(CpAIJobCombineUnloader, CpAIJob)

function CpAIJobCombineUnloader.new(isServer, customMt)
	local self = CpAIJob.new(isServer, customMt or AIJobCombineUnloaderCp_mt)

	self.lastPositionX, self.lastPositionZ = math.huge, math.huge
    self.hasValidPosition = false

    self.selectedFieldPlot = FieldPlot(g_currentMission.inGameMenu.ingameMap)
    self.selectedFieldPlot:setVisible(false)
	self.selectedFieldPlot:setBrightColor(true)

	self.heapPlot = HeapPlot(g_currentMission.inGameMenu.ingameMap)
    self.heapPlot:setVisible(false)
	self.heapNode = CpUtil.createNode("siloNode", 0, 0, 0, nil)

	--- Giants unload
	self.dischargeNodeInfos = {}
	
	return self
end

function CpAIJobCombineUnloader:delete()
	CpAICombineUnloader:superClass().delete(self)
	CpUtil.destroyNode(self.heapNode)
end

function CpAIJobCombineUnloader:setupTasks(isServer)
	CpAIJob.setupTasks(self, isServer)
	self.waitingForHarvesterOrLoaderTask = CpAITaskWaitingForHarvesterOrLoader(isServer, self)
	self.combineUnloaderTask = CpAITaskCombineUnloader(isServer, self)
	self.driveToUnloadingTask = AITaskDriveTo.new(isServer, self)
	self.dischargeTask = AITaskDischarge.new(isServer, self)
	self.unloadOnFieldTask = CpAITaskUnloadOnField(isServer, self)
	self.selfUnloadTask = CpAITaskSelfUnload(isServer, self)
	self:addTask(self.combineUnloaderTask)
end

--- Only add the task, once we now which are necessary.
function CpAIJobCombineUnloader:onPreStart()
	--- First we need to reset these tasks
	self:removeTask(self.driveToUnloadingTask)
	self:removeTask(self.dischargeTask)
	self:removeTask(self.unloadOnFieldTask)
	self:removeTask(self.selfUnloadTask)
	if self.cpJobParameters.useGiantsUnload:getValue() then
		--- Giants unload
		self:addTask(self.driveToUnloadingTask)
		self:addTask(self.dischargeTask)
		return 
	end
	if self.cpJobParameters.useFieldUnload:getValue() then
		--- Unloading on the field
		self:addTask(self.unloadOnFieldTask)
		return
	end
	--- Self unload on the field
	self:addTask(self.selfUnloadTask)
end

function CpAIJobCombineUnloader:setupJobParameters()
	CpAIJob.setupJobParameters(self)
    self:setupCpJobParameters(CpCombineUnloaderJobParameters(self))
	self.cpJobParameters.fieldUnloadPosition:setSnappingAngle(math.pi/8) -- AI menu snapping angle of 22.5 degree.

	--- Giants unload
	self.unloadingStationParameter = self.cpJobParameters.unloadingStation
	self.waitForFillingTask = self.combineUnloaderTask
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
	CpAIJob.applyCurrentState(self, vehicle, mission, farmId, isDirectStart)
	
	self.cpJobParameters:validateSettings()

	self:copyFrom(vehicle:getCpCombineUnloaderJob())

	local x, z = self.cpJobParameters.fieldPosition:getPosition()
	-- no field position from the previous job, use the vehicle's current position
	if x == nil or z == nil then
		x, _, z = getWorldTranslation(vehicle.rootNode)
		self.cpJobParameters.fieldPosition:setPosition(x, z)
	end
	local x, z = self.cpJobParameters.fieldUnloadPosition:getPosition()
	local angle = self.cpJobParameters.fieldUnloadPosition:getAngle()
	-- no field position from the previous job, use the vehicle's current position
	if x == nil or z == nil or angle == nil then
		x, _, z = getWorldTranslation(vehicle.rootNode)
		local dirX, _, dirZ = localDirectionToWorld(vehicle.rootNode, 0, 0, 1)
		local angle = MathUtil.getYRotationFromDirection(dirX, dirZ)
		self.cpJobParameters.fieldUnloadPosition:setPosition(x, z)
		self.cpJobParameters.fieldUnloadPosition:setAngle(angle)
	end
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
	self.waitingForHarvesterOrLoaderTask:setVehicle(vehicle)
	self.combineUnloaderTask:setVehicle(vehicle)
	self:validateFieldPosition()
	if self.cpJobParameters.useGiantsUnload:getValue() then
		self:setupGiantsUnloaderData(vehicle)
	elseif self.cpJobParameters.useFieldUnload:getValue() then
		self.unloadOnFieldTask:setVehicle(vehicle)
	else
		self.selfUnloadTask:setVehicle(vehicle)
	end
end

function CpAIJobCombineUnloader:validateFieldPosition(isValid, errorMessage)
	local tx, tz = self.cpJobParameters.fieldPosition:getPosition()
	if tx == nil or tz == nil then 
		return false, g_i18n:getText("CP_error_not_on_field")
	end
	local _
	self.fieldPolygon, _ = CpFieldUtil.getFieldPolygonAtWorldPosition(tx, tz)
	self.hasValidPosition = self.fieldPolygon ~= nil
	if self.hasValidPosition then 
		self.selectedFieldPlot:setWaypoints(self.fieldPolygon)
        self.selectedFieldPlot:setVisible(true)
	else
		return false, g_i18n:getText("CP_error_not_on_field")
	end
	return isValid, errorMessage
end

--- Called when parameters change, scan field
function CpAIJobCombineUnloader:validate(farmId)
	self.hasValidPosition = false
	self.selectedFieldPlot:setVisible(false)
	self.heapPlot:setVisible(false)
	local isValid, errorMessage = CpAIJob.validate(self, farmId)
	if not isValid then
		return isValid, errorMessage
	end
	local vehicle = self.vehicleParameter:getVehicle()
	if vehicle then 
		vehicle:applyCpCombineUnloaderJobParameters(self)
	end
	------------------------------------
	--- Validate selected field
	-------------------------------------
	local isValid, errorMessage = self:validateFieldPosition(isValid, errorMessage)

	if not isValid then
		return isValid, errorMessage
	end
	------------------------------------
	--- Validate start distance to field
	-------------------------------------
	local useGiantsUnload = false
	if not self.cpJobParameters.useGiantsUnload:getIsDisabled() then 
		useGiantsUnload =  self.cpJobParameters.useGiantsUnload:getValue() 
	end
	if isValid and self.isDirectStart then 
		--- Checks the distance for starting with the hud, as a safety check.
		--- Firstly check, if the vehicle is near the field.
		local x, _, z = getWorldTranslation(vehicle.rootNode)
		isValid = CpMathUtil.isPointInPolygon(self.fieldPolygon, x, z) or 
				  CpMathUtil.getClosestDistanceToPolygonEdge(self.fieldPolygon, x, z) < self.minStartDistanceToField
		if not isValid and useGiantsUnload then 
			--- Alternatively check, if the start marker is close to the field and giants unload is active.
			local x, z = self.cpJobParameters.startPosition:getPosition()
			isValid = CpMathUtil.isPointInPolygon(self.fieldPolygon, x, z) or 
				  CpMathUtil.getClosestDistanceToPolygonEdge(self.fieldPolygon, x, z) < self.minStartDistanceToField
			if not isValid then
				return false, g_i18n:getText("CP_error_start_position_to_far_away_from_field")
			end 
		end
		if not isValid then
			return false, g_i18n:getText("CP_error_unloader_to_far_away_from_field")
		end
	end
	------------------------------------
	--- Validate giants unload if needed
	-------------------------------------
	if useGiantsUnload then 
		isValid, errorMessage = self.cpJobParameters.unloadingStation:validateUnloadingStation()
		
		if not isValid then
			return false, errorMessage
		end

		if not AIJobDeliver.getIsAvailableForVehicle(self, vehicle) then 
			return false, g_i18n:getText("CP_error_giants_unloader_not_available")
		end
	end
	if not isValid then
		return isValid, errorMessage
	end
	------------------------------------
	--- Validate field unload if needed
	-------------------------------------
	local useFieldUnload = false
	if not self.cpJobParameters.useFieldUnload:getIsDisabled() then 
		useFieldUnload =  self.cpJobParameters.useFieldUnload:getValue() 
	end
	if useFieldUnload then 
		
		local x, z = self.cpJobParameters.fieldUnloadPosition:getPosition()
		isValid = CpMathUtil.isPointInPolygon(self.fieldPolygon, x, z) or 
				  CpMathUtil.getClosestDistanceToPolygonEdge(self.fieldPolygon, x, z) < self.minFieldUnloadDistanceToField
		if not isValid then
			return false, g_i18n:getText("CP_error_fieldUnloadPosition_too_far_away_from_field")
		end
		--- Draws the silo
		local angle = self.cpJobParameters.fieldUnloadPosition:getAngle()
		setTranslation(self.heapNode, x, 0, z)
		setRotation(self.heapNode, 0, angle, 0)
		local found, heapSilo = BunkerSiloManagerUtil.createHeapBunkerSilo(vehicle, self.heapNode, 0, self.maxHeapLength, -10)
		if found then	
			self.heapPlot:setArea(heapSilo:getArea())
			self.heapPlot:setVisible(true)
		end
	end

	return isValid, errorMessage
end

function CpAIJobCombineUnloader:drawSelectedField(map)
	self.selectedFieldPlot:draw(map)
    self.heapPlot:draw(map)
end

------------------------------------
--- Giants unload 
------------------------------------

--- Sets static data for the giants unload. 
function CpAIJobCombineUnloader:setupGiantsUnloaderData(vehicle)
	self.dischargeNodeInfos = {}
	if vehicle == nil then 
		return
	end
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
end

function CpAIJobCombineUnloader:getNextTaskIndex(isSkipTask)
	if self.cpJobParameters.useGiantsUnload:getValue() then
		--- Giants unload, sets the correct dischargeNode and vehicle and unload target information.
		return AIJobDeliver.getNextTaskIndex(self, isSkipTask)
	else
		return CpAIJobCombineUnloader:superClass().getNextTaskIndex(self, isSkipTask)
	end
end

function CpAIJobCombineUnloader:canContinueWork()
	local canContinueWork, errorMessage = CpAIJobCombineUnloader:superClass().canContinueWork(self)
	if not canContinueWork then 
		return canContinueWork, errorMessage
	end
	--- Giants unload, checks if the unloading station is still available and not full.
	if self.cpJobParameters.useGiantsUnload:getValue() then 
		
		local canContinue, errorMessage = AIJobDeliver.canContinueWork(self)
		if not canContinue then 
			return canContinue, errorMessage
		end
	end

	return true, nil
end

function CpAIJobCombineUnloader:startTask(task)
	--- Giants unload, reset the discharge nodes before unloading.
	if self.cpJobParameters.useGiantsUnload:getValue() then
		if task == self.driveToUnloadingTask then
			for _, dischargeNodeInfo in ipairs(self.dischargeNodeInfos) do
				dischargeNodeInfo.dirty = true
			end
		end
	end
	CpAIJobCombineUnloader:superClass().startTask(self, task)
end

--- Starting index for giants unload: 
---  - Close or on the field, we make sure cp pathfinder is always involved.
---  - Else if the trailer is full and we are far away from the field, then let giants drive to unload directly.
---@return number
function CpAIJobCombineUnloader:getStartTaskIndex()
	local startTask = CpAIJobCombineUnloader:superClass().getStartTaskIndex(self)
	local vehicle = self:getVehicle()
	local fillLevelPercentage = FillLevelManager.getTotalTrailerFillLevelPercentage(vehicle)
	local readyToDriveUnloading = vehicle:getCpSettings().fullThreshold:getValue() < fillLevelPercentage
	if not self.cpJobParameters.useGiantsUnload:getValue() then 
		if readyToDriveUnloading then 
			if self.cpJobParameters.useFieldUnload:getValue() then 
				return self.unloadOnFieldTask.taskIndex
			else 
				return self.selfUnloadTask.taskIndex
			end
		end
		return startTask
	end
	local vehicle = self:getVehicle()
	local x, _, z = getWorldTranslation(vehicle.rootNode)
	if CpMathUtil.isPointInPolygon(self.fieldPolygon, x, z) or 
		CpMathUtil.getClosestDistanceToPolygonEdge(self.fieldPolygon, x, z) < 2*self.minStartDistanceToField then
		CpUtil.debugVehicle(CpDebug.DBG_FIELDWORK, vehicle, "Close to the field, start cp drive strategy.")
		return startTask
	end
	if readyToDriveUnloading then 
		CpUtil.debugVehicle(CpDebug.DBG_FIELDWORK, vehicle, "Not close to the field and vehicle is full, so start driving to unload.")
		--- Small hack, so we can use the giants function and don't need to do copy & paste.
		local oldTaskIx = self.currentTaskIndex
		self.currentTaskIndex = self.combineUnloaderTask.taskIndex
		self:getNextTaskIndex()
		self.currentTaskIndex = oldTaskIx
		return self.driveToUnloadingTask.taskIndex
	end
	return startTask
end

function CpAIJobCombineUnloader:getIsLooping()
	return true
end

--- Applies the target data like the needed strategy and so on to the combine unloader task
function CpAIJobCombineUnloader:setTarget(...)
	self.combineUnloaderTask:setTarget(...)	
end

function CpAIJobCombineUnloader:skipToUnloadNow()
	self.waitingForHarvesterOrLoaderTask:skip()
	self.combineUnloaderTask:skip()
end