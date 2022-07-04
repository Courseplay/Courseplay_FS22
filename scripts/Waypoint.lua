--[[
This file is part of Courseplay (https://github.com/Courseplay/courseplay)
Copyright (C) 2018 Peter Vajko

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

---@class Point
Point = CpObject()
function Point:init(x, z, yRotation)
	self.x = x
	self.z = z
	self.yRotation = yRotation or 0
end

function Point:clone()
	return Point(self.x, self.z, self.yRotation)
end

---@param other Point
function Point:copy(other)
	return self:clone(other)
end

function Point:translate(dx, dz)
	self.x = self.x + dx
	self.z = self.z + dz
end

function Point:rotate(yRotation)
	self.x, self.z =
	self.x * math.cos(yRotation) + self.z * math.sin(yRotation),
	- self.x * math.sin(yRotation) + self.z * math.cos(yRotation)
	self.yRotation = yRotation
end

--- Get the local coordinates of a world position
---@param x number
---@param z number
---@return number, number x and z local coordinates
function Point:worldToLocal(x, z)
	local lp = Point(x, z, 0)
	lp:translate(-self.x, -self.z)
	lp:rotate(-self.yRotation)
	return lp.x, lp.z
end

--- Convert the local x z coordinates to world coordinates
---@param x number
---@param z number
---@return number, number x and z world coordinates
function Point:localToWorld(x, z)
	local lp = Point(x, z, 0)
	lp:rotate(self.yRotation)
	lp:translate(self.x, self.z)
	return lp.x, lp.z
end

---@class Waypoint : Point
Waypoint = CpObject(Point)
Waypoint.xmlKey = ".waypoints.wp"

-- constructor from the legacy Courseplay waypoint
function Waypoint:init(cpWp, cpIndex)
	self:set(cpWp, cpIndex)
end

function Waypoint:set(wp, cpIndex)
	-- we initialize explicitly, no table copy as we want to have
	-- full control over what is used in this object
	self.x = wp.x or 0
	self.z = wp.z or 0
	self.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, self.x, 0, self.z)
	self.angle = wp.angle or nil
	self.radius = wp.radius or nil
	self.rev = wp.rev or wp.turnReverse or wp.reverse or false
	self.rev = self.rev or wp.gear and wp.gear == Gear.Backward
	self.speed = wp.speed
	self.cpIndex = cpIndex or 0
	self.turnStart = wp.turnStart
	self.turnEnd = wp.turnEnd
	self.interact = wp.wait or false
	self.isConnectingTrack = wp.isConnectingTrack or nil
	self.lane = wp.lane
	self.rowNumber = wp.rowNumber
	self.ridgeMarker = wp.ridgeMarker
	self.unload = wp.unload
	self.headlandHeightForTurn = wp.headlandHeightForTurn
	self.useTightTurnOffset = wp.useTightTurnOffset
	self.turnControls = table.copy(wp.turnControls)
	self.dToNext = wp.dToNext
	self.yRot = wp.yRot

	self.rawData = wp
end

--- Set from a generated waypoint (output of the course generator)
function Waypoint.initFromGeneratedWp(wp, ix)
	local waypoint = Waypoint({})
	waypoint.x = wp.x
	waypoint.z = -wp.y
	waypoint.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, waypoint.x, 0, waypoint.z)
	waypoint.cpIndex = ix or 0
	waypoint.turnStart = wp.turnStart
	waypoint.turnEnd = wp.turnEnd
	waypoint.isConnectingTrack = wp.isConnectingTrack or nil
	waypoint.lane = wp.passNumber and -wp.passNumber
	waypoint.rowNumber = wp.rowNumber
	waypoint.ridgeMarker = wp.ridgeMarker
	--- Todo check if the course generator side is correctly implement.
	waypoint.rev = wp.rev
	return waypoint
end

--- Set from a saved waypoint in a xml file.
function Waypoint.initFromXmlFile(data,ix)
	local waypoint = Waypoint({})
	waypoint.x = data[1]
	waypoint.z = data[2]
	waypoint.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, waypoint.x, 0, waypoint.z)
	waypoint.cpIndex = ix or 0
	waypoint.turnStart = data[3]
	waypoint.turnEnd = data[4]
	waypoint.isConnectingTrack = data[5]
	waypoint.lane = data[6]
	waypoint.rowNumber = data[7]
	waypoint.ridgeMarker = data[8]
	waypoint.rev = data[9]
	return waypoint
end

--- Gets the data to saves this waypoint in a xml file.
--- New attributes can be added at the bottom and should'nt break old courses.
--- To remove attributes, they should be filled with a zero otherwise old course might be broken.
--- Every attribute needs to be a number.
function Waypoint:getXmlString()
	local v = {
		MathUtil.round(self.x,2),
		MathUtil.round(self.z,2),
		self.turnStart or "-",
		self.turnEnd or "-",
		self.isConnectingTrack or "-",
		self.lane or "-",
		self.rowNumber or "-",
		self.ridgeMarker or "-",
		self.rev or "-",
	}
	return CpUtil.getXmlVectorString(v)
end

--- Get the (original, non-offset) position of a waypoint
---@return number, number, number x, y, z
function Waypoint:getPosition()
	return self.x, self.y, self.z
end

