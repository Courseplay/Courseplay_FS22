--[[

Legacy code to display a course in 3D

]]
local deg, rad = math.deg, math.rad

local signData = {
	normal = { 10000, 'current',  4.5 }, -- orig height=5
	start =  {   500, 'current',  4.5 }, -- orig height=3
	stop =   {   500, 'current',  4.5 }, -- orig height=3
	wait =   {  1000, 'current',  4.5 }, -- orig height=3
	unload = {  2000, 'current', 4.0 },
	cross =  {  2000, 'crossing', 4.0 }
}
local waypointColors = {
	regular   = { 1.000, 0.212, 0.000, 1.000 }, -- orange
	turnStart = { 0.200, 0.900, 0.000, 1.000 }, -- green
	turnEnd   = { 0.896, 0.000, 0.000, 1.000 } -- red
}

---@class CourseDisplay
CourseDisplay = CpObject()

function CourseDisplay:init()
	self.courses = {}
	print('## Courseplay: setting up signs')

	local globalRootNode = getRootNode()

	self.buffer = {}
	self.bufferMax = {}
	self.sections = {}
	self.heightPos = {}
	self.protoTypes = {}

	for signType, data in pairs(signData) do
		self.buffer[signType] =    {}
		self.bufferMax[signType] = data[1]
		self.sections[signType] =  data[2]
		self.heightPos[signType] = data[3]
		local i3dNode =  g_i3DManager:loadSharedI3DFile( Courseplay.BASE_DIRECTORY .. 'img/signs/' .. signType .. '.i3d')
		local itemNode = getChildAt(i3dNode, 0)
		link(globalRootNode, itemNode)
		setRigidBodyType(itemNode, RigidBodyType.NONE)
		setTranslation(itemNode, 0, 0, 0)
		setVisibility(itemNode, false)
		delete(i3dNode)
		self.protoTypes[signType] = itemNode
	end
end

function CourseDisplay:delete()
	for _, vehicle in pairs(self.courses) do
		for _, course in pairs(vehicle) do
			for _, section in pairs(course) do
				self:deleteSign(section.sign)
			end
		end
	end

	for _,itemNode in pairs(courseplay.signs.protoTypes) do
		self:deleteSign(itemNode)
	end
end

function CourseDisplay:addSign(vehicle, signType, x, z, rotX, rotY, insertIndex, distanceToNext, diamondColor)
	signType = signType or 'normal'

	local sign
	local signFromBuffer = {}
	local receivedSignFromBuffer = CourseDisplay:tableMove(self.buffer[signType], signFromBuffer)

	if receivedSignFromBuffer then
		sign = signFromBuffer[1].sign
	else
		sign = clone(self.protoTypes[signType], true)
	end

	self:setTranslation(sign, signType, x, z)
	rotX = rotX or 0
	rotY = rotY or 0
	setRotation(sign, rad(rotX), rad(rotY), 0)
	if signType == 'normal' or signType == 'start' or signType == 'wait' then
		if signType == 'start' or signType == 'wait' then
			local signPart = getChildAt(sign, 1)
			setRotation(signPart, rad(-rotX), 0, 0)
		end
		if distanceToNext and distanceToNext > 0.01 then
			self:setWaypointSignLine(sign, distanceToNext, true)
		else
			self:setWaypointSignLine(sign, nil, false)
		end
	end
	setVisibility(sign, true)

	local signData = { type = signType, sign = sign, posX = x, posZ = z, rotY = rotY }
	if diamondColor and signType ~= 'cross' then
		self:setSignColor(signData, diamondColor)
	end

	local section = self.sections[signType]
	insertIndex = insertIndex or (#self.courses[vehicle][section] + 1)
	table.insert(self.courses[vehicle][section], insertIndex, signData)
end

function CourseDisplay:moveToBuffer(vehicle, vehicleIndex, signData)
	local signType = signData.type
	local section = self.sections[signType]

	if #self.buffer[signType] < self.bufferMax[signType] then
		setVisibility(signData.sign, false)
		CourseDisplay:tableMove(self.courses[vehicle][section], self.buffer[signType], vehicleIndex)
	else
		self:deleteSign(signData.sign)
		self.courses[vehicle][section][vehicleIndex] = nil
	end

end

function CourseDisplay:setTranslation(sign, signType, x, z)
	local terrainHeight = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 300, z)
	setTranslation(sign,	 x, terrainHeight + self.heightPos[signType], z)
