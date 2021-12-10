local abs, min, max, floor, ceil, square, pi, rad, deg = math.abs, math.min, math.max, math.floor, math.ceil, math.sqrt, math.pi, math.rad, math.deg
---@class TurnManeuver
TurnManeuver = CpObject()
TurnManeuver.wpDistance = 1.5  -- Waypoint Distance in Straight lines
TurnManeuver.wpChangeDistance 					= 3
TurnManeuver.reverseWPChangeDistance			= 5
TurnManeuver.reverseWPChangeDistanceWithTool	= 3
TurnManeuver.debugPrefix = '(Turn): '

--- Turn controls which can be placed on turn waypoints and control the execution of the turn maneuver.
-- Change direction when the implement is aligned with the tractor
-- value : boolean
TurnManeuver.CHANGE_DIRECTION_WHEN_ALIGNED = 'changeDirectionWhenAligned'
-- Change to forward when a given waypoint is reached (dz > 0 as we assume we are reversing)
-- value : index of waypoint to reach
TurnManeuver.CHANGE_TO_FWD_WHEN_REACHED = 'changeToFwdWhenReached'

---@param course Course
function TurnManeuver.getTurnControl(course, ix, control)
	local controls = course:getTurnControls(ix)
	return controls and controls[control]
end

---@return boolean, number true if this is a towed reversing implement/steeringLength
function TurnManeuver.getSteeringParameters(vehicle)
	local implement = AIUtil.getFirstReversingImplementWithWheels(vehicle)
	if not implement then
		return false, 0
	else
		return true, AIUtil.getTowBarLength(vehicle)
	end
end

---@param vehicle table only used for debug, to get the name of the vehicle
---@param turnContext TurnContext
---@param vehicleDirectionNode number Giants node, pointing in the vehicle's front direction
---@param turningRadius number
---@param workWidth number
---@param steeringLength number distance between the tractor's rear axle and the towed implement/trailer's rear axle,
--- roughly tells how far we need to pull ahead (or back) relative to our target until the entire rig reaches that target.
function TurnManeuver:init(vehicle, turnContext, vehicleDirectionNode, turningRadius, workWidth, steeringLength)
	self.vehicleDirectionNode = vehicleDirectionNode
	self.turnContext = turnContext
	self.vehicle = vehicle
	self.waypoints = {}
	self.turningRadius = turningRadius
	self.workWidth = workWidth
	self.steeringLength = steeringLength
	self.direction = turnContext:isLeftTurn() and -1 or 1
	-- how far the furthest point of the maneuver is from the vehicle's direction node, used to
	-- check if we can turn on the field
	self.dzMax = -math.huge
end

function TurnManeuver:getCourse()
	return self.course
end

function TurnManeuver:debug(...)
	CpUtil.debugVehicle(CpDebug.DBG_TURN, self.vehicle, self.debugPrefix .. string.format(...))
end

---@param course Course
function TurnManeuver:getDzMax(course)
	local dzMax = -math.huge
	for ix = 1, course:getNumberOfWaypoints() do
		local _, _, dz = course:getWaypointLocalPosition(self.vehicleDirectionNode, ix)
		dzMax = dz > dzMax and dz or dzMax
	end
	return dzMax
end

