--[[
This file is part of Courseplay (https://github.com/Courseplay/Courseplay_FS22)
Copyright (C) 2022 - 2023 Courseplay Dev Team

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

---@class CpAITask
---@field taskIndex number
CpAITask = CpObject()
function CpAITask:init(isServer, job)
	self.isServer = isServer
	---@type CpAIJob
	self.job = job
	self.isFinished = false
	self.isRunning = false
	self.markAsFinished = false
	self.debugChannel = CpDebug.DBG_FIELDWORK
	self:reset()
end

function CpAITask:delete()
end

function CpAITask:update(dt)
end

function CpAITask:start()
	self.isFinished = false
	self.isRunning = true

	if self.markAsFinished then
		self.isFinished = true
		self.markAsFinished = false
	end
end

function CpAITask:skip()
	if self.isRunning then
		self.isFinished = true
	else
		self.markAsFinished = true
	end
end

function CpAITask:stop(wasJobStopped)
	self.isRunning = false
	self.markAsFinished = false
end

function CpAITask:reset()
	self.isFinished = false
	self.vehicle = nil
end

function CpAITask:validate(ignoreUnsetParameters)
	return true, nil
end

function CpAITask:getIsFinished()
	return self.isFinished
end

function CpAITask:setVehicle(v)
	self.vehicle = v
end

function CpAITask:getVehicle()
	return self.vehicle
end

function CpAITask:debug(...)
	if self.vehicle then
		CpUtil.debugVehicle(self.debugChannel, self.vehicle, ...)
	else
		CpUtil.debugFormat(self.debugChannel, ...)
	end
end