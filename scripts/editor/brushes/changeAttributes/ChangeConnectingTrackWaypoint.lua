
--- Changes a new waypoint at the mouse position.
---@class CpBrushChangeConnectingTrackWP : CpBrush
CpBrushChangeConnectingTrackWP = {}
local CpBrushChangeWP_mt = Class(CpBrushChangeConnectingTrackWP, CpBrush)
function CpBrushChangeConnectingTrackWP.new(customMt, cursor)
	local self =  CpBrush.new(customMt or CpBrushChangeWP_mt, cursor)
	self.supportsPrimaryButton = true
	self.supportsPrimaryDragging = true
	self.supportsSecondaryButton = true
	self.supportsSecondaryDragging = true
	return self
end

function CpBrushChangeConnectingTrackWP:onButtonPrimary()
	local ix = self:getHoveredWaypointIx()
	if ix then 
		self.courseWrapper:setConnectingTrack(ix, true)
		self.editor:updateChangeSingle(ix)
	end
end

function CpBrushChangeConnectingTrackWP:onButtonSecondary()
	local ix = self:getHoveredWaypointIx()
	if ix then 
		self.courseWrapper:setConnectingTrack(ix, false)
		self.editor:updateChangeSingle(ix)
	end
end

function CpBrushChangeConnectingTrackWP:activate()
	self.courseWrapper:setConnectingTrackActive(true)
	self.editor:updateChanges(1)
end

function CpBrushChangeConnectingTrackWP:deactivate()
	self.courseWrapper:setConnectingTrackActive(false)
	self.editor:updateChanges(1)
end

function CpBrushChangeConnectingTrackWP:getButtonPrimaryText()
	return self:getTranslation(self.primaryButtonText)
end

function CpBrushChangeConnectingTrackWP:getButtonSecondaryText()
	return self:getTranslation(self.secondaryButtonText)
end
