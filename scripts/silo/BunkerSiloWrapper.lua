--- Heap Bunker Silo
--- Simulates a Giants BunkerSilo object
---@class CpHeapBunkerSilo
CpHeapBunkerSilo = CpObject()

---@param sx number
---@param sz number
---@param wx number
---@param wz number
---@param hx number
---@param hz number
function CpHeapBunkerSilo:init(sx, sz, wx, wz, hx, hz)

	self.bunkerSiloArea = {
		sx = sx,
		sy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, sx, 0, sz),
		sz = sz,
		wx = wx,
		wy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, wx, 0, wz),
		wz = wz,
		hx = hx,
		hy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, hx, 0, hz),
		hz = hz,
	}
	self.bunkerSiloArea.inner = {
		sx = sx,
		sy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, sx, 0, sz),
		sz = sz,
		wx = wx,
		wy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, wx, 0, wz),
		wz = wz,
		hx = hx,
		hy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, hx, 0, hz),
		hz = hz,
	}
	self.bunkerSiloArea.dhx = self.bunkerSiloArea.hx - self.bunkerSiloArea.sx
	self.bunkerSiloArea.dhy = self.bunkerSiloArea.hy - self.bunkerSiloArea.sy
	self.bunkerSiloArea.dhz = self.bunkerSiloArea.hz - self.bunkerSiloArea.sz
	self.bunkerSiloArea.dhx_norm, self.bunkerSiloArea.dhy_norm, self.bunkerSiloArea.dhz_norm = MathUtil.vector3Normalize(self.bunkerSiloArea.dhx, self.bunkerSiloArea.dhy, self.bunkerSiloArea.dhz)
	self.bunkerSiloArea.dwx = self.bunkerSiloArea.wx - self.bunkerSiloArea.sx
	self.bunkerSiloArea.dwy = self.bunkerSiloArea.wy - self.bunkerSiloArea.sy
	self.bunkerSiloArea.dwz = self.bunkerSiloArea.wz - self.bunkerSiloArea.sz
	self.bunkerSiloArea.dwx_norm, self.bunkerSiloArea.dwy_norm, self.bunkerSiloArea.dwz_norm = MathUtil.vector3Normalize(self.bunkerSiloArea.dwx, self.bunkerSiloArea.dwy, self.bunkerSiloArea.dwz)
	
	local area = self.bunkerSiloArea
	local dirX, dirZ, length = CpMathUtil.getPointDirection({x = area.sx, z = area.sz},
		{x = area.hx, z = area.hz})
	self.dirX = dirX
	self.dirZ = dirZ
	local dirWX, dirWZ, width = CpMathUtil.getPointDirection({x = area.sx, z = area.sz},
		{x = area.wx, z = area.wz})
	self.dirWX = dirWX
	self.dirWZ = dirWZ

	self.area = 	{
		{
			x = area.sx, 
			z = area.sz
		},
		{
			x = area.wx, 
			z = area.wz
		},
		{
			x = area.wx + dirX * length, 
			z = area.wz + dirZ * length,
		},
		{
			x = area.hx, 
			z = area.hz
		},
		{
			x = area.sx, 
			z = area.sz
		} }
	self.sx = area.sx
	self.sy = area.sy
	self.sz = area.sz
	self.wx = area.wx
	self.wy = area.wy
	self.wz = area.wz
	self.hx = area.hx
	self.hy = area.hy
	self.hz = area.hz
end

--- Gets the area of the heap.
function CpHeapBunkerSilo:getArea()
	return self.area
end

--- Gets the length from {sx, sz} to {hx, hz}.
function CpHeapBunkerSilo:getLength()
	return MathUtil.vector2Length(self.sx - self.hx, self.sz - self.hz)
end

function CpHeapBunkerSilo:getWidth()
	return MathUtil.vector2Length(self.sx - self.wx, self.sz - self.wz)
end

--- Front left corner
function CpHeapBunkerSilo:getStartPosition()
	return self.sx, self.sz
end

