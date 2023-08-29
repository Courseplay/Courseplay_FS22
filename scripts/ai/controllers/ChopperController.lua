-- A subclass of the combine controller to provide clean separation between Chopper specific functions and combine functions
-- Due to the interrelated nature of choppers and combines we should inherit the combine controller class
-- Chopper Support Added By Pops64 2023
---@class ChopperController : CombineController

ChopperController = CpObject(CombineController)

function ChopperController:init(vehicle, combine)
    CombineController.init(self, vehicle, combine)
end

-------------------------------------------------------------
--- Chopper
-------------------------------------------------------------

function ChopperController:getChopperDischargeDistance()
    local dischargeNode = self.implement:getCurrentDischargeNode()
    if self:isChopper() and dischargeNode and dischargeNode.maxDistance then
        return dischargeNode.maxDistance
    end
end

function ChopperController:isChopper()
    return self:getCapacity() > 10000000
end

function ChopperController:updateChopperFillType()
    --- Not exactly sure what this does, but without this the chopper just won't move.
    --- Copied from AIDriveStrategyCombine:update()
    -- no pipe, no discharge node
    local capacity = 0
    local dischargeNode = self.implement:getCurrentDischargeNode()

    if dischargeNode ~= nil then
        capacity = self.implement:getFillUnitCapacity(dischargeNode.fillUnitIndex)
    end

    if capacity == math.huge then
        local rootVehicle = self.implement.rootVehicle

        if rootVehicle.getAIFieldWorkerIsTurning ~= nil and not rootVehicle:getAIFieldWorkerIsTurning() then
            local trailer = NetworkUtil.getObject(self.implement.spec_pipe.nearestObjectInTriggers.objectId)

            if trailer ~= nil then
                local trailerFillUnitIndex = self.implement.spec_pipe.nearestObjectInTriggers.fillUnitIndex
                local fillType = self.implement:getDischargeFillType(dischargeNode)

                if fillType == FillType.UNKNOWN then
                    fillType = trailer:getFillUnitFillType(trailerFillUnitIndex)

                    if fillType == FillType.UNKNOWN then
                        fillType = trailer:getFillUnitFirstSupportedFillType(trailerFillUnitIndex)
                    end

                    self.implement:setForcedFillTypeIndex(fillType)
                else
                    self.implement:setForcedFillTypeIndex(nil)
                end
            end
        end
    end
end