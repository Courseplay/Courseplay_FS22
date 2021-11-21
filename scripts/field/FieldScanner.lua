source(Courseplay.BASE_DIRECTORY .. "scripts/CpUtil.lua")

---@class FieldScanner
FieldScanner = CpObject()

---@param resolution number the resolution of the scanner in meters (scan steps).
function FieldScanner:init(resolution)
    -- minimum practical resolution depends on how many meters a pixel in the density map really is, I'm not
    -- sure if it is 1 or 0.5, so 0.2 seems to be a safe bet
    self.resolution = resolution or 0.2
    self.highResolution = 0.01
    self.edgeTracerBeamLength = 1
    self.angleStep = self.highResolution / self.edgeTracerBeamLength
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

function FieldScanner:rotateProbe(probe, angleStep)
    local _, yRot, _ = getRotation(probe)
    setRotation(probe, 0, yRot + angleStep, 0)
end

function FieldScanner:rotateProbeInFieldEdgeDirection(probe)
    local x, y, z = localToWorld(probe, 0, 0, self.edgeTracerBeamLength)
    local startOnField = FSDensityMapUtil.getFieldDataAtWorldPosition(x, y, z)
    -- rotate the probe and see if a point in front of us is still on the field or not.
    local a, isOnField, targetOnFieldState = 0, startOnField, not startOnField
    -- rotate probe clockwise
    while a < 2 * math.pi and isOnField ~= targetOnFieldState do
        x, y, z = localToWorld(probe, 0, 0, self.edgeTracerBeamLength)
        isOnField = FSDensityMapUtil.getFieldDataAtWorldPosition(x, y, z)
        self:rotateProbe(probe, (isOnField and 1 or -1) * self.angleStep)
        a = a + self.angleStep
    end
    local _, yRot, _ = getRotation(probe)
--    self:debug('edge direction %.1f degrees', math.deg(yRot))
    return yRot
end

function FieldScanner:findContour(x, z)
    self.points = {}
    local probe = CpUtil.createNode('FieldScannerProbe', x, z, 0)
    if not self:isProbeOnField(probe) then
        self:debug('%.1f/%.1f is not on a field, can\'t start scanning here', x, z)
        return
    end
    local i = 0
    while i < 100000 and self:isProbeOnField(probe) do
        -- move probe forward
        self:moveProbeForward(probe, self.resolution)
        i = i + 1
    end
    while not self:isProbeOnField(probe) do
        self:moveProbeForward(probe, -self.highResolution)
    end
    local startX, _, startZ = getWorldTranslation(probe)
    local distanceFromStart = math.huge
    self:debug('Field edge found at %.1f/%.1f after %d steps', startX, startZ, i)
    i = 0
    while i < 1000 and (i == 1 or distanceFromStart > self.edgeTracerBeamLength) do
        self:rotateProbeInFieldEdgeDirection(probe)
        self:moveProbeForward(probe, self.edgeTracerBeamLength)
        local pX, pY, pZ = getWorldTranslation(probe)
        table.insert(self.points, {x = pX, y = pY, z = pZ})
        distanceFromStart = MathUtil.getPointPointDistance(pX, pZ, startX, startZ)
        i = i + 1
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

g_fieldScanner = FieldScanner()