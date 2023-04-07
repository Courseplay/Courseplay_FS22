---@class DriveNowRequestEvent
DriveNowRequestEvent = {}
local DriveNowRequestEvent_mt = Class(DriveNowRequestEvent, Event)

InitEventClass(DriveNowRequestEvent, "DriveNowRequestEvent")

function DriveNowRequestEvent.emptyNew()
	local self = Event.new(DriveNowRequestEvent_mt)

	return self
end

function DriveNowRequestEvent.new(vehicle)
	local self = DriveNowRequestEvent.emptyNew()
	self.vehicle = vehicle
	return self
end

function DriveNowRequestEvent:readStream(streamId, connection)
	self.vehicle = NetworkUtil.readNodeObject(streamId)

	self:run(connection)
end

function DriveNowRequestEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.vehicle)

end

function DriveNowRequestEvent:run(connection)
	self.vehicle:startCpCombineUnloaderUnloading()
end

function DriveNowRequestEvent.sendEvent(vehicle)
	if g_server ~= nil then
		g_server:broadcastEvent(DriveNowRequestEvent.new(vehicle), nil, nil, vehicle)
	else
		g_client:getServerConnection():sendEvent(DriveNowRequestEvent.new(vehicle))
	end
end