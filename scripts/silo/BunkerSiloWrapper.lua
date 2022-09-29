
--- Wrapper for a bunker silo.
CpBunkerSilo = CpObject()

CpBunkerSilo.UNLOADER_LENGTH_OFFSET = 15
CpBunkerSilo.UNLOADER_WIDTH_OFFSET = 5

function CpBunkerSilo:init(silo)
	self.silo = silo
	self:setupArea()
	self.controllers = {}
	self.numControllers = 0
	self.nearbyUnloaders = {}
	self.numNearbyUnloaders = 0
	self.isOneSidedSilo = false
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
	local x, z = self.sx + self.dirXWidth * self.width/2, self.sz + self.dirZWidth * self.width/2
	local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 0, z) + 2 

	raycastAll(x, y, z, self.dirXLength, 0, self.dirZLength, 'rayCastCallbackOneSidedSilo', self.length + 2, self)

	self.plot:setAreas(self:getPlotAreas())
end

function CpBunkerSilo:rayCastCallbackOneSidedSilo(hitObjectId, x, y, z, distance)
	if hitObjectId then 
		local object = g_currentMission:getNodeObject(hitObjectId)
		if self:isTheSameSilo(object) then 
			--- Back wall was found.
			self.isOneSidedSilo = true
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

--- Area in front of the silo, to manage possible unloaders there.
function CpBunkerSilo:getFrontArea(length, sideOffset)
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
function CpBunkerSilo:getBackArea(length, sideOffset)
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

function CpBunkerSilo:isPointInArea(x, z, area)
	return CpMathUtil.isPointInPolygon(area, x, z)	
end

function CpBunkerSilo:debug(...)
	CpUtil.debugFormat(CpUtil.DBG_SILO, ...)	
end

function CpBunkerSilo:update(dt)
	if not self.initialized then 
		self:initialize()
		self.initialized = true
	end
	--local x, z = self.sx + self.dirXWidth * self.width/2, self.sz + self.dirZWidth * self.width/2
	--local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 0, z) + 2
	--DebugUtil.drawDebugLine(x, y, z, x + self.dirXLength * (self.length + 2), y, z + self.dirZLength * (self.length + 2))

	--- Searches for new unloaders in the unloader area and remove unloaders, that left.
	self:updateUnloaders(dt)
end

function CpBunkerSilo:draw()
	for i, controller in pairs(self.controllers) do 
		controller:draw()
	end
	if self.numControllers > 0 then 
		--- Draw the unloader detection areas, for debugging for now.
		self:drawUnloaderArea()
	end
end

function CpBunkerSilo:drawArea(area)
	local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, area[1].x, 0, area[1].z) + 2
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
	if self.isOneSidedSilo then 
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
	end
end

function CpBunkerSilo:hasNearbyUnloader()
	return self.numNearbyUnloaders > 0
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

function CpBunkerSilo:updateUnloaders(dt)
	--- Searches for new unloaders in the unloader area and remove unloaders, that left.
	if self.numControllers > 0 and g_updateLoopIndex % 10 == 0 then 
		for i, vehicle in pairs(g_currentMission.vehicles) do 
			local isValid = false
			if self:isValidUnloader(vehicle) then 
				for i, v in pairs(vehicle:getChildVehicles()) do 
					local x, _, z = getWorldTranslation(v.rootNode)
					if self:isUnloaderInSilo(x, z) then
						isValid = true
					end 
				end
			end
			if not isValid then 
				self:removeNearbyUnloader(vehicle)
			end
		end
	end
	for i, unloader in pairs(self.nearbyUnloaders) do 
		--- TODO: handle ad unloaders here.
	end
end

--- Is the unloader in the silo or in front of the silo.
--- For silos without a back wall also check the back area of the silo.
function CpBunkerSilo:isUnloaderInSilo(x, z)
	return self:isPointInSilo(x, z) or 
			self:isPointInArea(x, z, self:getFrontArea())
			or not self.isOneSidedSilo and self:isPointInArea(x, z, self:getBackArea()) 
end

function CpBunkerSilo:drawUnloaderArea()
	self:drawArea(self:getFrontArea())
	if not self.isOneSidedSilo then
		self:drawArea(self:getBackArea())
	end
	self:drawArea(self:getArea())
end