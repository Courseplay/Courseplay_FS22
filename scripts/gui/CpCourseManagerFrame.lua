
--[[
	This frame is a page for the course manager.
]]--

CpCourseManagerFrame = {}
CpCourseManagerFrame.translations = {
	["title"] = "CP_courseManager_title",

	["loadCourse"] = "CP_courseManager_load_courses",
	["saveCourse"] = "CP_courseManager_save_courses",
	["clearCurrentCourse"] = "CP_courseManager_clear_current_courses",
	
	["changeMode"] = "CP_courseManager_change_mode",

	["deleteEntry"] = "CP_courseManager_delete_entry",
	["renameEntry"] = "CP_courseManager_rename_entry",
	["createDirectory"] = "CP_courseManager_create_directory",
	["moveEntry"] = "CP_courseManager_move_entry",
	["copyEntry"] = "CP_courseManager_copy_entry",
	
	["folderDialogTitle"] = "CP_courseManager_folder_dialog",
	["courseDialogTitle"] = "CP_courseManager_course_dialog",

	["deleteWarning"] = "CP_courseManager_deleteWarning",

	["deleteError"] = "CP_courseManager_deleteError",
	["entryExistAlreadyError"] = "CP_courseManager_entryExistAlreadyError",
	["noAccessError"] = "CP_courseManager_noAccessError",
	["targetIsNoFolder"] = "CP_courseManager_targetIsNoFolderError",
	["targetIsNoCourse"] = "CP_courseManager_targetIsNoCourseError",

	["basicSettings"] = "CP_courseManager_basicSettings",
	["advancedSettings"] = "CP_courseManager_advancedSettings",
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

---Creates the in game menu page.
function CpCourseManagerFrame.init(courseStorage)

	local inGameMenu = g_gui.screenControllers[InGameMenu]
	local function predicateFunc()
		local inGameMenu = g_gui.screenControllers[InGameMenu]
		local aiPage = inGameMenu.pageAI
		return aiPage.currentHotspot ~= nil
	end
	local page = CpGuiUtil.getNewInGameMenuFrame(inGameMenu,inGameMenu.pagePrices,CpCourseManagerFrame
												,predicateFunc,3,{256,0,128,128})
	inGameMenu.pageCourseManager = page
	inGameMenu.pageCourseManager.onClickItem = CpCourseManagerFrame.onClickItem
	inGameMenu.pageCourseManager.onClickLeftItem = CpCourseManagerFrame.onClickLeftItem
	inGameMenu.pageCourseManager.onClickRightItem = CpCourseManagerFrame.onClickRightItem
	inGameMenu.pageCourseManager.onClickIterateBack = CpCourseManagerFrame.onClickIterateBack
	inGameMenu.pageCourseManager.courseStorage = courseStorage
end

--- Setup of the gui elements and binds the settings to the gui elements.
function CpCourseManagerFrame:initialize()
	local inGameMenu = g_gui.screenControllers[InGameMenu]
	self.rightLayout = self.priceList
	self.leftLayout = self.productList
	
	--- Changes titles
	self.pageTitle = CpGuiUtil.getFirstElementWithProfileName(self,"ingameMenuFrameHeaderText") 
	local elements = CpGuiUtil.getElementsWithProfileName(self,"ingameCalendarHeaderBox")

	self.leftLayoutTitle = elements[1].elements[1]
	self.leftLayoutTitle:setText("")
	self.leftLayoutTitle.textUpperCase = false
	elements[1].elements[2]:delete()
	local rightLayoutTitle = elements[2].elements[1]
	self.rightToggleBtn = ButtonElement.new(self)
	TextElement.copyAttributes(self.rightToggleBtn,rightLayoutTitle)
	rightLayoutTitle.parent:addElement(self.rightToggleBtn)
	rightLayoutTitle.parent:invalidateLayout()
	self.rightToggleBtn.target = self
	self.rightToggleBtn.onClickCallback = function(self) 
												CpCourseManagerFrame.onClickChangeMode(self) 
												self:updateMenuButtons()
											end 
	self.rightToggleBtn:setVisible(true)
	self.rightToggleBtn.textUpperCase = false
	elements[2].elements[2]:delete()
	elements[2].elements[2]:delete()
	rightLayoutTitle:delete()
	--- Deletes unused layout.
	self:getDescendantById("fluctuationsColumn"):delete()
	self.noSellpointsText:delete()

	--- Changes the input actions.
	self.modeButton = {
		profile = "buttonActivate",
		inputAction = InputAction.MENU_ACTIVATE,
		text = g_i18n:getText(CpCourseManagerFrame.translations.changeMode),
		callback = function ()
			CpCourseManagerFrame.onClickChangeMode(self)
			self:updateMenuButtons()
		end
	}

	self.modes = {
		{
			--- Loads the current course
			{
				profile = "buttonActivate",
				inputAction = InputAction.MENU_ACTIVATE,
				text = g_i18n:getText(CpCourseManagerFrame.translations.loadCourse),
				callback = function ()
					self.actionState = CpCourseManagerFrame.actionStates.loadCourse
					self:updateMenuButtons()
				end,
				callbackDisabled = CpCourseManagerFrame.loadCourseDisabled,
			},
			---  Clears the current course
			{
				profile = "buttonActivate",
				inputAction = InputAction.MENU_CANCEL,
				text = g_i18n:getText(CpCourseManagerFrame.translations.clearCurrentCourse),
				callback = function ()
					CpCourseManagerFrame.onClickClearCurrentCourse(self)
					self:updateMenuButtons()
				end,
				callbackDisabled = CpCourseManagerFrame.clearCurrentCourseDisabled
			},
			--- Saves the current courses.
			{
				profile = "buttonActivate",
				inputAction = InputAction.MENU_EXTRA_1,
				text = g_i18n:getText(CpCourseManagerFrame.translations.saveCourse),
				callback = function ()
					self.actionState = CpCourseManagerFrame.actionStates.saveCourse
					self:updateMenuButtons()
				end,
				callbackDisabled = CpCourseManagerFrame.saveCourseDisabled,
			},
			--- Creates a new directory
			{
				profile = "buttonActivate",
				inputAction = InputAction.MENU_EXTRA_2,
				text = g_i18n:getText(CpCourseManagerFrame.translations.createDirectory),
				callback = function ()
					CpCourseManagerFrame.showInputTextDialog(
					self,CpCourseManagerFrame.translations.folderDialogTitle,
						CpCourseManagerFrame.onClickCreateDirectoryDialog)
				--	self.actionState = CpCourseManagerFrame.actionStates.createDirectory
					self:updateMenuButtons()
				end,
				callbackDisabled = CpCourseManagerFrame.createDirectoryDisabled,
			},
		},
		{
			--- Moves an entry
			{
				profile = "buttonActivate",
				inputAction = InputAction.MENU_ACTIVATE,
				text = g_i18n:getText(CpCourseManagerFrame.translations.moveEntry),
				callback = function ()
					self.actionState = CpCourseManagerFrame.actionStates.moveEntrySelect
					self:updateMenuButtons()
				end,
				callbackDisabled = CpCourseManagerFrame.moveEntryDisabled
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
				text = g_i18n:getText(CpCourseManagerFrame.translations.deleteEntry),
				callback = function ()
					self.actionState = CpCourseManagerFrame.actionStates.deleteEntry
					self:updateMenuButtons()
				end,
				callbackDisabled = CpCourseManagerFrame.deleteEntryDisabled
			},
			--- Rename
			{
				profile = "buttonActivate",
				inputAction = InputAction.MENU_EXTRA_2,
				text = g_i18n:getText(CpCourseManagerFrame.translations.renameEntry),
				callback = function ()
					self.actionState = CpCourseManagerFrame.actionStates.renameEntry
					self:updateMenuButtons()
				end,
				callbackDisabled = CpCourseManagerFrame.renameEntryDisabled
			}
		},
	}
end

function CpCourseManagerFrame:onGuiSetupFinished()
	InGameMenuPricesFrame:superClass().onGuiSetupFinished(self)
	self.leftLayout:setDataSource(self)
	self.leftLayout.delegate = self
	self.rightLayout:setDataSource(self)
	self.rightLayout.delegate = self
end

function CpCourseManagerFrame:onFrameOpen()
	InGameMenuPricesFrame:superClass().onFrameOpen(self)
	self.curMode = CpCourseManagerFrame.minMode
	self.actionState = CpCourseManagerFrame.actionStates.disabled
	self.selectedEntry = nil

	local currentHotspot = g_currentMission.inGameMenu.pageAI.currentHotspot
	self.currentVehicle =  InGameMenuMapUtil.getHotspotVehicle(currentHotspot)
	self:setSoundSuppressed(true)
	FocusManager:setFocus(self.leftLayout)
	self:setSoundSuppressed(false)
	CpCourseManagerFrame.updateLists(self)
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
	self.leftLayoutTitle:setText(self.courseStorage:getCurrentDirectoryViewPath())
	self.leftLayout:reloadData()
	self.rightLayout:reloadData()
	self:updateMenuButtons()
end

function CpCourseManagerFrame:getNumberOfItemsInSection(list, section)
	local numOfDirs = self.courseStorage:getNumberOfEntries()
	
	if list == self.leftLayout then
		return numOfDirs
	else
		if numOfDirs <=0 then 
			return 0
		end
		local ix = self.leftLayout:getSelectedIndexInSection()
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
	if list == self.leftLayout then
		local entry =  self.courseStorage:getEntryByIndex(index)
		cell.viewEntry = entry
		if entry:isDirectory() then
			CpCourseManagerFrame.setFolderIcon(cell:getAttribute("icon"))
		else 
			CpCourseManagerFrame.setCourseIcon(cell:getAttribute("icon"))
		end
		cell:getAttribute("icon"):setVisible(true)
		cell:getAttribute("title"):setText(entry and entry:getName() or "unknown: "..index)
		cell.target = self
		cell:setCallback("onClickCallback", "onClickLeftItem")
	else
	--	cell.alternateBackgroundColor =  CpCourseManagerFrame.colors.move
		local ix = self.leftLayout:getSelectedIndexInSection()
		local entry = self.courseStorage:getSubEntryByIndex(ix,index)
		cell.viewEntry = entry
		if entry:isDirectory() then
			CpCourseManagerFrame.setFolderIcon(cell:getAttribute("hotspot"))
		else 
			CpCourseManagerFrame.setCourseIcon(cell:getAttribute("hotspot"))
		end
		cell:getAttribute("hotspot"):setVisible(true)

		cell:getAttribute("title"):setText(entry and entry:getName() or "unknown: "..index)

		cell:getAttribute("price"):setVisible(false)
		cell:getAttribute("buyPrice"):setVisible(false)
		cell:getAttribute("priceTrend"):setVisible(false)

		cell.target = self
		cell:setCallback("onClickCallback", "onClickRightItem")
		
	end
end


function CpCourseManagerFrame:onClickLeftItem(element)
	self:onClickItem(self.leftLayout,element)
end


function CpCourseManagerFrame:onClickRightItem(element)
	self:onClickItem(self.rightLayout,element)
end

function CpCourseManagerFrame:onClickItem(layout,element)
	local viewEntry = element.viewEntry
	if viewEntry == nil then 
		return 
	end
	if self.actionState == CpCourseManagerFrame.actionStates.disabled then
		--- If no action is taking place, then allow traversing the file system in the left layout.
		if viewEntry:isDirectory() and layout == self.leftLayout and layout:getSelectedElement() == element then 
			self.courseStorage:iterateForwards(element.viewEntry)
		end
	elseif self.actionState == CpCourseManagerFrame.actionStates.loadCourse then 
		--- If a file/course was select then allow loading of the course.
		if not viewEntry:isDirectory() then
			self.currentVehicle:appendLoadedCpCourse(viewEntry:getEntity())
		else
			CpCourseManagerFrame.showInfoDialog(
				CpCourseManagerFrame.translations.targetIsNoCourse,viewEntry)
		end
		self.actionState = CpCourseManagerFrame.actionStates.disabled
	elseif self.actionState == CpCourseManagerFrame.actionStates.saveCourse then 
		--- Saves the course under a selected directory.
		if viewEntry:isDirectory() then 
			CpCourseManagerFrame.showInputTextDialog(
				self,CpCourseManagerFrame.translations.courseDialogTitle,
					CpCourseManagerFrame.onClickSaveEntryDialog,viewEntry)
		else 
			CpCourseManagerFrame.showInfoDialog(
				CpCourseManagerFrame.translations.targetIsNoFolder,viewEntry)
		end
		self.actionState = CpCourseManagerFrame.actionStates.disabled
	elseif self.actionState == CpCourseManagerFrame.actionStates.createDirectory then
		--- Creates a new sub directory under a selected directory.
		if viewEntry:isDirectory() then 
			CpCourseManagerFrame.showInputTextDialog(
				self,CpCourseManagerFrame.translations.folderDialogTitle,
					CpCourseManagerFrame.onClickCreateDirectoryDialog,viewEntry)
		else 
			CpCourseManagerFrame.showInfoDialog(
				CpCourseManagerFrame.translations.targetIsNoFolder,viewEntry)
		end
		self.actionState = CpCourseManagerFrame.actionStates.disabled
	elseif self.actionState == CpCourseManagerFrame.actionStates.moveEntrySelect then
		--- Selected a entity to move.
		if viewEntry:hasAccess() then
			self.selectedEntry = viewEntry 
			self.actionState = CpCourseManagerFrame.actionStates.moveEntryDestination
		else 
			CpCourseManagerFrame.showInfoDialog(
				CpCourseManagerFrame.translations.noAccessError,viewEntry)
			self.actionState = CpCourseManagerFrame.actionStates.disabled
		end
	elseif self.actionState == CpCourseManagerFrame.actionStates.moveEntryDestination then
		--- Moves the previous selected entity to a given directory.
		if viewEntry:isDirectory() then 
			self.courseStorage:validate(viewEntry)
			local wasMoved = self.selectedEntry:move(viewEntry)
			if not wasMoved then 
				CpCourseManagerFrame.showInfoDialog(
					CpCourseManagerFrame.translations.entryExistAlreadyError,viewEntry)
			end
		else 
			CpCourseManagerFrame.showInfoDialog(
				CpCourseManagerFrame.translations.targetIsNoFolder,viewEntry)
		end
		self.selectedEntry = nil
		self.actionState = CpCourseManagerFrame.actionStates.disabled
	elseif self.actionState == CpCourseManagerFrame.actionStates.deleteEntry then
		--- Deletes a selected entity.
		if viewEntry:isDeleteAllowed() then 
			CpCourseManagerFrame.showYesNoDialog(
				self,CpCourseManagerFrame.translations.deleteWarning,
					CpCourseManagerFrame.onClickDeleteEntryDialog,viewEntry)
		else 
			CpCourseManagerFrame.showInfoDialog(
			CpCourseManagerFrame.translations.noAccessError,viewEntry)
		end
		self.actionState = CpCourseManagerFrame.actionStates.disabled
	elseif self.actionState == CpCourseManagerFrame.actionStates.renameEntry then 
		--- Renames a selected entity.
		if viewEntry:isRenameAllowed() then
			CpCourseManagerFrame.showInputTextDialog(
						self,CpCourseManagerFrame.translations.renameEntry,
							CpCourseManagerFrame.onClickRenameEntryDialog,viewEntry)
		else 
			CpCourseManagerFrame.showInfoDialog(
				CpCourseManagerFrame.translations.noAccessError,viewEntry)
		end
		self.actionState = CpCourseManagerFrame.actionStates.disabled
	elseif self.actionState == CpCourseManagerFrame.actionStates.copyEntrySelect then 
		--- Selected a entity to copy.
		if viewEntry:hasAccess() then
			self.selectedEntry = viewEntry 
			self.actionState = CpCourseManagerFrame.actionStates.copyEntryDestination
		else
			CpCourseManagerFrame.showInfoDialog(
				CpCourseManagerFrame.translations.noAccessError,viewEntry)
			self.actionState = CpCourseManagerFrame.actionStates.disabled
		end
	elseif self.actionState == CpCourseManagerFrame.actionStates.copyEntryDestination then 
		--- Copies the previous selected entity to a given directory.
		if viewEntry:isDirectory() then 
			local wasCopied = self.selectedEntry:copy(viewEntry)
			if not wasCopied then 
				CpCourseManagerFrame.showInfoDialog(
					CpCourseManagerFrame.translations.entryExistAlreadyError,viewEntry)
			end
		else
			CpCourseManagerFrame.showInfoDialog(
				CpCourseManagerFrame.translations.targetIsNoFolder,viewEntry)
		end
		self.selectedEntry = nil
		self.actionState = CpCourseManagerFrame.actionStates.disabled
	end
	CpCourseManagerFrame.updateLists(self)
	CpUtil.debugFormat(CpUtil.DBG_HUD,"actionState -> %d",self.actionState)
end

function CpCourseManagerFrame:onListSelectionChanged(list, section, index)
	if list == self.leftLayout then 
		self.rightLayout:reloadData()
--		CpUtil.debugFormat(CpUtil.DBG_HUD,"leftLayout -> onListSelectionChanged")
	else
--		CpUtil.debugFormat(CpUtil.DBG_HUD,"rightLayout -> onListSelectionChanged")
	end
	self:updateMenuButtons()
end

--- Updates the button at the bottom, which depends on the current select mode.
function CpCourseManagerFrame:updateMenuButtons()
	local courseName = self.currentVehicle:getCurrentCpCourseName()
	local title = string.format(g_i18n:getText(CpCourseManagerFrame.translations.title),courseName)
	self.pageTitle:setText(title)
	self.menuButtonInfo = {
		{
			inputAction = InputAction.MENU_BACK,
		}
	}
	if self.courseStorage:getCanIterateBackwards() then
		self.menuButtonInfo[1].callback = function () self:onClickIterateBack() end
	end
--	table.insert(self.menuButtonInfo,self.modeButton)
	for i,data in pairs(self.modes[self.curMode]) do 
		if data.callbackDisabled == nil or not data.callbackDisabled(self) then
			table.insert(self.menuButtonInfo,data)
		end
	end	
	self:setMenuButtonInfoDirty()
	local text = self.curMode == CpCourseManagerFrame.minMode and g_i18n:getText(CpCourseManagerFrame.translations.basicSettings)
					or  g_i18n:getText(CpCourseManagerFrame.translations.advancedSettings)
	self.rightToggleBtn:setText(text)
end

---------------------------------------------------
--- Menu button click callbacks
---------------------------------------------------

--- Traverse back a directory.
function CpCourseManagerFrame:onClickIterateBack()
	self.courseStorage:iterateBackwards()
	CpCourseManagerFrame.updateLists(self)
end

--- Changes the current possible actions.
function CpCourseManagerFrame:onClickChangeMode()
	self.curMode = self.curMode + 1
	if self.curMode > CpCourseManagerFrame.maxMode then 
		self.curMode = CpCourseManagerFrame.minMode
	end
	CpUtil.debugFormat(CpUtil.DBG_HUD,"onClickChangeMode")
	self.actionState = CpCourseManagerFrame.actionStates.disabled
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
	CpCourseManagerFrame.updateLists(self)
end

--- Saves the current vehicle courses with a given name.
function CpCourseManagerFrame:onClickSaveEntryDialog(text,clickOk,viewEntry)
	if clickOk then 
		CpUtil.debugFormat(CpUtil.DBG_HUD,"onClickSaveEntryDialog - > %s",text)

		local file,fileCreated = viewEntry:addFile(text)
		if not fileCreated then 
			CpCourseManagerFrame.showInfoDialog(
				CpCourseManagerFrame.translations.entryExistAlreadyError,viewEntry)
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
			CpCourseManagerFrame.showInfoDialog(
				CpCourseManagerFrame.translations.entryExistAlreadyError,viewEntry)
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
			CpCourseManagerFrame.showInfoDialog(
				CpCourseManagerFrame.translations.deleteError,viewEntry)
		end
	end
end

function CpCourseManagerFrame:onClickRenameEntryDialog(text,clickOk,viewEntry)
	if clickOk then 
		CpUtil.debugFormat(CpUtil.DBG_HUD,"onClickRenameEntryDialog - > %s",text)
		self.courseStorage:validate(viewEntry)
		local wasRenamed = viewEntry:rename(text)
		if not wasRenamed then 
			CpCourseManagerFrame.showInfoDialog(
				CpCourseManagerFrame.translations.entryExistAlreadyError,viewEntry)
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
			CpCourseManagerFrame.updateLists(self)
		end,
		target = self,
		defaultText = "",
		dialogPrompt = string.format(g_i18n:getText(title),viewEntry and viewEntry:getName()),
		imePrompt = g_i18n:getText(title),
		confirmText = g_i18n:getText("button_ok"),
		args = viewEntry
	})
