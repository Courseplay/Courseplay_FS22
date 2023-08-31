--[[
	This specialization is used to control the shovel position into 4 stages:
		- Loading position 0.2m above the ground.
		- Transport position 
		- Pre unloading position
		- Unloading position

	TODO: 
		- Fine tuning
		- Testing from different front loaders ...
		- Add Telescopic handlers support.
]]--

---@class CpShovelPositions
CpShovelPositions = {
	DEACTIVATED = 0,
	LOADING = 1,
	TRANSPORT = 2,
	PRE_UNLOAD = 3,
	UNLOADING = 4,
	NUM_STATES = 4,
	LOADING_POSITION = {
		ARM_LIMITS = {
			0,
			0.1
		},
		SHOVEL_LIMITS = {
			88,
			92
		},
	},
	TRANSPORT_POSITION = {
		ARM_LIMITS = {
			0.1,
			0.20
		},
		SHOVEL_LIMITS = {
			53,
			57
		},
	},
	PRE_UNLOAD_POSITION = {
		ARM_LIMITS = {
			2.7,
			2.8
		},
		SHOVEL_LIMITS = {
			43,
			47
		},
	},
	DEBUG = true
}
CpShovelPositions.MOD_NAME = g_currentModName
CpShovelPositions.NAME = ".cpShovelPositions"
CpShovelPositions.SPEC_NAME = CpShovelPositions.MOD_NAME .. CpShovelPositions.NAME
CpShovelPositions.KEY = "." .. CpShovelPositions.SPEC_NAME

function CpShovelPositions.initSpecialization()
    local schema = Vehicle.xmlSchemaSavegame
	g_devHelper.consoleCommands:registerConsoleCommand("cpShovelPositionsPrintShovelDebug", 
        "Prints debug information for the shovel", 
        "consoleCommandPrintShovelDebug", CpShovelPositions)
	g_devHelper.consoleCommands:registerConsoleCommand("cpShovelPositionsSetState", 
        "Set's the current shovel state", 
        "consoleCommandSetShovelState", CpShovelPositions)
	g_devHelper.consoleCommands:registerConsoleCommand("cpShovelPositionsSetArmLimit", 
        "Set's the arm max limit", 
        "consoleCommandSetPreUnloadArmLimit", CpShovelPositions)
	g_devHelper.consoleCommands:registerConsoleCommand('cpShovelPositionsSetMinimalUnloadHeight', 
		'cpSetShovelSetMinimalUnloadHeight',
		'consoleCommandSetMinimalUnloadHeight', CpShovelPositions)
end

function CpShovelPositions.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(Shovel, specializations) and not 
		SpecializationUtil.hasSpecialization(Trailer, specializations) and not 
		SpecializationUtil.hasSpecialization(ConveyorBelt, specializations)
end

function CpShovelPositions.register(typeManager, typeName, specializations)
	if CpShovelPositions.prerequisitesPresent(specializations) then
		typeManager:addSpecialization(typeName, CpShovelPositions.SPEC_NAME)
	end
end

function CpShovelPositions.registerEventListeners(vehicleType)	
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", CpShovelPositions)
	SpecializationUtil.registerEventListener(vehicleType, "onDraw", CpShovelPositions)	
	SpecializationUtil.registerEventListener(vehicleType, "onUpdateTick", CpShovelPositions)
	SpecializationUtil.registerEventListener(vehicleType, "onPostAttach", CpShovelPositions)
end

function CpShovelPositions.registerFunctions(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, "cpSetShovelState", CpShovelPositions.cpSetShovelState)
    SpecializationUtil.registerFunction(vehicleType, "cpResetShovelState", CpShovelPositions.cpResetShovelState)
	SpecializationUtil.registerFunction(vehicleType, "cpSetupShovelPositions", CpShovelPositions.cpSetupShovelPositions)
	SpecializationUtil.registerFunction(vehicleType, "areCpShovelPositionsDirty", CpShovelPositions.areCpShovelPositionsDirty)
	SpecializationUtil.registerFunction(vehicleType, "setCpShovelMinimalUnloadHeight", CpShovelPositions.setCpShovelMinimalUnloadHeight)
end

