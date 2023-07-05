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
			3,
			4
		},
		SHOVEL_LIMITS = {
			43,
			47
		},
	},
	UNLOADING_POSITION = {
		ARM_LIMITS = {
			4,
			5
		},
	},
	DEBUG = false
}
CpShovelPositions.MOD_NAME = g_currentModName
CpShovelPositions.NAME = ".cpShovelPositions"
CpShovelPositions.SPEC_NAME = CpShovelPositions.MOD_NAME .. CpShovelPositions.NAME
CpShovelPositions.KEY = "." .. CpShovelPositions.SPEC_NAME

function CpShovelPositions.initSpecialization()
    local schema = Vehicle.xmlSchemaSavegame
	if CpShovelPositions.DEBUG then 
		g_devHelper.consoleCommands:registerConsoleCommand('cpSetShovelState', 'cpSetShovelState', 'consoleCommandSetShovelState', CpShovelPositions)
	end
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
	SpecializationUtil.registerFunction(vehicleType, "getCpShovelUnloadingPositionHeight", CpShovelPositions.getCpShovelUnloadingPositionHeight)
end


function CpShovelPositions:onLoad(savegame)
	--- Register the spec: spec_ShovelPositions
    self.spec_cpShovelPositions = self["spec_" .. CpShovelPositions.SPEC_NAME]
    local spec = self.spec_cpShovelPositions
	--- Current shovel state.
	spec.state = CpShovelPositions.DEACTIVATED
	spec.isDirty = false
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

function CpShovelPositions:consoleCommandSetShovelState(state)
	local vehicle = g_currentMission.controlledVehicle
	if not vehicle then 
		CpUtil.info("Not entered a valid vehicle!")
	end
	state = tonumber(state)
	if state == nil or state < 0 or state > CpShovelPositions.NUM_STATES then 
		CpUtil.infoVehicle(vehicle, "No valid state(0 - %d) was given!", CpShovelPositions.NUM_STATES)
		return
	end
	if not vehicle:getIsAIActive() then 
		local shovels, found = AIUtil.getAllChildVehiclesWithSpecialization(vehicle, Shovel)
		if found then 
			shovels[1]:cpSetShovelState(state)
		else 
			CpUtil.infoVehicle(vehicle, "No valid vehicle/implement with a shovel was found!")
		end
	else 
		CpUtil.infoVehicle(vehicle, "Error, AI is active!")
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
							0, 0, 0, getParent(tool.node))
					elseif tool.axis == "AXIS_FRONTLOADER_TOOL" then 
						spec.shovelToolIx = i
						spec.shovelTool = tool
						spec.shovelVehicle = vehicle
						spec.shovelProjectionNode = CpUtil.createNode("CpShovelProjectionNode", 
							0, 0, 0, getParent(tool.node))
					end
				end
			end
		end
	end
end

function CpShovelPositions:onUpdateTick(dt)
	local spec = self.spec_cpShovelPositions
	if spec.shovelToolIx == nil or  spec.armToolIx == nil then 
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

