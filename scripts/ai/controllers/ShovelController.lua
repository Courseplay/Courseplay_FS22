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

---@class ShovelController : ImplementController
ShovelController = CpObject(ImplementController)

ShovelController.POSITIONS = {
    DEACTIVATED = 0, 
    LOADING = 1,
    TRANSPORT = 2,
    PRE_UNLOADING = 3,
    UNLOADING = 4,
    SUGAR_CANE_TRANSPORT = 5,
    SUGAR_CANE_UNLOADING = 6,
}
ShovelController.MAX_TRIGGER_HEIGHT = 8
ShovelController.MIN_TRIGGER_HEIGHT = 1
ShovelController.TRIGGER_HEIGHT_RAYCAST_COLLISION_MASK = CollisionFlag.STATIC_WORLD + CollisionFlag.STATIC_OBJECTS + 
                                                         CollisionFlag.STATIC_OBJECT + CollisionFlag.VEHICLE

function ShovelController:init(vehicle, implement, isConsoleCommand)
    ImplementController.init(self, vehicle, implement)
    self.shovelSpec = self.implement.spec_shovel
    self.shovelNode = ImplementUtil.getShovelNode(implement)
    self.turnOnSpec = self.implement.spec_turnOnVehicle
    self.isConsoleCommand = isConsoleCommand
end

function ShovelController:getShovelNode()
	return self.shovelNode.node
end

function ShovelController:isFull()
    return self:getFillLevelPercentage() >= 99
end

function ShovelController:isEmpty()
    return self:getFillLevelPercentage() <= 1
end

function ShovelController:getFillLevelPercentage()
    return self.implement:getFillUnitFillLevelPercentage(self.shovelNode.fillUnitIndex) * 100
end

function ShovelController:isTiltedForUnloading()
    return self.implement:getShovelTipFactor() >= 0
end

function ShovelController:isUnloading()
    return self:isTiltedForUnloading() and self.implement:getDischargeState() ~= Dischargeable.DISCHARGE_STATE_OFF
end

--- Gets current loading fill type.
function ShovelController:getShovelFillType()
    return self.shovelSpec.loadingFillType
end

function ShovelController:getDischargeFillType()
    return self.implement:getDischargeFillType(self:getDischargeNode())
end

function ShovelController:getDischargeNode()
    return self.implement:getCurrentDischargeNode()
end

--- Checks if the shovel raycast has found an unload target.
---@param targetTrigger CpTrigger|nil
---@return boolean
function ShovelController:canDischarge(targetTrigger)
    local dischargeNode = self:getDischargeNode()
    local spec = self.implement.spec_dischargeable
	if not spec.isAsyncRaycastActive then
        local oldNode = dischargeNode.raycast.node
        dischargeNode.raycast.node = self.implement.spec_attachable.attacherJoint.node
		self.implement:updateRaycast(dischargeNode)
        dischargeNode.raycast.node = oldNode
	end
    if targetTrigger and targetTrigger:getTrigger() ~= self.implement:getDischargeTargetObject(dischargeNode) then 
        return false
    end
    return dischargeNode.dischargeHit
end

--- Is the shovel node over the trailer?
---@param refNode number
---@param margin number|nil
---@return boolean
function ShovelController:isShovelOverTrailer(refNode, margin)
    local node = self:getShovelNode()
    local _, _, distShovelToRoot = localToLocal(node, self.implement.rootVehicle:getAIDirectionNode(), 0, 0, 0)
    local _, _, distTrailerToRoot = localToLocal(refNode, self.implement.rootVehicle:getAIDirectionNode(), 0, 0, 0)
    margin = margin or 0
    if self:isHighDumpShovel() then 
        margin = margin + 1
    end
    return ( distTrailerToRoot - distShovelToRoot ) < margin
end

function ShovelController:isHighDumpShovel()
    return g_vehicleConfigurations:get(self.implement, "shovelMovingToolIx") ~= nil
end

