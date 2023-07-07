
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

function CpTrigger:drawPlot(map, selectedTrigger)
	self.plot:setHighlighted(self == selectedTrigger)
	self.plot:draw(map)
end