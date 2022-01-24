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
end

function CustomFieldManager:getNewFieldNumber()
    local entries = self.fileSystem:getRootDirectory():getEntries(false, true)
    -- custom field file names are always numbers
    -- sort them numerically
    for _, entry in ipairs(entries) do
        entry = tonumber(entry)
    end
    table.sort(entries)
    for i, entry in ipairs(entries) do
        if i ~= tonumber(entry:getName()) then
            -- the i. entry is not i, so we can use i as a new number (entries is sorted)
            return i
        end
    end
    return #entries + 1
end

function CustomFieldManager:addField(waypoints)
    ---@type CustomField
    local field = CustomField(self:getNewFieldNumber(), waypoints)
    field:saveToXml(self.fileSystem:getRootDirectory():getName())
end
