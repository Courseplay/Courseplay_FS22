---@class FoldableController : ImplementController
FoldableController = CpObject(ImplementController)

function FoldableController:init(vehicle,implement)
    ImplementController.init(self, vehicle, implement)
end

local function fold(implement,superFunc,...)
	if superFunc ~= nil then superFunc(implement,...) end
	implement:setFoldState(-1, false)
end
Foldable.onAIImplementEndLine = Utils.overwrittenFunction(Foldable.onAIImplementStartLine,fold)
Foldable.onAIImplementEnd = Utils.overwrittenFunction(Foldable.onAIImplementStartLine,fold)
