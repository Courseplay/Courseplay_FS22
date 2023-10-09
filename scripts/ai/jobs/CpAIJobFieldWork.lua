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

--- AI job derived of CpAIJob.
---@class CpAIJobFieldWork : CpAIJob
CpAIJobFieldWork = {
    name = "FIELDWORK_CP",
    jobName = "CP_job_fieldWork",
    GenerateButton = "FIELDWORK_BUTTON",
    fieldPositionParameterText = "CP_jobParameters_fieldPosition_title"
}
local AIJobFieldWorkCp_mt = Class(CpAIJobFieldWork, CpAIJob)

function CpAIJobFieldWork.new(isServer, customMt)
    local self = CpAIJob.new(isServer, customMt or AIJobFieldWorkCp_mt)

    self.hasValidPosition = false
    self.foundVines = nil
    self.selectedFieldPlot = FieldPlot(g_currentMission.inGameMenu.ingameMap)
    self.selectedFieldPlot:setVisible(false)
    return self
end

function CpAIJobFieldWork:setupTasks(isServer)
    -- this will add a standard driveTo task to drive to the target position selected by the user
    CpAIJobFieldWork:superClass().setupTasks(self, isServer)
    -- then we add our own driveTo task to drive from the target position to the waypoint where the
    -- fieldwork starts (first waypoint or the one we worked on last)
    self.attachHeaderTask = CpAITaskAttachHeader(isServer, self)
    self:addTask(self.attachHeaderTask)
    self.driveToFieldWorkStartTask = CpAITaskDriveTo(isServer, self)
    self:addTask(self.driveToFieldWorkStartTask)
    self.fieldWorkTask = CpAITaskFieldWork(isServer, self)
    self:addTask(self.fieldWorkTask)
end

function CpAIJobFieldWork:setupJobParameters()
    CpAIJob.setupJobParameters(self)
    self:setupCpJobParameters(CpJobParameters(self))
end

---@param vehicle Vehicle
---@param mission Mission
---@param farmId number
---@param isDirectStart boolean disables the drive to by giants
---@param isStartPositionInvalid boolean resets the drive to target position by giants and the field position to the vehicle position.
function CpAIJobFieldWork:applyCurrentState(vehicle, mission, farmId, isDirectStart, isStartPositionInvalid)
    CpAIJobFieldWork:superClass().applyCurrentState(self, vehicle, mission, farmId, isDirectStart)

    local _
    local x, z = self.cpJobParameters.fieldPosition:getPosition()

    if x == nil or z == nil then
        x, _, z = getWorldTranslation(vehicle.rootNode)
    end

    self.cpJobParameters.fieldPosition:setPosition(x, z)

    if isStartPositionInvalid then
        local x, _, z = getWorldTranslation(vehicle.rootNode) 
        local dirX, _, dirZ = localDirectionToWorld(vehicle.rootNode, 0, 0, 1)
        local angle = MathUtil.getYRotationFromDirection(dirX, dirZ)
        
        self.cpJobParameters.startPosition:setPosition(x, z)
        self.cpJobParameters.startPosition:setAngle(angle)

        self.cpJobParameters.fieldPosition:setPosition(x, z)
    end
end

--- Checks the field position setting.
function CpAIJobFieldWork:validateFieldSetup(isValid, errorMessage)

    if not isValid then
        return isValid, errorMessage
    end

    local vehicle = self.vehicleParameter:getVehicle()

    -- everything else is valid, now find the field
    local tx, tz = self.cpJobParameters.fieldPosition:getPosition()
    if tx == nil or tz == nil then 
        return false, g_i18n:getText("CP_error_not_on_field")
    end
    self.hasValidPosition = false
    self.foundVines = nil
    local isCustomField
    self.fieldPolygon, isCustomField = CpFieldUtil.getFieldPolygonAtWorldPosition(tx, tz)

    if self.fieldPolygon then
        self.hasValidPosition = true
        self.foundVines = g_vineScanner:findVineNodesInField(self.fieldPolygon, tx, tz, self.customField ~= nil)
        if self.foundVines then
            CpUtil.debugVehicle(CpDebug.DBG_FIELDWORK, vehicle, "Found vine nodes, generating a vine field border.")
            self.fieldPolygon = g_vineScanner:getCourseGeneratorVertices(0, tx, tz)
        end

        self.selectedFieldPlot:setWaypoints(self.fieldPolygon)
        self.selectedFieldPlot:setVisible(true)
        self.selectedFieldPlot:setBrightColor(true)
        if isCustomField then
            CpUtil.infoVehicle(vehicle, 'disabling island bypass on custom field')
            vehicle:getCourseGeneratorSettings().islandBypassMode:setValue(Island.BYPASS_MODE_NONE)
        end
    else
        self.selectedFieldPlot:setVisible(false)
        return false, g_i18n:getText("CP_error_not_on_field")
    end

    return true, ''
