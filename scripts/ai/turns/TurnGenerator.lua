local abs, min, max, floor, ceil, square, pi, rad, deg = math.abs, math.min, math.max, math.floor, math.ceil, math.sqrt, math.pi, math.rad, math.deg
---@class TurnGenerator
TurnGenerator = CpObject()
TurnGenerator.wpDistance = 1.5  -- Waypoint Distance in Straight lines

function TurnGenerator:init(vehicle, turnContext)
	self.turnContext = turnContext
	self.self.vehicle = self.vehicle
	self.waypoints = {}
end

function TurnGenerator:debug(...)
	CpUtil.debugself.vehicle(DBG_TURN, self.self.vehicle, ...)	
end

function TurnGenerator:generateStraightSection(fromPoint, toPoint, reverse, turnEnd, secondaryReverseDistance, changeDirectionWhenAligned, doNotAddLastPoint)
	local endTurn = false
	local dist = MathUtil.getPointPointDistance(fromPoint.x, fromPoint.z, toPoint.x, toPoint.z)
	local numPointsNeeded = math.ceil(dist / TurnGenerator.wpDistance)
	local dx, dz = (toPoint.x - fromPoint.x) / dist, (toPoint.z - fromPoint.z) / dist

	if turnEnd == true then
		endTurn = turnEnd
	end

	-- add first point
	TurnGenerator:addTurnTarget(fromPoint.x, fromPoint.z, endTurn, reverse, nil, changeDirectionWhenAligned)

	-- add points between the first and last
	local x, z
	if numPointsNeeded > 1 then
		TurnGenerator.wpDistance = dist / numPointsNeeded
		for i=1, numPointsNeeded - 1 do
			x = fromPoint.x + (i * TurnGenerator.wpDistance * dx)
			z = fromPoint.z + (i * TurnGenerator.wpDistance * dz)

			TurnGenerator:addTurnTarget(x, z, endTurn, reverse, nil, changeDirectionWhenAligned)
		end
	end

	if doNotAddLastPoint then return end

	-- add last point
	local revx, revz
	if reverse and secondaryReverseDistance then
		revx = toPoint.x + (secondaryReverseDistance * dx)
		revz = toPoint.z + (secondaryReverseDistance * dz)
	end

	x = toPoint.x
	z = toPoint.z

	TurnGenerator.addTurnTarget(self.vehicle, x, z, endTurn, reverse, revx, revz, nil, changeDirectionWhenAligned)

end

