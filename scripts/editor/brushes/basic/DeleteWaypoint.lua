
--- Deletes a new waypoint at the mouse position.
---@class CpBrushDeleteWP : CpBrush
CpBrushDeleteWP = {
	ERR_DELETE_MESSAGE_DURATION = 30 * 1000 -- 30sec
}
local CpBrushDeleteWP_mt = Class(CpBrushDeleteWP, CpBrush)
function CpBrushDeleteWP.new(customMt, cursor)
	local self =  CpBrush.new(customMt or CpBrushDeleteWP_mt, cursor)
	self.supportsPrimaryButton = true
	self.supportsPrimaryDragging = true
	self.supportsSecondaryButton = true
	self.deleteErrorMsgTimer = CpTemporaryObject(false)
	return self
end

function CpBrushDeleteWP:onButtonPrimary()
	local ix = self:getHoveredWaypointIx()
	if ix then 
		if not self.courseWrapper:deleteWaypoint(ix) then 
			self.deleteErrorMsgTimer:set(true, self.ERR_DELETE_MESSAGE_DURATION)
		end
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

function CpBrushDeleteWP:update(dt)
	CpBrushDeleteWP:superClass().update(self, dt)
	if self.deleteErrorMsgTimer:get() then
		self.cursor:setErrorMessage(self:getTranslation("err_to_few_waypoints"))
	end
end

function CpBrushDeleteWP:getButtonPrimaryText()
	return self:getTranslation(self.primaryButtonText)
end

function CpBrushDeleteWP:getButtonSecondaryText()
	return self:getTranslation(self.secondaryButtonText)
end