end

function CpCourseManagerFrame:showYesNoDialog(title,callbackFunc,viewEntry)
	g_gui:showYesNoDialog({
		text = string.format(g_i18n:getText(title),viewEntry:getName()),
		callback = function (self,clickOk,viewEntry)
			callbackFunc(self,clickOk,viewEntry)
			CpCourseManagerFrame.updateLists(self)
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
	return not self.currentVehicle:hasCpCourse() or self.actionState ~= CpCourseManagerFrame.actionStates.disabled
end

function CpCourseManagerFrame:loadCourseDisabled()
	return self.actionState ~= CpCourseManagerFrame.actionStates.disabled or not self.courseStorage.currentDirectoryView:areEntriesVisible()
end

function CpCourseManagerFrame:saveCourseDisabled()
	return not self.currentVehicle:hasCpCourse() or self.actionState ~= CpCourseManagerFrame.actionStates.disabled or not self.courseStorage.currentDirectoryView:areEntriesVisible()
end

function CpCourseManagerFrame:createDirectoryDisabled()
	return self.actionState ~= CpCourseManagerFrame.actionStates.disabled or not self.courseStorage.currentDirectoryView:areEntriesVisible()
end

function CpCourseManagerFrame:moveEntryDisabled()
	return self.actionState ~= CpCourseManagerFrame.actionStates.disabled or not self.courseStorage.currentDirectoryView:areEntriesVisible()
end

function CpCourseManagerFrame:copyEntryDisabled()
	return self.actionState ~= CpCourseManagerFrame.actionStates.disabled or not self.courseStorage.currentDirectoryView:areEntriesVisible()
end

function CpCourseManagerFrame:deleteEntryDisabled()
	return self.actionState ~= CpCourseManagerFrame.actionStates.disabled or not self.courseStorage.currentDirectoryView:areEntriesVisible()
end

function CpCourseManagerFrame:renameEntryDisabled()
	return self.actionState ~= CpCourseManagerFrame.actionStates.disabled or not self.courseStorage.currentDirectoryView:areEntriesVisible()
end