--- Get the offset position of a waypoint
---@param offsetX number left/right offset (right +, left -)
---@param offsetZ number forward/backward offset (forward +)
---@param dx number delta x to use (dx to the next waypoint by default)
---@param dz number delta z to use (dz to the next waypoint by default)
---@return number, number, number x, y, z
function Waypoint:getOffsetPosition(offsetX, offsetZ, dx, dz)
	local x, y, z = self:getPosition()
	local deltaX = dx or self.dx
	local deltaZ = dz or self.dz
	-- check for NaN
	if deltaX and deltaZ and deltaX == deltaX and deltaZ == deltaZ then
		-- X offset should be inverted if we drive reverse here (left is always left regardless of the driving direction)
		local reverse = self.reverseOffset and -1 or 1
		x = x - deltaZ * reverse * offsetX + deltaX * offsetZ
		z = z + deltaX * reverse * offsetX + deltaZ * offsetZ
	end
	return x, y, z
end

function Waypoint:setOffsetPosition(offsetX, offsetZ, dx, dz)
	self.x, self.y, self.z = self:getOffsetPosition(offsetX, offsetZ, dx, dz)
end

function Waypoint:getDistanceFromPoint(x, z)
	return MathUtil.getPointPointDistance(x, z, self.x, self.z)
end

function Waypoint:getDistanceFromVehicle(vehicle)
	local vx, _, vz = getWorldTranslation(vehicle:getAIDirectionNode() or vehicle.rootNode)
	return self:getDistanceFromPoint(vx, vz)
end

function Waypoint:getDistanceFromNode(node)
	local x, _, z = getWorldTranslation(node)
	return self:getDistanceFromPoint(x, z)
end

function Waypoint:setPosition(x, z, y)
	self.x = x 
	self.z = z 
	if y then 
		self.y = y 
	else 
		self.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 0, z)
	end
end

function Waypoint:translate(dx, dz)
	self.x = self.x + dx
	self.z = self.z + dz
	self.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, self.x, 0, self.z)
end

function Waypoint:clone()
	return Waypoint(self.rawData)
end

-- a node related to a waypoint
---@class WaypointNode
WaypointNode = CpObject()
WaypointNode.MODE_NORMAL = 1
WaypointNode.MODE_LAST_WP = 2
WaypointNode.MODE_SWITCH_DIRECTION = 3
WaypointNode.MODE_SWITCH_TO_FORWARD = 4

function WaypointNode:init(name, logChanges)
	self.logChanges = logChanges
	self.node = CpUtil.createNode(name, 0, 0, 0)
end

function WaypointNode:destroy()
	CpUtil.destroyNode(self.node)
end

---@param course Course
function WaypointNode:setToWaypoint(course, ix, suppressLog)
	local newIx = math.min(ix, course:getNumberOfWaypoints())
	if newIx ~= self.ix and self.logChanges and not suppressLog then
		CpUtil.debugVehicle(CpDebug.DBG_PPC, course.vehicle, 'PPC: %s waypoint index %d', getName(self.node), ix)
	end
	self.ix = newIx
	local x, y, z = course:getWaypointPosition(self.ix)
	setTranslation(self.node, x, y, z)
	setRotation(self.node, 0, course:getWaypointYRotation(self.ix), 0)
end

-- Allow ix > #Waypoints, in that case move the node lookAheadDistance beyond the last WP
function WaypointNode:setToWaypointOrBeyond(course, ix, distance)
	--if self.ix and self.ix > ix then return end
	if ix > course:getNumberOfWaypoints() then
		-- beyond the last, so put it on the last for now
		-- but use the direction of the one before the last as the last one's is bogus
		self:setToWaypoint(course, course:getNumberOfWaypoints())
		setRotation(self.node, 0, course:getWaypointYRotation(course:getNumberOfWaypoints() - 1), 0)
		-- And now, move ahead a bit.
		local nx, ny, nz = localToWorld(self.node, 0, 0, distance)
		setTranslation(self.node, nx, ny, nz)
		if self.logChanges and self.mode and self.mode ~= WaypointNode.MODE_LAST_WP then
			CpUtil.debugVehicle(CpDebug.DBG_PPC, course.vehicle, 'PPC: last waypoint reached, moving node beyond last: %s', getName(self.node))
		end
		
		self.mode = WaypointNode.MODE_LAST_WP
	elseif course:switchingToReverseAt(ix) or course:switchingToForwardAt(ix) then
		-- just like at the last waypoint, if there's a direction switch, we want to drive up
		-- to the waypoint so we move the goal point beyond it
		-- the angle of ix is already pointing to reverse here
		self:setToWaypoint(course, ix)
		-- turn node back as this is the one before the first reverse, already pointing to the reverse direction.
		local _, yRot, _ = getRotation(self.node)
		setRotation(self.node, 0, yRot + math.pi, 0)
		-- And now, move ahead a bit.
		local nx, ny, nz = localToWorld(self.node, 0, 0, distance)
		setTranslation(self.node, nx, ny, nz)
		if self.logChanges and self.mode and self.mode ~= WaypointNode.MODE_SWITCH_DIRECTION then
			CpUtil.debugVehicle(CpDebug.DBG_PPC, course.vehicle, 'PPC: switching direction at %d, moving node beyond it: %s', ix, getName(self.node))
		end
		self.mode = WaypointNode.MODE_SWITCH_DIRECTION
	else
		if self.logChanges and self.mode and self.mode ~= WaypointNode.MODE_NORMAL then
			CpUtil.debugVehicle(CpDebug.DBG_PPC, course.vehicle, 'PPC: normal waypoint (not last, no direction change: %s', getName(self.node))
		end
		self.mode = WaypointNode.MODE_NORMAL
		self:setToWaypoint(course, ix)
	end
end

