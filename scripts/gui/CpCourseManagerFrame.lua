

--[[
	This frame is a page for the course manager.
]]--

CpCourseManagerFrame = {
	CONTROLS = {
		HEADER = "header",
		MAIN_BOC = "mainBox",
		LEFT_COLUMN = "leftColumn",
		RIGHT_COLUMN = "rightColumn",
		LEFT_LIST = "leftList",
		RIGHT_LIST = "rightList",
		LEFT_COLUMN_HEADER ="leftColumnHeader",
		RIGHT_COLUMN_HEADER = "rightColumnHeader",
	},
}

CpCourseManagerFrame.translations = {
	title = "CP_courseManager_title",

	loadCourse = "CP_courseManager_load_courses",
	saveCourse = "CP_courseManager_save_courses",
	clearCurrentCourse = "CP_courseManager_clear_current_courses",
	editCourse = "CP_courseManager_edit_course",

	changeMode = "CP_courseManager_change_mode",
	activate = "CP_courseManager_activate",

	deleteEntry = "CP_courseManager_delete_entry",
	renameEntry = "CP_courseManager_rename_entry",
	createDirectory = "CP_courseManager_create_directory",
	moveEntry = "CP_courseManager_move_entry",
	copyEntry = "CP_courseManager_copy_entry",
	
	folderDialogTitle = "CP_courseManager_folder_dialog",
	courseDialogTitle = "CP_courseManager_course_dialog",

	deleteWarning = "CP_courseManager_deleteWarning",
	editWarning = "CP_courseManager_editCourseWarning",

	deleteError = "CP_courseManager_deleteError",
	entryExistAlreadyError = "CP_courseManager_entryExistAlreadyError",
	noAccessError = "CP_courseManager_noAccessError",
	targetIsNoFolder = "CP_courseManager_targetIsNoFolderError",
	targetIsNoCourse = "CP_courseManager_targetIsNoCourseError",

	basicSettings = "CP_courseManager_basicSettings",
	advancedSettings = "CP_courseManager_advancedSettings",
}

CpCourseManagerFrame.minMode = 1
CpCourseManagerFrame.maxMode = 2

CpCourseManagerFrame.actionStates = {
	disabled = 0,
	saveCourse = 1,
	loadCourse = 2,
	createDirectory = 3,
	moveEntrySelect = 4,
	moveEntryDestination = 5,
	deleteEntry = 6,
	renameEntry = 7,
	copyEntrySelect = 8,
	copyEntryDestination = 9,
}

CpCourseManagerFrame.colors = {
	move = {0, 0, 0, 0.35},
	default = {0.3140, 0.8069, 1.0000, 0.02}
}

local CpCourseManagerFrame_mt = Class(CpCourseManagerFrame, TabbedMenuFrameElement)

function CpCourseManagerFrame.new(courseStorage,target, custom_mt)
	local self = TabbedMenuFrameElement.new(target, custom_mt or CpCourseManagerFrame_mt)
	self:registerControls(CpCourseManagerFrame.CONTROLS)
	self.courseStorage = courseStorage
	return self
end


