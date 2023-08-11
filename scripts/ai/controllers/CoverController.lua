
---@class CoverController : ImplementController
CoverController = CpObject(ImplementController)
CoverController.COVER_STATE_UNKNOWN = 1
CoverController.COVER_STATE_OPEN = 2
CoverController.COVER_STATE_CLOSED = 3

function CoverController:init(vehicle, implement)
    ImplementController.init(self, vehicle, implement)
    self.coverSpec = self.implement.spec_cover
	self.coverState = self.COVER_STATE_UNKNOWN
end

function CoverController:isValid()
	return self.coverSpec.hasCovers
end

--- Gets the fill units for opening or closing of the trailer.
function CoverController:getFillUnits()
	if self.implement.getPipeDischargeNodeIndex then 
		local ix = self.implement:getPipeDischargeNodeIndex()
		local dischargeNode = self.implement:getDischargeNodeByIndex(ix)
		if dischargeNode then 
			return {dischargeNode.fillUnitIndex}
		end
	elseif self.implement.getAIDischargeNodes then
		local fillUnits = {}
		for _, dischargeNode in ipairs(self.implement:getAIDischargeNodes()) do
			table.insert(fillUnits, dischargeNode.fillUnitIndex)
		end
		return fillUnits
	end
	return {}
end

function CoverController:onStart()
	
end

function CoverController:onFinished()
	
end

function CoverController:openCover()
	if not self:isValid() then 
		return
	end
	self:debug("Opening covers")
	for _, fillUnitIndex in pairs(self:getFillUnits()) do 
		self.implement:aiPrepareLoading(fillUnitIndex)
	end
	self.coverState = self.COVER_STATE_OPEN
end

function CoverController:closeCover()
	if not self:isValid() then 
		return
	end
	self:debug("Closing covers")
	for _, fillUnitIndex in pairs(self:getFillUnits()) do 
		self.implement:aiFinishLoading(fillUnitIndex)
	end
	self.coverState = self.COVER_STATE_CLOSED
end

function CoverController:update(dt)
	if not self:isValid() then 
		return
	end
	--- Opens the cover, when the drive strategy allows it, otherwise keep the cover closed.
	if self.driveStrategy.isCoverOpeningAllowed then 
		if self.driveStrategy:isCoverOpeningAllowed() then 
			if self.coverState ~= self.COVER_STATE_OPEN then 
				self:openCover()
			end
		else 
			if self.coverState ~= self.COVER_STATE_CLOSED then 
				self:closeCover()
			end
		end
	end
end