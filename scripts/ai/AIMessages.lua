AIMessageErrorIsFull = {
	name = "CP_ERROR_FULL"
}
local AIMessageErrorIsFull_mt = Class(AIMessageErrorIsFull, AIMessage)

function AIMessageErrorIsFull.new(customMt)
	local self = AIMessage.new(customMt or AIMessageErrorIsFull_mt)

	return self
end

function AIMessageErrorIsFull:getMessage()
	return g_i18n:getText("CP_ai_messageErrorIsFull")
end

AIMessageCpError = {
	name = "CP_ERROR"
}
local AIMessageCpError_mt = Class(AIMessageCpError, AIMessage)

function AIMessageCpError.new(customMt)
	local self = AIMessage.new(customMt or AIMessageCpError_mt)

	return self
end

function AIMessageCpError:getMessage()
	return g_i18n:getText("CP_ai_messageError")
end

function AIMessageErrorIsFull.register()
	g_currentMission.aiMessageManager:registerMessage(AIMessageErrorIsFull.name, AIMessageErrorIsFull)
	g_currentMission.aiMessageManager:registerMessage(AIMessageCpError.name, AIMessageCpError)
end

--- Another ugly hack, as the giants code to get the message index in mp isn't working ..
local function getMessageIndex(aiMessageManager, superFunc, messageObject, ...)
	local ix = superFunc(aiMessageManager, messageObject, ...)
	if ix == nil then 
		return aiMessageManager.nameToIndex[messageObject.name]
	end
	return ix
end
AIMessageManager.getMessageIndex = Utils.overwrittenFunction(AIMessageManager.getMessageIndex, getMessageIndex)
