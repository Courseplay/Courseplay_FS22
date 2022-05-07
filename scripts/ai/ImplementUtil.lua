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
    if fromNode == toNode then
        return toNode
    end

    -- Attempt to find the jointNode by backtracking the compomentJoints.
    for index, component in ipairs(workTool.components) do
        if ImplementUtil.isPartOfNode(fromNode, component.node) then
            if not doReverse then
                for _, joint in ipairs(workTool.componentJoints) do
                    if joint.componentIndices[2] == index then
                        if workTool.components[joint.componentIndices[1]].node == toNode then
                            --          node            backtrack         rotLimits
                            return joint.jointNode, { joint.jointNode }, { joint.rotLimit }
                        else
                            local node, backTrack, rotLimits = ImplementUtil.findJointNodeConnectingToNode(workTool, workTool.components[joint.componentIndices[1]].node, toNode)
                            if backTrack then
                                table.insert(backTrack, 1, joint.jointNode)
                            end
                            if rotLimits then
                                table.insert(rotLimits, 1, joint.rotLimit)
                            end
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
                        return joint.jointNode, { joint.jointNode }, { joint.rotLimit }
                    else
                        local node, backTrack, rotLimits = ImplementUtil.findJointNodeConnectingToNode(workTool, workTool.components[joint.componentIndices[2]].node, toNode, true)
                        if backTrack then
                            table.insert(backTrack, 1, joint.jointNode)
                        end
                        if rotLimits then
                            table.insert(rotLimits, 1, joint.rotLimit)
                        end
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
        local jointTypeList = { "implement", "trailer", "trailerLow", "semitrailer" }
        for _, jointType in ipairs(jointTypeList) do
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
                    (not activeInputAttacherJoint.topReferenceNode or
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
                                        local xJoint, yJoint, zJoint = getWorldTranslation(joint.jointNode)
                                        local offset, _, direction = worldToLocal(node, xJoint, yJoint, zJoint)
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
    local jointNode, backtrack = ImplementUtil.findJointNodeConnectingToNode(implement, activeInputAttacherJoint.rootNode, implement.rootNode)
    local realFrontNode
    if jointNode and backtrack and activeInputAttacherJoint.jointType ~= AttacherJoints.JOINTTYPE_IMPLEMENT then
        local rootNode
        for _, joint in ipairs(implement.componentJoints) do
            if joint.jointNode == jointNode and joint.rotLimit ~= nil and joint.rotLimit[2] ~= nil and joint.rotLimit[2] > math.rad(15) then
                rootNode = implement.components[joint.componentIndices[2]].node
                break
            end
        end

        if rootNode then
            realFrontNode = CpUtil.createNode("realFrontNode", 0, 0, 0, rootNode)
            local x, y, z = getWorldTranslation(jointNode)
            local _, _, delta = worldToLocal(rootNode, x, y, z)
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
        local x, y, z
        if node == implement.rootNode then
            x, y, z = getWorldTranslation(activeInputAttacherJoint.node)
        else
            x, y, z = getWorldTranslation(node)
        end
        local _, _, tz = worldToLocal(implement.steeringAxleNode, x, y, z)
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
            if ImplementUtil.isWheeledImplement(workTool) then
                local workToolDistances = workTool.cp.distances

                if workToolDistances.attacherJointToPivot then
                    totalDistance = totalDistance + workToolDistances.attacherJointToPivot
                    ImplementUtil.debug(('getDirectionNodeToTurnNodeLength() -> %s: attacherJointToPivot=%.2fm'):format(
                            nameNum(workTool), workToolDistances.attacherJointToPivot), CpDebug.DBG_IMPLEMENTS)
                end

                totalDistance = totalDistance + workToolDistances.attacherJointOrPivotToTurningNode
                ImplementUtil.debug(('getDirectionNodeToTurnNodeLength() -> %s: attacherJointOrPivotToTurningNode=%.2fm'):format(
                        nameNum(workTool), workToolDistances.attacherJointOrPivotToTurningNode), CpDebug.DBG_IMPLEMENTS)
                ImplementUtil.debug(('getDirectionNodeToTurnNodeLength() -> %s: attacherJointToTurningNode=%.2fm'):format(
                        nameNum(workTool), totalDistance), CpDebug.DBG_IMPLEMENTS)
            else
                if not distances.attacherJointOrPivotToTurningNode and distances.attacherJointToRearTrailerAttacherJoints then
                    totalDistance = totalDistance + distances.attacherJointToRearTrailerAttacherJoints[activeInputAttacherJoint.jointType]
                end
                totalDistance = totalDistance + ImplementUtil.getDirectionNodeToTurnNodeLength(workTool)
                --ImplementUtil.debug(('%s: directionNodeToTurnNodeLength=%.2fm'):format(nameNum(workTool), totalDistance), CpDebug.DBG_IMPLEMENTS)
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
                nameNum(vehicle), totalDistance), CpDebug.DBG_IMPLEMENTS)
    end

    return vehicle.cp.directionNodeToTurnNodeLength or totalDistance
