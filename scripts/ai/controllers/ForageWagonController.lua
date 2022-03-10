--- Makes sure the driver is stopped, when the forage wagon is full.
---@class ForageWagonController : ImplementController
ForageWagonController = CpObject(ImplementController)
ForageWagonController.maxFillLevelPercentage = 0.95
function ForageWagonController:init(vehicle, forageWagon)
	self.forageWagon = forageWagon
    ImplementController.init(self, vehicle, self.forageWagon)
end

function ForageWagonController:update()
    local fillLevel = 0
    local capacity = 0
    local dischargeNode = self.forageWagon:getCurrentDischargeNode()
    if dischargeNode ~= nil then
        fillLevel = self.forageWagon:getFillUnitFillLevel(dischargeNode.fillUnitIndex)
        capacity = self.forageWagon:getFillUnitCapacity(dischargeNode.fillUnitIndex)
    end

    if fillLevel > capacity * self.maxFillLevelPercentage then
        self:debug("Stopped Cp, as the unit is full.")
        self.vehicle:stopCurrentAIJob(AIMessageErrorIsFull.new())
    end
end

function ForageWagonController:getDriveData()
    --- TODO: check if this is necessary.
    if not self.forageWagon:getIsTurnedOn() then
        if self.forageWagon.setFoldState then
            -- unfold if there is something to unfold
            self.forageWagon:setFoldState(-1, false)
        end
        if self.forageWagon:getCanBeTurnedOn() then
            self:debug('Turning on machine')
            self.forageWagon:setIsTurnedOn(true, false)
        end
    end
    return nil, nil, nil, nil
end


