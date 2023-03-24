--- Combine unloader job.
---@class CpAIJobSiloLoader : CpAIJobFieldWork
CpAIJobSiloLoader = {
	name = "SILO_LOADER_CP",
	jobName = "CP_job_siloLoader",
}
local AIJobCombineUnloaderCp_mt = Class(CpAIJobSiloLoader, CpAIJob)


function CpAIJobSiloLoader.new(isServer, customMt)
	local self = CpAIJob.new(isServer, customMt or AIJobCombineUnloaderCp_mt)

	self.heapPlot = HeapPlot(g_currentMission.inGameMenu.ingameMap)
    self.heapPlot:setVisible(false)
	self.heapNode = CpUtil.createNode("siloNode", 0, 0, 0, nil)
	self.heap = nil
	return self
end

function CpAIJobSiloLoader:delete()
	CpAIJobSiloLoader:superClass().delete(self)
	CpUtil.destroyNode(self.heapNode)
end

function CpAIJobSiloLoader:setupTasks(isServer)
	CpAIJob.setupTasks(self, isServer)
	self.siloLoaderTask = CpAITaskSiloLoader.new(isServer, self)
	self:addTask(self.siloLoaderTask)
end

function CpAIJobSiloLoader:setupJobParameters()
	CpAIJobSiloLoader:superClass().setupJobParameters(self)
	self:setupCpJobParameters()
end

function CpAIJobSiloLoader:setupCpJobParameters()
	self.cpJobParameters = CpSiloLoaderJobParameters(self)
	CpSettingsUtil.generateAiJobGuiElementsFromSettingsTable(self.cpJobParameters.settingsBySubTitle, self, self.cpJobParameters)
	self.cpJobParameters:validateSettings()
	self.cpJobParameters.loadPosition:setSnappingAngle(math.pi/8) -- AI menu snapping angle of 22.5 degree.
end

--- Disables course generation.
function CpAIJobSiloLoader:getCanGenerateFieldWorkCourse()
	return false
end

--- Disables course generation.
function CpAIJobSiloLoader:isCourseGenerationAllowed()
	return false
end

function CpAIJobSiloLoader:getIsAvailableForVehicle(vehicle)
	return vehicle.getCanStartCpSiloLoaderWorker and vehicle:getCanStartCpSiloLoaderWorker()
end

function CpAIJobSiloLoader:getCanStartJob()
	return self.heap ~= nil
end


---@param vehicle Vehicle
---@param mission Mission
---@param farmId number
---@param isDirectStart boolean disables the drive to by giants
---@param isStartPositionInvalid boolean resets the drive to target position by giants and the field position to the vehicle position.
function CpAIJobSiloLoader:applyCurrentState(vehicle, mission, farmId, isDirectStart, isStartPositionInvalid)
	CpAIJob.applyCurrentState(self, vehicle, mission, farmId, isDirectStart)
	
	self.cpJobParameters:validateSettings()

	self:copyFrom(vehicle:getCpSiloLoaderWorkerJob())

	local x, z = self.cpJobParameters.loadPosition:getPosition()

	-- no field position from the previous job, use the vehicle's current position
	if x == nil or z == nil then
		x, _, z = getWorldTranslation(vehicle.rootNode)
		self.cpJobParameters.loadPosition:setPosition(x, z)
	end
end


function CpAIJobSiloLoader:setValues()
	CpAIJob.setValues(self)
	local vehicle = self.vehicleParameter:getVehicle()
	self.siloLoaderTask:setVehicle(vehicle)
	self.siloLoaderTask:setSilo(self.heap)
end


--- Called when parameters change, scan field
function CpAIJobSiloLoader:validate(farmId)
	self.heapPlot:setVisible(false)
	self.heap = nil
	local isValid, errorMessage = CpAIJob.validate(self, farmId)
	if not isValid then
		return isValid, errorMessage
	end
	local vehicle = self.vehicleParameter:getVehicle()
	if vehicle then 
		vehicle:applyCpSiloLoaderWorkerJobParameters(self)
	end
	
	--- Updates the heap
	local x, z = self.cpJobParameters.loadPosition:getPosition()
	local angle = self.cpJobParameters.loadPosition:getAngle()
	if x == nil or angle == nil then
		return false, g_i18n:getText("CP_error_no_heap_found")
	end

	setTranslation(self.heapNode, x, 0, z)
	setRotation(self.heapNode, 0, angle, 0)

	--- TODO: Handle bunker silo ?

	local found, heapSilo = BunkerSiloManagerUtil.createHeapBunkerSilo(self.heapNode, 0, 50, -10)
	if found then	
		self.heapPlot:setArea(heapSilo:getArea())
		self.heapPlot:setVisible(true)
		self.heap = heapSilo
		self.siloLoaderTask:setSilo(self.heap)
	else 
		return false, g_i18n:getText("CP_error_no_heap_found")
	end

	return isValid, errorMessage
end

function CpAIJobSiloLoader:readStream(streamId, connection)
	CpAIJobSiloLoader:superClass().readStream(self, streamId, connection)

	local x, z = self.cpJobParameters.loadPosition:getPosition()
	local angle = self.cpJobParameters.loadPosition:getAngle()
	if x ~= nil and angle ~= nil then
		setTranslation(self.heapNode, x, 0, z)
		setRotation(self.heapNode, 0, angle, 0)
		local found, heapSilo = BunkerSiloManagerUtil.createHeapBunkerSilo(self.heapNode, 0, 50, -10)
		if found then	
			self.heapPlot:setArea(heapSilo:getArea())
			self.heapPlot:setVisible(true)
			self.heap = heapSilo
			self.siloLoaderTask:setSilo(self.heap)
		end
	end
end

function CpAIJobSiloLoader:writeStream(streamId, connection)
	CpAIJobSiloLoader:superClass().writeStream(self, streamId, connection)
end

function CpAIJobSiloLoader:saveToXMLFile(xmlFile, key, usedModNames)
	CpAIJobSiloLoader:superClass().saveToXMLFile(self, xmlFile, key)
	self.cpJobParameters:saveToXMLFile(xmlFile, key)

	return true
end

function CpAIJobSiloLoader:loadFromXMLFile(xmlFile, key)
	CpAIJobSiloLoader:superClass().loadFromXMLFile(self, xmlFile, key)
	self.cpJobParameters:loadFromXMLFile(xmlFile, key)
end

function CpAIJobSiloLoader:copyFrom(job)
	self.cpJobParameters:copyFrom(job.cpJobParameters)
end

function CpAIJobSiloLoader:drawSilos(map)
    if self.heapPlot then
        self.heapPlot:draw(map)
    end
end