end

--- Get the distance between a reference node (usually tractor's direction node) and a node on the implement,
--- considering that the implement may not be aligned with the tractor so a simple localToLocal between the
--- tractor's node and the implement node would result in errors.
---
--- Therefore, determine the distance in two steps:
--- 1. distance between the reference node and the attacher joint of the implement
--- 2. distance between the attacher joint and the implement node
---
---@param referenceNode number node, usually the tractor's direction node
---@param implementObject table implement object
---@param implementNode number node on the implement we want to know the distance of
function ImplementUtil.getDistanceToImplementNode(referenceNode, implementObject, implementNode)
    local rootToReferenceNodeOffset = 0
    local attacherJoint = implementObject.getActiveInputAttacherJoint and implementObject:getActiveInputAttacherJoint()
    if attacherJoint and attacherJoint.node then
        -- the implement may not be aligned with the vehicle so we need to calculate this distance in two
        -- steps, first the distance between the vehicle's root node and the attacher joint and then
        -- from the attacher joint to the implement's root node
        -- < 0 when the attacher joint is behind the reference node
        local _, _, referenceToAttacherJoint = localToLocal(attacherJoint.node, referenceNode, 0, 0, 0)
        -- > 0 when the attacher node is in front of the implement's root node (we don't use the attacher joint node
        -- as a reference as it may point to any direction, we know the implement's root node points forward
        local _, _, attacherJointToImplementRoot = localToLocal(attacherJoint.node, implementNode, 0, 0, 0)
        -- we call this offset, and is negative when behind the reference node, positive when in front of it
        -- (need to reverse attacherJointToImplementRoot)
        rootToReferenceNodeOffset = -attacherJointToImplementRoot + referenceToAttacherJoint
        CpUtil.debugFormat(CpDebug.DBG_IMPLEMENTS, '%s: ref to attacher joint %.1f, att to implement root %.1f, impl root to ref %.1f',
                implementObject:getName(), referenceToAttacherJoint, attacherJointToImplementRoot, rootToReferenceNodeOffset)
    else
        _, _, rootToReferenceNodeOffset = localToLocal(implementNode, referenceNode, 0, 0, 0)
    end
    return rootToReferenceNodeOffset
end

-- Bale loaders / wrappers have no AI markers
function ImplementUtil.getAIMarkersFromGrabberNode(object, spec)
    -- use the grabber node for all markers if exists
    if spec.baleGrabber and spec.baleGrabber.grabNode then
        return spec.baleGrabber.grabNode, spec.baleGrabber.grabNode, spec.baleGrabber.grabNode
    else
        return object.rootNode, object.rootNode, object.rootNode
    end
end

--- Is the vehicle/implement a Chopper 
function ImplementUtil.isChopper(implement)
    local spec = implement and implement.spec_combine
    return spec and implement:getFillUnitCapacity(spec.fillUnitIndex) > 10000000
end

--- Find the object to use as the combine
function ImplementUtil.findCombineObject(vehicle)
    local combine
    if vehicle.spec_combine then
        combine = vehicle.spec_combine
    else
        local combineImplement = AIUtil.getImplementWithSpecialization(vehicle, Combine)
        local peletizerImplement = FS19_addon_strawHarvest and
                AIUtil.getAIImplementWithSpecialization(vehicle, FS19_addon_strawHarvest.StrawHarvestPelletizer) or nil
        if combineImplement then
            combine = combineImplement.spec_combine
        elseif peletizerImplement then
            combine = peletizerImplement
            combine.fillUnitIndex = 1
            combine.spec_aiImplement.rightMarker = combine.rootNode
            combine.spec_aiImplement.leftMarker = combine.rootNode
            combine.spec_aiImplement.backMarker = combine.rootNode
            combine.isPremos = true --- This is needed as there is some logic in the CombineUnloadManager for it.
        else
            CpUtil.infoVehicle(vehicle, 'Vehicle is not a combine and could not find implement with spec_combine')
        end
    end
    return combine
end

--- Set all pipe related attributes on object for a vehicle:
--- pipe, objectWithPipe, pipeOnLeftSide, pipeOffsetX, pipeOffsetZ
---@param object table object we want to decorate with these attributes
---@param vehicle table
---@param combine table combine object, see ImplementUtil.findCombineObject()
function ImplementUtil.setPipeAttributes(object, vehicle, combine)
    if vehicle.spec_pipe then
        object.pipe = vehicle.spec_pipe
        object.objectWithPipe = vehicle
    else
        local implementWithPipe = AIUtil.getImplementWithSpecialization(vehicle, Pipe)
        if implementWithPipe then
            object.pipe = implementWithPipe.spec_pipe
            object.objectWithPipe = implementWithPipe
        else
            CpUtil.infoVehicle(vehicle, 'Could not find implement with pipe')
        end
    end

    if object.pipe then
        -- check the pipe length:
        -- unfold everything, open the pipe, check the side offset, then close pipe, fold everything back (if it was folded)
        local wasFolded, wasClosed
        wasFolded = ImplementUtil.unfoldForGettingWidth(vehicle)
        if object.pipe.currentState == AIUtil.PIPE_STATE_CLOSED then
            wasClosed = true
            if object.pipe.animation.name then
                object.pipe:setAnimationTime(object.pipe.animation.name, 1, true)
            else
                -- as seen in the Giants pipe code
                object.objectWithPipe:setPipeState(AIUtil.PIPE_STATE_OPEN, true)
                object.objectWithPipe:updatePipeNodes(999999, nil)
                -- this second call magically unfolds the sugarbeet harvesters, ask Stefan Maurus why :)
                object.objectWithPipe:updatePipeNodes(999999, nil)
            end
        end
        local dischargeNode = combine:getCurrentDischargeNode()
        local dx, _, _ = localToLocal(dischargeNode.node, combine.rootNode, 0, 0, 0)
        object.pipeOnLeftSide = dx >= 0
        CpUtil.debugVehicle(CpDebug.DBG_IMPLEMENTS, vehicle, 'Pipe on left side %s', tostring(object.pipeOnLeftSide))
        -- use combine so attached harvesters have the offset relative to the harvester's root node
        -- (and thus, does not depend on the angle between the tractor and the harvester)
        object.pipeOffsetX, _, object.pipeOffsetZ = localToLocal(dischargeNode.node, combine.rootNode, 0, 0, 0)
        CpUtil.debugVehicle(CpDebug.DBG_IMPLEMENTS, vehicle, 'Pipe offset: x = %.1f, z = %.1f',
                object.pipeOffsetX, object.pipeOffsetZ)
        if wasClosed then
            if object.pipe.animation.name then
                object.pipe:setAnimationTime(object.pipe.animation.name, 0, true)
            else
                object.objectWithPipe:setPipeState(AIUtil.PIPE_STATE_CLOSED, true)
                object.objectWithPipe:updatePipeNodes(999999, nil)
                -- this second call magically unfolds the sugarbeet harvesters, ask Stefan Maurus why :)
                object.objectWithPipe:updatePipeNodes(999999, nil)
            end
        end
        if wasFolded then
            ImplementUtil.foldAfterGettingWidth(vehicle)
            -- fold and unfold quickly, if we don't do that, the implement start event won't unfold the combine pipe
            -- zero idea why, it worked before https://github.com/Courseplay/Courseplay_FS22/pull/453
            Foldable.actionControllerFoldEvent(vehicle, -1)
            Foldable.actionControllerFoldEvent(vehicle, 1)
        end
    else
        -- make sure pipe offset has a value until CombineUnloadManager as cleaned up as it calls getPipeOffset()
        -- periodically even when CP isn't driving, and even for cotton harvesters...
        object.pipeOffsetX, object.pipeOffsetZ = 0, 0
        object.pipeOnLeftSide = true
    end
end

--- Unfold object so we can get measurements (width, pipe length, etc.)
---@return boolean true when object had to be unfolded
function ImplementUtil.unfoldForGettingWidth(object)
    if object.spec_foldable then
        local wasFolded = not object.spec_foldable:getIsUnfolded()
        if wasFolded then
            CpUtil.debugVehicle(CpDebug.DBG_IMPLEMENTS, object, "unfolding to get width.")
            Foldable.setAnimTime(object.spec_foldable, object.spec_foldable.startAnimTime == 1 and 0 or 1, true)
            return true
        end
    end
    return false
end

function ImplementUtil.foldAfterGettingWidth(object)
    if object.spec_foldable then
        Foldable.setAnimTime(object.spec_foldable, object.spec_foldable.startAnimTime == 1 and 1 or 0, true)
    end
end