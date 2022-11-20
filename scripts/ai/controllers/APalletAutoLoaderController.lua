--[[
This file is part of Courseplay (https://github.com/Courseplay/courseplay)
Copyright (C) 2019-2022 Peter Vaiko

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

--- Controller for the auto loader script: https://bitbucket.org/Achimobil79/ls22_palletautoloader

---@class APalletAutoLoaderController : BaleLoaderController
APalletAutoLoaderController = CpObject(BaleLoaderController)

function APalletAutoLoaderController:init(vehicle, autoLoader)
    self.autoLoader = autoLoader
    self.autoLoaderSpec = autoLoader.spec_aPalletAutoLoader
    ImplementController.init(self, vehicle, self.autoLoader)
    self:debug('Pallet autoloader controller initialized')
end

function APalletAutoLoaderController:isGrabbingBale()
    if self.autoLoader.PalIsGrabbingBale ~= nil then
        return self.autoLoader:PalIsGrabbingBale();
    end
    
    -- fallback for older AL versions
    return false
end

--- Is at least one bale loaded?
function APalletAutoLoaderController:hasBales()
    if self.autoLoader.PalHasBales ~= nil then
        return self.autoLoader:PalHasBales();
    end
    
    -- fallback for older AL versions
    return self.autoLoader:getFillUnitFillLevelPercentage(self.autoLoaderSpec.fillUnitIndex) >= 0.01
end

function APalletAutoLoaderController:isFull()
    if self.autoLoader.PalIsFull ~= nil then
        return self.autoLoader:PalIsFull();
    end
    
    -- fallback for older AL versions
    return self.autoLoader:getFillUnitFreeCapacity(self.autoLoaderSpec.fillUnitIndex) <= 0.01
end

function APalletAutoLoaderController:canBeFolded()
    return true
end

function APalletAutoLoaderController:isFuelSaveAllowed()
    return true
end

function APalletAutoLoaderController:onStart()
    -- turning the autoloader on when CP starts
    self.vehicle:raiseAIEvent("onAIFieldWorkerStart", "onAIImplementStart")
end

function APalletAutoLoaderController:onFinished()
    -- turning the autoloader on when CP starts
    self.vehicle:raiseAIEvent("onAIFieldWorkerEnd", "onAIImplementEnd")
end

--- Ignore all already loaded bales when pathfinding
function APalletAutoLoaderController:getBalesToIgnore()
    if self.autoLoader.PalGetBalesToIgnore ~= nil then
        return self.autoLoader:PalGetBalesToIgnore();
    end
    
    -- fallback for older AL versions
    local objectsToIgnore = {}
    for object, _ in pairs(self.autoLoaderSpec.triggeredObjects) do
        table.insert(objectsToIgnore, object)
    end
    return objectsToIgnore
end

function APalletAutoLoaderController:getDriveData()
    local maxSpeed 
    if self:isFull() then
        self:debugSparse("is full and waiting for release after animation has finished.")
        maxSpeed = 0
    end
    return nil, nil, nil, maxSpeed
end

function APalletAutoLoaderController:isChangingBaleSize()
    return false
end