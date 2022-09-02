--- Small gui window to display workWidth, tool offset.

CpGamePadHudScreen = {
	CONTROLS = {
		BUTTON_BACK = "backButton",
		BUTTON_START = "startButton",
		BUTTON_RECORD= "recordButton",
		BUTTON_CLEAR = "clearButton",
		BUTTON_LAYOUT = "bottomButtons",
		SETTING_TEMPLATE = "settingTemplate",
		SETTING_TITLE = "settingTitle",
		SETTING = "settingElement",
		LAYOUT = "layout"
	},
}
CpGamePadHudScreen.texts = {
	startRecording = g_i18n:getText("CP_controllerGui_startRecording"),
	stopRecording = g_i18n:getText("CP_controllerGui_stopRecording")
}

local CpGamePadHudScreen_mt = Class(CpGamePadHudScreen, ScreenElement)

function CpGamePadHudScreen.new(settings, target, custom_mt)
	local self = ScreenElement.new(target, custom_mt or CpGamePadHudScreen_mt)
	self:registerControls(CpGamePadHudScreen.CONTROLS)
	self.settings = settings
	return self
end

function CpGamePadHudScreen:onGuiSetupFinished()
	self.settingTemplate:unlinkElement()
	FocusManager:removeElement(self.settingTemplate)

	CpSettingsUtil.generateGuiElementsFromSettingsTableAlternating(self.settings, self.layout,
	self.settingTitle, self.settingElement)


	self.startButton:unlinkElement()
	FocusManager:removeElement(self.startButton)
	self.layout:addElement(self.startButton)

	self.recordButton:unlinkElement()
	FocusManager:removeElement(self.recordButton)
	self.layout:addElement(self.recordButton)

	self.clearButton:unlinkElement()
	FocusManager:removeElement(self.clearButton)
	self.clearButton:setText(g_i18n:getText("CP_courseManager_clear_current_courses"))
	self.layout:addElement(self.clearButton)

	self.backButton:unlinkElement()
	FocusManager:removeElement(self.backButton)
	self.layout:addElement(self.backButton)


	self.layout:invalidateLayout()

	CpGamePadHudScreen:superClass().onGuiSetupFinished(self)
end

--- Links gui elements with the settings.
function CpGamePadHudScreen:setData(vehicle,settings) 
	self.vehicle = vehicle
	self.settings = settings
	CpSettingsUtil.linkGuiElementsAndSettings(settings,self.layout)
end

function CpGamePadHudScreen:onOpen(element)
	CpGamePadHudScreen:superClass().onOpen(self)
	FocusManager:loadElementFromCustomValues(self.layout)
	self.layout:invalidateLayout()
	self:setSoundSuppressed(true)
	FocusManager:setFocus(self.layout)
	self:setSoundSuppressed(false)

	local text = self.vehicle.spec_aiJobVehicle.texts.hireEmployee
	if self.vehicle:getIsAIActive() then 
		text = self.vehicle.spec_aiJobVehicle.texts.dismissEmployee
	end
	self.startButton:setText(text)
	local _, eventId = g_inputBinding:registerActionEvent(InputAction.CP_OPEN_CLOSE_VEHICLE_SETTING_DISPLAY, self, self.onClickBack, false, true, false, true)
end

function CpGamePadHudScreen:onClose(element)
	CpGamePadHudScreen:superClass().onClose(self)
	if self.settings then
		CpSettingsUtil.unlinkGuiElementsAndSettings(self.settings,self.layout)
	end
	g_inputBinding:removeActionEventsByTarget(self)
	self.vehicle:closeCpGamePadHud()
end

function CpGamePadHudScreen:onClickBack()
	g_gui:showGui("")
end

function CpGamePadHudScreen:onClickOk()
	if self.vehicle then
		self.vehicle:cpStartStopDriver()

		local text = self.vehicle.spec_aiJobVehicle.texts.hireEmployee
		if self.vehicle:getIsAIActive() then 
			text = self.vehicle.spec_aiJobVehicle.texts.dismissEmployee
		end

		self.startButton:setText(text)
	end
end

function CpGamePadHudScreen:update(dt, ...)
	CpGamePadHudScreen:superClass().update(self,dt, ...)
	if not self.vehicle then
		return
	end
	if self.vehicle:getIsCpCourseRecorderActive() then 
		self.recordButton:setVisible(true)
		self.recordButton:setText(self.texts.stopRecording)
	elseif self.vehicle:getCanStartCpCourseRecorder() then 
		self.recordButton:setVisible(true)
		self.recordButton:setText(self.texts.startRecording)
	else 
		self.recordButton:setVisible(false)
	end
	self.startButton:setVisible(self.vehicle:getCanStartCp() or self.vehicle:getIsCpActive())
	self.clearButton:setVisible(self.vehicle:hasCpCourse() and not self.vehicle:getIsCpActive())

	g_currentMission.hud:updateBlinkingWarning(dt)
end

function CpGamePadHudScreen:onClickRecord()
	if not self.vehicle then
		return
	end
	if self.vehicle:getIsCpCourseRecorderActive() then 
		self.vehicle:cpStopCourseRecorder()
	elseif self.vehicle:getCanStartCpCourseRecorder() then 
		self.vehicle:cpStartCourseRecorder()
	end
end

function CpGamePadHudScreen:onClickClearCourse()
	if not self.vehicle then
		return
	end
	if self.vehicle:hasCpCourse() and not self.vehicle:getIsCpActive() then 
		self.vehicle:resetCpCoursesFromGui()
	end
end

function CpGamePadHudScreen:draw(...)
	CpGamePadHudScreen:superClass().draw(self,...)
	CpGamePadHud.onDraw(self.vehicle)	
	g_currentMission.hud:drawBlinkingWarning()
end

CpGamePadHudBaleLoaderScreen = {}
local CpGamePadHudBaleLoaderScreen_mt = Class(CpGamePadHudBaleLoaderScreen, CpGamePadHudScreen)

function CpGamePadHudBaleLoaderScreen.new(settings, target, custom_mt)
	local self = CpGamePadHudScreen.new(settings, target, custom_mt or CpGamePadHudBaleLoaderScreen_mt)

	return self
end

CpGamePadHudUnloaderScreen = {}
local CpGamePadHudUnloaderScreen_mt = Class(CpGamePadHudUnloaderScreen, CpGamePadHudScreen)

function CpGamePadHudUnloaderScreen.new(settings, target, custom_mt)
	local self = CpGamePadHudScreen.new(settings, target, custom_mt or CpGamePadHudUnloaderScreen_mt)

	return self
end