function TurnManeuver:generateStraightSection(fromPoint, toPoint, reverse, turnEnd,
											  secondaryReverseDistance, doNotAddLastPoint)
	local endTurn = false
	local dist = MathUtil.getPointPointDistance(fromPoint.x, fromPoint.z, toPoint.x, toPoint.z)
	local numPointsNeeded = math.ceil(dist / TurnManeuver.wpDistance)
	local dx, dz = (toPoint.x - fromPoint.x) / dist, (toPoint.z - fromPoint.z) / dist

	if turnEnd == true then
		endTurn = turnEnd
	end


	-- add first point
	self:addWaypoint(fromPoint.x, fromPoint.z, endTurn, reverse, nil)
	local fromIx = #self.waypoints

	-- add points between the first and last
	local x, z
	if numPointsNeeded > 1 then
		local wpDistance = dist / numPointsNeeded
		for i = 1, numPointsNeeded - 1 do
			x = fromPoint.x + (i * wpDistance * dx)
			z = fromPoint.z + (i * wpDistance * dz)

			self:addWaypoint(x, z, endTurn, reverse, nil)
		end
	end

	if doNotAddLastPoint then return fromIx, #self.waypoints end

	-- add last point
	local revx, revz
	if reverse and secondaryReverseDistance then
		revx = toPoint.x + (secondaryReverseDistance * dx)
		revz = toPoint.z + (secondaryReverseDistance * dz)
	end

	x = toPoint.x
	z = toPoint.z

	self:addWaypoint(x, z, endTurn, reverse, revx, revz, nil)
	return fromIx, #self.waypoints
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
	self:debug("generateTurnCircle: startRot=%d, endRot=%d, degreeStep=%d, degreeToTurn=%d, clockwise=%d",
		startRot, endRot, (degreeStep * clockwise), degreeToTurn, clockwise)

	-- Get the number of waypoints
	numWP = ceil(degreeToTurn / degreeStep)
	-- Recalculate degreeStep
	degreeStep = (degreeToTurn / numWP) * clockwise
	-- Add extra waypoint if addEndPoint is true
	if addEndPoint then numWP = numWP + 1 end

	self:debug("generateTurnCircle: numberOfWaypoints=%d, newDegreeStep=%d", numWP, degreeStep)

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
		self:debug("generateTurnCircle: waypoint %d curentRotation=%d", i, deg(rot))
	end

	-- Clean up the created node.
	unlink(point)
	delete(point)
end

function TurnManeuver:addWaypoint(x, z, turnEnd, reverse, dontPrint)
	local wp = {}
	wp.x = x
	wp.z = z
	wp.turnEnd = turnEnd
	wp.reverse = reverse
	table.insert(self.waypoints, wp)
	local dz = worldToLocal(self.vehicleDirectionNode, wp.x, 0, wp.z)
	self.dzMax = dz > self.dzMax and dz or self.dzMax
	if not dontPrint then
		self:debug("addWaypoint %d: x=%.2f, z=%.2f, dz=%.1f, turnEnd=%s, reverse=%s",
			#self.waypoints, x, z, dz,
			tostring(turnEnd and true or false), tostring(reverse and true or false))
	end
end

function TurnManeuver:addTurnControl(fromIx, toIx, control, value)
	self:debug('addTurnControl %d - %d %s %s', fromIx, toIx, control, tostring(value))
	for i = fromIx, toIx do
		if not self.waypoints[i].turnControls then
			self.waypoints[i].turnControls = {}
		end
		self.waypoints[i].turnControls[control] = value
	end
end

---@param course Course
---@param dBack number distance in meters to move the course back (positive moves it backwards!)
function TurnManeuver:moveCourseBack(course, dBack)
	-- move at least one meter
	dBack = dBack < 1 and 1 or dBack
	self:debug('moving course: dz=%.1f', dBack)
	-- generate a straight reverse section first
	local reverseBeforeTurn = Course.createFromNode(self.vehicle, self.turnContext.workEndNode,
		0, -self.steeringLength, -self.steeringLength - dBack, -1, true)
	local dx, dz = reverseBeforeTurn:getWaypointWorldDirections(1)
	self:debug('translating turn course: dx=%.1f, dz=%.1f', dx * dBack, dz * dBack)
	course:translate(dx * dBack, dz * dBack)
	reverseBeforeTurn:append(course)
	-- the last waypoint of the course after it was translated
	local _, _, dFromTurnEnd = course:getWaypointLocalPosition(self.turnContext.vehicleAtTurnEndNode, course:getNumberOfWaypoints())
	if dFromTurnEnd > 0 then
		local reverseAfterTurn = Course.createFromNode(self.vehicle, self.turnContext.vehicleAtTurnEndNode,
			0, dFromTurnEnd - self.steeringLength, -self.steeringLength, -1, true)
		reverseBeforeTurn:append(reverseAfterTurn)
	end
	return reverseBeforeTurn
end

