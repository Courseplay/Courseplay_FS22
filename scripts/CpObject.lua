--[[
This file is part of Courseplay (https://github.com/Courseplay/courseplay)
Copyright (C) 2018 Peter Vajko

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

-- Class implementation stolen from http://lua-users.org/wiki/SimpleLuaClasses

---@class CpObject
function CpObject(base, init)
	local c = {}    -- a new class instance
	if not init and type(base) == 'function' then
		init = base
		base = nil
	elseif type(base) == 'table' then
		-- our new class is a shallow copy of the base class!
		for i,v in pairs(base) do
			c[i] = v
		end
		c._base = base
	end
	-- the class will be the metatable for all its objects,
	-- and they will look up their methods in it.
	c.__index = c

	-- expose a constructor which can be called by <classname>(<args>)
	local mt = {}
	mt.__call = function(class_tbl, ...)
		local obj = {}
		setmetatable(obj, c)
		if class_tbl.init then
			class_tbl.init(obj,...)
		else
			-- make sure that any stuff from the base class is initialized!
			if base and base.init then
				base.init(obj, ...)
			end
		end
		return obj
	end
	c.init = init
	c.is_a = function(self, klass)
		local m = getmetatable(self)
		while m do
			if m == klass then return true end
			m = m._base
		end
		return false
	end
	setmetatable(c, mt)
	return c
end

--- Object that holds a value temporarily. You can tell when to set the value and how long it should keep that
--- value, in milliseconds. Great for timers.
---@class CpTemporaryObject
CpTemporaryObject = CpObject()

function CpTemporaryObject:init(valueWhenExpired)
	self.valueWhenExpired = valueWhenExpired
	self:reset()
end

--- Set temporary value for object
---@param value any the temporary value
---@param expiryMs number for expiryMs milliseconds after startMs, the object will return the value set above,
--- valueWhenExpired otherwise. When nil, it'll remain value forever
---@param startMs number after starMs milliseconds from now, the object will return the value set above
--- (for expiryMs milliseconds). When not nil, the value is set immediately.
function CpTemporaryObject:set(value, expiryMs, startMs)
	self.value = value
	self.startTime = startMs and g_time + startMs or g_time
	self.expiryTime = expiryMs and self.startTime + expiryMs or math.huge
end

--- Get the value of the temporary object
--- Returns the value set if the current time is between the start time end expiry time, otherwise the default value
function CpTemporaryObject:get()
	if g_time < self.startTime or g_time > self.expiryTime then
		-- value not yet due or already expired
		return self.valueWhenExpired
	else
		return self.value
	end
end

--- Is the object waiting for the startTime (set() has been called, but value not set yet)
function CpTemporaryObject:isPending()
	return g_time < self.startTime
end

--- Resets the object.
function CpTemporaryObject:reset()
	self.expiryTime = g_time
	self.value = self.valueWhenExpired
	self.expiryTime = g_time
	self.startTime = g_time
end

--- Object slowly adjusting its value
---@class CpSlowChangingObject
CpSlowChangingObject = CpObject()

function CpSlowChangingObject:init(targetValue, timeToReachTargetMs)
	self.value = targetValue
	self:set(targetValue, timeToReachTargetMs)
end

function CpSlowChangingObject:set(targetValue, timeToReachTargetMs)
	self.previousValue = self.value
	self.targetValue = targetValue
	self.targetValueMs = g_time
	self.timeToReachTargetMs = timeToReachTargetMs or 1
end

function CpSlowChangingObject:get()
	local age = g_time - self.targetValueMs
	if age < self.timeToReachTargetMs then
		-- not reaped yet, return a value proportional to the time until ripe
		self.value = self.previousValue + (self.targetValue - self.previousValue) * age / self.timeToReachTargetMs
	else
		self.value = self.targetValue
	end
	return self.value
end

