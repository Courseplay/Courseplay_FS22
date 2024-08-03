local abs, min, max, floor, ceil, square, pi, rad, deg = math.abs, math.min, math.max, math.floor, math.ceil, math.sqrt, math.pi, math.rad, math.deg
---@class TurnManeuver
TurnManeuver = CpObject()
TurnManeuver.wpDistance = 1.5  -- Waypoint Distance in Straight lines
-- buffer to add to straight lines to allow for aligning, forward and reverse
TurnManeuver.forwardBuffer = 3
TurnManeuver.reverseBuffer = 5
TurnManeuver.debugPrefix = '(Turn): '

--- Turn controls which can be placed on turn waypoints and control the execution of the turn maneuver.
-- Change direction when the implement is aligned with the tractor
-- value : boolean
TurnManeuver.CHANGE_DIRECTION_WHEN_ALIGNED = 'changeDirectionWhenAligned'
-- Change to forward when a given waypoint is reached (dz > 0 as we assume we are reversing)
-- value : index of waypoint to reach
TurnManeuver.CHANGE_TO_FWD_WHEN_REACHED = 'changeToFwdWhenReached'
-- Ending turn, from here, lower implement whenever needed (depending on the lowering duration,
-- making sure it is lowered when we reach the start of the next row)
TurnManeuver.LOWER_IMPLEMENT_AT_TURN_END = 'lowerImplementAtTurnEnd'

---@param course Course
function TurnManeuver.hasTurnControl(course, ix, control)
	local controls = course:getTurnControls(ix)
	return controls and controls[control]
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
	local dist = MathUtil.getPointPointDistance(fromPoint.x, fromPoint.z, toPoint.x, toPoint.z)
	local numPointsNeeded = math.ceil(dist / TurnManeuver.wpDistance)
	local dx, dz = (toPoint.x - fromPoint.x) / dist, (toPoint.z - fromPoint.z) / dist

	-- add first point
	self:addWaypoint(fromPoint.x, fromPoint.z, turnEnd, reverse, nil)
	local fromIx = #self.waypoints

	-- add points between the first and last
	local x, z
	if numPointsNeeded > 1 then
		local wpDistance = dist / numPointsNeeded
		for i = 1, numPointsNeeded - 1 do
			x = fromPoint.x + (i * wpDistance * dx)
			z = fromPoint.z + (i * wpDistance * dz)

			self:addWaypoint(x, z, turnEnd, reverse, nil)
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

	self:addWaypoint(x, z, turnEnd, reverse, revx, revz, nil)
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
	if turnEnd then
		TurnManeuver.addTurnControlToWaypoint(wp, TurnManeuver.LOWER_IMPLEMENT_AT_TURN_END, true)
	end
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

function TurnManeuver.addTurnControlToWaypoint(wp, control, value)
	if not wp.turnControls then
		wp.turnControls = {}
	end
	wp.turnControls[control] = value
end

function TurnManeuver.addTurnControl(waypoints, fromIx, toIx, control, value)
	for i = fromIx, toIx do
		TurnManeuver.addTurnControlToWaypoint(waypoints[i], control, value)
	end
end

--- Set the given control to value for all waypoints of course within d meters of the course end
---@param stopAtDirectionChange boolean if we reach a direction change, stop there, the last waypoint the function
--- is called for is the one before the direction change
function TurnManeuver.setTurnControlForLastWaypoints(course, d, control, value, stopAtDirectionChange)
	course:executeFunctionForLastWaypoints(
			d,
			function(wp)
				TurnManeuver.addTurnControlToWaypoint(wp, control, value)
			end,
			stopAtDirectionChange)
end

--- Get the distance between the direction node of the vehicle and the reverser node (if there is one). This
--- is to make sure that when the course changes to reverse and there is a reverse node, the first reverse
--- waypoint is behind the reverser node. Otherwise we'll just keep backing up until the emergency brake is triggered.
function TurnManeuver:getReversingOffset()
	local reverserNode, debugText = AIUtil.getReverserNode(self.vehicle)
	if reverserNode then
		local _, _, dz = localToLocal(reverserNode, self.vehicleDirectionNode, 0, 0, 0)
		self:debug('Using reverser node (%s) distance %.1f', debugText, dz)
		return math.abs(dz)
	end
	return self.steeringLength
end