--- Calculates the minimal unloading height for the trigger.
---@param triggerNode number|nil
---@return boolean
function ShovelController:calculateMinimalUnloadingHeight(triggerNode)
    local sx, sy, sz = getWorldTranslation(self.vehicle:getAIDirectionNode())
    local tx, ty, tz
    if triggerNode then 
        tx, ty, tz = getWorldTranslation(triggerNode)
    else
        local dirX, _, dirZ = localDirectionToWorld(self.vehicle:getAIDirectionNode(), 0, 0, 1)
        local _, frontMarkerDistance = Markers.getFrontMarkerNode(self.vehicle)
        tx, ty, tz = sx + dirX * (frontMarkerDistance + 4), sy, sz + dirZ * (frontMarkerDistance + 4)
    end
    local length = MathUtil.vector2Length(tx - sx, tz - sz) + 0.25
    local dx, dy, dz = tx - sx, ty - sy, tz -sz
    local _, terrainHeight, _ = getWorldTranslation(self.vehicle.rootNode)
    local maxHeightObjectHit = 0
    for i=self.MIN_TRIGGER_HEIGHT, self.MAX_TRIGGER_HEIGHT, 0.1 do 
        self.objectWasHit = false
        raycastAll(sx, terrainHeight + i, sz,  dx, 0, dz, 
            "calculateMinimalUnloadingHeightRaycastCallback", 
            length, self, 
            self.TRIGGER_HEIGHT_RAYCAST_COLLISION_MASK)
        if self.objectWasHit then 
            maxHeightObjectHit = i
        end
    end
    if maxHeightObjectHit > 0 then 
        self:debug("Finished raycast with minimal height: %.2f", maxHeightObjectHit)
        self.implement:setCpShovelMinimalUnloadHeight(maxHeightObjectHit + 0.5)
        return true
    end
    self:debug("Could not find a valid minimal height, so we use the maximum: %.2f", self.MAX_TRIGGER_HEIGHT)
    self.implement:setCpShovelMinimalUnloadHeight(self.MAX_TRIGGER_HEIGHT)
    return false
end

--- Callback checks if an object was hit.
function ShovelController:calculateMinimalUnloadingHeightRaycastCallback(hitObjectId, x, y, z, distance, nx, ny, nz, subShapeIndex, shapeId, isLast)
    if hitObjectId then 
        local object = g_currentMission.nodeToObject[hitObjectId]
        if object then 
            if object ~= self.vehicle and object ~= self.implement then 
                self:debug("Object: %s was hit!", CpUtil.getName(object))
                self.objectWasHit = true
                return true
            end
        else 
            self:debug("Shape was hit!")
            self.objectWasHit = true
            return true
        end
        return false
    end
    return false
end

function ShovelController:delete()
    if self.implement.cpResetShovelState then
        self.implement:cpResetShovelState()
    end
end

--- Applies the given shovel position and 
--- enables shovels that need an activation for unloading.
---@param pos number shovel position 1-4
---@return boolean reached? 
function ShovelController:moveShovelToPosition(pos)
    if self.turnOnSpec then
        if pos == ShovelController.POSITIONS.UNLOADING then 
            if not self.implement:getIsTurnedOn() and self.implement:getCanBeTurnedOn() then 
                self.implement:setIsTurnedOn(true)
                self:debug("Turning on the shovel.")
            end
            if not self.implement:getDischargeState() ~= Dischargeable.DISCHARGE_STATE_OBJECT then
                self.implement:setDischargeState(Dischargeable.DISCHARGE_STATE_OBJECT)
            end
            return false
        else
            if self.implement:getIsTurnedOn() then 
                self.implement:setIsTurnedOn(false)
                self:debug("turning off the shovel.")
            end
        end
    end
    if self.implement.cpSetShovelState == nil then 
        return false
    end
    self.implement:cpSetShovelState(pos)
    return self.implement:areCpShovelPositionsDirty()
end

--------------------------------------------
--- Debug functions
--------------------------------------------

function ShovelController:printShovelDebug()
    self:debug("--Shovel Debug--")
    if self.shovelNode then
        self:debug("Fill unit index: %d, max pickup angle: %.2f, width: %.2f", 
            self.shovelNode.fillUnitIndex, 
            math.deg(self.shovelNode.maxPickupAngle),
            self.shovelNode.width)
        if self.shovelNode.movingToolActivation then
            self:debug("Has moving tool activation => open factor: %.2f, inverted: %s", 
                self.shovelNode.movingToolActivation.openFactor, 
                tostring(self.shovelNode.movingToolActivation.isInverted))
        end
        if self.shovelSpec.shovelDischargeInfo.node then
            self:debug("min angle: %.2f, max angle: %.2f", 
                math.deg(self.shovelSpec.shovelDischargeInfo.minSpeedAngle), 
                math.deg(self.shovelSpec.shovelDischargeInfo.maxSpeedAngle))
        end
    end
    self:debug("--Shovel Debug finished--")
end

function ShovelController:debug(...)
    if self.isConsoleCommand then
        --- Ignore vehicle debug setting, if the pipe controller was created by a console command.
        self:info(...)
        return
    end
    ImplementController.debug(self, ...)    
end
