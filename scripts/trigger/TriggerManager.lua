--- Links all the needed trigger, except bunker silos to trigger wrappers.
TriggerManager = CpObject()

function TriggerManager:init()
	self.unloadSilos = {}
end

function TriggerManager:addUnloadingSilo(silo)
	if silo.exactFillRootNode ~= nil then 
		self.unloadSilos[silo.exactFillRootNode] = CpTrigger(silo, silo.exactFillRootNode)
	end
end

function TriggerManager:removeUnloadingSilo(silo)
	if silo.exactFillRootNode ~= nil then 
		if self.unloadSilos[silo.exactFillRootNode] then
			self.unloadSilos[silo.exactFillRootNode]:delete()
			self.unloadSilos[silo.exactFillRootNode] = nil
		end
	end
end

function TriggerManager:getUnloadTriggerForNode(node)
	return self.unloadSilos[node]
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

