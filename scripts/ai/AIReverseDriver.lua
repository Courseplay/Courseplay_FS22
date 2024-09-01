--[[
This file is part of Courseplay (https://github.com/Courseplay/courseplay)
Copyright (C) 2021 Satis, Peter Vaiko

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

The AIReverseDriver takes over the steering if there is a towed implement
or a trailer to be reversed.

We control the Giants vehicles by passing a goal point (in the vehicle's reference frame)
to the AIVehicleUtil.driveToPoint() function. The goal point is calculated by the
PurePursuitController and when driving forward or backward without a towed implement,
it can directly be used.

When driving backwards with a towed implement, we want the implement to follow the path
so the PurePursuitController uses a reference node on the implement to calculate a goal point
towards which the implement needs to be steered to stay on the path.

We can't use this goal point to directly control the tractor, we need to calculate a
'virtual' goal point for the tractor to be able to use AIVehicleUtil.driveToPoint().

This works by calculating the hitch angle (angle between the tractor and the trailer) that
would result in turning the implement towards the goal point. For the details, see the
papers referenced below.

]]--

---@class AIReverseDriver
AIReverseDriver = CpObject()

---@param ppc PurePursuitController
function AIReverseDriver:init(vehicle, ppc)
    self.vehicle = vehicle
    self.settings = vehicle:getCpSettings()
    ---@type PurePursuitController
    self.ppc = ppc
    -- the main implement (towed) or trailer we are controlling
    self.implement = AIUtil.getFirstReversingImplementWithWheels(self.vehicle)
    if self.implement then
        self.steeringLength = AIUtil.getTowBarLength(self.vehicle) or 3
        self:setImplementProperties(self.implement)
        self:setConstants()
        -- for articulated vehicles use the articulated axis' rotation node as it is a better indicator or the
        -- vehicle's orientation than the direction node which often turns/moves with an articulated vehicle part
        -- TODO: consolidate this with AITurn:getTurnNode() and if getAIDirectionNode() considers this already
        self.useArticulatedAxisRotationNode = SpecializationUtil.hasSpecialization(ArticulatedAxis, self.vehicle.specializations) and self.vehicle.spec_articulatedAxis.rotationNode
        if self.useArticulatedAxisRotationNode then
            self.tractorNode = self.vehicle.spec_articulatedAxis.rotationNode
        else
            self.tractorNode = self.vehicle:getAIDirectionNode()
        end
    else
        self:debug('No towed implement found.')
    end
    self:debug('AIReverseDriver created.')
end

function AIReverseDriver:debug(...)
    CpUtil.debugVehicle(CpDebug.DBG_REVERSE, self.vehicle, ...)
end

function AIReverseDriver:getDriveData()
    if self.implement == nil then
        -- no wheeled implement, simple reversing the PPC can handle by itself
        return nil
    end

    local trailerNode = self.implementProperties.node
    local trailerFrontNode = self.implementProperties.frontNode

    local tx, ty, tz = self.ppc:getGoalPointPosition()
    local lxTrailer, lzTrailer = AIVehicleUtil.getDriveDirection(trailerNode, tx, ty, tz)
    self:showDirection(trailerNode, lxTrailer, lzTrailer, 1, 0, 0)

    local maxTractorAngle = math.rad(75)

    local lx, lz, angleDiff

    if self.implementProperties.isPivot then
        -- The trailer/implement has a front axle (or dolly) with a draw bar.
        -- The current Courseplay dev team has no idea how this works :), this is magic
        -- from the old code, written by Satissis (Claus).
        -- TODO: adapt a documented algorithm for these trailers
        local xTrailer, yTrailer, zTrailer = getWorldTranslation(trailerNode);
        local xFrontNode, yFrontNode, zFrontNode = getWorldTranslation(trailerFrontNode)
        local lxFrontNode, lzFrontNode = AIVehicleUtil.getDriveDirection(trailerFrontNode, xTrailer, yTrailer, zTrailer)
        self:showDirection(trailerFrontNode, lxFrontNode, lzFrontNode, 0, 1, 0)

        local lxTractor, lzTractor = AIVehicleUtil.getDriveDirection(self.tractorNode, xFrontNode, yFrontNode, zFrontNode)
        self:showDirection(self.tractorNode, lxTractor, lzTractor, 0, 0.7, 0)

        local rotDelta = (self.implementProperties.nodeDistance *
                (0.5 - (0.023 * self.implementProperties.nodeDistance - 0.073)))
        local trailerToWaypointAngle = self:getLocalYRotationToPoint(trailerNode, tx, ty, tz, -1) * rotDelta
        trailerToWaypointAngle = MathUtil.clamp(trailerToWaypointAngle, -math.rad(90), math.rad(90))

        local dollyToTrailerAngle = self:getLocalYRotationToPoint(trailerFrontNode, xTrailer, yTrailer, zTrailer, -1)

        local tractorToDollyAngle = self:getLocalYRotationToPoint(self.tractorNode, xFrontNode, yFrontNode, zFrontNode, -1)

        local rearAngleDiff = (dollyToTrailerAngle - trailerToWaypointAngle)
        rearAngleDiff = MathUtil.clamp(rearAngleDiff, -math.rad(45), math.rad(45))

        local frontAngleDiff = (tractorToDollyAngle - dollyToTrailerAngle)
        frontAngleDiff = MathUtil.clamp(frontAngleDiff, -math.rad(45), math.rad(45))

        angleDiff = (frontAngleDiff - rearAngleDiff) *
                (1.5 - (self.implementProperties.nodeDistance * 0.4 - 0.9) + rotDelta)
        angleDiff = MathUtil.clamp(angleDiff, -math.rad(45), math.rad(45))

        lx, lz = MathUtil.getDirectionFromYRotation(angleDiff)
    else
        -- the trailer/implement is like a semi-trailer, has a rear axle only, the front of the implement
        -- is supported by the tractor
        local crossTrackError, orientationError, curvatureError, currentHitchAngle = self:calculateErrors(self.tractorNode, trailerNode)
        angleDiff = self:calculateHitchCorrectionAngle(crossTrackError, orientationError, curvatureError, currentHitchAngle)
        angleDiff = MathUtil.clamp(angleDiff, -maxTractorAngle, maxTractorAngle)

        lx, lz = MathUtil.getDirectionFromYRotation(angleDiff)
    end

    self:showDirection(self.tractorNode, lx, lz, 0.7, 0, 1)
    -- do a little bit of damping if using the articulated axis as lx tends to oscillate around 0 which results in the
    -- speed adjustment kicking in and slowing down the vehicle.
    if self.useArticulatedAxisRotationNode and math.abs(lx) < 0.04 then
        lx = 0
    end
    -- construct an artificial goal point to drive to
    lx, lz = -lx * self.ppc:getLookaheadDistance(), -lz * self.ppc:getLookaheadDistance()
    -- AIDriveStrategy wants a global position to drive to (which it later converts to local, but whatever...)
    local gx, _, gz = localToWorld(self.vehicle:getAIDirectionNode(), lx, 0, lz)
    return gx, gz, false, self.settings.reverseSpeed:getValue()
end

function AIReverseDriver:getLocalYRotationToPoint(node, x, y, z, direction)
    direction = direction or 1
    local dx, _, dz = worldToLocal(node, x, y, z)
    dx = dx * direction
    dz = dz * direction
    return MathUtil.getYRotationFromDirection(dx, dz)
end

function AIReverseDriver:showDirection(node, lx, lz, r, g, b)
    if CpDebug:isChannelActive(CpDebug.DBG_REVERSE, self.vehicle) then
        local x, y, z = getWorldTranslation(node)
        local tx, _, tz = localToWorld(node, lx * 5, y, lz * 5)
        DebugUtil.drawDebugLine(x, y + 5, z, tx, y + 5, tz, r or 1, g or 0, b or 0)
    end
end

--- Another Claus magic code to determine if the trailer has a front axle and find a node
--- for it to control.
---@param implement table implement.object
function AIReverseDriver:setImplementProperties(implement)
    if self.implementProperties and self.implementProperties.frontNode then
        return
    end
    self:debug('setImplementProperties for %s', CpUtil.getName(implement))

    self.implementProperties = {}

    -- if there's a reverser node on the tool, use that, otherwise the steering node
    -- the reverser direction node, if exists, works better for tools with offset or for
    -- rotating plows where it remains oriented and placed correctly
    self.implementProperties.node = AIVehicleUtil.getAIToolReverserDirectionNode(self.vehicle) or implement.steeringAxleNode
    
    local attacherVehicle = self.implement:getAttacherVehicle()

    if attacherVehicle == self.vehicle or ImplementUtil.isAttacherModule(attacherVehicle) then
        self.implementProperties.frontNode = ImplementUtil.getRealTrailerFrontNode(implement)
    else
        self.implementProperties.frontNode = ImplementUtil.getRealDollyFrontNode(attacherVehicle)
        if self.implementProperties.frontNode then
            self:debug('--> self.implement %s has dolly', CpUtil.getName(implement))
        else
            self:debug('--> self.implement %s has invalid dolly -> use implement own front node',
                    CpUtil.getName(implement))
            self.implementProperties.frontNode = ImplementUtil.getRealTrailerFrontNode(implement)
        end
    end

    self.implementProperties.nodeDistance = ImplementUtil.getRealTrailerDistanceToPivot(implement)
    self:debug("--> tz: %.1f real trailer distance to pivot: %s",
            self.implementProperties.nodeDistance, tostring(implement.steeringAxleNode))

    if implement.steeringAxleNode == self.implementProperties.frontNode then
        self:debug('--> implement.steeringAxleNode == self.implementProperties.frontNode')
        self.implementProperties.isPivot = false
    else
        self.implementProperties.isPivot = true
    end

    self:debug('--> isPivot=%s, frontNode=%s',
            tostring(self.implementProperties.isPivot), tostring(self.implementProperties.frontNode))
end

function AIReverseDriver:getNodeAngle(node)
    -- heading of the vehicle, looking backwards since we are reversing
    local dx, _, dz = localDirectionToWorld(node, 0, 0, -1)
    return MathUtil.getYRotationFromDirection(dx, dz)
end

function AIReverseDriver:setConstants()
    -- the following constants must be tuned based on experiments.
    -- base cross track error gain. 0.6-0.7 for longer implements, 0.5 for shorter ones, should be adjusted based on
    -- the steering length
    self.kXeBase = -0.5 - self.steeringLength / 50
    -- base orientation error gain
    self.kOeBase = 6
    -- base curvature error gain. 0 for now, as currently we only drive straight reverse
    self.kCeBase = 0
    self.maxHitchAngle = math.rad(35)
end

--- The reversing algorithm here is based on the papers:
---    Peter Ridley and Peter Corke. Load haul dump vehicle kinematics and control.
---        Journal of dynamic systems, measurement, and control, 125(1):54–59, 2003.
--- and
---    Amro Elhassan. Autonomous driving system for reversing an articulated vehicle, 2015
--- Calculate the path following errors (also called path disturbance inputs in the context of a controller)
function AIReverseDriver:calculateErrors(tractorNode, trailerNode)

    -- PPC already has the cross track error (lateral error)
    local crossTrackError = self.ppc:getCrossTrackError() --+ self.settings.toolOffsetX:getValue()

    -- Calculate the orientation error, the angle between the trailers current direction and
    -- the path direction
    local referencePathAngle = self.ppc:getCurrentWaypointYRotation()

    local trailerAngle = self:getNodeAngle(trailerNode)
    local tractorAngle = self:getNodeAngle(tractorNode)

    local orientationError = CpMathUtil.getDeltaAngle(trailerAngle, referencePathAngle)
    local currentHitchAngle = CpMathUtil.getDeltaAngle(tractorAngle, trailerAngle)

    -- The curvature (1/r) error is between the curvature of the path and the curvature of the tractor-trailer.
    -- This is really needed only when we are trying to follow a curved path in reverse
    local curvature = (2 * math.sin(currentHitchAngle / 2)) / calcDistanceFrom(tractorNode, trailerNode)
    local currentWp = self.ppc:getCurrentWaypoint()
    local curvatureError = currentWp.curvature - curvature

    return crossTrackError, orientationError, curvatureError, currentHitchAngle
end

--- Based on the current errors, calculate the required correction (in controller terms, use different gains for
--- different disturbances to calculate the controller's output, which in our case is just an angle the tractor
--- needs to drive to, in the tractor's local coordinate system.)
function AIReverseDriver:calculateHitchCorrectionAngle(crossTrackError, orientationError, curvatureError, currentHitchAngle)
    -- gain correction
    local gainCorrection = 1.5

    local hitchAngle = gainCorrection * (
            self.kXeBase * crossTrackError +
                    self.kOeBase * orientationError +
                    self.kCeBase * curvatureError
    )
    hitchAngle = MathUtil.clamp(hitchAngle, -self.maxHitchAngle, self.maxHitchAngle)

    local correctionAngle = -(hitchAngle - currentHitchAngle)

    if CpDebug:isChannelActive(CpDebug.DBG_REVERSE, self.vehicle) then
        local text = string.format('xte=%.1f oe=%.1f ce=%.1f current=%.1f reference=%.1f correction=%.1f',
                crossTrackError, math.deg(orientationError), curvatureError, math.deg(currentHitchAngle), math.deg(hitchAngle), math.deg(correctionAngle))
        setTextColor(1, 1, 0, 1)
        renderText(0.3, 0.3, 0.015, text)
    end

    return correctionAngle
end