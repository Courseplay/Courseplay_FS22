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

---@class CpAITaskFieldWork : CpAITask
CpAITaskFieldWork = CpObject(CpAITask)

function CpAITaskFieldWork:setStartPosition(startPosition)
	self.startPosition = startPosition
end

function CpAITaskFieldWork:reset()
	self.startPosition = nil
	CpAITask.reset(self)
end

function CpAITaskFieldWork:start()
	if self.isServer then
		self:debug("Fieldwork task started")
		self.vehicle:startCpFieldWorker(self, self.job:getCpJobParameters(), self.startPosition)
	end
	CpAITask.start(self)
end

function CpAITaskFieldWork:stop(wasJobStopped)
	if self.isServer then
		self:debug("Fieldwork task stopped")
        self.vehicle:stopCpFieldWorker(wasJobStopped)
	end
	CpAITask.stop(self)
end