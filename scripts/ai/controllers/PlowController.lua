--- Controller for Plows
--- Implements the automatic side(x) Offset calculation.
---@class PlowController : ImplementController
PlowController = CpObject(ImplementController)

function PlowController:init(vehicle, implement)
    ImplementController.init(self, vehicle, implement)
    self.plowSpec = self.implement.spec_plow
end


function PlowController:getAutomaticXOffset()
	local aiLeftMarker, aiRightMarker, aiBackMarker = self.implement:getAIMarkers()
    if aiLeftMarker and aiBackMarker and aiRightMarker then
        local attacherJoint = self.implement:getActiveInputAttacherJoint()
        local referenceNode = attacherJoint and attacherJoint.node or self.vehicle:getAIDirectionNode()
        -- find out the left/right AI markers distance from the attacher joint (or, if does not exist, the
        -- vehicle's root node) to calculate the offset.
        self.plowReferenceNode = referenceNode
        local leftMarkerDistance, rightMarkerDistance = self:getOffsets(referenceNode, 
			aiLeftMarker, aiRightMarker)
        -- some plows rotate the markers with the plow, so swap left and right when needed
        -- so find out if the left is really on the left of the vehicle's root node or not
        local leftDx, _, _ = localToLocal(aiLeftMarker, self.vehicle:getAIDirectionNode(), 0, 0, 0)
        local rightDx, _, _ = localToLocal(aiRightMarker, self.vehicle:getAIDirectionNode(), 0, 0, 0)
        if leftDx < rightDx then
            -- left is positive x, so looks like the plow is inverted, swap left/right then
            leftMarkerDistance, rightMarkerDistance = -rightMarkerDistance, -leftMarkerDistance
        end
        local newToolOffsetX = -(leftMarkerDistance + rightMarkerDistance) / 2
        self:debug('Current Offset left = %.1f, right = %.1f, leftDx = %.1f, rightDx = %.1f, new = %.1f',
            leftMarkerDistance, rightMarkerDistance, leftDx, rightDx, newToolOffsetX)
		return newToolOffsetX
    end
	return 0
end

function PlowController:getOffsets(referenceNode, aiLeftMarker, aiRightMarker)
    local refX, _, refZ = getWorldTranslation(referenceNode)
    local lx, _, lz = getWorldTranslation(aiLeftMarker)
    local rx, _, rz = getWorldTranslation(aiRightMarker)
    local leftOffset = -self:getScalarProjection(lx - refX, lz - refZ, lx - rx, lz - rz)
    local rightOffset = self:getScalarProjection(rx - refX, rz - refZ, rx - lx, rz - lz)
    return leftOffset, rightOffset
end

--- Get scalar projection of vector v onto vector u
function PlowController:getScalarProjection(vx, vz, ux, uz)
    local dotProduct = vx * ux + vz * uz
    local length = math.sqrt(ux * ux + uz * uz)
    return dotProduct / length
end

--- Is the plow currently being rotated?
---@return boolean
function PlowController:isRotationActive()
	return self:isRotatablePlow() and self.implement:getIsAnimationPlaying(self.plowSpec.rotationPart.turnAnimation)
end

--- Can the plow be rotated?
function PlowController:isRotatablePlow()
    return self.plowSpec.rotationPart.turnAnimation ~= nil
end

function PlowController:getIsPlowRotationAllowed()
    return self.implement:getIsPlowRotationAllowed()
end

--- Rotates the plow if possible.
---@param shouldBeOnTheLeft boolean|nil
function PlowController:rotate(shouldBeOnTheLeft)
    if self:isRotatablePlow() and self:getIsPlowRotationAllowed() then
        self.implement:setRotationMax(shouldBeOnTheLeft)
    end
end