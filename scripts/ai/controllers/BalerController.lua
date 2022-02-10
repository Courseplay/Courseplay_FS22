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

function BalerController:init(vehicle)
    self.baler = AIUtil.getImplementOrVehicleWithSpecialization(vehicle, Baler)
    ImplementController.init(self, vehicle, self.baler)
    self.slowDownFillLevel = 200
    self.slowDownStartSpeed = 20
    self.balerSpec = self.baler.spec_baler
    self:debug('Baler controller initialized')
end

function BalerController:getDriveData()
    local maxSpeed = self:handleBaler()
    return nil, nil, nil, maxSpeed
end

function BalerController:handleBaler()
    local maxSpeed

    if not self.baler:getIsTurnedOn() then
        if self.baler.setFoldState then
            -- unfold if there is something to unfold
            self.baler:setFoldState(-1, false)
        end
        if self.baler:getCanBeTurnedOn() then
            self:debug('Turning on baler')
            self.baler:setIsTurnedOn(true, false);
        else --maybe this line is enough to handle bale dropping and waiting ?
            maxSpeed = 0
        end
    end

    if self.baler.setPickupState ~= nil then -- lower pickup after unloading
        if self.baler.spec_pickup ~= nil and not self.baler.spec_pickup.isLowered then
            self.baler:setPickupState(true, false)
            self:debug('lowering baler pickup')
        end
    end
    
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
