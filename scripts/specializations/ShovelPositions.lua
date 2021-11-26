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

---@class ShovelPositions
ShovelPositions = {
	DEACTIVATED = 0,
	LOADING = 1,
	TRANSPORT = 2,
	PRE_UNLOAD = 3,
	UNLOADING = 4,
	LOADING_SHOVEL_ANGLE = 90,
	TRANSPORT_SHOVEL_ANGLE = 80
}
ShovelPositions.MOD_NAME = g_currentModName
ShovelPositions.DEBUG = true

function ShovelPositions.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(Shovel, specializations) 
end

function ShovelPositions.registerEventListeners(vehicleType)	
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", ShovelPositions)
	SpecializationUtil.registerEventListener(vehicleType, "onUpdateTick", ShovelPositions)
end

function ShovelPositions.registerFunctions(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, "setShovelState", ShovelPositions.setShovelState)
    SpecializationUtil.registerFunction(vehicleType, "resetShovelState", ShovelPositions.resetShovelState)
	SpecializationUtil.registerFunction(vehicleType, "setupShovelPositions", ShovelPositions.setupShovelPositions)
	SpecializationUtil.registerFunction(vehicleType, "isShovelPositionsDirty", ShovelPositions.isShovelPositionsDirty)
end


function ShovelPositions:onLoad(savegame)
	--- Register the spec: spec_ShovelPositions
    local specName = ShovelPositions.MOD_NAME .. ".shovelPositions"
    self.spec_shovelPositions = self["spec_" .. specName]
    local spec = self.spec_shovelPositions
	--- Current shovel state.
	spec.state = ShovelPositions.DEACTIVATED
	if ShovelPositions.DEBUG then 
		addConsoleCommand( 'cpSetShovelState', 'cpSetShovelState', 'setShovelState',self)
	end
end

--- Changes the current shovel state position.
function ShovelPositions:setShovelState(state)
	state = tonumber(state)
	if state == nil then 
		return
	end
	ShovelPositions.debugVehicle(self,"Changed shovelPositionState to %d.",state)
	local spec = self.spec_shovelPositions
	spec.state = state
	ShovelPositions.setupShovelPositions(self)
end

--- Deactivates the shovel position control.
function ShovelPositions:resetShovelState()
	ShovelPositions.debugVehicle(self,"Reset shovelPositionState.")
	local spec = self.spec_shovelPositions
	spec.state = ShovelPositions.DEACTIVATED
end

function ShovelPositions:isShovelPositionsDirty()
	local spec = self.spec_shovelPositions
	return spec.isDirty
end

--- Sets the relevant moving tools.
function ShovelPositions:setupShovelPositions()
	local spec = self.spec_shovelPositions
	spec.shovelToolIx = nil
	spec.armToolIx = nil
	spec.shovelTool = nil
	spec.armTool = nil
	local rootVehicle = self:getRootVehicle()
	for i,tool in pairs(rootVehicle.spec_cylindered.movingTools) do
		if tool.controlGroupIndex ~= nil then 
			if tool.axis == "AXIS_FRONTLOADER_ARM" then 
				spec.armToolIx = i
				spec.armTool = tool
			elseif tool.axis == "AXIS_FRONTLOADER_TOOL" then 
				spec.shovelToolIx = i
				spec.shovelTool = tool
			end
		end
	end
end

function ShovelPositions:onUpdateTick(dt)
	local spec = self.spec_shovelPositions
	if spec.shovelToolIx == nil or  spec.armToolIx == nil then 
		return
	end
	if spec.state == ShovelPositions.LOADING then 
		ShovelPositions.updateLoadingPosition(self,dt)
	elseif spec.state == ShovelPositions.TRANSPORT then 
		ShovelPositions.updateTransportPosition(self,dt)
	elseif spec.state == ShovelPositions.PRE_UNLOAD then 
		ShovelPositions.updatePreUnloadPosition(self,dt)
	elseif spec.state == ShovelPositions.UNLOADING then 
		ShovelPositions.updateUnloadingPosition(self,dt)
	end
end

--- Changes the shovel angle dependent on the selected position.
function ShovelPositions.setShovelPosition(spec,shovel,angle,max,min)
	local rootVehicle = shovel:getRootVehicle()
	local dir = MathUtil.sign(angle-math.rad(max))
	local diff = math.abs(angle-math.rad(max))
	local isDirty = false
	if max and math.deg(angle) > max then 
		isDirty = true
	elseif min and math.deg(angle)  < min then
		isDirty = true
	else 
		Cylindered.actionEventInput(rootVehicle,"", 0, spec.shovelToolIx, true)
	end
	if isDirty then 
		Cylindered.actionEventInput(rootVehicle,"", dir*diff*2, spec.shovelToolIx, true)
		ShovelPositions.debugVehicle(shovel,"Position(%d) angle: %.2f, diff: %.2f, dir: %d",spec.state,math.deg(angle),diff,dir)
	end
	return isDirty
