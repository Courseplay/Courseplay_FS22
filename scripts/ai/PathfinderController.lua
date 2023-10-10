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
PathfinderController for easy access to the pathfinder.
- Enables retrying with adjustable parameters compared to the last try, like fruit allowed and so..
- Handles the pathfinder coroutines if needed.
- One callback when the path finding finished.
	- Triggered if a valid path was found.
	- Gets triggered if the goal node is invalid.
	- Also gets triggered if no valid path was found and all retry attempts are used.
- Every time the path finding failed a callback gets triggered, if there are retry attempts left over.
	- Enabled the changing of the pathfinder context and restart with the new context.

PathfinderControllerContext implements all pathfinder parameters and the number of retries allowed.
- Other Context Classes could be derived for commonly used contexts. 



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
	path : table, goalNodeInvalid : boolean|nil)
	if success then
		// Path finding finished successfully
		local course = self.pathfinderController:getTemporaryCourseFromPath(path)
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

]]

---@class PathfinderControllerContext
PathfinderControllerContext = CpObject()
PathfinderControllerContext.defaultNumRetries = 0
function PathfinderControllerContext:init(vehicle, numRetries)
	self.vehicle = vehicle
	self.numRetries = numRetries or self.defaultNumRetries
	--- Percentage of fruit allowed, math.hug means no fruit avoidance
	self.maxFruitPercent = nil
	--- Penalty sticking on the field and avoiding outside of the field
	self.offFieldPenalty = nil
	--- Should none owned field be avoid?
	self.useFieldNum = false
	--- A given area that has to be avoided.
	self.areaToAvoid = nil
	--- Is reverse driving allowed?
	self.allowReverse = false
	--- Vehicle Collisions that are ignored.
	self.vehiclesToIgnore = nil
	--- Is a accurate pathfinder goal position needed?
	self.mustBeAccurate = false
	self.areaToIgnoreFruit = nil
end

--- Sets the Pathfinder context
---@param mustBeAccurate boolean|nil
---@param allowReverse boolean|nil
---@param maxFruitPercent number|nil
---@param offFieldPenalty number|nil
---@param useFieldNum boolean|nil
---@param areaToAvoid table|nil
---@param vehiclesToIgnore table|nil
---@param areaToIgnoreFruit table|nil
function PathfinderControllerContext:set(
	mustBeAccurate, allowReverse, 
	maxFruitPercent, offFieldPenalty, useFieldNum, 
	areaToAvoid, vehiclesToIgnore, areaToIgnoreFruit)
	self.maxFruitPercent = maxFruitPercent
	self.offFieldPenalty = offFieldPenalty
	self.useFieldNum = useFieldNum
	self.areaToAvoid = areaToAvoid
	self.allowReverse = allowReverse
	self.vehiclesToIgnore = vehiclesToIgnore
	self.mustBeAccurate = mustBeAccurate
	self.areaToIgnoreFruit = areaToIgnoreFruit
end

--- Disables the fruit avoidance
function PathfinderControllerContext:ignoreFruit()
	self.maxFruitPercent = math.huge
end

function PathfinderControllerContext:getNumRetriesAllowed()
	return self.numRetries
end

function PathfinderControllerContext:__tostring()
	local str = "PathfinderControllerContext(vehicle name=%s, maxFruitPercent=%s, "+ 
		"offFieldPenalty=%s, useFieldNum=%s, areaToAvoid=%s, allowReverse=%s, "+
		"vehiclesToIgnore=%s, mustBeAccurate=%s, areaToIgnoreFruit=%s)"
	return string.format(str,
		CpUtil.getName(self.vehicle),
		tostring(self.maxFruitPercent),
		tostring(self.offFieldPenalty),
		tostring(self.useFieldNum),
		tostring(self.areaToAvoid),
		tostring(self.allowReverse),
		tostring(self.vehiclesToIgnore),
		tostring(self.mustBeAccurate),
		tostring(self.areaToIgnoreFruit))
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
	self.callbackClass = nil
	self.callbackSuccessFunction = nil 
	self.callbackRetryFunction = nil
	self.lastContext = nil
end

function PathfinderController:update(dt)
	if self:isActive() then
		--- Applies coroutine for path finding
		local done, path, goalNodeInvalid = self.pathfinder:resume()
        if done then
			self:finished(path, goalNodeInvalid)
        end
	end
end

function PathfinderController:isActive()
	return self.pathfinder and self.pathfinder:isActive()
end

---@return PathfinderControllerContext
function PathfinderController:getLastContext()
	return self.lastContext
end

--- Sets the callbacks which get called on the pathfinder finish.
---@param class table
---@param successFunc function func(PathfinderController, success, path, goalNodeInvalid)
---@param retryFunc function func(PathfinderController, last context, was last retry, retry attempt number)
function PathfinderController:setCallbacks(class, successFunc, retryFunc)
	self.callbackClass = class
	self.callbackSuccessFunction = successFunc 
	self.callbackRetryFunction = retryFunc
end

--- Pathfinder was started
---@param context PathfinderControllerContext
function PathfinderController:started(context)
	self:debug("Started pathfinding with context: %s.", tostring(context))
	self.startedAt = g_time
	self.lastContext = context
	self.numRetries = context:getNumRetriesAllowed()
end

function PathfinderController:callCallback(callbackFunc, ...)
	if self.callbackClass then 
		callbackFunc(self.callbackClass, self, ...)
	else 
		callbackFunc(self, ...)
	end
end

--- Path finding has finished
---@param path table|nil
---@param goalNodeInvalid boolean|nil
function PathfinderController:finished(path, goalNodeInvalid)
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
				self:callCallback(self.callbackRetryFunction, self.lastContext, self.failCount == self.numRetries, self.failCount)
				return
			end
		end
	end
	self:callCallback(self.callbackSuccessFunction, retValue == self.SUCCESS_FOUND_VALID_PATH, path, goalNodeInvalid)
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
	self:started(context)
	local pathfinder, done, path, goalNodeInvalid = PathfinderUtil.startPathfindingFromVehicleToNode(
		context.vehicle,
		goalNode,
		xOffset,
		zOffset,
		context.allowReverse, 
		context.useFieldNum and 1,
		context.vehiclesToIgnore,
		context.maxFruitPercent,
		context.offFieldPenalty,
		context.areaToAvoid,
		context.mustBeAccurate
	)
	if done then 
		self:finished(path, goalNodeInvalid)
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
	self:started(context)
	local pathfinder, done, path, goalNodeInvalid = PathfinderUtil.startPathfindingFromVehicleToWaypoint(
		context.vehicle, 
		course, 
		waypointIndex,
		xOffset,
		zOffset,
		context.allowReverse,
		context.useFieldNum and CpFieldUtil.getFieldNumUnderVehicle(context.vehicle),
		context.vehiclesToIgnore, 
		context.maxFruitPercent,
		context.offFieldPenalty, 
		context.areaToAvoid, 
		context.areaToIgnoreFruit)
	if done then 
		self:finished(path, goalNodeInvalid)
	else 
		self:debug("Continuing as coroutine...")
		self.pathfinder = pathfinder
	end
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