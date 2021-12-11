
---@class CpGuiUtil
CpGuiUtil = {}

--- TODO: enable custom page icons.
--- Clones the setting in game menu page.
---@param inGameMenu InGameMenu
---@param class table
---@param title string
---@param predicateFunc function function called on inGameMenu:updatePages() and enables/disables the page.
---@param position number position in the in game menu.
---@return table
function CpGuiUtil.getNewInGameMenuFrame(inGameMenu,class,predicateFunc,position)
	
	local page = inGameMenu.pageSettingsGeneral:clone(inGameMenu.pageSettingsGeneral.parent,true)
	--- Changes the page title.
	CpGuiUtil.changeTextForElementsWithProfileName(page,"ingameMenuFrameHeaderText",title)

	inGameMenu:registerPage(page, nil, predicateFunc)
	inGameMenu:addPageTab(page,g_iconsUIFilename, GuiUtils.getUVs(InGameMenu.TAB_UV.GENERAL_SETTINGS)) -- use the global here because the value changes with resolution settings
	page:applyScreenAlignment()
	page:updateAbsolutePosition()
    page.onGuiSetupFinished = class.onGuiSetupFinished
	page.initialize = class.initialize
	page.onFrameOpen = class.onFrameOpen
	page.onFrameClose = class.onFrameClose
	page:initialize()
	--- Fixes the in game menu layout.
	CpGuiUtil.fixInGameMenuLayout(inGameMenu,page,position)
	return page
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
	return item and item:clone(parent,true)
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