end

--- Changes the front loader angle dependent on the selected position, relative to a target height.
function ShovelPositions.setArmPosition(spec,shovel,shovelNode,max,min)
	local rootVehicle = shovel:getRootVehicle()
	local x,y,z = getWorldTranslation(shovelNode)
	local dy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 0, z)
	local dir = -MathUtil.sign(y-dy - min)
	local diff = math.abs(y-dy - min)
	local isDirty = false
	if max and y-dy > max then 
		isDirty = true
	elseif min and y-dy < min then
		isDirty = true
	else 
		Cylindered.actionEventInput(rootVehicle,"", 0, spec.armToolIx, true)
	end
	if isDirty then 
		Cylindered.actionEventInput(rootVehicle,"", dir * diff, spec.armToolIx, true)
		ShovelPositions.debugVehicle(shovel,"Position(%d) height diff: %.2f, dir: %d",spec.state,diff,dir)
	end
	return isDirty
end

function ShovelPositions:updateLoadingPosition(dt)
	local spec = self.spec_shovelPositions
	local angle,shovelNode,maxAngle,minAngle,factor = ShovelPositions.getShovelData(self)
	local isDirty
	if angle then 
		local isDirtyShovel = ShovelPositions.setShovelPosition(spec,self,angle,91,89)
		local isDirtyArm = ShovelPositions.setArmPosition(spec,self,shovelNode,0.25,0.1)
		isDirty = isDirtyShovel or isDirtyArm
	end
	self.isDirty = isDirty
end

function ShovelPositions:updateTransportPosition(dt)
	local spec = self.spec_shovelPositions
	local angle,shovelNode,maxAngle,minAngle,factor = ShovelPositions.getShovelData(self)
	local isDirty
	if angle then 
		local isDirtyShovel = ShovelPositions.setShovelPosition(spec,self,angle,75,73)
		local isDirtyArm = ShovelPositions.setArmPosition(spec,self,shovelNode,1.2,1)
		isDirty = isDirtyShovel or isDirtyArm
	end
	self.isDirty = isDirty
end

function ShovelPositions:updatePreUnloadPosition(dt)
	local spec = self.spec_shovelPositions
	local angle,shovelNode,maxAngle,minAngle,factor = ShovelPositions.getShovelData(self)
	local isDirty
	if angle then 
		local isDirtyShovel = ShovelPositions.setShovelPosition(spec,self,angle,math.deg(minAngle)-2,math.deg(minAngle)-4)
		local isDirtyArm = ShovelPositions.setArmPosition(spec,self,shovelNode,4,3)
		isDirty = isDirtyShovel or isDirtyArm
	end
	self.isDirty = isDirty
end

function ShovelPositions:updateUnloadingPosition(dt)
	local spec = self.spec_shovelPositions
	local angle,shovelNode,maxAngle,minAngle,factor = ShovelPositions.getShovelData(self)
	local isDirty
	if angle then 
		local isDirtyShovel = ShovelPositions.setShovelPosition(spec,self,angle,math.deg(maxAngle)+2,math.deg(maxAngle))
		local isDirtyArm = ShovelPositions.setArmPosition(spec,self,shovelNode,4,3)
		isDirty = isDirtyShovel or isDirtyArm
	end
	self.isDirty = isDirty
end

--- Gets all relevant shovel data.
function ShovelPositions:getShovelData()
	local shovelSpec = self.spec_shovel
	if shovelSpec == nil then 
		ShovelPositions.debugVehicle(self,"Shovel spec not found!")
		return 
	end
	local info = shovelSpec.shovelDischargeInfo
    if info == nil or info.node == nil then 
		ShovelPositions.debugVehicle(self,"Info or node not found!")
		return 
	end
	local _, dy, _ = localDirectionToWorld(info.node, 0, 0, 1)
	local angle = math.acos(dy)
    if info.maxSpeedAngle == nil or info.minSpeedAngle == nil then
		ShovelPositions.debugVehicle(self,"maxSpeedAngle or minSpeedAngle not found!")
		return 
	end
	local factor = math.max(0, math.min(1, (angle - info.minSpeedAngle) / (info.maxSpeedAngle - info.minSpeedAngle)))

	if shovelSpec.shovelNodes == nil then 
		ShovelPositions.debugVehicle(self,"Shovel nodes not found!")
		return 
	end

	if shovelSpec.shovelNodes[1] == nil then 
		ShovelPositions.debugVehicle(self,"Shovel nodes index 0 not found!")
		return 
	end

	if shovelSpec.shovelNodes[1].node == nil then 
		ShovelPositions.debugVehicle(self,"Shovel node not found!")
		return 
	end

	return angle,shovelSpec.shovelNodes[1].node,info.maxSpeedAngle,info.minSpeedAngle,factor
end

function ShovelPositions.debugVehicle(vehicle,...)
	if ShovelPositions.DEBUG then
		Courseplay.infoVehicle(vehicle,...)
	end
end