--------------------------------------------
--- Console Commands
--------------------------------------------

local function executeConsoleCommand(func, ...)
	local vehicle = g_currentMission.controlledVehicle
	if not vehicle then 
		CpUtil.info("Not entered a valid vehicle!")
		return false
	end
	-- if vehicle:getIsAIActive() then 
	-- 	CpUtil.infoVehicle(vehicle, "Error, AI is active!")
	-- 	return false
	-- end
	local shovels, found = AIUtil.getAllChildVehiclesWithSpecialization(vehicle, Shovel)
	if not found then 
		CpUtil.infoVehicle(vehicle, "No shovel implement found!")
		return false
	end
	return func(shovels[1], ...)
end

function CpShovelPositions:consoleCommandSetShovelState(state)
	return executeConsoleCommand(function(shovelImplement, state)
		state = tonumber(state)
		if state == nil or state < 0 or state > CpShovelPositions.NUM_STATES then 
			CpUtil.infoVehicle(shovelImplement, "No valid state(0 - %d) was given!", CpShovelPositions.NUM_STATES)
			return false
		end
		shovelImplement:cpSetShovelState(state)
	end, state)
end

function CpShovelPositions:consoleCommandSetPreUnloadArmLimit(min, max)
	return executeConsoleCommand(function(shovelImplement, min, max)
		min = tonumber(min)
		max = tonumber(max)
		if min == nil or max == nil then 
			CpUtil.infoVehicle(shovelImplement, "No valid limits given! min: %s, max: %s", tostring(min), tostring(max))
			return false
		end
		CpShovelPositions.PRE_UNLOAD_POSITION.ARM_LIMITS = { min, max }
	end, min, max)
end

function CpShovelPositions:consoleCommandPrintShovelDebug(cylinderedDepth)
	return executeConsoleCommand(function(shovelImplement)
		--- Position debug
		CpUtil.infoImplement(shovelImplement, "-- Position debug --")
		local spec = shovelImplement.spec_cpShovelPositions
		if spec then 
			CpUtil.infoImplement(shovelImplement, " arm tool %s -> %s", 
				CpUtil.getName(spec.armVehicle), tostring(spec.armToolIx))
			CpUtil.infoImplement(shovelImplement, " shovel tool %s -> %s", 
				CpUtil.getName(spec.shovelVehicle), tostring(spec.shovelToolIx))
			local highDumpShovelIx = g_vehicleConfigurations:get(shovelImplement, "shovelMovingToolIx")	
			CpUtil.infoImplement(shovelImplement, " shovel high dump %s -> %s", 
				CpUtil.getName(shovelImplement), tostring(highDumpShovelIx))
		end

		CpUtil.infoImplement(shovelImplement, "-- Position debug --")
		--- Shovel debug
		local controller = ShovelController(shovelImplement.rootVehicle, shovelImplement, true)
		controller:printShovelDebug()
		controller:delete()
		--- Cylindered debug here
		CpUtil.infoImplement(shovelImplement, "-- Cylindered debug --")
		cylinderedDepth = cylinderedDepth and tonumber(cylinderedDepth) or 0

		local childVehicles = shovelImplement.rootVehicle:getChildVehicles()
		for _, vehicle in ipairs(childVehicles) do
			if vehicle.spec_cylindered then
				for ix, tool in pairs(vehicle.spec_cylindered.movingTools) do
					CpUtil.infoImplement(shovelImplement, " %s => ix: %d ",
						CpUtil.getName(vehicle), ix)
					if cylinderedDepth > 0 then
						CpUtil.infoImplement(shovelImplement, " %s", 
							DebugUtil.debugTableToString(tool, "   ", 0, cylinderedDepth))
					end
					CpUtil.infoImplement(shovelImplement, " %s => ix: %d finished", 
						CpUtil.getName(vehicle), ix)
				end
			end
		end
		CpUtil.infoImplement(shovelImplement, "-- Cylindered debug finished --")
	end)
end

function CpShovelPositions:consoleCommandSetMinimalUnloadHeight(height)
	return executeConsoleCommand(function(shovelImplement, height)
		height = tonumber(height)
		if height == nil then 
			CpUtil.infoVehicle(shovelImplement, "No valid height given! height: %s", tostring(height))
			return false
		end
		local spec = shovelImplement.spec_cpShovelPositions
		spec.minimalShovelUnloadHeight = height
	end, height)