end

function CourseDisplay:changeSignType(vehicle, vehicleIndex, oldType, newType)
	local section = self.sections[oldType]
	local signData = self.courses[vehicle][section][vehicleIndex]
	self:moveToBuffer(vehicle, vehicleIndex, signData)
	self:addSign(vehicle, newType, signData.posX, signData.posZ, signData.rotX, signData.rotY, vehicleIndex, nil, 'regular')
end

function CourseDisplay:setWaypointSignLine(sign, distance, vis)
	local line = getChildAt(sign, 0)
	if line ~= 0 then
		if vis and distance ~= nil then
			setScale(line, 1, 1, distance)
		end
		if vis ~= nil then
			setVisibility(line, vis)
		end
	end
end

function CourseDisplay:updateWaypointSigns(vehicle, section, idx)
	local waypoints = g_courseManager:getLegacyWaypoints(vehicle)
	if not waypoints then return end

	if self.courses[vehicle] == nil then
		self.courses[vehicle] = {current = {}, crossing = {}}
	end

	section = section or 'all' --section: 'all', 'crossing', 'current'
	CpUtil.debugVehicle(CpDebug.DBG_COURSES, vehicle, 'Updating waypoint display for %s', section)

	if section == 'all' or section == 'current' then
		local neededPoints = #waypoints

		--move not needed ones to buffer
		if #self.courses[vehicle].current > neededPoints then
			for j=#self.courses[vehicle].current, neededPoints+1, -1 do --go backwards so we can safely move/delete
				local signData = self.courses[vehicle].current[j]
				self:moveToBuffer(vehicle, j, signData)
			end
		end

		local np
		for i,wp in pairs(waypoints) do
    		if idx == nil or i == idx then  -- add this for courseEditor
    			local neededSignType = 'normal'
    			if i == 1 then
    				neededSignType = 'start'
    			elseif i == #waypoints then
    				neededSignType = 'stop'
    			elseif wp.wait or wp.interact then
    				neededSignType = 'wait'
    			elseif wp.unload then
    				neededSignType = 'unload'
    			end

    			-- direction + angle
    			if wp.rotX == nil then wp.rotX = 0 end
    			if wp.y == nil or wp.cy == 0 then
    				wp.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, wp.x, 0, wp.z)
    			end

    			if i < #waypoints then
    				np = waypoints[i + 1]
    				if np.y == nil or np.y == 0 then
    					np.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, np.x, 0, np.z)
    				end

    				wp.dirX, wp.dirY, wp.dirZ = MathUtil.vector3Normalize(np.x - wp.x, np.y - wp.y, np.z - wp.z)
					wp.distToNextPoint = MathUtil.vector3Length(np.x - wp.x, np.y - wp.y, np.z - wp.z)
    				if wp.distToNextPoint <= 0.01 and i > 1 then
    					local pp = waypoints[i - 1]
    					wp.dirX, wp.dirY, wp.dirZ = pp.dirX, pp.dirY, pp.dirZ
    				end
    				wp.rotY = MathUtil.getYRotationFromDirection(wp.dirX, wp.dirZ)
    				wp.angle = deg(wp.rotY)

    				local dy = np.y - wp.y
    				local dist2D = MathUtil.vector2Length(np.x - wp.x, np.z - wp.z)
    				wp.rotX = -MathUtil.getYRotationFromDirection(dy, dist2D)
    			else
    				local pp = waypoints[i - 1]
					if pp then
						wp.dirX, wp.dirY, wp.dirZ, wp.distToNextPoint = pp.dirX, pp.dirY, pp.dirZ, 0
						wp.rotX = 0
						wp.rotY = pp.rotY
					end
    			end

    			local diamondColor = 'regular'
    			if wp.turnStart then
    				diamondColor = 'turnStart'
    			elseif wp.turnEnd then
    				diamondColor = 'turnEnd'
    			end

    			local existingSignData = self.courses[vehicle].current[i]
    			if existingSignData ~= nil then
    				if existingSignData.type == neededSignType then
    					self:setTranslation(existingSignData.sign, existingSignData.type, wp.x, wp.z)
    					if wp.rotX and wp.rotY then
    						setRotation(existingSignData.sign, wp.rotX, wp.rotY, 0)
    						if neededSignType == 'normal' or neededSignType == 'start' or neededSignType == 'wait' or neededSignType == 'unload' then
    							if neededSignType == 'start' or neededSignType == 'wait' or neededSignType == 'unload' then
    								local signPart = getChildAt(existingSignData.sign, 1)
    								setRotation(signPart, -wp.rotX, 0, 0)
    							end
    							self:setWaypointSignLine(existingSignData.sign, wp.distToNextPoint, true)
    						end
    						if neededSignType ~= 'cross' then
    							self:setSignColor(existingSignData, diamondColor)
    						end
    					end
    				else
    					self:moveToBuffer(vehicle, i, existingSignData)
    					self:addSign(vehicle, neededSignType, wp.x, wp.z, deg(wp.rotX), wp.angle, i, wp.distToNextPoint, diamondColor)
    				end
    			else
    				self:addSign(vehicle, neededSignType, wp.x, wp.z, deg(wp.rotX), wp.angle, i, wp.distToNextPoint, diamondColor)
    			end
    		end
		end
	end

	self:setSignsVisibility(vehicle)