---@class AnalyticTurnManeuver : TurnManuever
AnalyticTurnManeuver = CpObject(TurnManeuver)
function AnalyticTurnManeuver:init(vehicle, turnContext, vehicleDirectionNode, turningRadius, workWidth, steeringLength, distanceToFieldEdge)
	TurnManeuver.init(self, vehicle, turnContext, vehicleDirectionNode, turningRadius, workWidth, steeringLength)
	self:debug('Start generating')
	self:debug('r=%.1f, w=%.1f, steeringLength=%.1f, distanceToFieldEdge=%.1f',
		turningRadius, workWidth, steeringLength, distanceToFieldEdge)

	local turnEndNode, startOffset, goalOffset = self.turnContext:getTurnEndNodeAndOffsets(self.vehicle)

	self.course = self:findAnalyticPath(vehicleDirectionNode, startOffset, turnEndNode, 0, goalOffset, self.turningRadius)

	-- make sure we use tight turn offset towards the end of the course so a towed implement is aligned with the new row
	self.course:setUseTightTurnOffsetForLastWaypoints(10)
	self.turnContext:appendEndingTurnCourse(self.course)
	-- and once again, if there is an ending course, keep adjusting the tight turn offset
	-- TODO: should probably better done on onWaypointChange, to reset to 0
	self.course:setUseTightTurnOffsetForLastWaypoints(10)

	local dzMax = self:getDzMax(self.course)
	local spaceNeededOnFieldForTurn = dzMax + workWidth / 2
	distanceToFieldEdge = distanceToFieldEdge or 500  -- if not given, assume we have a lot of space
	self:debug('dzMax=%.1f, workWidth=%.1f, spaceNeeded=%.1f, distanceToFieldEdge=%.1f',
		dzMax, workWidth, spaceNeededOnFieldForTurn, distanceToFieldEdge)
	if distanceToFieldEdge < spaceNeededOnFieldForTurn then
		self.course = self:moveCourseBack(self.course, spaceNeededOnFieldForTurn - distanceToFieldEdge)
	end
	self.course:setTurnEndForLastWaypoints(5)
end

---@class DubinsTurnManeuver : AnalyticTurnManeuver
DubinsTurnManeuver = CpObject(AnalyticTurnManeuver)

function DubinsTurnManeuver:init(vehicle, turnContext, vehicleDirectionNode, turningRadius,
								 workWidth, steeringLength, distanceToFieldEdge)
	self.debugPrefix = '(DubinsTurn): '
	AnalyticTurnManeuver.init(self, vehicle, turnContext, vehicleDirectionNode, turningRadius,
		workWidth, steeringLength, distanceToFieldEdge)
end

function DubinsTurnManeuver:findAnalyticPath(vehicleDirectionNode, startOffset, turnEndNode,
											 xOffset, goalOffset, turningRadius)
	local path = PathfinderUtil.findAnalyticPath(PathfinderUtil.dubinsSolver,
		vehicleDirectionNode, startOffset, turnEndNode, 0, goalOffset, self.turningRadius)
	return Course(self.vehicle, CourseGenerator.pointsToXzInPlace(path), true)
end

---@class LeftTurnReedsSheppSolver : ReedsSheppSolver
LeftTurnReedsSheppSolver = CpObject(ReedsSheppSolver)
function LeftTurnReedsSheppSolver:solve(start, goal, turnRadius)
	return ReedsSheppSolver.solve(self, start, goal, turnRadius, {ReedsShepp.PathWords.LfRbLf})
end

---@class RightTurnReedsSheppSolver : ReedsSheppSolver
RightTurnReedsSheppSolver = CpObject(ReedsSheppSolver)
function RightTurnReedsSheppSolver:solve(start, goal, turnRadius)
	return ReedsSheppSolver.solve(self, start, goal, turnRadius, {ReedsShepp.PathWords.RfLbRf})
end

---@class ReedsSheppTurnManeuver : AnalyticTurnManeuver
ReedsSheppTurnManeuver = CpObject(AnalyticTurnManeuver)

function ReedsSheppTurnManeuver:init(vehicle, turnContext, vehicleDirectionNode, turningRadius,
								 workWidth, steeringLength, distanceToFieldEdge)
	self.debugPrefix = '(ReedsSheppTurn): '
	AnalyticTurnManeuver.init(self, vehicle, turnContext, vehicleDirectionNode, turningRadius,
		workWidth, steeringLength, distanceToFieldEdge)
end