end

--------------------------------------------
--- Event Listener
--------------------------------------------

function CpShovelPositions:onLoad(savegame)
	--- Register the spec: spec_ShovelPositions
    self.spec_cpShovelPositions = self["spec_" .. CpShovelPositions.SPEC_NAME]
    local spec = self.spec_cpShovelPositions
	--- Current shovel state.
	spec.state = CpShovelPositions.DEACTIVATED
	spec.isDirty = false
	spec.minimalShovelUnloadHeight = 4
end

function CpShovelPositions:onPostAttach()
	if self.spec_cpShovelPositions then
		CpShovelPositions.cpSetupShovelPositions(self)
	end
end

function CpShovelPositions:onDraw()
	if CpShovelPositions.DEBUG and self:getRootVehicle() then 
		local angle, shovelNode, maxAngle, minAngle, factor = CpShovelPositions.getShovelData(self)
		if shovelNode then
			DebugUtil.drawDebugNode(shovelNode, "shovelNode")
		end
	end
end

function CpShovelPositions:onUpdateTick(dt)
	local spec = self.spec_cpShovelPositions
	if spec.shovelToolIx == nil or spec.armToolIx == nil or self.rootVehicle == nil then 
		return
	end
	if spec.state == CpShovelPositions.LOADING then 
		CpShovelPositions.updateLoadingPosition(self, dt)
	elseif spec.state == CpShovelPositions.TRANSPORT then 
		CpShovelPositions.updateTransportPosition(self, dt)
	elseif spec.state == CpShovelPositions.PRE_UNLOAD then 
		CpShovelPositions.updatePreUnloadPosition(self, dt)
	elseif spec.state == CpShovelPositions.UNLOADING then 
		CpShovelPositions.updateUnloadingPosition(self, dt)
	end
end

--- Changes the current shovel state position.
function CpShovelPositions:cpSetShovelState(state)
	local spec = self.spec_cpShovelPositions
	if spec.state ~= state then
		spec.state = state
		if state == CpShovelPositions.DEACTIVATED then 
			ImplementUtil.stopMovingTool(spec.armVehicle, spec.armTool)
			ImplementUtil.stopMovingTool(spec.shovelVehicle, spec.shovelTool)
		end
	end
end

--- Deactivates the shovel position control.
function CpShovelPositions:cpResetShovelState()
	CpShovelPositions.debug(self, "Reset shovelPositionState.")
	local spec = self.spec_cpShovelPositions
	spec.state = CpShovelPositions.DEACTIVATED
	ImplementUtil.stopMovingTool(spec.armVehicle, spec.armTool)
	ImplementUtil.stopMovingTool(spec.shovelVehicle, spec.shovelTool)
end

--- Is the current target shovel position not yet reached?
function CpShovelPositions:areCpShovelPositionsDirty()
	local spec = self.spec_cpShovelPositions
	return spec.isDirty
end

--- Sets the relevant moving tools.
function CpShovelPositions:cpSetupShovelPositions()
	local spec = self.spec_cpShovelPositions
	spec.shovelToolIx = nil
	spec.armToolIx = nil
	spec.shovelTool = nil
	spec.armTool = nil
	local rootVehicle = self:getRootVehicle()
	local childVehicles = rootVehicle:getChildVehicles()
	for _, vehicle in ipairs(childVehicles) do
		if vehicle.spec_cylindered then
			for i, tool in pairs(vehicle.spec_cylindered.movingTools) do
				if tool.controlGroupIndex ~= nil then 
					if tool.axis == "AXIS_FRONTLOADER_ARM" then 
						spec.armToolIx = i
						spec.armTool = tool
						spec.armVehicle = vehicle
						spec.armProjectionNode = CpUtil.createNode("CpShovelArmProjectionNode", 
							0, 0, 0, vehicle.rootNode)
						spec.armToolRefNode = CpUtil.createNode("CpShovelArmToolRefNode", 
							0, 0, 0, vehicle.rootNode)
					elseif tool.axis == "AXIS_FRONTLOADER_TOOL" then 
						spec.shovelToolIx = i
						spec.shovelTool = tool
						spec.shovelVehicle = vehicle
					elseif tool.axis == "AXIS_FRONTLOADER_ARM2" then 
						spec.armExtendToolIx = i
						spec.armExtendTool = tool
						spec.armExtendVehicle = vehicle
					end
				end
			end
		end
	end