end

function CourseDisplay:setSignColor(signData, colorName)
	if signData.type ~= 'cross' and (signData.color == nil or signData.color ~= colorName) then
		local x,y,z,w = unpack(waypointColors[colorName])
		-- print(('setSignColor (%q): sign=%s, x=%.3f, y=%.3f, z=%.3f, w=%d'):format(colorName, tostring(signData.sign), x, y, z, w))
		setShaderParameter(signData.sign, 'shapeColor', x,y,z,w, false)
		signData.color = colorName
	end
end


function CourseDisplay:deleteSign(sign)
	unlink(sign)
	delete(sign)
end

function CourseDisplay:setSignsVisibility(vehicle, forceHide)
	if self.courses[vehicle] == nil or (#self.courses[vehicle].current == 0 and #self.courses[vehicle].crossing == 0) then
		return
	end
	local numSigns = #self.courses[vehicle].current

	local showVisualWaypointsState = vehicle:getCpSettingValue(CpVehicleSettings.showCourse)

	local vis, isStartEndPoint
	for k,signData in pairs(self.courses[vehicle].current) do
		vis = false
		isStartEndPoint = k <= 2 or k >= (numSigns - 2)

		if (signData.type == 'wait' or signData.type == 'unload') and showVisualWaypointsState>=CpVehicleSettings.SHOW_COURSE_START_STOP then
			vis = true
			local line = getChildAt(signData.sign, 0)
			if showVisualWaypointsState==CpVehicleSettings.SHOW_COURSE_START_STOP then
				setVisibility(line, isStartEndPoint)
			else
				setVisibility(line, true)
			end
		else
			if showVisualWaypointsState==CpVehicleSettings.SHOW_COURSE_ALL then
				vis = true
			elseif showVisualWaypointsState>=CpVehicleSettings.SHOW_COURSE_START_STOP and isStartEndPoint then
				vis = true
			end
		end

		-- TODO_22
		--if vehicle.cp.isRecording then
		--	vis = true
		--elseif forceHide or not vehicle:getIsEntered() then
		--	vis = false
		--end

		setVisibility(signData.sign, vis)
	end

	for _,signData in pairs(self.courses[vehicle].crossing) do
		-- TODO_22
		local vis = true
		--local vis = vehicle.cp.settings.showVisualWaypointsCrossPoint:get()
		if forceHide or not vehicle:getIsEntered() then
			vis = false
		end

		setVisibility(signData.sign, vis)
	end
end

-- legacy function that seems to remove the last element of t1 and append it to t2
-- the original author, as usual, did not bother explaining the purpose
function CourseDisplay:tableMove(t1, t2, t1_index, t2_index)
	t1_index = t1_index or (#t1)
	t2_index = t2_index or (#t2 + 1)
	if t1[t1_index] == nil then
		return false
	end

	t2[t2_index] = t1[t1_index]
	table.remove(t1, t1_index)
	return t2[t2_index] ~= nil
end

-- Recreate if already exists. This is only for development to recreate the global instance if this
-- file is reloaded while the game is running
if g_courseDisplay then
	g_courseDisplay:delete()
	g_courseDisplay = CourseDisplay()
end
