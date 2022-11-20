--- Makes sure the server has the same job parameters as the client.
---@class CpJobStartAtLastWpSyncEvent
CpJobStartAtLastWpSyncEvent = {}
local CpJobStartAtLastWpSyncEvent_mt = Class(CpJobStartAtLastWpSyncEvent, Event)

InitEventClass(CpJobStartAtLastWpSyncEvent, "CpJobStartAtLastWpSyncEvent")

function CpJobStartAtLastWpSyncEvent.emptyNew()
	local self = Event.new(CpJobStartAtLastWpSyncEvent_mt)

	return self
end

function CpJobStartAtLastWpSyncEvent.new(vehicle)
	local self = CpJobStartAtLastWpSyncEvent.emptyNew()
	self.vehicle = vehicle
	return self
end

function CpJobStartAtLastWpSyncEvent:readStream(streamId, connection)
	self.vehicle = NetworkUtil.readNodeObject(streamId)

	--- Fieldwork job 
	self.vehicle.spec_cpAIFieldWorker.cpJobStartAtLastWp:readStream(streamId, connection)

	--- Bale finder job
	self.vehicle.spec_cpAIBaleFinder.cpJobStartAtLastWp:readStream(streamId, connection)

	self:run(connection)
end

function CpJobStartAtLastWpSyncEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.vehicle)

	--- Fieldwork job 
	self.vehicle.spec_cpAIFieldWorker.cpJobStartAtLastWp:writeStream(streamId, connection)

	--- Bale finder job
	self.vehicle.spec_cpAIBaleFinder.cpJobStartAtLastWp:writeStream(streamId, connection)

end

function CpJobStartAtLastWpSyncEvent:run(connection)
	
end

function CpJobStartAtLastWpSyncEvent.sendEvent(vehicle)
	if not g_server then 
		g_client:getServerConnection():sendEvent(CpJobStartAtLastWpSyncEvent.new(vehicle))
	end
end

--- Ask the server, if the vehicle was started by a player.
--- TODO: This should be implemented into the ad code!
---@class CpJobStartAtLastWpSyncRequestEvent
CpJobStartAtLastWpSyncRequestEvent = {}
local CpJobStartAtLastWpSyncRequestEvent_mt = Class(CpJobStartAtLastWpSyncRequestEvent, Event)

InitEventClass(CpJobStartAtLastWpSyncRequestEvent, "CpJobStartAtLastWpSyncRequestEvent")

function CpJobStartAtLastWpSyncRequestEvent.emptyNew()
	local self = Event.new(CpJobStartAtLastWpSyncRequestEvent_mt)

	return self
end

function CpJobStartAtLastWpSyncRequestEvent.new(vehicle)
	local self = CpJobStartAtLastWpSyncRequestEvent.emptyNew()
	self.vehicle = vehicle
	return self
end

function CpJobStartAtLastWpSyncRequestEvent:readStream(streamId, connection)
	self.vehicle = NetworkUtil.readNodeObject(streamId)

	self:run(connection)
end

function CpJobStartAtLastWpSyncRequestEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.vehicle)

end

function CpJobStartAtLastWpSyncRequestEvent:run(connection)
	if g_server then 
		if not self.vehicle.ad.restartCP  then 
			connection:sendEvent(CpJobStartAtLastWpSyncRequestEvent.new(self.vehicle))
		end
	else 
		CpJobStartAtLastWpSyncEvent.sendEvent(self.vehicle)
	end
end

function CpJobStartAtLastWpSyncRequestEvent.sendEvent(vehicle)
	if not g_server then 
		g_client:getServerConnection():sendEvent(CpJobStartAtLastWpSyncRequestEvent.new(vehicle))
	end
end