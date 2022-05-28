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

--- Controller for the pallet autoloader https://bitbucket.org/Achimobil79/ls22_palletautoloader

---@class APalletAutoLoaderController : BaleLoaderController
APalletAutoLoaderController = CpObject(BaleLoaderController)

function APalletAutoLoaderController:init(vehicle, autoLoader)
    self.autoLoader = autoLoader
    self.autoLoaderSpec = autoLoader.spec_aPalletAutoLoader
    ImplementController.init(self, vehicle, self.autoLoader)
    self:debug('Pallet autoloader controller initialized')
end

function APalletAutoLoaderController:isGrabbingBale()
    return false
end

--- Is at least one bale loaded?
function APalletAutoLoaderController:hasBales()
    return self.autoLoader:getFillUnitFillLevelPercentage(self.autoLoaderSpec.fillUnitIndex) >= 0.01
end

function APalletAutoLoaderController:isFull()
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
    self.autoLoader:SetLoadingState(FS22_aPalletAutoLoader.APalletAutoLoaderLoadingState.RUNNING)
end

--- Ignore all already loaded bales when pathfinding
function APalletAutoLoaderController:getBalesToIgnore()
    local objectsToIgnore = {}
    for object, _ in pairs(self.autoLoaderSpec.triggeredObjects) do
        table.insert(objectsToIgnore, object)
    end
    return objectsToIgnore
end