function CpCourseManagerFrame:onGuiSetupFinished()
	CpCourseManagerFrame:superClass().onGuiSetupFinished(self)
	

	
	--- Changes the input actions.
	self.modeButton = {
		profile = "buttonActivate",
		inputAction = InputAction.MENU_ACTIVATE,
		text = g_i18n:getText(self.translations.changeMode),
		callback = function ()
			self.onClickChangeMode(self)
			self:updateMenuButtons()
		end,
		callbackDisabled = self.modeDisabled,
	}
	self.activateButton = {
		profile = "buttonSelect",
		inputAction = InputAction.MENU_ACTIVATE,
		text = g_i18n:getText(self.translations.activate),
		callback = function ()
			self.onClickActivate(self)
			self:updateMenuButtons()
		end,
		callbackDisabled = self.activateDisabled,
	}

	self.modes = {
		{
			--- Loads the current course
			{
				profile = "buttonActivate",
				inputAction = InputAction.MENU_EXTRA_1,
				text = g_i18n:getText(self.translations.loadCourse),
				callback = function ()
					self.actionState = self.actionStates.loadCourse
					self:updateMenuButtons()
				end,
				callbackDisabled = self.loadCourseDisabled,
			},
			---  Clears the current course
			{
				profile = "buttonActivate",
				inputAction = InputAction.MENU_CANCEL,
				text = g_i18n:getText(self.translations.clearCurrentCourse),
				callback = function ()
					self.onClickClearCurrentCourse(self)
					self:updateMenuButtons()
				end,
				callbackDisabled = self.clearCurrentCourseDisabled
			},
			---  Opens the course editor.
			{
				profile = "buttonActivate",
				inputAction = InputAction.MENU_CANCEL,
				text = g_i18n:getText(self.translations.editCourse),
				callback = function ()
					self.onClickOpenEditor(self)
					self:updateMenuButtons()
				end,
				callbackDisabled = self.openEditorDisabled
			},
			--- Saves the current courses.
			{
				profile = "buttonActivate",
				inputAction = InputAction.MENU_EXTRA_1,
				text = g_i18n:getText(self.translations.saveCourse),
				callback = function ()
					self.actionState = self.actionStates.saveCourse
					self:updateMenuButtons()
				end,
				callbackDisabled = self.saveCourseDisabled,
			},
			--- Creates a new directory
			{
				profile = "buttonActivate",
				inputAction = InputAction.MENU_EXTRA_2,
				text = g_i18n:getText(self.translations.createDirectory),
				callback = function ()
					CpCourseManagerFrame.showInputTextDialog(
					self,self.translations.folderDialogTitle,
					self.onClickCreateDirectoryDialog)
				--	self.actionState = CpCourseManagerFrame.actionStates.createDirectory
					self:updateMenuButtons()
				end,
				callbackDisabled = self.createDirectoryDisabled,
			},
		},
		{
			--- Moves an entry
			{
				profile = "buttonActivate",
				inputAction = InputAction.MENU_CANCEL,
				text = g_i18n:getText(self.translations.moveEntry),
				callback = function ()
					self.actionState = self.actionStates.moveEntrySelect
					self:updateMenuButtons()
				end,
				callbackDisabled = self.moveEntryDisabled
			},
			--- Copy an entry
--			{
--				profile = "buttonActivate",
--				inputAction = InputAction.MENU_ACTIVATE,
--				text = g_i18n:getText(CpCourseManagerFrame.translations.copyEntry),
--				callback = function ()
--					self.actionState = CpCourseManagerFrame.actionStates.copyEntrySelect
--					self:updateMenuButtons()
--				end,
--				callbackDisabled = CpCourseManagerFrame.copyEntryDisabled
--			},
			--- Delete
			{
				profile = "buttonActivate",
				inputAction = InputAction.MENU_EXTRA_1,
				text = g_i18n:getText(self.translations.deleteEntry),
				callback = function ()
					self.actionState = self.actionStates.deleteEntry
					self:updateMenuButtons()
				end,
				callbackDisabled = self.deleteEntryDisabled
			},
			--- Rename
			{
				profile = "buttonActivate",
				inputAction = InputAction.MENU_EXTRA_2,
				text = g_i18n:getText(self.translations.renameEntry),
				callback = function ()
					self.actionState = self.actionStates.renameEntry
					self:updateMenuButtons()
				end,
				callbackDisabled = self.renameEntryDisabled
			}
		},
	}
	self.leftList:setDataSource(self)
	self.rightList:setDataSource(self)
end
function CpCourseManagerFrame:onFrameOpen()
	InGameMenuPricesFrame:superClass().onFrameOpen(self)
	self.curMode = self.minMode
	self.actionState = self.actionStates.disabled
	self.selectedEntry = nil
	self.currentVehicle = CpInGameMenuAIFrameExtended.getVehicle()
	self:setSoundSuppressed(true)
	FocusManager:loadElementFromCustomValues(self.leftList)
	FocusManager:loadElementFromCustomValues(self.rightList)
	FocusManager:linkElements(self.leftList, FocusManager.RIGHT, self.rightList)
	FocusManager:linkElements(self.rightList, FocusManager.LEFT, self.leftList)
	self:updateLists()
	FocusManager:setFocus(self.leftList)
	self:setSoundSuppressed(false)
	self.initialized = true
end
	
