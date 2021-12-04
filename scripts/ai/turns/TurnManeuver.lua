local abs, min, max, floor, ceil, square, pi, rad, deg = math.abs, math.min, math.max, math.floor, math.ceil, math.sqrt, math.pi, math.rad, math.deg
---@class TurnManeuver
TurnManeuver = CpObject()
TurnManeuver.wpDistance = 1.5  -- Waypoint Distance in Straight lines
TurnManeuver.wpChangeDistance 					= 3
TurnManeuver.reverseWPChangeDistance			= 5
TurnManeuver.reverseWPChangeDistanceWithTool	= 3

---@param vehicle table only used for debug, to get the name of the vehicle
---@param turnContext TurnContext
---@param vehicleDirectionNode number Giants node, pointing in the vehicle's front direction
---@param turningRadius number
---@param workWidth number
function TurnManeuver:init(vehicle, turnContext, vehicleDirectionNode, turningRadius, workWidth, directionNodeToTurnNodeLength)
	self.vehicleDirectionNode = vehicleDirectionNode
	self.turnContext = turnContext
	self.vehicle = vehicle
	self.waypoints = {}
	self.turningRadius = turningRadius
	self.workWidth = workWidth
	-- TODO_22: calculate!
	self.directionNodeToTurnNodeLength = directionNodeToTurnNodeLength
	self.direction = turnContext:isLeftTurn() and -1 or 1
end

function TurnManeuver:getWaypoints()
	return self.waypoints
end

function TurnManeuver:debug(...)
	CpUtil.debugVehicle(DBG_TURN, self.vehicle, ...)
end

function TurnManeuver:generateStraightSection(fromPoint, toPoint, reverse, turnEnd,
											  secondaryReverseDistance, changeDirectionWhenAligned, doNotAddLastPoint)
	local endTurn = false
	local dist = MathUtil.getPointPointDistance(fromPoint.x, fromPoint.z, toPoint.x, toPoint.z)
	local numPointsNeeded = math.ceil(dist / TurnManeuver.wpDistance)
	local dx, dz = (toPoint.x - fromPoint.x) / dist, (toPoint.z - fromPoint.z) / dist

	if turnEnd == true then
		endTurn = turnEnd
	end

	-- add first point
	self:addWaypoint(fromPoint.x, fromPoint.z, endTurn, reverse, nil, changeDirectionWhenAligned)

	-- add points between the first and last
	local x, z
	if numPointsNeeded > 1 then
		local wpDistance = dist / numPointsNeeded
		for i=1, numPointsNeeded - 1 do
			x = fromPoint.x + (i * wpDistance * dx)
			z = fromPoint.z + (i * wpDistance * dz)

			self:addWaypoint(x, z, endTurn, reverse, nil, changeDirectionWhenAligned)
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

	self:addWaypoint(x, z, endTurn, reverse, revx, revz, nil, changeDirectionWhenAligned)
end

-- startDir and stopDir are points (x,z). The arc starts where the line from the center of the circle
-- to startDir intersects the circle and ends where the line from the center of the circle to stopDir
-- intersects the circle.
--
function TurnManeuver:generateTurnCircle(center, startDir, stopDir, radius, clockwise, addEndPoint, reverse)
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
	local dx, dz = CpMathUtil.getPointDirection(center, startDir, false)
	startRot = deg(MathUtil.getYRotationFromDirection(dx, dz))
	dx, dz = CpMathUtil.getPointDirection(center, stopDir, false)
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
	self:debug("(Turn:generateTurnCircle) startRot=%d, endRot=%d, degreeStep=%d, degreeToTurn=%d, clockwise=%d",
		startRot, endRot, (degreeStep * clockwise), degreeToTurn, clockwise)

	-- Get the number of waypoints
	numWP = ceil(degreeToTurn / degreeStep)
	-- Recalculate degreeStep
	degreeStep = (degreeToTurn / numWP) * clockwise
	-- Add extra waypoint if addEndPoint is true
	if addEndPoint then numWP = numWP + 1 end

	self:debug("(Turn:generateTurnCircle) numberOfWaypoints=%d, newDegreeStep=%d", numWP, degreeStep)

	-- Generate the waypoints
	for i = 1, numWP, 1 do
		if i ~= 1 then
			local _,currentRot,_ = getRotation(point)
			local newRot = deg(currentRot) + degreeStep

			setRotation(point, 0, rad(newRot), 0)
		end

		local x,_,z = localToWorld(point, 0, 0, radius)
		self:addWaypoint(x, z, nil, reverse, nil, nil, true)

		local _,rot,_ = getRotation(point)
		self:debug("(Turn:generateTurnCircle) waypoint %d curentRotation=%d", i, deg(rot))
	end

	-- Clean up the created node.
	unlink(point)
	delete(point)
end

function TurnManeuver:addWaypoint(x, z, turnEnd, reverse, dontPrint, changeDirectionWhenAligned)
	local wp = {}
	wp.x = x
	wp.z = z
	wp.turnEnd = turnEnd
	wp.reverse = reverse
	wp.changeDirectionWhenAligned = changeDirectionWhenAligned
	table.insert(self.waypoints, wp)

	if not dontPrint then
		self:debug("(Turn:addWaypoint %d) x=%.2f, z=%.2f, turnEnd=%s, reverse=%s, changeDirectionWhenAligned=%s",
			#self.waypoints, x, z,
			tostring(turnEnd and true or false), tostring(reverse and true or false), 
			tostring(changeDirectionWhenAligned and true or false))
	end
