
--- Draws the bunker silo walls on the ai inGame menu map.
BunkerSiloPlot = CpObject()

---@param map table inGame map to draw on.
function BunkerSiloPlot:init(map)
	self.map = map
	self.overlayId = createImageOverlay('dataS/scripts/shared/graph_pixel.dds')
	self.isVisible = true
	self.color = {42, 193, 237}
end

function BunkerSiloPlot:normalizeRgb(r, g, b)
	return r / 255, g / 255, b / 255
end

function BunkerSiloPlot:delete()
	if self.overlayId ~= 0 then
		delete(self.overlayId)
	end
end

function BunkerSiloPlot:setVisible( isVisible )
	self.isVisible = isVisible
end

function BunkerSiloPlot:worldToScreen( worldX, worldZ )
	local objectX = (worldX + self.map.worldCenterOffsetX) / self.map.worldSizeX * 0.5 + 0.25
	local objectZ = (worldZ + self.map.worldCenterOffsetZ) / self.map.worldSizeZ * 0.5 + 0.25
	local x, y, _, _ = self.map.fullScreenLayout:getMapObjectPosition(objectX, objectZ, 0, 0, 0, true)
	return x, y
end

function BunkerSiloPlot:screenToWorld( x, y )
	local worldX = ((x - self.x) / self.scaleX) - self.worldOffsetX
	local worldZ = ((y - self.y - self.height) / -self.scaleZ) - self.worldOffsetZ
	return worldX, worldZ
end


function BunkerSiloPlot:draw()
	if not self.isVisible then return end
	local lineThickness = 2 / g_screenHeight -- 2 pixels
	local r, g, b = self:normalizeRgb(42, 193, 237)
	local dx, dz, dx2D, dy2D, width, rotation
	for _,silo in pairs(CpTriggers.getBunkerSilos()) do 
		local area = silo.bunkerSiloArea
		local sx, sz = self:worldToScreen( area.sx, area.sz )
		local wx, wz = self:worldToScreen( area.wx, area.wz )
		local hx, hz = self:worldToScreen( area.hx, area.hz )
		local dhx_norm,dhz_norm = area.dhx_norm, area.dhz_norm 
		local dwx_norm,dwz_norm = area.dwx_norm, area.dwz_norm 
		-- render only if it is on the plot area
		if sx and sz and wx and wz and hx and hz then
			dx2D = hx - sx
			dy2D = ( hz - sz ) / g_screenAspectRatio
			width = MathUtil.vector2Length(dx2D, dy2D)
			dx = hx - sx
			dz = hz - sz
			rotation = MathUtil.getYRotationFromDirection(dx*dhx_norm, dz*dhz_norm) - math.pi * 0.5
			setOverlayColor( self.overlayId, r, g, b, 1 )
			setOverlayRotation( self.overlayId, rotation, 0, 0 )
			renderOverlay( self.overlayId, sx, sz, width, lineThickness )


			renderOverlay( self.overlayId, sx + (sx-wx)*dwx_norm, sz + (sz-wz)*dwz_norm, width, lineThickness )
		end
	end
end