function CpCourseManagerFrame:onFrameClose()
	if self.moveElementSelected then
		self.moveElementSelected.element:setAlternating(false)
	end
	InGameMenuPricesFrame:superClass().onFrameClose(self)
	self.initialized = false
end

function CpCourseManagerFrame:updateLists()
	self.courseStorage:refresh()
	self.leftColumnHeader:setText(self.courseStorage:getCurrentDirectoryViewPath())
	self.leftList:reloadData()
	self.rightList:reloadData()
	self:updateMenuButtons()
end

function CpCourseManagerFrame:getNumberOfItemsInSection(list, section)
	local numOfDirs = self.courseStorage:getNumberOfEntries()
	
	if list == self.leftList then
		return numOfDirs
	else
		if numOfDirs <=0 then 
			return 0
		end
		local ix = self.leftList:getSelectedIndexInSection()
		return self.courseStorage:getNumberOfEntriesForIndex(ix) or 0
	end
end

function CpCourseManagerFrame.setFolderIcon(element)
	element.iconImageSize = {32,32}
	element:setImageFilename(Utils.getFilename('img/iconSprite.dds', g_Courseplay.BASE_DIRECTORY))
	element:setImageUVs(nil,unpack(GuiUtils.getUVs({0,220,32,32},{256,512})))
	element:setImageColor(nil,0, 0, 0, 0.5)
end

function CpCourseManagerFrame.setCourseIcon(element)
	element.iconImageSize = {32,32}
	element:setImageFilename(Utils.getFilename('img/iconSprite.dds', g_Courseplay.BASE_DIRECTORY))
	element:setImageUVs(nil,unpack(GuiUtils.getUVs({40,76,32,32},{256,512})))
	element:setImageColor(nil,0, 0, 0, 0.5)
end


function CpCourseManagerFrame:populateCellForItemInSection(list, section, index, cell)
	if list == self.leftList then
		local entry =  self.courseStorage:getEntryByIndex(index)
		cell.viewEntry = entry
		if entry:isDirectory() then
			self.setFolderIcon(cell:getAttribute("icon"))
		else 
			self.setCourseIcon(cell:getAttribute("icon"))
		end
		cell:getAttribute("icon"):setVisible(true)
		cell:getAttribute("title"):setText(entry and entry:getName() or "unknown: "..index)
		cell.target = self
		cell:setCallback("onClickCallback", "onClickLeftItem")
	else
	--	cell.alternateBackgroundColor =  CpCourseManagerFrame.colors.move
		local ix = self.leftList:getSelectedIndexInSection()
		local entry = self.courseStorage:getSubEntryByIndex(ix,index)
		cell.viewEntry = entry
		if entry:isDirectory() then
			self.setFolderIcon(cell:getAttribute("icon"))
		else 
			self.setCourseIcon(cell:getAttribute("icon"))
		end
		cell:getAttribute("icon"):setVisible(true)

		cell:getAttribute("title"):setText(entry and entry:getName() or "unknown: "..index)
		cell.target = self
		cell:setCallback("onClickCallback", "onClickRightItem")
		
	end
end


function CpCourseManagerFrame:onClickLeftItem(element)
	self:onClickItem(self.leftList,element)
end


function CpCourseManagerFrame:onClickRightItem(element)
	self:onClickItem(self.rightList,element)
end

