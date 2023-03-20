--- Used to synchronize the combine unloader and bunker silo 
--- jobs after the player left a given vehicle.
---@class CpJobSyncOnLeaveEvent
CpJobSyncOnLeaveEvent = {}
local CpJobSyncOnLeaveEvent_mt = Class(CpJobSyncOnLeaveEvent, Event)

InitEventClass(CpJobSyncOnLeaveEvent, "CpJobSyncOnLeaveEvent")

function CpJobSyncOnLeaveEvent.emptyNew()
	local self = Event.new(CpJobSyncOnLeaveEvent_mt)

	return self
end

function CpJobSyncOnLeaveEvent.new(vehicle)
	local self = CpJobSyncOnLeaveEvent.emptyNew()
	self.vehicle = vehicle
	return self
end

function CpJobSyncOnLeaveEvent:readStream(streamId, connection)
	self.vehicle = NetworkUtil.readNodeObject(streamId)

	self.vehicle.spec_cpAIBunkerSiloWorker:readStream(streamId, connection)
	self.vehicle.spec_cpAICombineUnloader:readStream(streamId, connection)


	self:run(connection)
end

function CpJobSyncOnLeaveEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.vehicle)


	self.vehicle.spec_cpAIBunkerSiloWorker:writeStream(streamId, connection)
	self.vehicle.spec_cpAICombineUnloader:writeStream(streamId, connection)

end

function CpJobSyncOnLeaveEvent:run(connection)
	
end

function CpJobSyncOnLeaveEvent.sendEvent(vehicle)
	if g_server ~= nil then
		g_server:broadcastEvent(CpJobSyncOnLeaveEvent.new(vehicle), nil, nil, vehicle)
	else
		g_client:getServerConnection():sendEvent(CpJobSyncOnLeaveEvent.new(vehicle))
	end
end