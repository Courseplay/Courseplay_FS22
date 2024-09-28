--- The Plow:setRotationCenter() function is not synchronized, so we do this here.
---@class PlowCenterTurnEvent
PlowCenterTurnEvent = {}
local PlowCenterTurnEvent_mt = Class(PlowCenterTurnEvent, Event)

InitEventClass(PlowCenterTurnEvent, 'PlowCenterTurnEvent')

function PlowCenterTurnEvent.emptyNew()
    return Event.new(PlowCenterTurnEvent_mt)
end

function PlowCenterTurnEvent.new(implement)
    local self = PlowCenterTurnEvent.emptyNew()
    self.implement = implement
    return self
end

function PlowCenterTurnEvent:readStream(streamId, connection)
    self.implement = NetworkUtil.readNodeObject(streamId)
    CpUtil.debugImplement(CpDebug.DBG_MULTIPLAYER, self.implement,
        'Plow rotation center event: read stream')
    self:run(connection)
end

function PlowCenterTurnEvent:writeStream(streamId, connection)
    CpUtil.debugImplement(CpDebug.DBG_MULTIPLAYER, self.implement,
        'Plow rotation center event: write stream')
    NetworkUtil.writeNodeObject(streamId, self.implement)
end

-- Process the received event
function PlowCenterTurnEvent:run(connection)
    CpUtil.debugImplement(CpDebug.DBG_MULTIPLAYER, self.implement,
        'Plow rotation center event: run')
    self.implement:setRotationCenter()    
end

function PlowCenterTurnEvent.sendEvent(implement)
    implement:setRotationCenter()
    CpUtil.debugImplement(CpDebug.DBG_MULTIPLAYER, implement,
        'sending Plow rotation center event.')
    if g_server ~= nil then
        g_server:broadcastEvent(PlowCenterTurnEvent.new(implement), 
            nil, nil, implement)
    end
end
