---@class MovingAverage
MovingAverage = CpObject()

--- A simple moving average over n values
---@param n number number of values to calculate the moving average
function MovingAverage:init(n)
    self.n = n
    self.values = {}
    self.avg = nil
end

--- Add a value to the moving average and recalculate
---@param value number new value
---@return number moving average after value is added
function MovingAverage:update(value)
    table.insert(self.values, value)
    if #self.values > self.n then
        -- once we have enough values, we can avoid looping through all
        local oldestValue = table.remove(self.values, 1)
        self.avg = self.avg + (value - oldestValue) / self.n
    else
        local total = 0
        for _, v in ipairs(self.values) do
            total = total + v
        end
        self.avg = total / #self.values
    end
    return self.avg
end

function MovingAverage:get()
    return self.avg
end