end

--- Sets the current shovel position values, like the arm and shovel rotations.
---@param dt number
---@param shovelLimits table
---@param armLimits table
---@param isLoading boolean|nil
---@param heightOffset number|nil
---@param isUnloading boolean|nil
---@return boolean|nil
function CpShovelPositions:setShovelPosition(dt, shovelLimits, armLimits, 
	isLoading, heightOffset, isUnloading)
	heightOffset = heightOffset or 0
	local min, max = unpack(shovelLimits)
	--- Target angle of the shovel node, which is at the end of the shovel.
	local targetAngle = math.rad(min) + math.rad(max - min)/2
	min, max = unpack(armLimits)
	--- Target height of the arm.
	--- This is relative to the attacher joint of the shovel.
	local targetHeight = min + (max - min)/2
	local shovelTool = self.spec_cpShovelPositions.shovelTool
	local armTool = self.spec_cpShovelPositions.armTool
	local shovelVehicle = self.spec_cpShovelPositions.shovelVehicle
	local armVehicle = self.spec_cpShovelPositions.armVehicle
	local minimalTargetHeight = self.spec_cpShovelPositions.minimalShovelUnloadHeight
	local curRot = {}
	curRot[1], curRot[2], curRot[3] = getRotation(shovelTool.node)
	local oldShovelRot = curRot[shovelTool.rotationAxis]

	curRot = {}
	curRot[1], curRot[2], curRot[3] = getRotation(armTool.node)
	local oldArmRot = curRot[armTool.rotationAxis]

	local armProjectionNode = self.spec_cpShovelPositions.armProjectionNode
	local armToolRefNode = self.spec_cpShovelPositions.armToolRefNode

	local radiusArmToolToShovelTool = calcDistanceFrom(shovelTool.node, armTool.node)
	
	local attacherJointNode = self.spec_attachable.attacherJoint.node
	local angle, shovelNode = CpShovelPositions.getShovelData(self)
	--local _, shovelY, _ = localToLocal(self.rootNode, attacherJointNode, 0, 0, 0)
	local _, shovelY, _ = localToLocal(armVehicle.rootNode, shovelVehicle.rootNode, 0, 0, 0)
	
	--- All values will be calculated in the coordinate system from the vehicle root node.

	local _, ty, tz = localToLocal(getChildAt(armTool.node, 0), armVehicle.rootNode, 0, 0, 0)
	local ax, ay, az = localToLocal(armTool.node, armVehicle.rootNode, 0, 0, 0)
	local wx, _, wz = getWorldTranslation(armVehicle.rootNode)
	local deltaY = 0
	if isUnloading then
		deltaY = minimalTargetHeight - ay
	end
	local by = shovelY
	if self.spec_foliageBending and self.spec_foliageBending.bendingNodes[1] then 
		local bending = self.spec_foliageBending.bendingNodes[1]
		if bending.id ~= nil and bending.node ~= nil then 
			local sx, _, sz = localToWorld(shovelTool.node, 0, 0, 0)
			local bx1, by1, bz1 = localToWorld(bending.node, 0, 0, bending.minZ)
			local bx2, by2, bz2 = localToWorld(bending.node, 0, 0, bending.maxZ)
			DebugUtil.drawDebugLine(bx1, by1, bz1, bx2, by2, bz2, 0, 0, 1)
			if by1 < by2 then 
				_, by, _ = worldToLocal(shovelTool.node, sx, by1, sz)
				DebugUtil.drawDebugLine(sx, by1, sz, sx, by1 - by, sz, 0, 0, 1)
			else 
				_, by, _ = worldToLocal(shovelTool.node, sx, by2, sz)
				DebugUtil.drawDebugLine(sx, by2, sz, sx, by2 - by, sz, 0, 0, 1)
			end
		end
	else 
		local bx1, by1, bz1 = localToWorld(self.rootNode, 0, 0, self.size.lengthOffset + self.size.length/2)
		local bx2, by2, bz2 = localToWorld(self.rootNode, 0, 0, self.size.lengthOffset - self.size.length/2)
		DebugUtil.drawDebugLine(bx1, by1, bz1, bx2, by2, bz2, 0, 0, 1)
		local sx, _, sz = localToWorld(shovelTool.node, 0, 0, 0)
		if by1 < by2 then 
			_, by, _ = worldToLocal(shovelTool.node, sx, by1, sz)
		else 
			_, by, _ = worldToLocal(shovelTool.node, sx, by2, sz)
		end
	end

	local sx, sy, sz = 0, -by + targetHeight + heightOffset + deltaY, 0
	local ex, ey, ez = 0, -by + targetHeight + heightOffset + deltaY, 20
	local wsx, wsy, wsz = localToWorld(armVehicle.rootNode, sx, sy, sz)
	local wex, wey, wez = localToWorld(armVehicle.rootNode, ex, ey, ez)
	local terrainHeight = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, wsx, 0, wsz)

	local yMax = ay + radiusArmToolToShovelTool
	local yMin = ay - radiusArmToolToShovelTool
	if sy > yMax then 
		--- Makes sure the target height is still reachable
		sy = yMax - 0.01
		ey = yMax - 0.01
	end
	if sy < yMin then 
		--- Makes sure the target height is still reachable
		sy = yMin + 0.01
		ey = yMin + 0.01
	end
	local hasIntersection, i1z, i1y, i2z, i2y = MathUtil.getCircleLineIntersection(
		az, ay, radiusArmToolToShovelTool,
		sz, sy, ez, ey)
	
	local isDirty, alpha, oldRotRelativeArmRot
	if hasIntersection then
		--- Controls the arm height
		setTranslation(armProjectionNode, 0, i1y, i1z)
		setTranslation(armToolRefNode, ax, ay, az)
		local _, shy, shz = localToLocal(shovelTool.node, armVehicle.rootNode, 0, 0, 0)
		local dirZ, dirY = MathUtil.vector2Normalize(shz - az, shy - ay)
		oldRotRelativeArmRot = MathUtil.getYRotationFromDirection(-dirZ, dirY) + math.pi/2

		alpha = math.atan2(i1y - ay, i1z - az)
		local beta = -math.atan2(i2y - ay, i2z - az)
		local angle = MathUtil.clamp(oldArmRot - MathUtil.getAngleDifference(
			alpha, oldRotRelativeArmRot), armTool.rotMin, armTool.rotMax)
		isDirty = ImplementUtil.moveMovingToolToRotation(
			armVehicle, armTool, dt, angle)
	end

	--- Controls the arm extension


	local highDumpShovelTool
	local highDumpShovelIx = g_vehicleConfigurations:get(self, "shovelMovingToolIx")
	if highDumpShovelIx ~= nil then 
		highDumpShovelTool = self.spec_cylindered.movingTools[highDumpShovelIx]
		if isUnloading then
			--- Makes sure the shovel is almost vertical for the high dump functionality
			local _, dy, _ = localDirectionToWorld(getParent(highDumpShovelTool.node), 0, 0, 1)
			angle = math.acos(dy)
			targetAngle = math.pi/2 - math.pi/6
		else 
			isDirty = ImplementUtil.moveMovingToolToRotation(self, highDumpShovelTool, dt,
				highDumpShovelTool.invertAxis and highDumpShovelTool.rotMax or highDumpShovelTool.rotMin) or isDirty
		end
	else
		local shovelData = ImplementUtil.getShovelNode(self)
		if shovelData.movingToolActivation then
			--- The shovel has a moving tool for grabbing.
			for i, tool in pairs(self.spec_cylindered.movingTools) do 
				if tool.axis then 
					if isLoading or isUnloading then 
						--- Opens the shovel for loading and unloading
						isDirty = ImplementUtil.moveMovingToolToRotation(self, tool, dt,
							tool.invertAxis and tool.rotMin or tool.rotMax) or isDirty
					else 
						--- Closes the shovel after loading
						isDirty = ImplementUtil.moveMovingToolToRotation(self, tool, dt,
							tool.invertAxis and tool.rotMax or tool.rotMin) or isDirty
					end
					break
				end
			end
		end
	end
	local deltaAngle = targetAngle - angle
	local goalAngle = MathUtil.clamp(oldShovelRot + deltaAngle, shovelTool.rotMin, shovelTool.rotMax)
	isDirty = ImplementUtil.moveMovingToolToRotation(shovelVehicle, 
		shovelTool, dt, goalAngle) or isDirty
	if isUnloading and highDumpShovelTool then
		--- Uses the high dump shovel functionality.
		isDirty = isDirty or ImplementUtil.moveMovingToolToRotation(self, highDumpShovelTool, dt,
				highDumpShovelTool.invertAxis and highDumpShovelTool.rotMin or highDumpShovelTool.rotMax)
	end
	--- Debug information
	if g_currentMission.controlledVehicle == shovelVehicle.rootVehicle and 
		CpDebug:isChannelActive(CpDebug.DBG_SILO, shovelVehicle.rootVehicle) then 
		DebugUtil.drawDebugLine(wsx, wsy, wsz, wex, wey, wez)
		DebugUtil.drawDebugLine(wsx, terrainHeight + minimalTargetHeight , wsz, 
			wex, terrainHeight + minimalTargetHeight, wez, 0, 0, 1)
		DebugUtil.drawDebugCircleAtNode(armVehicle.rootNode, radiusArmToolToShovelTool, 
			30, nil, true, {ax, ay, az})
		CpUtil.drawDebugNode(armVehicle.rootNode)
		CpUtil.drawDebugNode(armTool.node)
		CpUtil.drawDebugNode(shovelTool.node)
		CpUtil.drawDebugNode(armProjectionNode)
		CpUtil.drawDebugNode(armToolRefNode)

		local debugData = {}
		if hasIntersection then	
			table.insert(debugData, {
				value = "",
				name = "Arm Rotation:" })
			table.insert(debugData, { 
				name = "alpha", value = math.deg(alpha) })
			table.insert(debugData, { 
				name = "deltaAlphaOld", value = math.deg(MathUtil.getAngleDifference(alpha, oldArmRot)) })
			table.insert(debugData, { 
				name = "old", value = math.deg(oldArmRot) })
			table.insert(debugData, {
				name = "deltaAlpha", value = math.deg(MathUtil.getAngleDifference(alpha, oldRotRelativeArmRot)) })
			table.insert(debugData, {
				name = "deltaY", value = deltaY})
			table.insert(debugData, {
				name = "shovelY", value = shovelY})
			table.insert(debugData, {
				name = "dirRot", value = math.deg(oldRotRelativeArmRot) })
			table.insert(debugData, {
				name = "distAlpha", value = MathUtil.vector2Length(i1z - tz, i1y - ty) })

			table.insert(debugData, {
				value = "",
				name = "",
				columnOffset = 0.12
			})
		end
		table.insert(debugData, {
			value = "",
			name = "Shovel Rotation:" })
		table.insert(debugData, { 
			name = "angle", value = math.deg(angle) })
		table.insert(debugData, { 
			name = "deltaAngle", value = math.deg(deltaAngle) })	
		table.insert(debugData, { 
			name = "targetAngle", value = math.deg(targetAngle) })	
		table.insert(debugData, {
			value = "",
			name = "Diff:" })
		table.insert(debugData, { 
			name = "unload height", value = minimalTargetHeight })		

		DebugUtil.renderTable(0.4, 0.4, 0.018, 
			debugData, 0)

		if self.spec_foliageBending ~= nil then
			local offset = 0.25
	
			for _, bendingNode in ipairs(self.spec_foliageBending.bendingNodes) do
				if bendingNode.id ~= nil then
					DebugUtil.drawDebugRectangle(bendingNode.node, bendingNode.minX, bendingNode.maxX, bendingNode.minZ, bendingNode.maxZ, bendingNode.yOffset, 1, 0, 0)
					DebugUtil.drawDebugRectangle(bendingNode.node, bendingNode.minX - offset, bendingNode.maxX + offset, bendingNode.minZ - offset, bendingNode.maxZ + offset, bendingNode.yOffset, 0, 1, 0)
					DebugUtil.drawDebugNode(bendingNode.node, "Bending node")
				end	
			end
		end


	end
	return isDirty
