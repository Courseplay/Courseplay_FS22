source(Courseplay.BASE_DIRECTORY .. "scripts/CpUtil.lua")

--- Create a polygon representing a field in Farming Simulator.
--- We put a probe (a node) on anywhere on the field, then start moving the probe to north until we
--- find the field edge. From that point on, we trace the edge clockwise around the field.
---
--- Finally, we simplify the resulting polygon by removing unneeded vertices.
--- TODO: island detection. Currently we don't know if we found the outer edge of the field or just an island.
---
---@class FieldScanner
FieldScanner = CpObject()

---@param resolution number the resolution of the scanner in meters (scan steps).
function FieldScanner:init(resolution)
    -- minimum practical resolution depends on how many meters a pixel in the density map really is, I'm not
    -- sure if it is 1 or 0.5, so 0.2 seems to be a safe bet
    self.resolution = resolution or 0.2
    self.highResolution = 0.01
    self.normalTracerLookahead = 1.0
    self.shortTracerLookahead = self.normalTracerLookahead / 20
    self.angleStep = self.highResolution / self.normalTracerLookahead
end

function FieldScanner:debug(...)
    -- temporarily just print
    print('FieldScanner: ' .. string.format(...))
end

function FieldScanner:isProbeOnField(node)
    local x, y, z = getWorldTranslation(node)
    local isOnField, _ = FSDensityMapUtil.getFieldDataAtWorldPosition(x, y, z)
    return isOnField
end

function FieldScanner:moveProbeForward(probe, d)
    local x, _, z = localToWorld(probe, 0, 0, d)
    self:setProbePosition(probe, x, z)
end

function FieldScanner:setProbePosition(probe, x, z)
    local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 0, z)
    setTranslation(probe, x, y, z)
end

function FieldScanner:rotateProbeBy(probe, angleStep)
    local _, yRot, _ = getRotation(probe)
    setRotation(probe, 0, yRot + angleStep, 0)
end

--- Rotate the probe until it aligns with the field edge
function FieldScanner:rotateProbeInFieldEdgeDirection(probe, tracerLookahead)
    local x, y, z = localToWorld(probe, 0, 0, tracerLookahead)
    local startOnField = FSDensityMapUtil.getFieldDataAtWorldPosition(x, y, z)
    -- rotate the probe and see if a point in front of us is still on the field or not.
    local a, isOnField, targetOnFieldState = 0, startOnField, not startOnField
    -- rotate probe clockwise
    while a < 2 * math.pi and isOnField ~= targetOnFieldState do
        x, y, z = localToWorld(probe, 0, 0, tracerLookahead)
        isOnField = FSDensityMapUtil.getFieldDataAtWorldPosition(x, y, z)
        self:rotateProbeBy(probe, (isOnField and 1 or -1) * self.angleStep)
        a = a + self.angleStep
    end
    local _, yRot, _ = getRotation(probe)
    return yRot
end

--- Move northwards in big steps until we pass the edge of the field, then
--- back up with small steps until we are back on the field.
--- At the end, we'll be very close to the field edge.
---@return boolean true if the edge was found
function FieldScanner:findFieldEdge(probe)
    local i = 0
    while i < 100000 and self:isProbeOnField(probe) do
        -- move probe forward
        self:moveProbeForward(probe, self.resolution)
        i = i + 1
    end
    while not self:isProbeOnField(probe) do
        self:moveProbeForward(probe, -self.highResolution)
    end
    local x, _, z = getWorldTranslation(probe)
    self:debug('Field edge found at %.1f/%.1f after %d steps', x, z, i)
end

