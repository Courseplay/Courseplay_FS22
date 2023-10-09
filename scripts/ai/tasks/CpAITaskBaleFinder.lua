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

---@class CpAITaskBaleFinder : CpAITask
CpAITaskBaleFinder = CpObject(CpAITask)

function CpAITaskBaleFinder:start()
	if self.isServer then
		self:debug("Bale finder task started")
		local tx, tz = self.job:getCpJobParameters().fieldPosition:getPosition()
		local fieldPolygon = CpFieldUtil.getFieldPolygonAtWorldPosition(tx, tz)
		self.vehicle:startCpBaleFinder(self, fieldPolygon, self.job:getCpJobParameters())
	end
	CpAITask.start(self)
end

function CpAITaskBaleFinder:stop(wasJobStopped)
	if self.isServer then
		self:debug("Bale finder task stopped")
		self.vehicle:stopCpBaleFinder(wasJobStopped)
	end
	CpAITask.stop(self)
end
