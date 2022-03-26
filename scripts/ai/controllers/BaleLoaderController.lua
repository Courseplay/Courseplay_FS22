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

--- Controller for bale loaders. Not much to do here as long as we do not unload the bales,
--- loading them is pretty straightforward and automatic, once they are in range.

---@class BaleLoaderController : ImplementController
BaleLoaderController = CpObject(ImplementController)

function BaleLoaderController:init(vehicle, baleLoader)
    self.baleLoader = baleLoader
    self.baleLoaderSpec = baleLoader.spec_baleLoader
    ImplementController.init(self, vehicle, self.baleLoader)
    if self.baleLoader then
        -- Bale loaders have no AI markers (as they are not AIImplements according to Giants) so add a function here
        -- to get the markers
        self.baleLoader.getAIMarkers = function(object)
            return ImplementUtil.getAIMarkersFromGrabberNode(object, object.spec_baleLoader)
        end
    end
    self:debug('Bale loader controller initialized')
end

function BaleLoaderController:isGrabbingBale()
    return self.baleLoader.spec_baleLoader.grabberMoveState
end

--- Is at least one bale loaded?
function BaleLoaderController:hasBales()
    return self.baleLoader:getFillUnitFillLevelPercentage(self.baleLoaderSpec.fillUnitIndex) >= 0.01
end

function BaleLoaderController:isFull()
    return self.baleLoader:getFillUnitFreeCapacity(self.baleLoaderSpec.fillUnitIndex) <= 0.01
end

function BaleLoaderController:canBeFolded()
    return not self:isGrabbingBale() and self.baleLoaderSpec.emptyState == BaleLoader.EMPTY_NONE
end

function BaleLoaderController:update()
    --- The bale loader is full.
    if self:isFull() and self:canBeFolded() then
        --- Only stop the driver when any possible animations have finished playing.
        self:info('Bale loader is full, stopping job.')
        self.vehicle:stopCurrentAIJob(AIMessageErrorIsFull.new())
    end
end

function BaleLoaderController:getDriveData()
    --- While animations are playing and the bale loader is full, then just wait.
    local maxSpeed 
    if self:isFull() then 
        self:debugSparse("is full and waiting for release after animation has finished.")
        maxSpeed = 0
    end
    return nil, nil, nil, maxSpeed
end

function BaleLoaderController:isFuelSaveAllowed()
    return false
end

function BaleLoaderController:onStart()
    if not self.baleLoaderSpec.isInWorkPosition then
        self.baleLoader:doStateChange(BaleLoader.CHANGE_BUTTON_WORK_TRANSPORT)
    end
end
