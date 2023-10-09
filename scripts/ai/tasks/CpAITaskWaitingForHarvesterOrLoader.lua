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

--- Task to wait for an unload target like a harvester or loader vehicle
---@class CpAITaskWaitingForHarvesterOrLoader : CpAITask
---@field job CpAIJobCombineUnloader
CpAITaskWaitingForHarvesterOrLoader = CpObject(CpAITask)

function CpAITaskWaitingForHarvesterOrLoader:start()
	if self.isServer then 
		self:debug("Waiting for harvester or loader task started")
		local strategy = AIDriveStrategyWaitingForHarvesterOrLoader(self)
		strategy:setAIVehicle(self.vehicle)
		strategy:setJobParameterValues(self.job:getCpJobParameters())
		self.vehicle:startCpWithStrategy(strategy)
	end
	CpAITask.start(self)
end

function CpAITaskWaitingForHarvesterOrLoader:stop(wasJobStopped)
	if not self.isServer then 
		self:debug("Waiting for harvester or loader task stopped")
		self.vehicle:stopCpDriver(wasJobStopped)
	end
	CpAITask.stop(self)
end

---@param targetStrategy AIDriveStrategyCourse
---@param targetVehicle table
---@param targetPoint Waypoint|number|nil
function CpAITaskWaitingForHarvesterOrLoader:setTarget(targetStrategy, targetVehicle, targetPoint)
	self.job:setTarget(targetStrategy, targetVehicle, targetPoint)
end

function CpAITaskWaitingForHarvesterOrLoader:skipToUnloadNow()
	self.job:skipToUnloadNow()
end