function ReedsSheppTurnManeuver:findAnalyticPath(vehicleDirectionNode, startOffset, turnEndNode,
											 xOffset, goalOffset, turningRadius)
	local solver
	if self.turnContext:isLeftTurn() then
		self:debug('using LeftTurnReedsSheppSolver')
		solver = LeftTurnReedsSheppSolver()
	else
		self:debug('using RightTurnReedsSheppSolver')
		solver = RightTurnReedsSheppSolver()
	end
	local path = PathfinderUtil.findAnalyticPath(solver, vehicleDirectionNode, startOffset, turnEndNode,
		0, goalOffset, self.turningRadius)
	local course = Course(self.vehicle, CourseGenerator.pointsToXzInPlace(path), true)
	course:print()
	course:adjustForTowedImplements(1.5 * self.steeringLength)
	course:print()
	return course
end

---@class HeadlandCornerTurnManeuver : TurnManeuver
HeadlandCornerTurnManeuver = CpObject(TurnManeuver)

------------------------------------------------------------------------
-- Drive past turnEnd, up to implement width from the edge of the field (or current headland), raise implements, then
-- reverse back straight, then forward on a curve, then back up to the corner, lower implements there.
------------------------------------------------------------------------
---@param turnContext TurnContext
function HeadlandCornerTurnManeuver:init(vehicle, turnContext, vehicleDirectionNode, turningRadius, workWidth,
										 reversingWorkTool, steeringLength)
	TurnManeuver.init(self, vehicle, turnContext, vehicleDirectionNode, turningRadius, workWidth, steeringLength)
	self.debugPrefix = '(HeadlandTurn): '
	self:debug('Start generating')
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
		self:debug("now driving forward so implement reaches headland")
		self:generateStraightSection(fromPoint, toPoint, false )
		setTranslation(helperNode, dx, dy, dz)
	end
	-- in reverse our reference point is the implement's turn node so put the first reverse waypoint behind us
	fromPoint.x, _, fromPoint.z = localToWorld(self.vehicleDirectionNode, 0, 0, - self.steeringLength )

	-- allow for a little buffer so we can straighten out the implement
	local buffer = self.steeringLength * 0.8

	-- now back up so the tractor is at the start of the arc
	toPoint = corner:getPointAtDistanceFromArcStart(self.steeringLength + self.reverseWPChangeDistance + buffer)
	-- helper node is where we would be at this point of the turn, so check if next target is behind or in front of us
	_, _, dz = worldToLocal( helperNode, toPoint.x, toPoint.y, toPoint.z )
	CpUtil.destroyNode(helperNode)
	self:debug("from ( %.2f %.2f ), to ( %.2f %.2f) workWidth: %.1f, dz = %.1f",
		fromPoint.x, fromPoint.z, toPoint.x, toPoint.z, self.workWidth, dz )
	local fromIx, toIx = self:generateStraightSection( fromPoint, toPoint, dz < 0)
	-- this is where the arc will begin, and once the tractor reaches it, can switch to forward
	local changeToFwdIx = #self.waypoints + 1
	-- Generate turn circle (Forward)
	local startDir = corner:getArcStart()
	local stopDir = corner:getArcEnd()
	self:generateTurnCircle(centerForward, startDir, stopDir, self.turningRadius, self.direction * -1, true)
	self:addTurnControl(fromIx, toIx, TurnManeuver.CHANGE_TO_FWD_WHEN_REACHED, changeToFwdIx)

	-- Drive forward until our implement reaches the circle end and a bit more so it is hopefully aligned with the tractor
	-- and we can start reversing more or less straight.
	fromPoint = corner:getPointAtDistanceFromArcEnd((self.steeringLength + self.wpChangeDistance + buffer) * 0.2)
	toPoint = corner:getPointAtDistanceFromArcEnd(self.steeringLength + self.wpChangeDistance + buffer)
	self:debug("from ( %.2f %.2f ), to ( %.2f %.2f)",
		fromPoint.x, fromPoint.z, toPoint.x, toPoint.z)

	fromIx, toIx = self:generateStraightSection(fromPoint, toPoint, false, false, 0, true)
	self:addTurnControl(fromIx, toIx, TurnManeuver.CHANGE_DIRECTION_WHEN_ALIGNED, true)

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
	self.course = Course(vehicle, self.waypoints, true)
end
