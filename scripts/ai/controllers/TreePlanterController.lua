--[[
This file is part of Courseplay (https://github.com/Courseplay/courseplay)
Copyright (C) 2024 Courseplay dev team

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

--- Extension for the Treeplanter Spec
---@class TreePlanterController : ImplementController
TreePlanterController = CpObject(ImplementController)
function TreePlanterController:init(vehicle, implement)
    ImplementController.init(self, vehicle, implement) 
    self.treePlanterSpec = implement.spec_treePlanter
end

-------------------------
--- Refill handling
-------------------------

function TreePlanterController:isRefillingAllowed()
    return true
end

function TreePlanterController:needsRefilling()
    return not g_currentMission.missionInfo.helperBuySeeds 
        and self.treePlanterSpec.mountedSaplingPallet == nil
end

function TreePlanterController:onStartRefilling() 
	if self:needsRefilling() then 
        if self.implement.aiPrepareLoading ~= nil then
            self.implement:aiPrepareLoading(self.treePlanterSpec.fillUnitIndex)
        end
        self.refillData.timer:set(false, 10 * 1000)
	end
    self.refillData.hasChanged = false
end

function TreePlanterController:onUpdateRefilling()
    if self.treePlanterSpec.mountedSaplingPallet == nil and 
        self.treePlanterSpec.nearestSaplingPallet ~= nil then

        self.implement:loadPallet(NetworkUtil.getObjectId(
            self.treePlanterSpec.nearestSaplingPallet))
        self.refillData.hasChanged = true
    end
    return self.refillData.timer:get(), self.refillData.hasChanged
end

function TreePlanterController:onStopRefilling()
    if self.implement.aiFinishLoading ~= nil then
        self.implement:aiFinishLoading()
    end
end