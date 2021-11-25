--[[
This file is part of Courseplay (https://github.com/Courseplay/courseplay)
Copyright (C) 2019 Peter Vaiko

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
--- Development helper utilities to easily test and diagnose things.
--- To test the pathfinding:
--- 1. mark the start location/heading with Alt + <
--- 2. mark the goal location/heading with Alt + >
--- 3. watch the path generated ...
--- 4. use Ctrl + > to regenerate the path
---
--- Also showing field/fruit/collision information when walking around
DevHelper = CpObject()

function DevHelper:init()
    self.data = {}
    self.isEnabled = false
    self:registerConsoleCommands()
end

function DevHelper:registerConsoleCommands()
	addConsoleCommand( 'cpGiantsAIDebug', 'cpGiantsAIDebug', 'turnOnGiantsAIDebug',self)
end


function DevHelper:debug(...)
    print(string.format(...))
end

function DevHelper:update()
    if not self.isEnabled then return end

    local lx, lz, hasCollision, vehicle

    -- make sure not calling this for something which does not have courseplay installed (only ones with spec_aiVehicle)
    if g_currentMission.controlledVehicle and g_currentMission.controlledVehicle.spec_aiVehicle then

        if self.vehicle ~= g_currentMission.controlledVehicle then
            --self.vehicleData = PathfinderUtil.VehicleData(g_currentMission.controlledVehicle, true)
        end

        self.vehicle = g_currentMission.controlledVehicle
        self.node = g_currentMission.controlledVehicle.rootNode
        lx, _, lz = localDirectionToWorld(self.node, 0, 0, 1)

    else
        -- camera node looks backwards so need to flip everything by 180 degrees
        self.node = g_currentMission.player.cameraNode
        lx, _, lz = localDirectionToWorld(self.node, 0, 0, -1)
    end

    self.yRot = math.atan2( lx, lz )
    self.data.yRotDeg = math.deg(self.yRot)
    self.data.yRotDeg2 = math.deg(MathUtil.getYRotationFromDirection(lx, lz))
    self.data.x, self.data.y, self.data.z = getWorldTranslation(self.node)
--    self.data.fieldNum = courseplay.fields:getFieldNumForPosition(self.data.x, self.data.z)

--    self.data.hasFruit, self.data.fruitValue, self.data.fruit = PathfinderUtil.hasFruit(self.data.x, self.data.z, 5, 3.6)

    --self.data.landId =  PathfinderUtil.getFieldIdAtWorldPosition(self.data.x, self.data.z)
    --self.data.owned =  PathfinderUtil.isWorldPositionOwned(self.data.x, self.data.z)
	self.data.farmlandId = g_farmlandManager:getFarmlandIdAtWorldPosition(self.data.x, self.data.z)
	self.data.farmland = g_farmlandManager:getFarmlandAtWorldPosition(self.data.x, self.data.z)
--    self.data.fieldAreaPercent = 100 * self.fieldArea / self.totalFieldArea

	local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, self.data.x, self.data.y, self.data.z)
    self.data.isOnField, self.data.densityBits = FSDensityMapUtil.getFieldDataAtWorldPosition(self.data.x, y, self.data.z)

    self.data.nx, self.data.ny, self.data.nz = getTerrainNormalAtWorldPos(g_currentMission.terrainRootNode, self.data.x, y, self.data.z)

    self.data.collidingShapes = ''
    overlapBox(self.data.x, self.data.y + 0.2, self.data.z, 0, self.yRot, 0, 1.6, 1, 8, "overlapBoxCallback", self, bitOR(CollisionMask.VEHICLE, 2), true, true, true)

end

function DevHelper:overlapBoxCallback(transformId)
    local collidingObject = g_currentMission.nodeToObject[transformId]
    local text
    if collidingObject then
        if collidingObject.getRootVehicle then
            text = 'vehicle' .. collidingObject:getName()
        else
			if collidingObject:isa(Bale) then
				text = 'Bale ' .. tostring(collidingObject) .. ' ' .. tostring(NetworkUtil.getObjectId(collidingObject))
			else
            	text = collidingObject.getName and collidingObject:getName() or 'N/A'
			end
        end
    else
        text = ''
        for key, classId in pairs(ClassIds) do
            if getHasClassId(transformId, classId) then
                text = text .. ' ' .. key
            end
        end
    end


    self.data.collidingShapes = self.data.collidingShapes .. '|' .. text
end

-- Left-Alt + , (<) = mark current position as start for pathfinding
-- Left-Alt + , (<) = mark current position as start for pathfinding
-- Left-Alt + . (>) = mark current position as goal for pathfinding
-- Left-Ctrl + . (>) = start pathfinding from marked start to marked goal
-- Left-Ctrl + , (<) = mark current field as field for pathfinding
-- Left-Alt + Space = save current vehicle position
-- Left-Ctrl + Space = restore current vehicle position
function DevHelper:keyEvent(unicode, sym, modifier, isDown)
    if not self.isEnabled then return end
    if bitAND(modifier, Input.MOD_LALT) ~= 0 and isDown and sym == Input.KEY_comma then
        -- Left Alt + < mark start
        self.start = State3D(self.data.x, -self.data.z, CourseGenerator.fromCpAngleDeg(self.data.yRotDeg))
        self:debug('Start %s', tostring(self.start))
		PathfinderUtil.checkForObstaclesAhead(self.vehicle, 6)
    elseif bitAND(modifier, Input.MOD_LALT) ~= 0 and isDown and sym == Input.KEY_period then
        -- Left Alt + > mark goal
        self.goal = State3D(self.data.x, -self.data.z, CourseGenerator.fromCpAngleDeg(self.data.yRotDeg))

        local x, y, z = getWorldTranslation(self.node)
        local _, yRot, _ = getRotation(self.node)
        if self.goalNode then
            setTranslation( self.goalNode, x, y, z );
            setRotation( self.goalNode, 0, yRot, 0);
        else
            self.goalNode = courseplay.createNode('devhelper', x, z, yRot)
        end

        self:debug('Goal %s', tostring(self.goal))
        --self:startPathfinding()
    elseif bitAND(modifier, Input.MOD_LCTRL) ~= 0 and isDown and sym == Input.KEY_period then
        -- Left Ctrl + > find path
        self:debug('Calculate')
        self:startPathfinding()
    elseif bitAND(modifier, Input.MOD_LCTRL) ~= 0 and isDown and sym == Input.KEY_comma then
        self.fieldNumForPathfinding = PathfinderUtil.getFieldNumUnderNode(self.node)
        self:debug('Set field %d for pathfinding', self.fieldNumForPathfinding)
    elseif bitAND(modifier, Input.MOD_LALT) ~= 0 and isDown and sym == Input.KEY_space then
        -- save vehicle position
        g_currentMission.controlledVehicle.vehiclePositionData = {}
        DevHelper.saveVehiclePosition(g_currentMission.controlledVehicle, g_currentMission.controlledVehicle.vehiclePositionData)
    elseif bitAND(modifier, Input.MOD_LCTRL) ~= 0 and isDown and sym == Input.KEY_space then
        -- restore vehicle position
        DevHelper.restoreVehiclePosition(g_currentMission.controlledVehicle)
    elseif bitAND(modifier, Input.MOD_LALT) ~= 0 and isDown and sym == Input.KEY_c then
        self:debug('Finding contour of current field')
        g_fieldScanner:findContour(self.data.x, self.data.z)
    elseif bitAND(modifier, Input.MOD_LALT) ~= 0 and isDown and sym == Input.KEY_g then
        self:debug('Generate course')
        local status, ok, course = CourseGeneratorInterface.generate({x = self.data.x, z = self.data.z},
                0, 6, 1, true)
        if ok then
            self.course = course
            local map = g_currentMission.inGameMenu.pageAI.ingameMap
            self.coursePlot = CoursePlot(map.ingameMap)
            self.coursePlot:setWaypoints(course.waypoints)
            self.coursePlot:setVisible(true)
            g_currentMission.inGameMenu.pageAI.ingameMap.draw =
                Utils.appendedFunction(g_currentMission.inGameMenu.pageAI.ingameMap.draw, g_devHelper.drawCoursePlot)
        end
    end
end

function DevHelper:toggle()
    self.isEnabled = not self.isEnabled
end

function DevHelper:draw()
    if not self.isEnabled then return end
    local data = {}
    for key, value in pairs(self.data) do
        table.insert(data, {name = key, value = value})
    end
    DebugUtil.renderTable(0.65, 0.3, 0.013, data, 0.05)
    self:showFillNodes()
    for _, vehicle in pairs(g_currentMission.vehicles) do
        if vehicle ~= g_currentMission.controlledVehicle and vehicle.cp and vehicle.cp.driver then
            vehicle.cp.driver:onDraw()
        end
    end

	if not self.tNode then
		self.tNode = createTransformGroup("devhelper")
		link(g_currentMission.terrainRootNode, self.tNode)
	end

	DebugUtil.drawDebugNode(self.tNode, 'Terrain normal')
	local nx, ny, nz = getTerrainNormalAtWorldPos(g_currentMission.terrainRootNode, self.data.x, self.data.y, self.data.z)

	local x, y, z = localToWorld(self.node, 0, -1, -3)

	drawDebugLine(x, y, z, 1, 1, 1, x + nx, y + ny, z + nz, 1, 1, 1)
	local xRot, yRot, zRot = getWorldRotation(self.tNode)
	DebugUtil.drawOverlapBox(self.data.x, self.data.y, self.data.z, xRot, yRot, zRot, 4, 1, 4, 0, 100, 0)
    g_fieldScanner:draw()
end

function DevHelper:showFillNodes()
    for _, vehicle in pairs(g_currentMission.vehicles) do
        if SpecializationUtil.hasSpecialization(Trailer, vehicle.specializations) then
            DebugUtil.drawDebugNode(vehicle.rootNode, 'Root node')
            local fillUnits = vehicle:getFillUnits()
            for i = 1, #fillUnits do
                local fillRootNode = vehicle:getFillUnitExactFillRootNode(i)
                if fillRootNode then DebugUtil.drawDebugNode(fillRootNode, 'Fill node ' .. tostring(i)) end
            end
        end
    end
end


function DevHelper.saveVehiclePosition(vehicle, vehiclePositionData)
    local savePosition = function(object)
        local savedPosition = {}
        savedPosition.x, savedPosition.y, savedPosition.z = getWorldTranslation(object.rootNode)
        savedPosition.xRot, savedPosition.yRot, savedPosition.zRot = getWorldRotation(object.rootNode)
        return savedPosition
    end
    if not vehicle.getAttachedImplements then return end
    table.insert(vehiclePositionData, {vehicle, savePosition(vehicle)})
    for _,impl in pairs(vehicle:getAttachedImplements()) do
        DevHelper.saveVehiclePosition(impl.object, vehiclePositionData)
    end
    Courseplay.info('Saved position of %s', vehicle:getName())
end

function DevHelper.restoreVehiclePosition(vehicle)
    if vehicle.vehiclePositionData then
        for _, savedPosition in pairs(vehicle.vehiclePositionData) do
            savedPosition[1]:setAbsolutePosition(savedPosition[2].x, savedPosition[2].y, savedPosition[2].z,
                    savedPosition[2].xRot, savedPosition[2].yRot, savedPosition[2].zRot)
            Courseplay.info('Restored position of %s', savedPosition[1]:getName())
        end
    end
end

function DevHelper.restoreAllVehiclePositions()
    for _, vehicle in pairs(g_currentMission.vehicles) do
        if vehicle.vehiclePositionData then
            DevHelper.restoreVehiclePosition(vehicle)
        end
    end
end

function DevHelper.saveAllVehiclePositions()
    for _, vehicle in pairs(g_currentMission.vehicles) do
        vehicle.vehiclePositionData = {}
        DevHelper.saveVehiclePosition(vehicle, vehicle.vehiclePositionData)
    end
end

function DevHelper.turnOnGiantsAIDebug()
    VehicleDebug.setState(7)
    g_currentMission.aiSystem:consoleCommandAIEnableDebug()
    g_currentMission.aiSystem:consoleCommandAIToggleSplineVisibility()
    g_currentMission.aiSystem:consoleCommandAIToggleAINodeDebug()
    g_currentMission.aiSystem:consoleCommandAIShowObstacles()
    g_currentMission.aiSystem:consoleCommandAIShowCosts()
end

function DevHelper.drawCoursePlot()
    if g_devHelper.coursePlot then
        g_devHelper.coursePlot:draw()
    end
end

-- make sure to recreate the global dev helper whenever this script is (re)loaded
g_devHelper = DevHelper()

