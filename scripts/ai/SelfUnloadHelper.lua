--[[
This file is part of Courseplay (https://github.com/Courseplay/Courseplay_FS22)
Copyright (C) 2022 Peter Vaiko

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


--- Helper functions for finding a trailer around the field where a combine or an auger wagon can unload
---@class SelfUnloadHelper
SelfUnloadHelper = {}
SelfUnloadHelper.debugChannel = CpDebug.DBG_FIELDWORK
-- keep the helper nodes we create in this table for each vehicle so no nodes need to be created/destroyed
SelfUnloadHelper.bestFillNodes = {}

------ Find a trailer we can use for self unloading
function SelfUnloadHelper:findBestTrailer(fieldPolygon, myVehicle, fillType, pipeOffsetX)
    local bestTrailer, bestFillUnitIndex
    local minDistance = math.huge
    local maxCapacity = 0
    for _, otherVehicle in pairs(g_currentMission.vehicles) do
        if SpecializationUtil.hasSpecialization(Trailer, otherVehicle.specializations) then
            local rootVehicle = otherVehicle:getRootVehicle()
            local attacherVehicle
            if SpecializationUtil.hasSpecialization(Attachable, otherVehicle.specializations) then
                attacherVehicle = otherVehicle.spec_attachable:getAttacherVehicle()
            end
            local fieldNum = CpFieldUtil.getFieldNumUnderVehicle(otherVehicle)
            local myFieldNum = CpFieldUtil.getFieldNumUnderVehicle(myVehicle)
            local x, _, z = getWorldTranslation(otherVehicle.rootNode)
            local closestDistance = self:getClosestDistanceToFieldEdge(fieldPolygon, x, z)
            local lastSpeed = rootVehicle:getLastSpeed()
            local isCpActive = rootVehicle.getIsCpActive and rootVehicle:getIsCpActive()
            CpUtil.debugVehicle(self.debugChannel, myVehicle,
                    '%s is a trailer on field %d, closest distance to %d is %.1f, attached to %s, root vehicle is %s, last speed %.1f, CP active %s',
                    otherVehicle:getName(), fieldNum, myFieldNum, closestDistance, attacherVehicle and attacherVehicle:getName() or 'none', 
		            rootVehicle:getName(), lastSpeed, isCpActive)
            -- consider only trailer on my field or close to my field, not driven by CP and stopped
            if rootVehicle ~= myVehicle and not isCpActive and lastSpeed < 0.1 and
                    (fieldNum == myFieldNum or myFieldNum == 0 or closestDistance < 20)  then
                local d = calcDistanceFrom(myVehicle:getAIDirectionNode(), otherVehicle.rootNode or otherVehicle.nodeId)
                local canLoad, freeCapacity, fillUnitIndex = FillLevelManager.canLoadTrailer(otherVehicle, fillType)
                if d < minDistance and canLoad then
                    bestTrailer = otherVehicle
                    bestFillUnitIndex = fillUnitIndex
                    minDistance = d
                    maxCapacity = freeCapacity
                end
            end
        end
    end
    local fillRootNode
    if bestTrailer then
        fillRootNode = bestTrailer:getFillUnitExactFillRootNode(bestFillUnitIndex)
        CpUtil.debugVehicle(self.debugChannel, myVehicle, 
                'Best trailer is %s at %.1f meters, free capacity %d, root node %s', 
                bestTrailer:getName(), minDistance, maxCapacity, tostring(fillRootNode))
        local bestFillNode = self:findBestFillNode(myVehicle, fillRootNode, pipeOffsetX)
        return bestTrailer, bestFillNode
    else
        CpUtil.infoVehicle(myVehicle, 'Found no trailer to unload to.')
        return nil
    end
end

function SelfUnloadHelper:getClosestDistanceToFieldEdge(fieldPolygon, x, z)
    local closestDistance = math.huge
    for _, p in ipairs(fieldPolygon) do
        local d = MathUtil.getPointPointDistance(x, z, p.x, p.z)
        closestDistance = d < closestDistance and d or closestDistance
    end
    return closestDistance
end

function SelfUnloadHelper:findBestFillNode(myVehicle, fillRootNode, offset)
    local dx, dy, dz = localToLocal(fillRootNode, AIUtil.getDirectionNode(myVehicle), offset, 0, 0)
    local dLeft = MathUtil.vector3Length(dx, dy, dz)
    dx, dy, dz = localToLocal(fillRootNode, AIUtil.getDirectionNode(myVehicle), -offset, 0, 0)
    local dRight = MathUtil.vector3Length(dx, dy, dz)
    CpUtil.debugVehicle(self.debugChannel, myVehicle, 'Trailer left side distance %d, right side %d', dLeft, dRight)
    if dLeft <= dRight then
        -- left side of the trailer is closer, so turn the fillRootNode around as the combine must approach the
        -- trailer from the front of the trailer
        if not self.bestFillNodes[myVehicle] then
            self.bestFillNodes[myVehicle] = CpUtil.createNode('bestFillNode', 0, 0, math.pi, fillRootNode)
        else
            unlink(self.bestFillNodes[myVehicle])
            link(fillRootNode, self.bestFillNodes[myVehicle])
            setRotation(self.bestFillNodes[myVehicle], 0, math.pi, 0)
        end
        return self.bestFillNodes[myVehicle]
    else
        -- right side closer, combine approaches the trailer from the rear, driving the same direction as the getFillUnitExactFillRootNode
        return fillRootNode
    end
end

function SelfUnloadHelper:getTargetParameters(fieldPolygon, myVehicle, fillType, objectWithPipeAttributes)

    local bestTrailer, fillRootNode = SelfUnloadHelper:findBestTrailer(fieldPolygon, myVehicle, fillType,
            objectWithPipeAttributes.pipeOffsetX)

    if not bestTrailer then
        return nil
    end

    local targetNode = fillRootNode or bestTrailer.rootNode
    local trailerRootNode = bestTrailer.rootNode
    local trailerLength = bestTrailer.size.length
    local trailerWidth = bestTrailer.size.width

    local _, _, dZ = localToLocal(trailerRootNode, targetNode, 0, 0, 0)

    -- this should put the pipe's end 1.1 m from the trailer's edge towards the middle. We are not aiming for
    -- the centerline of the trailer to avoid bumping into very wide trailers, we don't want to get closer
    -- than what is absolutely necessary.
    local offsetX = math.abs(objectWithPipeAttributes.pipeOffsetX) + trailerWidth / 2 - 1.1
    offsetX = objectWithPipeAttributes.pipeOnLeftSide and -offsetX or offsetX
    -- arrive near the trailer alignLength meters behind the target, from there, continue straight a bit
    local _, steeringLength = AIUtil.getSteeringParameters(myVehicle)
    local alignLength = (trailerLength / 2) + dZ + math.max(myVehicle.size.length / 2, steeringLength)
    CpUtil.debugVehicle(CpDebug.DBG_FIELDWORK, myVehicle,
            'Trailer length: %.1f, width: %.1f, dZ: %.1f, align length %.1f, my length: %.1f, steering length %.1f, offsetX %.1f',
            trailerLength, trailerWidth, dZ, alignLength, myVehicle.size.length, steeringLength, offsetX)
    return targetNode, alignLength, offsetX
end
