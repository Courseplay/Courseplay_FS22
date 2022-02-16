--- Controller for sprayers and fertilizer spreaders
--- Main motivation as of now is to turn the sprayer off while the vehicle is not moving
--- for whatever reason, for instance in a convoy waiting to start.
---@class SprayerController : ImplementController
SprayerController = CpObject(ImplementController)

function SprayerController:init(vehicle, sprayer)
    self.sprayer = sprayer
    ImplementController.init(self, vehicle, self.sprayer)
    self.turnedOffBecauseStopped = false
end

function SprayerController:onRaising()
    if self.turnedOffBecauseStopped then
        self:debug('Sprayer was turned off because the vehicle stopped, it is now turned off for some other reason, will not turn on when we start moving again')
        self.turnedOffBecauseStopped = false
    end
end

function SprayerController:getDriveData()
    if self.vehicle:getLastSpeed() < 0.1 then
        -- we don't really move, turn off sprayer to stop wasting material
        if self.sprayer:getIsTurnedOn() then
            self:debug('Turning off sprayer while vehicle is stopped')
            self.sprayer:setIsTurnedOn(false)
            self.turnedOffBecauseStopped = true
        end
    else
        -- we are moving
        if self.turnedOffBecauseStopped and not self.sprayer:getIsTurnedOn() then
            self.sprayer:setIsTurnedOn(true)
            self:debug('Turning on sprayer as vehicle started moving')
            self.turnedOffBecauseStopped = false
        end
    end
end