end

function CpAIJobFieldWork:setValues()
    CpAIJobFieldWork:superClass().setValues(self)
    local vehicle = self.vehicleParameter:getVehicle()
    self.driveToFieldWorkStartTask:reset()
    self.driveToFieldWorkStartTask:setVehicle(vehicle)
    self.attachHeaderTask:setVehicle(vehicle)
    self.fieldWorkTask:setVehicle(vehicle)
    self:validateFieldSetup()
end

--- Called when parameters change, scan field
function CpAIJobFieldWork:validate(farmId)
    local isValid, errorMessage = CpAIJobFieldWork:superClass().validate(self, farmId)
    if not isValid then
        return isValid, errorMessage
    end
    local vehicle = self.vehicleParameter:getVehicle()

    --- Only check the valid field position in the in game menu.
    if not self.isDirectStart then
        isValid, errorMessage = self:validateFieldSetup(isValid, errorMessage)
        if not isValid then
            return isValid, errorMessage
        end
        self.cpJobParameters:validateSettings()
    end

    if not vehicle:hasCpCourse() then
        return false, g_i18n:getText("CP_error_no_course")
    end
    return true, ''
end

function CpAIJobFieldWork:drawSelectedField(map)
    if self.selectedFieldPlot then
        self.selectedFieldPlot:draw(map)
    end
end

function CpAIJobFieldWork:getCanGenerateFieldWorkCourse()
    return self.hasValidPosition
end

-- To pass an alignment course from the drive to fieldwork start to the fieldwork, so the
-- fieldwork strategy can continue the alignment course set up by the drive to fieldwork start strategy.
function CpAIJobFieldWork:setStartFieldWorkCourse(course, ix)
    self.startFieldWorkCourse = course
    self.startFieldWorkCourseIx = ix
end

function CpAIJobFieldWork:getStartFieldWorkCourse()
    return self.startFieldWorkCourse, self.startFieldWorkCourseIx
end

--- Is course generation allowed ?
function CpAIJobFieldWork:isCourseGenerationAllowed()
    local vehicle = self:getVehicle()
    --- Disables the course generation for bale loaders and wrappers.
    local baleFinderAllowed = vehicle and vehicle:getCanStartCpBaleFinder()
    return self:getCanGenerateFieldWorkCourse() and not baleFinderAllowed
end

function CpAIJobFieldWork:getCanStartJob()
    local vehicle = self:getVehicle()
    return vehicle and vehicle:hasCpCourse()
end

--- Button callback to generate a field work course.
function CpAIJobFieldWork:onClickGenerateFieldWorkCourse()
    local vehicle = self.vehicleParameter:getVehicle()
    local settings = vehicle:getCourseGeneratorSettings()
    local tx, tz = self.cpJobParameters.fieldPosition:getPosition()
    local ok, course
    if self.foundVines then
        local vineSettings = vehicle:getCpVineSettings()
        local vertices, width, startingPoint, rowAngleDeg = g_vineScanner:getCourseGeneratorVertices(
                vineSettings.vineCenterOffset:getValue(),
                tx, tz
        )
        ok, course = CourseGeneratorInterface.generateVineCourse(vertices,
                startingPoint,
                width,
                AIUtil.getTurningRadius(vehicle),
                rowAngleDeg,
                vineSettings.vineRowsToSkip:getValue(),
                vineSettings.vineMultiTools:getValue()
        )
    else

        ok, course = CourseGeneratorInterface.generate(self.fieldPolygon,
                { x = tx, z = tz },
                settings.isClockwise:getValue(),
                settings.workWidth:getValue(),
                AIUtil.getTurningRadius(vehicle),
                settings.numberOfHeadlands:getValue(),
                settings.startOnHeadland:getValue(),
                settings.headlandCornerType:getValue(),
                settings.headlandOverlapPercent:getValue(),
                settings.centerMode:getValue(),
                settings.rowDirection:getValue(),
                settings.manualRowAngleDeg:getValue(),
                settings.rowsToSkip:getValue(),
                false,
                settings.rowsPerLand:getValue(),
                settings.islandBypassMode:getValue(),
                settings.fieldMargin:getValue(),
                settings.multiTools:getValue(),
                self:isPipeOnLeftSide(vehicle)
        )
    end
    if not ok then
        g_gui:showInfoDialog({
            dialogType = DialogElement.TYPE_ERROR,
            text = g_i18n:getText('CP_error_could_not_generate_course')
        })
        return false
    end

    vehicle:setFieldWorkCourse(course)