--- Changes the shovel angle dependent on the selected position.
function CpShovelPositions.setShovelPosition(dt, spec, shovel, shovelNode, angle, limits)
	local min, max = unpack(limits)
	local targetAngle = math.rad(min) + math.rad(max - min)/2
	if math.deg(angle) < max and  math.deg(angle) > min  then 
		ImplementUtil.stopMovingTool(spec.shovelVehicle, spec.shovelTool)
		return false
	end
	

	local curRot = {}
	curRot[1], curRot[2], curRot[3] = getRotation(spec.shovelTool.node)
	local oldRot = curRot[spec.shovelTool.rotationAxis]
	local radius = calcDistanceFrom(shovelNode, spec.shovelTool.node)
	local x, y, z = getTranslation(spec.shovelTool.node)

	setTranslation(spec.shovelProjectionNode, x, y, z)

	setRotation(spec.shovelProjectionNode, targetAngle - math.pi/2, 0, 0)

	local sx, sy, sz = getWorldTranslation(shovelNode)
	local tx, _, tz = getWorldTranslation(spec.shovelTool.node)
	local px, py, pz = localToWorld(spec.shovelProjectionNode, 0, 0, radius)
	
	if CpShovelPositions.DEBUG then
		DebugUtil.drawDebugCircleAtNode(spec.shovelTool.node, radius, 30, nil, true)

		DebugUtil.drawDebugLine(px, py, pz, sx, sy, sz)
		DebugUtil.drawDebugLine(px, py, pz, tx, py, tz)
	end

	local yRot = math.atan2(MathUtil.vector3Length(px - sx, py - sy, pz - sz),
	MathUtil.vector3Length(px - tx, py - py, pz - tz))

	local dyRot = 0
	if angle > targetAngle then 
		dyRot = -yRot
	else 
		dyRot = yRot
	end
	
	CpShovelPositions.debug(shovel, 
		"Shovel position(%d) angle: %.2f, targetAngle: %.2f, yRot: %.2f, oldRot: %.2f", 
		spec.state, math.deg(angle), math.deg(targetAngle), math.deg(dyRot), math.deg(oldRot)) 

	return ImplementUtil.moveMovingToolToRotation(spec.shovelVehicle, spec.shovelTool, dt, 
		MathUtil.clamp(oldRot + dyRot , spec.shovelTool.rotMin, spec.shovelTool.rotMax))
end

--- Changes the front loader angle dependent on the selected position, relative to a target height.
function CpShovelPositions.setArmPosition(dt, spec, shovel, shovelNode, limits)
	--- Interval in which the shovel height should be in.
	local min, max = unpack(limits)
	local targetHeight = min + (max - min)/2
	
	local attacherJointNode = shovel.spec_attachable.attacherJoint.node
	local _, shovelY, shovelR = localToLocal(attacherJointNode, shovelNode, 0, 0, 0)
	
	local x, y, z = getWorldTranslation(attacherJointNode)
	local dy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 0, z)
	
	local targetAttacherHeight = dy + shovelY + targetHeight 
	local diff = targetAttacherHeight - y

	CpShovelPositions.debug(shovel, "shovel => y: %.2f, z: %.2f, targetAttacherHeight: %.2f", shovelY, shovelR, targetAttacherHeight)

	if math.abs(diff) < (max - min)/2 then 
		ImplementUtil.stopMovingTool(spec.armVehicle, spec.armTool)
		return false
	end

	local curRot = {}
	curRot[1], curRot[2], curRot[3] = getRotation(spec.armTool.node)
	local oldRot = curRot[spec.armTool.rotationAxis]
	

	setWorldTranslation(spec.armProjectionNode, x, targetAttacherHeight, z)


	local _, ay, _ = localToLocal(spec.armTool.node, spec.armVehicle.rootNode, 0, 0, 0)

	local nodeDiff = MathUtil.clamp( targetHeight - ay , -shovelR, shovelR) + ay

	local ax, _, az = getWorldTranslation(spec.armTool.node)
	local sx, sy, sz = getWorldTranslation(spec.shovelTool.node)

	if CpShovelPositions.DEBUG then
		DebugUtil.drawDebugCircleAtNode(spec.armTool.node, shovelR, 30, nil, true)

		DebugUtil.drawDebugNode(spec.armProjectionNode, "Projection node", false, 0)

		DebugUtil.drawDebugLine(x, targetAttacherHeight, z, sx, sy, sz)
		DebugUtil.drawDebugLine(x, targetAttacherHeight, z, ax, targetAttacherHeight, az) -- y
	end
	local yRot = math.atan2(MathUtil.vector3Length(x - sx, targetAttacherHeight - sy, z - sz),
		MathUtil.vector3Length(x - ax, 0, z - az))

	if diff < 0 then 
		yRot = yRot
	else 
		yRot = -yRot
	end
	
	CpShovelPositions.debug(shovel, 
		"Arm position(%d) height diff: %.2f, targetHeight: %.2f, old angle: %.2f, yRot: %.2f",
		spec.state, diff, targetHeight,  math.deg(oldRot),  math.deg(yRot))

	return ImplementUtil.moveMovingToolToRotation(spec.armVehicle, spec.armTool, dt, 
		MathUtil.clamp(oldRot + yRot , spec.armTool.rotMin, spec.armTool.rotMax))
