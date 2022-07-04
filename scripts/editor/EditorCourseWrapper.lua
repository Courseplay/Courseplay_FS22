
--- Wrapper for the course object, which allows waypoint manipulations.
---@class EditorCourseWrapper
EditorCourseWrapper = CpObject()

function EditorCourseWrapper:init(course)
	self.course = course
	self.selectedWaypoints = {}
	self.hoveredWaypointIx = nil
	self.headlandMode = nil
	self.rowNumberMode = nil
	self.connectingTrackActive = false
end

function EditorCourseWrapper:getCourse()
	return self.course	
end

function EditorCourseWrapper:getWaypoints()
	return self.course.waypoints	
end

function EditorCourseWrapper:getFirstWaypointPosition()
	return self.course:getWaypointPosition(1)
end

function EditorCourseWrapper:getAllWaypoints()
	return self.course:getAllWaypoints()
end

------------------------------------
--- Course display interaction.
------------------------------------

--- Is the waypoint hovered by a editor brush?
function EditorCourseWrapper:isHovered(ix)
	return self.hoveredWaypointIx == ix
end

--- Sets the hovered waypoint by the editor brush.
function EditorCourseWrapper:setHovered(ix)
	self.hoveredWaypointIx = ix
end

function EditorCourseWrapper:resetHovered()
	self.hoveredWaypointIx = nil
end

--- Is the waypoint selected by a editor brush?
function EditorCourseWrapper:isSelected(ix)
	if ix then
		return self.selectedWaypoints[ix]
	end
end

function EditorCourseWrapper:setSelected(ix)
	if ix then
		self.selectedWaypoints[ix] = true
	end
end

function EditorCourseWrapper:resetSelected()
	self.selectedWaypoints = {}
end

--- Sets the selected headland to show, 0 == lanes are visible.
function EditorCourseWrapper:setHeadlandMode(mode)
	self.headlandMode = mode	
end

--- Sets the selected lane to show.
function EditorCourseWrapper:setRowNumberMode(mode)
	self.rowNumberMode = mode	
end

--- Sets the connecting track visible.
function EditorCourseWrapper:setConnectingTrackActive(active)
	self.connectingTrackActive = active	
end

function EditorCourseWrapper:isHeadland(ix)
	local wp = ix ~=nil and self.course:getWaypoint(ix)
	if wp and self.headlandMode ~= nil then
		if self.headlandMode > 0 then
			return self.course:isOnHeadland(ix, self.headlandMode)
		elseif self.headlandMode == 0 then
			return not self.course:isOnHeadland(ix)
		end
	end
end

function EditorCourseWrapper:isOnRowNumber(ix)
	local wp = ix ~=nil and self.course:getWaypoint(ix)
	if wp and wp.rowNumber ~= nil and self.rowNumberMode ~= nil then
		return wp.rowNumber == self.rowNumberMode
	end
end

function EditorCourseWrapper:isConnectingTrack(ix)
	local wp = ix ~=nil and self.course:getWaypoint(ix)
	if wp and self.connectingTrackActive then
		return self.course:isOnConnectingTrack(ix)
	end
end

------------------------------------
--- Course editor interaction.
------------------------------------

--- Inserts a waypoint ahead of the given waypoint.
--- The inserted waypoint has the same attributes, as the selected one.
function EditorCourseWrapper:insertWaypointAhead(ix)
	local waypoint = self.course:getWaypoint(ix)
	if waypoint then 
		local frontWp = self.course:getWaypoint(ix-1)
		if frontWp and ix > 1 then 
			local x, z = frontWp.x + (waypoint.x - frontWp.x)/2 , frontWp.z + (waypoint.z - frontWp.z)/2
			local wp = waypoint:clone()
			wp:setPosition(x, z)
			table.insert(self.course.waypoints, ix, wp)
		else 
			local backWp = self.course:getWaypoint(ix+1)
			if backWp then
				local dx, dz = MathUtil.vector2Normalize(backWp.x - waypoint.x, backWp.z - waypoint.z)
				local x, z = waypoint.x - dx * 3, waypoint.z - dz * 3
				local wp = waypoint:clone()
				wp:setPosition(x, z)
				table.insert(self.course.waypoints, 1, wp)
			end
		end
		
	end
end

--- Inserts a waypoint behind the given waypoint.
--- The inserted waypoint has the same attributes, as the selected one.
function EditorCourseWrapper:insertWaypointBehind(ix)
	local waypoint = self.course:getWaypoint(ix)
	local wp
	if waypoint then 
		local backWp = self.course:getWaypoint(ix+1)
		if backWp and ix < #self.course.waypoints then 
			local x, z = waypoint.x + (backWp.x - waypoint.x)/2 , waypoint.z + (backWp.z - waypoint.z)/2
			wp = waypoint:clone()
			wp:setPosition(x, z)
			table.insert(self.course.waypoints, ix+1, wp)
		else 
			local frontWp = self.course:getWaypoint(ix-1)
			if frontWp then
				local dx, dz = MathUtil.vector2Normalize(waypoint.x - frontWp.x, waypoint.z - frontWp.z)
				local x, z = waypoint.x + dx * 3, waypoint.z + dz * 3
				wp = waypoint:clone()
				wp:setPosition(x, z)
				table.insert(self.course.waypoints, wp)
			end
		end
	end
	return wp
