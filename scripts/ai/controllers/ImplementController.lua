---@class ImplementController
ImplementController = CpObject()

function ImplementController:init(vehicle, implement)
    self.vehicle = vehicle
    self.implement = implement
end

--- Get the controlled implement
function ImplementController:getImplement()
    return self.implement
end

---@param disabledStates table list of drive strategy states where the controlling of this implement is disabled
function ImplementController:setDisabledStates(disabledStates)
    self.disabledStates = disabledStates
end

---@param currentState table current state of the drive strategy
---@return boolean true if currentState is not one of the disabled states
function ImplementController:isEnabled(currentState)
    for _, state in pairs(self.disabledStates) do
        if currentState == state then
            return false
        end
    end
    return true
end

function ImplementController:debug(...)
    CpUtil.debugVehicle(CpDebug.DBG_IMPLEMENTS, self.vehicle,
            CpUtil.getName(self.implement) .. ': ' .. string.format(...))
end

function ImplementController:debugSparse(...)
    if g_updateLoopIndex % 100 == 0 then
        self:debug(...)
    end
end

--- Drive strategies can instantiate controllers for implements and call getDriveData for each
--- implement. If the implement wants to change any of the driving parameter, it'll return
--- a non nil value for that parameter, most often a speed value to slow down or stop.

---@return number gx world x coordinate to drive to or nil
---@return number gz world z coordinate to drive to or nil
---@return boolean direction is forwards if true or nil
---@return number maximum speed or nil
function ImplementController:getDriveData()
    return nil, nil, nil, nil
end

function ImplementController:update(dt)
    -- implement in the derived classes as needed
end