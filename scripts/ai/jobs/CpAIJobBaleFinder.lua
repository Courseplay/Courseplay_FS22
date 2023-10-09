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

--- Bale finder job.
---@class CpAIJobBaleFinder : CpAIJobFieldWork
---@field selectedFieldPlot FieldPlot
CpAIJobBaleFinder = {
	name = "BALE_FINDER_CP",
	jobName = "CP_job_baleCollect",
	minStartDistanceToField = 20,
}
local AIJobBaleFinderCp_mt = Class(CpAIJobBaleFinder, CpAIJob)


function CpAIJobBaleFinder.new(isServer, customMt)
	local self = CpAIJob.new(isServer, customMt or AIJobBaleFinderCp_mt)
	self.hasValidPosition = false
	self.selectedFieldPlot = FieldPlot(g_currentMission.inGameMenu.ingameMap)
    self.selectedFieldPlot:setVisible(false)
	self.selectedFieldPlot:setBrightColor(true)

	return self
end

function CpAIJobBaleFinder:setupTasks(isServer)
	CpAIJob.setupTasks(self, isServer)
	self.baleFinderTask = CpAITaskBaleFinder(isServer, self)
	self:addTask(self.baleFinderTask)
end

function CpAIJobBaleFinder:setupJobParameters()
	CpAIJob.setupJobParameters(self)
    self:setupCpJobParameters(CpBaleFinderJobParameters(self))
end

function CpAIJobBaleFinder:getIsAvailableForVehicle(vehicle)
	return vehicle.getCanStartCpBaleFinder and vehicle:getCanStartCpBaleFinder()
end

function CpAIJobBaleFinder:getCanStartJob()
	return self.hasValidPosition
end


function CpAIJobBaleFinder:applyCurrentState(vehicle, mission, farmId, isDirectStart, isStartPositionInvalid)
	CpAIJobBaleFinder:superClass().applyCurrentState(self, vehicle, mission, farmId, isDirectStart, isStartPositionInvalid)
	self.cpJobParameters:validateSettings()

	self:copyFrom(vehicle:getCpBaleFinderJob())
	local x, z = self.cpJobParameters.fieldPosition:getPosition()
	-- no field position from the previous job, use the vehicle's current position
	if x == nil or z == nil then
		x, _, z = getWorldTranslation(vehicle.rootNode)
		self.cpJobParameters.fieldPosition:setPosition(x, z)
	end
end

function CpAIJobBaleFinder:setValues()
	CpAIJob.setValues(self)
	local vehicle = self.vehicleParameter:getVehicle()
	self.baleFinderTask:setVehicle(vehicle)
	self:validateFieldPosition()
end

--- Called when parameters change, scan field
function CpAIJobBaleFinder:validate(farmId)
	local isValid, errorMessage = CpAIJob.validate(self, farmId)
	if not isValid then
		return isValid, errorMessage
	end
	local vehicle = self.vehicleParameter:getVehicle()
	if vehicle then 
		vehicle:applyCpBaleFinderJobParameters(self)
	end
	--------------------------------------------------------------
	--- Validate field setup
	--------------------------------------------------------------
	
	isValid, errorMessage = self:validateFieldPosition(isValid, errorMessage)	

	--------------------------------------------------------------
	--- Validate start distance to field, if started with the hud
	--------------------------------------------------------------
	if isValid and self.isDirectStart then 
		--- Checks the distance for starting with the hud, as a safety check.
		--- Firstly check, if the vehicle is near the field.
		local x, _, z = getWorldTranslation(vehicle.rootNode)
		isValid = CpMathUtil.isPointInPolygon(self.fieldPolygon, x, z) or 
				  CpMathUtil.getClosestDistanceToPolygonEdge(self.fieldPolygon, x, z) < self.minStartDistanceToField
		if not isValid then
			return false, g_i18n:getText("CP_error_vehicle_too_far_away_from_field")
		end
	end


	return isValid, errorMessage
end

function CpAIJobBaleFinder:validateFieldPosition(isValid, errorMessage)
	local tx, tz = self.cpJobParameters.fieldPosition:getPosition()
	if tx == nil or tz == nil then 
		return false, g_i18n:getText("CP_error_not_on_field")
	end
	local _
	self.fieldPolygon, _ = CpFieldUtil.getFieldPolygonAtWorldPosition(tx, tz)
	self.hasValidPosition = self.fieldPolygon ~= nil
	if self.hasValidPosition then 
		self.selectedFieldPlot:setWaypoints(self.fieldPolygon)
        self.selectedFieldPlot:setVisible(true)
	else
		return false, g_i18n:getText("CP_error_not_on_field")
	end
	return isValid, errorMessage
end

function CpAIJobBaleFinder:drawSelectedField(map)
	self.selectedFieldPlot:draw(map)
end
