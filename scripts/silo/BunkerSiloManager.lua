--- Links all placed bunker silos to the silo wrappers.
BunkerSiloManager = CpObject()

function BunkerSiloManager:init()
	self.silos = {}	
end

function BunkerSiloManager:addBunkerSilo(silo)
	local triggerNode = silo.interactionTriggerNode
	if triggerNode then
		self.silos[triggerNode] = CpBunkerSilo(silo)
	end
end

function BunkerSiloManager:removeBunkerSilo(silo)
	local triggerNode = silo.interactionTriggerNode
	if triggerNode and self.silos[triggerNode] then
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

---@class BunkerSiloManagerUtil
BunkerSiloManagerUtil = {}
BunkerSiloManagerUtil.debugChannel = CpDebug.DBG_SILO

function BunkerSiloManagerUtil.debug(...)
	CpUtil.debugFormat(BunkerSiloManagerUtil.debugChannel, ...)	
end

---Checks for heaps between two points
---@param node number StartPoint
---@param xOffset number 
---@param length number SearchLength
---@param zOffset number StartOffset
---@return boolean found heap?
---@return CpHeapBunkerSilo
function BunkerSiloManagerUtil.createHeapBunkerSilo(node, xOffset, length, zOffset)
	local p1x, p1y, p1z = localToWorld(node, xOffset, 0, zOffset)
	local p2x, p2y, p2z = localToWorld(node, xOffset, 0, length)
	local heapFillType = DensityMapHeightUtil.getFillTypeAtLine(p1x, p1y, p1z, p2x, p2y, p2z, 5)
	if heapFillType == nil or heapFillType == FillType.UNKNOWN then 
		BunkerSiloManagerUtil.debug("Heap not found!")
		return false, nil
	end
	length = length - zOffset
	local _, yRot, _ = getRotation(node)

	--create temp node 
	local point = CpUtil.createNode("cpTempHeapFindingPoint", p1x, p1z, yRot, nil)
	
	-- move the line to find out the size of the heap
	
	--find maxX 
	local stepSize = 0.1
	local searchWidth = 0.1
	local maxX = 0
	local tempStartX, tempStartY, tempStartZ, tempHeightX, tempHeightY, tempHeightZ = 0, 0, 0, 0, 0, 0
	for i=stepSize, 250, stepSize do
		tempStartX, tempStartY, tempStartZ = localToWorld(point, i, 0, 0)
		tempHeightX, tempHeightY, tempHeightZ= localToWorld(point, i, 0, length*2)
		local fillType = DensityMapHeightUtil.getFillTypeAtLine(tempStartX, tempStartY, tempStartZ, tempHeightX, tempHeightY, tempHeightZ, searchWidth)
		--print(string.format("fillType:%s distance: %.1f", tostring(fillType), i))	
		if fillType ~= heapFillType then
			maxX = i-stepSize
			BunkerSiloManagerUtil.debug("maxX = %.2f", maxX)
			break
		end
	end
	
	--find minX 
	local minX = 0
	local tempStartX, tempStartZ, tempHeightX, tempHeightZ = 0, 0, 0, 0;
	for i=stepSize, 250, stepSize do
		tempStartX, tempStartY, tempStartZ = localToWorld(point, -i, 0, 0)
		tempHeightX, tempHeightY, tempHeightZ= localToWorld(point, -i, 0, length*2)
		local fillType = DensityMapHeightUtil.getFillTypeAtLine(tempStartX, tempStartY, tempStartZ, tempHeightX, tempHeightY, tempHeightZ, searchWidth)
		--print(string.format("fillType:%s distance: %.1f", tostring(fillType), i))	
		if fillType ~= heapFillType then
			minX = i-stepSize
			BunkerSiloManagerUtil.debug("minX = %.2f", minX)
			break
		end
	end
	
	--find minZ and maxZ
	local foundHeap = false
	local minZ, maxZ = 0, 0
	for i=0, 250, stepSize do
		tempStartX, tempStartY, tempStartZ = localToWorld(point, maxX, 0, i)
		tempHeightX, tempHeightY, tempHeightZ= localToWorld(point, -minX, 0, i)
		local fillType = DensityMapHeightUtil.getFillTypeAtLine(tempStartX, tempStartY, tempStartZ, tempHeightX, tempHeightY, tempHeightZ, searchWidth)
		if not foundHeap then
			if fillType == heapFillType then
				foundHeap = true
				minZ = i-stepSize
				BunkerSiloManagerUtil.debug("minZ = %.2f", minZ)
			end
		else
			if fillType ~= heapFillType then
				maxZ = i-stepSize+1
				BunkerSiloManagerUtil.debug("maxZ = %.2f", maxZ)
				break
			end
		end	
	end
	
	--set found values into bunker table and return it
	local sx, _, sz = localToWorld(point, maxX, 0, minZ)
	local wx, _, wz = localToWorld(point, -minX, 0, minZ)
	local hx, _, hz = localToWorld(point, maxX, 0, maxZ)
	local bunker = CpHeapBunkerSilo(sx, sz, wx, wz, hx, hz)
	local fillLevel = DensityMapHeightUtil.getFillLevelAtArea(heapFillType, sx, sz, wx, wz, hx, hz)
	BunkerSiloManagerUtil.debug("Heap found with %s(%d) and fillLevel: %.2f", g_fillTypeManager:getFillTypeByIndex(heapFillType).title, heapFillType, fillLevel)

	CpUtil.destroyNode(point)

	return true, bunker
end