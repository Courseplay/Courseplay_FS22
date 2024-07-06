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

---
--- Helper class to generate headland corner maneuvers.
---
------@class Corner
Corner = CpObject()

---@param vehicle table the vehicle
---@param startAngleDeg number the angle we are arriving at the turn start waypoint (not the angle of the turn start wp, the angle
---of the one before!)
---@param startWp Waypoint turn start waypoint
---@param endAngleDeg number direction we want to end the turn
---@param endWp Waypoint turn end waypoint
---@param turnRadius number radius to use in this turn
---@param offsetX number left/right offset of the course. The Corner uses the un-offset coordinates of the start/end
--- waypoints and the offsetX to move the corner point diagonally inward or outward if the course has a side offset
function Corner:init(vehicle, startAngleDeg, startWp, endAngleDeg, endWp, turnRadius, offsetX)
	self.debugChannel = CpDebug.DBG_TURN
	self.vehicle = vehicle
	self.startWp = startWp
	self.endWp = endWp
	self.endAngleDeg = endAngleDeg
	self.offsetX = offsetX or 0
	self.startNode = CpUtil.createNode(tostring(self) .. '-cpTurnStartNode', self.startWp.x, self.startWp.z, math.rad(startAngleDeg))
	self.endNode = CpUtil.createNode(tostring(self) .. '-cpTurnEndNode', self.endWp.x, self.endWp.z, math.rad(self.endAngleDeg))
	self.alpha, self.reverseStartAngle = Corner.getAngles(startAngleDeg, endAngleDeg)
	self.turnDirection = self.alpha > 0 and 1 or -1
	self:debug('start: %.1f end: %.1f alpha: %.1f dir: %d',
		startAngleDeg, self.endAngleDeg, math.deg(self.alpha), self.turnDirection)

	self:findCornerNodes(startAngleDeg)
	self:findCircle(turnRadius)
end

function Corner.getAngles(startAngleDeg, endAngleDeg)
	-- the startAngle reversed by 180
	local reverseStartAngle = startAngleDeg > 0 and startAngleDeg - 180 or startAngleDeg + 180
	-- this is the corner angle
	local alpha = CpMathUtil.getDeltaAngle(math.rad(endAngleDeg), math.rad(reverseStartAngle))
	return alpha, reverseStartAngle
end

function Corner:delete()
	CpUtil.destroyNode(self.startNode)
	CpUtil.destroyNode(self.endNode)
	CpUtil.destroyNode(self.cornerStartNode)
	CpUtil.destroyNode(self.cornerNode)
	CpUtil.destroyNode(self.cornerEndNode)
end

--
--                              /
--                             /
--                   endNode  /
--                           x
--
--
--
--                      /
--                        alpha
--                    x  --         <-----x
--             cornerNode             startNode
--
function Corner:findCornerNodes(startAngle)
	-- As there's no guarantee that either of the start or end waypoints are in the corner,
	-- we first find the corner based on these turn start/end waypoints.
	-- The corner is at the intersection of the lines:
	-- line 1 through startWp at startAngle, and
	-- line 2 through endWp at endAngle

	-- So go ahead and find that point. First we need to make the lines long enough so they actually intersect
	-- must look far enough, start/end waypoints may be far away
	local extensionDistance = math.max(50, 1.5 * MathUtil.getPointPointDistance(self.startWp.x, self.startWp.z, self.endWp.x, self.endWp.z))
	-- extend line 1 back and forth
	local l1x1, _, l1z1 = localToWorld(self.startNode, 0, 0, -extensionDistance)
	local l1x2, _, l1z2 = localToWorld(self.startNode, 0, 0, extensionDistance)
	local l2x1, _, l2z1 = localToWorld(self.endNode, 0, 0, -extensionDistance)
	local l2x2, _, l2z2 = localToWorld(self.endNode, 0, 0, extensionDistance)
	-- The Giants MathUtil line intersection function is undocumented so use what we have:
	local is = CpMathUtil.getIntersectionPoint(l1x1, l1z1, l1x2, l1z2, l2x1, l2z1, l2x2, l2z2)
	if is then
		-- points to the inside of the corner from the corner, half angle between start and end. The center of the arc
		-- making a nice turn in this corner is on this line
		self.cornerNode = CpUtil.createNode(tostring(self) .. '-cpTurnHalfNode', is.x, is.z,
				CpMathUtil.getAverageAngle(math.rad(self.reverseStartAngle), math.rad(self.endAngleDeg)))
		self:debug('startAngle: %.1f, endAngle %.1f avg %.1f',
			self.reverseStartAngle, self.endAngleDeg, math.deg(CpMathUtil.getAverageAngle(math.rad(startAngle) + math.pi, math.rad(self.endAngleDeg))))
		-- move corner back according to the offset and turn direction it moves to the inside or outside
		local x, y, z = localToWorld(self.cornerNode, 0, 0, - self.offsetX / math.sin(self.alpha / 2))
		setTranslation(self.cornerNode, x, y, z)
		-- child nodes pointing towards the start and end waypoint. Every important location in the corner lies on these
		-- two lines, extending outwards from the corner.
		-- node at the corner, pointing back in the direction we were coming from to the turn start waypoint
		self.cornerStartNode = CpUtil.createNode(tostring(self) .. '-cpCornerStartNode', 0, 0, self.alpha / 2, self.cornerNode)
		-- node at the corner, pointing in the direction we will be leaving the turn end waypoint
		self.cornerEndNode = CpUtil.createNode(tostring(self) .. '-cpCornerEndNode', 0, 0, -self.alpha / 2, self.cornerNode)
		self:debug('%.1f %.1f, startAngle: %.1f, endAngle %.1f', is.x, is.z, startAngle, self.endAngleDeg)
	else
		self:debug('Could not find turn corner, using turn end waypoint')
		self.cornerNode = self.endNode
		self.cornerStartNode = self.startNode
		self.cornerEndNode = self.startNode
	end
