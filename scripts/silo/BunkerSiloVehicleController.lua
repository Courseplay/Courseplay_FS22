--- Controls a driver in the bunker silo. 
---@class CpBunkerSiloVehicleController
CpBunkerSiloVehicleController = CpObject()
CpBunkerSiloVehicleController.WALL_OFFSET = 0.5
function CpBunkerSiloVehicleController:init(silo, vehicle, driveStrategy)
	---@type CpBunkerSilo
	self.silo = silo
	self.vehicle = vehicle
	self.driveStrategy = driveStrategy
	self.isInverted = false

	local vehicleNode = vehicle:getAIDirectionNode()
	if calcDistanceFrom(self.silo.startNode, vehicleNode) > calcDistanceFrom(self.silo.heightNode, vehicleNode) then
		self.isInverted = true
	end

	self.debugChannel = CpDebug.DBG_SILO
end

function CpBunkerSiloVehicleController:delete()
	
end

--- Gets the direction into the silo
--- Automatically adjust for the vehicle start position,
--- as a silo might be inverted depending on the vehicle starting point.
function CpBunkerSiloVehicleController:getDriveIntoDirection()
	local dirX, dirZ = self.silo:getLengthDirection()
	if self.isInverted then 
		dirX, dirZ = -dirX, -dirZ
	end
	return dirX, dirZ
end

--- Gets the drive data for the drive strategy.
---@param width number
---@return {x : number, z : number} start position 
---@return {dx : number, dz : number} end position 
function CpBunkerSiloVehicleController:getTarget(width)
	
	local widthCount, siloWidth = 0, self.silo:getWidth()
	widthCount = math.ceil(siloWidth/width)
	local unitWidth = siloWidth/widthCount
	self:debug('Bunker width: %.1f, working width: %.1f (passed in), unit width: %.1f', siloWidth, width, unitWidth)
	self:setupMap(width, unitWidth, widthCount)

	local targetLine = self:getNextLine(widthCount, width)
	self:debug("target line: %d", targetLine)

	local x, z, dx, dz = self:getPositionsForLine(targetLine, width, widthCount, unitWidth)
	self.lastLine = targetLine
	self.drivingTarget = {{x, z}, {dx, dz}}
	return {x, z}, {dx, dz}	
end

--- Gets the last generated target.
function CpBunkerSiloVehicleController:getLastTarget()
	return unpack(self.drivingTarget)
end

--- Gets a lane to drive into the silo from.
---@param line number target line in the bunker silo
---@param width number correct width of a single line
---@param widthCount number total number of lines
---@param unitWidth number 
---@return number x start point
---@return number z start point
---@return number dx end point
---@return number dz end point
function CpBunkerSiloVehicleController:getPositionsForLine(line, width, widthCount, unitWidth)
	local x, z
	local sx, sz = self.silo:getStartPosition()
	local dirXWidth, dirZWidth = self.silo:getWidthDirection()
	local dirXLength, dirZLength = self.silo:getLengthDirection()
	local siloWidth = self.silo:getWidth()
	local siloLength = self.silo:getLength()
	if line == 1 then
		x = sx + dirXWidth * (width/2 + self.WALL_OFFSET)
		z = sz + dirZWidth * (width/2 + self.WALL_OFFSET)
	elseif line == widthCount then 
		x = sx + dirXWidth * (siloWidth - width/2 - self.WALL_OFFSET)
		z = sz + dirZWidth * (siloWidth - width/2 - self.WALL_OFFSET)
	else
		x = sx + dirXWidth * (line * unitWidth - unitWidth/2)
		z = sz + dirZWidth * (line * unitWidth - unitWidth/2)
	end

	local dx = x + dirXLength * siloLength
	local dz = z + dirZLength * siloLength

	if self.isInverted then 
		x, z, dx, dz = dx, dz, x, z
	end
	return x, z, dx, dz
end

--- Gets the next line to drive.
function CpBunkerSiloVehicleController:getNextLine(numLines, width)
	return 1
end

--- Setups a map with all lanes mostly for debugging for now.
---@param width number
---@param unitWidth number
---@param widthCount number
function CpBunkerSiloVehicleController:setupMap(width, unitWidth, widthCount)
	self.map = {}
	local x, z, dx, dz
	for i = 1, widthCount do 
		x, z, dx, dz = self:getPositionsForLine(i, width, widthCount, unitWidth)
		table.insert(self.map, {x, z, dx, dz})
	end
end

function CpBunkerSiloVehicleController:debug(...)
	CpUtil.debugVehicle(self.debugChannel, self.vehicle,  ...)	
end

--- Tells the driver, that the bunker silo was deleted.
function CpBunkerSiloVehicleController:setBunkerSiloInvalid()
	self.driveStrategy:stopSiloWasDeleted()
end

function CpBunkerSiloVehicleController:draw()
	if self:isDebugEnabled() then
		if self.map then
			for _, line in pairs(self.map) do 
				local x, z, dx, dz = unpack(line)
				local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 0, z)
				local dy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, dx, 0, dz)
				drawDebugLine(x, y + 2, z, 1, 0, 1, dx, dy + 2, dz, 0, 1, 1)
			end
		end
	end
