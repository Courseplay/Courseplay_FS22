--- For now empty.
---@class PickupController : ImplementController
PickupController = CpObject(ImplementController)

function PickupController:init(vehicle, implement)
    ImplementController.init(self, vehicle, implement)
    self.pickupSpec = self.implement.spec_pickup
end

function PickupController:onLowering()
    self.implement:aiImplementStartLine()
end

function PickupController:onRaising()
    self.implement:aiImplementEndLine()
end