end

function CpAIJobFieldWork:isPipeOnLeftSide(vehicle)
    local pipeObject = AIUtil.getImplementOrVehicleWithSpecialization(vehicle, Pipe)
    if pipeObject and SpecializationUtil.hasSpecialization(Combine, pipeObject.specializations) then
        --- The controller measures the pipe attributes on creation.
        local controller = PipeController(vehicle, pipeObject)
        local isPipeOnLeftSide = controller:isPipeOnTheLeftSide()
        controller:delete()
        return isPipeOnLeftSide
    else
        return true
    end
end

function CpAIJobFieldWork:getIsAvailableForVehicle(vehicle)
    return vehicle.getCanStartCpFieldWork and vehicle:getCanStartCpFieldWork()
end

function CpAIJobFieldWork:resetStartPositionAngle(vehicle)
    CpAIJobFieldWork:superClass().resetStartPositionAngle(self, vehicle)
    local x, _, z = getWorldTranslation(vehicle.rootNode)
    self.cpJobParameters.fieldPosition:setPosition(x, z)
end

--- Ugly hack to fix a mp problem from giants, where the helper is not always reset correctly on the client side.
function CpAIJobFieldWork:stop(aiMessage)
    CpAIJobFieldWork:superClass().stop(self, aiMessage)

    local vehicle = self.vehicleParameter:getVehicle()
    if vehicle and vehicle.spec_aiFieldWorker.isActive then
        vehicle.spec_aiFieldWorker.isActive = false
    end
end

function CpAIJobFieldWork:hasFoundVines()
    return self.foundVines
end

function CpAIJobFieldWork:setStartPosition(startPosition)
    if self.fieldWorkTask then
        self.fieldWorkTask:setStartPosition(startPosition)
    end
end

function CpAIJobFieldWork:getNextTaskIndex(isSkipTask)
    local nextTaskIndex = CpAIJobFieldWork:superClass().getNextTaskIndex(self, isSkipTask)
    if self.currentTaskIndex == self.driveToTask.taskIndex then
        --- Checks if a cutter is attached on the back, 
        --- so the attach header strategy needs to be used.
        local vehicle = self.vehicleParameter:getVehicle()
        if vehicle and (AIUtil.hasCutterOnTrailerAttached(vehicle) 
            or AIUtil.hasCutterAsTrailerAttached(vehicle)) then 
            CpUtil.debugVehicle(CpDebug.DBG_FIELDWORK, vehicle, "Cutter on trailer attached.")
            return nextTaskIndex
        else 
            --- Header Attach strategy is not needed.
            return nextTaskIndex + 1
        end
	end

	return nextTaskIndex
end

function CpAIJobFieldWork:getStartTaskIndex()
    if self.isDirectStart or self:isTargetReached() then 
        local vehicle = self.vehicleParameter:getVehicle()
        if AIUtil.hasCutterOnTrailerAttached(vehicle) or 
            AIUtil.hasCutterAsTrailerAttached(vehicle) then 
            --- Makes sure the direct start from the hud, starts with the attach header strategy.
            return 2
        end
        --- Skips the attach header strategy.
        return 3
    end
    return 1
end

function CpAIJobFieldWork:onFinishAttachCutter()
    --- Finished attaching a given header.
    self.attachHeaderTask:skip()
end