--- Back left corner
function CpHeapBunkerSilo:getHeightPosition()
	return self.hx, self.hz
end

--- Front right corner
function CpHeapBunkerSilo:getWidthPosition()
	return self.wx, self.wz
end

function CpHeapBunkerSilo:getDirection()
	return self.dirX, self.dirZ
end

function CpHeapBunkerSilo:getFrontCenter()
	local width = self:getWidth()
	return self.sx + self.dirWX * width/2, self.sz + self.dirWZ * width/2
end

function CpHeapBunkerSilo:getBackCenter()
	local length = self:getLength()
	local fcx, fcz = self:getFrontCenter()
	return fcx + self.dirX * length/2, fcz + self.dirZ * length/2
end

function CpHeapBunkerSilo:drawDebug()
	DebugUtil.drawDebugAreaRectangle(self.sx, self.sy + 2, self.sz, self.wx, self.wy + 2, self.wz, self.hx, self.hy + 2, self.hz,
		 false, 0.5, 0.5, 0.5)

	DebugUtil.drawDebugGizmoAtWorldPos(self.sx, self.sy + 3, self.sz, self.dirX, 0, self.dirZ, 
		0, 1, 0, "StartPoint", false)
	DebugUtil.drawDebugGizmoAtWorldPos(self.wx, self.wy + 3, self.wz, self.dirX, 0, self.dirZ, 
		0, 1, 0, "WidthPoint", false)
	DebugUtil.drawDebugGizmoAtWorldPos(self.hx, self.hy + 3, self.hz, self.dirX, 0, self.dirZ, 
		0, 1, 0, "HeightPoint", false)
end


--- Is the point directly in the silo area.
function CpHeapBunkerSilo:isPointInSilo(x, z)
	return self:isPointInArea(x, z, self.area)
end

function CpHeapBunkerSilo:isNodeInSilo(node)
	local x, _, z = getWorldTranslation(node)
	return self:isPointInArea(x, z, self.area)
end

function CpHeapBunkerSilo:isVehicleInSilo(vehicle)
	return self:isNodeInSilo(vehicle.rootNode)
end

function CpHeapBunkerSilo:isPointInArea(x, z, area)
	return CpMathUtil.isPointInPolygon(area, x, z)	
end


--- Wrapper for a bunker silo.
CpBunkerSilo = CpObject()

CpBunkerSilo.UNLOADER_LENGTH_OFFSET = 50
CpBunkerSilo.UNLOADER_WIDTH_OFFSET = 20
CpBunkerSilo.DRAW_DEBUG = false
CpBunkerSilo.SIDE_MODES = {
	OPEN = 0,
	ONE_SIDED = 1,
	ONE_SIDED_INVERTED = 2
}


function CpBunkerSilo:init(silo)
	self.silo = silo
	self:setupArea()
	self.controllers = {}
	self.numControllers = 0
	self.nearbyUnloaders = {}
	self.numNearbyUnloaders = 0
	self.siloMode = self.SIDE_MODES.OPEN
	self.initialized = false

	self.plot = BunkerSiloPlot()
end

--- Setup the bunker silo area and direction data.
function CpBunkerSilo:setupArea()
	local area = self.silo.bunkerSiloArea.inner
	local dirX, dirZ, length = CpMathUtil.getPointDirection({x = area.sx, z = area.sz},
															 {x = area.hx, z = area.hz})
	self.area = 	{
		{
			x = area.sx, 
			z = area.sz
		},
		{
			x = area.wx, 
			z = area.wz
		},
		{
			x = area.wx + dirX * length, 
			z = area.wz + dirZ * length,
		},
		{
			x = area.hx, 
			z = area.hz
		},
		{
			x = area.sx, 
			z = area.sz
		} }
	self.length = length
	self.dirXLength, self.dirZLength = dirX, dirZ
	self.dirXWidth, self.dirZWidth, self.width = CpMathUtil.getPointDirection({x = area.sx, z = area.sz},
															 {x = area.wx, z = area.wz})
		
	self.sx = area.sx
	self.sz = area.sz
	self.wx = area.wx
	self.wz = area.wz
	self.hx = area.hx
	self.hz = area.hz

	self.startNode = area.start
	self.widthNode = area.width
	self.heightNode = area.height
