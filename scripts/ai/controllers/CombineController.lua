--- For now only handles possible silage additives, if needed.
--- TODO: Straw swath handling should be moved here.
---@class CombineController : ImplementController
CombineController = CpObject(ImplementController)
function CombineController:init(vehicle, forageWagon)
    ImplementController.init(self, vehicle, forageWagon)
    self.combineSpec = forageWagon.spec_combine
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
