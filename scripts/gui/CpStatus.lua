--- Summary status of Courseplay to display in the HUD
---@class CpStatus
CpStatus = CpObject()

function CpStatus:init(isActive, vehicle, currentWaypointIx, numberOfWaypoints)
    self:set(isActive, vehicle, currentWaypointIx, numberOfWaypoints)
end

function CpStatus:set(isActive, vehicle, currentWaypointIx, numberOfWaypoints,timeRemaining)
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
    self.timeRemaining = 0
end

function CpStatus:setActive(active)
    self.isActive = active
end

function CpStatus:setWaypointData(currentWaypointIx,numberOfWaypoints,timeRemaining)
    self.currentWaypointIx = currentWaypointIx
    self.numberOfWaypoints = numberOfWaypoints
    self.timeRemaining = timeRemaining
end

function CpStatus:getWaypointText()
    if self.isActive and self.currentWaypointIx and self.numberOfWaypoints then 
        return string.format('%d/%d', self.currentWaypointIx, self.numberOfWaypoints)
    end 
    return '--/--'
end

function CpStatus:getTimeRemainingText()
    if self.isActive and self.timeRemaining then
        return self.timeRemaining and CpGuiUtil.getFormatTimeText(self.timeRemaining) or "WIP"
    end 
    return '--/--'
end

function CpStatus:getIsActive()
    return self.isActive
end