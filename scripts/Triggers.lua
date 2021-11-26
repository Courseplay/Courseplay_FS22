--- Global container for direct access to triggers.
---@class CpTriggers
CpTriggers = {
	bunkerSilos = {}
}
function CpTriggers.addBunkerSilo(silo,superFunc,...)
	local returnValue = superFunc(silo,...)
	local triggerNode = silo.interactionTriggerNode
	CpTriggers.bunkerSilos[triggerNode] = silo
	return returnValue

end
BunkerSilo.load = Utils.overwrittenFunction(BunkerSilo.load,CpTriggers.addBunkerSilo)

function CpTriggers.removeBunkerSilo(silo)
	local triggerNode = silo.interactionTriggerNode
	CpTriggers.bunkerSilos[triggerNode] = nil
end
BunkerSilo.delete = Utils.prependedFunction(BunkerSilo.delete,CpTriggers.removeBunkerSilo)


function CpTriggers.getBunkerSilos()
	return CpTriggers.bunkerSilos	
end

--- These functions are still WIP.
---@class BunkerSiloUtil
BunkerSiloUtil = {}

function BunkerSiloUtil.findBunkerSiloAtPosition(x,z,xDir,zDir)
	for _,silo in pairs(CpTriggers.getBunkerSilos()) do 
		local area = silo.bunkerSiloArea
		local x1,z1 = area.sx,area.sz
		local x2,z2 = area.wx,area.wz
		local x3,z3 = area.hx,area.hz
		local tx,tz = x +10*xDir,z+10*zDir
		if MathUtil.hasRectangleLineIntersection2D(x1,z1,x2-x1,z2-z1,x3-x1,z3-z1,x,z,tx-x,tz-z) then 
			return silo
		end
	end
end

function BunkerSiloUtil.getStartPointFromVehiclePos(silo,x,z,workWidth)
	local area = silo.bunkerSiloArea
	local distStart = MathUtil.getPointPointDistance(x,z,area.sx,area.sz)
	local distEnd = MathUtil.getPointPointDistance(x,z,area.hx,area.hz)
	local isInverted = false
	if distStart>distEnd then 
		isInverted = true	
	end
	local x,z = BunkerSiloUtil.getStartPositionWithMostFillLevel(silo,workWidth)
	local dirX,dirZ = area.dhx_norm,area.dhz_norm
	if isInverted then 
		local length = MathUtil.getPointPointDistance(area.sx,area.sz,area.hx,area.hz)
		x,z = x+length*area.dhx_norm,z+length*area.dhz_norm
		dirX,dirZ = -dirX,-dirZ
	end
	return x,z,dirX,dirZ
end

function BunkerSiloUtil.getStartPositionWithMostFillLevel(silo,workWidth)
	local area = silo.bunkerSiloArea
	local width = MathUtil.getPointPointDistance(area.sx,area.sz,area.wx,area.wz)
	local numLines = math.max(width/workWidth)
	local offset = width/numLines
	local x0,z0 = area.sx,area.sz
	local maxFillLevel,x,z = 0,x0+width/2*area.dwx_norm,z0+width/2*area.dwz_norm
	for i = 1,numLines do 
		local x1 = area.sx + i*width * area.dwx_norm
		local z1 = area.sz + i*width * area.dwz_norm
		local x2 = area.hx + i*width * area.dwx_norm
		local z2 = area.hz + i*width * area.dwz_norm

		local fillType = DensityMapHeightUtil.getFillTypeAtArea(x0, z0, x1, z1, x2, z2)
		local fillLevel = DensityMapHeightUtil.getFillLevelAtArea(fillType, x0, z0, x1, z1, x2, z2)
		if fillLevel > maxFillLevel then 
			maxFillLevel = fillLevel
			x = x0 + width/2 * area.dwx_norm
			z = z0 + width/2 * area.dwz_norm
		end
		x0,z0 = x1,z1
	end
	return x,z
end

function BunkerSiloUtil.getEndPositionFromStartPositionAndDirection(silo,x,z,xDir,zDir,offset)
	local area = silo.bunkerSiloArea
	local length = MathUtil.getPointPointDistance(area.sx,area.sz,area.hx,area.hz)
	return x + (length-offset)*xDir,z + (length-offset)*zDir
end