end

--- Moves the waypoint to a given world position.
function EditorCourseWrapper:setWaypointPosition(ix, x, z)
	local waypoint = self.course:getWaypoint(ix)
	if waypoint then 
		waypoint:setPosition(x, z)
	end
end

--- Moves the waypoint by a given difference.
function EditorCourseWrapper:moveMultipleWaypoints(firstIx, lastIx, dx, dz)
	for i=firstIx,lastIx do
		local wp = self.course:getWaypoint(i)
		if wp then 
			wp:translate(dx, dz)
		end
	end
end

--- Deletes a given waypoint.
function EditorCourseWrapper:deleteWaypoint(ix)
	local wp = self.course:getWaypoint(ix)
	if wp and self.course:getNumberOfWaypoints() > 5 then 
		table.remove(self.course.waypoints, ix)
	end
end

--- Deletes waypoints in between.
function EditorCourseWrapper:deleteWaypointsBetween(firstIx, lastIx)
	for ix=lastIx-1, firstIx + 1, -1 do
		local wp = self.course:getWaypoint(ix)
		if wp then
			table.remove(self.course.waypoints, ix)
		end
	end
end

--- Changes the waypoint type between normal, turn start and turn end.
function EditorCourseWrapper:changeWaypointType(ix)
	local wp = self.course:getWaypoint(ix)
	if wp then 
		if wp.turnStart then 
			wp.turnStart = false 
			wp.turnEnd = true
		elseif wp.turnEnd then 
			wp.turnEnd = false 
		else
			wp.turnStart = true 
		end
	end
end

--- Gets the waypoint type (normal, turn start and turn end)
function EditorCourseWrapper:getWaypointType(ix)
	local wp = ix ~=nil and self.course:getWaypoint(ix)
	if wp then
		if wp.turnStart then 
			return CpBrushChangeWP.TYPES.TURN_START
		elseif wp.turnEnd then 
			return CpBrushChangeWP.TYPES.TURN_END
		else
			return CpBrushChangeWP.TYPES.NORMAL
		end
	end
end

--- Changes the headland of a given waypoint.
function EditorCourseWrapper:changeHeadland(ix, n)
	local wp = ix ~=nil and self.course:getWaypoint(ix)
	if wp then
		if n == 0 then 
			wp.lane = nil
		else
			wp.lane = -n
		end
	end
end

--- Sets the connecting track of a waypoint.
function EditorCourseWrapper:setConnectingTrack(ix, set)
	local wp = ix ~=nil and self.course:getWaypoint(ix)
	if wp then
		wp.isConnectingTrack = set
	end
end

--- Set the lane number.
function EditorCourseWrapper:getMaxRowNumber()
	local max = 0
	for i=1, self.course:getNumberOfWaypoints() do 
		local wp = self.course:getWaypoint(i)
		if wp and wp.rowNumber ~= nil then 
			max = math.max(max, wp.rowNumber)
		end
	end
	return max
end

--- Changes the row number of a given waypoint.
function EditorCourseWrapper:changeRowNumber(ix, n)
	local wp = ix ~=nil and self.course:getWaypoint(ix)
	if wp then
		if n == 0 then 
			wp.rowNumber = nil
		else 
			wp.rowNumber = n
		end
	end
end

--- Creates dynamic waypoint curves.
function EditorCourseWrapper:updateCurve(firstIx, lastIx, x, z)
	
	local wp = self.course:getWaypoint(firstIx)
	local np = self.course:getWaypoint(lastIx)

	if wp and np then 
		local dist = MathUtil.vector2Length(np.x - x,np.z - z) + MathUtil.vector2Length(wp.x - x,wp.z - z)
								 
		local dt = 1/dist
		local points = {
			{
				wp.x,
				wp.z
			},
			{
				x,
				z
			},
			{
				np.x,
				np.z
			}
		}
		self:deleteWaypointsBetween(firstIx, lastIx)
		local i = firstIx
		for t=dt , 1, dt do 
			local dx, dz = CpMathUtil.de_casteljau(t, points)
			local p = self:insertWaypointBehind(i)
			p:setPosition(dx, dz)
			i = i + 1
		end
		--- Cleans points that are to close to each other.
		for j=i, firstIx, -1 do 
			local wp = self.course:getWaypoint(j)
			local pp = self.course:getWaypoint(j - 1)
			if wp and pp and MathUtil.vector2Length(wp.x - pp.x, wp.z - pp.z) < 0.75 then 
				table.remove(self.course.waypoints, j)
				i = i - 1
			end
		end
		return i + 1
	end
end