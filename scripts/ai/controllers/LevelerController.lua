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

--- Controls the leveler height and tilt.
---@class LevelerController : ImplementController
LevelerController = CpObject(ImplementController)

function LevelerController:init(vehicle, leveler)
    ImplementController.init(self, vehicle, leveler)
    self.levelerSpec = leveler.spec_leveler
	self.shieldHeightOffset = 0
end

function LevelerController:update(dt)
	self:updateHeight(dt)	
end

function LevelerController:getDriveData()
    local maxSpeed = nil
    return nil, nil, nil, maxSpeed
end

--- Updates leveler height and rotation.
function LevelerController:updateHeight(dt)
	local shield = self.implement
	local spec = shield.spec_attacherJointControl
	local jointDesc = spec.jointDesc
	local objectAttacherJoint = shield.spec_attachable.attacherJoint
	if self.driveStrategy:isLevelerLoweringAllowed() then 
		local levelerNode = shield.spec_leveler.nodes[1].node
		local x, y, z = getWorldTranslation(levelerNode)
		local terrainHeight = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, y, z)
		---target height of leveling, fill up is 0 by default
		local targetHeight = self:getTargetShieldHeight()

		self:updateShieldHeightOffset()
		--get the height difference that needs to be adjusted form the shield leveler node to the ground
		local heightDiff = terrainHeight+self.shieldHeightOffset+targetHeight-y

		--[[ In the long term it should be safer to calculate the new alpha directly,
				instead of adjusting the alpha by a constant.
				This is currently not working as the shield then tends to toggle between going up and down repeatedly.

		---Reference: AttacherJoints:calculateAttacherJointMoveUpperLowerAlpha(jointDesc, object)
		local dx, dy, dz = localToLocal(jointDesc.jointTransform, jointDesc.rootNode, 0, 0, 0)
		local delta = jointDesc.lowerDistanceToGround - dy
		local ax, ay, az = localToLocal(jointDesc.jointTransform, levelerNode, 0, heightDiff, 0)
		local hx, hy, hz = localToLocal(jointDesc.jointTransform, jointDesc.rootNode, ax, ay, az)
		local lowerDistanceToGround = hy + delta

		--calculate the target alpha
		local alpha = MathUtil.clamp((lowerDistanceToGround - jointDesc.upperDistanceToGround) / (jointDesc.lowerDistanceToGround - jointDesc.upperDistanceToGround), 0, 1)
		self:debug("lastCurAlpha: %.2f, nextAlpha: %.2f, heightDiff: %.2f", spec.lastHeightAlpha, alpha, heightDiff)
		self:debug("terrainHeight: %.2f, shieldHeight: %.2f, shieldHeightOffset: %.2f, targetHeight: %.2f", terrainHeight, y, self.shieldHeightOffset, targetHeight)

		]]--
	--	self:debug("heightDiff: %.2f, shieldHeightOffset: %.2f, targetHeight: %.2f", heightDiff, self.shieldHeightOffset, targetHeight)		
		local curAlpha = spec.heightController.moveAlpha 
		--For now we are only adjusting the shield height by a constant
		--heightDiff > -0.04 means we are under the target height, for example in fillUp modi below the ground offset by 0.04			
		if heightDiff > -0.04 then 
			spec.heightTargetAlpha = curAlpha - 0.05 
		--heightDiff < -0.12 means we are above the target height by 0.12, which also is used to minimize going up and down constantly  
		elseif heightDiff < -0.12 then
			spec.heightTargetAlpha = curAlpha + 0.05 
		else
		--shield is in valid height scope, so we stop all movement
			spec.heightTargetAlpha =-1
		end
		--TODO: maybe change the shield tilt angle relative to the shield height alpha

		--rotate shield to standing on ground position, should roughly be 90 degree to ground by default
		--tilt the shield relative to the additional shield height offset
		--added a factor of 2 to make sure the shield is getting tilted enough
		local targetAngle = math.min(spec.maxTiltAngle*self.shieldHeightOffset*2, spec.maxTiltAngle)
		self:controlShieldTilt(dt, jointDesc, spec.maxTiltAngle, targetAngle)		
	else 
		self.shieldHeightOffset = 0
		spec.heightTargetAlpha = jointDesc.upperAlpha
		--move shield to upperPosition and rotate it up
		self:controlShieldTilt(dt, jointDesc, spec.maxTiltAngle, spec.maxTiltAngle)			
	end
end

--- Controls the tilt of the shield, as giants doesn't have implement a function for tilting the shield smoothly
---@param dt number
---@param jointDesc table of the vehicle
---@param maxTiltAngle number max tilt angle
---@param targetAngle number target tilt angle
function LevelerController:controlShieldTilt(dt, jointDesc, maxTiltAngle, targetAngle)
	local curAngle = jointDesc.upperRotationOffset-jointDesc.upperRotationOffsetBackup
	local diff = curAngle - targetAngle + 0.0001
	local moveTime = diff / maxTiltAngle * jointDesc.moveTime
	local moveStep = dt / moveTime * diff
	if diff > 0 then
		moveStep = -moveStep
	end
	local newAngle = targetAngle + moveStep/10
	jointDesc.upperRotationOffset = jointDesc.upperRotationOffsetBackup - newAngle
	jointDesc.lowerRotationOffset = jointDesc.lowerRotationOffsetBackup - newAngle
end

--- If the driver is slower than 2 km/h, then move the shield slowly up (increase self.shieldHeightOffset)
function LevelerController:updateShieldHeightOffset()
	--- A small reduction to the offset, as the shield should be lifted after a only a bit silage.
	local smallOffsetReduction = 0.3
	local fillLevelPercentage = self:getShieldFillLevelPercentage()
	self.shieldHeightOffset = MathUtil.clamp(fillLevelPercentage-smallOffsetReduction, 0, 1)
end

--- Is the shield full ?
---@return boolean shield is full
function LevelerController:isShieldFull()
	return self.implement:getFillUnitFreeCapacity(1) <= 0.01
end

--- Gets the shield fill level percentage.
---@return number fillLevelPercentage
function LevelerController:getShieldFillLevelPercentage()
	return self.implement:getFillUnitFillLevelPercentage(1)
end

--- Gets the target shield height, could be used for a possible LevelingAIDriver.
function LevelerController:getTargetShieldHeight()
	return 0
end

--- Overrides the player shield controls, while a cp driver is driving.
function LevelerController.actionEventAttacherJointControl(object, superFunc, ...)
	local rootVehicle = object:getRootVehicle()
	local job = rootVehicle:getJob()
	if job and job:isa(CpAIJobBunkerSilo) then 
		return
	end
	superFunc(object, ...)
end
AttacherJointControl.actionEventAttacherJointControl = Utils.overwrittenFunction(AttacherJointControl.actionEventAttacherJointControl, LevelerController.actionEventAttacherJointControl)