end

--- Checks if the silo has a back wall and sets the plot area afterwards. 
function CpBunkerSilo:initialize()
	local x, z = self.sx + self.dirXWidth * self.width/2 + self.dirXLength * 2, self.sz + self.dirZWidth * self.width/2 + self.dirZLength * 2
	local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 0, z) + 2 

	raycastAll(x, y, z, self.dirXLength, 0, self.dirZLength, 'rayCastCallbackOneSidedSilo', self.length + 2, self)

	local x, z = self.hx + self.dirXWidth * self.width/2 - self.dirXLength * 2, self.hz + self.dirZWidth * self.width/2 - self.dirZLength * 2
	local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 0, z) + 2 

	raycastAll(x, y, z, -self.dirXLength, 0, -self.dirZLength, 'rayCastCallbackOneSidedSiloInverted', self.length + 2, self)


	self.plot:setAreas(self:getPlotAreas())
	self.initialized = true
end


function CpBunkerSilo.readStreamSilo(silo, ...)
	local wrapper = g_bunkerSiloManager:getSiloWrapperByNode(silo.interactionTriggerNode)
	if wrapper then 
		wrapper:initialize()
	end
end
BunkerSilo.readStream = Utils.appendedFunction(BunkerSilo.readStream, CpBunkerSilo.readStreamSilo)

function CpBunkerSilo:rayCastCallbackOneSidedSilo(hitObjectId, x, y, z, distance, nx, ny, nz, subShapeIndex, shapeId, isLast)
	if hitObjectId then 
		local object = g_currentMission:getNodeObject(hitObjectId)
		if self:isTheSameSilo(object) then 

			--- Back wall was found.
			self.siloMode = self.SIDE_MODES.ONE_SIDED
			return true
		end
	end
end

function CpBunkerSilo:rayCastCallbackOneSidedSiloInverted(hitObjectId, x, y, z, distance, nx, ny, nz, subShapeIndex, shapeId, isLast)
	if hitObjectId then 
		local object = g_currentMission:getNodeObject(hitObjectId)
		if self:isTheSameSilo(object) then 

			--- Back wall was found.
			self.siloMode = self.SIDE_MODES.ONE_SIDED_INVERTED
			return true
		end
	end
end

--- Is the placeable object the same as the silo?  
function CpBunkerSilo:isTheSameSilo(object)
	if object and object:isa(Placeable) then 
		if object.spec_bunkerSilo then 
			if self.silo == object.spec_bunkerSilo.bunkerSilo then 
				return true
			end
		end
	end
end

function CpBunkerSilo:getFrontArea(length, sideOffset)
	if self.siloMode == self.SIDE_MODES.ONE_SIDED_INVERTED then 
		return self:getBackAreaInternal(length, sideOffset)
	else 
		return self:getFrontAreaInternal(length, sideOffset)
	end
end

function CpBunkerSilo:getBackArea(length, sideOffset)
	if self.siloMode == self.SIDE_MODES.ONE_SIDED_INVERTED then 
		return self:getFrontAreaInternal(length, sideOffset)
	else 
		return self:getBackAreaInternal(length, sideOffset)
	end
end

--- Area in front of the silo, to manage possible unloaders there.
function CpBunkerSilo:getFrontAreaInternal(length, sideOffset)
	length = length or CpBunkerSilo.UNLOADER_LENGTH_OFFSET
	sideOffset = sideOffset or CpBunkerSilo.UNLOADER_WIDTH_OFFSET
	local area = 	{
		{
			x = self.sx - self.dirXWidth * sideOffset, 
			z = self.sz - self.dirZWidth * sideOffset
		},
		{
			x = self.wx + self.dirXWidth * sideOffset, 
			z = self.wz + self.dirZWidth * sideOffset
		},
		{
			x = self.wx - self.dirXLength * length + self.dirXWidth * sideOffset, 
			z = self.wz - self.dirZLength * length + self.dirZWidth * sideOffset,
		},
		{
			x = self.sx - self.dirXLength * length - self.dirXWidth * sideOffset, 
			z = self.sz - self.dirZLength * length - self.dirZWidth * sideOffset
		},
		{
			x = self.sx - self.dirXWidth * sideOffset, 
			z = self.sz - self.dirZWidth * sideOffset
		} }
	return area
