--[[
This file is part of Courseplay (https://github.com/Courseplay/Courseplay_FS22)
Copyright (C) 2021 Peter Vaiko

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

Drive strategy for driving a vine field work course

]]--

---@class AIDriveStrategyVineFieldWorkCourse : AIDriveStrategyFieldWorkCourse
AIDriveStrategyVineFieldWorkCourse = {}
local AIDriveStrategyVineFieldWorkCourse_mt = Class(AIDriveStrategyVineFieldWorkCourse, AIDriveStrategyFieldWorkCourse)

function AIDriveStrategyVineFieldWorkCourse.new(customMt)
    if customMt == nil then
        customMt = AIDriveStrategyVineFieldWorkCourse_mt
    end
    local self = AIDriveStrategyFieldWorkCourse.new(customMt)
    
    return self
end

function AIDriveStrategyVineFieldWorkCourse:setAIVehicle(...)
    AIDriveStrategyVineFieldWorkCourse:superClass().setAIVehicle(self, ...)
end

--- Always disables turn on field.
function AIDriveStrategyVineFieldWorkCourse:isTurnOnFieldActive()
    return false
end