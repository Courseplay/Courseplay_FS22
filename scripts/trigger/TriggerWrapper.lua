
--- Wrapper for a trigger. 
---@class CpTrigger
CpTrigger = CpObject()

function CpTrigger:init(trigger, node)
	self.trigger = trigger
	self.node = node
	self.plot = UnloadingTriggerPlot(self.node)
end

function CpTrigger:delete()

end

function CpTrigger:getNode()
	return self.node
end

function CpTrigger:getTrigger()
	return self.trigger
end

function CpTrigger:getTarget()
	return self.trigger:getTarget()
end

function CpTrigger:getFillUnitExactFillRootNode(fillUnitIndex)
	return self.trigger:getFillUnitExactFillRootNode(fillUnitIndex)
end

function CpTrigger:getFillUnitFreeCapacity(fillUnitIndex, fillTypeIndex, farmId)
	return self.trigger:getFillUnitFreeCapacity(fillUnitIndex, fillTypeIndex, farmId)
end

--- Is the fill type allowed ?
---@param fillType any
---@return boolean
function CpTrigger:getIsFillTypeAllowed(fillType)
	return self.trigger:getIsFillTypeAllowed(fillType)
end

---@param map table
---@param selectedTrigger CpTrigger
---@param fillTypes table|nil
function CpTrigger:drawPlot(map, selectedTrigger, fillTypes)
	if fillTypes then 
		local found = false
		for i, fillType in pairs(fillTypes) do
			if self.trigger:getIsFillTypeAllowed(fillType) then 
				found = true
			end
		end
		if not found then 
			return
		end
	end
	self.plot:setHighlighted(self == selectedTrigger)
	self.plot:draw(map)
end