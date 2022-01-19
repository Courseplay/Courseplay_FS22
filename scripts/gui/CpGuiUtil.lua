
---@class CpGuiUtil
CpGuiUtil = {}

--- TODO: enable custom page icons.
--- Clones the setting in game menu page.
---@param inGameMenu InGameMenu
---@param parentGui FrameElement
---@param class table
---@param predicateFunc function function called on inGameMenu:updatePages() and enables/disables the page.
---@param position number position in the in game menu.
---@param uvs table
---@return table
function CpGuiUtil.getNewInGameMenuFrame(inGameMenu,parentGui,class,predicateFunc,position,uvs)
	local page = parentGui:clone(parentGui.parent,true)
	FocusManager:removeElement(page)
	CpGuiUtil.replaceFunction(page,"initialize",class.initialize)
	CpGuiUtil.replaceFunction(page,"onGuiSetupFinished",class.onGuiSetupFinished)
	CpGuiUtil.replaceFunction(page,"reset",class.reset)
	CpGuiUtil.replaceFunction(page,"delete",class.delete)
	CpGuiUtil.replaceFunction(page,"onFrameOpen",class.onFrameOpen)
	CpGuiUtil.replaceFunction(page,"onFrameClose",class.onFrameClose)
	CpGuiUtil.replaceFunction(page,"getNumberOfItemsInSection", class.getNumberOfItemsInSection)
	CpGuiUtil.replaceFunction(page,"populateCellForItemInSection",class.populateCellForItemInSection)
	CpGuiUtil.replaceFunction(page,"onListSelectionChanged",class.onListSelectionChanged)
	CpGuiUtil.replaceFunction(page,"onListHighlightChanged",class.onListHighlightChanged)
	CpGuiUtil.replaceFunction(page,"onClearElementSelection",class.onClearElementSelection)
	CpGuiUtil.replaceFunction(page,"updateMenuButtons",class.updateMenuButtons)
	inGameMenu:registerPage(page, nil, predicateFunc)
	local iconFileName = Utils.getFilename('img/ui_courseplay.dds', g_Courseplay.BASE_DIRECTORY)
	inGameMenu:addPageTab(page,iconFileName, GuiUtils.getUVs(uvs)) -- use the global here because the value changes with resolution settings
	page:applyScreenAlignment()
	page:updateAbsolutePosition()
	
	page:initialize()
	--- Fixes the in game menu layout.
	CpGuiUtil.fixInGameMenuLayout(inGameMenu,page,position)
	page:onGuiSetupFinished()
	return page
end

function CpGuiUtil.replaceFunction(class,funcName,replaceFunc)
	if replaceFunc ~=nil then 
		class[funcName] = replaceFunc
	end
end

--- Fixes the in game menu layout.
---@param inGameMenu InGameMenu
---@param page table
---@param position number
function CpGuiUtil.fixInGameMenuLayout(inGameMenu,page,position)
	
	for i = 1, #inGameMenu.pagingElement.elements do
		local child = inGameMenu.pagingElement.elements[i]
		if child == page then
			table.remove(inGameMenu.pagingElement.elements, i)
			table.insert(inGameMenu.pagingElement.elements, position, child)
			break
		end
	end

	for i = 1, #inGameMenu.pagingElement.pages do
		local child = inGameMenu.pagingElement.pages[i]
		if child.element == page then
			table.remove(inGameMenu.pagingElement.pages, i)
			table.insert(inGameMenu.pagingElement.pages, position, child)
			break
		end
	end

	inGameMenu.pagingElement:updateAbsolutePosition()
	inGameMenu.pagingElement:updatePageMapping()
	
    for i = 1, #inGameMenu.pageFrames do
        local child = inGameMenu.pageFrames[i]
        if child == page then
            table.remove(inGameMenu.pageFrames, i)
            table.insert(inGameMenu.pageFrames, position, child)
            break
        end
    end

	inGameMenu:rebuildTabList()
end

--- Clones a child element with a given profile name.
---@param rootElement GuiElement Searches in this element children elements.
---@param profileName string 
---@param parent GuiElement New parent element to link the gui element with.
---@return GuiElement
function CpGuiUtil.cloneElementWithProfileName(rootElement,profileName,parent)
	local item = CpGuiUtil.getFirstElementWithProfileName(rootElement,profileName)
	local clone = item and item:clone(item.parent,true)
	if clone then 
		clone:unlinkElement()
		FocusManager:removeElement(clone)
		return clone:clone(parent,true)
	end	
end

--- Gets all children elements with a given profile name.
---@param rootElement GuiElement Searches in this element children elements.
---@param profileName string 
---@return table
function CpGuiUtil.getElementsWithProfileName(rootElement,profileName)
	local function getElement(element)
		return element.profile and element.profile == profileName
	end
	return rootElement:getDescendants(getElement)
end

--- Gets the first children element with a given profile name.
---@param rootElement GuiElement Searches in this element children elements.
---@param profileName string 
---@return GuiElement
function CpGuiUtil.getFirstElementWithProfileName(rootElement,profileName)
	local items = CpGuiUtil.getElementsWithProfileName(rootElement,profileName)
	return items and items[1]
end

--- Executes a function for all children elements with a given profile name.
---@param rootElement GuiElement Searches in this element children elements.
---@param profileName string 
---@param lambda function
---@return GuiElement
function CpGuiUtil.executeFunctionForElementsWithProfileName(rootElement,profileName,lambda,...)
	local items = CpGuiUtil.getElementsWithProfileName(rootElement,profileName)
	if items then 
		for _,item in ipairs(items) do 
			lambda(item,...)
		end
	end
