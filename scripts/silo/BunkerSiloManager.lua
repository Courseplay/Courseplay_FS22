--- Links all placed bunker silos to the silo wrappers.
BunkerSiloManager = CpObject()

function BunkerSiloManager:init()
	self.silos = {}	
end

function BunkerSiloManager:addBunkerSilo(silo)
	local triggerNode = silo.interactionTriggerNode
	self.silos[triggerNode] = CpBunkerSilo(silo)
end

function BunkerSiloManager:removeBunkerSilo(silo)
	local triggerNode = silo.interactionTriggerNode
	if self.silos[triggerNode] then
		self.silos[triggerNode]:delete()
		self.silos[triggerNode] = nil
	end
end

function BunkerSiloManager:drawSilos(map, selectedBunkerSilo)
	for _, silo in pairs(self.silos) do 
		silo:drawPlot(map, selectedBunkerSilo)
	end
end

--- Gets a bunker silo at a given position.
---@param tx number
---@param tz number
---@return boolean bunker silo was found ?
---@return BunkerSilo
function BunkerSiloManager:getBunkerSiloAtPosition(tx, tz)
	if tx == nil or tz == nil then 
		return false, nil
	end
	for _, silo in pairs(self.silos) do 
		if silo:isPointInSilo(tx, tz) then 
			return true, silo
		end
	end
	return false, nil
end

function BunkerSiloManager:getSiloWrapperByNode(node)
	return node and self.silos[node]
end

function BunkerSiloManager:update(dt)
	for _, silo in pairs(self.silos) do 
		silo:update(dt)
	end
end

function BunkerSiloManager:draw(dt)
	if CpDebug:isChannelActive(CpDebug.DBG_SILO) then
		for _, silo in pairs(self.silos) do 
			silo:draw(dt)
		end
	end
end


g_bunkerSiloManager = BunkerSiloManager()

local function addBunkerSilo(silo, superFunc, ...)
	local ret = superFunc(silo, ...)
	g_bunkerSiloManager:addBunkerSilo(silo)
	return ret
end

BunkerSilo.load = Utils.overwrittenFunction(BunkerSilo.load, addBunkerSilo)


local function removeBunkerSilo(silo, ...)
	g_bunkerSiloManager:removeBunkerSilo(silo)
end

BunkerSilo.delete = Utils.prependedFunction(BunkerSilo.delete, removeBunkerSilo)

