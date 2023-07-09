--- Job for stationary loader.
---@class CpAIJobSiloLoader : CpAIJobFieldWork
---@field heapPlot HeapPlot
---@field heapNode number
CpAIJobSiloLoader = {
	name = "SILO_LOADER_CP",
	jobName = "CP_job_siloLoader",
	maxHeapLength = 150
}
local AIJobCombineUnloaderCp_mt = Class(CpAIJobSiloLoader, CpAIJob)

function CpAIJobSiloLoader.new(isServer, customMt)
	local self = CpAIJob.new(isServer, customMt or AIJobCombineUnloaderCp_mt)

	self.heapPlot = HeapPlot(g_currentMission.inGameMenu.ingameMap)
    self.heapPlot:setVisible(false)

	self.heapNode = CpUtil.createNode("siloNode", 0, 0, 0, nil)
	self.heap = nil
	self.hasValidPosition = false
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
	self:setupCpJobParameters(CpSiloLoaderJobParameters(self))
	self.cpJobParameters.loadPosition:setSnappingAngle(math.pi/8) -- AI menu snapping angle of 22.5 degree.
	self.cpJobParameters.unloadPosition:setSnappingAngle(math.pi/8) -- AI menu snapping angle of 22.5 degree.
end

function CpAIJobSiloLoader:getIsAvailableForVehicle(vehicle)
	return vehicle.getCanStartCpSiloLoaderWorker and vehicle:getCanStartCpSiloLoaderWorker()
end

function CpAIJobSiloLoader:getCanStartJob()
	return self.hasValidPosition
end

---@param vehicle table
---@param mission table
---@param farmId number
---@param isDirectStart boolean disables the drive to by giants
---@param isStartPositionInvalid boolean resets the drive to target position by giants and the field position to the vehicle position.
function CpAIJobSiloLoader:applyCurrentState(vehicle, mission, farmId, isDirectStart, isStartPositionInvalid)
	CpAIJob.applyCurrentState(self, vehicle, mission, farmId, isDirectStart)
	
	self.cpJobParameters:validateSettings()

	self:copyFrom(vehicle:getCpSiloLoaderWorkerJob())

	local x, z = self.cpJobParameters.loadPosition:getPosition()
	local angle = self.cpJobParameters.loadPosition:getAngle()
	-- no field position from the previous job, use the vehicle's current position
	if x == nil or z == nil or angle == nil then
		x, _, z = getWorldTranslation(vehicle.rootNode)
		local dirX, _, dirZ = localDirectionToWorld(vehicle.rootNode, 0, 0, 1)
		local angle = MathUtil.getYRotationFromDirection(dirX, dirZ)
		self.cpJobParameters.loadPosition:setPosition(x, z)
		self.cpJobParameters.loadPosition:setAngle(angle)
	end

	local x, z = self.cpJobParameters.unloadPosition:getPosition()

	-- no unload position use the vehicle's current position
	if x == nil or z == nil then
		x, _, z = getWorldTranslation(vehicle.rootNode)
		self.cpJobParameters.unloadPosition:setPosition(x, z)
	end
end


function CpAIJobSiloLoader:setValues()
	CpAIJob.setValues(self)
	local vehicle = self.vehicleParameter:getVehicle()
	self.siloLoaderTask:setVehicle(vehicle)

	local found, bunkerSilo, heapSilo = self:getBunkerSiloOrHeap(self.cpJobParameters.loadPosition, self.heapNode)
	if found then 
		if bunkerSilo then 
			self.bunkerSilo = bunkerSilo
		elseif heapSilo then
			self.heapPlot:setArea(heapSilo:getArea())
			self.heapPlot:setVisible(true)
			self.heap = heapSilo
		end
		self.siloLoaderTask:setSiloAndHeap(self.bunkerSilo, self.heap)
	end
end


