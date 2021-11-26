--- Draws the navigation cost around a set position target for a semi automatic helper.
NavigationCostPlot = CpObject()


---@param map table inGame map to draw on.
function NavigationCostPlot:init(map)
	self.map = map
	self.overlayId = createImageOverlay('dataS/scripts/shared/graph_pixel.dds')
	
	self.isVisible = true
	self.color = {42, 193, 237}
end

function NavigationCostPlot:normalizeRgb(r, g, b)
	return r / 255, g / 255, b / 255
end

function NavigationCostPlot:delete()
	if self.overlayId ~= 0 then
		delete(self.overlayId)
	end
end

function NavigationCostPlot:setVisible( isVisible )
	self.isVisible = isVisible
end

function NavigationCostPlot:worldToScreen( worldX, worldZ )
	local objectX = (worldX + self.map.worldCenterOffsetX) / self.map.worldSizeX * 0.5 + 0.25
	local objectZ = (worldZ + self.map.worldCenterOffsetZ) / self.map.worldSizeZ * 0.5 + 0.25
	local x, y, _, _ = self.map.fullScreenLayout:getMapObjectPosition(objectX, objectZ, 0, 0, 0, true)
	return x, y
end

function NavigationCostPlot:screenToWorld( objectX, objectZ )
	local worldX = (objectX - 0.25) * 2 * self.map.worldSizeX - self.map.worldCenterOffsetX
	local worldZ = (objectZ - 0.25) * 2 * self.map.worldSizeZ - self.map.worldCenterOffsetZ
	return worldX, worldZ
end

function NavigationCostPlot:draw()
	if not self.isVisible then return end
	local lineThickness = 2 / g_screenHeight -- 2 pixels
	local aiSystem = g_currentMission.aiSystem
	local cellSizeHalf = aiSystem.cellSizeMeters * 0.5
	local terrainSizeHalf = g_currentMission.terrainSize * 0.5
	local range = 20 * aiSystem.cellSizeMeters

	local job = g_currentMission.inGameMenu.pageAI.currentJob
	if job then 
		for _,g in pairs(job.groupedParameters) do 
			for _,p in pairs(g:getParameters()) do 
				if p:getType() == AIParameterType.POSITION_ANGLE then 
					local x,z = p:getPosition()
					if x and z then 
						local dx = math.floor(x / aiSystem.cellSizeMeters) * aiSystem.cellSizeMeters + cellSizeHalf
						local dz = math.floor(z / aiSystem.cellSizeMeters) * aiSystem.cellSizeMeters + cellSizeHalf
						local minX = math.max(dx - range, -terrainSizeHalf + cellSizeHalf)
						local minZ = math.max(dz - range, -terrainSizeHalf + cellSizeHalf)
						local maxX = math.min(dx + range, terrainSizeHalf - cellSizeHalf)
						local maxZ = math.min(dz + range, terrainSizeHalf - cellSizeHalf)

						for stepZ = minZ, maxZ, aiSystem.cellSizeMeters do
							for stepX = minX, maxX, aiSystem.cellSizeMeters do
								local worldPosX = stepX
								local worldPosY = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, stepX, 0, stepZ)
								local worldPosZ = stepZ
								local cost, isBlocking = getVehicleNavigationMapCostAtWorldPos(aiSystem.navigationMap, worldPosX, worldPosY, worldPosZ)
								local color = aiSystem.debug.colors.default
								
								if isBlocking then
									color = aiSystem.debug.colors.blocking
								else
									local r, g, b = Utils.getGreenRedBlendedColor(cost / 255)
									color[1] = r
									color[2] = g
									color[3] = b
								end
								local mapX,mapZ = self:worldToScreen(worldPosX,worldPosZ)
								local r,g,b = unpack(color)
								setOverlayColor( self.overlayId,r,g,b, 0.5 )
								renderOverlay( self.overlayId, mapX, mapZ,lineThickness , lineThickness )
							end
						end
								
					end
				end
			end
		end	
	end
end