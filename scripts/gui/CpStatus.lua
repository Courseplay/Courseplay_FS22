--- Summary status of Courseplay to display in the HUD
---@class CpStatus
CpStatus = CpObject()

function CpStatus:init(isActive, vehicle, currentWaypointIx, numberOfWaypoints)
    self:set(isActive, vehicle, currentWaypointIx, numberOfWaypoints)
    self.dirtyFlag = self.vehicle:getNextDirtyFlag()
    self.remainingTime = CpRemainingTime(self.vehicle)
end

function CpStatus:set(isActive, vehicle, currentWaypointIx, numberOfWaypoints)
    self.isActive = isActive
    self.vehicle = vehicle
    self.currentWaypointIx = currentWaypointIx
    self.numberOfWaypoints = numberOfWaypoints
end

function CpStatus:reset()
    self.isActive = false
    self.currentWaypointIx = nil
    self.numberOfWaypoints = nil
    self.remainingTime:reset()
end

function CpStatus:start()
    self.remainingTime:start()
end

function CpStatus:setActive(active)
    if self.isActive ~= active then 
        self.isActive = active
        self:raiseDirtyFlag()
        if not active then 
            self:reset()
        else 
            self:start()
        end
    end
end

function CpStatus:update(dt, isActive, strategy)
    if isActive then 
        if strategy then
            strategy:updateCpStatus(self)
            self.remainingTime:update(dt)
        end
    end 
    self:setActive(isActive)
end

function CpStatus:setWaypointData(currentWaypointIx, numberOfWaypoints, course)
    if self.currentWaypointIx ~= currentWaypointIx then 
        self.currentWaypointIx = currentWaypointIx
        self.numberOfWaypoints = numberOfWaypoints
        self:raiseDirtyFlag()
        self.remainingTime:calculate(course, currentWaypointIx)
    end
end

function CpStatus:getWaypointText()
    if self.isActive and self.currentWaypointIx and self.numberOfWaypoints then 
        return string.format('%d/%d', self.currentWaypointIx, self.numberOfWaypoints)
    end 
    return '--/--'
end

function CpStatus:getTimeRemainingText()
    return self.remainingTime:getText()
end

function CpStatus:getIsActive()
    return self.isActive
end

function CpStatus:raiseDirtyFlag()
    self.vehicle:raiseDirtyFlags(self.dirtyFlag)
end

function CpStatus:onWriteUpdateStream(streamId, connection, dirtyMask)
	if not connection:getIsServer() and streamWriteBool(streamId, bitAND(dirtyMask, self.dirtyFlag) ~= 0) then
		streamWriteInt32(streamId, self.numberOfWaypoints or 0)
        streamWriteInt32(streamId, self.currentWaypointIx or 0)
        streamWriteBool(streamId, self.isActive or false)
        streamWriteString(streamId, self.remainingTime:getText() or "")
	end
end

function CpStatus:onReadUpdateStream(streamId, timestamp, connection)
	if connection:getIsServer() and streamReadBool(streamId) then
        self.numberOfWaypoints = streamReadInt32(streamId)
        self.currentWaypointIx = streamReadInt32(streamId)
        self.isActive = streamReadBool(streamId)
        self.remainingTime:setText(streamReadString(streamId))
	end
end