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
CustomFieldManager.namePrefix = "CP-"

---@param fileSystem FileSystem
function CustomFieldManager:init(fileSystem)
    ---@type FileSystem
    self.fileSystem = fileSystem
    self.currentView = fileSystem.currentDirectoryView
    self.rootDir = fileSystem.rootDirectory
    self:load()
end

function CustomFieldManager:load()
    self.fields = {}
    self.fileSystem:refresh()
    local entries = self.rootDir:getEntries(false,true)
    for i, entry in pairs(entries) do
        table.insert(self.fields, CustomField.createFromXmlFile(entry))
    end
end

--- New fields are created with a prefix and the next available number.
function CustomFieldManager:getNewFieldNumber()
    local numbers = {}
    for i, entry in pairs(self.fields) do 
        local name = entry:getName()
        if name:startsWith("CP-") then 
            local n = entry:getFieldNumber()
            if n then 
                table.insert(numbers,entry)
            end
        end
    end
    table.sort(numbers, function (a, b) return a:getFieldNumber() < b:getFieldNumber() end)
    for i, entry in pairs(numbers) do
        if i ~= entry:getFieldNumber() then
            -- the i. entry is not i, so we can use i as a new number (entries is sorted)
            return i
        end
    end
    return #numbers + 1
end

function CustomFieldManager:addField(waypoints)
    if #waypoints < 10 then
        CpUtil.info('Recorded course has less than 10 waypoints, ignoring.')
        return
    end
    ---@type CustomField
    local newField = CustomField()
    newField:setup(self.namePrefix..self:getNewFieldNumber(), waypoints)
    g_gui:showYesNoDialog({
        text = string.format(g_i18n:getText("CP_customFieldManager_confirm_save"), newField:getName()),
        callback = CustomFieldManager.onClickSaveDialog,
        target = self,
        args = newField
    })
end


function CustomFieldManager:deleteField(fieldToDelete)
    g_gui:showYesNoDialog({
        text = string.format(g_i18n:getText("CP_customFieldManager_confirm_delete"), fieldToDelete:getName()),
        callback = CustomFieldManager.onClickDeleteDialog,
        target = self,
        args = fieldToDelete
    })
end

function CustomFieldManager:renameField(field,hotspot)
    g_gui:showTextInputDialog({
		disableFilter = true,
		callback = CustomFieldManager.onClickRenameDialog,
		target = self,
		defaultText = "",
		dialogPrompt = g_i18n:getText("CP_customFieldManager_rename"),
		maxCharacters = 30,
		confirmText = g_i18n:getText("button_ok"),
		args = field
	})
end

function CustomFieldManager:editField(fieldToEdit, hotspot)
    for i, field in pairs(self.fields) do
        if field == fieldToEdit then
            local file = self.currentView:getEntryByName(fieldToEdit:getName())
            if file then 
                g_courseEditor:activateCustomField(file:getEntity(), fieldToEdit)
            end
        end
    end
end

function CustomFieldManager:saveField(file, field, forceReload)
    file:save(CustomField.rootXmlKey, 
    CustomField.xmlSchema,
    CustomField.rootXmlKey, 
    CustomField.saveToXml, 
    field,
    field:getName())
    if forceReload then
        self:delete()
        self:load()
    end
end

--- Creates a new file with a given name.
function CustomFieldManager:onClickSaveDialog(clickOk, field)
    local fieldValid = false
    if clickOk then
        CpUtil.debugFormat(CpDebug.DBG_COURSES, 'Saving custom field %s', field:getName())
        local file, fileCreated = self.currentView:addFile(field:getName())
        if fileCreated then 
            self:saveField(file, field)
            fieldValid = true
            table.insert(self.fields, field)
            self.fileSystem:refresh()
        end
    end
    if not fieldValid then 
        field:delete()
    end
end

function CustomFieldManager:onClickDeleteDialog(clickOk, fieldToDelete)
    if clickOk then
        CpUtil.debugFormat(CpDebug.DBG_COURSES, 'Deleting custom field %s', fieldToDelete:getName())
        for i, field in pairs(self.fields) do
            if field == fieldToDelete then
                local file = self.currentView:getEntryByName(fieldToDelete:getName())
                if file then 
                    file:delete()
                    field:delete()
                    table.remove(self.fields, i)
                    self.fileSystem:refresh()
                else 
                    CpUtil.debugFormat(CpDebug.DBG_COURSES, 'Custom field %s was found, but the file not.', fieldToDelete:getName())
                end
                return
            end
        end
        CpUtil.debugFormat(CpDebug.DBG_COURSES, 'Custom field %s not found, not deleted', fieldToDelete:getName())
    end
end

function CustomFieldManager:onClickRenameDialog(newName,clickOk,fieldToRename)
    if clickOk then
        CpUtil.debugFormat(CpDebug.DBG_COURSES, 'Trying to rename custom field from %s to %s.', fieldToRename:getName(),newName)
        for i, field in pairs(self.fields) do
            if field == fieldToRename then
                local file = self.currentView:getEntryByName(fieldToRename.name)
                if file then 
                    CpUtil.debugFormat(CpDebug.DBG_COURSES, 'Renamed custom field from %s to %s.', fieldToRename:getName(),newName)
                    if file:rename(newName) then 
                        fieldToRename:setName(newName)
                        self.fileSystem:refresh()
                        return
                    end
                end
            end
        end
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

function CustomFieldManager:delete()
    for _,field in pairs(self.fields) do 
        field:delete()
    end
end

--- Makes sure all custom fields are valid and in the filesystem.
--- Gets refresh on opening of the ai page in the in game menu.
function CustomFieldManager:refresh()
    self.fileSystem:refresh()
    local entries = self.rootDir:getEntries(false,true)
    for i = #self.fields, 1, -1 do 
        local foundIx = nil
        for j = #entries, 1, -1 do 
            if self.fields[i] and entries[j] and self.fields[i]:getName() == entries[j]:getName() then 
                foundIx = j 
                break
            end
        end
        if foundIx then 
            table.remove(entries,foundIx)
        else 
            CpUtil.debugFormat(CpDebug.DBG_COURSES,"Removed not saved hotspot %s.", self.fields[i]:getName())
            self.fields[i]:delete()
            table.remove(self.fields,i)
        end
    end
    for i, entry in pairs(entries) do
        CpUtil.debugFormat(CpDebug.DBG_COURSES,"Added new hotspot %s from filesystem.", entry:getName())
        table.insert(self.fields, CustomField.createFromXmlFile(entry))
    end
end

-- for reload only:
if g_customFieldManager then
    g_customFieldManager = CustomFieldManager(FileSystem(g_Courseplay.customFieldDir, g_currentMission.missionInfo.mapId))
end