--- Set implement lowering control for the end of the turn
---@param stopAtDirectionChange boolean if we reach a direction change, stop there, the last waypoint the function
--- is called for is the one before the direction change
function TurnManeuver.setLowerImplements(course, distance, stopAtDirectionChange)
	TurnManeuver.setTurnControlForLastWaypoints(course, math.max(distance, 3) + 2,
			TurnManeuver.LOWER_IMPLEMENT_AT_TURN_END, true, stopAtDirectionChange)
end

-- Add reversing sections at the beginning and end of the turn, so the vehicle can make the turn without
-- leaving the field.
---@param course Course course already moved back a bit so it won't leave the field
---@param dBack number distance in meters to move the course back (positive moves it backwards!)
---@param ixBeforeEndingTurnSection number index of the last waypoint of the actual turn, if we can finish the turn
--- before we reach the vehicle position at turn end, there's no reversing needed at the turn end.
---@param endingTurnLength number length of the straight ending turn section into the next row
function TurnManeuver:adjustCourseToFitField(course, dBack, ixBeforeEndingTurnSection, endingTurnLength)
	self:debug('moving course back: d=%.1f', dBack)
	local reversingOffset = self:getReversingOffset()
	-- generate a straight reverse section first (less than 1 m step should make sure we always end up with
	-- at least two waypoints
	local courseWithReversing = Course.createFromNode(self.vehicle, self.vehicle:getAIDirectionNode(),
		0, -reversingOffset, -reversingOffset - dBack, -0.9, true)
	-- now add the actual turn, which has already been shifted back before this function was called
	courseWithReversing:append(course)
	-- the last waypoint of the course after it was translated
	local _, _, dFromTurnEnd = course:getWaypointLocalPosition(self.turnContext.vehicleAtTurnEndNode, ixBeforeEndingTurnSection)
	local _, _, dFromWorkStart = course:getWaypointLocalPosition(self.turnContext.workStartNode, ixBeforeEndingTurnSection)
	self:debug('Work start from curve end %.1f, vehicle at %.1f, %.1f between vehicle and work start)',
		dFromWorkStart, dFromTurnEnd, self.turnContext.turnEndForwardOffset)
	if self.turnContext.turnEndForwardOffset > 0 and math.max(dFromTurnEnd, dFromWorkStart) > -self.steeringLength then
		self:debug('Reverse to work start (implement in back)')
		-- vehicle in front of the work start node at turn end
		-- allow early direction change when aligned
		TurnManeuver.setTurnControlForLastWaypoints(courseWithReversing, endingTurnLength,
			TurnManeuver.CHANGE_DIRECTION_WHEN_ALIGNED, true, true)
		-- go all the way to the back marker distance so there's plenty of room for lower early too, also, the
		-- reversingOffset may be even behind the back marker, especially for vehicles which have a AIToolReverserDirectionNode
		-- which is then used as the PPC controlled node, and thus it must be far enough that we reach the lowering
		-- point before the controlled node reaches the end of the course
		local reverseAfterTurn = Course.createFromNode(self.vehicle, self.turnContext.vehicleAtTurnEndNode,
			0, dFromTurnEnd + self.steeringLength,
			math.min(dFromTurnEnd, self.turnContext.backMarkerDistance, -reversingOffset), -0.8, true)
		courseWithReversing:append(reverseAfterTurn)
	elseif self.turnContext.turnEndForwardOffset <= 0 and dFromTurnEnd >= 0 then
		self:debug('Reverse to work start (implement in front)')
		-- the work start is in front of the vehicle at the turn end
		TurnManeuver.setTurnControlForLastWaypoints(courseWithReversing, endingTurnLength,
			TurnManeuver.CHANGE_DIRECTION_WHEN_ALIGNED, true, true)
		local reverseAfterTurn = Course.createFromNode(self.vehicle, self.turnContext.workStartNode,
			0, -reversingOffset, -reversingOffset + self.turnContext.turnEndForwardOffset, -1, true)
		courseWithReversing:append(reverseAfterTurn)
	end
	return courseWithReversing
end

---@class AnalyticTurnManeuver : TurnManeuver
AnalyticTurnManeuver = CpObject(TurnManeuver)
function AnalyticTurnManeuver:init(vehicle, turnContext, vehicleDirectionNode, turningRadius, workWidth, steeringLength, distanceToFieldEdge)
	TurnManeuver.init(self, vehicle, turnContext, vehicleDirectionNode, turningRadius, workWidth, steeringLength)
	self:debug('Start generating')
	self:debug('r=%.1f, w=%.1f, steeringLength=%.1f, distanceToFieldEdge=%.1f',
		turningRadius, workWidth, steeringLength, distanceToFieldEdge)

	local turnEndNode, goalOffset = self.turnContext:getTurnEndNodeAndOffsets(self.steeringLength)
	self.course = self:findAnalyticPath(vehicleDirectionNode, 0, turnEndNode, 0, goalOffset, self.turningRadius)
	local endingTurnLength
	local dzMax = self:getDzMax(self.course)
	local spaceNeededOnFieldForTurn = dzMax + workWidth / 2
	distanceToFieldEdge = distanceToFieldEdge or 500  -- if not given, assume we have a lot of space
	local dBack = spaceNeededOnFieldForTurn - distanceToFieldEdge
	local canReverse = AIUtil.canReverse(vehicle)
	if dBack > 0 and canReverse then
		dBack = dBack < 2 and 2 or dBack
		self:debug('Not enough space on field, regenerating course back %.1f meters', dBack)
		self.course = self:findAnalyticPath(vehicleDirectionNode, -dBack, turnEndNode, 0, goalOffset + dBack, self.turningRadius)
		self.course:setUseTightTurnOffsetForLastWaypoints(
				g_vehicleConfigurations:getRecursively(vehicle, 'tightTurnOffsetDistanceInTurns') or 10)
		local ixBeforeEndingTurnSection = self.course:getNumberOfWaypoints()
		endingTurnLength = self.turnContext:appendEndingTurnCourse(self.course, steeringLength, true)
		self:debug('dzMax=%.1f, workWidth=%.1f, spaceNeeded=%.1f, distanceToFieldEdge=%.1f, ixBeforeEndingTurnSection=%d, canReverse=%s',
				dzMax, workWidth, spaceNeededOnFieldForTurn, distanceToFieldEdge, ixBeforeEndingTurnSection, canReverse)
		self.course = self:adjustCourseToFitField(self.course, dBack, ixBeforeEndingTurnSection, endingTurnLength)
	else
		endingTurnLength = self.turnContext:appendEndingTurnCourse(self.course, steeringLength, true)
	end
	-- make sure we use tight turn offset towards the end of the course so a towed implement is aligned with the new row
	self.course:setUseTightTurnOffsetForLastWaypoints(
			g_vehicleConfigurations:getRecursively(vehicle, 'tightTurnOffsetDistanceInTurns') or 10)
	TurnManeuver.setLowerImplements(self.course, endingTurnLength, true)
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
	return Course.createFromAnalyticPath(self.vehicle, path, true)
end

---@class LeftTurnReedsSheppSolver : ReedsSheppSolver
LeftTurnReedsSheppSolver = CpObject(ReedsSheppSolver)
function LeftTurnReedsSheppSolver:solve(start, goal, turnRadius)
	return ReedsSheppSolver.solve(self, start, goal, turnRadius, {ReedsShepp.PathWords.LfRbLf})
end

---@class LeftTurnReverseReedsSheppSolver : ReedsSheppSolver
LeftTurnReverseReedsSheppSolver = CpObject(ReedsSheppSolver)
function LeftTurnReverseReedsSheppSolver:solve(start, goal, turnRadius)
	return ReedsSheppSolver.solve(self, start, goal, turnRadius, {ReedsShepp.PathWords.LbSbLb})
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
	if not path or #path == 0 then
		self:debug('Could not find ReedsShepp path, retry with Dubins')
		path = PathfinderUtil.findAnalyticPath(PathfinderUtil.dubinsSolver, vehicleDirectionNode, startOffset,
				turnEndNode, 0, goalOffset, self.turningRadius)
	end
	local course = Course.createFromAnalyticPath(self.vehicle, path, true)
	course:adjustForTowedImplements(1.5 * self.steeringLength + 1)
	return course
end

---@class TurnEndingManeuver : TurnManeuver
TurnEndingManeuver = CpObject(TurnManeuver)

--- Create a turn ending course using the vehicle's current position and the front marker node (where the vehicle must
--- be in the moment it starts on the next row. Use the Corner class to generate a nice arc.
--- Could be using Dubins but that may end up generating a full circle if there's not enough room, even if we
--- miss it by just a few centimeters
function TurnEndingManeuver:init(vehicle, turnContext, vehicleDirectionNode, turningRadius, workWidth, steeringLength)
	self.debugPrefix = '(TurnEnding): '
	TurnManeuver.init(self, vehicle, turnContext, vehicleDirectionNode, turningRadius, workWidth, steeringLength)
	self:debug('Start generating')
	self:debug('r=%.1f, w=%.1f', turningRadius, workWidth)

	local startAngle = math.deg(CpMathUtil.getNodeDirection(vehicleDirectionNode))
	local r = turningRadius
	local startPos, endPos = {}, {}
	startPos.x, _, startPos.z = getWorldTranslation(vehicleDirectionNode)
	endPos.x, _, endPos.z = getWorldTranslation(turnContext.vehicleAtTurnEndNode)
	-- use side offset 0 as all the offsets is already included in the vehicleAtTurnEndNode
	local myCorner = Corner(vehicle, startAngle, startPos, self.turnContext.turnEndWp.angle, endPos	, r, 0)
	local center = myCorner:getArcCenter()
	local startArc = myCorner:getArcStart()
	local endArc = myCorner:getArcEnd()
	self:generateTurnCircle(center, startArc, endArc, r, self.turnContext:isLeftTurn() and 1 or -1, false)
	-- make sure course reaches the front marker node so end it well behind that node
	local endStraight = {}
	endStraight.x, _, endStraight.z = localToWorld(self.turnContext.vehicleAtTurnEndNode, 0, 0, 3)
	self:generateStraightSection(endArc, endStraight)
	myCorner:delete()
	self.course = Course(vehicle, self.waypoints, true)
	self.course:setUseTightTurnOffsetForLastWaypoints(
			g_vehicleConfigurations:getRecursively(vehicle, 'tightTurnOffsetDistanceInTurns') or 20)
	TurnManeuver.setLowerImplements(self.course, math.max(math.abs(turnContext.frontMarkerDistance), steeringLength))
end

---@class HeadlandCornerTurnManeuver : TurnManeuver
HeadlandCornerTurnManeuver = CpObject(TurnManeuver)

------------------------------------------------------------------------
-- When this maneuver is created, the vehicle already finished the row, the implement is raised when
-- it reached the headland. Now reverse back straight, then forward on a curve, then back up to the
-- corner, lower implements there.
------------------------------------------------------------------------
---@param turnContext TurnContext
function HeadlandCornerTurnManeuver:init(vehicle, turnContext, vehicleDirectionNode, turningRadius, workWidth,
										 reversingWorkTool, steeringLength)
	TurnManeuver.init(self, vehicle, turnContext, vehicleDirectionNode, turningRadius, workWidth, steeringLength)
	self.debugPrefix = '(HeadlandTurn): '
	self:debug('Start generating')
	self:debug('r=%.1f, w=%.1f, steeringLength=%.1f', turningRadius, workWidth, steeringLength)
	local fromPoint, toPoint = {}, {}

	local corner = turnContext:createCorner(vehicle, self.turningRadius)

	local centerForward = corner:getArcCenter()
	local helperNode = CpUtil.createNode('tmp', 0, 0, 0, self.vehicleDirectionNode)

	-- in reverse our reference point is the implement's turn node so put the first reverse waypoint behind us
	fromPoint.x, _, fromPoint.z = localToWorld(self.vehicleDirectionNode, 0, 0, - self.steeringLength )

	-- now back up so the tractor is at the start of the arc
	toPoint = corner:getPointAtDistanceFromArcStart(2 * self.steeringLength + self.reverseBuffer)
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
	TurnManeuver.addTurnControl(self.waypoints, fromIx, toIx, TurnManeuver.CHANGE_TO_FWD_WHEN_REACHED, changeToFwdIx)

	-- Drive forward until our implement reaches the circle end and a bit more so it is hopefully aligned with the tractor
	-- and we can start reversing more or less straight.
	fromPoint = corner:getPointAtDistanceFromArcEnd((2 * self.steeringLength + self.forwardBuffer) * 0.2)
	toPoint = corner:getPointAtDistanceFromArcEnd(2 * self.steeringLength + self.forwardBuffer)
	self:debug("from ( %.2f %.2f ), to ( %.2f %.2f)", fromPoint.x, fromPoint.z, toPoint.x, toPoint.z)

	fromIx, toIx = self:generateStraightSection(fromPoint, toPoint, false, false, 0, true)
	TurnManeuver.addTurnControl(self.waypoints, fromIx, toIx, TurnManeuver.CHANGE_DIRECTION_WHEN_ALIGNED, true)

	-- now back up the implement to the edge of the field (or headland)
	fromPoint = corner:getArcEnd()
	toPoint = corner:getPointAtDistanceFromCornerEnd(-(self.workWidth / 2) - turnContext.frontMarkerDistance - self.reverseBuffer - self.steeringLength)

	self:generateStraightSection(fromPoint, toPoint, true, true, self.reverseBuffer)

	-- lower the implement
	self.waypoints[#self.waypoints].lowerImplement = true
	self.course = Course(vehicle, self.waypoints, true)
end

AlignmentCourse = CpObject(TurnManeuver)

---@param vehicle table only for debugging
---@param vehicleDirectionNode number node, start of the alignment course
---@param turningRadius number
---@param course Course
---@param ix number end of the alignment course is the ix waypoint of course
---@param zOffset number forward(+)/backward(-) offset for the target, relative to the waypoint
function AlignmentCourse:init(vehicle, vehicleDirectionNode, turningRadius, course, ix, zOffset)
	self.debugPrefix = '(AlignmentCourse): '
	self.vehicle = vehicle
	self:debug('creating alignment course to waypoint %d, zOffset = %.1f', ix, zOffset)
	local x, z, yRot = PathfinderUtil.getNodePositionAndDirection(vehicleDirectionNode, 0, 0)
	local start = State3D(x, -z, CpMathUtil.angleFromGame(yRot))
	x, _, z = course:getWaypointPosition(ix)
	local goal = State3D(x, -z, CpMathUtil.angleFromGame(math.rad(course:getWaypointAngleDeg(ix))))

	local offset = Vector(zOffset, 0)
	goal:add(offset:rotate(goal.t))

	-- have a little reserve to make sure vehicles can always follow the course
	turningRadius = turningRadius * 1.1
	local solution = PathfinderUtil.dubinsSolver:solve(start, goal, turningRadius)

	local alignmentWaypoints = solution:getWaypoints(start, turningRadius)
	if not alignmentWaypoints then
		self:debug("Can't find an alignment course, may be too close to target wp?" )
		return nil
	end
	if #alignmentWaypoints < 3 then
		self:debug("Alignment course would be only %d waypoints, it isn't needed then.", #alignmentWaypoints )
		return nil
	end
	self:debug('Alignment course with %d waypoints created.', #alignmentWaypoints)
	self.course = Course.createFromAnalyticPath(self.vehicle, alignmentWaypoints, true)
end

---@class VineTurnManeuver : TurnManeuver
VineTurnManeuver = CpObject(TurnManeuver)
function VineTurnManeuver:init(vehicle, turnContext, vehicleDirectionNode, turningRadius, workWidth)
	TurnManeuver.init(self, vehicle, turnContext, vehicleDirectionNode, turningRadius, workWidth, 0)

	self:debug('Start generating')

	local turnEndNode, goalOffset = self.turnContext:getTurnEndNodeAndOffsets(0)
	local _, _, dz = turnContext:getLocalPositionOfTurnEnd(vehicle:getAIDirectionNode())
	local startOffset = 0
	if dz > 0 then
		startOffset = startOffset + dz
	else
		goalOffset = goalOffset + dz
	end
	self:debug('r=%.1f, w=%.1f, dz=%.1f, startOffset=%.1f, goalOffset=%.1f',
			turningRadius, workWidth, dz, startOffset, goalOffset)
	local path = PathfinderUtil.findAnalyticPath(PathfinderUtil.dubinsSolver,
			-- always move the goal a bit backwards to let the vehicle align
			vehicleDirectionNode, startOffset, turnEndNode, 0, goalOffset - turnContext.frontMarkerDistance, self.turningRadius)
	self.course = Course.createFromAnalyticPath(self.vehicle, path, true)
	local endingTurnLength = self.turnContext:appendEndingTurnCourse(self.course, 0, false)
	TurnManeuver.setLowerImplements(self.course, endingTurnLength, true)
end