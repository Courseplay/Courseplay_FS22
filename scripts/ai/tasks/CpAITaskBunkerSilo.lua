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

---@class CpAITaskBunkerSilo : CpAITask
CpAITaskBunkerSilo = CpObject(CpAITask)

function CpAITaskBunkerSilo:setSilo(silo)
	self.silo = silo	
end

function CpAITaskBunkerSilo:setParkPosition(x, z, angle, dirX, dirZ)
	self.parkPosition =  {x = x, z = z, angle = angle, dirX = dirX, dirZ = dirZ}
end

function CpAITaskBunkerSilo:reset()
	self.silo = nil
	self.parkPosition = nil
	CpAITask.reset(self)
end

function CpAITaskBunkerSilo:start()
	if self.isServer then
		self:debug("Bunker silo task started")
		self.vehicle:startCpBunkerSiloWorker(self, self.silo, self.job:getCpJobParameters(), self.parkPosition)
	end
	CpAITask.start(self)
end

function CpAITaskBunkerSilo:stop(wasJobStopped)
	if self.isServer then
		self:debug("Bunker silo task task stopped")
		self.vehicle:stopCpBunkerSiloWorker(wasJobStopped)
	end
	CpAITask.stop(self)
end