--[[
This file is part of Courseplay (https://github.com/Courseplay/courseplay)
Copyright (C) 2019 Peter Vaiko

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

--[[

All turns have three phases:

1. Finishing Row

Keep driving until it is time to raise the implements.

2. Turn

The actual turn maneuver starts at the moment when the implements are raised. The turn maneuver can be dynamically
controlled based on the vehicle's current position or follow a calculated course. Not all turns can be run dynamically,
and this also has to be enabled by the vehicle.cp.settings.useAiTurns.

Turn courses are calculated by the code in turn.lua (which historically also did the driving) and passed on the
PPC to follow.

3. Ending Turn

In this phase we put the vehicle on a path to align with the course following the turn and initiate the lowering
of implements when needed. From this point on, control is passed back to the AIDriver.

]]

---@class AITurn
AITurn = CpObject()
AITurn.debugChannel = CpDebug.DBG_TURN

---@field ppc PurePursuitController
---@field turnContext TurnContext
function AITurn:init(vehicle, driveStrategy, ppc, turnContext, workWidth, name)
	self:addState('INITIALIZING')
	self:addState('FINISHING_ROW')
	self:addState('TURNING')
	self:addState('ENDING_TURN')
	self:addState('REVERSING_AFTER_BLOCKED')
	self:addState('FORWARDING_AFTER_BLOCKED')
	self:addState('WAITING_FOR_PATHFINDER')
	self.vehicle = vehicle
	self.settings = vehicle:getCpSettings()
	self.turningRadius = AIUtil.getTurningRadius(self.vehicle)
	---@type PurePursuitController
	self.ppc = ppc
	self.workWidth = workWidth
	---@type AIDriveStrategyFieldWorkCourse
	self.driveStrategy = driveStrategy
	-- turn handles its own waypoint changes
	self.ppc:registerListeners(self, 'onWaypointPassed', 'onWaypointChange')
	---@type TurnContext
	self.turnContext = turnContext
	self.reversingImplement, self.steeringLength = TurnManeuver.getSteeringParameters(self.vehicle)
	self.state = self.states.INITIALIZING
	self.name = name or 'AITurn'
end

function AITurn:addState(state)
	if not self.states then self.states = {} end
	self.states[state] = {name = state}
end

function AITurn:debug(...)
	CpUtil.debugVehicle(self.debugChannel, self.vehicle, self.name .. ' state: ' .. self.state.name .. ' ' .. string.format( ... ))
end

--- Start the actual turn maneuver after the row is finished
function AITurn:startTurn()
	-- implement in derived classes
end

--- Stuff we need to do during the turn no matter what turn type we are using
function AITurn:turn()
	-- TODO_22: the giants combine strategy should probably handle this too
	--if self.driveStrategy:holdInTurnManeuver(false, self.turnContext:isHeadlandCorner()) then
		-- tell driver to stop if unloading or whatever
	--	self.driveStrategy:setSpeed(0)
	--end
	return nil, nil, nil, self:getForwardSpeed()
end

function AITurn:onBlocked()
	self:debug('onBlocked()')
end

function AITurn:onWaypointChange(ix)
	self:debug('onWaypointChange %d', ix)
	-- make sure to set the proper X offset if applicable (for turning plows for example)
	self.driveStrategy:setOffsetX()
end

function AITurn:onWaypointPassed(ix, course)
	self:debug('onWaypointPassed %d', ix)
	if ix == course:getNumberOfWaypoints() then
		self:debug('Last waypoint reached, this should not happen, resuming fieldwork')
		self.driveStrategy:resumeFieldworkAfterTurn(self.turnContext.turnEndWpIx)
	end
end

function AITurn.canMakeKTurn(vehicle, turnContext, workWidth)
	if turnContext:isHeadlandCorner() then
		CpUtil.debugVehicle(AITurn.debugChannel, vehicle, 'Headland turn, not doing a 3 point turn.')
		return false
	end
	local turningRadius = AIUtil.getTurningRadius(vehicle)
	if turnContext.dx > 2 * turningRadius then
		CpUtil.debugVehicle(AITurn.debugChannel, vehicle, 'Next row is too far (%.1f, turning radius is %.1f), no 3 point turn',
			turnContext.dx, turningRadius)
		return false
	end
	if not AIVehicleUtil.getAttachedImplementsAllowTurnBackward(vehicle) then
		CpUtil.debugVehicle(AITurn.debugChannel, vehicle, 'Not all attached implements allow for reversing, use generated course turn')
		return false
	end
	local reversingImplement, _ = TurnManeuver.getSteeringParameters(vehicle)
	if reversingImplement then
		CpUtil.debugVehicle(AITurn.debugChannel, vehicle, 'Have a towed implement, use generated course turn')
		return false
	end
	local settings = vehicle:getCpSettings()
	if settings.turnOnField:getValue() and
			not AITurn.canTurnOnField(turnContext, vehicle, workWidth, turningRadius) then
		CpUtil.debugVehicle(AITurn.debugChannel, vehicle, 'Turn on field is on but there is not enough room to stay on field with a 3 point turn')
		return false
	end
	CpUtil.debugVehicle(AITurn.debugChannel, vehicle, 'Can make a 3 point turn')
	return true
end

---@param turnContext TurnContext
---@return boolean, number True if there's enough space to make a forward turn on the field. Also return the
---distance to reverse in order to be able to just make the turn on the field
function AITurn.canTurnOnField(turnContext, vehicle, workWidth, turningRadius)
	local spaceNeededOnFieldForTurn = turningRadius + workWidth / 2
	local distanceToFieldEdge = turnContext:getDistanceToFieldEdge(turnContext.vehicleAtTurnStartNode)
	CpUtil.debugVehicle(AITurn.debugChannel, vehicle, 'Space needed to turn on field %.1f m', spaceNeededOnFieldForTurn)
	if distanceToFieldEdge then
		return (distanceToFieldEdge > spaceNeededOnFieldForTurn), spaceNeededOnFieldForTurn - distanceToFieldEdge
	else
		return false, 0
	end
end

function AITurn:getForwardSpeed()
	return self.settings.turnSpeed:getValue()
end

function AITurn:getReverseSpeed()
	return self.settings.reverseSpeed:getValue()
end

function AITurn:isForwardOnly()
	return false
end

function AITurn:isFinishingRow()
	return self.state == self.states.FINISHING_ROW
end

function AITurn:isEndingTurn()
	-- include the direction too because some turns go to the ENDING_TURN state very early, while still driving
	-- perpendicular to the row. This way this returns true really only when we are about to end the turn
	return self.state == self.states.ENDING_TURN and self.turnContext:isDirectionCloseToEndDirection(self.vehicle:getAIDirectionNode(), 15)
end

-- get a virtual goal point position for a turn performed with full steering angle to the left or right (or straight)
---@param moveForwards boolean move forward when true, backwards otherwise
---@param isLeftTurn boolean turn to the right or left, or straight when nil
function AITurn:getGoalPointForTurn(moveForwards, isLeftTurn)
	local dx, dz
	if isLeftTurn == nil then
		dx = 0
		dz = moveForwards and self.ppc:getLookaheadDistance() or -self.ppc:getLookaheadDistance()
	else
		dx = isLeftTurn and self.ppc:getLookaheadDistance() or -self.ppc:getLookaheadDistance()
		dz = moveForwards and 1 or -1
	end
	local gx, _, gz = localToWorld(self.vehicle:getAIDirectionNode(), dx, 0, dz)
	return gx, gz
end

function AITurn:getDriveData(dt)
	local maxSpeed = self:getForwardSpeed()
	local gx, gz, moveForwards
	if self.state == self.states.INITIALIZING then
		local rowFinishingCourse = self.turnContext:createFinishingRowCourse(self.vehicle)
		self.ppc:setCourse(rowFinishingCourse)
		self.ppc:initialize(1)
		self.state = self.states.FINISHING_ROW
		-- Finishing the current row
	elseif self.state == self.states.FINISHING_ROW then
		self:finishRow(dt)
	elseif self.state == self.states.ENDING_TURN then
		-- Ending the turn (starting next row)
		self:endTurn(dt)
	elseif self.state == self.states.WAITING_FOR_PATHFINDER then
		maxSpeed = 0
	else
		-- Performing the actual turn
		gx, gz, moveForwards, maxSpeed = self:turn(dt)
	end
	return gx, gz, moveForwards, maxSpeed
end

-- default for 180 turns: we need to raise the implement (when finishing a row) when we reach the
-- workEndNode.
function AITurn:getRaiseImplementNode()
	return self.turnContext.workEndNode
end

function AITurn:finishRow(dt)
	-- keep driving straight until we need to raise our implements
	if self.driveStrategy:shouldRaiseImplements(self:getRaiseImplementNode()) then
		self.driveStrategy:raiseImplements()
		self:startTurn()
		self:debug('Row finished, starting turn.')
	end
	-- TODO_22: the giants combine strategy should probably handle this too
	--if self.driveStrategy:holdInTurnManeuver(true, self.turnContext:isHeadlandCorner()) then
		-- tell driver to stop while straw swath is active
	--	self.driveStrategy:setSpeed(0)
	--end
end

function AITurn:endTurn(dt)
	-- keep driving on the turn ending temporary course until we need to lower our implements
	-- check implements only if we are more or less in the right direction (next row's direction)
	if self.turnContext:isDirectionCloseToEndDirection(self.vehicle:getAIDirectionNode(), 30) and
		self.driveStrategy:shouldLowerImplements(self.turnContext.turnEndWpNode.node, false) then
		self:debug('Turn ended, resume fieldwork')
		self.driveStrategy:resumeFieldworkAfterTurn(self.turnContext.turnEndWpIx)
	end
end

function AITurn:drawDebug()

end

--[[
A K (3 point) turn to make a 180 to continue on the next row. This is a hybrid maneuver, starting with
the forward (and reverse if there's not enough room) leg, then using a course leading into the next row
in the turn end phase.
]]

---@class KTurn : AITurn
KTurn = CpObject(AITurn)

function KTurn:init(vehicle, strategy, ppc, turnContext, workWidth)
	AITurn.init(self, vehicle, strategy, ppc, turnContext, workWidth, 'KTurn')
	self:addState('FORWARD')
	self:addState('REVERSE')
	self:addState('FORWARD_ARC')
	self.blocked = CpTemporaryObject(false)
	self.blocked:set(false, 1)
end

function KTurn:onWaypointChange(ix)
	-- ending part of the K turn is driving on the course end, so revert to the default
	if self.state == self.states.ENDING_TURN then
		AITurn.onWaypointChange(self, ix)
	end
end

function KTurn:onWaypointPassed(ix, course)
	-- ending part of the K turn is driving on the course end, so revert to the default
	if self.state == self.states.ENDING_TURN then
		AITurn.onWaypointPassed(self, ix, course)
	end
end

function KTurn:startTurn()
	self.state = self.states.FORWARD
	self.vehicle:raiseAIEvent("onAIFieldWorkerTurnProgress", "onAIImplementTurnProgress", 0, self.turnContext:isLeftTurn())
	self:debug('Turn progress 0')
end

function KTurn:turn(dt)
	-- we end the K turn with a temporary course leading straight into the next row. During this turn the
	-- AI driver's state remains TURNING and thus calls AITurn:drive() which wil take care of raising the implements
	local endTurn = function(course)
		self:debug('Turn progress 100')
		self.vehicle:raiseAIEvent("onAIFieldWorkerTurnProgress", "onAIImplementTurnProgress", 100, self.turnContext:isLeftTurn())
		self.state = self.states.ENDING_TURN
		self.ppc:setCourse(course)
		self.ppc:initialize(1)
	end

	local gx, gz, maxSpeed, moveForwards
	if self.state == self.states.FORWARD then
		local dx, _, dz = self.turnContext:getLocalPositionFromTurnEnd(self.vehicle:getAIDirectionNode())
		maxSpeed = self:getForwardSpeed()
		moveForwards = true
		if dz > -math.max(0, math.max(2, self.turnContext.frontMarkerDistance)) then
			-- drive straight until we are beyond the turn end (or, if the implement is mounted on the front,
			-- make sure we end up at least 2 meters before the row start to have time to straighten out, so there
			-- is no fruit missed)
			gx, gz = self:getGoalPointForTurn(moveForwards, nil)
		elseif not self.turnContext:isDirectionPerpendicularToTurnEndDirection(self.vehicle:getAIDirectionNode()) then
			-- full turn towards the turn end waypoint
			gx, gz = self:getGoalPointForTurn(moveForwards, self.turnContext:isLeftTurn())
		else
			-- drive straight ahead until we cross turn end line
			gx, gz = self:getGoalPointForTurn(moveForwards, nil)
			if self.turnContext:isLateralDistanceGreater(dx, self.turningRadius * 1.05) then
				-- no need to reverse from here, we can make the turn
				self.endingTurnCourse = TurnEndingManeuver(self.vehicle, self.turnContext,
						self.vehicle:getAIDirectionNode(), self.turningRadius, self.workWidth, 0):getCourse()
				self:debug('K Turn: dx = %.1f, r = %.1f, no need to reverse.', dx, self.turningRadius)
				endTurn(self.endingTurnCourse)
			else
				-- reverse until we can make turn to the turn end point
				self.vehicle:raiseAIEvent("onAIFieldWorkerTurnProgress", "onAIImplementTurnProgress", 50, self.turnContext:isLeftTurn())
				self:debug('Turn progress 50')
				self.state = self.states.REVERSE
				self.endingTurnCourse = TurnEndingManeuver(self.vehicle, self.turnContext,
						self.vehicle:getAIDirectionNode(), self.turningRadius, self.workWidth, 0):getCourse()
				self:debug('K Turn: dx = %.1f, r = %.1f, reversing now.', dx, self.turningRadius)
			end
		end
	elseif self.state == self.states.REVERSE then
		-- reversing parallel to the direction between the turn start and turn end waypoints
		moveForwards = false
		maxSpeed = self:getReverseSpeed()
		gx, gz = self:getGoalPointForTurn(moveForwards, nil)
		local _, _, dz = self.endingTurnCourse:getWaypointLocalPosition(self.vehicle:getAIDirectionNode(), 1)
		if dz > 0  then
			-- we can make the turn from here
			self:debug('K Turn ending turn')
			endTurn(self.endingTurnCourse)
		end
	elseif self.state == self.states.REVERSING_AFTER_BLOCKED then
		moveForwards = false
		maxSpeed = self:getReverseSpeed()
		-- TODO_22 here we should not fully steer to recover, see if this is still needed
		gx, gz = self:getGoalPointForTurn(moveForwards, self.turnContext:isLeftTurn())
		if not self.blocked:get() then
			self.state = self.stateAfterBlocked
			self:debug('Trying again after reversed due to being blocked')
		end
	elseif self.state == self.states.FORWARDING_AFTER_BLOCKED then
		maxSpeed = self:getForwardSpeed()
		moveForwards = true
		-- TODO_22 here we should not fully steer to recover, see if this is still needed
		gx, gz = self:getGoalPointForTurn(moveForwards, self.turnContext:isLeftTurn())
		if not self.blocked:get() then
			self.state = self.stateAfterBlocked
			self:debug('Trying again after forwarded due to being blocked')
		end
	end
	return gx, gz, moveForwards, maxSpeed
end

function KTurn:onBlocked()
	if self.driveStrategy:holdInTurnManeuver(false, self.turnContext:isHeadlandCorner()) then
		-- not really blocked just waiting for the straw for example
		return
	end
	self.stateAfterBlocked = self.state
	self.blocked:set(true, 3500)
	if self.state == self.states.REVERSE then
		self.state = self.states.FORWARDING_AFTER_BLOCKED
		self:debug('Blocked, try forwarding a bit')
	elseif self.state == self.states.FORWARD then
		self.state = self.states.REVERSING_AFTER_BLOCKED
		self:debug('Blocked, try reversing a bit')
	end
end

--[[
  Headland turn for combines:
  1. drive forward to the field edge or the headland path edge
  2. start turning forward
  3. reverse straight and then align with the direction after the
     corner while reversing
  4. forward to the turn start to continue on headland
]]
---@class CombineHeadlandTurn : AITurn
CombineHeadlandTurn = CpObject(AITurn)

---@param driveStrategy AIDriveStrategyFieldWorkCourse
---@param turnContext TurnContext
function CombineHeadlandTurn:init(vehicle, driveStrategy, ppc, turnContext)
	AITurn.init(self, vehicle, driveStrategy, ppc, turnContext, 'CombineHeadlandTurn')
	self:addState('FORWARD')
	self:addState('REVERSE_STRAIGHT')
	self:addState('REVERSE_ARC')
	self.turningRadius = AIUtil.getTurningRadius(self.vehicle)
	self.cornerAngleToTurn = turnContext:getCornerAngleToTurn()
	self.angleToTurnInReverse = math.abs(self.cornerAngleToTurn / 2)
	self.dxToStartReverseTurn = self.turningRadius - math.abs(self.turningRadius - self.turningRadius * math.cos(self.cornerAngleToTurn))
	self.blocked = CpTemporaryObject(false)
	self.blocked:set(false, 1)
end

function CombineHeadlandTurn:startTurn()
	self.state = self.states.FORWARD
	self:debug('Starting combine headland turn')
end

-- in a combine headland turn we want to raise the header after it reached the field edge (or headland edge on an inner
-- headland.
function CombineHeadlandTurn:getRaiseImplementNode()
	return self.turnContext.lateWorkEndNode
end

function CombineHeadlandTurn:turn(dt)
	local gx, gz, moveForwards, maxSpeed = AITurn.turn(self)
	local dx, _, dz = self.turnContext:getLocalPositionFromTurnEnd(self.vehicle:getAIDirectionNode())
	local angleToTurnEnd = math.abs(self.turnContext:getAngleToTurnEndDirection(self.vehicle:getAIDirectionNode()))
	if self.state == self.states.FORWARD then
		maxSpeed = self:getForwardSpeed()
		moveForwards = true
		if angleToTurnEnd > self.angleToTurnInReverse then --and not self.turnContext:isLateralDistanceLess(dx, self.dxToStartReverseTurn) then
			-- full turn towards the turn end direction
			gx, gz = self:getGoalPointForTurn(moveForwards, self.turnContext:isLeftTurn())
		else
			-- reverse until we can make turn to the turn end point
			self.state = self.states.REVERSE_STRAIGHT
			self:debug('Combine headland turn start reversing straight')
		end

	elseif self.state == self.states.REVERSE_STRAIGHT then
		maxSpeed = self:getReverseSpeed()
		moveForwards = false
		gx, gz = self:getGoalPointForTurn(moveForwards, nil)
		if math.abs(dx) < 0.2  then
			self.state = self.states.REVERSE_ARC
			self:debug('Combine headland turn start reversing arc')
		end

	elseif self.state == self.states.REVERSE_ARC then
		maxSpeed = self:getReverseSpeed()
		moveForwards = false
		gx, gz = self:getGoalPointForTurn(moveForwards, not self.turnContext:isLeftTurn())
		if angleToTurnEnd < math.rad(20) then
			self.state = self.states.ENDING_TURN
			self:debug('Combine headland turn forwarding again')
			-- lower implements here unconditionally (regardless of the direction, self:endTurn() would wait until we
			-- are pointing to the turn target direction)
			self.driveStrategy:lowerImplements()
			self.driveStrategy:resumeFieldworkAfterTurn(self.turnContext.turnEndWpIx)
		end
	elseif self.state == self.states.REVERSING_AFTER_BLOCKED then
		maxSpeed = self:getReverseSpeed()
		moveForwards = false
		-- TODO: may need to steer less...
		gx, gz = self:getGoalPointForTurn(moveForwards, self.turnContext:isLeftTurn())
		if not self.blocked:get() then
			self.state = self.stateAfterBlocked
			self:debug('Trying again after reversed due to being blocked')
		end
	elseif self.state == self.states.FORWARDING_AFTER_BLOCKED then
		maxSpeed = self:getForwardSpeed()
		moveForwards = true
		-- TODO: may need to steer less...
		gx, gz = self:getGoalPointForTurn(moveForwards, self.turnContext:isLeftTurn())
		if not self.blocked:get() then
			self.state = self.stateAfterBlocked
			self:debug('Trying again after forwarded due to being blocked')
		end
	end
	return gx, gz, moveForwards, maxSpeed
end

function CombineHeadlandTurn:onBlocked()
	self.stateAfterBlocked = self.state
	self.blocked:set(true, 3500)
	if self.state == self.states.REVERSE_ARC or self.state == self.states.REVERSE_STRAIGHT then
		self.state = self.states.FORWARDING_AFTER_BLOCKED
		self:debug('Blocked, try forwarding a bit')
	else
		self.state = self.states.REVERSING_AFTER_BLOCKED
		self:debug('Blocked, try reversing a bit')
	end
end

--[[
A turn maneuver following a course (waypoints created by turn.lua)
]]

---@class CourseTurn : AITurn
CourseTurn = CpObject(AITurn)

function CourseTurn:init(vehicle, driveStrategy, ppc, turnContext, fieldworkCourse, workWidth, name)
	AITurn.init(self, vehicle, driveStrategy, ppc, turnContext, workWidth, name or 'CourseTurn')

	self.forceTightTurnOffset = false
	self.enableTightTurnOffset = false
	self.fieldworkCourse = fieldworkCourse
end

function CourseTurn:getForwardSpeed()
	if self.turnCourse then
		local currentWpIx = self.turnCourse:getCurrentWaypointIx()
		if self.turnCourse:getDistanceFromFirstWaypoint(currentWpIx) > 10 and
				self.turnCourse:getDistanceToLastWaypoint(currentWpIx) > 10 then
			-- in the middle of a long turn maneuver we can drive faster...
			return 1.5 * AITurn.getForwardSpeed(self)
		else
			return AITurn.getForwardSpeed(self)
		end
	end
	return AITurn.getForwardSpeed(self)
end

-- this turn starts when the vehicle reached the point where the implements are raised.
-- now use turn.lua to generate the turn maneuver waypoints
function CourseTurn:startTurn()
	local canTurnOnField = AITurn.canTurnOnField(self.turnContext, self.vehicle, self.workWidth, self.turningRadius)
	-- TODO_22 self.vehicle.cp.settings.turnOnField:is(false)
	if (canTurnOnField or self.settings.turnOnField:getValue()) and
			self.turnContext:isPathfinderTurn(self.turningRadius * 2) and
			not self.turnContext:isSimpleWideTurn(self.turningRadius * 2) then
		-- if we can turn on the field or it does not matter if we can, pathfinder turn is ok. If turn on field is on
		-- but we don't have enough space and have to reverse, fall back to the generated turns
		self:generatePathfinderTurn()
	else
		self:generateCalculatedTurn()
		self.ppc:setCourse(self.turnCourse)
		self.ppc:initialize(1)
		self.state = self.states.TURNING
	end
end

function CourseTurn:isForwardOnly()
	return self.turnCourse and self.turnCourse:isForwardOnly()
end

function CourseTurn:getCourse()
	return self.turnCourse
end

function CourseTurn:turn()

	local gx, gz, moveForwards, maxSpeed = AITurn.turn(self)

	self:updateTurnProgress()

	self:changeDirectionWhenAligned()
	self:changeToFwdWhenWaypointReached()

	if self.turnCourse:isTurnEndAtIx(self.turnCourse:getCurrentWaypointIx()) then
		self.state = self.states.ENDING_TURN
		self:debug('About to end turn')
	end
	return gx, gz, moveForwards, maxSpeed
end

function CourseTurn:endTurn(dt)
-- keep driving on the turn course until we need to lower our implements
	if not self.implementsLowered and self.driveStrategy:shouldLowerImplements(self.turnContext.workStartNode, self.ppc:isReversing()) then
		self:debug('Turn ending, lowering implements')
		self.driveStrategy:lowerImplements()
		self.implementsLowered = true
		if self.ppc:isReversing() then
			-- when ending a turn in reverse, don't drive the rest of the course, switch right back to fieldwork
			self.driveStrategy:resumeFieldworkAfterTurn(self.turnContext.turnEndWpIx)
		end
	end
	return false
end

function CourseTurn:updateTurnProgress()
	if self.turnCourse then
		local progress = self.turnCourse:getCurrentWaypointIx() / self.turnCourse:getNumberOfWaypoints()
		self.vehicle:raiseAIEvent("onAIFieldWorkerTurnProgress", "onAIImplementTurnProgress", progress, self.turnContext:isLeftTurn())
	end
end

function CourseTurn:onWaypointChange(ix)
	AITurn.onWaypointChange(self, ix)
	if self.turnCourse then
		if self.forceTightTurnOffset or (self.enableTightTurnOffset and self.turnCourse:useTightTurnOffset(ix)) then
			-- adjust the course a bit to the outside in a curve to keep a towed implement on the course
			-- TODO_22
			self.tightTurnOffset = AIUtil.calculateTightTurnOffset(self.vehicle, self.turnCourse,
					self.tightTurnOffset, true)
			self.turnCourse:setOffset(self.tightTurnOffset, 0)
		end
	end
end

--- When switching direction during a turn, especially when switching to reverse we want to make sure
--- that a towed implement is aligned with the reverse direction (already straight behind the tractor when
--- starting to reverse). Turn courses are generated with a very long alignment section to allow for this with
--- the changeDirectionWhenAligned property set, indicating that we don't have to travel along the path, we can
--- change direction as soon as the implement is aligned.
--- So check that here and force a direction change when possible.
function CourseTurn:changeDirectionWhenAligned()
	if TurnManeuver.getTurnControl(self.turnCourse, self.turnCourse:getCurrentWaypointIx(), TurnManeuver.CHANGE_DIRECTION_WHEN_ALIGNED) then
		local aligned = self.driveStrategy:areAllImplementsAligned(self.turnContext.turnEndWpNode.node)
		self:debug('aligned: %s', tostring(aligned))
		if aligned then
			-- find the next direction switch and continue course from there
			local nextDirectionChangeIx = self.turnCourse:getNextDirectionChangeFromIx(self.turnCourse:getCurrentWaypointIx())
			if nextDirectionChangeIx then
				self:debug('skipping to next direction change at %d', nextDirectionChangeIx + 1)
				self.ppc:initialize(nextDirectionChangeIx + 1)
			end
		end
	end
end

--- Check if we reached a waypoint where we should change to forward. This is useful when backing up to reach a point
--- where we can start driving on an arc, for example in a headland corner of when backing up from the field edge
--- before we make a U turn
function CourseTurn:changeToFwdWhenWaypointReached()
	local changeWpIx =
		TurnManeuver.getTurnControl(self.turnCourse, self.turnCourse:getCurrentWaypointIx(), TurnManeuver.CHANGE_TO_FWD_WHEN_REACHED)
	if changeWpIx and self.ppc:isReversing() then
		local _, _, dz = self.turnCourse:getWaypointLocalPosition(self.vehicle:getAIDirectionNode(), changeWpIx)
		-- is the change waypoint now in front of us?
		if dz > 0 then
			-- find the next direction switch and continue course from there
			local getNextFwdWaypointIx = self.turnCourse:getNextFwdWaypointIx(self.turnCourse:getCurrentWaypointIx())
			if getNextFwdWaypointIx then
				self:debug('skipping to next forward waypoint at %d (dz: %.1f)', getNextFwdWaypointIx, dz)
				self.ppc:initialize(getNextFwdWaypointIx)
			end
		end
	end
end

function CourseTurn:generateCalculatedTurn()
	local turnManeuver
	if self.turnContext:isHeadlandCorner() then
		-- TODO_22
		self:debug('This is a headland turn')
		turnManeuver = HeadlandCornerTurnManeuver(self.vehicle, self.turnContext, self.vehicle:getAIDirectionNode(),
			self.turningRadius, self.workWidth, self.reversingImplement, self.steeringLength)
		-- adjust turn course for tight turns only for headland corners by default
		self.forceTightTurnOffset = self.steeringLength > 0
	else
		local distanceToFieldEdge = self.turnContext:getDistanceToFieldEdge(self.turnContext.vehicleAtTurnStartNode)
		local turnOnField = self.settings.turnOnField:getValue()
		self:debug('This is NOT a headland turn, turnOnField=%s distanceToFieldEdge=%.1f', turnOnField, distanceToFieldEdge)
		-- if don't have to turn on field then pretend we have a lot of space
		distanceToFieldEdge = turnOnField and distanceToFieldEdge or math.huge
		if distanceToFieldEdge > self.workWidth or self.steeringLength > 0 then
			-- if there's plenty of space or it is a towed implement, stick with Dubins, that's easier
			turnManeuver = DubinsTurnManeuver(self.vehicle, self.turnContext, self.vehicle:getAIDirectionNode(),
				self.turningRadius, self.workWidth, self.steeringLength, distanceToFieldEdge)
		else
			turnManeuver = ReedsSheppTurnManeuver(self.vehicle, self.turnContext, self.vehicle:getAIDirectionNode(),
				self.turningRadius, self.workWidth, self.steeringLength, distanceToFieldEdge)
		end
		-- only use tight turn offset if we are towing something
		self.enableTightTurnOffset = self.steeringLength > 0
	end
	self.turnCourse = turnManeuver:getCourse()
end

function CourseTurn:generatePathfinderTurn()
	self.pathfindingStartedAt = g_currentMission.time
	local done, path
	local turnEndNode, startOffset, goalOffset = self.turnContext:getTurnEndNodeAndOffsets(self.steeringLength)

	self:debug('Wide turn: generate turn with hybrid A*, start offset %.1f, goal offset %.1f', startOffset, goalOffset)
	self.driveStrategy.pathfinder, done, path = PathfinderUtil.findPathForTurn(self.vehicle, startOffset, turnEndNode, goalOffset,
			self.turningRadius, self.driveStrategy:getAllowReversePathfinding(), self.fieldworkCourse)
	if done then
		return self:onPathfindingDone(path)
	else
		self.state = self.states.WAITING_FOR_PATHFINDER
		self.driveStrategy:setPathfindingDoneCallback(self, self.onPathfindingDone)
	end
end

function CourseTurn:onPathfindingDone(path)
	if path and #path > 2 then
		self:debug('Pathfinding finished with %d waypoints (%d ms)', #path, g_currentMission.time - (self.pathfindingStartedAt or 0))
		if self.reverseBeforeStartingTurnWaypoints and #self.reverseBeforeStartingTurnWaypoints > 0 then
			self.turnCourse = Course(self.vehicle, self.reverseBeforeStartingTurnWaypoints, true)
			self.turnCourse:appendWaypoints(CourseGenerator.pointsToXzInPlace(path))
		else
			self.turnCourse = Course(self.vehicle, CourseGenerator.pointsToXzInPlace(path), true)
		end
		self.turnCourse:setTurnEndForLastWaypoints(5)
		-- make sure we use tight turn offset towards the end of the course so a towed implement is aligned with the new row
		self.turnCourse:setUseTightTurnOffsetForLastWaypoints(10)
		self.turnContext:appendEndingTurnCourse(self.turnCourse)
		-- and once again, if there is an ending course, keep adjusting the tight turn offset
		-- TODO: should probably better done on onWaypointChange, to reset to 0
		self.turnCourse:setUseTightTurnOffsetForLastWaypoints(10)
	else
		self:debug('No path found in %d ms, falling back to normal turn course generator', g_currentMission.time - (self.pathfindingStartedAt or 0))
		self:generateCalculatedTurn()
	end
	self.ppc:setCourse(self.turnCourse)
	self.ppc:initialize(1)
	self.state = self.states.TURNING
end

function CourseTurn:drawDebug()
	if self.turnCourse and self.turnCourse:isTemporary() and CpDebug:isChannelActive(CpDebug.DBG_COURSES) then
		self.turnCourse:draw()
	end
end

--- Combines (in general, when harvesting) in headland corners we want to work the corner first, then back up and then
--- turn so we harvest any area before we drive over it
---@class CombineCourseTurn : CourseTurn
CombineCourseTurn = CpObject(CourseTurn)

---@param turnContext TurnContext
function CombineCourseTurn:init(vehicle, driveStrategy, ppc, turnContext, fieldworkCourse, workWidth, name)
	CourseTurn.init(self, vehicle, driveStrategy, ppc, turnContext, fieldworkCourse,workWidth, name or 'CombineCourseTurn')
end

-- in a combine headland turn we want to raise the header after it reached the field edge (or headland edge on an inner
-- headland.
function CombineCourseTurn:getRaiseImplementNode()
	return self.turnContext.lateWorkEndNode
end

--[[
  Headland turn for combines on the outermost headland:
  1. drive forward to the field edge or the headland path edge
  2. start turning forward
  3. reverse straight and then align with the direction after the
     corner while reversing
  4. forward to the turn start to continue on headland
]]
---@class CombinePocketHeadlandTurn : CombineCourseTurn
CombinePocketHeadlandTurn = CpObject(CombineCourseTurn)

---@param driveStrategy AIDriveStrategyCombineCourse
---@param turnContext TurnContext
function CombinePocketHeadlandTurn:init(vehicle, driveStrategy, ppc, turnContext, fieldworkCourse, workWidth)
	CombineCourseTurn.init(self, vehicle, driveStrategy, ppc, turnContext, fieldworkCourse,
			workWidth, 'CombinePocketHeadlandTurn')
end

--- Create a pocket in the next row at the corner to stay on the field during the turn maneuver.
---@param turnContext TurnContext
function CombinePocketHeadlandTurn:generatePocketHeadlandTurn(turnContext)
	local cornerWaypoints = {}
	-- this is how far we have to cut into the next headland (the position where the header will be after the turn)
	local offset = math.min(self.turningRadius + turnContext.frontMarkerDistance, self.workWidth)
	local corner = turnContext:createCorner(self.vehicle, self.turningRadius)
	local d = -self.workWidth / 2 + turnContext.frontMarkerDistance
	local wp = corner:getPointAtDistanceFromCornerStart(d + 2)
	wp.speed = self.settings.turnSpeed:getValue() * 0.75
	table.insert(cornerWaypoints, wp)
	-- drive forward up to the field edge
	wp = corner:getPointAtDistanceFromCornerStart(d)
	wp.speed = self.settings.turnSpeed:getValue() * 0.75
	table.insert(cornerWaypoints, wp)
	-- drive back to prepare for making a pocket
	-- reverse back to set up for the headland after the corner
	local reverseDistance = 2 * offset
	wp = corner:getPointAtDistanceFromCornerStart(reverseDistance / 2)
	wp.rev = true
	table.insert(cornerWaypoints, wp)
	wp = corner:getPointAtDistanceFromCornerStart(reverseDistance)
	wp.rev = true
	table.insert(cornerWaypoints, wp)
	-- now make a pocket in the inner headland to make room to turn
	wp = corner:getPointAtDistanceFromCornerStart(reverseDistance * 0.75, -offset * 0.6)
	table.insert(cornerWaypoints, wp)
	wp = corner:getPointAtDistanceFromCornerStart(reverseDistance * 0.5, -offset * 0.7)
	if not CpFieldUtil.isOnField(wp.x, wp.z) then
		self:debug('No field where the pocket would be, this seems to be a 270 corner')
		corner:delete()
		return nil
	end
	table.insert(cornerWaypoints, wp)
	-- drive forward to the field edge on the inner headland
	wp = corner:getPointAtDistanceFromCornerStart(d, -offset * 0.7)
	wp.speed = self.settings.turnSpeed:getValue() * 0.75
	table.insert(cornerWaypoints, wp)
	wp = corner:getPointAtDistanceFromCornerStart(reverseDistance / 1.5)
	wp.rev = true
	table.insert(cornerWaypoints, wp)
	wp = corner:getPointAtDistanceFromCornerEnd(self.turningRadius / 3, self.turningRadius / 2)
	wp.speed = self.settings.turnSpeed:getValue() * 0.5
	table.insert(cornerWaypoints, wp)
	wp = corner:getPointAtDistanceFromCornerEnd(self.turningRadius, self.turningRadius / 4)
	wp.speed = self.settings.turnSpeed:getValue() * 0.5
	table.insert(cornerWaypoints, wp)
	corner:delete()
	return Course(self.vehicle, cornerWaypoints, true), turnContext.turnEndWpIx
end


function CombinePocketHeadlandTurn:startTurn()
	self.turnCourse = self:generatePocketHeadlandTurn(self.turnContext)
	if not self.turnCourse then
		self:debug('Could not create pocket course, falling back to normal headland corner')
		self:generateCalculatedTurn()
	end
	self.ppc:setCourse(self.turnCourse)
	self.ppc:initialize(1)
	self.state = self.states.TURNING
end

--- When making a pocket we need to lower the header whenever driving forward
function CombinePocketHeadlandTurn:turn(dt)
	local gx, gy, moveForwards, maxSpeed = AITurn.turn(self)
	if self.ppc:isReversing() then
		self.driveStrategy:raiseImplements()
		self.implementsLowered = nil
	elseif not self.implementsLowered then
		self.driveStrategy:lowerImplements()
		self.implementsLowered = true
	end
	return gx, gy, moveForwards, maxSpeed
end

--- A turn type which isn't really a turn, we only use this to finish a row (drive straight until the implement
--- reaches the end of the row, don't drive towards the next waypoint until then)
--- This is to make sure the last row before transitioning to the headland is properly finished, otherwise
--- we'd start driving towards the next headland waypoint, turning towards it before the implement reaching the
--- end of the row and leaving unworked patches.
---@class FinishRowOnly : AITurn
FinishRowOnly = CpObject(AITurn)

function FinishRowOnly:init(vehicle, driver, turnContext)
	AITurn.init(self, vehicle, driver, turnContext, 'FinishRowOnly')
end

function FinishRowOnly:finishRow()
	-- keep driving straight until we need to raise our implements
	if self.driveStrategy:shouldRaiseImplements(self:getRaiseImplementNode()) then
		self:debug('Row finished, returning to fieldwork.')
		self.driveStrategy:resumeFieldworkAfterTurn(self.turnContext.turnEndWpIx, true)
	end
	return false
end