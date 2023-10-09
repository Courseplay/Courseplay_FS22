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

--------------------------------------------
--- Sugar can trailer controller
--------------------------------------------

---@class SugarCaneTrailerController : ShovelController
SugarCaneTrailerController = CpObject(ShovelController)
function SugarCaneTrailerController:init(vehicle, implement, isConsoleCommand)
    ShovelController.init(self, vehicle, implement, isConsoleCommand)
    --- Is the sugar can trailer currently discharging?
    self.isDischargeActive = false
    --- Timer to check if the discharge is active
    self.isDischargingTimer = CpTemporaryObject(false)
    --- Is the discharge target the ground?
    self.isDischargingToGround = false
    
end

function SugarCaneTrailerController.getValidTrailer(vehicle)
    local shovelVehicles, _ = AIUtil.getAllChildVehiclesWithSpecialization(vehicle, Shovel)
    for i, implement in pairs(shovelVehicles) do
        if ImplementUtil.isAttachedToTrailerJoint(implement) then 
            return implement
        end
    end
end

function SugarCaneTrailerController:getDischargeObject()
    local dischargeNode = self:getDischargeNode()
    if dischargeNode then
        local targetObject, fillUnitIndex = self.implement:getDischargeTargetObject(dischargeNode)
        return targetObject, fillUnitIndex
    end
    return false
end

function SugarCaneTrailerController:getDriveData()
	local maxSpeed

    --- Sugar cane trailer discharge
    if self.isDischargeActive then
        if self:isEmpty() then 
            self:debug("Finished unloading as the trailer is empty.")
            self:finishedSugarCaneTrailerDischarge()
        end
        if self:moveShovelToPosition(self.POSITIONS.SUGAR_CANE_UNLOADING) then 
            self.isDischargingTimer:set(true, 500)
            maxSpeed = 0
            self:debugSparse("Waiting for unloading moving tool to finish!")
        else
            if self.isDischargingToGround then 
                self.isDischargingTimer:set(true, 500)
                if self.implement:getCanDischargeToGround(self:getDischargeNode()) then 
                    maxSpeed = 0
                end
            else 
                if self:getDischargeObject() then
                    self.isDischargingTimer:set(true, 500)
                    self:debugSparse("Waiting for unloading to trailer to finish!")
                end
            end
            if not self.isDischargingTimer:get() then 
                self:debug("Finished unloading by timer.")
                self:finishedSugarCaneTrailerDischarge()
            end
        end
    else 
        if self:moveShovelToPosition(self.POSITIONS.SUGAR_CANE_TRANSPORT) then 
            maxSpeed = 0
        end
    end
	return nil, nil, nil, maxSpeed
end

--- Gets the dischargeNode and offset from a selected tip side.
---@param tipSideID number
---@param isTippingToGroundNeeded boolean
---@return table|nil dischargeNodeIndex
---@return table|nil dischargeNode
---@return number|nil xOffset 
function SugarCaneTrailerController:getDischargeNodeAndOffsetForTipSide(tipSideID, isTippingToGroundNeeded)
    local dischargeNode = self:getDischargeNode()
    return dischargeNode.index, dischargeNode, self:getDischargeXOffset(dischargeNode)
end

--- Gets the x offset of the discharge node relative to the implement root.
function SugarCaneTrailerController:getDischargeXOffset(dischargeNode)
    return 3.5-- g_vehicleConfigurations:get("")
end

--- Starts AI Discharge to an object/trailer.
---@param dischargeNode table discharge node to use.
---@return boolean success
function SugarCaneTrailerController:startDischarge(dischargeNode)
    self.isDischargeActive = true
    self.isDischargingTimer:set(true, 500)
    return true
end

--- Starts discharging to the ground if possible.
function SugarCaneTrailerController:startDischargeToGround(dischargeNode)
    self.isDischargeActive = true
    self.isDischargingToGround = true
    -- self.isDischargingToGround = true
    -- self.dischargeData = {
    --     dischargeNode = dischargeNode,
    -- }
	-- local tipSide = self.trailerSpec.dischargeNodeIndexToTipSide[dischargeNode.index]
	-- if tipSide ~= nil then
	-- 	self.implement:setPreferedTipSide(tipSide.index)
	-- end
    return true
end

--- Callback for the drive strategy, when the unloading finished.
function SugarCaneTrailerController:setFinishDischargeCallback(finishDischargeCallback)
    self.finishDischargeCallback = finishDischargeCallback
end

--- Callback for ai discharge.
function SugarCaneTrailerController:finishedSugarCaneTrailerDischarge()
    self:debug("Finished unloading.")
    if self.finishDischargeCallback then 
        self.finishDischargeCallback(self.driveStrategy, self, self:getFillLevelPercentage())
    end
    self.isDischargeActive = false
    self.isDischargingToGround = false
end

function SugarCaneTrailerController:prepareForUnload()
    return true
end

function SugarCaneTrailerController:isDischarging()
    return self.implement:getDischargeState() ~= Dischargeable.DISCHARGE_STATE_OFF
end

--- Gets the discharge node z offset relative to the root vehicle direction node.
function SugarCaneTrailerController:getUnloadOffsetZ(dischargeNode)
    local _, _, offsetZ = localToLocal(dischargeNode.node, 
        self.implement.rootNode, 0, 0, 0)
    local dist = ImplementUtil.getDistanceToImplementNode(self.vehicle:getAIDirectionNode(),
        self.implement, self.implement.rootNode)
    return offsetZ + dist
end
