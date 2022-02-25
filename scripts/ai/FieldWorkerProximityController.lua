--- The purpose of the FieldWorkerProximityController is to make sure a vehicle operating on
--- a field does not bump into another vehicle working on the same field, using the same
--- field work course.
FieldWorkerProximityController = CpObject()

-- How many meters between the points of the trail
FieldWorkerProximityController.trailSpacing = 5
-- Other vehicles are considered as long as their direction is within sameDirectionLimit (radians)
-- of the own vehicle
FieldWorkerProximityController.sameDirectionLimit = math.rad(45)
-- Other vehicles are considered only as long as the lateral distance to them is less than
-- lateralDistanceLimit * working width
FieldWorkerProximityController.lateralDistanceLimit = 1.1

function FieldWorkerProximityController:init(vehicle, workingWidth)
    self.vehicle = vehicle
    self.workingWidth = workingWidth
    self.fieldWorkCourse = self.vehicle:getFieldWorkCourse()
    ---@type Waypoint[]
    self.trail = {}
end

function FieldWorkerProximityController:debug(...)
    CpUtil.debugVehicle(CpDebug.DBG_TRAFFIC, self.vehicle, 'FieldWorkerProximityController: '.. string.format(...))
end

function FieldWorkerProximityController:debugSparse(...)
    -- since we are not called on every loop (maybe every 4th) use a prime number which should
    -- make sure that we are called once in a while
    if g_updateLoopIndex % 19 == 0 then
        self:debug(...)
    end
end

function FieldWorkerProximityController:info(...)
    CpUtil.infoVehicle(self.vehicle, ...)
end

function FieldWorkerProximityController:draw()
    if CpDebug:isChannelActive(CpDebug.DBG_TRAFFIC, self.vehicle) then
        for i, p in ipairs(self.trail) do
            local x, y, z = p:getPosition()
            Utils.renderTextAtWorldPosition(x, y + 2.2, z,
                    string.format('%d', self:getDistanceAtIx(i)), getCorrectTextSize(0.012), 0)
            DebugUtil.drawDebugLine(x, y + 1.5, z, x, y + 2, z, 0, 0, 1)
        end
    end
end

--- Distance of the ix-th trail point from the vehicle
function FieldWorkerProximityController:getDistanceAtIx(ix)
    return (#self.trail - ix) * self.trailSpacing
end

function FieldWorkerProximityController:hasSameCourse(otherVehicle)
    local otherCourse = otherVehicle.getFieldWorkCourse and otherVehicle:getFieldWorkCourse()
    return otherCourse and
            otherCourse:getName() == self.fieldWorkCourse:getName() and
            otherCourse:getMultiTools() == self.fieldWorkCourse:getMultiTools()
end

--- Each vehicle leaves a trail consisting of its past positions in regular intervals
---@param maxLength number maximum length of the trail
function FieldWorkerProximityController:updateTrail(maxLength)
    local x, y, z = getWorldTranslation(self.vehicle.rootNode)
    local dTraveled = #self.trail > 0 and self.trail[#self.trail]:getDistanceFromPoint(x, z) or self.trailSpacing
    if dTraveled < self.trailSpacing then return end
    -- time to record a new point
    local _, yRot, _ = getWorldRotation(self.vehicle.rootNode)
    table.insert(self.trail, Waypoint({x = x, y = y, z = z, yRot = yRot}))
    self:debug('Recorded new trail point (%d)', #self.trail)
    local numberOfPoints = math.floor(maxLength / self.trailSpacing)
    if #self.trail > numberOfPoints then
        table.remove(self.trail, 1)
    end
end

--- How far is node behind us? We use our trail to figure this distance out, node is in our proximity if it
--- is anywhere within lateralDistanceLimit * workWidth our trail, provided the trail point direction is more or less the node's
--- direction.
function FieldWorkerProximityController:getFieldWorkProximity(node)
    local distance = math.huge
    local trailLength = #self.trail * self.trailSpacing
    for i = #self.trail, 1, -1 do
        local p = self.trail[i]
        local dx, _, dz = worldToLocal(node, p.x, p.y, p.z)
        local _, yRot, _ = getWorldRotation(node)
        -- we only check along the trail, in front of us, so dz > 0 but less than the length of the trail
        -- also, it is in the adjacent row, so dx is limited by the working width
        -- and finally, it needs to point into the same direction (approximately) to filter out a trail in
        -- the opposite direction
        --self:debug('%d: %.1f %.1f/%.1f %.1f (%.1f)', i, distance, dx, dz, math.deg(yRot - p.yRot), trailLength)
        if dz < trailLength and dz > 0 and math.abs(dx) < self.lateralDistanceLimit * self.workingWidth and
                math.abs(yRot - p.yRot) < self.sameDirectionLimit then
            distance = math.min(distance,  self:getDistanceAtIx(i) + dz)
            --self:debug('   %.1f', self:getDistanceAtIx(i) + dz)
        end
    end
    return distance
end

function FieldWorkerProximityController:getMaxSpeed(distanceLimit, currentMaxSpeed)
    -- update my own trail
    self:updateTrail(distanceLimit)

    for _, otherVehicle in pairs(g_currentMission.vehicles) do
        if otherVehicle ~= self.vehicle and self:hasSameCourse(otherVehicle) and
                otherVehicle.getIsCpFieldWorkActive and otherVehicle:getIsCpFieldWorkActive() then
            local otherStrategy = otherVehicle:getCpDriveStrategy()
            local otherIsDone = otherStrategy:isDone()
            if not otherIsDone then
                local distanceFromOther = otherStrategy:getFieldWorkProximity(self.vehicle.rootNode)
                self:debugSparse('have same course as %s (done = %s), distance %.1f', CpUtil.getName(otherVehicle), otherIsDone, distanceFromOther)
                if distanceFromOther > 0 and distanceFromOther < distanceLimit then
                    self:debugSparse('too close (%.1f m < %.1f) to %s in front of me, slowing down.',
                            distanceFromOther, distanceLimit, CpUtil.getName(otherVehicle))
                    -- the closer we are, the slower we drive, but stop at half the minDistance
                    local maxSpeed = currentMaxSpeed *
                            math.max(0, 2 * (1 - (distanceLimit - distanceFromOther + distanceLimit / 2) / distanceLimit))
                    -- everything low enough should be 0 so it does not trigger the Giants didNotMoveTimer (which is disabled
                    -- only when the maxSpeed we return in getDriveData is exactly 0
                    return maxSpeed > 1 and maxSpeed or 0
                end
            end
        end
    end
    return math.huge
end