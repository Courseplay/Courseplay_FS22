--[[
This file is part of Courseplay (https://github.com/Courseplay/Courseplay_FS22)
Copyright (C) 2022-2023 Courseplay Dev Team

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

---@class ImplementController
ImplementController = CpObject()

function ImplementController:init(vehicle, implement)
    self.vehicle = vehicle
    self.implement = implement
    self.settings = vehicle:getCpSettings()
    self.disabledStates = {}
end

--- Get the controlled implement
function ImplementController:getImplement()
    return self.implement
end

---@param disabledStates table|nil list of drive strategy states where the controlling of this implement is disabled
function ImplementController:setDisabledStates(disabledStates)
    self.disabledStates = disabledStates
end

function ImplementController:setDriveStrategy(driveStrategy)
    self.driveStrategy = driveStrategy
end

---@param currentState table current state of the drive strategy
---@return boolean true if currentState is not one of the disabled states
function ImplementController:isEnabled(currentState)
    if self.disabledStates then
        for _, state in pairs(self.disabledStates) do
            if currentState == state then
                return false
            end
        end
    end
    return true
end

function ImplementController:debug(...)
    CpUtil.debugImplement(CpDebug.DBG_IMPLEMENTS, self.implement, ...)
end

function ImplementController:debugSparse(...)
    if g_updateLoopIndex % 100 == 0 then
        self:debug(...)
    end
end

function ImplementController:info(...)
    CpUtil.infoVehicle(self.vehicle, CpUtil.getName(self.implement) .. ': ' .. string.format(...))
end

--- Drive strategies can instantiate controllers for implements and call getDriveData for each
--- implement. If the implement wants to change any of the driving parameter, it'll return
--- a non nil value for that parameter, most often a speed value to slow down or stop.

---@return number gx world x coordinate to drive to or nil
---@return number gz world z coordinate to drive to or nil
---@return boolean direction is forwards if true or nil
---@return number maximum speed or nil
function ImplementController:getDriveData()
    return nil, nil, nil, nil
end

function ImplementController:update(dt)
    -- implement in the derived classes as needed
end

function ImplementController:delete()
    
end

--- Called by the drive strategy on lowering of the implements.
function ImplementController:onLowering()
    --- override 
end

--- Called by the drive strategy on raising of the implements.
function ImplementController:onRaising()
    --- override
end

function ImplementController:onStart()
    --- override
end

function ImplementController:onFinished()
    --- override
end

function ImplementController:onFinishRow(isHeadlandTurn)
end

function ImplementController:onTurnEndProgress(workStartNode, reversing, shouldLower, isLeftTurn)
end

--- Any object this controller wants us to ignore, can register here a callback at the proximity controller
function ImplementController:registerIgnoreProximityObjectCallback(proximityController)

end

function ImplementController:setInfoText(infoText)
    self.driveStrategy:setInfoText(infoText)
end

function ImplementController:clearInfoText(infoText)
    self.driveStrategy:clearInfoText(infoText)
end

function ImplementController:isFuelSaveAllowed()
    return true
end

function ImplementController:canContinueWork()
    return true
end

--------------------------------------------
--- Interfaces
--------------------------------------------

ImplementControllerInterfaces = {}

---@class UnloadImplementControllerInterface : ImplementController
local UnloadImplementControllerInterface = CpObject(ImplementController)

--- Gets the dischargeNode and offset from a selected tip side.
---@param tipSideID number|nil
---@param isTippingToGroundNeeded boolean|nil
---@return number dischargeNodeIndex
---@return table dischargeNode
---@return number xOffset 
function UnloadImplementControllerInterface:getDischargeNodeAndOffsetForTipSide(tipSideID, isTippingToGroundNeeded)
    ---override
    return 0, {}, 0
end

--- Gets the x offset of the dischargeNode
---@param dischargeNode table
---@return number
function UnloadImplementControllerInterface:getDischargeXOffset(dischargeNode)
    ---override
    return 0
end

--- Starts discharging
---@param dischargeNode table
---@return boolean|nil
function UnloadImplementControllerInterface:startDischarge(dischargeNode)
    ---override
end

--- Starts discharging to the ground
---@param dischargeNode table
---@return boolean|nil
function UnloadImplementControllerInterface:startDischargeToGround(dischargeNode)
    ---override
end

--- Function callback once the discharge has finished
---@param finishDischargeCallback function function callback(fillLevelPercentage) end
function UnloadImplementControllerInterface:setFinishDischargeCallback(finishDischargeCallback)
    ---override    
end

--- Prepares the trailer for discharging, for example pipe unfolding and so on ..
---@return boolean|nil
function UnloadImplementControllerInterface:prepareForUnload()
    ---override
end

--- Is the trailer currently discharging?
---@return boolean|nil
function UnloadImplementControllerInterface:isDischarging()
    ---override    
end

--- Gets the z offset 
---@param dischargeNode table
---@return number
function UnloadImplementControllerInterface:getUnloadOffsetZ(dischargeNode)
    ---override  
    return 0 
end
---@type UnloadImplementControllerInterface
ImplementControllerInterfaces.UnloadImplementControllerInterface = UnloadImplementControllerInterface