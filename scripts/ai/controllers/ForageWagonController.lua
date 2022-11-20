--- Makes sure the driver is stopped, when the forage wagon is full.
--- Also checks the silage additive, if needed.
---@class ForageWagonController : ImplementController
ForageWagonController = CpObject(ImplementController)
ForageWagonController.maxFillLevelPercentage = 0.95
ForageWagonController.slowDownFillLevel = 200
ForageWagonController.slowDownStartSpeed = 20
function ForageWagonController:init(vehicle, forageWagon)
    ImplementController.init(self, vehicle, forageWagon)
    self.forageWagonSpec = forageWagon.spec_forageWagon
    self.settings = vehicle:getCpSettings()
end

function ForageWagonController:update()
    if self.implement:getFillUnitFreeCapacity(self.forageWagonSpec.fillUnitIndex) <= 0 then
        self:debug("Stopped Cp, as the forage wagon is full.")
        self.vehicle:stopCurrentAIJob(AIMessageErrorIsFull.new())
    end
    if self.settings.useAdditiveFillUnit:getValue() then 
        --- If the silage additive is empty, then stop the driver.
        local additives = self.forageWagonSpec.additives
        if additives.available then 
            if self.implement:getFillUnitFillLevelPercentage(additives.fillUnitIndex) <= 0 then 
                self:debug("Stopped Cp, as the additive fill unit is empty.")
                self.vehicle:stopCurrentAIJob(AIMessageErrorOutOfFill.new())
            end
        end
    end
end

function ForageWagonController:getDriveData()
    local fillLevel = self.implement:getFillUnitFillLevel(self.forageWagonSpec.fillUnitIndex)
    local capacity = self.implement:getFillUnitCapacity(self.forageWagonSpec.fillUnitIndex)
    local freeFillLevel = capacity - fillLevel
    local maxSpeed
    if freeFillLevel < self.slowDownFillLevel then
        maxSpeed = 5 + freeFillLevel / self.slowDownFillLevel * self.slowDownStartSpeed
    end
    return nil, nil, nil, maxSpeed
end

