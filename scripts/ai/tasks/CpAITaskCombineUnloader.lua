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

---@class CpAITaskCombineUnloader : CpAITask
CpAITaskCombineUnloader = CpObject(CpAITask)

function CpAITaskCombineUnloader:start()
	if self.isServer then
		self:debug("Combine unloader task started")
		local class = self:getNeededStrategy()
		---@type Interface_AIDriveStrategyUnloaderOfHarvesterOrLoader
		local strategy = class(self)
		strategy:setAIVehicle(self.vehicle, self.job:getCpJobParameters())
		strategy:setTarget(self.targetVehicle, self.targetStrategy, self.targetPoint)
		self.vehicle:startCpWithStrategy(strategy)
	end
	CpAITask.start(self)
end

function CpAITaskCombineUnloader:reset()
	CpAITask.reset(self)
	self.targetStrategy = nil
	self.targetVehicle = nil
	self.targetPoint = nil
end

function CpAITaskCombineUnloader:stop(wasJobStopped)
	if self.isServer then
		self:debug("Combine unloader task stopped")
		self.vehicle:stopCpDriver(wasJobStopped)
	end
	CpAITask.stop(self)
end

function CpAITaskCombineUnloader:setTarget(targetStrategy, targetVehicle, targetPoint)
	self.targetStrategy = targetStrategy
	self.targetVehicle = targetVehicle
	self.targetPoint = targetPoint
end

function CpAITaskCombineUnloader:getNeededStrategy(unloadTargetStrategy)
	if unloadTargetStrategy:is_a(AIDriveStrategySiloLoader) then 
		return AIDriveStrategyUnloadCombine
	end
	return AIDriveStrategyUnloadCombine
end