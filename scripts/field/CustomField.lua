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

function CustomField:init(name, waypoints)
    if type(name) == 'number' then
        name = string.format('%d', name)
    end
    self.name = name
    self.waypoints = waypoints
end

function CustomField:saveToXml(directory)
    local key = 'CustomField'
    local xmlFile = createXMLFile("customField", directory .. self.name, key);
    if xmlFile and xmlFile ~= 0 then
        xmlFile:setValue(key .. '#name',self.name)
        xmlFile:setValue(key  .. '.waypoints',self:serializeWaypoints())
        saveXMLFile(xmlFile)
        delete(xmlFile)
        CpUtil.debugFormat(CpDebug.DBG_COURSES, 'Saved custom field %s', self.name)
    else
        CpUtil.debugFormat(CpDebug.DBG_COURSES, 'Could not save custom field %s', self.name)
    end
end

function CustomField:writeStream(streamId, connection)
    streamWriteString(streamId, self.name)
    streamWriteString(streamId, self:serializeWaypoints())
end

function CustomField:serializeWaypoints()
    local serializedWaypoints = '\n' -- (pure cosmetic)
    for _, p in ipairs(self.waypoints) do
        local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, p.x, 0, p.z)
        local serializedWaypoint = string.format('%.2f %.2f %.2f|\n', p.x, y, p.z)
        serializedWaypoints = serializedWaypoints .. serializedWaypoint
    end
    return serializedWaypoints
end

function CustomField.deserializeWaypoints(serializedWaypoints)
    local waypoints = {}

    local lines = string.split(serializedWaypoints, '|')
    for _, line in ipairs(lines) do
        local p = {}
        p.x, p.y, p.z = string.getVector(line)
        -- just skip empty lines
        if p.x then
            table.insert(waypoints, p)
        end
    end
    return waypoints
end

function CustomField.createFromXml(customFieldXml, customFieldKey)
    local name = customFieldXml:getValue( customFieldKey .. '#name')
    local serializedWaypoints = customFieldXml:getValue( customFieldKey .. '.waypoints')
    local customField = CustomField(name, CustomField.deserializeWaypoints(serializedWaypoints))
    CpUtil.debugFormat(CpDebug.DBG_COURSES, 'Custom field with %d points loaded from file.', #customField.waypoints)
    return customField
end

function CustomField.createFromStream(streamId, connection)
    local name = streamReadString(streamId)
    local serializedWaypoints = streamReadString(streamId)
    local customField = CustomField(name, CustomField.deserializeWaypoints(serializedWaypoints))
    CpUtil.debugFormat(CpDebug.DBG_COURSES, vehicle, 'Custom field with %d points loaded from stream.', #customField.waypoints)
    return customField
end
