
--- Moves a new waypoint at the mouse position.
---@class CpBrushCurveInsertWP : CpBrush
CpBrushCurveInsertWP = {
	DELAY = 100,
	ERR_SELECT_MESSAGE_DURATION = 15 * 1000 -- 15 sec
}
local CpBrushMoveWP_mt = Class(CpBrushCurveInsertWP, CpBrush)
function CpBrushCurveInsertWP.new(customMt, cursor)
	local self =  CpBrush.new(customMt or CpBrushMoveWP_mt, cursor)
	self.supportsPrimaryButton = true
	self.supportsPrimaryDragging = true
	self.supportsSecondaryButton = true
	self.delay = g_time

	self.selectedFirstIx = nil
	self.selectedSecondIx = nil
	self.selectingErrorMsgTimer = CpTemporaryObject(false)
	return self
end

function CpBrushCurveInsertWP:onButtonPrimary(isDown, isDrag, isUp)
	if isDown and not isDrag then
		if self.delay <= g_time then 
			local ix = self:getHoveredWaypointIx()
			if ix then
				if self.courseWrapper:isWaypointTurn(ix) then 		
					if self.selectedFirstIx == nil or self.selectedSecondIx == nil then
						self.selectingErrorMsgTimer:set(true, self.ERR_SELECT_MESSAGE_DURATION)
					end
				else 
					self.selectingErrorMsgTimer:reset()
					if self.selectedFirstIx == nil then 
						self.selectedFirstIx = ix
						self.courseWrapper:setSelected(self.selectedFirstIx)
					elseif self.selectedSecondIx == nil and self.selectedFirstIx ~= ix then 
						self.selectedSecondIx = ix
						self.courseWrapper:setSelected(self.selectedSecondIx)
						if self.selectedSecondIx and self.selectedSecondIx < self.selectedFirstIx then 
							self.selectedFirstIx, self.selectedSecondIx = self.selectedSecondIx, self.selectedFirstIx
						end
					end
				end
			end
		end 
		self.delay = g_time + self.DELAY
	end
	if isDrag then 
		if self.delay <= g_time then 
			if self.selectedFirstIx and self.selectedSecondIx then 
				local x, _, z = self.cursor:getPosition()
				self.selectedSecondIx = self.courseWrapper:updateCurve(self.selectedFirstIx, self.selectedSecondIx, x, z)
				self.courseWrapper:resetSelected()
				self.courseWrapper:setSelected(self.selectedFirstIx)
				self.courseWrapper:setSelected(self.selectedSecondIx)
				self.editor:updateChanges(self.selectedFirstIx)
			end
		end
	end
	if isUp then
		
	end
end

function CpBrushCurveInsertWP:update(dt)
	CpBrushCurveInsertWP:superClass().update(self, dt)
	if self.selectingErrorMsgTimer:get() then
		self.cursor:setErrorMessage(self:getTranslation("err_turn"))
	end
end

function CpBrushCurveInsertWP:onButtonSecondary()
	self.courseWrapper:resetSelected()
	self.selectedFirstIx = nil
	self.selectedSecondIx = nil
	self.editor:updateChanges(1)
end

function CpBrushCurveInsertWP:deactivate()
	self.courseWrapper:resetSelected()
	self.editor:updateChanges(1)
end

function CpBrushCurveInsertWP:getButtonPrimaryText()
	return self:getTranslation(self.primaryButtonText)
end

function CpBrushCurveInsertWP:getButtonSecondaryText()
	return self:getTranslation(self.secondaryButtonText)
end
