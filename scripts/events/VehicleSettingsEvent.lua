---@class VehicleSettingsEvent
VehicleSettingsEvent = {}

local VehicleSettingsEvent_mt = Class(VehicleSettingsEvent, Event)

InitEventClass(VehicleSettingsEvent, "VehicleSettingsEvent")

function VehicleSettingsEvent.emptyNew()
	return Event.new(VehicleSettingsEvent_mt)
end

--- Creates a new Event
function VehicleSettingsEvent.new(vehicle, setting)
	local self = VehicleSettingsEvent.emptyNew()
	self.vehicle = vehicle
	self.setting = setting
	return self
end

--- Reads the serialized data on the receiving end of the event.
function VehicleSettingsEvent:readStream(streamId, connection)
	self.vehicle = NetworkUtil.readNodeObject(streamId)
	VehicleSettingsEvent.debug(self.vehicle, "readStream")
	local name = streamReadString(streamId)
	local setting = self.vehicle:getCpSettings()[name]
	setting:readStream(streamId, connection)
	self:run(connection, setting);
end

--- Writes the serialized data from the sender.
function VehicleSettingsEvent:writeStream(streamId, connection) 
	VehicleSettingsEvent.debug(self.vehicle, "writeStream")
	NetworkUtil.writeNodeObject(streamId, self.vehicle)
	streamWriteString(streamId, self.setting:getName())
	self.setting:writeStream(streamId, connection)
end

--- Runs the event on the receiving end of the event.
function VehicleSettingsEvent:run(connection, setting) 
	--- If the receiver was the client make sure every clients gets also updated.
	if not connection:getIsServer() then
		VehicleSettingsEvent.debug(self.vehicle, "broadcastEvent")
		g_server:broadcastEvent(VehicleSettingsEvent.new(self.vehicle, setting), nil, connection, self.vehicle)
	end
end

function VehicleSettingsEvent.sendEvent(vehicle, setting)
	if g_server ~= nil then
		VehicleSettingsEvent.debug(vehicle, "sendEvent")
		g_server:broadcastEvent(VehicleSettingsEvent.new(vehicle, setting), nil, nil, vehicle)
	else
		g_client:getServerConnection():sendEvent(VehicleSettingsEvent.new(vehicle, setting))
	end
end

function VehicleSettingsEvent.debug(vehicle, str, ...)
	CpUtil.debugVehicle(CpDebug.DBG_MULTIPLAYER, vehicle, "VehicleSettingsEvent: "..str, ...)
end

--- Sends the changed setting value to the server,
--- so it can be saved there.
---@class VehicleUserSettingsEvent
VehicleUserSettingsEvent = {}

local VehicleUserSettingsEvent_mt = Class(VehicleUserSettingsEvent, Event)

InitEventClass(VehicleUserSettingsEvent, "VehicleUserSettingsEvent")

function VehicleUserSettingsEvent.emptyNew()
	return Event.new(VehicleUserSettingsEvent_mt)
end

--- Creates a new Event
function VehicleUserSettingsEvent.new(vehicle, setting)
	local self = VehicleUserSettingsEvent.emptyNew()
	self.vehicle = vehicle
	self.setting = setting
	return self
end

--- Reads the serialized data on the receiving end of the event.
function VehicleUserSettingsEvent:readStream(streamId, connection)
	self.vehicle = NetworkUtil.readNodeObject(streamId)
	VehicleUserSettingsEvent.debug(self.vehicle, "readStream")
	local name = streamReadString(streamId)
	local value = streamReadInt32(streamId)
	self:run(connection, name, value)
end

--- Writes the serialized data from the sender.
function VehicleUserSettingsEvent:writeStream(streamId, connection) 
	VehicleUserSettingsEvent.debug(self.vehicle, "writeStream")
	NetworkUtil.writeNodeObject(streamId, self.vehicle)
	streamWriteString(streamId, self.setting:getName())
	streamWriteInt32(streamId, self.setting:getClosestSetupIx())
end

--- Runs the event on the receiving end of the event.
function VehicleUserSettingsEvent:run(connection, name, value) 
	local uniqueUserId = g_currentMission.userManager:getUniqueUserIdByConnection(connection)
	VehicleUserSettingsEvent.debug(self.vehicle, "name: %s, value: %s, userId: %s", name, tostring(value), tostring(uniqueUserId))
	self.vehicle:cpSaveUserSettingValue(uniqueUserId, name, value)
end

function VehicleUserSettingsEvent.sendEvent(vehicle, setting)
	VehicleUserSettingsEvent.debug(vehicle, "sendEvent")
	g_client:getServerConnection():sendEvent(VehicleUserSettingsEvent.new(vehicle, setting))
end

function VehicleUserSettingsEvent.debug(vehicle, str, ...)
	CpUtil.debugVehicle(CpDebug.DBG_MULTIPLAYER, vehicle, "VehicleUserSettingsEvent: "..str, ...)
end