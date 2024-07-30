---@class HudSettingsEvent
HudSettingsEvent = {}

local HudSettingsEvent_mt = Class(HudSettingsEvent, Event)

InitEventClass(HudSettingsEvent, "HudSettingsEvent")

function HudSettingsEvent.emptyNew()
	return Event.new(HudSettingsEvent_mt)
end

--- Creates a new Event
function HudSettingsEvent.new(vehicle, setting)
	local self = HudSettingsEvent.emptyNew()
	self.vehicle = vehicle
	self.setting = setting
	return self
end

--- Reads the serialized data on the receiving end of the event.
function HudSettingsEvent:readStream(streamId, connection)
	self.vehicle = NetworkUtil.readNodeObject(streamId)
	HudSettingsEvent.debug(self.vehicle, "readStream")
	local name = streamReadString(streamId)
	local setting = self.vehicle:getCpHudSettings()[name]
	setting:readStream(streamId, connection)
	self:run(connection, setting);
end

--- Writes the serialized data from the sender.
function HudSettingsEvent:writeStream(streamId, connection) 
	HudSettingsEvent.debug(self.vehicle, "writeStream")
	NetworkUtil.writeNodeObject(streamId, self.vehicle)
	streamWriteString(streamId, self.setting:getName())
	self.setting:writeStream(streamId, connection)
end

--- Runs the event on the receiving end of the event.
function HudSettingsEvent:run(connection, setting) 
	--- If the receiver was the client make sure every clients gets also updated.
	if not connection:getIsServer() then
		HudSettingsEvent.debug(self.vehicle, "broadcastEvent")
		g_server:broadcastEvent(HudSettingsEvent.new(self.vehicle, setting), nil, connection, self.vehicle)
	end
end

function HudSettingsEvent.sendEvent(vehicle, setting)
	if g_server ~= nil then
		HudSettingsEvent.debug(vehicle, "sendEvent")
		g_server:broadcastEvent(HudSettingsEvent.new(vehicle, setting), nil, nil, vehicle)
	else
		g_client:getServerConnection():sendEvent(HudSettingsEvent.new(vehicle, setting))
	end
end

function HudSettingsEvent.debug(vehicle, str, ...)
	CpUtil.debugVehicle(CpDebug.DBG_MULTIPLAYER, vehicle, "HudSettingsEvent: "..str, ...)
end