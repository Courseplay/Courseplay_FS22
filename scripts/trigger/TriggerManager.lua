--- Links all the needed trigger, except bunker silos to trigger wrappers.
---@class TriggerManager
TriggerManager = CpObject()

function TriggerManager:init()
	---@type table<number,CpTrigger>
	self.unloadTriggers = {}
	---@type table<number,CpTrigger>
	self.dischargeableUnloadTriggers = {}
end

function TriggerManager:addUnloadingSilo(silo)
	if silo.exactFillRootNode ~= nil then 
		self.unloadTriggers[silo.exactFillRootNode] = CpTrigger(silo, silo.exactFillRootNode)
		if silo:getIsToolTypeAllowed(ToolType.DISCHARGEABLE) then 
			self.dischargeableUnloadTriggers[silo.exactFillRootNode] = self.unloadTriggers[silo.exactFillRootNode]
		end
	end
end

function TriggerManager:removeUnloadingSilo(silo)
	if silo.exactFillRootNode ~= nil then 
		if self.unloadTriggers[silo.exactFillRootNode] then
			self.unloadTriggers[silo.exactFillRootNode]:delete()
			self.unloadTriggers[silo.exactFillRootNode] = nil
			self.dischargeableUnloadTriggers[silo.exactFillRootNode] = nil
		end
	end
end

function TriggerManager:getUnloadTriggerForNode(node)
	return self.unloadTriggers[node]
end

--- Gets the first trigger found in the defined area.
---@param triggers table<number,CpTrigger>
---@param x number
---@param z number
---@param dirX number
---@param dirZ number
---@param width number
---@param length number
---@return boolean
---@return table|nil
---@return table|nil
function TriggerManager:getTriggerAt(triggers, x, z, dirX, dirZ, width, length)
	local angle = MathUtil.getYRotationFromDirection(dirX, dirZ)
	local dirWX, dirWZ = MathUtil.getDirectionFromYRotation(angle + math.pi/2)
	local sx, sz = x + dirWX * width/2, z + dirWZ * width/2
	
	local area = {
		{
			x = sx,
			z = sz
		},
		{
			x = sx - dirWX * width,
			z = sz - dirWZ * width
		},
		{
			x = sx - dirWX * width + dirX * length,
			z = sz - dirWZ * width + dirZ * length
		},
		{
			x = sx + dirX * length,
			z = sz + dirZ * length
		},
		{
			x = sx,
			z = sz
		},
	}
	local dx, _, dz
	for node, trigger in pairs(triggers) do 
		dx, _, dz  = getWorldTranslation(node)
		if CpMathUtil.isPointInPolygon(area, dx, dz) then 
			return true, trigger, trigger:getTrigger():getTarget()
		end
	end
	return false
end

--- Gets the first unload trigger found in the defined area.
---@param x number
---@param z number
---@param dirX number
---@param dirZ number
---@param width number
---@param length number
---@return boolean
---@return table|nil
---@return table|nil
function TriggerManager:getUnloadTriggerAt(x, z, dirX, dirZ, width, length)
	return self:getTriggerAt(self.unloadTriggers, x, z, dirX, dirZ, width, length)
end

--- Gets the first dischargeable unload trigger found in the defined area.
---@param x number
---@param z number
---@param dirX number
---@param dirZ number
---@param width number
---@param length number
---@return boolean
---@return table|nil
---@return table|nil
function TriggerManager:getDischargeableUnloadTriggerAt(x, z, dirX, dirZ, width, length)
	return self:getTriggerAt(self.dischargeableUnloadTriggers, x, z, dirX, dirZ, width, length)
end

function TriggerManager:update(dt)
	
end

--- Draws all bunker silos onto the ai map.
---@param map table map to draw to.
---@param selected CpTrigger silo that gets highlighted.
function TriggerManager:drawUnloadTriggers(map, selected)
	for _, trigger in pairs(self.unloadTriggers) do 
		trigger:drawPlot(map, selected)
	end
end

--- Draws all bunker silos onto the ai map.
---@param map table map to draw to.
---@param selected CpTrigger silo that gets highlighted.
function TriggerManager:drawDischargeableTriggers(map, selected)
	for _, trigger in pairs(self.dischargeableUnloadTriggers) do 
		trigger:drawPlot(map, selected)
	end
end

function TriggerManager:draw()
	for node, trigger in pairs(self.unloadTriggers) do 
		local text = string.format("%s:\n %d", getName(node), node )
		CpUtil.drawDebugNode(node, false, 2, text)
	end
end

g_triggerManager = TriggerManager()

local function addUnloadingSilo(silo, superFunc, ...)
	local ret = superFunc(silo, ...)
	g_triggerManager:addUnloadingSilo(silo)
	return ret
end

UnloadTrigger.load = Utils.overwrittenFunction(UnloadTrigger.load, addUnloadingSilo)


local function removeUnloadingSilo(silo, ...)
	g_triggerManager:removeUnloadingSilo(silo)
end

UnloadTrigger.delete = Utils.prependedFunction(UnloadTrigger.delete, removeUnloadingSilo)