end

function CpShovelPositions:updateLoadingPosition(dt)
	local spec = self.spec_cpShovelPositions
	local angle = CpShovelPositions.getShovelData(self)
	local heightOffset = self.rootVehicle.getCpSettings and self.rootVehicle:getCpSettings().loadingShovelHeightOffset:getValue()
	local isDirty
	if angle then 
		isDirty = CpShovelPositions.setShovelPosition(self, dt, 
			CpShovelPositions.LOADING_POSITION.SHOVEL_LIMITS, 
			CpShovelPositions.LOADING_POSITION.ARM_LIMITS, 
			true, heightOffset)
	end
	spec.isDirty = isDirty
end

function CpShovelPositions:updateTransportPosition(dt)
	local spec = self.spec_cpShovelPositions
	local angle = CpShovelPositions.getShovelData(self)
	local heightOffset = self.rootVehicle.getCpSettings and self.rootVehicle:getCpSettings().loadingShovelHeightOffset:getValue()
	local isDirty
	if angle then 
		isDirty = CpShovelPositions.setShovelPosition(self, dt, 
			CpShovelPositions.TRANSPORT_POSITION.SHOVEL_LIMITS, 
			CpShovelPositions.TRANSPORT_POSITION.ARM_LIMITS, 
			false, heightOffset)
	end
	spec.isDirty = isDirty
