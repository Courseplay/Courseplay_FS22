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

---@class CpAITaskSiloLoader : CpAITask
CpAITaskSiloLoader = CpObject(CpAITask)

function CpAITaskSiloLoader:setSiloAndHeap(silo, heap)
	self.silo = silo
	self.heap = heap	
end

function CpAITaskSiloLoader:reset()
	self.silo = nil
	self.heap = nil
	CpAITask.reset(self)
end

function CpAITaskSiloLoader:start()
	if self.isServer then
		self:debug("Silo loader task started")
		local _, unloadTrigger, unloadStation = self.job:getUnloadTriggerAt(self.job:getCpJobParameters().unloadPosition)
		self.vehicle:startCpSiloLoaderWorker(self, self.job:getCpJobParameters(), self.silo, self.heap, unloadTrigger, unloadStation)
	end
	CpAITask.start(self)
end

function CpAITaskSiloLoader:stop(wasJobStopped)
	if self.isServer then
		self:debug("Silo loader task stopped")
		self.vehicle:stopCpSiloLoaderWorker(wasJobStopped)
	end
	CpAITask.stop(self)
end