
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
---@param fillType number|nil
function CpTrigger:drawPlot(map, selectedTrigger, fillType)
	if fillType and fillType ~= FillType.UNKNOWN then 
		if not self.trigger:getIsFillTypeAllowed(fillType) then 
			--- Fill type is not allowed.
			return
		end
	end
	self.plot:setHighlighted(self == selectedTrigger)
	self.plot:draw(map)
end