end

--- Area in back of the silo, to manage possible unloaders there.
function CpBunkerSilo:getBackAreaInternal(length, sideOffset)
	length = length or CpBunkerSilo.UNLOADER_LENGTH_OFFSET
	sideOffset = sideOffset or CpBunkerSilo.UNLOADER_WIDTH_OFFSET
	local area = 	{
		{
			x = self.sx + self.dirXLength * self.length - self.dirXWidth * sideOffset, 
			z = self.sz + self.dirZLength * self.length - self.dirZWidth * sideOffset
		},
		{
			x = self.sx + self.dirXLength * (self.length + length) - self.dirXWidth * sideOffset, 
			z = self.sz + self.dirZLength * (self.length + length) - self.dirZWidth * sideOffset
		},
		{
			x = self.wx + self.dirXLength * (self.length + length) + self.dirXWidth * sideOffset, 
			z = self.wz + self.dirZLength * (self.length + length) + self.dirZWidth * sideOffset
		},
		{
			x = self.wx + self.dirXLength * self.length + self.dirXWidth * sideOffset, 
			z = self.wz + self.dirZLength * self.length + self.dirZWidth * sideOffset
		},
		{
			x = self.sx + self.dirXLength * self.length - self.dirXWidth * sideOffset, 
			z = self.sz + self.dirZLength * self.length - self.dirZWidth * sideOffset
		} }
	return area
end


function CpBunkerSilo:getArea()
	return self.area	
end

function CpBunkerSilo:getFrontCenter()
	return self.sx + self.dirWX * self.width/2, self.sz + self.dirWZ * self.width/2
end

function CpBunkerSilo:getBackCenter()
	local fcx, fcz = self:getFrontCenter()
	return fcx + self.dirX * self.length/2, fcz + self.dirZ * self.length/2
end

function CpBunkerSilo:getSilo()
	return self.silo	
end

function CpBunkerSilo:getNode()
	return self.silo.interactionTriggerNode	
end

function CpBunkerSilo:delete()
	for _, controller in pairs(self.controllers) do 
		controller:setBunkerSiloInvalid()
		controller:delete()
	end
	self.plot:delete()
end

--- Is the point directly in the silo area.
function CpBunkerSilo:isPointInSilo(x, z)
	return self:isPointInArea(x, z, self.area)
end

function CpBunkerSilo:isVehicleInSilo(vehicle)
	local x, _, z = getWorldTranslation(vehicle.rootNode)
	return self:isPointInArea(x, z, self.area)
end

function CpBunkerSilo:isPointInArea(x, z, area)
	return CpMathUtil.isPointInPolygon(area, x, z)	
end

function CpBunkerSilo:debug(...)
	CpUtil.debugFormat(CpUtil.DBG_SILO, ...)	
end

function CpBunkerSilo:update(dt)
	if not self.initialized then 
		self:initialize()
	end

	--- Searches for new unloaders in the unloader area and remove unloaders, that left.
	self:updateUnloaders(dt)
end

