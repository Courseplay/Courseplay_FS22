--- For now only handles possible silage additives, if needed.
--- TODO: Straw swath handling should be moved here.
---@class CombineController : ImplementController
CombineController = CpObject(ImplementController)
function CombineController:init(vehicle, combine)
    ImplementController.init(self, vehicle, combine)
    self.combineSpec = combine.spec_combine
    self.settings = vehicle:getCpSettings()
end

function CombineController:update()
	if self.settings.useAdditiveFillUnit:getValue() then 
		--- If the silage additive is empty, then stop the driver.
        local additives = self.combineSpec.additives
        if additives.available then 
            if self.implement:getFillUnitFillLevelPercentage(additives.fillUnitIndex) <= 0 then 
				self:debug("Stopped Cp, as the additive fill unit is empty.")
                self.vehicle:stopCurrentAIJob(AIMessageErrorOutOfFill.new())
            end
        end
    end
end

function CombineController:getDriveData()
    local maxSpeed = nil 
    if self.implement:getIsThreshingDuringRain() then 
        maxSpeed = 0
        self:setInfoText(InfoTextManager.WAITING_FOR_RAIN_TO_FINISH)
    else 
        self:clearInfoText(InfoTextManager.WAITING_FOR_RAIN_TO_FINISH)
    end
    return nil, nil, nil, maxSpeed
end
