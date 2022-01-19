--- Summary status of Courseplay to display in the HUD
---@class CourseplayStatus
CourseplayStatus = CpObject()

function CourseplayStatus:init(isActive, vehicle, currentWaypointIx, numberOfWaypoints)
    self:set(isActive, vehicle, currentWaypointIx, numberOfWaypoints)
end

function CourseplayStatus:set(isActive, vehicle, currentWaypointIx, numberOfWaypoints,timeRemaining)
    self.isActive = isActive
    self.vehicle = vehicle
    self.currentWaypointIx = currentWaypointIx
    self.numberOfWaypoints = numberOfWaypoints
    self.timeRemaining = timeRemaining
end

function CourseplayStatus:getWaypointText()
    if self.isActive then 
        return string.format('%d/%d', self.currentWaypointIx, self.numberOfWaypoints)
    end 
    return '--/--'
end

function CourseplayStatus:getTimeRemainingText()
    if self.isActive then
        return self.timeRemaining and CpGuiUtil.getFormatTimeText(self.timeRemaining) or "WIP"
    end 
    return '--/--'
end

function CourseplayStatus:getIsActive()
    return self.isActive
end