function CpCourseManagerFrame:onClickItem(layout,element)
	local viewEntry = element.viewEntry
	if viewEntry == nil then 
		return 
	end
	if self.actionState == self.actionStates.disabled then
		--- If no action is taking place, then allow traversing the file system in the left layout.
		if viewEntry:isDirectory() and layout == self.leftList and layout:getSelectedElement() == element then 
			self.courseStorage:iterateForwards(element.viewEntry)
		end
	elseif self.actionState == self.actionStates.loadCourse then 
		--- If a file/course was select then allow loading of the course.
		if not viewEntry:isDirectory() then
			self.currentVehicle:appendLoadedCpCourse(viewEntry:getEntity())
		else
			self.showInfoDialog(
				self.translations.targetIsNoCourse,viewEntry)
		end
		self.actionState = self.actionStates.disabled
	elseif self.actionState == self.actionStates.saveCourse then 
		--- Saves the course under a selected directory.
		if viewEntry:isDirectory() then 
			self.showInputTextDialog(
				self,self.translations.courseDialogTitle,
				self.onClickSaveEntryDialog,viewEntry)
		else 
			self.showInfoDialog(
				self.translations.targetIsNoFolder,viewEntry)
		end
		self.actionState = self.actionStates.disabled
	elseif self.actionState == self.actionStates.createDirectory then
		--- Creates a new sub directory under a selected directory.
		if viewEntry:isDirectory() then 
			self.showInputTextDialog(
				self,self.translations.folderDialogTitle,
				self.onClickCreateDirectoryDialog,viewEntry)
		else 
			self.showInfoDialog(
				self.translations.targetIsNoFolder,viewEntry)
		end
		self.actionState = self.actionStates.disabled
	elseif self.actionState == self.actionStates.moveEntrySelect then
		--- Selected a entity to move.
		if viewEntry:hasAccess() then
			self.selectedEntry = viewEntry 
			self.actionState = self.actionStates.moveEntryDestination
		else 
			self.showInfoDialog(
				self.translations.noAccessError,viewEntry)
			self.actionState = self.actionStates.disabled
		end
	elseif self.actionState == self.actionStates.moveEntryDestination then
		--- Moves the previous selected entity to a given directory.
		if viewEntry:isDirectory() then 
			self.courseStorage:validate(viewEntry)
			local wasMoved = self.selectedEntry:move(viewEntry)
			if not wasMoved then 
				self.showInfoDialog(
					self.translations.entryExistAlreadyError,viewEntry)
			end
		else 
			self.showInfoDialog(
				self.translations.targetIsNoFolder,viewEntry)
		end
		self.selectedEntry = nil
		self.actionState = self.actionStates.disabled
	elseif self.actionState == self.actionStates.deleteEntry then
		--- Deletes a selected entity.
		if viewEntry:isDeleteAllowed() then 
			self.showYesNoDialog(
				self,self.translations.deleteWarning,
				self.onClickDeleteEntryDialog,viewEntry)
		else 
			self.showInfoDialog(
				self.translations.noAccessError,viewEntry)
		end
		self.actionState = self.actionStates.disabled
	elseif self.actionState == self.actionStates.renameEntry then 
		--- Renames a selected entity.
		if viewEntry:isRenameAllowed() then
			self.showInputTextDialog(
						self,self.translations.renameEntry,
						self.onClickRenameEntryDialog,viewEntry)
		else 
			self.showInfoDialog(
				self.translations.noAccessError,viewEntry)
		end
		self.actionState = self.actionStates.disabled
	elseif self.actionState == self.actionStates.copyEntrySelect then 
		--- Selected a entity to copy.
		if viewEntry:hasAccess() then
			self.selectedEntry = viewEntry 
			self.actionState = self.actionStates.copyEntryDestination
		else
			self.showInfoDialog(
				self.translations.noAccessError,viewEntry)
			self.actionState = self.actionStates.disabled
		end
	elseif self.actionState == self.actionStates.copyEntryDestination then 
		--- Copies the previous selected entity to a given directory.
		if viewEntry:isDirectory() then 
			local wasCopied = self.selectedEntry:copy(viewEntry)
			if not wasCopied then 
				self.showInfoDialog(
					self.translations.entryExistAlreadyError,viewEntry)
			end
		else
			self.showInfoDialog(
				self.translations.targetIsNoFolder,viewEntry)
		end
		self.selectedEntry = nil
		self.actionState = self.actionStates.disabled
	end
	self:updateLists()
	CpUtil.debugFormat(CpUtil.DBG_HUD,"actionState -> %d",self.actionState)
end

function CpCourseManagerFrame:onListSelectionChanged(list, section, index)
	if list == self.leftList then 
		self.rightList:reloadData()
--		CpUtil.debugFormat(CpUtil.DBG_HUD,"leftList -> onListSelectionChanged")
	else
--		CpUtil.debugFormat(CpUtil.DBG_HUD,"rightList -> onListSelectionChanged")
	end
	self:updateMenuButtons()
end