function CpBunkerSilo:draw()
	for i, controller in pairs(self.controllers) do 
		controller:draw()
	end
	if CpBunkerSilo.DRAW_DEBUG then
		self:drawUnloaderArea()
		local x, z = self.sx + self.dirXWidth * self.width/2 + self.dirXLength * 2, self.sz + self.dirZWidth * self.width/2 + self.dirZLength * 2
		local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 0, z) + 2
		DebugUtil.drawDebugLine(x, y, z, x + self.dirXLength * (self.length + 2), y, z + self.dirZLength * self.length)

		local x, z = self.hx + self.dirXWidth * self.width/2 - self.dirXLength * 2, self.hz + self.dirZWidth * self.width/2 - self.dirZLength * 2
		local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 0, z) + 3
		DebugUtil.drawDebugLine(x, y, z, x - self.dirXLength * (self.length + 2), y, z - self.dirZLength * self.length)

		if self.startNode then
			DebugUtil.drawDebugNode(self.startNode, "Start Node: "..tostring(self.siloMode), false, 5)
			DebugUtil.drawDebugNode(self.widthNode, "Width Node", false, 5)
			DebugUtil.drawDebugNode(self.heightNode, "Height Node", false, 5)
		end
	end
end

function CpBunkerSilo:drawArea(area)
	local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, self.sx, 0, self.sz) + 2
	DebugUtil.drawDebugAreaRectangle(area[1].x, y, area[1].z, area[2].x, y, area[2].z, area[4].x, y, area[4].z, false, 1, 0, 0)
end


--------------------------------------------------
--- Vehicle controllers.
--------------------------------------------------

--- Creates a controller for the vehicle.
---@param vehicle Vehicle
---@param driveStrategy AIDriveStrategyBunkerSilo
---@param drivingForwardsIntoSilo boolean
---@return CpBunkerSiloVehicleController
function CpBunkerSilo:setupTarget(vehicle, driveStrategy, drivingForwardsIntoSilo)
	self.controllers[vehicle.rootNode] = CpBunkerSiloVehicleController(self, vehicle, driveStrategy, drivingForwardsIntoSilo)
	self.numControllers = self.numControllers + 1 
	return self.controllers[vehicle.rootNode]
end

--- Resets the controller for the given vehicle.
function CpBunkerSilo:resetTarget(vehicle)
	if self.controllers[vehicle.rootNode] then
		self.controllers[vehicle.rootNode]:delete()
		self.controllers[vehicle.rootNode] = nil
		self.numControllers = self.numControllers - 1
	end
end

--------------------------------------------------
--- Bunker silo plot
--------------------------------------------------

function CpBunkerSilo:drawPlot(map, selectedSilo)
	self.plot:setHighlighted(self == selectedSilo)
	self.plot:draw(map)
end


function CpBunkerSilo:getPlotAreas()
	if self.siloMode == self.SIDE_MODES.ONE_SIDED then 
		return {
				{
					x = self.sx, 
					z = self.sz
				},
				{
					x = self.sx + self.dirXLength * self.length, 
					z = self.sz + self.dirZLength * self.length
				},
				{
					x = self.wx + self.dirXLength * self.length,
					z = self.wz + self.dirZLength * self.length,
				},
				{
					x = self.wx, 
					z = self.wz
				},
			}
	elseif self.siloMode == self.SIDE_MODES.ONE_SIDED_INVERTED then 
		return {
			{
				x = self.hx, 
				z = self.hz
			},
			{
				x = self.sx, 
				z = self.sz
			},
			{
				x = self.wx,
				z = self.wz,
			},
			{
				x = self.wx + self.dirXLength * self.length, 
				z = self.wz + self.dirZLength * self.length
			},
		}
	else
		return {
				{
					x = self.sx, 
					z = self.sz
				},
				{
					x = self.sx + self.dirXLength * self.length, 
					z = self.sz + self.dirZLength * self.length
				},
			},
			{
				{
					x = self.wx, 
					z = self.wz,
				},
				{
					x = self.wx + self.dirXLength * self.length, 
					z = self.wz + self.dirZLength * self.length
				},
			}
	end
end

function CpBunkerSilo:getPlot()
	return self.plot	
end

--------------------------------------------------
--- Manage nearby unloaders
--------------------------------------------------

