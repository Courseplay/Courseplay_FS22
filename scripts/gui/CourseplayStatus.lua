--- Summary status of Courseplay to display in the HUD
---@class CourseplayStatus
CourseplayStatus = CpObject()

function CourseplayStatus:init(isActive, vehicle, currentWaypointIx, numberOfWaypoints)
    self:set(isActive, vehicle, currentWaypointIx, numberOfWaypoints)
end

function CourseplayStatus:set(isActive, vehicle, currentWaypointIx, numberOfWaypoints)
    self.isActive = isActive
    self.vehicle = vehicle
    self.currentWaypointIx = currentWaypointIx
    self.numberOfWaypoints = numberOfWaypoints
end