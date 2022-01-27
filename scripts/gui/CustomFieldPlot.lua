--[[
This file is part of Courseplay (https://github.com/Courseplay/Courseplay_FS22)
Copyright (C) 2022 Peter Vaiko

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

---@class CustomFieldPlot : CoursePlot
CustomFieldPlot = CpObject(CoursePlot)

--- Shows custom fields on the in-game map
function CustomFieldPlot:init()
	CoursePlot.init(self)
	-- use same color for the entire plot
	self.lightColor = {self:normalizeRgb(38, 174, 214)}
	self.darkColor = {self:normalizeRgb(38, 174, 214)}
	-- use a thicker line
	self.lineThickness = 4 / g_screenHeight
end

function CustomFieldPlot:draw(map)
	if not self.isVisible then return end
	self:drawPoints(map)
end

