--- Raises/lowers the additional cutters, like the straw/grass pickup for harvesters.
--- Also disables the cutter, while it's waiting for unloading.
---@class CutterController : ImplementController
CutterController = CpObject(ImplementController)

function CutterController:init(vehicle, implement)
    ImplementController.init(self, vehicle, implement)
    self.cutterSpec = self.implement.spec_cutter
end

function CutterController:getDriveData()
    self:disableCutterTimer()
    --- Turns off the cutter, while the driver is waiting for unloading.
    if self.driveStrategy.getCanCutterBeTurnedOff and self.driveStrategy:getCanCutterBeTurnedOff() then
        if self.implement:getIsTurnedOn() then
            -- Do not immediately turn off the cutter. This is just a safety measure for the case when
            -- the combine forgets to check if it is stopped before getCanCutterBeTurnedOff() returns true
            -- also, a little bit of hysteresis won't hurt...
            if not self.delayedTurnOff then
                self:debug('Cutter can be turned off, wait a little bit before turning off...')
                self.delayedTurnOff = Timer.createOneshot(2000, function()
                    self:debug('Turning off cutter now')
                    self.implement:setIsTurnedOn(false)
                    self.delayedTurnOff = nil
                end)
            end
        end
    else
        self.delayedTurnOff = nil
        --- Turns it back on, when the unloading finished and the cutter is lowered.
        if not self.implement:getIsTurnedOn() and self.implement:getIsLowered() then
            self.implement:setIsTurnedOn(true)
        end
    end
    return nil, nil, nil, nil
end

--- The Giants Cutter class has a timer to stop the AI job if there is no fruit being processed for 5 seconds.
--- This prevents us from driving for instance on a connecting track or longer turns (and also testing), so
--- we just reset that timer here in every update cycle.
--- Consider setting Cutter:getAllowCutterAIFruitRequirements() to false
function CutterController:disableCutterTimer()
    if self.cutterSpec.aiNoValidGroundTimer then
        self.cutterSpec.aiNoValidGroundTimer = 0
    end
end

function CutterController:onLowering()
    self.implement:aiImplementStartLine()
end

function CutterController:onRaising()
    self.implement:aiImplementEndLine()
end