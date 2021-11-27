
--- Example AI job parameter, that is listed in the game menu.

---@class AIParameterCenterMode
AIParameterCenterMode = {
	UP_DOWN = 1,
	CIRCULAR = 2,
	SPIRAL = 3,
	LANDS = 4,
	translations = {
		'COURSEPLAY_CENTER_MODE_UP_DOWN',
		'COURSEPLAY_CENTER_MODE_CIRCULAR',
		'COURSEPLAY_CENTER_MODE_SPIRAL',
		'COURSEPLAY_CENTER_MODE_LANDS'
	}
}
local AIParameterCenterMode_mt = Class(AIParameterCenterMode, AIParameter)

function AIParameterCenterMode.new(customMt)
	local self = AIParameter.new(customMt or AIParameterCenterMode_mt)
	self.type = AIParameterType.SELECTOR
	self.min = self.UP_DOWN
	self.max = self.LANDS
	self.value  = self.min
	return self
end

function AIParameterCenterMode:saveToXMLFile(xmlFile, key, usedModNames)
	xmlFile:setInt(key .. "#value", self.value)
end

function AIParameterCenterMode:loadFromXMLFile(xmlFile, key)
	self.value = xmlFile:getInt(key .. "#value", self.value)
end

function AIParameterCenterMode:readStream(streamId, connection)
	self:setValue(streamReadInt32(streamId))
end

function AIParameterCenterMode:writeStream(streamId, connection)
	streamWriteInt32(streamId, self.value)
end

function AIParameterCenterMode:setValue(value)
	self.value = value
end

function AIParameterCenterMode:getValue()
	return self.value
end

function AIParameterCenterMode:getString()
	return g_i18n:getText(self.translations[self.value])
end

function AIParameterCenterMode:setNextItem()
	self.value = math.min(self.value+1,self.max)
end

function AIParameterCenterMode:setPreviousItem()
	self.value = math.max(self.value-1,self.min)
end
