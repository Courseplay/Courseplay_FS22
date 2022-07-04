
--- Deletes a new waypoint at the mouse position.
---@class CpBrushDeleteWP : CpBrush
CpBrushDeleteWP = {}
local CpBrushDeleteWP_mt = Class(CpBrushDeleteWP, CpBrush)
function CpBrushDeleteWP.new(customMt, cursor)
	local self =  CpBrush.new(customMt or CpBrushDeleteWP_mt, cursor)
	self.supportsPrimaryButton = true
	self.supportsPrimaryDragging = true
	self.supportsSecondaryButton = true
	return self
end

function CpBrushDeleteWP:onButtonPrimary()
	local ix = self:getHoveredWaypointIx()
	if ix then 
		self.courseWrapper:deleteWaypoint(ix)
		self.courseWrapper:resetHovered()
		self.editor:updateChanges(ix)
	end
end

function CpBrushDeleteWP:onButtonSecondary()
	local ix = self:getHoveredWaypointIx()
	if ix then 
		self.courseWrapper:deleteWaypoint(ix)
		self.courseWrapper:resetHovered()
		self.editor:updateChanges(ix)
	end
end

function CpBrushDeleteWP:getButtonPrimaryText()
	return self:getTranslation(self.primaryButtonText)
end

function CpBrushDeleteWP:getButtonSecondaryText()
	return self:getTranslation(self.secondaryButtonText)
end