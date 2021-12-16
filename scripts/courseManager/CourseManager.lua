--[[
This file is part of Courseplay (https://github.com/Courseplay/courseplay)
Copyright (C) 2021 Peter Vaiko

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

The Course Manager is responsible for:
	- managing all saved courses, in particular:
		* maintaining a directory/file structure on the disk
		* saving courses to XML files
		* loading courses from files when the user selects them in the HUD
		* creating directories on the disk when the user creates a folder in the HUD
	- keeping track of courses assigned to a vehicle:
		* courses are assigned to a vehicle when the users selects them in the HUD
		* the Course Manager provides the assigned courses to the AIDriver on start
		* assignments are saved with the savegame and loaded on game start
	- synchronizing course assignments in multiplayer
		* courses are saved/loaded on the client only
		* the Course Manager on the server only holds the assignments and provides the courses to the AIDriver
		* whenever an assignment changes, all assigned courses of the vehicle are sent to
		  the server (as a CourseEvent), which then also broadcasts them to the other clients

]]--

--- An entity (file or directory) in the file system
---@class FileSystemEntity
FileSystemEntity = CpObject()

---@param fullPath string
---@param parent FileSystemEntity
---@param name string
function FileSystemEntity:init(fullPath, parent, name)
	self.fullPath = fullPath
	self.parent = parent
	self.name = name or string.match(fullPath, '.*[\\/](.+)')
end

function FileSystemEntity:isDirectory()
	return false
end

function FileSystemEntity:getName()
	return self.name
end

function FileSystemEntity:getFullPath()
	return self.fullPath
end

function FileSystemEntity:getParent()
	return self.parent
end

function FileSystemEntity.__eq(a, b)
	return a.fullPath == b.fullPath
end

function FileSystemEntity.__lt(a, b)
	return a.name < b.name
end

function FileSystemEntity:__tostring()
	return 'Name: ' .. self.name .. ', Path: ' .. self.fullPath
end

---@class File : FileSystemEntity
File = CpObject(FileSystemEntity)

function File:__tostring()
	return 'File: ' .. FileSystemEntity.__tostring(self) .. '\n'
end

function File:delete()
	getfenv(0).deleteFile(self:getFullPath())
	CpUtil.debugFormat(CpDebug.DBG_COURSES, 'deleted file %s', self:getFullPath())
end

function File:clone()
	local clonedFile = File(self:getFullPath(),self:getParent(),self:getName())
	return clonedFile	
end

--- A directory on the file system. This can recursively be traversed to all subdirectories.
---@class Directory : FileSystemEntity
Directory = CpObject(FileSystemEntity)

function Directory:init(fullPath, parent, name)
	FileSystemEntity.init(self, fullPath, parent, name)
	self.entries = {}
	createFolder(self.fullPath)
	self:refresh()
end

function Directory:isDirectory()
	return true
end

function Directory:getEntries(directories, files)
	local entries = {}
	for _, entry in pairs(self.entries) do
		if directories and entry:isDirectory() then
			table.insert(entries, entry)
		end
		if files and not entry:isDirectory() then
			table.insert(entries, entry)
		end
	end
	table.sort(entries)
	return entries
end


function Directory:getDirectories()
	return self:getEntries(true, false)
end

function Directory:getFiles()
	return self:getEntries(false, true)
end


--- Refresh from disk
function Directory:refresh()
	self.entriesToRemove = {}
	for key, _ in pairs(self.entries) do
		self.entriesToRemove[key] = true
	end
	getFiles(self.fullPath, 'fileCallback', self)
	for key, _ in pairs(self.entriesToRemove) do
		self.entries[key] = nil
	end
end

function Directory:fileCallback(name, isDirectory)
	if isDirectory then
		if self.entries[name] then
			self.entries[name]:refresh()
		else
			self.entries[name] = Directory(self.fullPath .. '\\' .. name, self)
		end
	elseif not self.entries[name] then
		self.entries[name] = File(self.fullPath .. '\\' .. name, self)
	end
	if self.entriesToRemove[name] then
		self.entriesToRemove[name] = nil
	end
end

function Directory:deleteFile(name)
	getfenv(0).deleteFile(self.entries[name]:getFullPath())
	self.entries[name] = nil
end

function Directory:delete()
	if self:isEmpty() then
		getfenv(0).deleteFolder(self:getFullPath())
		CpUtil.debugFormat(CpDebug.DBG_COURSES, 'deleted folder %s', self:getFullPath())
	else
		CpUtil.debugFormat(CpDebug.DBG_COURSES, 'folder %s is not empty, cannot delete', self:getFullPath())
	end
end

function Directory:isEmpty()
	-- (can't use # as this is a dictionary, not an array)
	for _, _ in pairs(self.entries) do
		return false
	end
	return true
end

function Directory:createDirectory(name)
	if not self.entries[name] then
		self.entries[name] = Directory(self.fullPath .. '\\' .. name, self)
	end
	return self.entries[name]
end

function Directory:__tostring()
	local str = 'Directory: ' .. FileSystemEntity.__tostring(self) .. '\n'
	for _, entry in pairs(self.entries) do
		str = str .. tostring(entry)
	end
	return str
end

function Directory:clone()
	local clonedDir = Directory(self:getFullPath(),self:getParent(),self:getName())
	clonedDir:refresh()
	return clonedDir	
end

--- A view representing a file system entity (file or directory). The view knows how to display an entity on the UI.
---@class FileSystemEntityView
FileSystemEntityView = CpObject()
FileSystemEntityView.indentString = '  '

function FileSystemEntityView:init(entity, level)
	self.name = entity:getName()
	self.level = level or 0
	self.entity = entity
	self.indent = ''
	-- indent only from level 2. level 0 is never shown, as it is the root directory, level 1
	-- has no indent.
	for i = 2, self.level do
		self.indent = self.indent .. FileSystemEntityView.indentString
	end
end

function FileSystemEntityView:getEntity()
	return self.entity
end

function FileSystemEntityView:getName()
	return self.name
end

function FileSystemEntityView:getFullPath()
	return self.entity:getFullPath()
end

function FileSystemEntityView:getLevel()
	return self.level
end

function FileSystemEntityView:__tostring()
	return self.indent .. self.name .. '\n'
end

function FileSystemEntityView.__lt(a, b)
	return a.entity.name < b.entity.name
end

function FileSystemEntityView:isDirectory()
	return self.entity:isDirectory()
end

-- by default, no fold or unfold shown
function FileSystemEntityView:showUnfoldButton()
	return false
end

function FileSystemEntityView:showFoldButton()
	return false
end

function FileSystemEntityView:showDeleteButton()
	return true
end

function FileSystemEntityView:showSaveButton()
	return false
end

function FileSystemEntityView:showLoadButton()
	return false
end

function FileSystemEntityView:showAddButton()
	return false
end

--- View of a regular file (XML with a saved course
---@class FileView : FileSystemEntityView
FileView = CpObject(FileSystemEntityView)
function FileView:init(file, level)
	FileSystemEntityView.init(self, file, level)
end

function FileView:showLoadButton()
	return true
end

--- View of a directory of saved courses
---@class DirectoryView
DirectoryView = CpObject(FileSystemEntityView)

---@param directory Directory
function DirectoryView:init(directory, level, folded)
	FileSystemEntityView.init(self, directory, level)
	self.directory = directory
	self.folded = false--folded or false
	self:refresh()
end

function DirectoryView:refresh()
	self.directoryViews = {}
	self.fileViews = {}
	for _, entry in pairs(self.directory.entries) do
		if entry:isDirectory() then
			table.insert(self.directoryViews, DirectoryView(entry, self.level + 1, true))
		else
			table.insert(self.fileViews, FileView(entry, self.level + 1))
		end
	end
	table.sort(self.directoryViews)
	table.sort(self.fileViews)
end

function DirectoryView:fold()
	self.folded = true
end

function DirectoryView:unfold()
	self.folded = false
end

function DirectoryView:isFolded()
	return self.folded
end

function DirectoryView:__tostring()
	local str = ''
	if self.level > 0 then
		str = str .. self.indent .. self.name .. '\n'
	end
	if not self.folded then
		for _, dv in ipairs(self.directoryViews) do
			str = str .. tostring(dv)
		end
		for _, fv in ipairs(self.fileViews) do
			str = str .. tostring(fv)
		end
	end
	return str
end

function DirectoryView:collectEntries(t)
	if self.level > 0 then
--		table.insert(t, self)
	end
	if not self.folded then
		for _, dv in ipairs(self.directoryViews) do
			dv:collectEntries(t)
		end
		for _, fv in ipairs(self.fileViews) do
			table.insert(t, fv)
		end
	end
end

--- Entries according to the current folded/unfolded state of the directories.
function DirectoryView:getEntries()
	self.entries = {}
	self:collectEntries(self.entries)
	return self.entries
end

function DirectoryView:showUnfoldButton()
	return self:isFolded()
end

function DirectoryView:showFoldButton()
	return not self:isFolded()
end

function DirectoryView:showSaveButton()
	return true
end

function DirectoryView:showDeleteButton()
	return self:getEntity():isEmpty()
end

--- The CourseManager is responsible for loading/saving all courses and maintaining the vehicle - course
--- assignments.
--- Course folders shown in the HUD correspond actual file system folders.
--- Courses shown in the HUD correspond actual files on the file system.
---@class CourseManager
CourseManager = CpObject()
---@param baseDir string base path for storing all none save game cp files
function CourseManager:init(baseDir)
	-- courses are stored in a folder per map, under modSettings/Courseplay/Courses/<map name>/
	-- create subfolders one by one, seems like createFolder() can't recursively create subfolders
	baseDir = baseDir .. "Courses/"
	createFolder(baseDir)
	self.courseDirFullPath = baseDir .. g_currentMission.missionInfo.mapId
	self.courseDir = Directory(self.courseDirFullPath)
	self.courseDirView = DirectoryView(self.courseDir)
	self.currentEntry = 1

	-- representation of all waypoints loaded for a vehicle as needed by the legacy functions
	self.legacyWaypoints = {}

	self.vehiclesWithCourses = {}

end

--- Refresh everything from disk
function CourseManager:refresh()
	self.courseDir:refresh()
	self.courseDirView:refresh()
	self:setCurrentEntry(self:getCurrentEntry())
end

--- Gets all entries in the main directory.
function CourseManager:getEntries()
	return self.courseDirView:getEntries()
end

--- Gets all directories in the main directory.
function CourseManager:getDirectories()
	return self.courseDir:getDirectories()
end

--- Gets an entry in directory by it's index.
function CourseManager:getEntryByIndex(index)
	local entries = self:getEntries()
	return entries[index]
end

--- Gets an sub directory to the root by it's index.
function CourseManager:getDirectoryByIndex(index)
	local directories = self:getDirectories()
	return directories[index]
end

--- Gets all entries in a given sub directory to the root.
function CourseManager:getEntriesForDirectory(dirIx)
	local dir = self:getDirectoryByIndex(dirIx)
	local view = DirectoryView(dir)
	return view:getEntries()
end

--- Gets a specific entry for a dub directory.
function CourseManager:getEntryForDirectory(dirIx,index)
	return self:getEntriesForDirectory(dirIx)[index]
end

--- Gets the number of entries in a sub directory of the root.
function CourseManager:getNumberOfEntriesForDirectory(dirIx)
	return #self:getEntriesForDirectory(dirIx)
end

--- Gets the number of entries.
function CourseManager:getNumberOfEntries()
	return #self:getEntries()
end

--- Gets the number of sub dictionaries.
function CourseManager:getNumberOfDirectories()
	return #self:getDirectories()
end


--- The current entry is the one on the top of the HUD. Scrolling the HUD changes the current entry.
function CourseManager:setCurrentEntry(num)
	self.currentEntry = math.max(math.min(num, #self.courseDirView:getEntries()), 1)
end

function CourseManager:getCurrentEntry()
	return self.currentEntry
end

function CourseManager:getLastEntry()
	return self:getEntryByIndex(#self.courseDirView:getEntries())
end

--- Return directory view displayed at index on the HUD
function CourseManager:getViewAtIndex(index)
	return self.courseDirView:getEntries()[self:getCurrentEntry() - 1 + index]
end

-- Unfold (expand) a folder
function CourseManager:unfold(index)
	local dir = self:getViewAtIndex(index)
	dir:unfold()
	self:debug('%s unfolded', dir:getName())
end

-- Fold (hide contents) a folder
function CourseManager:fold(index)
	local dir = self:getViewAtIndex(index)
	dir:fold()
	self:debug('%s folded', dir:getName())
end

function CourseManager:createDirectory(dir, name)
	-- if dir is given the new directory under that,
	-- otherwise under the root
	local parentDir = dir or self.courseDir
	parentDir:createDirectory(name)
	self:refresh()
end

--- Take all the courses currently assigned to the vehicle and concatenate them into a single course
--- and then save this course to the directory at index in the HUD
function CourseManager:saveCourseFromVehicle(directoryIx, vehicle, name)
	local dir = self:getDirectoryByIndex(directoryIx)
	self:debugVehicle(vehicle, 'saving course %s in folder %s', name, dir:getName())
	self:saveCourses(vehicle,dir:getFullPath() .. '/' .. name,name)
	self:refresh()
end

function CourseManager:saveCourses(vehicle,fullPath,name)
	local courseXml = XMLFile.create("courseXML", fullPath, CpCourseControl.rootKeyFileManager,CpCourseControl.xmlSchema)
	vehicle:saveAssignedCourses(courseXml,CpCourseControl.xmlKeyFileManager,name)
	courseXml:save()
	courseXml:delete()
	self:debug('Course %s saved in %s.', vehicle:getName(),fullPath)
end

--- Load the course shown in the HUD at index
function CourseManager:loadCourseSelectedInHud(vehicle, dirIx,entryIx)
	local file = self:getEntryForDirectory(dirIx,entryIx)
	local courseXml = XMLFile.load("courseXML",file:getFullPath(),CpCourseControl.xmlSchema)
	vehicle:loadAssignedCourses(courseXml,CpCourseControl.xmlKeyFileManager)
	courseXml:delete()
	self:debug('Course %s loaded in %s.', vehicle:getCurrentCourseName(),file:getFullPath())
end

function CourseManager:deleteDirectory(dirIx)
	local dir = self:getDirectoryByIndex(dirIx)
	if dir then
		dir:delete()
		self:refresh()
	end
end

function CourseManager:deleteEntityInDirectory(dirIx,entityIx)
	local entry = self:getEntryForDirectory(dirIx,entityIx)
	if entry then
		local file = entry:getEntity()
		file:delete()
		self:refresh()
	end
end

function CourseManager:renameCourse(dirIx,entityIx,name)
	local dir = self:getDirectoryByIndex(dirIx)
	local entry = self:getEntryForDirectory(dirIx,entityIx)
	local newPath = dir:getFullPath() .. "/"..name
	copyFile(entry:getFullPath(),newPath,false)
	self:deleteEntityInDirectory(dirIx,entityIx)
	self:refresh()
end

function CourseManager:renameFolder(dirIx,name)
	local dir = self:getDirectoryByIndex(dirIx)
	local entries = self:getEntriesForDirectory(dirIx)
	local newPath = dir:getParent():getFullPath() .. "/" .. name
	local oldPath = dir:getFullPath()
	self:createDirectory(nil,name)
	for i,entry in pairs(entries) do 
		copyFile(oldPath.."/"..entry:getName(),newPath.."/"..entry:getName(),false)
		local file = entry:getEntity()
		file:delete()
	end
	self:refresh()
	dir:delete()
	self:refresh()
end

function CourseManager:moveCourse(prevDirIx,entityIx,targetDirIx)
	local preEntry = self:getEntryForDirectory(prevDirIx,entityIx)
	local targetDir = self:getDirectoryByIndex(targetDirIx)
	local targetPath = targetDir:getFullPath() .. '/' .. preEntry:getName()
	copyFile(preEntry:getFullPath(),targetPath,false)
	self:deleteEntityInDirectory(prevDirIx,entityIx)
	self:debug('Moved course from %s to %s.',preEntry:getFullPath() ,targetPath)
	self:refresh()
end

--- For backwards compatibility, create all waypoints of all loaded courses for this vehicle, as it
--- used to be stored in the terrible global Waypoints variable
--- Update all the legacy (as usual global) data structures related to a vehicle's loaded course
-- TODO: once someone has the time and motivation, refactor those legacy structures
function CourseManager:updateLegacyWaypoints(vehicle)
	self.legacyWaypoints[vehicle] = {}
	local n = 1
	for _, course in ipairs(vehicle:getCourses()) do
		for i = 1, course:getNumberOfWaypoints() do
			table.insert(self.legacyWaypoints[vehicle], Waypoint(course:getWaypoint(i), n))
			n = n +1
		end
	end
end

function CourseManager:getLegacyWaypoints(vehicle)
	return self.legacyWaypoints[vehicle]
end

function CourseManager:getAllVehiclesWithCourses()
	return self.vehiclesWithCourses
end

function CourseManager:debug(...)
	CpUtil.debugFormat(CpDebug.DBG_COURSES, string.format(...))
end

function CourseManager:debugVehicle(vehicle,...)
	CpUtil.debugVehicle(CpDebug.DBG_COURSES,vehicle, string.format(...))
end

function CourseManager:dump()
	for _, assignment in ipairs(self.assignments) do
		for _, course in ipairs(assignment.courses) do
			self:debugVehicle( assignment.vehicle, 'course: %s', course:getName())
		end
	end
	return 'courses dumped.'
end

-- Recreate if already exists. This is only for development to recreate the global instance if this
-- file is reloaded while the game is running
if g_courseManager then
	local old_courseManager = g_courseManager
	g_courseManager = CourseManager(g_Courseplay.baseDir)
	-- preserve the existing vehicle/course assignments
	g_courseManager.assignments = old_courseManager.assignments
	g_courseManager.legacyWaypoints = old_courseManager.legacyWaypoints
end