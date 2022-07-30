--- Summary status of Courseplay to display in the HUD
---@class CpStatus
CpStatus = CpObject()

function CpStatus:init(isActive, vehicle, currentWaypointIx, numberOfWaypoints)
    self:set(isActive, vehicle, currentWaypointIx, numberOfWaypoints)
    self.dirtyFlag = self.vehicle:getNextDirtyFlag()
end

function CpStatus:set(isActive, vehicle, currentWaypointIx, numberOfWaypoints, timeRemaining)
    self.isActive = isActive
    self.vehicle = vehicle
    self.currentWaypointIx = currentWaypointIx
    self.numberOfWaypoints = numberOfWaypoints
    self.timeRemaining = timeRemaining
end

function CpStatus:reset()
    self.isActive = false
    self.currentWaypointIx = nil
    self.numberOfWaypoints = nil
    self.timeRemaining = ""
    if self.remainingTime then
        self.remainingTime:delete()
    end
    self.remainingTime = nil
end

function CpStatus:setActive(active)
    if self.isActive ~= active then 
        self.isActive = active
        self:raiseDirtyFlag()
    end
end

function CpStatus:setWaypointData(course, dt, startIx)
    if self.isActive then
        local currentWaypointIx = course:getCurrentWaypointIx()

        if not self.remainingTime and course then
            self.remainingTime = CpRemainingTime(self.vehicle, course, startIx)
        end
        --- Needs to be updated even if the value is not applied.
        if self.remainingTime then
            self.remainingTime:update(dt)
        end
        if currentWaypointIx and self.currentWaypointIx ~= currentWaypointIx then 
            self.currentWaypointIx = currentWaypointIx
            self.numberOfWaypoints = course:getNumberOfWaypoints()
            local timeRemaining = self.remainingTime:getTimeRemaining()
            self.timeRemaining = CpGuiUtil.getFormatTimeText(timeRemaining) or ""

            self:raiseDirtyFlag()
        end
    end
end

function CpStatus:getWaypointText()
    if self.isActive and self.currentWaypointIx and self.numberOfWaypoints then 
        return string.format('%d/%d', self.currentWaypointIx, self.numberOfWaypoints)
    end 
    return '--/--'
end

function CpStatus:getTimeRemainingText()
    if self.isActive and self.timeRemaining then
        return self.timeRemaining
    end 
    return ""
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

        streamWriteString(streamId, self.timeRemaining or "")
	end
end

function CpStatus:onReadUpdateStream(streamId, timestamp, connection)
	if connection:getIsServer() and streamReadBool(streamId) then
        self.numberOfWaypoints = streamReadInt32(streamId, self.numberOfWaypoints)
        self.currentWaypointIx = streamReadInt32(streamId, self.currentWaypointIx)
        self.isActive = streamReadBool(streamId, self.currentWaypointIx)

        self.timeRemaining = streamReadString(streamId)
	end
end