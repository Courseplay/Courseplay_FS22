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
	local context = PathfinderContext(self.vehicle)
	context:set(
		...
	)
	self.pathfinderController:setCallbacks(self, self.onPathfindingFinished, self.onPathfindingFailed)

	local numRetries = 2
	self.pathfinderController:findPathToNode(context, ..., numRetries)

end

function Strategy:onPathfindingFinished(controller : PathfinderController, success : boolean,
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

function Strategy:onPathfindingFailed(controller : PathfinderController, lastContext : PathfinderContext,
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
]]

---@class DefaultFieldPathfinderControllerContext : PathfinderContext
DefaultFieldPathfinderControllerContext = CpObject(PathfinderContext)

function DefaultFieldPathfinderControllerContext:init(...)
	PathfinderContext.init(self, ...)
end

---@class PathfinderController 
PathfinderController= CpObject()

PathfinderController.defaultNumRetries = 0
PathfinderController.SUCCESS_FOUND_VALID_PATH = 0
PathfinderController.ERROR_NO_PATH_FOUND = 1
PathfinderController.ERROR_INVALID_GOAL_NODE = 2
function PathfinderController:init(vehicle)
	self.vehicle = vehicle
	---@type PathfinderInterface
	self.pathfinder = nil
	---@type PathfinderContext
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

---@return PathfinderContext
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
---@param context PathfinderContext
function PathfinderController:onStart(context, numRetries)
	self.numRetries = numRetries or self.defaultNumRetries
	self:debug("Started pathfinding with context: %s, retries: %d.", tostring(context), numRetries)
	self.startedAt = g_time
	self.lastContext = context
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
		retValue == self.SUCCESS_FOUND_VALID_PATH and self:getTemporaryCourseFromPath(path), 
		goalNodeInvalid)
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
---@param context PathfinderContext
---@param goalNode number
---@param xOffset number
---@param zOffset number
---@param numRetries number|nil how many times to retry, default 0
---@return boolean Was path finding started?
function PathfinderController:findPathToNode(context, goalNode, xOffset, zOffset, numRetries)

	if not self.callbackSuccessFunction then
		self:error("No valid success callback was given!") 
		return false
	end
	self:onStart(context, numRetries)
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
---@param context PathfinderContext
---@param course Course
---@param waypointIndex number
---@param xOffset number
---@param zOffset number
---@param numRetries number|nil how many times to retry, default 0
---@return boolean Was path finding started?
function PathfinderController:findPathToWaypoint(context, course, waypointIndex, xOffset, zOffset, numRetries)

	if not self.callbackSuccessFunction then 
		self:error("No valid success callback was given!") 
		return false
	end
	self:onStart(context, numRetries)
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

--- Finds a path to a waypoint of a course.
---@param context PathfinderContext
---@param goal State3D
---@param numRetries number|nil how many times to retry, default 0
---@return boolean Was path finding started?
function PathfinderController:findPathToGoal(context, goal, numRetries)

	if not self.callbackSuccessFunction then 
		self:error("No valid success callback was given!") 
		return false
	end
	self:onStart(context, numRetries)
	local pathfinder, done, path, goalNodeInvalid = PathfinderUtil.startPathfindingFromVehicleToGoal(
		context._vehicle, 
		goal, 
		context._allowReverse,
		context._useFieldNum,
		context._vehiclesToIgnore,
		context._objectsToIgnore, 
		context._maxFruitPercent,
		context._offFieldPenalty, 
		context._areaToAvoid,
		context._mustBeAccurate, 
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