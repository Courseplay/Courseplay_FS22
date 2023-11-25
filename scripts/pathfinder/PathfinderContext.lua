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
--- Pathfinder controller context
--------------------------------------------

PathfinderContext implements all pathfinder parameters.
        - Other Context Classes could be derived for commonly used contexts.
        - Only the attributesToDefaultValue table has to be changed in the derived class.

Example usage of the builder api:

local context = PathfinderContext():maxFruitPercent(100):useFieldNum(10):vehiclesToIgnore({vehicle})

]]

---@class PathfinderContext
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
---@field _objectsToIgnore table[]|nil
---@field _mustBeAccurate boolean
---@field _areaToIgnoreFruit table[]
PathfinderContext = CpObject()
PathfinderContext.attributesToDefaultValue = {
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
    ["vehiclesToIgnore"] = {},
    ["objectsToIgnore"] = {},
    -- If false, as we reach the maximum iterations, we relax our criteria to reach the goal: allow for arriving at
    -- bigger angle differences, trading off accuracy for speed. This usually results in a direction at the goal
    -- being less then 30º off which in many cases isn't a problem.
    -- Otherwise, for example when a combine self unloading must accurately find the trailer, set this to true.
    ["mustBeAccurate"] = false,
    -- No fruit penalty in this area (e.g. when we know the goal is in fruit but want to avoid fruit all the way there)
    ["areaToIgnoreFruit"] = CpObjectUtil.BUILDER_API_NIL
}

function PathfinderContext:init(vehicle)
    self._vehicle = vehicle
    CpObjectUtil.registerBuilderAPI(self, self.attributesToDefaultValue)
end

--- Disables the fruit avoidance
function PathfinderContext:ignoreFruit()
    self._maxFruitPercent = math.huge
    return self
end

--- Uses the field number of the vehicle to restrict path finding.
function PathfinderContext:useVehicleFieldNumber()
    self._useFieldNum = CpFieldUtil.getFieldNumUnderVehicle(self._vehicle)
    return self
end

function PathfinderContext:__tostring()
    local str = string.format('[ %s: ', CpUtil.getName(self._vehicle))
    for attributeName, _ in pairs(PathfinderContext.attributesToDefaultValue) do
        local variableName = '_' .. attributeName
        str = str .. string.format('%s: %s ', variableName, self[variableName])
    end
    str = str .. ']'
    return str
end