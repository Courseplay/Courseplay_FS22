--[[
This file is part of Courseplay (https://github.com/Courseplay/Courseplay_FS22)
Copyright (C) 2023 Courseplay Dev Team
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

--------------------------------------------
--- Pathfinder controller
--------------------------------------------

PathfinderController for easy access to the pathfinder.
- Enables retrying with adjustable parameters compared to the last try, like fruit allowed and so..
- Handles the pathfinder coroutines if needed.
- One callback when the path finding finished.
	- Triggered if a valid path was found.
	- Gets triggered if the goal node is invalid.
	- Also gets triggered if no valid path was found and all retry attempts are used.
- Every time the path finding failed a callback gets triggered, if there are retry attempts left over.
	- Enabled the changing of the pathfinder context and restart with the new context.

Example implementations: 

function Strategy:startPathfindingToGoal()
	local numRetries = 2
	local context = PathfinderControllerContext(self.vehicle, numRetries)
	context:set(
		... 
	)
	self.pathfinderController:setCallbacks(self, self.onPathfingFinished, self.onPathfindingFailed)

	self.pathfinderController:findPathToNode(context, ...)

end

function Strategy:onPathfingFinished(controller : PathfinderController, success : boolean, 
	course : Course, goalNodeInvalid : boolean|nil)
	if success then
		// Path finding finished successfully
		...
	else 
		if goalNodeInvalid then 
			// Goal position can't be reached!
		else 
			// Num retries reached without path!
		end
	end
end

function Strategy:onPathfindingFailed(controller : PathfinderController, lastContext : PathfinderControllerContext, 
	wasLastRetry : boolean, currentRetryAttempt : number)
	if currentRetryAttempt == 1 then 
		// Reduced fruit impact:
		lastContext:ignoreFruit()
		self.pathfinderController:findPathToNode(lastContext, ...)
	else 
		// Something else ...
		self.pathfinderController:findPathToNode(lastContext, ...)
	end
end

--------------------------------------------
--- Pathfinder controller context
--------------------------------------------


PathfinderControllerContext implements all pathfinder parameters and the number of retries allowed.
- Other Context Classes could be derived for commonly used contexts. 
- Only the attributesToDefaultValue table has to be changed in the derived class.

Example usage of the builder api:

local context = PathfinderControllerContext():maxFruitPercent(100):useFieldNum(true):vehiclesToIgnore({vehicle})


]]

---@class PathfinderControllerContext
---@field maxFruitPercent function
---@field offFieldPenalty function
---@field useFieldNum function
---@field areaToAvoid function
---@field allowReverse function
---@field vehiclesToIgnore function
---@field mustBeAccurate function
---@field areaToIgnoreFruit function
---@field _maxFruitPercent number
---@field _offFieldPenalty number
---@field _useFieldNum number
---@field _areaToAvoid PathfinderUtil.NodeArea|nil
---@field _allowReverse boolean
---@field _vehiclesToIgnore table[]|nil
---@field _mustBeAccurate boolean
---@field _areaToIgnoreFruit table[]
PathfinderControllerContext = CpObject()
PathfinderControllerContext.defaultNumRetries = 0
PathfinderControllerContext.attributesToDefaultValue = {
	-- If an 4 x 4 m area around a pathfinder node has more than this fruit, a penalty of 0.5 * actual fruit
	-- percentage will be applied to that node.
	-- TODO: check if the fruitValue returned by FSDensityMapUtil.getFruitArea() really is a percentage
	["maxFruitPercent"] = 50,
	-- This penalty is added to the cost of each step, which is about 12% of the turning radius when using
	-- the hybrid A* and 3 with the simple A*.
	-- Simple A* is used for long-range pathfinding, in that case we are willing to drive about 3 times longer
	-- to stay on the field. Hybrid A* is more restrictive, TODO: review if these should be balanced
	["offFieldPenalty"] = 7.5,
	-- If useFieldNum > 0, fields that are not owned have a 20% greater penalty.
 	["useFieldNum"] = 0,
	-- Pathfinder nodes in this area have a prohibitive penalty (2000)
	["areaToAvoid"] = CpObjectUtil.BUILDER_API_NIL,
	["allowReverse"] = false,
	["vehiclesToIgnore"] = CpObjectUtil.BUILDER_API_NIL,
	-- If false, as we reach the maximum iterations, we relax our criteria to reach the goal: allow for arriving at
	-- bigger angle differences, trading off accuracy for speed. This usually results in a direction at the goal
	-- being less then 30º off which in many cases isn't a problem.
	-- Otherwise, for example when a combine self unloading must accurately find the trailer, set this to true.
	["mustBeAccurate"] = false,
	-- No fruit penalty in this area (e.g. when we know the goal is in fruit but want to avoid fruit all the way there)
	["areaToIgnoreFruit"] = CpObjectUtil.BUILDER_API_NIL
}

function PathfinderControllerContext:init(vehicle, numRetries)
	self._vehicle = vehicle
	self._numRetries = numRetries or self.defaultNumRetries
	CpObjectUtil.registerBuilderAPI(self, self.attributesToDefaultValue)
end

--- Disables the fruit avoidance
function PathfinderControllerContext:ignoreFruit()
	self._maxFruitPercent = math.huge
end

--- Uses the field number of the vehicle to restrict path finding.
function PathfinderControllerContext:useVehicleFieldNumber()
	self._useFieldNum = CpFieldUtil.getFieldNumUnderVehicle(self._vehicle)
end

function PathfinderControllerContext:getNumRetriesAllowed()
	return self._numRetries
end

---@class DefaultFieldPathfinderControllerContext : PathfinderControllerContext
DefaultFieldPathfinderControllerContext = CpObject(PathfinderControllerContext)

function DefaultFieldPathfinderControllerContext:init(...)
	PathfinderControllerContext.init(self, ...)
end

---@class PathfinderController 
PathfinderController= CpObject()

PathfinderController.SUCCESS_FOUND_VALID_PATH = 0
PathfinderController.ERROR_NO_PATH_FOUND = 1
PathfinderController.ERROR_INVALID_GOAL_NODE = 2
function PathfinderController:init(vehicle)
	self.vehicle = vehicle
	---@type PathfinderInterface
	self.pathfinder = nil
	---@type PathfinderControllerContext
	self.lastContext = nil
	self:reset()
end

function PathfinderController:__tostring()
	return string.format("PathfinderController(failCount=%d, numRetries=%s, active=%s)",
		self.failCount, self.numRetries, tostring(self.pathfinder ~= nil))
end

function PathfinderController:reset()
	self.numRetries = 0
	self.failCount = 0
	self.startedAt = 0
	self.timeTakenMs = 0
	self.lastContext = nil
end

function PathfinderController:update(dt)
	if self:isActive() then
		--- Applies coroutine for path finding
		local done, path, goalNodeInvalid = self.pathfinder:resume()
        if done then
			self:onFinish(path, goalNodeInvalid)
        end
	end
end

function PathfinderController:getDriveData()
	local maxSpeed
	if self:isActive() then 
		--- Pathfinder is active, so we stop the driver.
		maxSpeed = 0
	end
	return nil, nil, nil, maxSpeed
end

function PathfinderController:isActive()
	return self.pathfinder and self.pathfinder:isActive()
end

---@return PathfinderControllerContext
function PathfinderController:getLastContext()
	return self.lastContext
end

--- Registers listeners for pathfinder success and failures.
--- TODO: Decide if multiple registered listeners are needed or not?
---@param object table
---@param successFunc function func(PathfinderController, success, Course, goalNodeInvalid)
---@param retryFunc function func(PathfinderController, last context, was last retry, retry attempt number)
function PathfinderController:registerListeners(object, successFunc, retryFunc)
	self.callbackObject = object
	self.callbackSuccessFunction = successFunc 
	self.callbackRetryFunction = retryFunc
end

--- Pathfinder was started
---@param context PathfinderControllerContext
function PathfinderController:onStart(context)
	self:debug("Started pathfinding with context: %s.", tostring(context))
	self.startedAt = g_time
	self.lastContext = context
	self.numRetries = context:getNumRetriesAllowed()
end

--- Path finding has finished
---@param path table|nil
---@param goalNodeInvalid boolean|nil
function PathfinderController:onFinish(path, goalNodeInvalid)
	self.pathfinder = nil
	self.timeTakenMs = g_time - self.startedAt
	local retValue = self:isValidPath(path, goalNodeInvalid)
	if retValue == self.ERROR_NO_PATH_FOUND then 
		if self.callbackRetryFunction then
			--- Retry is allowed, so check if any tries are leftover
			if self.failCount < self.numRetries then 
				self:debug("Failed with try %d of %d.", self.failCount, self.numRetries)
				--- Retrying the path finding
				self.failCount = self.failCount + 1
				self:callCallback(self.callbackRetryFunction, 
					self.lastContext, self.failCount == self.numRetries, self.failCount)
				return
			elseif self.numRetries > 0 then 
				self:debug("Max number of retries already reached!")
			end
		end
	end
	self:callCallback(self.callbackSuccessFunction, 
		retValue == self.SUCCESS_FOUND_VALID_PATH, 
		self:getTemporaryCourseFromPath(path), goalNodeInvalid)
	self:reset()
end

--- Is the path found and valid?
---@param path table|nil
---@param goalNodeInvalid boolean|nil
---@return integer
function PathfinderController:isValidPath(path, goalNodeInvalid)
	if path and #path > 2 then
        self:debug('Found a path (%d waypoints, after %d ms)', #path, self.timeTakenMs)
        return self.SUCCESS_FOUND_VALID_PATH
    end
	if goalNodeInvalid then
		self:error('No path found, goal node is invalid')
		return self.ERROR_INVALID_GOAL_NODE
	end 
	self:error("No path found after %d ms", self.timeTakenMs)
	return self.ERROR_NO_PATH_FOUND
end

function PathfinderController:callCallback(callbackFunc, ...)
	if self.callbackObject then 
		callbackFunc(self.callbackObject, self, ...)
	else 
		callbackFunc(self, ...)
	end
end

--- Finds a path to given goal node
---@param context PathfinderControllerContext
---@param goalNode number
---@param xOffset number
---@param zOffset number
---@return boolean Was path finding started?
function PathfinderController:findPathToNode(context, 
	goalNode, xOffset, zOffset)

	if not self.callbackSuccessFunction then
		self:error("No valid success callback was given!") 
		return false
	end
	self:onStart(context)
	local pathfinder, done, path, goalNodeInvalid = PathfinderUtil.startPathfindingFromVehicleToNode(
		context._vehicle,
		goalNode,
		xOffset,
		zOffset,
		context._allowReverse, 
		context._useFieldNum,
		context._vehiclesToIgnore,
		context._maxFruitPercent,
		context._offFieldPenalty,
		context._areaToAvoid,
		context._mustBeAccurate
	)
	if done then 
		self:onFinish(path, goalNodeInvalid)
	else 
		self:debug("Continuing as coroutine...")
		self.pathfinder = pathfinder
	end
	return true
end

--- Finds a path to a waypoint of a course.
---@param context PathfinderControllerContext
---@param course Course
---@param waypointIndex number
---@param xOffset number
---@param zOffset number
---@return boolean Was path finding started?
function PathfinderController:findPathToWaypoint(context, 
	course, waypointIndex, xOffset, zOffset)

	if not self.callbackSuccessFunction then 
		self:error("No valid success callback was given!") 
		return false
	end
	self:onStart(context)
	local pathfinder, done, path, goalNodeInvalid = PathfinderUtil.startPathfindingFromVehicleToWaypoint(
		context._vehicle, 
		course, 
		waypointIndex,
		xOffset,
		zOffset,
		context._allowReverse,
		context._useFieldNum,
		context._vehiclesToIgnore, 
		context._maxFruitPercent,
		context._offFieldPenalty, 
		context._areaToAvoid, 
		context._areaToIgnoreFruit)
	if done then 
		self:onFinish(path, goalNodeInvalid)
	else 
		self:debug("Continuing as coroutine...")
		self.pathfinder = pathfinder
	end
	return true
end

function PathfinderController:getTemporaryCourseFromPath(path)
	return Course(self.vehicle, CourseGenerator.pointsToXzInPlace(path), true)
end

--------------------------------------------
--- Debug functions
--------------------------------------------

function PathfinderController:debugStr(str, ...)
	return "Pathfinder controller: " .. str, ...
end

function PathfinderController:debug(...)
	CpUtil.debugVehicle(CpDebug.DBG_PATHFINDER, self.vehicle, self:debugStr(...))	
end

function PathfinderController:info(...)
	CpUtil.infoVehicle(self.vehicle, self:debugStr(...))	
end

function PathfinderController:error(...)
	self:info(...)
end