--- Updates the button at the bottom, which depends on the current select mode.
function CpCourseManagerFrame:updateMenuButtons()
	local courseName = self.currentVehicle:getCurrentCpCourseName()
	local title = string.format(g_i18n:getText(self.translations.title),self.currentVehicle:getName(),courseName)
	
	self.header:setText(title)
	self.menuButtonInfo = {
		{
			inputAction = InputAction.MENU_BACK,
		}
	}
	if self.courseStorage:getCanIterateBackwards() then
		self.menuButtonInfo[1].callback = function () self:onClickIterateBack() end
	end
	if self.activateButton.callbackDisabled == nil or not self.activateButton.callbackDisabled(self) then
		table.insert(self.menuButtonInfo,self.activateButton)
	end
	if self.modeButton.callbackDisabled == nil or not self.modeButton.callbackDisabled(self) then
		table.insert(self.menuButtonInfo,self.modeButton)
	end
	for i,data in pairs(self.modes[self.curMode]) do 
		if data.callbackDisabled == nil or not data.callbackDisabled(self) then
			table.insert(self.menuButtonInfo,data)
		end
	end	
	self:setMenuButtonInfoDirty()
	local text = self.curMode == self.minMode and g_i18n:getText(self.translations.basicSettings)
					or  g_i18n:getText(self.translations.advancedSettings)
	self.rightColumnHeader:setText(text)
	--self.rightToggleBtn:setText(text)
end

---------------------------------------------------
--- Menu button click callbacks
---------------------------------------------------

--- Traverse back a directory.
function CpCourseManagerFrame:onClickIterateBack()
	self.courseStorage:iterateBackwards()
	self:updateLists()
end

--- Changes the current possible actions.
function CpCourseManagerFrame:onClickChangeMode()
	self.curMode = self.curMode + 1
	if self.curMode > self.maxMode then 
		self.curMode = self.minMode
	end
	CpUtil.debugFormat(CpUtil.DBG_HUD,"onClickChangeMode")
	self.actionState = self.actionStates.disabled
	self.selectedEntry = nil
	--- CpCourseManagerFrame.updateLists(self)
end

--- Clears the current courses.
function CpCourseManagerFrame:onClickClearCurrentCourse()
	CpUtil.debugFormat(CpUtil.DBG_HUD,"onClickClearCurrentCourse")
	local hasCourse = self.currentVehicle:hasCpCourse()
	if hasCourse then 
		self.currentVehicle:resetCpCoursesFromGui()
	end
	self:updateLists()
end

--- Saves the current vehicle courses with a given name.
function CpCourseManagerFrame:onClickSaveEntryDialog(text,clickOk,viewEntry)
	if clickOk then 
		CpUtil.debugFormat(CpUtil.DBG_HUD,"onClickSaveEntryDialog - > %s",text)

		local file,fileCreated = viewEntry:addFile(text)
		if not fileCreated then 
			self.showInfoDialog(
				self.translations.entryExistAlreadyError,viewEntry)
			return 
		end
		self.currentVehicle:saveCpCourses(file,text)
	end
end

--- Creates a new directory with a given name.
function CpCourseManagerFrame:onClickCreateDirectoryDialog(text,clickOk,viewEntry)
	if clickOk then 
		CpUtil.debugFormat(CpUtil.DBG_HUD,"onClickCreateDirectoryDialog - > %s",text)
		local wasAdded = self.courseStorage:createDirectory(text)
		if not wasAdded then 
			self.showInfoDialog(
				self.translations.entryExistAlreadyError,viewEntry)
		end
	end
end

--- Creates a new directory with a given name.
function CpCourseManagerFrame:onClickDeleteEntryDialog(clickOk,viewEntry)
	if clickOk then 
		CpUtil.debugFormat(CpUtil.DBG_HUD,"onClickDeleteEntryDialog")
		self.courseStorage:validate(viewEntry)
		local wasDeleted = viewEntry:delete()
		if not wasDeleted then 
			self.showInfoDialog(
				self.translations.deleteError,viewEntry)
		end
	end
end

function CpCourseManagerFrame:onClickRenameEntryDialog(text,clickOk,viewEntry)
	if clickOk then 
		CpUtil.debugFormat(CpUtil.DBG_HUD,"onClickRenameEntryDialog - > %s",text)
		self.courseStorage:validate(viewEntry)
		local wasRenamed = viewEntry:rename(text)
		if not wasRenamed then 
			self.showInfoDialog(
				self.translations.entryExistAlreadyError,viewEntry)
		end
	end
