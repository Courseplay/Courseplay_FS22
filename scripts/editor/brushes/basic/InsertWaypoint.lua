
--- Inserts a new waypoint at the mouse position.
---@class CpBrushInsertWP : CpBrush
CpBrushInsertWP = {
	ERR_INSERT_MESSAGE_DURATION = 15 * 1000 -- 15 sec
}
local CpBrushInsertWP_mt = Class(CpBrushInsertWP, CpBrush)
function CpBrushInsertWP.new(customMt, cursor)
	local self =  CpBrush.new(customMt or CpBrushInsertWP_mt, cursor)
	self.supportsPrimaryButton = true
	self.supportsSecondaryButton = true
	self.insertErrorMsgTimer = CpTemporaryObject(false)
	return self
end

function CpBrushInsertWP:onButtonPrimary()
	local ix = self:getHoveredWaypointIx()
	if ix then 
		local wp, inserted = self.courseWrapper:insertWaypointBehind(ix)
		if inserted then 
			self.courseWrapper:resetHovered()
			self.editor:updateChanges(1)
			self.insertErrorMsgTimer:reset()
		else
			self.insertErrorMsgTimer:set(true, self.ERR_INSERT_MESSAGE_DURATION)
		end
	end
end

function CpBrushInsertWP:onButtonSecondary()
	local ix = self:getHoveredWaypointIx()
	if ix then 
		local wp, inserted = self.courseWrapper:insertWaypointAhead(ix)
		if inserted then 
			self.editor:updateChanges(1)
			self.insertErrorMsgTimer:reset()
		else
			self.insertErrorMsgTimer:set(true, self.ERR_INSERT_MESSAGE_DURATION)
		end
	end
end

function CpBrushInsertWP:update(dt)
	CpBrushInsertWP:superClass().update(self, dt)
	if self.insertErrorMsgTimer:get() then
		self.cursor:setErrorMessage(self:getTranslation("err_turn"))
	end
end

function CpBrushInsertWP:getButtonPrimaryText()
	return self:getTranslation(self.primaryButtonText)
end

function CpBrushInsertWP:getButtonSecondaryText()
	return self:getTranslation(self.secondaryButtonText)
end
