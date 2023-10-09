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

--- AI job for the silo driver.
---@class CpAIJobBunkerSilo : CpAIJob
CpAIJobBunkerSilo = {
	name = "BUNKER_SILO_CP",
	jobName = "CP_job_bunkerSilo",
	fieldPositionParameterText = "CP_jobParameters_bunkerSiloPosition_title",
	targetPositionParameterText = "CP_jobParameters_parkPosition_title",
}
local CpAIJobBunkerSilo_mt = Class(CpAIJobBunkerSilo, CpAIJob)

function CpAIJobBunkerSilo.new(isServer, customMt)
	local self = CpAIJob.new(isServer, customMt or CpAIJobBunkerSilo_mt)
	
	self.hasValidPosition = nil 
	self.bunkerSilo = nil

	return self
end

function CpAIJobBunkerSilo:setupTasks(isServer)
	-- this will add a standard driveTo task to drive to the target position selected by the user
	CpAIJob.setupTasks(self, isServer)
	
	self.bunkerSiloTask = CpAITaskBunkerSilo(isServer, self)
	self:addTask(self.bunkerSiloTask)
end

function CpAIJobBunkerSilo:setupJobParameters()
	CpAIJob.setupJobParameters(self)
    self:setupCpJobParameters(CpBunkerSiloJobParameters(self))
end

function CpAIJobBunkerSilo:getIsAvailableForVehicle(vehicle)
	return vehicle.getCanStartCpBunkerSiloWorker and vehicle:getCanStartCpBunkerSiloWorker()
end

function CpAIJobBunkerSilo:getCanStartJob()
	return self.hasValidPosition
end

function CpAIJobBunkerSilo:applyCurrentState(vehicle, mission, farmId, isDirectStart)
	CpAIJob.applyCurrentState(self, vehicle, mission, farmId, isDirectStart)
	
	self:copyFrom(vehicle:getCpBunkerSiloWorkerJob())

	local x, z = self.cpJobParameters.siloPosition:getPosition()

	-- no silo position from the previous job, use the vehicle's current position
	if x == nil or z == nil then
		x, _, z = getWorldTranslation(vehicle.rootNode)
		self.cpJobParameters.siloPosition:setPosition(x, z)
	end

end

--- Checks the bunker silo position setting.
function CpAIJobBunkerSilo:validateBunkerSiloSetup(isValid, errorMessage)
	
	if not isValid then 
		return isValid, errorMessage
	end
	self.hasValidPosition = false 
	self.bunkerSilo = nil
	-- everything else is valid, now find the bunker silo.
	local tx, tz = self.cpJobParameters.siloPosition:getPosition()
	self.hasValidPosition, self.bunkerSilo =  g_bunkerSiloManager:getBunkerSiloAtPosition(tx, tz)
	--[[	
	if not self.hasValidPosition and self.isDirectStart then 
		local vehicle = self:getVehicle()
		if vehicle then
			local x, _, z
			x, _, z = getWorldTranslation(Markers.getFrontMarkerNode(vehicle))
			self.hasValidPosition, self.bunkerSilo =  g_bunkerSiloManager:getBunkerSiloAtPosition(x, z)
			if not self.hasValidPosition then 
				x, _, z = getWorldTranslation(Markers.getBackMarkerNode(vehicle))
				self.hasValidPosition, self.bunkerSilo =  g_bunkerSiloManager:getBunkerSiloAtPosition(x, z)
			end
		end
	end
	]]--
	self.bunkerSiloTask:setSilo(self.bunkerSilo)
	
	local x, z = self.cpJobParameters.startPosition:getPosition()
	local angle = self.cpJobParameters.startPosition:getAngle()
	local dirX, dirZ = self.cpJobParameters.startPosition:getDirection()
	self.bunkerSiloTask:setParkPosition(x, z, angle, dirX, dirZ)

	if not self.hasValidPosition or self.bunkerSilo == nil then 
		return false, g_i18n:getText("CP_error_no_bunkerSilo_found")
	end
	return true, ''
end

function CpAIJobBunkerSilo:setValues()
	CpAIJob.setValues(self)
	local vehicle = self.vehicleParameter:getVehicle()
	self.bunkerSiloTask:setVehicle(vehicle)
end

--- Called when parameters change, scan field
function CpAIJobBunkerSilo:validate(farmId)
	local isValid, errorMessage = CpAIJob.validate(self, farmId)
	if not isValid then
		return isValid, errorMessage
	end
	local vehicle = self.vehicleParameter:getVehicle()
	if vehicle then 
		vehicle:applyCpBunkerSiloWorkerJobParameters(self)
	end
	isValid, errorMessage = self:validateBunkerSiloSetup(isValid, errorMessage)
	if not isValid then
		return isValid, errorMessage
	end
	return true, ''
end

function CpAIJobBunkerSilo:drawSilos(map)
	g_bunkerSiloManager:drawSilos(map, self.bunkerSilo)
end

function CpAIJobBunkerSilo:readStream(streamId, connection)
	CpAIJobBunkerSilo:superClass().readStream(self, streamId, connection)
	
	local x, z = self.cpJobParameters.siloPosition:getPosition()
	self.hasValidPosition, self.bunkerSilo =  g_bunkerSiloManager:getBunkerSiloAtPosition(x, z)
	self.bunkerSiloTask:setSilo(self.bunkerSilo)

	local x, z = self.cpJobParameters.startPosition:getPosition()
	local angle = self.cpJobParameters.startPosition:getAngle()
	local dirX, dirZ = self.cpJobParameters.startPosition:getDirection()
	self.bunkerSiloTask:setParkPosition(x, z, angle, dirX, dirZ)
end