end

function CpBunkerSiloVehicleController:isDebugEnabled()
	return CpDebug:isChannelActive(self.debugChannel, self.vehicle)
end

--- Is the end of the silo reached.
---@param node number
---@param margin number
---@return boolean end reached?
---@return number distance to the end 
function CpBunkerSiloVehicleController:isEndReached(node, margin)
	if self.drivingTarget then
		local x, _, z = localToWorld(node, 0, 0, margin)
		local dx, dz = unpack(self.drivingTarget[2])
		local dist = MathUtil.vector2Length(x - dx, z - dz)
		return not self.silo:isPointInSilo(x, z) and dist < 5, MathUtil.clamp(2 * dist, 5, math.huge)
	end
	return false, math.huge
end

--- Silo controller for a Bunker silo leveler driver.
--- Handles the bunker silo lines and the automatic 
--- selection of the next line for a new approach.
---@class CpBunkerSiloLevelerController : CpBunkerSiloVehicleController
CpBunkerSiloLevelerController = CpObject(CpBunkerSiloVehicleController)
CpBunkerSiloLevelerController.LAST_DIRECTIONS = {
	LEFT = 0,
	RIGHT = 1
}
function CpBunkerSiloLevelerController:init(silo, vehicle, driveStrategy)
	CpBunkerSiloVehicleController.init(self, silo, vehicle, driveStrategy)
	self.lastLine = 1
	self.currentTarget = nil
	self.lastDirection = self.LAST_DIRECTIONS.LEFT
end


function CpBunkerSiloLevelerController:hasNearbyUnloader()
	return self.silo:hasNearbyUnloader()
end

function CpBunkerSiloLevelerController:isWaitingForUnloaders()
	return self.driveStrategy:isWaitingForUnloaders()
end

function CpBunkerSiloLevelerController:isWaitingAtParkPosition()
	return self.driveStrategy:isWaitingAtParkPosition()
end

--- Gets the next line to drive.
---@param numLines number
---@return number new line to drive on
function CpBunkerSiloLevelerController:getNextLine(numLines)
	local nextLine, nextDirection
	if self.lastDirection == self.LAST_DIRECTIONS.LEFT then 
		--- 4-3-2-1
		if self.lastLine <= 1 then
			nextLine = math.min(self.lastLine + 1, numLines)
			nextDirection = self.LAST_DIRECTIONS.RIGHT
		else 
			nextLine = self.lastLine - 1
			nextDirection = self.LAST_DIRECTIONS.LEFT
		end
	else
		--- 2-3-4-5
		if self.lastLine >= numLines then
			nextLine = math.max(self.lastLine - 1, 1)
			nextDirection = self.LAST_DIRECTIONS.LEFT
		else 
			nextLine = self.lastLine + 1
			nextDirection = self.LAST_DIRECTIONS.RIGHT
		end
	end
	self.lastDirection = nextDirection
	return nextLine
end

function CpBunkerSiloLevelerController:draw()
	CpBunkerSiloVehicleController.draw(self)
	if self:isDebugEnabled() then
		self.silo:drawUnloaderArea()
		if g_currentMission.controlledVehicle == self.vehicle then
			local debugData = self.silo:getDebugData()
			table.insert(debugData, 1, {
				name = "is waiting", value = self:isWaitingAtParkPosition()
			})
			DebugUtil.renderTable(0.4, 0.4, 0.018, debugData, 0)
		end
	end
end

--- Controls the driving lines into the silo,
--- based on the fill level in the lines.
---@class CpBunkerSiloLoaderController : CpBunkerSiloVehicleController
CpBunkerSiloLoaderController = CpObject(CpBunkerSiloVehicleController)

function CpBunkerSiloLoaderController:init(silo, vehicle, driveStrategy)
	CpBunkerSiloVehicleController.init(self, silo, vehicle, driveStrategy)
end

--- Gets the next line with the most fill level.
---@param numLines number
---@param width number
---@return number next lane to take.
function CpBunkerSiloLoaderController:getNextLine(numLines, width)
	local dirXWidth, dirZWidth = self.silo:getWidthDirection()
	local bestLane, mostFillLevel, fillType = 1, 0
	for i, line in ipairs(self.map) do 

		local sx, sz = line[1] + dirXWidth * - width/2, line[2] + dirZWidth * - width/2
		local wx, wz = line[1] + dirXWidth * width/2, line[2] + dirZWidth * width/2
		local hx, hz = line[3] + dirXWidth * - width/2 , line[4] + dirZWidth * - width/2

		local fillType = DensityMapHeightUtil.getFillTypeAtArea(sx, sz, wx, wz, hx, hz)
		if fillType and fillType ~= 0 then 
			local fillLevel = DensityMapHeightUtil.getFillLevelAtArea(fillType, sx, sz, wx, wz, hx, hz)
			self:debug("Lane(%d) has %.2f of %s", i, fillLevel, g_fillTypeManager:getFillTypeByIndex(fillType).title)
			if fillLevel > mostFillLevel then 
				mostFillLevel = fillLevel
				bestLane = i
				fillType = fillType
			end
		end
	end
	return bestLane
end