end

--- Sets a value for all children elements with a given profile name.
---@param rootElement GuiElement Searches in this element children elements.
---@param profileName string 
---@param valueName string
---@return GuiElement
function CpGuiUtil.setValueForElementsWithProfileName(rootElement,profileName,valueName,...)
	local items = CpGuiUtil.getElementsWithProfileName(rootElement,profileName)
	if items then 
		for _,item in ipairs(items) do 
			item[valueName](item,...)
		end
	end
end

--- Executes a function for all children elements.
---@param rootElement GuiElement Searches in this element children elements.
---@param lambda1 function
---@param lambda2 function
---@return GuiElement
function CpGuiUtil.executeFunctionForElements(rootElement,lambda1,lambda2,...)
	local items = rootElement:getDescendants(lambda1)
	if items then 
		for _,item in ipairs(items) do 
			lambda2(item,...)
		end
	end
end

--- Changes the text of children elements with a given profile name.
---@param rootElement GuiElement Searches in this element children elements.
---@param profileName string 
---@param text string
---@return GuiElement
function CpGuiUtil.changeTextForElementsWithProfileName(rootElement,profileName,text)
	CpGuiUtil.executeFunctionForElementsWithProfileName(rootElement,profileName,
														TextElement.setText,text)
end

--- Changes the color of children elements with a given profile name.
---@param rootElement GuiElement Searches in this element children elements.
---@param profileName string 
---@param color table r,g,b,alpha
---@return GuiElement
function CpGuiUtil.changeColorForElementsWithProfileName(rootElement,profileName,color)
	local r,g,b,a = unpack(color)

	CpGuiUtil.executeFunctionForElementsWithProfileName(rootElement,profileName,
													BitmapElement.setImageColor,nil,r,g,b,a)
end

--- Gets the first multi text element for the rootElement.
---@param rootElement GuiElement Searches in this element children elements.
---@return GuiElement
function CpGuiUtil.getGenericSettingElementFromLayout(rootElement)
	return CpGuiUtil.getFirstElementWithProfileName(rootElement,"multiTextOptionSettings")
end

--- Gets the first sub title element for the rootElement.
---@param rootElement GuiElement Searches in this element children elements.
---@return GuiElement
function CpGuiUtil.getGenericSubTitleElementFromLayout(rootElement)
	return CpGuiUtil.getFirstElementWithProfileName(rootElement,"settingsMenuSubtitle")
end

function CpGuiUtil.getNormalizedRgb(r, g, b,alpha)
	return r / 255, g / 255, b / 255, alpha
end
---unit_minutesShort
function CpGuiUtil.getFormatTimeText(seconds)
	local minutes = math.floor(seconds/60)
	seconds = seconds %60
	local hours = math.floor(minutes/60)
	seconds = seconds %60
	minutes = minutes %60
	if hours > 0 then 
		return string.format("%dh/%dm/%ds",hours,minutes,seconds)
	elseif minutes>0 then 
		return string.format("%dm/%ds",minutes,seconds)
	else 
		return string.format("%ds",seconds)
	end
end

function CpGuiUtil.debugFocus(element,direction)
	local targetElement = FocusManager.getNestedFocusTarget(element, direction)
	CpUtil.debugFormat(CpDebug.DBG_HUD,"isFocusLocked: %s, canReceiveFocus: %s, targetName: %s, focusElement: %s",
										tostring(FocusManager.isFocusLocked),
										tostring(element:canReceiveFocus()),
										FocusManager.getNestedFocusTarget(element, direction).targetName,
										FocusManager.currentFocusData.focusElement and FocusManager.currentFocusData.focusElement == targetElement and FocusManager.currentFocusData.focusElement.focusActive
										)	
end
function CpGuiUtil.setTarget(element,target)
	for i = 1, #element.elements do
		CpGuiUtil.setTarget(element.elements[i],target)
	end

	element.target = target
	element.targetName = target.name
end

--- Enable/disable camera rotation when a vehicle is selected. We want to disable camera rotation per mouse
--- when we enable the mouse cursor so it can be used click controls on a GUI
---@param vehicle table
---@param enableRotation boolean
---@param savedRotatableInfo boolean[] the caller may want to pass in a variable to save the original isRotatable
--- setting of the camera so it will only enabled again when it was originally enabled
function CpGuiUtil.setCameraRotation(vehicle, enableRotation, savedRotatableInfo)
	if not savedRotatableInfo then
		savedRotatableInfo = {}
	end
	for i, camera in pairs(vehicle.spec_enterable.cameras) do
		local isRotatable
		if enableRotation then
			-- restore original setting if exists
			isRotatable = savedRotatableInfo[camera] or true
			CpUtil.debugVehicle(CpDebug.DBG_HUD, vehicle, '    camera %d restore isRotatable %s', i, isRotatable)
		else
			-- save original rotatable setting
			CpUtil.debugVehicle(CpDebug.DBG_HUD, vehicle, '    camera %d disable rotation, current %s', i, camera.isRotatable)
			savedRotatableInfo[camera] = camera.isRotatable
			camera.isRotatable = false
		end
		camera.isRotatable = isRotatable
	end
end

local function fixFocus(self)
	FocusManager:loadElementFromCustomValues(self.boxLayout)
	self.boxLayout:invalidateLayout()
	self:setSoundSuppressed(true)
	FocusManager:setFocus(self.boxLayout)
	self:setSoundSuppressed(false)
end
InGameMenuGeneralSettingsFrame.onFrameOpen = Utils.appendedFunction(InGameMenuGeneralSettingsFrame.onFrameOpen,fixFocus)