-- startDir and stopDir are points (x,z). The arc starts where the line from the center of the circle
-- to startDir intersects the circle and ends where the line from the center of the circle to stopDir
-- intersects the circle.
--
function TurnGenerator:generateTurnCircle(center, startDir, stopDir, radius, clockwise, addEndPoint, reverse)
	-- Convert clockwise to the right format
	if clockwise == nil then clockwise = 1 end
	if clockwise == false or clockwise < 0 then
		clockwise = -1
	else
		clockwise = 1
	end

	-- Define some basic values to use
	local numWP 		= 1
	local degreeToTurn	= 0
	local wpDistance	= 1
	local degreeStep	= 360 / (2 * radius * math.pi) * wpDistance
	local startRot		= 0
	local endRot		= 0

	-- Get the start and end rotation
	local dx, dz = MathUtil.getPointPointDistance(center, startDir, false)
	startRot = deg(MathUtil.getYRotationFromDirection(dx, dz))
	dx, dz = MathUtil.getPointPointDistance(center, stopDir, false)
	endRot = deg(MathUtil.getYRotationFromDirection(dx, dz))

	-- Create new transformGroupe to use for placing waypoints
	local point = createTransformGroup("cpTempGenerateTurnCircle")
	link(g_currentMission.terrainRootNode, point)

	-- Move the point to the center
	local cY = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, center.x, 300, center.z)
	setTranslation(point, center.x, cY, center.z)

	-- Rotate it to the start direction
	setRotation(point, 0, rad(startRot), 0)

	-- Fix the rotation values in some special cases
	if clockwise == 1 then
		--(Turn:generateTurnCircle) startRot=90, endRot=-29, degreeStep=20, degreeToTurn=240, clockwise=1
		if startRot > endRot then
			degreeToTurn = endRot + 360 - startRot
		else
			degreeToTurn = endRot - startRot
		end
	else
		--(Turn:generateTurnCircle) startRot=150, endRot=90, degreeStep=-20, degreeToTurn=60, clockwise=-1
		if startRot < endRot then
			degreeToTurn = startRot + 360 - endRot
		else
			degreeToTurn = startRot - endRot
		end
	end
	courseplay:debug(string.format("%s:(Turn:generateTurnCircle) startRot=%d, endRot=%d, degreeStep=%d, degreeToTurn=%d, clockwise=%d", nameNum(self.vehicle), startRot, endRot, (degreeStep * clockwise), degreeToTurn, clockwise), courseplay.DBG_TURN)

	-- Get the number of waypoints
	numWP = ceil(degreeToTurn / degreeStep)
	-- Recalculate degreeStep
	degreeStep = (degreeToTurn / numWP) * clockwise
	-- Add extra waypoint if addEndPoint is true
	if addEndPoint then numWP = numWP + 1 end

	courseplay:debug(string.format("%s:(Turn:generateTurnCircle) numberOfWaypoints=%d, newDegreeStep=%d", nameNum(self.vehicle), numWP, degreeStep), courseplay.DBG_TURN)

	-- Generate the waypoints
	local i = 1
	for i = 1, numWP, 1 do
		if i ~= 1 then
			local _,currentRot,_ = getRotation(point)
			local newRot = deg(currentRot) + degreeStep

			setRotation(point, 0, rad(newRot), 0)
		end

		local x,_,z = localToWorld(point, 0, 0, radius)
		TurnGenerator.addTurnTarget(self.vehicle, x, z, nil, reverse, nil, nil, true)

		local _,rot,_ = getRotation(point)
		courseplay:debug(string.format("%s:(Turn:generateTurnCircle) waypoint %d curentRotation=%d", nameNum(self.vehicle), i, deg(rot)), courseplay.DBG_TURN)
	end

	-- Clean up the created node.
	unlink(point)
	delete(point)
end

