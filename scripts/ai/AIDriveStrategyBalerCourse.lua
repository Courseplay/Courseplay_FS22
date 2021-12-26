--[[
This file is part of Courseplay (https://github.com/Courseplay/courseplay)
Copyright (C) 2019-2021 Peter Vaiko

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

---@class AIDriveStrategyBalerCourse : AIDriveStrategyFieldWorkCourse
AIDriveStrategyBalerCourse = {}
local AIDriveStrategyBalerCourse_mt = Class(AIDriveStrategyBalerCourse, AIDriveStrategyFieldWorkCourse)

function AIDriveStrategyBalerCourse.new(customMt)
    if customMt == nil then
        customMt = AIDriveStrategyBalerCourse_mt
    end
    local self = AIDriveStrategyFieldWorkCourse.new(customMt)
    self.slowDownFillLevel = 200
    self.slowDownStartSpeed = 20
    return self
end

function AIDriveStrategyBalerCourse:setAIVehicle(vehicle)
    AIDriveStrategyBalerCourse:superClass().setAIVehicle(self, vehicle)

    if SpecializationUtil.hasSpecialization(Combine, vehicle.specializations) or
            AIUtil.hasAIImplementWithSpecialization(vehicle, Combine) then
        self.isCombine = true
    end
    self.baler = AIUtil.getImplementWithSpecialization(self.vehicle, Baler)
    if self.baler then
        self.balerSpec = self.baler.spec_baler
        --use giants automaticDrop, so we don't have to do it
        if self.balerSpec then
            self.oldAutomaticDrop = self.balerSpec.automaticDrop
            self.balerSpec.automaticDrop = true
        end
    end
end

function AIDriveStrategyBalerCourse:getDriveData(dt, vX, vY, vZ)
    if self.baler then
        self:handleBaler()
    end
    return AIDriveStrategyBalerCourse.superClass().getDriveData(self, dt, vX, vY, vZ)
end

function AIDriveStrategyBalerCourse:startTurn(ix)
    if self.isCombine then
        self:debug('This vehicle is also a harvester, check check for special headland turns.')
        local fm, bm = self:getFrontAndBackMarkers()
        self.turnContext = TurnContext(self.course, ix, self.turnNodes, self:getWorkWidth(), fm, bm,
                self:getTurnEndSideOffset(), self:getTurnEndForwardOffset())

        if self.turnContext:isHeadlandCorner() then
            if self.course:isOnConnectingTrack(ix) then
                self:debug('Headland turn but this a connecting track, use normal turn maneuvers.')
                AIDriveStrategyFieldWorkCourse.startTurn(self, ix)
            elseif self.course:isOnOutermostHeadland(ix) and self.vehicle.cp.settings.turnOnField:is(true) then
                self:debug('Creating a pocket in the corner so the harvester stays on the field during the turn')
                self.aiTurn = CombinePocketHeadlandTurn(self.vehicle, self, self.ppc, self.turnContext,
                        self.course, self:getWorkWidth())
                self.fieldworkState = self.states.TURNING
                self.ppc:setShortLookaheadDistance()
            else
                self:debug('Use combine headland turn.')
                self.aiTurn = CombineHeadlandTurn(self.vehicle, self, self.ppc, self.turnContext)
                self.fieldworkState = self.states.TURNING
            end
        else
            self:debug('Non headland turn.')
            AIDriveStrategyFieldWorkCourse.startTurn(self, ix)
        end
    else
        AIDriveStrategyFieldWorkCourse.startTurn(self, ix)
    end
end

function AIDriveStrategyBalerCourse:isHandlingAllowed()
    if self.state == self.states.ON_CONNECTING_TRACK or
            self.state == self.states.TEMPORARY or self.state == self.states.TURNING then
        return false
    end
    return true
end

function AIDriveStrategyBalerCourse:handleBaler()
    -- turn.lua will raise/lower as needed, don't touch the balers while the turn maneuver is executed or while on temporary alignment / connecting track
    if not self:isHandlingAllowed() then return end
    if not self.baler:getIsTurnedOn() then
        if self.baler.setFoldState then
            -- unfold if there is something to unfold
            self.baler:setFoldState(-1, false)
        end
        if self.baler:getCanBeTurnedOn() then
            self:debug('Turning on baler')
            self.baler:setIsTurnedOn(true, false);
        else --maybe this line is enough to handle bale dropping and waiting ?
            self:setMaxSpeed(0)
            --baler needs refilling of some sort (net,...)
            if self.balerSpec.unloadingState == Baler.UNLOADING_CLOSED then
                self:setInfoText('NEEDS_REFILLING')
            end
        end
    end

    if self.baler.setPickupState ~= nil then -- lower pickup after unloading
        if self.baler.spec_pickup ~= nil and not self.baler.spec_pickup.isLowered then
            self.baler:setPickupState(true, false)
            self:debug('lowering baler pickup')
        end
    end

    local fillLevel = self.baler:getFillUnitFillLevel(self.balerSpec.fillUnitIndex)
    local capacity = self.baler:getFillUnitCapacity(self.balerSpec.fillUnitIndex)

    if not self.balerSpec.nonStopBaling and (self.balerSpec.hasUnloadingAnimation or self.balerSpec.allowsBaleUnloading) then
        self:debugSparse("hasUnloadingAnimation: %s, allowsBaleUnloading: %s, nonStopBaling:%s",
                tostring(self.balerSpec.hasUnloadingAnimation),tostring(self.balerSpec.allowsBaleUnloading),tostring(self.balerSpec.nonStopBaling))
        --copy of giants code:  AIDriveStrategyBaler:getDriveData(dt, vX,vY,vZ) to avoid leftover when full
        local freeFillLevel = capacity - fillLevel
        if freeFillLevel < self.slowDownFillLevel then
            local maxSpeed = 2 + (freeFillLevel / self.slowDownFillLevel) * self.slowDownStartSpeed
            self:setMaxSpeed(maxSpeed)
        end

        --baler is full or is unloading so wait!
        if fillLevel == capacity or self.balerSpec.unloadingState ~= Baler.UNLOADING_CLOSED then
            self:setMaxSpeed(0)
        end
    end
    return true
end

Pickup.onAIImplementStartLine = Utils.overwrittenFunction(Pickup.onAIImplementStartLine,
        function(self, superFunc)
            if superFunc ~= nil then superFunc(self) end
            self:setPickupState(true)
        end)

Pickup.onAIImplementEndLine = Utils.overwrittenFunction(Pickup.onAIImplementEndLine,
        function(self, superFunc)
            if superFunc ~= nil then superFunc(self) end
            self:setPickupState(false)
        end)

Pickup.onAIImplementEnd = Utils.overwrittenFunction(Pickup.onAIImplementEnd,
        function(self, superFunc)
            if superFunc ~= nil then superFunc(self) end
            self:setPickupState(false)
        end)

-- TODO: move these to another dedicated class for implements?
local PickupRegisterEventListeners = function(vehicleType)
    print('## Courseplay: Registering pickup event listeners for loader wagons/balers.')
    SpecializationUtil.registerEventListener(vehicleType, "onAIImplementStartLine", Pickup)
    SpecializationUtil.registerEventListener(vehicleType, "onAIImplementEndLine", Pickup)
    SpecializationUtil.registerEventListener(vehicleType, "onAIImplementEnd", Pickup)
end

print('## Courseplay: Appending pickup event listener for loader wagons/balers.')
Pickup.registerEventListeners = Utils.appendedFunction(Pickup.registerEventListeners, PickupRegisterEventListeners)
