--- Dummy mower controller (for now), mostly it is just housing the updateMowerArea override
--- Was created in the hope that calling clearAITerrainDetailRequiredRange() as suggested by
--- Stefan @Giants will fix the issue, but that did not work out.
---@class MowerController : ImplementController
MowerController = CpObject(ImplementController)

function MowerController:init(vehicle, mower)
    self.mower = mower
    ImplementController.init(self, vehicle, self.mower)
    self:debug('Mower controller initialized')
end

-- Override the limitToField parameter to false always. The Mower spec sets this to true when the AI is active, preventing
-- the Giants helper to mow grass outside of a field. With this override, the Giants helper will also mow grass
-- outside of the field, although it won't drive off the field, only when the mower is above a non-field grass area,
-- it'll cut the grass there
local oldFunc = FSDensityMapUtil.updateMowerArea
FSDensityMapUtil.updateMowerArea = function(fruitType, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, limitToField)
    return oldFunc(fruitType, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, false)
end

--- For some reason the animations are not working for an ai driven hand mower..
--- So we disable them to avoid errors.
local function postAnimationUpdate(vehicle, superFunc, ...)
    if vehicle.getIsCpActive and vehicle:getIsCpActive() then 
        --- Currently CP is driving and the animations can't be played.
        return
    end
    return superFunc(vehicle, ...)
end
PushHandTool.postAnimationUpdate = Utils.overwrittenFunction(PushHandTool.postAnimationUpdate, postAnimationUpdate)
