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
    local maxSpeed = self:handleLoadigMachine()
    return nil, nil, nil, maxSpeed
end

function ForageWagonController:handleLoadigMachine()
    local maxSpeed

    if not self.forageWagon:getIsTurnedOn() then
        if self.forageWagon.setFoldState then
            -- unfold if there is something to unfold
            self.forageWagon:setFoldState(-1, false)
        end
        if self.forageWagon:getCanBeTurnedOn() then
            self:debug('Turning on machine')
            self.forageWagon:setIsTurnedOn(true, false);
        -- else
            -- maxSpeed = 0
            -- self:debug('NEED_SOMETHING')
        end
    end

    if self.forageWagon.setPickupState ~= nil then
        if self.forageWagon.spec_pickup ~= nil and not self.forageWagon.spec_pickup.isLowered then
            self.forageWagon:setPickupState(true, false)
            self:debug('lowering pickup')
        end
    end

    return maxSpeed
end