end

function CpCourseManagerFrame:onClickActivate()
	local layout = FocusManager:getFocusedElement()
	if layout then  
		local element = layout:getSelectedElement()
		self:onClickItem(layout,element)
	end
end

function CpCourseManagerFrame:onClickOpenEditor()
	local layout = FocusManager:getFocusedElement()
	if layout then  
		local element = layout:getSelectedElement()
		local viewEntry = element.viewEntry
		if viewEntry == nil then 
			return 
		end
		if not viewEntry:isDirectory() then 
			g_courseEditor:activate(viewEntry:getEntity())
			self.showInfoDialog(
				self.translations.editWarning, viewEntry)
		else 
			self.showInfoDialog(
				self.translations.targetIsNoCourse,viewEntry)
		end
	end
end

---------------------------------------------------
--- Gui dialogs
---------------------------------------------------


function CpCourseManagerFrame:showInputTextDialog(title,callbackFunc,viewEntry)
	g_gui:showTextInputDialog({
		disableFilter = true,
		callback = function (self,text,clickOk,viewEntry)
			callbackFunc(self,text,clickOk,viewEntry)
			self:updateLists()
		end,
		target = self,
		defaultText = "",
		dialogPrompt = string.format(g_i18n:getText(title),viewEntry and viewEntry:getName()),
		imePrompt = g_i18n:getText(title),
		maxCharacters = 50,
		confirmText = g_i18n:getText("button_ok"),
		args = viewEntry
	})
end

function CpCourseManagerFrame:showYesNoDialog(title,callbackFunc,viewEntry)
	g_gui:showYesNoDialog({
		text = string.format(g_i18n:getText(title),viewEntry:getName()),
		callback = function (self,clickOk,viewEntry)
			callbackFunc(self,clickOk,viewEntry)
			self:updateLists()
		end,
		target = self,
		args = viewEntry
	})
end

function CpCourseManagerFrame.showInfoDialog(title,viewEntry)
	g_gui:showInfoDialog({
		text = string.format(g_i18n:getText(title),viewEntry:getName())
	})
end

---------------------------------------------------
--- Menu button disabled callbacks
---------------------------------------------------

function CpCourseManagerFrame:clearCurrentCourseDisabled()
	return not self.currentVehicle:hasCpCourse() or self.actionState ~= self.actionStates.disabled
end

function CpCourseManagerFrame:loadCourseDisabled()
	return self.currentVehicle:hasCpCourse() or self.actionState ~= self.actionStates.disabled or not self.courseStorage.currentDirectoryView:areEntriesVisible()
end

function CpCourseManagerFrame:saveCourseDisabled()
	return not self.currentVehicle:hasCpCourse() or self.actionState ~= self.actionStates.disabled or not self.courseStorage.currentDirectoryView:areEntriesVisible()
end

function CpCourseManagerFrame:createDirectoryDisabled()
	return self.actionState ~= self.actionStates.disabled or not self.courseStorage.currentDirectoryView:areEntriesVisible()
end

function CpCourseManagerFrame:moveEntryDisabled()
	return self.actionState ~= self.actionStates.disabled or not self.courseStorage.currentDirectoryView:areEntriesVisible()
end

function CpCourseManagerFrame:copyEntryDisabled()
	return self.actionState ~= self.actionStates.disabled or not self.courseStorage.currentDirectoryView:areEntriesVisible()
end

function CpCourseManagerFrame:deleteEntryDisabled()
	return self.actionState ~= self.actionStates.disabled or not self.courseStorage.currentDirectoryView:areEntriesVisible()
end

function CpCourseManagerFrame:renameEntryDisabled()
	return self.actionState ~= self.actionStates.disabled or not self.courseStorage.currentDirectoryView:areEntriesVisible()
end

function CpCourseManagerFrame:activateDisabled()
	return self.actionState == self.actionStates.disabled
end

function CpCourseManagerFrame:modeDisabled()
	return self.actionState ~= self.actionStates.disabled
end

function CpCourseManagerFrame:openEditorDisabled()
	return not self:clearCurrentCourseDisabled() or self.actionState ~= self.actionStates.disabled
end
