AIMessageErrorIsFull = {}
local AIMessageErrorIsFull_mt = Class(AIMessageErrorIsFull, AIMessage)

function AIMessageErrorIsFull.new(customMt)
	local self = AIMessage.new(customMt or AIMessageErrorIsFull_mt)

	return self
end

function AIMessageErrorIsFull:getMessage()
	return g_i18n:getText("CP_ai_messageErrorIsFull")
end
