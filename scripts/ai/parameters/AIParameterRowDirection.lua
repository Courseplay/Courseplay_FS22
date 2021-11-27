
--- Example AI job parameter, that is listed in the game menu.

---@class AIParameterRowDirection
AIParameterRowDirection = {
	AUTO = 1,
	LONGEST_EDGE = 2,
	translations = {
		'auto',
		'Longest Edge',
	}
}
local AIParameterRowDirection_mt = Class(AIParameterRowDirection, AIParameter)

function AIParameterRowDirection.new(customMt)
	local self = AIParameter.new(customMt or AIParameterRowDirection_mt)
	self.type = AIParameterType.SELECTOR
	self.min = self.AUTO
	self.max = self.LONGEST_EDGE
	self.value  = self.min
	return self
end

function AIParameterRowDirection:saveToXMLFile(xmlFile, key, usedModNames)
	xmlFile:setInt(key .. "#value", self.value)
end

function AIParameterRowDirection:loadFromXMLFile(xmlFile, key)
	self.value = xmlFile:getInt(key .. "#value", self.value)
end

function AIParameterRowDirection:readStream(streamId, connection)
	self:setValue(streamReadInt32(streamId))
end

function AIParameterRowDirection:writeStream(streamId, connection)
	streamWriteInt32(streamId, self.value)
end

function AIParameterRowDirection:setValue(value)
	self.value = value
end

function AIParameterRowDirection:getValue()
	return self.value
end

function AIParameterRowDirection:getString()
	return g_i18n:getText(self.translations[self.value])
end

function AIParameterRowDirection:setNextItem()
	self.value = math.min(self.value+1,self.max)
end

function AIParameterRowDirection:setPreviousItem()
	self.value = math.max(self.value-1,self.min)
end
