
--- Example AI job parameter, that is listed in the game menu.

---@class AIParameterNumberOfHeadlands
AIParameterNumberOfHeadlands = {}
local AIParameterNumberOfHeadlands_mt = Class(AIParameterNumberOfHeadlands, AIParameter)
function AIParameterNumberOfHeadlands.new(customMt)
	local self = AIParameter.new(customMt or AIParameterNumberOfHeadlands_mt)
	self.type = AIParameterType.SELECTOR
	self.min = 0
	self.max = 40
	self.value  = self.min
	return self
end

function AIParameterNumberOfHeadlands:saveToXMLFile(xmlFile, key, usedModNames)
	xmlFile:setInt(key .. "#value", self.value)
end

function AIParameterNumberOfHeadlands:loadFromXMLFile(xmlFile, key)
	self.value = xmlFile:getInt(key .. "#value", self.value)
end

function AIParameterNumberOfHeadlands:readStream(streamId, connection)
	self:setValue(streamReadInt32(streamId))
end

function AIParameterNumberOfHeadlands:writeStream(streamId, connection)
	streamWriteInt32(streamId, self.value)
end

function AIParameterNumberOfHeadlands:setValue(value)
	self.value = value
end

function AIParameterNumberOfHeadlands:getValue()
	return self.value
end

function AIParameterNumberOfHeadlands:getString()
	return tostring(self.value)
end

function AIParameterNumberOfHeadlands:setNextItem()
	self.value = math.min(self.value+1,self.max)
end

function AIParameterNumberOfHeadlands:setPreviousItem()
	self.value = math.max(self.value-1,self.min)
end
