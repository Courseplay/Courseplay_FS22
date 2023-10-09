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

--- Interface for any combine, choppers and loaders(ropa maus, ...) strategy.
--- This interface is for the common communication to the unloader strategies.
---@class Interface_AIDriveStrategyHarvesterOrLoader : AIDriveStrategyCourse
Interface_AIDriveStrategyHarvesterOrLoader = CpObject()
function Interface_AIDriveStrategyHarvesterOrLoader:init()
	
end

--- Offset of the pipe from the combine implement's root node
---@param additionalOffsetX number add this to the offsetX if you don't want to be directly under the pipe. If
--- greater than 0 -> to the left, less than zero -> to the right
---@param additionalOffsetZ number forward (>0)/backward (<0) offset from the pipe
---@return number pipe offset x
---@return number pipe offset z
function Interface_AIDriveStrategyHarvesterOrLoader:getPipeOffset(additionalOffsetX, additionalOffsetZ)
    return 0, 0
end

--- Distance to the back from the ai direction node.
---@return number
function Interface_AIDriveStrategyHarvesterOrLoader:getMeasuredBackDistance()
	return 0
end
