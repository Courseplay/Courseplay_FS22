
--[[
	Simple calculation of the remaining time for the course.

	- The optimal time is calculated by the course length divided by the max of the work speed or field work speed setting.
	- Every turn adds a flat turn penalty to the course length. Reduced by the course progress with a logarithm. (0 <-> ln(3)[~1.098..] )
	- Global exponential factor applied to the course, depending on the progress left. (1 <-> e[~2.718..])

]]--
---@class CpRemainingTime
CpRemainingTime = CpObject()
CpRemainingTime.DISABLED_TEXT = ""
CpRemainingTime.TURN_PENALTY = 20 -- Flat turn penalty
CpRemainingTime.EXP_PENALTY_REDUCTION = 0.3 -- Reduces the impact of the exponential penalty.

function CpRemainingTime:init(vehicle)
	self.vehicle = vehicle
	self:reset()
end

function CpRemainingTime:reset()
	self:setText(self.DISABLED_TEXT)
	self.time = 0
end

function CpRemainingTime:update(dt)

end

function CpRemainingTime:calculate(course, ix)
	local time = self:getRemainingCourseTime(course, ix)
	self:applyTime(time)
end

--- Get the max speed for the field work. Depending on the max work speed and the field work speed.
function CpRemainingTime:getOptimalSpeed() -- in m/s
	local fieldSettingSpeed = self.vehicle:getCpSettings().fieldWorkSpeed:getValue()
	return MathUtil.kmhToMps(MathUtil.clamp(self.vehicle:getSpeedLimit(), 0, fieldSettingSpeed))
end 

--- Estimate of the course time left with penalties increased.
function CpRemainingTime:getRemainingCourseTime(course, ix) -- in seconds 
	local optimalTime = self:getOptimalCourseTime(course, ix)

    return optimalTime * math.exp(1-course:getProgress(ix)) * self.EXP_PENALTY_REDUCTION
		   + course.totalTurns * self.TURN_PENALTY * math.log(course:getProgress(ix) * 2 + 1)
end

--- Optimal course time, where no additional turn times are included.
function CpRemainingTime:getOptimalCourseTime(course, ix)
	local speed = self:getOptimalSpeed()
	local length = course:getLength()
    local dx = course:getProgress(ix)
	return ((1-dx) * length) / speed
end

function CpRemainingTime:getText()
	return self.text
end

function CpRemainingTime:setText(text)
	self.text = text
end

function CpRemainingTime:applyTime(time)
	if self:getOptimalSpeed() == 0 then 
		return 
	end
	self.text = CpGuiUtil.getFormatTimeText(time or 0)
	self.time = time
end