--- Called when parameters change, scan field
function CpAIJobSiloLoader:validate(farmId)
	self.heapPlot:setVisible(false)
	self.heap = nil
	self.bunkerSilo = nil
	self.unloadStation = nil
	self.unloadTrigger = nil
	self.hasValidPosition = false
	self:getCpJobParameters().unloadStation:setValue(-1)
	local isValid, errorMessage = CpAIJob.validate(self, farmId)
	if not isValid then
		return isValid, errorMessage
	end
	local vehicle = self.vehicleParameter:getVehicle()
	if vehicle then 
		vehicle:applyCpSiloLoaderWorkerJobParameters(self)
	end
	
	--- First we search for bunker silos:
	local found, bunkerSilo, heapSilo = self:getBunkerSiloOrHeap(self.cpJobParameters.loadPosition, self.heapNode)
	if found then 
		self.hasValidPosition = true
		if bunkerSilo then 
			self.bunkerSilo = bunkerSilo
		elseif heapSilo then
			self.heapPlot:setArea(heapSilo:getArea())
			self.heapPlot:setVisible(true)
			self.heap = heapSilo
		end
		self.siloLoaderTask:setSiloAndHeap(self.bunkerSilo, self.heap)
	else 
		return false, g_i18n:getText("CP_error_no_heap_found")
	end
	if not AIUtil.hasChildVehicleWithSpecialization(vehicle, ConveyorBelt) then 
		if self.cpJobParameters.unloadAt:getValue() == CpSiloLoaderJobParameters.UNLOAD_TRIGGER then 
			--- Validate the trigger setup
			local found, unloadTrigger, unloadStation = self:getUnloadTriggerAt(self.cpJobParameters.unloadPosition)
			if found then 
				self.unloadStation = unloadStation
				self.unloadTrigger = unloadTrigger
				if unloadStation == nil then 
					return false, g_i18n:getText("CP_error_no_unload_trigger_found")
				end
				local id = NetworkUtil.getObjectId(unloadStation)
				if id ~= nil then 
					self:getCpJobParameters().unloadStation:setValue(id)
					self:getCpJobParameters().unloadStation:validateUnloadingStation()
				end
			else 
				return false, g_i18n:getText("CP_error_no_unload_trigger_found")
			end
			local unloadPosition = self:getCpJobParameters().unloadPosition
			if unloadPosition.x == nil or unloadPosition.angle == nil then 
				return false, g_i18n:getText("CP_error_no_unload_trigger_found")
			end
		end
	end
	return isValid, errorMessage
end

--- Gets the bunker silo or heap at the loading position in that order.
---@param loadPosition CpAIParameterPositionAngle
---@param node number
---@return boolean found?
---@return CpBunkerSilo|nil
---@return CpHeapBunkerSilo|nil
function CpAIJobSiloLoader:getBunkerSiloOrHeap(loadPosition, node)
	local x, z = loadPosition:getPosition()
	local angle = loadPosition:getAngle()
	if x == nil or angle == nil then
		return false
	end
	setTranslation(self.heapNode, x, 0, z)
	setRotation(self.heapNode, 0, angle, 0)
	local vehicle = self.vehicleParameter:getVehicle()
	local found, bunkerSilo = BunkerSiloManagerUtil.getBunkerSiloBetween(vehicle, node, 0, 25, -5)
	if found then 
		return true, bunkerSilo
	end
	local found, heapSilo = BunkerSiloManagerUtil.createHeapBunkerSilo(vehicle, node, 0, self.maxHeapLength, -10)
	return found, nil, heapSilo
end

--- Gets the unload trigger at the unload position.
---@param unloadPosition CpAIParameterPositionAngle
---@return boolean
---@return table|nil
function CpAIJobSiloLoader:getUnloadTriggerAt(unloadPosition)
	local x, z = unloadPosition:getPosition()
	local dirX, dirZ = unloadPosition:getDirection()
	if x == nil or dirX == nil then
		return false
	end	
	return g_triggerManager:getDischargeableUnloadTriggerAt( x, z, dirX, dirZ, 5, 5)
end

function CpAIJobSiloLoader:drawSilos(map)
    self.heapPlot:draw(map)
	g_bunkerSiloManager:drawSilos(map, self.bunkerSilo) 
	if self.cpJobParameters.unloadAt:getValue() == CpSiloLoaderJobParameters.UNLOAD_TRIGGER then 
		g_triggerManager:drawDischargeableTriggers(map, self.unloadTrigger)
	end
end


--- Gets the giants unload station.
function CpAIJobSiloLoader:getUnloadingStations()
	local unloadingStations = {}
	for _, unloadingStation in pairs(g_currentMission.storageSystem:getUnloadingStations()) do
		if g_currentMission.accessHandler:canPlayerAccess(unloadingStation) and unloadingStation:isa(UnloadingStation) then
			table.insert(unloadingStations, unloadingStation)
		end
	end
	return unloadingStations
end
