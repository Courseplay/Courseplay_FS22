---@class ForageWagonController : ImplementController
ForageWagonController = CpObject(ImplementController)

function ForageWagonController:init(vehicle)
	self.loadigMachine = AIUtil.getImplementOrVehicleWithSpecialization(vehicle, ForageWagon)
    ImplementController.init(self, vehicle, self.loadigMachine)
end

function ForageWagonController:update()
    local fillLevel = 0
    local capacity = 0
    local dischargeNode = self.loadigMachine:getCurrentDischargeNode()
    if dischargeNode ~= nil then
        fillLevel = self.loadigMachine:getFillUnitFillLevel(dischargeNode.fillUnitIndex)
        capacity = self.loadigMachine:getFillUnitCapacity(dischargeNode.fillUnitIndex)
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

    if not self.loadigMachine:getIsTurnedOn() then
        if self.loadigMachine.setFoldState then
            -- unfold if there is something to unfold
            self.loadigMachine:setFoldState(-1, false)
        end
        if self.loadigMachine:getCanBeTurnedOn() then
            self:debug('Turning on machine')
            self.loadigMachine:setIsTurnedOn(true, false);
        -- else
            -- maxSpeed = 0
            -- self:debug('NEED_SOMETHING')
        end
    end

    if self.loadigMachine.setPickupState ~= nil then
        if self.loadigMachine.spec_pickup ~= nil and not self.loadigMachine.spec_pickup.isLowered then
            self.loadigMachine:setPickupState(true, false)
            self:debug('lowering pickup')
        end
    end

    return maxSpeed
end


