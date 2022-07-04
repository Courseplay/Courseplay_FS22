
--- Changes a new waypoint at the mouse position.
---@class CpBrushChangeWP : CpBrush
CpBrushChangeWP = {
	TYPES = {
		NORMAL = 1,
		TURN_START = 2,
		TURN_END = 3
	},
}
CpBrushChangeWP.TYPES_TRANSLATIONS = {
	[CpBrushChangeWP.TYPES.NORMAL] = "type_normal",
	[CpBrushChangeWP.TYPES.TURN_START] = "type_turnStart",
	[CpBrushChangeWP.TYPES.TURN_END] = "type_turnEnd",
}

local CpBrushChangeWP_mt = Class(CpBrushChangeWP, CpBrush)
function CpBrushChangeWP.new(customMt, cursor)
	local self =  CpBrush.new(customMt or CpBrushChangeWP_mt, cursor)
	self.supportsPrimaryButton = true

	return self
end

function CpBrushChangeWP:onButtonPrimary()
	local ix = self:getHoveredWaypointIx()
	if ix then 
		self.courseWrapper:changeWaypointType(ix)
		self.editor:updateChangeSingle(ix)
	end
end

function CpBrushChangeWP:getButtonPrimaryText()
	local type = self.courseWrapper:getWaypointType(self.lastHoveredIx)
	return self:getTranslation(self.primaryButtonText, type~=nil and self:getTranslation(self.TYPES_TRANSLATIONS[type]))
end
