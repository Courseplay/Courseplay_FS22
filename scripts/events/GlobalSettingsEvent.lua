---@class GlobalSettingsEvent
GlobalSettingsEvent = {}
local GlobalSettingsEvent_mt = Class(GlobalSettingsEvent, Event)

InitEventClass(GlobalSettingsEvent, "GlobalSettingsEvent")

function GlobalSettingsEvent.emptyNew()
	return Event.new(GlobalSettingsEvent_mt)
end

--- Creates a new Event
function GlobalSettingsEvent.new(setting)
	local self = GlobalSettingsEvent.emptyNew()
	self.setting = setting
	return self
end

--- Reads the serialized data on the receiving end of the event.
function GlobalSettingsEvent:readStream(streamId, connection) -- wird aufgerufen wenn mich ein Event erreicht
	GlobalSettingsEvent.debug("readStream")
	local name = streamReadString(streamId)
	local setting = g_Courseplay.globalSettings[name]
	setting:readStream(streamId, connection)
	self:run(connection,setting);
end

--- Writes the serialized data from the sender.
function GlobalSettingsEvent:writeStream(streamId, connection)  -- Wird aufgrufen wenn ich ein event verschicke (merke: reihenfolge der Daten muss mit der bei readStream uebereinstimmen 
	GlobalSettingsEvent.debug("writeStream")
	streamWriteString(streamId,self.setting:getName())
	self.setting:writeStream(streamId, connection)
end

--- Runs the event on the receiving end of the event.
function GlobalSettingsEvent:run(connection,setting) -- wir fuehren das empfangene event aus
	--- If the receiver was the client make sure every clients gets also updated.
	if not connection:getIsServer() then
		GlobalSettingsEvent.debug("broadcastEvent")
		g_server:broadcastEvent(GlobalSettingsEvent.new(setting), nil, connection, nil)
	end
end

function GlobalSettingsEvent.sendEvent(setting)
	if g_server ~= nil then
		GlobalSettingsEvent.debug("sendEvent")
		g_server:broadcastEvent(GlobalSettingsEvent.new(setting), nil, nil, nil)
	else
		g_client:getServerConnection():sendEvent(GlobalSettingsEvent.new(setting))
	end
end

function GlobalSettingsEvent.debug(str, ...)
	CpUtil.debugFormat(CpDebug.DBG_MULTIPLAYER, "GlobalSettingsEvent: "..str,...)
end