end

---@class HeadlandCornerTurnManeuver : TurnManeuver
HeadlandCornerTurnManeuver = CpObject(TurnManeuver)

------------------------------------------------------------------------
-- Drive past turnEnd, up to implement width from the edge of the field (or current headland), raise implements, then
-- reverse back straight, then forward on a curve, then back up to the corner, lower implements there.
------------------------------------------------------------------------
---@param turnContext TurnContext
function HeadlandCornerTurnManeuver:init(vehicle, turnContext, vehicleDirectionNode, turningRadius, workWidth,
										 reversingWorkTool, directionNodeToTurnNodeLength)
	TurnManeuver.init(self, vehicle, turnContext, vehicleDirectionNode, turningRadius, workWidth, directionNodeToTurnNodeLength)

	self:debug("(Turn) Using Headland Corner Reverse Turn for tractors")

	local fromPoint, toPoint = {}, {}

	local corner = turnContext:createCorner(vehicle, self.turningRadius)

	local centerForward = corner:getArcCenter()
	local helperNode = CpUtil.createNode('tmp', 0, 0, 0, self.vehicleDirectionNode)

	-- drive forward until our implement reaches the headland after the turn
	fromPoint.x, _, fromPoint.z = localToWorld( helperNode, 0, 0, 0 )
	-- drive forward only until our implement reaches the headland area after the turn so we leave an unworked area here at the corner
	toPoint = corner:getPointAtDistanceFromCornerStart((turnContext.workWidth / 2) + turnContext.frontMarkerDistance - self.wpChangeDistance)
	-- is this now in front of us? We may not need to drive forward
	local dx, dy, dz = worldToLocal( helperNode, toPoint.x, toPoint.y, toPoint.z )
	-- at which waypoint we have to raise the implement
	if dz > 0 then
		self:debug("(Turn) TurnGenerator.generateTurnTypeHeadlandCornerReverseStraightTractor(), now driving forward so implement reaches headland")
		self:generateStraightSection(fromPoint, toPoint, false )
		setTranslation(helperNode, dx, dy, dz)
	end
	-- in reverse our reference point is the implement's turn node so put the first reverse waypoint behind us
	fromPoint.x, _, fromPoint.z = localToWorld(self.vehicleDirectionNode, 0, 0, - self.directionNodeToTurnNodeLength )

	-- allow for a little buffer so we can straighten out the implement
	local buffer = self.directionNodeToTurnNodeLength * 0.8

	-- now back up so the tractor is at the start of the arc
	toPoint = corner:getPointAtDistanceFromArcStart(self.directionNodeToTurnNodeLength + self.reverseWPChangeDistance + buffer)
	-- helper node is where we would be at this point of the turn, so check if next target is behind or in front of us
	_, _, dz = worldToLocal( helperNode, toPoint.x, toPoint.y, toPoint.z )
	CpUtil.destroyNode(helperNode)
	self:debug("(Turn) TurnGenerator.generateTurnTypeHeadlandCornerReverseStraightTractor(), from ( %.2f %.2f ), to ( %.2f %.2f) workWidth: %.1f, dz = %.1f",
		fromPoint.x, fromPoint.z, toPoint.x, toPoint.z, self.workWidth, dz )
	self:generateStraightSection( fromPoint, toPoint, dz < 0)

	-- Generate turn circle (Forward)
	local startDir = corner:getArcStart()
	local stopDir = corner:getArcEnd()
	self:generateTurnCircle(centerForward, startDir, stopDir, self.turningRadius, self.direction * -1, true)

	-- Drive forward until our implement reaches the circle end and a bit more so it is hopefully aligned with the tractor
	-- and we can start reversing more or less straight.
	fromPoint = corner:getPointAtDistanceFromArcEnd((self.directionNodeToTurnNodeLength + self.wpChangeDistance + buffer) * 0.2)
	toPoint = corner:getPointAtDistanceFromArcEnd(self.directionNodeToTurnNodeLength + self.wpChangeDistance + buffer)
	self:debug("(Turn) TurnGenerator.generateTurnTypeHeadlandCornerReverseStraightTractor(), from ( %.2f %.2f ), to ( %.2f %.2f)",
		fromPoint.x, fromPoint.z, toPoint.x, toPoint.z)
	self:generateStraightSection(fromPoint, toPoint, false, false )

	-- now back up the implement to the edge of the field (or headland)
	fromPoint = corner:getArcEnd()

	if reversingWorkTool then
		-- with towed reversing tools the reference point is the tool, not the tractor so don't care about frontMarker and such
		toPoint = corner:getPointAtDistanceFromCornerEnd(-(self.workWidth / 2) - self.reverseWPChangeDistance - 10)
	else
		toPoint = corner:getPointAtDistanceFromCornerEnd(-(self.workWidth / 2) - turnContext.frontMarkerDistance - self.reverseWPChangeDistance - 10)
	end

	self:generateStraightSection(fromPoint, toPoint, true, true, self.reverseWPChangeDistance)

	-- lower the implement
	self.waypoints[#self.waypoints].lowerImplement = true
end
