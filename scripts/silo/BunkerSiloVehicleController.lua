--- Controls a driver in the bunker silo. 
---@class CpBunkerSiloVehicleController
CpBunkerSiloVehicleController = CpObject()
CpBunkerSiloVehicleController.LAST_DIRECTIONS = {
	LEFT = 0,
	RIGHT = 1
}
CpBunkerSiloVehicleController.WALL_OFFSET = 0.5
function CpBunkerSiloVehicleController:init(silo, vehicle, driveStrategy, drivingForwardsIntoSilo)
	self.silo = silo
	self.vehicle = vehicle
	self.driveStrategy = driveStrategy
	self.isInverted = false

	local vehicleNode = vehicle:getAIDirectionNode()
	if calcDistanceFrom(self.silo.startNode, vehicleNode) > calcDistanceFrom(self.silo.heightNode, vehicleNode) then
		self.isInverted = true
	end
	self.lastLine = 1
	self.currentTarget = nil
	self.lastDirection = self.LAST_DIRECTIONS.LEFT

	self.debugChannel = CpDebug.DBG_SILO
end

function CpBunkerSiloVehicleController:delete()
	
end

function CpBunkerSiloVehicleController:getDriveIntoDirection()
	local dirX, dirZ = self.silo.dirXLength, self.silo.dirZLength
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
	
	local widthCount = 0
	widthCount = math.ceil(self.silo.width/width)
	local unitWidth = self.silo.width/widthCount
	self:debug('Bunker width: %.1f, working width: %.1f (passed in), unit width: %.1f', self.silo.width, width, unitWidth)
	self:setupMap(width, unitWidth, widthCount)

	local targetLine, targetDirection = self:getNextLine(widthCount)
	self:debug("target line: %d", targetLine)

	local x, z, dx, dz = self:getPositionsForLine(targetLine, width, widthCount, unitWidth)
	self.lastLine = targetLine
	self.lastDirection = targetDirection
	self.drivingTarget = {{x, z}, {dx, dz}}
	return {x, z}, {dx, dz}	
end

function CpBunkerSiloVehicleController:getLastTarget()
	return unpack(self.drivingTarget)
end

function CpBunkerSiloVehicleController:getPositionsForLine(line, width, widthCount, unitWidth)
	local x, z
	if line == 1 then
		x = self.silo.sx + self.silo.dirXWidth * (width/2 + self.WALL_OFFSET)
		z = self.silo.sz + self.silo.dirZWidth * (width/2 + self.WALL_OFFSET)
	elseif line == widthCount then 
		x = self.silo.sx + self.silo.dirXWidth * (self.silo.width - width/2 - self.WALL_OFFSET)
		z = self.silo.sz + self.silo.dirZWidth * (self.silo.width - width/2 - self.WALL_OFFSET)
	else
		x = self.silo.sx + self.silo.dirXWidth * (line * unitWidth - unitWidth/2)
		z = self.silo.sz + self.silo.dirZWidth * (line * unitWidth - unitWidth/2)
	end

	local dx = x + self.silo.dirXLength * self.silo.length
	local dz = z + self.silo.dirZLength * self.silo.length

	if self.isInverted then 
		x, z, dx, dz = dx, dz, x, z
	end
	return x, z, dx, dz
end

--- Gets the next line to drive.
function CpBunkerSiloVehicleController:getNextLine(numLines)
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
	return nextLine, nextDirection
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

function CpBunkerSiloVehicleController:hasNearbyUnloader()
	return self.silo:hasNearbyUnloader()
end

function CpBunkerSiloVehicleController:isWaiting()
	return self:isWaitingAtParkPosition() or self:isWaitingForUnloaders()
end

function CpBunkerSiloVehicleController:isWaitingForUnloaders()
	return self.driveStrategy:isWaitingForUnloaders()
end

function CpBunkerSiloVehicleController:isWaitingAtParkPosition()
	return self.driveStrategy:isWaitingAtParkPosition()
end

function CpBunkerSiloVehicleController:draw()
	if self.map and self:isDebugEnabled() then
		for _, line in pairs(self.map) do 
			local x, z, dx, dz = unpack(line)
			local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 0, z)
			local dy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, dx, 0, dz)
			drawDebugLine(x, y + 2, z, 1, 0, 1, dx, dy + 2, dz, 0, 1, 1)
		end
		self.silo:drawUnloaderArea()
	end
end

function CpBunkerSiloVehicleController:isDebugEnabled()
	return CpDebug:isChannelActive(self.debugChannel, self.vehicle)
end

--- Is the end of the silo reached.
function CpBunkerSiloVehicleController:isEndReached(node, margin)
	if self.drivingTarget then
		local x, _, z = localToWorld(node, 0, 0, margin)
		local dx, dz = unpack(self.drivingTarget[2])
		local dist = MathUtil.vector2Length(x - dx, z - dz)
		return not self.silo:isPointInSilo(x, z) and dist < 5, MathUtil.clamp(2 * dist, 5, math.huge)
	end
	return false, math.huge
end