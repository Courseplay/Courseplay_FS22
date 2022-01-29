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

    Keeping track and persisting all custom fields

]]--

---@class CustomFieldManager
CustomFieldManager = CpObject()

---@param fileSystem FileSystem
function CustomFieldManager:init(fileSystem)
    ---@type FileSystem
    self.fileSystem = fileSystem
    self.fields = {}
    self:load()
end

function CustomFieldManager:load()
    local entries = self.fileSystem:getRootDirectory():getEntries(false, true)
    for i, entry in pairs(entries) do
        table.insert(self.fields, CustomField.createFromXmlFile(entry:getFullPath()))
    end
end

function CustomFieldManager:getNewFieldNumber()
    local entries = self.fileSystem:getRootDirectory():getEntries(false, true)
    -- custom field file names are always numbers
    -- sort them numerically
    table.sort(entries, function (a, b) return tonumber(a:getName()) < tonumber(b:getName()) end)
    for i, entry in pairs(entries) do
        if i ~= tonumber(entry:getName()) then
            -- the i. entry is not i, so we can use i as a new number (entries is sorted)
            return i
        end
    end
    return #entries + 1
end

function CustomFieldManager:addField(waypoints)
    if #waypoints < 10 then
        CpUtil.info('Recorded course has less than 10 waypoints, ignoring.')
        return
    end
    ---@type CustomField
    local newField = CustomField(self:getNewFieldNumber(), waypoints)
    g_gui:showYesNoDialog({
        text = string.format(g_i18n:getText("CP_customFieldManager_confirm_save"), newField:getName()),
        callback = CustomFieldManager.onClickSaveDialog,
        target = self,
        args = newField
    })
end

--- Creates a new directory with a given name.
function CustomFieldManager:onClickSaveDialog(clickOk, field)
    if clickOk then
        CpUtil.debugFormat(CpDebug.DBG_COURSES, 'Saving custom field %s', field:getName())
        table.insert(self.fields, field)
        field:saveToXml(self.fileSystem:getRootDirectory())
        self.fileSystem:refresh()
    end
end

function CustomFieldManager:getCustomField(x, z)
    for _, field in pairs(self.fields) do
        if field:isPointOnField(x, z) then
            return field
        end
    end
    return nil
end

function CustomFieldManager:draw(map)
    for _, field in pairs(self.fields) do
        field:draw(map)
    end
end

-- for reload only:
if g_customFieldManager then
    g_customFieldManager = CustomFieldManager(FileSystem(g_Courseplay.customFieldDir, g_currentMission.missionInfo.mapId))
end