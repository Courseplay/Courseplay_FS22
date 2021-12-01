---@class CpGuiUtil
CpGuiUtil = {}

---@param settingList SettingList
function CpGuiUtil.bindSetting(settingList, guiElement, infoText)
	---@type SettingList
	local setting = settingList[guiElement.name] or settingList[guiElement.id]
	if setting and setting.getGuiElement then
		setting:setGuiElement(guiElement)
		guiElement.labelElement.text = setting:getLabel()
		guiElement.toolTipText = setting:getToolTip()
		guiElement:setTexts(setting:getGuiElementTexts())
		guiElement:setState(setting:getGuiElementState())
		guiElement:setDisabled(setting:isDisabled())
	else
		CpUtil.info(infoText or 'bindSetting' .. ': can\'t find setting %s', guiElement.name)
	end
end 

--- Creates gui elements for settings of a settings container. For now only settings list types are allowed.
---@param container SettingsContainer
---@param lambda function
---@param ... table
function CpGuiUtil.createGuiElementsFromSettingsContainer(container,lambda,...)
	local titleElement,subElement,getToolTipFunc = lambda(...)
	local clonedTitleElement = titleElement:clone(titleElement.parent)
	clonedTitleElement:setText(container:getHeaderText())

	local function createSettingElements(setting,element,getToolTipFunc)
		local clonedElement = element:clone(element.parent)
		clonedElement.leftButtonElement.target = setting
		clonedElement.leftButtonElement:setCallback("onClickCallback", "setPrevious")
		clonedElement.rightButtonElement.target = setting
		clonedElement.rightButtonElement:setCallback("onClickCallback", "setNext")
		setting:setGuiElement(clonedElement)
		clonedElement:setLabel(setting:getLabel())
		local toolTipElement = getToolTipFunc(clonedElement)
		toolTipElement:setText(setting:getToolTip())
		element.parent:invalidateLayout()
	end
	container:iterate(createSettingElements,subElement,getToolTipFunc)
end

function CpGuiUtil.applyGuiElementsStatesFromSettingsContainer(container)
	container:iterate(SettingList.updateGuiElement)
end
