--[[
This file is part of Courseplay (https://github.com/Courseplay/courseplay)
Copyright (C) 2021 Peter Vaiko

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

---
--- High level (scope is the entire vehicle chain) utilities for the Courseplay AI

---@class AIUtil
AIUtil = {}

-- chopper: 0= pipe folded (really? isn't this 1?), 2,= autoaiming;  combine: 1 = closed  2= open
AIUtil.PIPE_STATE_MOVING = 0
AIUtil.PIPE_STATE_CLOSED = 1
AIUtil.PIPE_STATE_OPEN = 2

function AIUtil.isReverseDriving(vehicle)
	if not vehicle then
		printCallstack()
		return false
	end
	return vehicle.spec_reverseDriving and vehicle.spec_reverseDriving.isReverseDriving
end

function AIUtil.getDirectionNode(vehicle)
	-- our reference node we are tracking/controlling, by default it is the vehicle's root/direction node
	if AIUtil.isReverseDriving(vehicle) then
		-- reverse driving tractor, use the CP calculated reverse driving direction node pointing in the
		-- direction the driver seat is facing
		return vehicle:getReverseDrivingDirectionNode()
	else
		return vehicle:getAIDirectionNode() or vehicle.rootNode
	end
end

--- If we are towing an implement, move to a bigger radius in tight turns
--- making sure that the towed implement's trajectory remains closer to the
--- course.
---@param course Course
function AIUtil.calculateTightTurnOffset(vehicle, course, previousOffset, useCalculatedRadius)
	local tightTurnOffset

	local function smoothOffset(offset)
		return (offset + 3 * (previousOffset or 0 )) / 4
	end

	-- first of all, does the current waypoint have radius data?
	local r
	if useCalculatedRadius then
		r = course:getCalculatedRadiusAtIx(course:getCurrentWaypointIx())
	else
		r = course:getRadiusAtIx(course:getCurrentWaypointIx())
	end
	if not r then
		return smoothOffset(0)
	end

	-- limit the radius we are trying to follow to the vehicle's turn radius.
	-- TODO: there's some potential here as the towed implement can move on a radius less than the vehicle's
	-- turn radius so this limit may be too pessimistic
	local turnDiameter = r or vehicle.cp.settings.turnDiameter:get() -- TODO_22
	r = math.max(r, turnDiameter / 2)

	local towBarLength = AIUtil.getTowBarLength(vehicle)

	-- Is this really a tight turn? It is when the tow bar is longer than radius / 3, otherwise
	-- we ignore it.
	if towBarLength < r / 3 then
		return smoothOffset(0)
	end

	-- Ok, looks like a tight turn, so we need to move a bit left or right of the course
	-- to keep the tool on the course. Use a little less than the calculated, this is purely empirical and should probably
	-- be reviewed why the calculated one seems to overshoot.
	local offset = 0.75 * AIUtil.getOffsetForTowBarLength(r, towBarLength)
	if offset ~= offset then
		-- check for nan
		return smoothOffset(0)
	end
	-- figure out left or right now?
	local nextAngle = course:getWaypointAngleDeg(course:getCurrentWaypointIx() + 1)
	local currentAngle = course:getWaypointAngleDeg(course:getCurrentWaypointIx())
	if not nextAngle or not currentAngle then
		return smoothOffset(0)
	end

	if getDeltaAngle(math.rad(nextAngle), math.rad(currentAngle)) > 0 then offset = -offset end

	-- smooth the offset a bit to avoid sudden changes
	tightTurnOffset = smoothOffset(offset)
	CpUtil.debugVehicle(CpDebug.DBG_AI_DRIVER, vehicle,
		'Tight turn, r = %.1f, tow bar = %.1f m, currentAngle = %.0f, nextAngle = %.0f, offset = %.1f, smoothOffset = %.1f',
		r, towBarLength, currentAngle, nextAngle, offset, tightTurnOffset )
	-- remember the last value for smoothing
	return tightTurnOffset
end

function AIUtil.getTowBarLength(vehicle)
	-- is there a wheeled implement behind the tractor and is it on a pivot?
	local implement = AIUtil.getFirstReversingImplementWithWheels(vehicle)
	if not implement or not implement.steeringAxleNode then
		CpUtil.debugVehicle(CpDebug.DBG_AI_DRIVER, vehicle, 'could not get tow bar length, using default 3 m.')
		-- default is not 0 as this is used to calculate trailer heading and 0 here may result in NaNs
		return 3
	end
	-- get the distance between the tractor and the towed implement's turn node
	-- (not quite accurate when the angle between the tractor and the tool is high)
	local tractorX, _, tractorZ = getWorldTranslation(AIUtil.getDirectionNode(vehicle))
	local toolX, _, toolZ = getWorldTranslation(implement.steeringAxleNode)
	local towBarLength = MathUtil.getPointPointDistance( tractorX, tractorZ, toolX, toolZ )
	CpUtil.debugVehicle(CpDebug.DBG_AI_DRIVER, vehicle, 'tow bar length is %.1f.', towBarLength)
	return towBarLength
end

function AIUtil.getOffsetForTowBarLength(r, towBarLength)
	local rTractor = math.sqrt( r * r + towBarLength * towBarLength ) -- the radius the tractor should be on
	return rTractor - r
end

-- Find the node to use by the PPC when driving in reverse
function AIUtil.getReverserNode(vehicle)
	local reverserNode, debugText
	-- if there's a reverser node on the tool, use that
	local reverserDirectionNode = AIVehicleUtil.getAIToolReverserDirectionNode(vehicle)
	local reversingWheeledWorkTool = AIUtil.getFirstReversingImplementWithWheels(vehicle)
	if reverserDirectionNode then
		reverserNode = reverserDirectionNode
		debugText = 'implement reverse (Giants)'
	elseif reversingWheeledWorkTool and reversingWheeledWorkTool.steeringAxleNode then
		reverserNode = reversingWheeledWorkTool.steeringAxleNode
		debugText = 'implement reverse (Courseplay)'
	elseif vehicle.spec_articulatedAxis ~= nil then
		-- articulated axis vehicles have a special reverser node
		-- and yes, Giants has a typo in there...
		if vehicle.spec_articulatedAxis.aiRevereserNode ~= nil then
			reverserNode = vehicle.spec_articulatedAxis.aiRevereserNode
			debugText = 'vehicle articulated axis reverese'
		elseif vehicle.spec_articulatedAxis.aiReverserNode ~= nil then
			reverserNode = vehicle.spec_articulatedAxis.aiReverserNode
			debugText = 'vehicle articulated axis reverse'
		end
	else
		-- otherwise see if the vehicle has a reverser node
		if vehicle.getAIVehicleReverserNode then
			reverserDirectionNode = vehicle:getAIVehicleReverserNode()
			if reverserDirectionNode then
				reverserNode = reverserDirectionNode
				debugText = 'vehicle reverse'
			end
		end
	end
	return reverserNode, debugText
end

-- Get the turning radius of the vehicle and its implements (copied from AIDriveStrategyStraight.updateTurnData())
function AIUtil.getTurningRadius(vehicle)
	CpUtil.debugVehicle(CpDebug.DBG_IMPLEMENTS, vehicle, 'Finding turn radius:')

	local radius = vehicle.maxTurningRadius or 6
	CpUtil.debugVehicle(CpDebug.DBG_IMPLEMENTS, vehicle, '  turnRadius set to %.1f', radius)

	if g_vehicleConfigurations:get(vehicle, 'turnRadius') then
		radius = g_vehicleConfigurations:get(vehicle, 'turnRadius')
		CpUtil.debugVehicle(CpDebug.DBG_IMPLEMENTS, vehicle, '  turnRadius set from configfile to %.1f', radius)
	end

	-- TODO_22
	--local turnDiameterSetting = vehicle.cp.settings.turnDiameter
	--if not turnDiameterSetting:isAutomaticActive() then
	--	radius = turnDiameterSetting:get() / 2
	--	CpUtil.debugVehicle(CpDebug.DBG_IMPLEMENTS, vehicle, '  turnRadius manually set to %.1f', radius)
	--end

	if vehicle:getAIMinTurningRadius() ~= nil then
		CpUtil.debugVehicle(CpDebug.DBG_IMPLEMENTS, vehicle, '  AIMinTurningRadius by Giants is %.1f', vehicle:getAIMinTurningRadius())
		radius = math.max(radius, vehicle:getAIMinTurningRadius())
	end

	local maxToolRadius = 0

	for _, implement in pairs(vehicle:getAttachedImplements()) do
		local turnRadius = 0
		if g_vehicleConfigurations:get(implement.object, 'turnRadius') then
			turnRadius = g_vehicleConfigurations:get(implement.object, 'turnRadius')
			CpUtil.debugVehicle(CpDebug.DBG_IMPLEMENTS, vehicle, '  %s: using the configured turn radius %.1f',
				implement.object:getName(), turnRadius)
		elseif SpecializationUtil.hasSpecialization(AIImplement, implement.object.specializations) then
			-- only call this for AIImplements, others may throw an error as the Giants code assumes AIImplement
			turnRadius = AIVehicleUtil.getMaxToolRadius(implement)
			if turnRadius > 0 then
				CpUtil.debugVehicle(CpDebug.DBG_IMPLEMENTS, vehicle, '  %s: using the Giants turn radius %.1f',
					implement.object:getName(), turnRadius)
			end
		end
		if turnRadius == 0 then
			-- TODO
			--turnRadius = courseplay:getToolTurnRadius(implement.object)
			CpUtil.debugVehicle(CpDebug.DBG_IMPLEMENTS, vehicle, '  %s: no Giants turn radius, we assume %.1f',
				implement.object:getName(), turnRadius)
		end
		maxToolRadius = math.max(maxToolRadius, turnRadius)
		CpUtil.debugVehicle(CpDebug.DBG_IMPLEMENTS, vehicle, '  %s: max tool radius now is %.1f', implement.object:getName(), maxToolRadius)
	end
	radius = math.max(radius, maxToolRadius)
	CpUtil.debugVehicle(CpDebug.DBG_IMPLEMENTS, vehicle, 'getTurningRadius: %.1f m', radius)
	return radius
end

---@return table implement object
function AIUtil.getFirstReversingImplementWithWheels(vehicle)
	-- since some weird things like Seed Bigbag are also vehicles, check this first
	if not vehicle.getAttachedImplements then return nil end
	-- Check all attached implements if we are a wheeled workTool behind the tractor
	for _, imp in ipairs(vehicle:getAttachedImplements()) do
		-- Check if the implement is behind
		if AIUtil.isObjectAttachedOnTheBack(vehicle, imp.object) then
			if ImplementUtil.isWheeledImplement(imp.object) then
				-- If the implement is a wheeled workTool, then return the object
				return imp.object
			else
				-- If the implement is not a wheeled workTool, then check if that implement have an attached wheeled workTool and return that.
				return AIUtil.getFirstReversingImplementWithWheels(imp.object)
			end
		end
	end
	-- If we didnt find any workTool, return nil
	return nil
end

---@return boolean true if there are any implements attached to the back of the vehicle
function AIUtil.hasImplementsOnTheBack(vehicle)
	for _, implement in pairs(vehicle:getAttachedImplements()) do
		if implement.object ~= nil then
			local _, _, dz = localToLocal(implement.object.rootNode, vehicle.rootNode, 0, 0, 0)
			if dz < 0 then
				return true
			end
		end
	end
	return false
end

--- Is the object attached at the front of the vehicle.
---@param vehicle table
---@param object table
---@return boolean
function AIUtil.isObjectAttachedOnTheFront(vehicle,object)
	local _, _, dz = localToLocal(object.rootNode, vehicle.rootNode, 0, 0, 0)
	if dz > 0 then
		return true
	end
	return false
end

--- Is the object attached at the back of the vehicle.
---@param vehicle table
---@param object table
---@return boolean
function AIUtil.isObjectAttachedOnTheBack(vehicle,object)
	local _, _, dz = localToLocal(object.rootNode, vehicle.rootNode, 0, 0, 0)
	if dz < 0 then
		return true
	end
	return false
end

function AIUtil.getAllAttachedImplements(object, implements)
	if not implements then implements = {} end
	for _, implement in ipairs(object:getAttachedImplements()) do
		table.insert(implements, implement)
		AIUtil.getAllAttachedImplements(implement.object, implements)
	end
	return implements
end

---@return table, number frontmost object and the distance between the front of that object and the root node of the vehicle
--- when > 0 in front of the vehicle
function AIUtil.getFirstAttachedImplement(vehicle,suppressLog)
	-- by default, it is the vehicle's front
	local maxDistance = vehicle.size.length / 2 + vehicle.size.lengthOffset
	local firstImplement = vehicle
	for _, implement in pairs(AIUtil.getAllAttachedImplements(vehicle)) do
		if implement.object ~= nil then
			-- the distance from the vehicle's root node to the front of the implement
			local _, _, d = localToLocal(implement.object.rootNode, vehicle.rootNode, 0, 0,
				implement.object.size.length / 2 + implement.object.size.lengthOffset)
			if not suppressLog then
				CpUtil.debugVehicle(CpDebug.DBG_IMPLEMENTS, vehicle, '%s front distance %d', implement.object:getName(), d)
			end
			if d > maxDistance then
				maxDistance = d
				firstImplement = implement.object
			end
		end
	end
	return firstImplement, maxDistance
end

---@return table, number rearmost object and the distance between the back of that object and the root node of the object
function AIUtil.getLastAttachedImplement(vehicle,suppressLog)
	-- by default, it is the vehicle's back
	local minDistance = vehicle.size.length / 2 - vehicle.size.lengthOffset
	-- size.lengthOffset > 0 if the root node is towards the back of the vehicle, < 0 if it is towards the front
	local lastImplement = vehicle
	for _, implement in pairs(AIUtil.getAllAttachedImplements(vehicle)) do
		if implement.object ~= nil then
			-- the distance from the vehicle's root node to the back of the implement
			local _, _, d = localToLocal(implement.object.rootNode, vehicle.rootNode, 0, 0,
				- implement.object.size.length / 2 + implement.object.size.lengthOffset)
			if not suppressLog then
				CpUtil.debugVehicle(CpDebug.DBG_IMPLEMENTS, vehicle, '%s back distance %d', implement.object:getName(), d)
			end
			if d < minDistance then
				minDistance = d
				lastImplement = implement.object
			end
		end
	end
	return lastImplement, minDistance
end

function AIUtil.isAllFolded(object)
	if SpecializationUtil.hasSpecialization(Foldable, object.specializations) then
		if object:getIsUnfolded() then
			-- object is unfolded, so all can't be folded
			return false
		end
	end
	for _, implement in pairs(object:getAttachedImplements()) do
		if not AIUtil.isAllFolded(implement.object) then
			-- at least on implement is not completely folded so all can't be folded
			return false
		end
	end
	-- nothing is unfolded
	return true
end

--- These functions only find directly attached implements/trailer to the vehicle.
--- Implements of others for example a shovel attached to a front loader are not detected.
function AIUtil.hasAIImplementWithSpecialization(vehicle, specialization)
	return AIUtil.getAIImplementWithSpecialization(vehicle, specialization) ~= nil
end

function AIUtil.hasImplementWithSpecialization(vehicle, specialization)
	return AIUtil.getImplementWithSpecialization(vehicle, specialization) ~= nil
end

function AIUtil.getAIImplementWithSpecialization(vehicle, specialization)
	local aiImplements = vehicle:getAttachedAIImplements()
	return AIUtil.getImplementWithSpecializationFromList(specialization, aiImplements)
end

function AIUtil.getImplementWithSpecialization(vehicle, specialization)
	local implements = vehicle:getAttachedImplements()
	return AIUtil.getImplementWithSpecializationFromList(specialization, implements)
end

--- Gets a directly attached implement to the vehicle with a given specialization.
--- Additionally checks if the vehicle has the specialization and returns it, if no implement was found.
--- For example a self driving overloader.
function AIUtil.getImplementOrVehicleWithSpecialization(vehicle, specialization)
	return  AIUtil.getImplementWithSpecialization(vehicle, specialization) or  
			SpecializationUtil.hasSpecialization(specialization, vehicle.specializations) and vehicle
end

function AIUtil.getImplementWithSpecializationFromList(specialization, implements)
	for _, implement in ipairs(implements) do
		if SpecializationUtil.hasSpecialization(specialization, implement.object.specializations) then
			return implement.object
		end
	end
end

function AIUtil.getAllAIImplements(object, implements)
	if not implements then implements = {} end
	for _, implement in ipairs(object:getAttachedImplements()) do
		-- ignore everything which has no work area
		if AIUtil.isValidAIImplement(implement.object) then
			table.insert(implements, implement)
		end
		AIUtil.getAllAIImplements(implement.object, implements)
	end
	return implements
end

-- Is this and implement we should consider when deciding when to lift/raise implements at the end/start of a row?
function AIUtil.isValidAIImplement(object)
	if WorkWidthUtil.hasWorkAreas(object) then
		-- has work areas, good.
		return true
	else
		local aiLeftMarker, _, _ = WorkWidthUtil.getAIMarkers(object, nil, true)
		if aiLeftMarker then
			-- has AI markers, good
			return true
		else
			-- no work areas, no AI markers, can't use.
			return false
		end
	end
end



--- Is this a real wheel the implement is actually rolling on (and turning around) or just some auxiliary support
--- wheel? We need to know about the real wheels when finding the turn radius/distance between attacher joint and
--- wheels.
function AIUtil.isRealWheel(wheel)
	return wheel.hasTireTracks and wheel.maxLatStiffnessLoad > 0.5
end

function AIUtil.isBehindOtherVehicle(vehicle, otherVehicle)
	local _, _, dz = localToLocal(AIUtil.getDirectionNode(vehicle), AIUtil.getDirectionNode(otherVehicle), 0, 0, 0)
	return dz < 0
end

function AIUtil.isStopped(vehicle)
	-- giants supplied last speed is in mm/s
	return math.abs(vehicle.lastSpeedReal) < 0.0001
end

function AIUtil.isReversing(vehicle)
	return vehicle.movingDirection == -1 and vehicle.lastSpeedReal * 3600 > 0.1
end

--- Get the current normalized steering angle:
---@return number between -1 and +1, -1 full right steering, +1 full left steering
function AIUtil.getCurrentNormalizedSteeringAngle(vehicle)
	if vehicle.rotatedTime >= 0 then
		return vehicle.rotatedTime / vehicle.maxRotTime
	elseif vehicle.rotatedTime < 0 then
		return -vehicle.rotatedTime / vehicle.minRotTime
	end
end

--- Is a sugarcane trailer attached ?
---@param vehicle table
function AIUtil.hasSugarCaneTrailer(vehicle)
	if vehicle.spec_shovel and vehicle.spec_trailer then 
		return true
	end
	for _, implement in pairs(AIUtil.getAllAttachedImplements(vehicle)) do
		local object = implement.object
		if object.spec_shovel and object.spec_trailer then 
			return true
		end
	end
end

--- Are there any trailer under the pipe ?
---@param pipe table 
---@param shouldTrailerBeStandingStill boolean
function AIUtil.isTrailerUnderPipe(pipe,shouldTrailerBeStandingStill)
	if not pipe then return end
	for trailer, value in pairs(pipe.objectsInTriggers) do
		if value > 0 then
			if shouldTrailerBeStandingStill then 
				local rootVehicle = trailer:getRootVehicle()
				if rootVehicle then 
					if AIUtil.isStopped(rootVehicle) then 
						return true
					else 
						return false
					end
				end
			end
			return true
		end
	end
	return false
end

---Gets the total length of the vehicle and all it's implements.
function AIUtil.getVehicleAndImplementsTotalLength(vehicle)
	local totalLength = vehicle.size.length
	for _, implement in pairs(AIUtil.getAllAttachedImplements(vehicle)) do
		if implement.object ~= nil then
			totalLength = totalLength + implement.object.size.length
		end
	end
	return totalLength
end 

function AIUtil.getShieldWorkWidth(object,logPrefix)
	if object.spec_leveler then 
		local width = object.spec_leveler.nodes[1].maxDropWidth * 2
		CpUtil.debugFormat(CpDebug.DBG_IMPLEMENTS,'%s%s: Is a shield with work width: %.1f', logPrefix, nameNum(object), width)
		return width
	end
end

function AIUtil.findLoweringDurationMs(vehicle)
	local function getLoweringDurationMs(object)
		if object.spec_animatedVehicle then
			-- TODO: implement these in the specifications?
			return math.max(object.spec_animatedVehicle:getAnimationDuration('lowerAnimation'),
					object.spec_animatedVehicle:getAnimationDuration('rotatePickup'),
					object.spec_animatedVehicle:getAnimationDuration('folding'))
		else
			return 0
		end
	end

	local loweringDurationMs = getLoweringDurationMs(vehicle)
	CpUtil.debugFormat(CpDebug.DBG_IMPLEMENTS, 'Lowering duration: %d ms', loweringDurationMs)

	-- check all implements first
	local implements = vehicle:getAttachedImplements()
	for _, implement in ipairs(implements) do
		local implementLoweringDurationMs = getLoweringDurationMs(implement.object)
		CpUtil.debugFormat(CpDebug.DBG_IMPLEMENTS, 'Lowering duration (%s): %d ms', implement.object:getName(), implementLoweringDurationMs)
		if implementLoweringDurationMs > loweringDurationMs then
			loweringDurationMs = implementLoweringDurationMs
		end
		local jointDescIndex = implement.jointDescIndex
		-- now check the attacher joints
		if vehicle.spec_attacherJoints and jointDescIndex then
			local ajs = vehicle.spec_attacherJoints:getAttacherJoints()
			local ajLoweringDurationMs = ajs[jointDescIndex] and ajs[jointDescIndex].moveDefaultTime or 0
			CpUtil.debugFormat(CpDebug.DBG_IMPLEMENTS, 'Lowering duration (%s attacher joint): %d ms', implement.object:getName(), ajLoweringDurationMs)
			if ajLoweringDurationMs > loweringDurationMs then
				loweringDurationMs = ajLoweringDurationMs
			end
		end
	end
	if not loweringDurationMs or loweringDurationMs <= 1 then
		loweringDurationMs = 2000
		CpUtil.debugFormat(CpDebug.DBG_IMPLEMENTS, 'No lowering duration found, setting to: %d ms', loweringDurationMs)
	end
	CpUtil.debugFormat(CpDebug.DBG_IMPLEMENTS, 'Final lowering duration: %d ms', loweringDurationMs)
	return loweringDurationMs
end
