--[[
This file is part of Courseplay (https://github.com/Courseplay/courseplay)
Copyright (C) 2021 Peter Vaiko

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

---
--- Implement utilities for the Courseplay AI

---@class ImplementUtil
ImplementUtil = {}

function ImplementUtil.isPartOfNode(node, parentNode)
    -- Check if Node is part of partOfNode and not in a different component
    while node ~= 0 and node ~= nil do
        if node == parentNode then
            return true
        else
            node = getParent(node)
        end
    end
    return false
end

--- ImplementUtil.findJointNodeConnectingToNode(workTool, fromNode, toNode, doReverse)
--	Returns: (node, backtrack, rotLimits)
--		node will return either:		1. The jointNode that connects to the toNode,
--										2. The toNode if no jointNode is found but the fromNode is inside the same component as the toNode
--										3. nil in case none of the above fails.
--		backTrack will return either:	1. A table of all the jointNodes found from fromNode to toNode, if the jointNode that connects to the toNode is found.
--										2: nil if no jointNode is found.
--		rotLimits will return either:	1. A table of all the rotLimits of the componentJoint, found from fromNode to toNode, if the jointNode that connects to the toNode is found.
--										2: nil if no jointNode is found.
function ImplementUtil.findJointNodeConnectingToNode(workTool, fromNode, toNode, doReverse)
    if fromNode == toNode then return toNode end

    -- Attempt to find the jointNode by backtracking the compomentJoints.
    for index, component in ipairs(workTool.components) do
        if ImplementUtil.isPartOfNode(fromNode, component.node) then
            if not doReverse then
                for _, joint in ipairs(workTool.componentJoints) do
                    if joint.componentIndices[2] == index then
                        if workTool.components[joint.componentIndices[1]].node == toNode then
                            --          node            backtrack         rotLimits
                            return joint.jointNode, {joint.jointNode}, {joint.rotLimit}
                        else
                            local node, backTrack, rotLimits = ImplementUtil.findJointNodeConnectingToNode(workTool, workTool.components[joint.componentIndices[1]].node, toNode)
                            if backTrack then table.insert(backTrack, 1, joint.jointNode) end
                            if rotLimits then table.insert(rotLimits, 1, joint.rotLimit) end
                            return node, backTrack, rotLimits
                        end
                    end
                end
            end

            -- Do Reverse in case not found
            for _, joint in ipairs(workTool.componentJoints) do
                if joint.componentIndices[1] == index then
                    if workTool.components[joint.componentIndices[2]].node == toNode then
                        --          node            backtrack         rotLimits
                        return joint.jointNode, {joint.jointNode}, {joint.rotLimit}
                    else
                        local node, backTrack, rotLimits = ImplementUtil.findJointNodeConnectingToNode(workTool, workTool.components[joint.componentIndices[2]].node, toNode, true)
                        if backTrack then table.insert(backTrack, 1, joint.jointNode) end
                        if rotLimits then table.insert(rotLimits, 1, joint.rotLimit) end
                        return node, backTrack, rotLimits
                    end
                end
            end
        end
    end

    -- Last attempt to find the jointNode by getting parent of parent untill hit or the there is no more parents.
    if ImplementUtil.isPartOfNode(fromNode, toNode) then
        return toNode, nil
    end

    -- If anything else fails, return nil
    return nil, nil
end



local allowedJointTypes = {}
---@param implement table implement object
function ImplementUtil.isWheeledImplement(implement)
    if #allowedJointTypes == 0 then
        local jointTypeList = {"implement", "trailer", "trailerLow", "semitrailer"}
        for _,jointType in ipairs(jointTypeList) do
            local index = AttacherJoints.jointTypeNameToInt[jointType]
            if index then
                table.insert(allowedJointTypes, index, true)
            end
        end
    end

    local activeInputAttacherJoint = implement:getActiveInputAttacherJoint()

    if activeInputAttacherJoint and allowedJointTypes[activeInputAttacherJoint.jointType] and
            implement.spec_wheels and implement.spec_wheels.wheels and #implement.spec_wheels.wheels > 0 then
        -- Attempt to find the pivot node.
        local node, _ = ImplementUtil.findJointNodeConnectingToNode(implement, activeInputAttacherJoint.rootNode, implement.rootNode)
        if node then
            -- Trailers
            if (activeInputAttacherJoint.jointType ~= AttacherJoints.JOINTTYPE_IMPLEMENT)
                    -- Implements with pivot and wheels that do not lift the wheels from the ground.
                    or (node ~= implement.rootNode and activeInputAttacherJoint.jointType == AttacherJoints.JOINTTYPE_IMPLEMENT and
                    (not activeInputAttacherJoint.topReferenceNode or true or
                    -- TODO_22
                            g_vehicleConfigurations:get(implement, 'implementWheelAlwaysOnGround')))
            then
                return true
            end
        end
    end
    return false
end

---@param implement table implement object
function ImplementUtil.getLastComponentNodeWithWheels(implement)
    -- Check if there is more than 1 component
    local wheels = implement:getWheels()
    if wheels and #wheels > 0 and #implement.components > 1 then
        -- Set default node to start from.
        local node = implement.rootNode

        -- Loop through all the components.
        for index, component in ipairs(implement.components) do
            -- Don't use the component that is the rootNode.
            if component.node ~= node then
                -- Loop through all the wheels and see if they are attached to this component.
                for i = 1, #wheels do
                    if AIUtil.isRealWheel(wheels[i]) then
                        if ImplementUtil.isPartOfNode(wheels[i].node, component.node) then
                            -- Check if they are linked together
                            for _, joint in ipairs(implement.componentJoints) do
                                if joint.componentIndices[2] == index then
                                    if implement.components[joint.componentIndices[1]].node == node then
                                        -- Check if the component is behind the node.
                                        local xJoint,yJoint,zJoint = getWorldTranslation(joint.jointNode)
                                        local offset,_,direction = worldToLocal(node, xJoint,yJoint,zJoint)
                                        --offset check to make sure we are selecting a node that is centered
                                        if direction < 0 and offset == 0 then
                                            -- Component is behind, so set the node to the new component node.
                                            node = component.node
                                        end
                                    end
                                end
                            end
                            break
                        end
                    end
                end
            end
        end

        -- Return the found node.
        return node
    end

    -- Return default rootNode if none is found.
    return implement.rootNode
end


---@param implement table implement object
function ImplementUtil.getRealTrailerFrontNode(implement)
    local activeInputAttacherJoint = implement:getActiveInputAttacherJoint()
    local jointNode, backtrack = 
        ImplementUtil.findJointNodeConnectingToNode(implement, activeInputAttacherJoint.rootNode, implement.rootNode)
    local realFrontNode
    if jointNode and backtrack and activeInputAttacherJoint.jointType ~= AttacherJoints.JOINTTYPE_IMPLEMENT then
        local rootNode
        for _, joint in ipairs(implement.componentJoints) do
            if joint.jointNode == jointNode and joint.rotLimit ~= nil and joint.rotLimit[2] ~= nil and joint.rotLimit[2] > rad(15) then
                rootNode = implement.components[joint.componentIndices[2]].node
                break
            end
        end

        if rootNode then
            realFrontNode = CpUtil.createNode("realFrontNode", 0, 0, 0, rootNode)
            local x, y, z = getWorldTranslation(jointNode)
            local _,_,delta = worldToLocal(rootNode, x, y, z)
            setTranslation(realFrontNode, 0, 0, delta)
        end
    end

    if not realFrontNode then
        realFrontNode = implement.steeringAxleNode
    end

    return realFrontNode
end

---@param implement table implement object
function ImplementUtil.isAttacherModule(implement)
    if implement.spec_attacherJoints.attacherJoint then
        local workToolsWheels = implement:getWheels()
        return (implement.spec_attacherJoints.attacherJoint.jointType == AttacherJoints.JOINTTYPE_SEMITRAILER and
                (not workToolsWheels or (workToolsWheels and #workToolsWheels == 0)))
    end
    return false
end

---@param dolly table implement object
function ImplementUtil.getRealDollyFrontNode(dolly)
    local frontNode
    local activeInputAttacherJoint = dolly:getActiveInputAttacherJoint()
    local node, _ = ImplementUtil.findJointNodeConnectingToNode(dolly, activeInputAttacherJoint.rootNode, dolly.rootNode)
    if node then
        -- Trailers without pivote
        if (node == dolly.rootNode and activeInputAttacherJoint.jointType ~= AttacherJoints.JOINTTYPE_IMPLEMENT)
                -- Implements with pivot and wheels that do not lift the wheels from the ground.
                or (node ~= dolly.rootNode and activeInputAttacherJoint.jointType == AttacherJoints.JOINTTYPE_IMPLEMENT and not activeInputAttacherJoint.topReferenceNode) then
            frontNode = dolly.steeringAxleNode
        else
            frontNode = nil
        end
    end

    return frontNode
end

---@param implement table implement object
function ImplementUtil.getRealTrailerDistanceToPivot(implement)
    -- Attempt to find the pivot node.
    local activeInputAttacherJoint = implement:getActiveInputAttacherJoint()
    local node, backTrack = ImplementUtil.findJointNodeConnectingToNode(implement, activeInputAttacherJoint.rootNode,
            ImplementUtil.getLastComponentNodeWithWheels(implement))
    if node then
        local x,y,z
        if node == implement.rootNode then
            x,y,z = getWorldTranslation(activeInputAttacherJoint.node)
        else
            x,y,z = getWorldTranslation(node)
        end
        local _,_,tz = worldToLocal(implement.steeringAxleNode, x,y,z)
        return tz
    else
        return 3
    end
end

function ImplementUtil.getDirectionNodeToTurnNodeLength(vehicle)

    local totalDistance = 0

    --- If this have not been set before after last stop command, we need to reset it again.
        local distances = vehicle.cp.distances

        for _, imp in ipairs(vehicle:getAttachedImplements()) do
            if AIUtil.isObjectAttachedOnTheBack(vehicle, imp.object) then
                local workTool = imp.object
                local activeInputAttacherJoint = workTool:getActiveInputAttacherJoint()
                if ImplementUtil.isWheeledWorkTool(workTool) then
                    local workToolDistances = workTool.cp.distances

                    if workToolDistances.attacherJointToPivot then
                        totalDistance = totalDistance + workToolDistances.attacherJointToPivot
                        ImplementUtil.debug(('getDirectionNodeToTurnNodeLength() -> %s: attacherJointToPivot=%.2fm'):format(
                                nameNum(workTool), workToolDistances.attacherJointToPivot), courseplay.DBG_IMPLEMENTS)
                    end

                    totalDistance = totalDistance + workToolDistances.attacherJointOrPivotToTurningNode
                    ImplementUtil.debug(('getDirectionNodeToTurnNodeLength() -> %s: attacherJointOrPivotToTurningNode=%.2fm'):format(
                            nameNum(workTool), workToolDistances.attacherJointOrPivotToTurningNode), courseplay.DBG_IMPLEMENTS)
                    ImplementUtil.debug(('getDirectionNodeToTurnNodeLength() -> %s: attacherJointToTurningNode=%.2fm'):format(
                            nameNum(workTool), totalDistance), courseplay.DBG_IMPLEMENTS)
                else
                    if not distances.attacherJointOrPivotToTurningNode and distances.attacherJointToRearTrailerAttacherJoints then
                        totalDistance = totalDistance + distances.attacherJointToRearTrailerAttacherJoints[activeInputAttacherJoint.jointType]
                    end
                    totalDistance = totalDistance + ImplementUtil.getDirectionNodeToTurnNodeLength(workTool)
                    --ImplementUtil.debug(('%s: directionNodeToTurnNodeLength=%.2fm'):format(nameNum(workTool), totalDistance), courseplay.DBG_IMPLEMENTS)
                end
                break
            end
        end

        if vehicle.cp.directionNode and totalDistance > 0 then
            for _, imp in ipairs(vehicle:getAttachedImplements()) do
                if ImplementUtil.isRearAttached(vehicle, imp.jointDescIndex) then
                    local workTool = imp.object
                    local activeInputAttacherJoint = workTool:getActiveInputAttacherJoint()
                    totalDistance = totalDistance + distances.turningNodeToRearTrailerAttacherJoints[activeInputAttacherJoint.jointType]
                    break
                end
            end
            vehicle.cp.directionNodeToTurnNodeLength = totalDistance
            ImplementUtil.debug(('getDirectionNodeToTurnNodeLength() -> %s: directionNodeToTurnNodeLength=%.2fm'):format(
                    nameNum(vehicle), totalDistance), courseplay.DBG_IMPLEMENTS)
        end

    return vehicle.cp.directionNodeToTurnNodeLength or totalDistance
end
