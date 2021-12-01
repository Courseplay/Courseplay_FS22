--- Enables adding of Settings containers to the inGame gui.
---@class InGameMenuGeneralSettingsExtendedCP
InGameMenuGeneralSettingsExtendedCP = {}
---@param self InGameMenuGeneralSettingsFrame
function InGameMenuGeneralSettingsExtendedCP.onFrameOpen(self)
	if not self.initCpGuiDone then
		InGameMenuGeneralSettingsExtendedCP.createGlobalSettings(self,g_Courseplay.debugChannels)
		self.initCpGuiDone = true
	end
	CpGuiUtil.applyGuiElementsStatesFromSettingsContainer(g_Courseplay.debugChannels)
end
InGameMenuGeneralSettingsFrame.onFrameOpen = Utils.appendedFunction(InGameMenuGeneralSettingsFrame.onFrameOpen,InGameMenuGeneralSettingsExtendedCP.onFrameOpen)


function InGameMenuGeneralSettingsExtendedCP.getSubTitleElement(layout)
	for i,element in ipairs(layout.elements) do 
		if element.profile == "settingsMenuSubtitle" then 
			return element
		end
	end
end

function InGameMenuGeneralSettingsExtendedCP.getElementToolTip(element)
	for i,element in ipairs(element.elements) do 
		if element.profile == "multiTextOptionSettingsTooltip" then 
			return element
		end
	end
end

--- Creates gui multi text elements for a settings container.
---@param self InGameMenuGeneralSettingsFrame
---@param container SettingsContainer
function InGameMenuGeneralSettingsExtendedCP.createGlobalSettings(self,container)
	local function lambda(self,layout)
		return InGameMenuGeneralSettingsExtendedCP.getSubTitleElement(layout),self.multiInputHelpMode,InGameMenuGeneralSettingsExtendedCP.getElementToolTip
	end
	CpGuiUtil.createGuiElementsFromSettingsContainer(container,lambda,self,self.boxLayout)
end