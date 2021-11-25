--[[
This file is part of Courseplay (https://github.com/Courseplay/courseplay)
Copyright (C) 2018 Peter Vaiko

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

CoursePlot = CpObject()

-- Position and size of the course plot as normalized screen coordinates
-- x = 0, y = 0 is the bottom left corner of the screen, terrainSize is in meters
---@param map table, an Inga derived class where the plot is displayed
function CoursePlot:init(map)
	self.map = map
	self.courseOverlayId = createImageOverlay('dataS/scripts/shared/graph_pixel.dds')
	self.startSignOverlayId = createImageOverlay(Utils.getFilename('img/signs/start_noMM.dds', Courseplay.BASE_DIRECTORY))
	self.stopSignOverlayId = createImageOverlay(Utils.getFilename('img/signs/stop_noMM.dds', Courseplay.BASE_DIRECTORY))
	self.startPosition = {}
	self.stopPosition = {}
	self.isVisible = false
	-- the normal FS22 blue
	self.color = {self:normalizeRgb(42, 193, 237)}
	-- a lighter shade of the same color
	self.lightColor = {self:normalizeRgb(45, 207, 255)}
	-- a darker shade of the same color
	self.darkColor = {self:normalizeRgb(19, 87, 107)}
end

function CoursePlot:normalizeRgb(r, g, b)
	return r / 255, g / 255, b / 255
end

function CoursePlot:delete()
	if self.courseOverlayId ~= 0 then
		delete(self.courseOverlayId);
	end;
	if self.startSignOverlayId ~= 0 then
		delete(self.startSignOverlayId);
	end;
end

function CoursePlot:setVisible( isVisible )
	self.isVisible = isVisible
end

function CoursePlot:setWaypoints( waypoints )
	self.waypoints = {}
	-- remove waypoints from long straight lines, the plot only needs start/end. Too many waypoints
	-- in the plot are a performance problem
	table.insert(self.waypoints, waypoints[1])
	self.waypoints[1].progress = 0
	for i = 2, #waypoints - 1 do
		if math.abs(waypoints[i].angle - waypoints[i - 1].angle) > math.pi / 1800 then
			table.insert(self.waypoints, waypoints[i])
			self.waypoints[#self.waypoints].progress = i / #waypoints
		end
	end
	table.insert(self.waypoints, waypoints[#waypoints])
	self.waypoints[1].progress = 1
end

-- start position used when generating the course, either first course wp
-- or the position selected by the user on the map. We'll show a sign there.
function CoursePlot:setStartPosition( x, z )
	self.startPosition.x, self.startPosition.z = x, z
end

-- end position of the course
function CoursePlot:setStopPosition( x, z )
	self.stopPosition.x, self.stopPosition.z = x, z
end

function CoursePlot:worldToScreen( worldX, worldZ )
	local objectX = (worldX + self.map.worldCenterOffsetX) / self.map.worldSizeX * 0.5 + 0.25
	local objectZ = (worldZ + self.map.worldCenterOffsetZ) / self.map.worldSizeZ * 0.5 + 0.25
	local x, y, _, _ = self.map.fullScreenLayout:getMapObjectPosition(objectX, objectZ, 0, 0, 0, true)
	return x, y
end

function CoursePlot:screenToWorld( x, y )
	local worldX = ((x - self.x) / self.scaleX) - self.worldOffsetX
	local worldZ = ((y - self.y - self.height) / -self.scaleZ) - self.worldOffsetZ
	return worldX, worldZ
end

-- Draw the course in the screen area defined in new(), the bottom left corner
-- is at worldX/worldZ coordinates, the size shown is worldWidth wide (and high)
function CoursePlot:draw()

	if not self.isVisible then return end
	local lineThickness = 2 / g_screenHeight -- 2 pixels

--	if g_updateLoopIndex % 200 == 0 then
--		local wx, wz = self.waypoints[1].x, self.waypoints[1].z
--		local x, y = self:worldToScreen(wx, wz)
--		print(string.format('%.1f/%.1f -> %.1f/%.1f', wx, wz, x, y))
--	end

	if self.waypoints and #self.waypoints > 1 then
		-- I know this is in helpers.lua already but that code has too many dependencies
		-- on global variables and vehicle.cp.
		local wp, np, startX, startY, endX, endY, dx, dz, dx2D, dy2D, width, rotation, r, g, b

		-- render a line between subsequent waypoints
		for i = 1, #self.waypoints - 1 do
			wp = self.waypoints[ i ]
			np = self.waypoints[ i + 1 ]

			startX, startY = self:worldToScreen( wp.x, wp.z )
			endX, endY	   = self:worldToScreen( np.x, np.z )
			-- render only if it is on the plot area
			if startX and startY and endX and endY then
				dx2D = endX - startX;
				dy2D = ( endY - startY ) / g_screenAspectRatio;
				width = MathUtil.vector2Length(dx2D, dy2D);

				dx = np.x - wp.x;
				dz = np.z - wp.z;
				rotation = MathUtil.getYRotationFromDirection(dx, dz) - math.pi * 0.5;
				r, g, b = MathUtil.vector3ArrayLerp(self.lightColor, self.darkColor, wp.progress);

				--r, g, b = self:normalizeRgb(42, 193, 237)

				setOverlayColor( self.courseOverlayId, r, g, b, 1 )
				setOverlayRotation( self.courseOverlayId, rotation, 0, 0 )
				renderOverlay( self.courseOverlayId, startX, startY, width, lineThickness )
			end
		end;
		setOverlayRotation( self.courseOverlayId, 0, 0, 0 ) -- reset overlay rotation
	end

	local signSizeMeters = 20
	local zoom = self.map.fullScreenLayout:getIconZoom()
	local signWidth, signHeight = signSizeMeters * self.map.uiScale * zoom, signSizeMeters * self.map.uiScale * zoom

	-- render a sign marking the end of the course
	if self.stopPosition.x and self.stopPosition.z then
		local x, y = self:worldToScreen( self.stopPosition.x, self.stopPosition.z )
		if x and y then
			setOverlayColor( self.stopSignOverlayId, 1, 1, 1, 0.8 )
			renderOverlay( self.stopSignOverlayId,
				x - signWidth / 2, -- offset so the middle of the sign is on the stopping location
				y - signHeight / 2,
				signWidth, signHeight)
		end
	end

	-- render a sign marking the current position used as a starting location for the course
	if self.startPosition.x and self.startPosition.z then
		local x, y = self:worldToScreen( self.startPosition.x, self.startPosition.z )
		if x and y then
			setOverlayColor( self.startSignOverlayId, 1, 1, 1, 0.8 )
			renderOverlay( self.startSignOverlayId,
				x - signWidth / 2, -- offset so the middle of the sign is on the starting location
				y - signHeight / 2,
				signWidth, signHeight)
		end
	end
end