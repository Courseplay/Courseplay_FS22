--[[
This file is part of Courseplay (https://github.com/Courseplay/courseplay)
Copyright (C) 2022 Peter Vaiko

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

--[[

	A custom field is what the user created by driving around its edges
	and recording waypoints.

]]--

---@class CustomField
CustomField = CpObject()

CustomField.xmlSchema = XMLSchema.new("customField")
CustomField.xmlSchema:register(XMLValueType.STRING, "customField#name", "Custom field name")
CustomField.xmlSchema:register(XMLValueType.STRING ,"customField.vertices", "Vertices of the field polygon")

function CustomField:init(name, vertices)
    if type(name) == 'number' then
        name = string.format('%d', name)
    end
    self.name = name
    self.vertices = vertices

    self:findFieldCenter()

    self.fieldPlot = CustomFieldPlot(g_currentMission.inGameMenu.ingameMap)
    self.fieldPlot:setWaypoints(vertices)
    self.fieldPlot:setVisible(true)
end

function CustomField:addHotspot()
    self.fieldHotspot = FieldHotspot.new()
    self.fieldHotspot:setField(self)
    self.fieldHotspot:setOwnerFarmId(g_currentMission.player.farmId)
    g_currentMission:addMapHotspot(self.fieldHotspot)
end

function CustomField:isPointOnField(x, z)
    return CpMathUtil.isPointInPolygon(self.vertices, x, z)
end

function CustomField:draw(map)
    if not self.fieldHotspot then
        -- add hotspot when draw first called. Can't create in the constructor as on game load
        -- when the custom fields are loaded there's no player yet
        self:addHotspot()
    end
    self.fieldPlot:draw(map)
end

-- FieldHotspot needs this
function CustomField:getName()
    return 'CP-' .. self.name
end

function CustomField:getVertices()
    return self.vertices
end

function CustomField:findFieldCenter()
    -- calculating the centroid should be fine as long as the field is more or less concave.
    -- a more sophisticated method would be https://github.com/mapbox/polylabel
    local x, z = 0, 0
    for _, v in ipairs(self.vertices) do
        x = x + v.x
        z = z + v.z
    end
    -- FieldHotspot uses these
    self.posX = x / #self.vertices
    self.posZ = z / #self.vertices
end

---@param directory Directory
function CustomField:saveToXml(directory)
    local key = 'customField'
    local fullPath = directory:getFullPathForFile(self.name)
    local xmlFile = createXMLFile("customField", fullPath, key);
    if xmlFile and xmlFile ~= 0 then
        setXMLString(xmlFile, key .. '#name', self.name)
        setXMLString(xmlFile, key  .. '.vertices', self:serializeVertices())
        saveXMLFile(xmlFile)
        delete(xmlFile)
        CpUtil.debugFormat(CpDebug.DBG_COURSES, 'Saved custom field %s', fullPath)
    else
        CpUtil.debugFormat(CpDebug.DBG_COURSES, 'Could not save custom field %s', fullPath)
    end
end

function CustomField:writeStream(streamId, connection)
    streamWriteString(streamId, self.name)
    streamWriteString(streamId, self:serializeVertices())
end

function CustomField:serializeVertices()
    local serializedVertices = '\n' -- (pure cosmetic)
    for _, p in ipairs(self.vertices) do
        local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, p.x, 0, p.z)
        local serializedVertex = string.format('%.2f %.2f %.2f|\n', p.x, y, p.z)
        serializedVertices = serializedVertices .. serializedVertex
    end
    return serializedVertices
end

function CustomField.deserializeVertices(serializedVertices)
    local vertices = {}

    local lines = string.split(serializedVertices, '|')
    for _, line in ipairs(lines) do
        local p = {}
        p.x, p.y, p.z = string.getVector(line)
        -- just skip empty lines
        if p.x then
            table.insert(vertices, p)
        end
    end
    return vertices
end

function CustomField.createFromXmlFile(fullPath)
    local xmlFile = XMLFile.loadIfExists("customFieldXmlFile", fullPath, CustomField.xmlSchema)
    local key = 'customField'
    local name = xmlFile:getValue( key .. '#name')
    local serializedVertices = xmlFile:getValue( key .. '.vertices')
    xmlFile:delete()
    local customField = CustomField(name, CustomField.deserializeVertices(serializedVertices))
    CpUtil.debugFormat(CpDebug.DBG_COURSES, 'Custom field with %d vertices loaded from %s.',
            #customField.vertices, fullPath)
    return customField
end

function CustomField.createFromStream(streamId, connection)
    local name = streamReadString(streamId)
    local serializedVertices = streamReadString(streamId)
    local customField = CustomField(name, CustomField.deserializeVertices(serializedVertices))
    CpUtil.debugFormat(CpDebug.DBG_COURSES, vehicle, 'Custom field with %d points loaded from stream.', #customField.vertices)
    return customField
end
