--[[
This file is part of Courseplay (https://github.com/Courseplay/Courseplay_FS22)
Copyright (C) 2021 Peter Vaiko

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

Base class for all Courseplay drive strategies

]]

---@class AIDriveStrategyCourse : AIDriveStrategy
AIDriveStrategyCourse = {}
local AIDriveStrategyCourse_mt = Class(AIDriveStrategyCourse, AIDriveStrategy)

AIDriveStrategyCourse.myStates = {
    INITIAL = {},
    WAITING_FOR_PATHFINDER = {},
    DRIVING_TO_WORK_START_WAYPOINT = {},
}

--- Implement controller events.
AIDriveStrategyCourse.onRaisingEvent = "onRaising"
AIDriveStrategyCourse.onLoweringEvent = "onLowering"
AIDriveStrategyCourse.onFinishedEvent = "onFinished"
AIDriveStrategyCourse.onStartEvent = "onStart"
AIDriveStrategyCourse.updateEvent = "update"
AIDriveStrategyCourse.deleteEvent = "delete"

function AIDriveStrategyCourse.new(customMt)
    if customMt == nil then
        customMt = AIDriveStrategyCourse_mt
    end
    local self = AIDriveStrategy.new(customMt)
    self.debugChannel = CpDebug.DBG_AI_DRIVER
    self:initStates(AIDriveStrategyCourse.myStates)
    ---@type ImplementController[]
    self.controllers = {}
    self.registeredInfoTexts = {}
    --- To temporary hold a vehicle (will force speed to 0)
    self.held = CpTemporaryObject()
    return self
end

--- Aggregation of states from this and all descendant classes
function AIDriveStrategyCourse:initStates(states)
    if self.states == nil then
        self.states = {}
    end
    for key, state in pairs(states) do
        self.states[key] = {name = tostring(key), properties = state}
    end
end

function AIDriveStrategyCourse:getStateAsString()
    return self.state.name
end

function AIDriveStrategyCourse:getName()
    return CpUtil.getName(self.vehicle)
end

function AIDriveStrategyCourse:debug(...)
    CpUtil.debugVehicle(self.debugChannel, self.vehicle, self:getStateAsString() .. ': ' .. string.format(...))
end

function AIDriveStrategyCourse:debugSparse(...)
    local nowSecs = math.floor(g_time / 1000)
    -- report every 5 seconds
    -- TODO: make this a parameter in seconds?
    if not self.lastLogSecs or (nowSecs > self.lastLogSecs and nowSecs % 5 == 0) then
        self:debug(...)
        self.lastLogSecs = nowSecs
    end
end

function AIDriveStrategyCourse:info(...)
    CpUtil.infoVehicle(self.vehicle, self:getStateAsString() .. ': ' .. string.format(...))
end

function AIDriveStrategyCourse:error(...)
    CpUtil.infoVehicle(self.vehicle, self:getStateAsString() .. ': ' .. string.format(...))
end

function AIDriveStrategyCourse:setInfoText(text)
    self.vehicle:setCpInfoTextActive(text)
end

function AIDriveStrategyCourse:setAIVehicle(vehicle, jobParameters)
    AIDriveStrategyCourse:superClass().setAIVehicle(self, vehicle)
    self:initializeImplementControllers(vehicle)
    ---@type FillLevelManager
    self.fillLevelManager = FillLevelManager(vehicle)
    self.ppc = PurePursuitController(vehicle)
    self.ppc:registerListeners(self, 'onWaypointPassed', 'onWaypointChange')
    -- TODO_22 properly implement this in courseplaySpec
    self.storage = vehicle.spec_courseplaySpec

    self.settings = vehicle:getCpSettings()
    self.courseGeneratorSettings = vehicle:getCourseGeneratorSettings()

    -- for now, pathfinding generated courses can't be driven by towed tools
    self.allowReversePathfinding = AIUtil.getFirstReversingImplementWithWheels(self.vehicle) == nil
    self.turningRadius = AIUtil.getTurningRadius(vehicle)

    self:enableCollisionDetection()
    self:setAllStaticParameters()

    -- TODO: this may or may not be the course we need for the strategy
    local course = self:getGeneratedCourse(jobParameters)
    if course then
        self:debug('Vehicle has a fieldwork course, figure out where to start')
        if course:wasEditedByCourseEditor() then 
            self:info('The fieldwork course was edited by the course editor.')
        end
        local startIx = self:getStartingPointWaypointIx(course, jobParameters.startAt:getValue())
        self:start(course, startIx, jobParameters)
    else
        -- some strategies do not need a recorded or generated course to work, they
        -- will create the courses on the fly.
        self:debug('Vehicle has no course, start work without it.')
        self:startWithoutCourse()
    end
    self:raiseControllerEvent(self.onStartEvent)
end

function AIDriveStrategyCourse:delete()
    self:raiseControllerEvent(self.deleteEvent)
    AIDriveStrategyCourse:superClass().delete(self)
end

function AIDriveStrategyCourse:getGeneratedCourse(jobParameters)
    local course = self.vehicle:getFieldWorkCourse()
    local numMultiTools = course:getMultiTools()
    local position = numMultiTools > 1 and jobParameters.laneOffset:getValue() or 0
    if numMultiTools < 2 then
        self:debug('Single vehicle fieldwork course')
        self.vehicle:setOffsetFieldWorkCourse(nil)
        return course
    elseif position == 0 then
        self:debug('Multitool course, center vehicle, using original course')
        self.vehicle:setOffsetFieldWorkCourse(nil)
        return course
    else
        self:debug('Multitool course, non-center vehicle, generating offset course for lane number %d', position)
        --- only one vehicle can have position zero (center)
        local offsetCourse, previousPosition = self.vehicle:getOffsetFieldWorkCourse()
        if offsetCourse == nil or position ~= previousPosition then
            --- Work width of a single vehicle.
            local width = course:getWorkWidth() / numMultiTools
            offsetCourse = course:calculateOffsetCourse(numMultiTools, position, width,
                    self.settings.symmetricLaneChange:getValue())
            self.vehicle:setOffsetFieldWorkCourse(offsetCourse, position)
        end
        return offsetCourse
    end
end

function AIDriveStrategyCourse:getStartingPointWaypointIx(course, startAt)
    if startAt == CpJobParameters.START_AT_NEAREST_POINT then 
        local _, _, ixClosestRightDirection, _ = course:getNearestWaypoints(self.vehicle:getAIDirectionNode())
        self:debug('Starting course at the closest waypoint in the right direction %d', ixClosestRightDirection)
        return ixClosestRightDirection
    elseif startAt == CpJobParameters.START_AT_LAST_POINT then
        local lastWpIx = self.vehicle:getCpLastRememberedWaypointIx()
        if lastWpIx then
            self:debug('Starting course at the last waypoint %d', lastWpIx)
            return lastWpIx
        end
    end
    self:debug('Starting course at the first waypoint')
    return 1
end

function AIDriveStrategyCourse:start(course, startIx, jobParameters)
    self:startCourse(course, startIx)
    self.state = self.states.INITIAL
end

function AIDriveStrategyCourse:startWithoutCourse()
end

function AIDriveStrategyCourse:updateCpStatus(status)
    --- override
end

-----------------------------------------------------------------------------------------------------------------------
--- Implement handling
-----------------------------------------------------------------------------------------------------------------------
--- Adds implement controllers for every implement, that has the given specialization.
---@param vehicle table
---@param class ImplementController
---@param spec table
---@param states table
---@param specReference string
---@return table last implement found.
---@return table last implement controller
function AIDriveStrategyCourse:addImplementController(vehicle, class, spec, states, specReference)
    --- If multiple implements have this spec, then add a controller for each implement.
    local lastImplement, lastController
    for _,childVehicle in pairs(AIUtil.getAllChildVehiclesWithSpecialization(vehicle, spec, specReference)) do
        local controller = class(vehicle, childVehicle)
        controller:setDisabledStates(states)
        controller:setDriveStrategy(self)
        table.insert(self.controllers, controller)
        lastImplement, lastController = childVehicle, controller
    end
    return lastImplement, lastController
end

--- Checks if any controller disables fuel save, for example a round baler that is dropping a bale.
function AIDriveStrategyCourse:isFuelSaveAllowed()  
    --[[ TODO: implement this, when fuel save is implemented for every vehicle combo and not only harvesters.
         for _, controller in pairs(self.controllers) do
            ---@type ImplementController
            if controller:isEnabled() then
                if not controller:isFuelSaveAllowed() then 
                    return false
                end
            end
        end
    ]]  
    return false
end

function AIDriveStrategyCourse:initializeImplementControllers(vehicle)
end

--- Normal update function called every frame.
--- For releasing the helper in the controller, use this one.
function AIDriveStrategyCourse:updateImplementControllers(dt)
    self:raiseControllerEvent(self.updateEvent, dt)
end

--- Called in the low frequency function for the helper.
function AIDriveStrategyCourse:updateLowFrequencyImplementControllers()
    for _, controller in pairs(self.controllers) do
        ---@type ImplementController
        if controller:isEnabled() then
            -- we don't know yet if we even need anything from the controller other than the speed.
            local _, _, _, maxSpeed = controller:getDriveData()
            if maxSpeed then
                self:setMaxSpeed(maxSpeed)
            end
        end
    end
end

--- Raises a event for the controllers.
function AIDriveStrategyCourse:raiseControllerEvent(eventName, ...)
    for _, controller in pairs(self.controllers) do
        ---@type ImplementController
        if controller:isEnabled() then
            if controller[eventName] then 
                controller[eventName](controller, ...)
            end
        end
    end
end

function AIDriveStrategyCourse:raiseImplements()
    --- Raises all implements, that are available for the giants field worker.
    for _, implement in pairs(self.vehicle:getAttachedAIImplements()) do
        implement.object:aiImplementEndLine()
    end
    self.vehicle:raiseStateChange(Vehicle.STATE_CHANGE_AI_END_LINE)
    --- Raises implements, that are not covered by giants.
    self:raiseControllerEvent(self.onRaisingEvent)
end

-----------------------------------------------------------------------------------------------------------------------
--- Static parameters (won't change while driving)
-----------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyCourse:setAllStaticParameters()
    self.workWidth = self.vehicle:getCourseGeneratorSettings().workWidth:getValue()
    self.reverser = AIReverseDriver(self.vehicle, self.ppc)
    self.proximityController = ProximityController(self.vehicle, self:getProximitySensorWidth())
end

--- Find the foremost and rearmost AI marker
function AIDriveStrategyCourse:setFrontAndBackMarkers()
    local markers= {}
    local addMarkers = function(object, referenceNode)
        self:debug('Finding AI markers of %s', CpUtil.getName(object))
        local aiLeftMarker, aiRightMarker, aiBackMarker = WorkWidthUtil.getAIMarkers(object)
        if aiLeftMarker and aiBackMarker and aiRightMarker then
            local leftMarkerDistance = ImplementUtil.getDistanceToImplementNode(referenceNode, object, aiLeftMarker)
            local rightMarkerDistance = ImplementUtil.getDistanceToImplementNode(referenceNode, object, aiRightMarker)
            local backMarkerDistance = ImplementUtil.getDistanceToImplementNode(referenceNode, object, aiBackMarker)
            table.insert(markers, leftMarkerDistance)
            table.insert(markers, rightMarkerDistance)
            table.insert(markers, backMarkerDistance)
            self:debug('%s: left = %.1f, right = %.1f, back = %.1f', CpUtil.getName(object), leftMarkerDistance, rightMarkerDistance, backMarkerDistance)
        end
    end

    local referenceNode = self.vehicle:getAIDirectionNode()
    -- now go ahead and try to find the real markers
    -- work areas of the vehicle itself
    addMarkers(self.vehicle, referenceNode)
    -- and then the work areas of all the implements
    for _, implement in pairs( AIUtil.getAllAIImplements(self.vehicle)) do
        addMarkers(implement.object, referenceNode)
    end

    if #markers == 0 then
        -- make sure we always have a default front/back marker, placed on the direction node if nothing else found
        table.insert(markers, 0)
        table.insert(markers, 3)
    end
    -- now that we have all, find the foremost and the last
    self.frontMarkerDistance, self.backMarkerDistance = 0, 0
    local frontMarkerDistance, backMarkerDistance = -math.huge, math.huge
    for _, d in pairs(markers) do
        if d > frontMarkerDistance then
            frontMarkerDistance = d
        end
        if d < backMarkerDistance then
            backMarkerDistance = d
        end
    end
    self.frontMarkerDistance = frontMarkerDistance
    self.backMarkerDistance = backMarkerDistance
    self:debug('front marker: %.1f, back marker: %.1f', frontMarkerDistance, backMarkerDistance)
end

function AIDriveStrategyCourse:getFrontAndBackMarkers()
    if not self.frontMarkerDistance then
        self:setFrontAndBackMarkers()
    end
    return self.frontMarkerDistance, self.backMarkerDistance
end

function AIDriveStrategyCourse:getWorkWidth()
    return self.workWidth
end

function AIDriveStrategyCourse:update()
    self.ppc:update()
    self:updatePathfinding()
    self:updateInfoTexts()
end

function AIDriveStrategyCourse:getDriveData(dt, vX, vY, vZ)
    local moveForwards = not self.ppc:isReversing()
    local gx, _, gz = self.ppc:getGoalPointPosition()
    return gx, gz, moveForwards, self.maxSpeed, 100
end

function AIDriveStrategyCourse:getReverseDriveData()
    local gx, gz, _, maxSpeed = self.reverser:getDriveData()
    if not gx then
        -- simple reverse (not towing anything), just use PPC
        gx, _, gz = self.ppc:getGoalPointPosition()
        maxSpeed = self.settings.reverseSpeed:getValue()
    end
    return gx, gz, maxSpeed
end


-----------------------------------------------------------------------------------------------------------------------
--- Proximity
-----------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyCourse:getProximitySensorWidth()
    -- a bit less as size.width always has plenty of buffer
    return self.vehicle.size.width - 0.5
end

function AIDriveStrategyCourse:checkProximitySensors(moveForwards)
    local _, _, _, maxSpeed = self.proximityController:getDriveData(self:getMaxSpeed(), moveForwards)
    self:setMaxSpeed(maxSpeed)
end

--- Is vehicle close to the front or rear proximity sensors?
---@param vehicle table
---@return boolean, number true if vehicle is in proximity, distance of vehicle
function AIDriveStrategyCourse:isVehicleInProximity(vehicle)
    return self.proximityController:isVehicleInRange(vehicle)
end

-----------------------------------------------------------------------------------------------------------------------
--- Speed control
-----------------------------------------------------------------------------------------------------------------------
--- Set the maximum speed. The idea is that self.maxSpeed is reset at the beginning of every loop and
-- every function calls setMaxSpeed() and the speed will be set to the minimum
-- speed set in this loop.
function AIDriveStrategyCourse:setMaxSpeed(speed)
    if self.maxSpeedUpdatedLoopIndex == nil or self.maxSpeedUpdatedLoopIndex ~= g_updateLoopIndex then
        -- new loop, reset max speed. Always 0 if frozen
        self.maxSpeed = (self.frozen or self:isBeingHeld()) and 0 or self.vehicle:getSpeedLimit(true)
        self.maxSpeedUpdatedLoopIndex = g_updateLoopIndex
    end
    self.maxSpeed = math.min(self.maxSpeed, speed)
end

function AIDriveStrategyCourse:getMaxSpeed()
    return self.maxSpeed or self.vehicle:getSpeedLimit(true)
end

--- Hold the vehicle (set speed to 0) temporary. This is meant to be used for other vehicles to coordinate movements,
--- for instance tell a vehicle it should not move as the other vehicle is driving around it.
---@param milliseconds number milliseconds to hold
function AIDriveStrategyCourse:hold(milliseconds)
    if not self.held:get() then
        self:debug('Hold requested for %.1f seconds', milliseconds / 1000)
    end
    self.held:set(true, milliseconds)
end

--- Release a hold anytime, even before it is released automatically after the time given at hold()
function AIDriveStrategyCourse:unhold()
    if self.held:get() then
        self:debug("Hold reset")
    end
    self.held:reset()
end

--- Are we currently being held?
function AIDriveStrategyCourse:isBeingHeld()
    return self.held:get()
end

--- Freeze (force speed to 0), but keep everything up and running otherwise, showing all debug
--- drawings, etc. This is for troubleshooting only. Unlike pausing the game, this still calls update() and
--- getDriveData() so all debug drawings remain visible during the freeze.
function AIDriveStrategyCourse:freeze()
    self.frozen = true
end

function AIDriveStrategyCourse:unfreeze()
    self.frozen = false
end

--- Slow down a bit towards the end of course or near direction changes, and later maybe where the turn radius is
--- small, unless we are reversing, as then (hopefully) we already have a slow speed set
function AIDriveStrategyCourse:limitSpeed()
    if self.maxSpeed > self.settings.turnSpeed:getValue() and
            not self.ppc:isReversing() and
            (self.ppc:getCourse():isCloseToLastWaypoint(15) or
                    self.ppc:getCourse():isCloseToNextDirectionChange(15)) then

        local maxSpeed = self.maxSpeed
        self:setMaxSpeed(self.settings.turnSpeed:getValue())
        self:debugSparse('speed %.1f limited to turn speed %.1f', maxSpeed, self.maxSpeed)
    else
        self:debugSparse('speed %.1f', self.maxSpeed)
    end
end

--- Start a course and continue with nextCourse at ix when done
---@param tempCourse Course
---@param nextCourse Course
---@param ix number
function AIDriveStrategyCourse:startCourse(course, ix)
    self:debug('Starting a course, at waypoint %d (of %d).', ix, course:getNumberOfWaypoints())
    self.course = course
    self.ppc:setCourse(self.course)
    self.ppc:initialize(ix)
end

--- @param msgReference string as defined in globalInfoText.msgReference
function AIDriveStrategyCourse:clearInfoText(msgReference)
    if msgReference then
        self.vehicle:resetCpActiveInfoText(msgReference)
    end
end

function AIDriveStrategyCourse:getFillLevelInfoText()
    return InfoTextManager.NEEDS_UNLOADING
end

-----------------------------------------------------------------------------------------------------------------------
--- Event listeners
-----------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyCourse:onWaypointChange(ix, course)
end

function AIDriveStrategyCourse:onWaypointPassed(ix, course)
end

------------------------------------------------------------------------------------------------------------------------
--- Pathfinding
---------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyCourse:getAllowReversePathfinding()
    return self.allowReversePathfinding and self.settings.allowReversePathfinding:getValue()
end

function AIDriveStrategyCourse:setPathfindingDoneCallback(object, func)
    self.pathfindingDoneObject = object
    self.pathfindingDoneCallbackFunc = func
end

function AIDriveStrategyCourse:updatePathfinding()
    if self.pathfinder and self.pathfinder:isActive() then
        self:setMaxSpeed(0)
        local done, path = self.pathfinder:resume()
        if done then
            self.pathfindingDoneCallbackFunc(self.pathfindingDoneObject, path)
        end
    end
end

--- Create an alignment course between the current vehicle position and waypoint endIx of the course
---@param course Course the course to start
---@param ix number the waypoint where start the course
function AIDriveStrategyCourse:createAlignmentCourse(course, ix)
    self:debug('Generate alignment course to waypoint %d', ix)
    local alignmentCourse = AlignmentCourse(self.vehicle, self.vehicle:getAIDirectionNode(), self.turningRadius,
            course, ix, math.min(-self.frontMarkerDistance, -1)):getCourse()
    return alignmentCourse
end

-- remember a course to start
function AIDriveStrategyCourse:rememberCourse(course, ix)
    self.rememberedCourse = course
    self.rememberedCourseStartIx = ix
end

-- start a remembered course
function AIDriveStrategyCourse:startRememberedCourse()
    self:startCourse(self.rememberedCourse, self.rememberedCourseStartIx)
end

function AIDriveStrategyCourse:getRememberedCourseAndIx()
    return self.rememberedCourse, self.rememberedCourseStartIx
end

------------------------------------------------------------------------------------------------------------------------
--- Collision
---------------------------------------------------------------------------------------------------------------------------
function AIDriveStrategyCourse:disableCollisionDetection()
    if self.vehicle then
        CourseplaySpec.disableCollisionDetection(self.vehicle)
    end
end

function AIDriveStrategyCourse:enableCollisionDetection()
    if self.vehicle then
        CourseplaySpec.enableCollisionDetection(self.vehicle)
    end
end

------------------------------------------------------------------------------------------------------------------------
--- Course helpers
---------------------------------------------------------------------------------------------------------------------------

--- Are we within distance meters of the last waypoint (measured on the course, not direct path)?
function AIDriveStrategyCourse:isCloseToCourseEnd(distance)
    return self.course:getDistanceToLastWaypoint(self.ppc:getCurrentWaypointIx()) < distance
end

--- Are we within distance meters of the first waypoint (measured on the course, not direct path)?
function AIDriveStrategyCourse:isCloseToCourseStart(distance)
    return self.course:getDistanceFromFirstWaypoint(self.ppc:getCurrentWaypointIx()) < distance
end

--- Event raised when the drive is finished.
--- This gets called in the :stopCurrentAIJob(), as the giants code might stop the driver and not the active strategy.
function AIDriveStrategyCourse:onFinished()
    self:raiseControllerEvent(self.onFinishedEvent)
end

--- This is to set the offsets on the course at start, or update those values
--- if the user changed them during the run or the AI driver wants to add an offset
function AIDriveStrategyCourse:updateFieldworkOffset(course)
    course:setOffset(self.settings.toolOffsetX:getValue() + (self.aiOffsetX or 0) + (self.tightTurnOffset or 0),
            (self.aiOffsetZ or 0))
end

------------------------------------------------------------------------------------------------------------------------
--- Info texts
---------------------------------------------------------------------------------------------------------------------------

--- Registers info texts for specific states.
---@param infoText CpInfoTextElement
---@param states table
function AIDriveStrategyCourse:registerInfoTextForStates(infoText, states)
    if self.registeredInfoTexts[infoText] == nil then 
        self.registeredInfoTexts[infoText] = states
    end
end

--- Enables/disables based on the state.
function AIDriveStrategyCourse:updateInfoTexts()
    for infoText, states in pairs(self.registeredInfoTexts) do 
        if states[self.state] then 
            self:setInfoText(infoText)
        else 
            self:clearInfoText(infoText)
        end
    end
end