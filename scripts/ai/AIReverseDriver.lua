--[[
This file is part of Courseplay (https://github.com/Courseplay/courseplay)
Copyright (C) 2021 Satis, Peter Vaiko

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

The AIReverseDriver takes over the steering if there is a towed implement
or a trailer to be reversed.

]]--

---@class AIReverseDriver
AIReverseDriver = CpObject()

---@param course Course
function AIReverseDriver:init(vehicle, ppc)
	self.vehicle = vehicle
	self.settings = vehicle:getCpSettings()
	---@type PurePursuitController
	self.ppc = ppc
	-- the main implement (towed) or trailer we are controlling
	self.reversingImplement = AIUtil.getFirstReversingImplementWithWheels(self.vehicle)
	if self.reversingImplement then
		self:setReversingProperties(self.reversingImplement)
	else
		self:debug('No towed implement found.')
	end
	self:debug('AIReverseDriver created.')
	-- TODO_22
	-- handle HookLift
end

function AIReverseDriver:debug(...)
	CpUtil.debugVehicle(CpDebug.DBG_REVERSE, self.vehicle, ...)
end

function AIReverseDriver:getDriveData()
	if self.reversingImplement == nil then
		-- no wheeled implement, simple reversing the PPC can handle by itself
		return nil
	end

	local trailerNode = self.reversingImplement.steeringAxleNode
	local xTipper, yTipper, zTipper = getWorldTranslation(trailerNode);

	local trailerFrontNode = self.reversingImplement.reversingProperties.frontNode
	local xFrontNode,yFrontNode,zFrontNode = getWorldTranslation(trailerFrontNode)

	local tx, ty, tz = self.ppc:getGoalPointPosition()

	local lxTipper, lzTipper = AIVehicleUtil.getDriveDirection(trailerNode, tx, ty, tz)

	self:showDirection(trailerNode, lxTipper, lzTipper, 1, 0, 0)

	local lxFrontNode, lzFrontNode = AIVehicleUtil.getDriveDirection(trailerFrontNode, xTipper, yTipper, zTipper)

	local lxTractor, lzTractor = 0, 0

	local maxTractorAngle = math.rad(75)

	-- for articulated vehicles use the articulated axis' rotation node as it is a better indicator or the
	-- vehicle's orientation than the direction node which often turns/moves with an articulated vehicle part
	-- TODO: consolidate this with AITurn:getTurnNode() and if getAIDirectionNode() considers this already
	local tractorNode
	local useArticulatedAxisRotationNode = 
		SpecializationUtil.hasSpecialization(ArticulatedAxis, self.vehicle.specializations) and self.vehicle.spec_articulatedAxis.rotationNode
	if useArticulatedAxisRotationNode then
		tractorNode = self.vehicle.spec_articulatedAxis.rotationNode
	else
		tractorNode = self.vehicle:getAIDirectionNode()
	end

	local lx, lz, angleDiff
	
	if self.reversingImplement.reversingProperties.isPivot then
		self:showDirection(trailerFrontNode, lxFrontNode, lzFrontNode, 0, 1, 0)

		lxTractor, lzTractor = AIVehicleUtil.getDriveDirection(tractorNode, xFrontNode, yFrontNode, zFrontNode)
		self:showDirection(tractorNode,lxTractor, lzTractor, 0, 0.7, 0)

		local rotDelta = (self.reversingImplement.reversingProperties.nodeDistance *
				(0.5 - (0.023 * self.reversingImplement.reversingProperties.nodeDistance - 0.073)))
		local trailerToWaypointAngle = self:getLocalYRotationToPoint(trailerNode, tx, ty, tz, -1) * rotDelta
		trailerToWaypointAngle = MathUtil.clamp(trailerToWaypointAngle, -math.rad(90), math.rad(90))

		local dollyToTrailerAngle = self:getLocalYRotationToPoint(trailerFrontNode, xTipper, yTipper, zTipper, -1)

		local tractorToDollyAngle = self:getLocalYRotationToPoint(tractorNode, xFrontNode, yFrontNode, zFrontNode, -1)

		local rearAngleDiff	= (dollyToTrailerAngle - trailerToWaypointAngle)
		rearAngleDiff = MathUtil.clamp(rearAngleDiff, -math.rad(45), math.rad(45))

		local frontAngleDiff = (tractorToDollyAngle - dollyToTrailerAngle)
		frontAngleDiff = MathUtil.clamp(frontAngleDiff, -math.rad(45), math.rad(45))

		angleDiff = (frontAngleDiff - rearAngleDiff) * 
				(1.5 - (self.reversingImplement.reversingProperties.nodeDistance * 0.4 - 0.9) + rotDelta)
		angleDiff = MathUtil.clamp(angleDiff, -math.rad(45), math.rad(45))

		lx, lz = MathUtil.getDirectionFromYRotation(angleDiff)
	else
		lxTractor, lzTractor = AIVehicleUtil.getDriveDirection(tractorNode, xTipper, yTipper, zTipper)
		self:showDirection(tractorNode, lxTractor, lzTractor, 1, 1, 0)

		local rotDelta = self.reversingImplement.reversingProperties.nodeDistance * 0.5
		local trailerToWaypointAngle = self:getLocalYRotationToPoint(trailerNode, tx, yTipper, tz, -1) * rotDelta


		trailerToWaypointAngle = MathUtil.clamp(trailerToWaypointAngle, -math.rad(90), math.rad(90))

		local tractorToTrailerAngle = self:getLocalYRotationToPoint(tractorNode, xTipper, yTipper, zTipper, -1)

		angleDiff = (tractorToTrailerAngle - trailerToWaypointAngle) * (1 + rotDelta)

		-- If we only have steering axle on the worktool and they turn when reversing, we need to steer a lot more to counter this.
		if self.reversingImplement.reversingProperties.steeringAxleUpdateBackwards then
			angleDiff = angleDiff * 4
		end

		angleDiff = self:calculateHitchAngle(tractorNode, trailerNode)
		angleDiff = MathUtil.clamp(angleDiff, -maxTractorAngle, maxTractorAngle)

		lx, lz = MathUtil.getDirectionFromYRotation(angleDiff)
	end

	self:showDirection(tractorNode, lx, lz, 0.7, 0, 1)
	-- do a little bit of damping if using the articulated axis as lx tends to oscillate around 0 which results in the
	-- speed adjustment kicking in and slowing down the vehicle.
	if useArticulatedAxisRotationNode and math.abs(lx) < 0.04 then lx = 0 end
	-- construct an artificial goal point to drive to
	lx, lz = -lx * self.ppc:getLookaheadDistance(), -lz * self.ppc:getLookaheadDistance()
	-- AIDriveStrategy wants a global position to drive to (which it later converts to local, but whatever...)
	local gx, _, gz = localToWorld(self.vehicle:getAIDirectionNode(), lx, 0, lz)
	DebugUtil.drawDebugLine(gx, ty, gz, gx, ty + 3, gz, 1, 0, 0)
	-- TODO_22 reverse speed
	return gx, gz, false, self.settings.reverseSpeed:getValue()
end

function AIReverseDriver:getLocalYRotationToPoint(node, x, y, z, direction)
	direction = direction or 1
	local dx, _, dz = worldToLocal(node, x, y, z)
	dx = dx * direction
	dz = dz * direction
	return MathUtil.getYRotationFromDirection(dx, dz)
end

function AIReverseDriver:showDirection(node, lx, lz, r, g, b)
	if CpUtil.isVehicleDebugActive(self.vehicle) and CpDebug:isChannelActive(CpDebug.DBG_REVERSE) then
		local x,y,z = getWorldTranslation(node)
		local tx,_, tz = localToWorld(node,lx*5,y,lz*5)
		DebugUtil.drawDebugLine(x, y+5, z, tx, y+5, tz, r or 1, g or 0, b or 0)
	end
end

---@param implement table implement.object
function AIReverseDriver:setReversingProperties(implement)
	if implement.reversingProperties and implement.reversingProperties.frontNode then return end
	self:debug('setReversingProperties for %s', CpUtil.getName(implement))

	implement.reversingProperties = {}

	local attacherVehicle = self.reversingImplement:getAttacherVehicle()

	if attacherVehicle == self.vehicle or ImplementUtil.isAttacherModule(attacherVehicle) then
		implement.reversingProperties.frontNode = ImplementUtil.getRealTrailerFrontNode(implement)
	else
		implement.reversingProperties.frontNode = ImplementUtil.getRealDollyFrontNode(attacherVehicle)
		if implement.reversingProperties.frontNode then
			self:debug('--> self.reversingImplement %q has dolly')
		else
			self:debug('--> self.reversingImplement %q has invalid dolly -> return')
			return
		end
	end

	implement.reversingProperties.nodeDistance = ImplementUtil.getRealTrailerDistanceToPivot(implement)
	self:debug("--> tz: %.1f real trailer distance to pivot: %s",
			implement.reversingProperties.nodeDistance, tostring(implement.steeringAxleNode))

	if implement.steeringAxleNode == implement.reversingProperties.frontNode then
		self:debug('--> implement.steeringAxleNode == implement.reversingProperties.frontNode')
		implement.reversingProperties.isPivot = false
	else
		implement.reversingProperties.isPivot = true
	end

	self:debug('--> isPivot=%s, frontNode=%s', 
			tostring(implement.reversingProperties.isPivot), tostring(implement.reversingProperties.frontNode))
end

function AIReverseDriver:calculateHitchAngle(tractorNode, trailerNode)

	local crossTrackError = self.ppc:getCrossTrackError()
	local currentWp = self.ppc:getCurrentWaypoint()
	local referenceAngle = currentWp.yRot
	local dx, _, dz = localDirectionToWorld(trailerNode, 0, 0, -1)
	local trailerAngle = MathUtil.getYRotationFromDirection(dx, dz)

	local orientationError = getDeltaAngle(trailerAngle, referenceAngle)

	local _, tractorAngle, _ = getWorldRotation(tractorNode)
	dx, _, dz = localDirectionToWorld(tractorNode, 0, 0, -1)
	tractorAngle = MathUtil.getYRotationFromDirection(dx, dz)

	local currentHitchAngle = getDeltaAngle(tractorAngle, trailerAngle)
	local curvature = ( 2 * math.sin(currentHitchAngle / 2 )) / calcDistanceFrom(tractorNode, trailerNode)
	local curvatureError = currentWp.curvature - curvature
	local hitchAngle = -0.2 * crossTrackError + 0.4 * orientationError + 0.1 * curvatureError
	local correctionAngle = -(hitchAngle - currentHitchAngle)

	local text = string.format('xte=%.1f oe=%.1f ce=%.1f current=%.1f reference=%.1f correction=%.1f',
			crossTrackError, math.deg(orientationError), curvatureError, math.deg(currentHitchAngle), math.deg(hitchAngle), math.deg(correctionAngle))
	print(text)
	setTextColor(1, 1, 0, 1)
	renderText(0.3, 0.3, 0.015, text)

	return correctionAngle
end