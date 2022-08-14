--- Controls moveable pipes and raises the base pipe rod to the maximum.
---@class PipeController : ImplementController
PipeController = CpObject(ImplementController)
PipeController.MAX_ROT_SPEED = 0.6
PipeController.MIN_ROT_SPEED = 0.1

function PipeController:init(vehicle, implement)
    ImplementController.init(self, vehicle, implement)
    self.pipeSpec = self.implement.spec_pipe
	self.cylinderedSpec = self.implement.spec_cylindered
	self.validMovingTools = {}
	if self.cylinderedSpec and self.pipeSpec.numAutoAimingStates <=0 then
		for i, m in ipairs(self.cylinderedSpec.movingTools) do 
			-- Gets only the pipe moving tools.
			if m.freezingPipeStates ~=nil and next(m.freezingPipeStates)~=nil then
				table.insert(self.validMovingTools, m)
			end
		end
	end
	self.hasPipeMovingTools = #self.validMovingTools > 0
end

function PipeController:update(dt)
	if self.hasPipeMovingTools then
		if self.pipeSpec.unloadingStates[self.pipeSpec.currentState] == true then 
			for i, m in ipairs(self.validMovingTools) do 
				-- Only move the base pipe rod.
				if #m.dependentAnimations <=0  then
					self:movePipeUp(m, dt)
					return
				end
			end
		end
	end
end

function PipeController:movePipeUp(tool, dt)	
	local rotTarget = tool.invertAxis and tool.rotMin or tool.rotMax 
	ImplementUtil.moveMovingToolToRotation(self.implement, tool, dt, rotTarget)
end