function FieldScanner:traceFieldEdge(probe)
    self.points = {}
    local startX, _, startZ = getWorldTranslation(probe)
    local distanceFromStart = math.huge
    local tracerLookahead = self.normalTracerLookahead
    local prevYRot
    local totalYRot = 0
    local approachingCorner = false
    local i = 0
    -- limit the number of iterations, also, must be close to the start and have made almost a full circle (pi is just
    -- a half circle, but should be ok to protect us from edge cases like starting with a corner
    while i < 10000 and (i == 1 or distanceFromStart > tracerLookahead or math.abs(totalYRot) < math.pi) do
        local yRot = self:rotateProbeInFieldEdgeDirection(probe, tracerLookahead)
        -- how much we just turned?
        local deltaYRot = yRot - (prevYRot or yRot)
        if prevYRot and math.abs(deltaYRot) > math.rad(15) then
            local pX, pY, pZ = getWorldTranslation(probe)
            if approachingCorner then
                -- approaching the corner and there was a big rotation change so we just passed the corner
                tracerLookahead = self.normalTracerLookahead
                totalYRot = totalYRot + deltaYRot
                approachingCorner = false
                -- self:debug('Looks like just passed a corner at %.1f/%.1f (%d, %.1f°)', pX, pZ, i, math.deg(deltaYRot))
            else
                -- there is a big rotation change, a corner may be ahead,
                -- switch to shorter tracer length while approaching the corner
                tracerLookahead = self.normalTracerLookahead / 20
                approachingCorner = true
                -- rotate probe back to original direction
                setRotation(probe, 0, prevYRot, 0)
                yRot = prevYRot
                --self:debug('Approaching a corner at %.1f/%.1f (%d, %.1f°)', pX, pZ, i, math.deg(deltaYRot))
            end
        else
            self:moveProbeForward(probe, tracerLookahead)
            local pX, pY, pZ = getWorldTranslation(probe)
            table.insert(self.points, {x = pX, y = pY, z = pZ, yRot = yRot})
            distanceFromStart = MathUtil.getPointPointDistance(pX, pZ, startX, startZ)
            totalYRot = totalYRot + deltaYRot
        end
        -- more or less in the same direction, continue with the longer tracer beam
        prevYRot = yRot
        i = i + 1
    end
    self:debug('Field contour with %d points generated, total rotation %.1f°', #self.points, math.deg(totalYRot))
    -- a negative totalYRot means we went around the field clockwise, which we always should if we start in the
    -- middle of the field
    -- if it is positive, it means we bumped into an island and traced the island instead of the field
    return totalYRot < 0 and math.abs(totalYRot) > math.pi
end

--- Find the polygon representing a field. The point (x,z) must be on the field.
---@param x number
---@param z number
function FieldScanner:findContour(x, z)
    local probe = CpUtil.createNode('FieldScannerProbe', x, z, 0)
    if not self:isProbeOnField(probe) then
        self:debug('%.1f/%.1f is not on a field, can\'t start scanning here', x, z)
        return
    end
    self:debug('Start field scanning at %.1f/%.1f', x, z)
    local i = 1
    while i < 10 do
        self:findFieldEdge(probe)
        if self:traceFieldEdge(probe) then
            break
        else
            self:debug('Edge not, found we may have hit an island, reset/rotate the probe a bit and retry')
            self:setProbePosition(probe, x, z)
            setRotation(probe, 0, i * math.pi / 7, 0)
        end
        i = i + 1
    end
    self.points = self:simplifyPolygon(self.points, 0.75)
    self:debug('Field contour simplified, has now %d points', #self.points)
    self:sharpenCorners(self.points)
    for i, p in ipairs(self.points) do
        self:debug('%d %.1f/%.1f', i, p.x, p.z)
    end
    CpUtil.destroyNode(probe)
end

function FieldScanner:draw()
    if self.points then
        for i = 2, #self.points do
            local p, n = self.points[i - 1], self.points[i]
            DebugUtil.drawDebugLine(p.x, p.y + 1, p.z, n.x, n.y + 1, n.z, 0, 1, 0)
        end
    end
end

-- If two points are too close together (mostly at corners where we work with a high resolution),
-- replace the two points with a new one exactly between them
function FieldScanner:sharpenCorners(points)
    local prev = points[#points]
    local indicesToRemove = {}
    for i, p in ipairs(points) do
        local d = MathUtil.getPointPointDistance(p.x, p.z, prev.x, prev.z)
        if d < self.shortTracerLookahead then
            self:debug('There seems to be a corner at %i: %.1f, %.1f', i, p.x, p.z)
            table.insert(indicesToRemove, i)
            prev.x, prev.z = (p.x + prev.x) / 2, (p.z + prev.z) /2
        end
        prev = p
    end
    -- remove extra points, start from the end of the table so index of the point to be removed next won't change
    for i = #indicesToRemove, 1, -1  do
        table.remove(points, indicesToRemove[i])
    end
end

-- Distance of a point (px, pz) from a line starting between (sx, sz) and (ex, ez)GG
function FieldScanner:perpendicularDistance(px, pz, sx, sz, ex, ez)
    local dirX, dirZ = MathUtil.vector2Normalize(sx - ex, sz - ez)
    local x, z = MathUtil.projectOnLine(px, pz, sx, sz, dirX, dirZ)
    return MathUtil.getPointPointDistance(px, pz, x, z)
end

--- An implementation of the Ramer–Douglas–Peucker algorithm to smooth the non orthogonal field edges.
--- Due to the finite (I think 1 m) resolution of the density maps, our algorithm generates a zigzagged line if the
--- field edge is straight but not N-S or E-W direction.
function FieldScanner:simplifyPolygon(points, epsilon)
    -- Find the point with the maximum distance
    local dMax, index = 0, 0
    for i = 2, #points do
        local d = self:perpendicularDistance(points[i].x, points[i].z, points[1].x, points[1].z, points[#points].x, points[#points].z)
        if d > dMax then
            index = i
            dMax = d
        end
    end
    -- If max distance is greater than epsilon, recursively simplify
    if dMax > epsilon then
        local firstHalf = {}
        for i = 1, index do
            table.insert(firstHalf, points[i])
        end
        local result = self:simplifyPolygon(firstHalf, epsilon)
        local secondHalf = {}
        for i = index + 1, #points do
            table.insert(secondHalf, points[i])
        end
        local results2 = self:simplifyPolygon(secondHalf, epsilon)
        for _, p in ipairs(results2) do
            table.insert(result, p)
        end
        return result
    else
        return {points[1], points[#points]}
    end
end

g_fieldScanner = FieldScanner()