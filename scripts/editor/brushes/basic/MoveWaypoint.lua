
--- Moves a new waypoint at the mouse position.
---@class CpBrushMoveWP : CpBrush
CpBrushMoveWP = {
	DELAY = 100
}
local CpBrushMoveWP_mt = Class(CpBrushMoveWP, CpBrush)
function CpBrushMoveWP.new(customMt, cursor)
	local self =  CpBrush.new(customMt or CpBrushMoveWP_mt, cursor)
	self.supportsPrimaryButton = true
	self.supportsPrimaryDragging = true
	self.delay = g_time
	return self
end

function CpBrushMoveWP:onButtonPrimary(isDown, isDrag, isUp)
	if isDown and not isDrag then
		self.selectedIx = self:getHoveredWaypointIx()
	end
	if isDrag then 

		if self.selectedIx then 
			local x, _, z = self.cursor:getPosition()
			self.courseWrapper:setWaypointPosition(self.selectedIx, x, z )
			self.editor:updateChangesBetween(self.selectedIx, self.selectedIx)
		end
	end
	if isUp then
		self.selectedIx = nil
	end
end

function CpBrushMoveWP:getButtonPrimaryText()
	return self:getTranslation(self.primaryButtonText)
end
