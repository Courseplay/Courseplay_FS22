--- For now only activates optional sowing machines, for example a roller with a sowing machine configuration.
---@class SowingMachineController : ImplementController
SowingMachineController = CpObject(ImplementController)

function SowingMachineController:init(vehicle, implement)
    ImplementController.init(self, vehicle, implement)
    self.sowingMachineSpec = self.implement.spec_sowingMachine
	self.settings = vehicle:getCpSettings()
end

function SowingMachineController:onLowering()
	if not self.implement:getIsTurnedOn() and self.settings.optionalSowingMachineEnabled:getValue() then 
    	self.implement:setIsTurnedOn(true)
	end
end

function SowingMachineController:onFinished()
    self.implement:setIsTurnedOn(false)
end