--- Does the vehicle have a trailer and also is controlled by a player or AD.
--- TODO: Maybe add fill typ check ?
function CpBunkerSilo:isValidUnloader(vehicle)
	if AIUtil.hasChildVehicleWithSpecialization(vehicle, Trailer) then 
		if vehicle.getIsControlled and vehicle:getIsControlled() then 
			return true
		end
		if vehicle.ad and vehicle.ad.stateModule and vehicle.ad.stateModule:isActive() then
			return true
		end
	end
	return false
end

function CpBunkerSilo:hasNearbyUnloader()
	return self.numNearbyUnloaders > 0
end

function CpBunkerSilo:shouldUnloadersWaitForSiloWorker()
	local needsWaiting = false
	for _, controller in pairs(self.controllers) do 
		needsWaiting = needsWaiting or not controller:isWaitingForUnloaders() 
	end
	return needsWaiting
end

function CpBunkerSilo:addNearbyUnloader(vehicle)
	if not self.nearbyUnloaders[vehicle.rootNode] then
		self.nearbyUnloaders[vehicle.rootNode] = vehicle
		self.numNearbyUnloaders = self.numNearbyUnloaders + 1
		vehicle:addDeleteListener(self, "removeNearbyUnloader")
	end
end

function CpBunkerSilo:removeNearbyUnloader(vehicle)
	if self.nearbyUnloaders[vehicle.rootNode] then 
		self.nearbyUnloaders[vehicle.rootNode] = nil
		self.numNearbyUnloaders = self.numNearbyUnloaders - 1
		vehicle:removeDeleteListener(self, "removeNearbyUnloader")
	end
end

function CpBunkerSilo:getNearbyUnloaders()
	return self.nearbyUnloaders
end

function CpBunkerSilo:updateUnloaders(dt)
	--- Searches for new unloaders in the unloader area and remove unloaders, that left.
	if self.numControllers > 0 and g_updateLoopIndex % 7 == 0 then 
		for _, vehicle in pairs(g_currentMission.vehicles) do 
			local isValid = false
			if self:isValidUnloader(vehicle) then 
				for _, v in pairs(vehicle:getChildVehicles()) do 
					local x, _, z = getWorldTranslation(v.rootNode)
					if self:isUnloaderInSilo(x, z) then
						isValid = true
					end 
				end
			end
			if isValid then 
				self:addNearbyUnloader(vehicle)
			else
				self:removeNearbyUnloader(vehicle)
			end
		end
	end
	if self:shouldUnloadersWaitForSiloWorker() then
		--- Makes sure the AD driver wait for the silo worker. 
		for _, unloader in pairs(self.nearbyUnloaders) do
			if unloader.spec_autodrive and unloader.spec_autodrive.HoldDriving then 
				unloader.spec_autodrive:HoldDriving(unloader)
			end
		end
	end
end

--- Is the unloader in the silo or in front of the silo.
--- For silos without a back wall also check the back area of the silo.
function CpBunkerSilo:isUnloaderInSilo(x, z)
	return self:isPointInSilo(x, z) or 
			self:isPointInArea(x, z, self:getFrontArea())
			or self.siloMode == self.SIDE_MODES.OPEN and self:isPointInArea(x, z, self:getBackArea()) 
end

function CpBunkerSilo:drawUnloaderArea()
	self:drawArea(self:getFrontArea())
	if self.siloMode == self.SIDE_MODES.OPEN then
		self:drawArea(self:getBackArea())
	end
	self:drawArea(self:getArea())
end

function CpBunkerSilo:getDebugData()
	local data = {
		{
			name = "unloaders should wait: ",
			value = self:shouldUnloadersWaitForSiloWorker()
		}
	}
	for _, unloader in pairs(self.nearbyUnloaders) do 
		if unloader.ad and unloader.ad.stateModule and unloader.ad.stateModule:isActive() then
			table.insert(data, {
				name = "nearby unloader", 
				value = "AD: ".. CpUtil.getName(unloader)
			})
		else 
			table.insert(data, {
				name = "nearby unloader", 
				value = CpUtil.getName(unloader)
			})
		end
	end
	return data
end