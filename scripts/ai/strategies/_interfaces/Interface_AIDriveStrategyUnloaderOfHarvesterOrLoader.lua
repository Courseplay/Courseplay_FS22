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

--- Interface for any unload strategy for combine, choppers and loaders(ropa maus, ...).
---@class Interface_AIDriveStrategyUnloaderOfHarvesterOrLoader : AIDriveStrategyCourse
Interface_AIDriveStrategyUnloaderOfHarvesterOrLoader = CpObject()
function Interface_AIDriveStrategyUnloaderOfHarvesterOrLoader:init()
	
end

--- Sets the unload target 
---@param targetStrategy AIDriveStrategyCourse
---@param targetVehicle table
---@param targetPoint Waypoint|number|nil
function Interface_AIDriveStrategyUnloaderOfHarvesterOrLoader:setTarget(targetVehicle, targetStrategy, targetPoint)
	
end