end

-- Circle (arc) between the start and end lines
function Corner:findCircle(turnRadius)
	-- tangent points on the arc
	local r = turnRadius * 1.0
	-- distance between the corner and the tangent points
	self.dCornerToTangentPoints = math.abs(r / math.tan(self.alpha / 2))
	self.dCornerToCircleCenter = math.abs(self.dCornerToTangentPoints / math.cos(self.alpha / 2))
	self:debug('r=%.1f d=%.1f', r, self.dCornerToTangentPoints)
	self.arcStart, self.arcEnd, self.center = {}, {}, {}
	self.arcStart.x, _, self.arcStart.z = localToWorld(self.cornerStartNode, 0, 0, self.dCornerToTangentPoints)
	self.arcEnd.x, _, self.arcEnd.z = localToWorld(self.cornerEndNode, 0, 0, self.dCornerToTangentPoints)
	self.center.x, _, self.center.z = localToWorld(self.cornerNode, 0, 0, self.dCornerToCircleCenter)
	self:debug('arc start: %.1f %.1f, arc end: %.1f %.1f, arc center: %.1f %.1f ',
		self.arcStart.x, self.arcStart.z, self.arcEnd.x, self.arcEnd.z, self.center.x, self.center.z)
end

function Corner:getCornerStartNode()
	return self.cornerStartNode
end

--- Point in distance from the corner in the turn start direction. Positive number until the corner is reached
function Corner:getPointAtDistanceFromCornerStart(d, sideOffset)
	local x, y, z = localToWorld(self.cornerStartNode, sideOffset and sideOffset * self.turnDirection or 0, 0, d)
	return {x = x, y = y, z = z}
end

--- Point in distance from the point on the start leg where the arc begins. Positive until we reach the arc
function Corner:getPointAtDistanceFromArcStart(d)
	local x, y, z = localToWorld(self.cornerStartNode, 0, 0, self.dCornerToTangentPoints + d)
	return {x = x, y = y, z = z}
end

function Corner:getPointAtDistanceFromCornerEnd(d, sideOffset)
	local x, y, z = localToWorld(self.cornerEndNode, sideOffset and sideOffset * self.turnDirection or 0, 0, d)
	return {x = x, y = y, z = z}
end

function Corner:getPointAtDistanceFromArcEnd(d)
	local x, y, z = localToWorld(self.cornerEndNode, 0, 0, d + self.dCornerToTangentPoints)
	return {x = x, y = y, z = z}
end

function Corner:getCornerEndNode()
	return self.cornerEndNode
end

function Corner:getArcStart()
	return self.arcStart
end

function Corner:getArcEnd()
	return self.arcEnd
end

function Corner:getArcCenter()
	return self.center
end

function Corner:getEndAngleDeg()
	return self.endAngleDeg
end

function Corner:debug(...)
	CpUtil.debugVehicle(self.debugChannel, self.vehicle, 'Corner: ' .. string.format(...))
end

function Corner:drawDebug()
	if CpDebug:isChannelActive(self.debugChannel, self.vehicle) then
		local cx, cy, cz
		local nx, ny, nz
		if self.cornerNode then
			cx, cy, cz = localToWorld(self.cornerNode, 0, 0, 0)
			nx, ny, nz = localToWorld(self.cornerNode, 0, 0, 3)
			cpDebug:drawPoint(cx, cy + 6, cz, 0, 0, 70)
			DebugUtil.drawDebugLine(cx, cy + 6, cz, 0, 0, 30, nx, ny + 6, nz)
			nx, ny, nz = localToWorld(self.cornerStartNode, 0, 0, 3)
			DebugUtil.drawDebugLine(cx, cy + 6, cz, 0, 30, 0, nx, ny + 6, nz)
			nx, ny, nz = localToWorld(self.cornerEndNode, 0, 0, 3)
			DebugUtil.drawDebugLine(cx, cy + 6, cz, 30, 0, 0, nx, ny + 6, nz)
		end
	end
end
