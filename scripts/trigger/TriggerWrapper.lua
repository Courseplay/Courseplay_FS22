
---@class CpTrigger
CpTrigger = CpObject()

function CpTrigger:init(trigger, node)
	self.trigger = trigger
	self.node = node
end

function CpTrigger:delete()

end

function CpTrigger:getNode()
	return self.node
end

function CpTrigger:getTrigger()
	return self.trigger
end