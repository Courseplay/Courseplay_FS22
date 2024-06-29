--- An index to be used to address vertices in a polygon. It has
--- addition/subtraction and can wrap around the ends once.

local WrapAroundIndex = CpObject()
---@param t table
---@param ix number value to set the index to
function WrapAroundIndex:init(t, ix)
    self.t = t
    self:set(ix)
end

function WrapAroundIndex:set(ix)
    if ix > #self.t then
        self.ix = ix - #self.t
    elseif ix < 1 then
        self.ix = ix + #self.t
    else
        self.ix = ix
    end
end

function WrapAroundIndex:inc(y)
    self:set(self.ix + (y or 1))
end

function WrapAroundIndex:dec(y)
    self:set(self.ix - (y or 1))
end

function WrapAroundIndex:get()
    return self.ix
end

function WrapAroundIndex.__add(a, b)
    a:inc(b)
    return a
end

function WrapAroundIndex.__sub(a, b)
    a:dec(b)
    return a
end

---@class CourseGenerator.WrapAroundIndex
CourseGenerator.WrapAroundIndex = WrapAroundIndex