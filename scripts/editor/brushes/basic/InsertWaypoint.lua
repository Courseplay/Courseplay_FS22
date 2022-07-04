
--- Inserts a new waypoint at the mouse position.
---@class CpBrushInsertWP : CpBrush
CpBrushInsertWP = {}
local CpBrushInsertWP_mt = Class(CpBrushInsertWP, CpBrush)
function CpBrushInsertWP.new(customMt, cursor)
	local self =  CpBrush.new(customMt or CpBrushInsertWP_mt, cursor)
	self.supportsPrimaryButton = true
	self.supportsSecondaryButton = true
	return self
end

function CpBrushInsertWP:onButtonPrimary()
	local ix = self:getHoveredWaypointIx()
	if ix then 
		self.courseWrapper:insertWaypointAhead(ix)
		self.courseWrapper:resetHovered()
		self.editor:updateChanges(1)
	end
end

function CpBrushInsertWP:onButtonSecondary()
	local ix = self:getHoveredWaypointIx()
	if ix then 
		self.courseWrapper:insertWaypointBehind(ix)
		self.editor:updateChanges(1)
	end
end

function CpBrushInsertWP:getButtonPrimaryText()
	return self:getTranslation(self.primaryButtonText)
end

function CpBrushInsertWP:getButtonPrimaryText()
	return self:getTranslation(self.secondaryButtonText)
end