function TurnGenerator.addTurnTarget(x, z, turnEnd, reverse, dontPrint, changeDirectionWhenAligned)
	local target = {}
	target.x = x
	target.z = z
	target.turnEnd = turnEnd
	target.reverse = reverse
	target.changeDirectionWhenAligned = changeDirectionWhenAligned
	table.insert(self.vehicle.cp.turnTargets, target)

	if not dontPrint then
		CpUtil.debugFormat(("%s:(Turn:addTurnTarget %d) x=%.2f, z=%.2f, turnEnd=%s, reverse=%s, changeDirectionWhenAligned=%s",
			nameNum(self.vehicle), #self.vehicle.cp.turnTargets, x, z,
			tostring(turnEnd and true or false), tostring(reverse and true or false), 
			tostring(changeDirectionWhenAligned and true or false))
	end
end

------------------------------------------------------------------------
-- Drive past turnEnd, up to implement width from the edge of the field (or current headland), raise implements, then
-- reverse back straight, then forward on a curve, then back up to the corner, lower implements there.
------------------------------------------------------------------------
function courseplay.generateTurnTypeHeadlandCornerReverseStraightTractor(turnInfo)
	courseplay.debugLine(courseplay.DBG_TURN, 3)
	courseplay:debug(string.format("%s:(Turn) Using Headland Corner Reverse Turn for tractors", nameNum(self.vehicle)), courseplay.DBG_TURN)
	courseplay.debugLine(courseplay.DBG_TURN, 3)

	local fromPoint, toPoint = {}, {}
	local centerForward = self.vehicle.cp.turnCorner:getArcCenter()
	courseplay:debug(("%s:(Turn) TurnGenerator.generateTurnTypeHeadlandCornerReverseStraightTractor(), fwdCircle( %.2f %.2f ), deltaAngle %.2f"):format(
		nameNum(self.vehicle), centerForward.x, centerForward.z, math.deg( turnInfo.deltaAngle )), 14)

	local helperNode = courseplay.createNode('tmp', 0, 0, 0, turnInfo.directionNode)

	-- drive forward until our implement reaches the headland after the turn
	fromPoint.x, _, fromPoint.z = localToWorld( helperNode, 0, 0, 0 )
	-- drive forward only until our implement reaches the headland area after the turn so we leave an unworked area here at the corner
	local workWidth = self.vehicle.cp.courseGeneratorSettings.workWidth:get()
	toPoint = self.vehicle.cp.turnCorner:getPointAtDistanceFromCornerStart((workWidth / 2) + turnInfo.frontMarker - turnInfo.wpChangeDistance)
	-- is this now in front of us? We may not need to drive forward
	local dx, dy, dz = worldToLocal( helperNode, toPoint.x, toPoint.y, toPoint.z )
	-- at which waypoint we have to raise the implement
	if dz > 0 then
		courseplay:debug(("%s:(Turn) TurnGenerator.generateTurnTypeHeadlandCornerReverseStraightTractor(), now driving forward so implement reaches headland"):format( nameNum( self.vehicle )), courseplay.DBG_TURN )
		TurnGenerator.generateStraightSection( self.vehicle, fromPoint, toPoint, false )
		setTranslation(helperNode, dx, dy, dz)
	end
	-- in reverse our reference point is the implement's turn node so put the first reverse waypoint behind us
	fromPoint.x, _, fromPoint.z = localToWorld( turnInfo.directionNode, 0, 0, - turnInfo.directionNodeToTurnNodeLength )

	-- allow for a little buffer so we can straighten out the implement
	local buffer = turnInfo.directionNodeToTurnNodeLength * 0.8

	-- now back up so the tractor is at the start of the arc
	toPoint = self.vehicle.cp.turnCorner:getPointAtDistanceFromArcStart(turnInfo.directionNodeToTurnNodeLength + turnInfo.reverseWPChangeDistance + buffer)
	-- helper node is where we would be at this point of the turn, so check if next target is behind or in front of us
	_, _, dz = worldToLocal( helperNode, toPoint.x, toPoint.y, toPoint.z )
	courseplay.destroyNode(helperNode)
	courseplay:debug(("%s:(Turn) TurnGenerator.generateTurnTypeHeadlandCornerReverseStraightTractor(), from ( %.2f %.2f ), to ( %.2f %.2f) workWidth: %.1f, dz = %.1f"):format(
		nameNum(self.vehicle), fromPoint.x, fromPoint.z, toPoint.x, toPoint.z, workWidth, dz ), 14)
	TurnGenerator.generateStraightSection(self.vehicle, fromPoint, toPoint, dz < 0)

	-- Generate turn circle (Forward)
	local startDir = self.vehicle.cp.turnCorner:getArcStart()
	local stopDir = self.vehicle.cp.turnCorner:getArcEnd()
	TurnGenerator.generateTurnCircle( self.vehicle, centerForward, startDir, stopDir, turnInfo.turnRadius, turnInfo.direction * -1, true)

	-- Drive forward until our implement reaches the circle end and a bit more so it is hopefully aligned with the tractor
	-- and we can start reversing more or less straight.
	fromPoint = self.vehicle.cp.turnCorner:getPointAtDistanceFromArcEnd((turnInfo.directionNodeToTurnNodeLength + turnInfo.wpChangeDistance + buffer) * 0.2)
	toPoint = self.vehicle.cp.turnCorner:getPointAtDistanceFromArcEnd(turnInfo.directionNodeToTurnNodeLength + turnInfo.wpChangeDistance + buffer)
	courseplay:debug(("%s:(Turn) TurnGenerator.generateTurnTypeHeadlandCornerReverseStraightTractor(), from ( %.2f %.2f ), to ( %.2f %.2f)"):format(
		nameNum(self.vehicle), fromPoint.x, fromPoint.z, toPoint.x, toPoint.z), 14)
	TurnGenerator.generateStraightSection(self.vehicle, fromPoint, toPoint, false, false )

	-- now back up the implement to the edge of the field (or headland)
	fromPoint = self.vehicle.cp.turnCorner:getArcEnd()

	if turnInfo.reversingWorkTool and turnInfo.reversingWorkTool.cp.realTurningNode then
		-- with towed reversing tools the reference point is the tool, not the tractor so don't care about frontMarker and such
		toPoint = self.vehicle.cp.turnCorner:getPointAtDistanceFromCornerEnd(-(workWidth / 2) - turnInfo.reverseWPChangeDistance - 10)
	else
		toPoint = self.vehicle.cp.turnCorner:getPointAtDistanceFromCornerEnd(-(workWidth / 2) - turnInfo.frontMarker - turnInfo.reverseWPChangeDistance - 10)
	end

	TurnGenerator.generateStraightSection(self.vehicle, fromPoint, toPoint, true, true, turnInfo.reverseWPChangeDistance)

	-- lower the implement
	self.vehicle.cp.turnTargets[#self.vehicle.cp.turnTargets].lowerImplement = true

	--- Finish the turn
	toPoint = self.vehicle.cp.turnCorner:getPointAtDistanceFromArcEnd(3)
	-- add just one target well forward, making sure it is in front of the tractor
	--TurnGenerator.addTurnTarget(self.vehicle, toPoint.x, toPoint.z, true, false)
end

function courseplay:getTurnCircleTangentIntersectionPoints(cp, np, radius, leftTurn)
	local point = createTransformGroup("cpTempTurnCircleTangentIntersectionPoint")
	link(g_currentMission.terrainRootNode, point)

	-- Rotate it in the right direction
	local dx, dz = MathUtil.getPointPointDistance(cp, np, false)
	local yRot = MathUtil.getYRotationFromDirection(dx, dz)
	setRotation(point, 0, yRot, 0)

	if leftTurn then
		radius = radius * -1
	end

	-- Get the Tangent Intersection Point from start point.
	setTranslation(point, cp.x, 0, cp.z)
	cp.x, _, cp.z = localToWorld(point, radius, 0, 0)

	-- Get the Tangent Intersection Point from end point.
	setTranslation(point, np.x, 0, np.z)
	np.x, _, np.z = localToWorld(point, radius, 0, 0)

	-- Clean up the created node.
	unlink(point)
	delete(point)

	-- return the values.
	return cp, np
end

-- TODO: move this logic into the course
function courseplay:getLaneInfo(vehicle)
	local numLanes			= 1
	local onLaneNum			= 0
	for index, wP in ipairs(self.vehicle.Waypoints) do
		local isWorkArea = index >= self.vehicle.cp.startWork and index <= self.vehicle.cp.stopWork
		if (wP.generated or isWorkArea) and (not wP.lane or wP.lane >= 0) then
			if self.vehicle.cp.waypointIndex == index then
				onLaneNum = numLanes
			end

			if wP.turnStart then
				numLanes = numLanes + 1
			end
		end
	end

	courseplay:debug(("%s:(Turn) courseplay:getLaneInfo(), On Lane Nummber = %d, Number of Lanes = %d"):format(nameNum(self.vehicle), onLaneNum, numLanes), courseplay.DBG_TURN)
	return numLanes, onLaneNum
end

function courseplay:haveHeadlands(vehicle)
	return self.vehicle.cp.coursenumHeadlands and self.vehicle.cp.coursenumHeadlands > 0
end