end

function CpShovelPositions:updatePreUnloadPosition(dt)
	local spec = self.spec_cpShovelPositions
	local angle = CpShovelPositions.getShovelData(self)
	local isDirty
	if angle then
		isDirty = CpShovelPositions.setShovelPosition(self, dt, 
			CpShovelPositions.PRE_UNLOAD_POSITION.SHOVEL_LIMITS, 
			CpShovelPositions.PRE_UNLOAD_POSITION.ARM_LIMITS,
			false, nil) 
	end
	spec.isDirty = isDirty
end

function CpShovelPositions:updateUnloadingPosition(dt)
	local spec = self.spec_cpShovelPositions
	local angle, _, maxAngle = CpShovelPositions.getShovelData(self)
	local isDirty
	if angle and maxAngle then 
		isDirty = CpShovelPositions.setShovelPosition(self, dt, 
		{math.deg(maxAngle), math.deg(maxAngle) + 2}, 
		CpShovelPositions.PRE_UNLOAD_POSITION.ARM_LIMITS, false, 
		nil, true)
	end
	spec.isDirty = isDirty
end

function CpShovelPositions:setCpShovelMinimalUnloadHeight(height)
	local spec = self.spec_cpShovelPositions
	spec.minimalShovelUnloadHeight = height
end

--- Gets all relevant shovel data.
function CpShovelPositions:getShovelData()
	local shovelSpec = self.spec_shovel
	local info = shovelSpec.shovelDischargeInfo
    if info == nil or info.node == nil then 
		CpShovelPositions.debug(self, "Info or node not found!")
		return 
	end
    if info.maxSpeedAngle == nil or info.minSpeedAngle == nil then
		CpShovelPositions.debug(self, "maxSpeedAngle or minSpeedAngle not found!")
		return 
	end
	if shovelSpec.shovelNodes[1] == nil then 
		CpShovelPositions.debug(self, "Shovel nodes index 0 not found!")
		return 
	end
	local _, dy, _ = localDirectionToWorld(info.node, 0, 0, 1)
	local angle = math.acos(dy)
	local factor = math.max(0, math.min(1, (angle - info.minSpeedAngle) / (info.maxSpeedAngle - info.minSpeedAngle)))
	return angle, shovelSpec.shovelNodes[1].node, info.maxSpeedAngle, info.minSpeedAngle, factor
end

function CpShovelPositions.debug(implement, ...)
	if CpShovelPositions.DEBUG then
		CpUtil.infoImplement(implement, ...)
	end
end