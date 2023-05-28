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

---@class BalerController : ImplementController
BalerController = CpObject(ImplementController)

function BalerController:init(vehicle, baler)
    self.baler = baler
    ImplementController.init(self, vehicle, self.baler)
    self.slowDownFillLevel = 200
    self.slowDownStartSpeed = 20
    self.balerSpec = self.baler.spec_baler
    self.baleWrapperSpec = self.baler.spec_baleWrapper
    self.lastDroppedBale = CpTemporaryObject()
    self:debug('Baler controller initialized')
end

function BalerController:getDriveData()
    local maxSpeed = self:handleBaler()
    return nil, nil, nil, maxSpeed
end

function BalerController:update()
	if self.settings.useAdditiveFillUnit:getValue() then 
		--- If the silage additive is empty, then stop the driver.
        if self.balerSpec.additives.available then 
            if self.implement:getFillUnitFillLevelPercentage(self.balerSpec.additives.fillUnitIndex) <= 0 then 
                self:debug("Stopped Cp, as the additive fill unit is empty.")
                self.vehicle:stopCurrentAIJob(AIMessageErrorOutOfFill.new())
            end
        end
    end
end

function BalerController:handleBaler()
    if self.driveStrategy:isTurning() then
        --- Waits for the bale wrapping and unload at the start of a turn.
        if self:isWrappingBale() then
            return 0
        end
        if self.balerSpec.unloadingState ~= Baler.UNLOADING_CLOSED then
            return 0
        end
        --- Waits until the bale dropped to the platform.
        if self.balerSpec.platformDropInProgress then
            return self.balerSpec.platformAIDropSpeed
        end
        --- Makes sure the slowdown is not applied, while turning.
        return
    end
    local maxSpeed
    if not self.balerSpec.nonStopBaling and self.balerSpec.hasUnloadingAnimation then
        local fillLevel = self.baler:getFillUnitFillLevel(self.balerSpec.fillUnitIndex)
        local capacity = self.baler:getFillUnitCapacity(self.balerSpec.fillUnitIndex)
        local freeFillLevel = capacity - fillLevel

        if freeFillLevel < self.slowDownFillLevel then
            maxSpeed = 2 + freeFillLevel / self.slowDownFillLevel * self.slowDownStartSpeed
        end

        if fillLevel == capacity or self.balerSpec.unloadingState ~= Baler.UNLOADING_CLOSED then
            maxSpeed = 0
        end
    elseif self.balerSpec.platformDropInProgress then
        maxSpeed = self.balerSpec.platformAIDropSpeed
    end
    return maxSpeed
end

function BalerController:isWrappingBale()
    if self.baleWrapperSpec then 
        local state = self.baleWrapperSpec.baleWrapperState
        return state ~= BaleWrapper.STATE_NONE and state ~= BaleWrapper.STATE_WRAPPER_FINSIHED
    end
end

function BalerController:isWaitingForBaleOutput()
    if not self.balerSpec.nonStopBaling and self.balerSpec.hasUnloadingAnimation then
        local fillLevel = self.baler:getFillUnitFillLevel(self.balerSpec.fillUnitIndex)
        local capacity = self.baler:getFillUnitCapacity(self.balerSpec.fillUnitIndex)

        if fillLevel == capacity or self.balerSpec.unloadingState ~= Baler.UNLOADING_CLOSED then
            return true
        end
    elseif self.balerSpec.platformDropInProgress then 
        return true
    end
end

--- Makes sure that fuel save is disabled, while a bale is dropping.
function BalerController:isFuelSaveAllowed()
    return not self:isWaitingForBaleOutput()
end

--- Giants isn't unfolding balers, so we do it here.
function BalerController:onStart()
    self.baler:setFoldDirection(self.baler.spec_foldable.turnOnFoldDirection)
end

function BalerController:onFinished()
    -- TODO: not working, as this probably needs to be called, before the drive is released.
    -- Baler.actionEventUnloading(self.implement)
end

function BalerController:isThisMyBale(baleObject)
    if self.balerSpec.bales then
        if self.lastDroppedBale:get() == baleObject then
            return true
        end
        -- we assume that the baler always drops bale #1. So if #1 changes, remember the one which was
        -- the first previously, as that must be the one being dropped
        if self.previousFirstBale ~= self.balerSpec.bales[1].baleObject then
            -- the last dropped bale is removed from the baler approximately when it is halfway down the
            -- ramp, but then we still want to ignore it, so try to remember it for a while
            self.lastDroppedBale:set(self.previousFirstBale, 30000)
            self.previousFirstBale = self.balerSpec.bales[1].baleObject
        end
        for i = 1, #self.balerSpec.bales do
            if self.balerSpec.bales[i].baleObject == baleObject then
                return true
            end
        end
    end
    return false
end

--- Ignore bales not dropped yet when moving backwards
function BalerController:ignoreProximityObject(object, vehicle, moveForwards)
    if object and not moveForwards and object.isa and object:isa(Bale) then
        if self:isThisMyBale(object) then
            self:debugSparse('ignoring undropped bale in the back')
            return true
        end
    end
end

--- Ask the proximity controller to check with us if an object is blocking, we don't want to block
--- on bales ready but not dropped yet when moving backwards
function BalerController:registerIgnoreProximityObjectCallback(proximityController)
    proximityController:registerIgnoreObjectCallback(self, self.ignoreProximityObject)
end

--- Returns false, while the baler is being unfolded.
---@return boolean
function BalerController:canContinueWork()
    local spec = self.baler.spec_foldable
    if spec == nil then 
        return true
    end
    return spec.foldAnimTime == 0 or spec.foldAnimTime == 1
end