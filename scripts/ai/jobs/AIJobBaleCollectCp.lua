--[[
This file is part of Courseplay (https://github.com/Courseplay/courseplay)
Copyright (C) 2022 Peter Vaiko

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

--- AI job to drive to a field (if not there already), and then find all bales to collect or wrap them.

------@class AIJobBaleCollectCp : AIJobFieldWorkCp
AIJobBaleCollectCp = {}
local AIJobBaleCollectCp_mt = Class(AIJobBaleCollectCp, AIJobFieldWorkCp)

---Localization text symbols.
AIJobBaleCollectCp.translations = {
    JobName = "CP_job_baleCollect",
}

function AIJobBaleCollectCp.new(isServer, customMt)
	local self = AIJobFieldWork.new(isServer, customMt or AIJobBaleCollectCp_mt)
	self.lastPositionX, self.lastPositionZ = math.huge, math.huge
	self.hasValidPosition = false

	--- Small translation fix, needs to be removed once giants fixes it.
	local ai = 	g_currentMission.aiJobTypeManager
	ai:getJobTypeByIndex(ai:getJobTypeIndexByName("BALECOLLECT_CP")).title = g_i18n:getText(AIJobBaleCollectCp.translations.JobName)

	return self
end

--- Called when parameters change, scan field
function AIJobBaleCollectCp:validate(farmId)
	local isValid, errorMessage = AIJobFieldWork:superClass().validate(self, farmId)
	if not isValid then
		return isValid, errorMessage
	end

	-- everything else is valid, now find the field
	local tx, tz = self.positionAngleParameter:getPosition()
	if tx == self.lastPositionX and tz == self.lastPositionZ then
		return isValid, errorMessage
	else
		self.lastPositionX, self.lastPositionZ = tx, tz
		self.hasValidPosition = true
	end

	self.fieldNum = CpFieldUtil.getFieldIdAtWorldPosition(tx, tz)

	CpUtil.info('Bale collect job: target is field %d on %s', fieldNum, g_currentMission.missionInfo.mapTitle)

	if self.fieldId == 0 then
		self.hasValidPosition = false
		return false, g_i18n:getText("CP_error_not_on_field")
	end
	return true, ''
end

--- Registers additional jobs.
function AIJobBaleCollectCp.registerJob(self)
	self:registerJobType("BALECOLLECT_CP", AIJobBaleCollectCp.translations.JobName, AIJobBaleCollectCp)
end

--- for reload, messing with the internals of the job type manager so it uses the reloaded job
if g_currentMission then
	local myJobTypeIndex = g_currentMission.aiJobTypeManager:getJobTypeIndexByName('BALECOLLECT_CP')
	if myJobTypeIndex then
		local myJobType = g_currentMission.aiJobTypeManager:getJobTypeByIndex(myJobTypeIndex)
		myJobType.classObject = AIJobBaleCollectCp
	end
end

AIJobTypeManager.loadMapData = Utils.appendedFunction(AIJobTypeManager.loadMapData,AIJobBaleCollectCp.registerJob)

function AIJobBaleCollectCp:getIsAvailableForVehicle(vehicle)
	if AIUtil.hasImplementWithSpecialization(vehicle, BaleWrapper) and
			not AIUtil.hasImplementWithSpecialization(self.Baler) then
		return true
	end
	if AIUtil.hasImplementWithSpecialization(vehicle, BaleLoader) then
		return true
	end
	return false
end