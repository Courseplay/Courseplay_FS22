---@class ForageWagonController : ImplementController
ForageWagonController = CpObject(ImplementController)

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

    if fillLevel > capacity * 0.95 then
        self:debug("Stopped Cp, as the unit is full.")
        self.vehicle:stopCurrentAIJob(AIMessageErrorIsFull.new())
    end
end

function ForageWagonController:getDriveData()
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