end

function CpShovelPositions:updateLoadingPosition(dt)
	local spec = self.spec_cpShovelPositions
	local angle, shovelNode, maxAngle, minAngle, factor = CpShovelPositions.getShovelData(self)
	local isDirty
	if angle then 
		isDirty = CpShovelPositions.setShovelPosition(dt, spec, self, shovelNode, angle, CpShovelPositions.LOADING_POSITION.SHOVEL_LIMITS)
		isDirty = isDirty or CpShovelPositions.setArmPosition(dt, spec, self, shovelNode, CpShovelPositions.LOADING_POSITION.ARM_LIMITS)
	end
	spec.isDirty = isDirty
end

function CpShovelPositions:updateTransportPosition(dt)
	local spec = self.spec_cpShovelPositions
	local angle, shovelNode, maxAngle, minAngle, factor = CpShovelPositions.getShovelData(self)
	local isDirty
	if angle then 
		isDirty = CpShovelPositions.setShovelPosition(dt, spec, self, shovelNode, angle, CpShovelPositions.TRANSPORT_POSITION.SHOVEL_LIMITS)
		isDirty = isDirty or CpShovelPositions.setArmPosition(dt, spec, self, shovelNode, CpShovelPositions.TRANSPORT_POSITION.ARM_LIMITS)
	end
	spec.isDirty = isDirty
end

function CpShovelPositions:updatePreUnloadPosition(dt)
	local spec = self.spec_cpShovelPositions
	local angle, shovelNode, maxAngle, minAngle, factor = CpShovelPositions.getShovelData(self)
	local isDirty
	if angle then 
		isDirty = CpShovelPositions.setShovelPosition(dt, spec, self, shovelNode, angle, CpShovelPositions.PRE_UNLOAD_POSITION.SHOVEL_LIMITS)
		isDirty = isDirty or CpShovelPositions.setArmPosition(dt, spec, self, shovelNode, self:getCpShovelUnloadingPositionHeight())
	end
	spec.isDirty = isDirty
end

function CpShovelPositions:updateUnloadingPosition(dt)
	local spec = self.spec_cpShovelPositions
	local angle, shovelNode, maxAngle, minAngle, factor = CpShovelPositions.getShovelData(self)
	local isDirty
	if angle and maxAngle then 
		isDirty = CpShovelPositions.setArmPosition(dt, spec, self, shovelNode, self:getCpShovelUnloadingPositionHeight())
		isDirty = isDirty or CpShovelPositions.setShovelPosition(dt, spec, self, shovelNode, angle, {math.deg(maxAngle), math.deg(maxAngle) + 2})
	end
	spec.isDirty = isDirty
end

function CpShovelPositions:getCpShovelUnloadingPositionHeight()
	return CpShovelPositions.PRE_UNLOAD_POSITION.ARM_LIMITS
end

--- Gets all relevant shovel data.
function CpShovelPositions:getShovelData()
	local shovelSpec = self.spec_shovel
	if shovelSpec == nil then 
		CpShovelPositions.debug(self, "Shovel spec not found!")
		return 
	end
	local info = shovelSpec.shovelDischargeInfo
    if info == nil or info.node == nil then 
		CpShovelPositions.debugt(self, "Info or node not found!")
		return 
	end
    if info.maxSpeedAngle == nil or info.minSpeedAngle == nil then
		CpShovelPositions.debug(self, "maxSpeedAngle or minSpeedAngle not found!")
		return 
	end

	if shovelSpec.shovelNodes == nil then 
		CpShovelPositions.debug(self, "Shovel nodes not found!")
		return 
	end

	if shovelSpec.shovelNodes[1] == nil then 
		CpShovelPositions.debug(self, "Shovel nodes index 0 not found!")
		return 
	end

	if shovelSpec.shovelNodes[1].node == nil then 
		CpShovelPositions.debug(self, "Shovel node not found!")
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