CpSettingsUtil = {}

--- Class reference name to Class.
CpSettingsUtil.classTypes = {
	["AIParameterSettingList"] = AIParameterSettingList.new,
	["AIParameterBooleanSetting"] = AIParameterBooleanSetting.new,
	["AIParameterSpeedSetting"] = AIParameterSpeedSetting.new,
}

--[[
	All the settings configurations.
	They are divided by sub titles in the gui.
	
	All basic AIParameterSettingList can be initialized with values/texts or as an number sequence: [min:incremental:max]

	Callbacks are passed as an string to to the class:raiseCallback() function.
	If the class is a Specializations for example VehicleSettings, 
	then the callback will be called as an event and must be registered by another specialization. 

	Settings :
		- prefixText (string):  pre fix text used for translations
		- autoUpdateGui (bool): automatically updates the gui, optional

		- SettingSubTitle(?) :
			- prefix (bool): prefix used yes/no?, default = true
			- title (string): sub title text in the gui menu

			- isDisabled (string): function called from the parent container, to disable all setting under the subtitle.
			- isVisible (string): function called from the parent container, to change the visibility of all setting under the subtitle.

			- Setting(?)
				- classType (string): class name
				- name (string): name of the setting 
				- title (string): title text in the gui menu (optional)
				- tooltip (string): tooltip text in the gui menu (optional)
				- default(int) : default value to be set. (optional)
				- defaultBool(bool) : default value to be set. (optional)
				- textInput(bool) : is text input allowed ? (optional), every automatic generated number sequence is automatically allowed.
				- isUserSetting(bool): should the setting be saved in the game settings and not in the savegame dir.

				- min (int): min value
				- max (int): max value
				- incremental (float): increment (optional), default "1"
				- text(string): string to format the setting value with in the gui element.
				- unit (int) : 1 == km/h, 2 == meters, 3 == ha (optional), 4 = percent (%), 5 = degrees (°)

				- vehicleConfiguration(string): vehicle configuration, that will be used for reset to default for example.
				- onChangeCallback(string): callback function raised on setting value changed. 

				- isDisabled (string): function called by the setting from the parent container, to disable the setting.
				- isVisible (string): function called by the setting from the parent container, to change the setting visibility.
				- setDefault (string): function called by the setting from the parent container, to set a default value, for example work width.

				- Values : 
					- Value(?) :
						- name (string): Global name, should be unique for all settings in this xml file.
						- value (int): value
						- isDisabled(string): function called by the setting from the parent container, to disable this value.
				- Texts : 
					- Text(?) :
						- prefix (string): prefix used yes/no?, default = true
						- value (string): translation text		
]]--
--- All xml values used by the settings setup xml files.
function CpSettingsUtil.init()
    CpSettingsUtil.setupXmlSchema = XMLSchema.new("SettingsSetup")
    local schema = CpSettingsUtil.setupXmlSchema	
	-- valueTypeId, path, description, defaultValue, isRequired
	schema:register(XMLValueType.STRING, "Settings#title","Settings prefix text",nil,true)
	schema:register(XMLValueType.STRING, "Settings#prefixText","Settings prefix text",nil,true)
	schema:register(XMLValueType.STRING, "Settings#autoUpdateGui","Gui gets updated automatically")

	local key = "Settings.SettingSubTitle(?)"
	schema:register(XMLValueType.STRING, key .."#title", "Setting sub title",nil,true)
	schema:register(XMLValueType.BOOL, key .."#prefix", "Setting sub title is a prefix",true)
	
	schema:register(XMLValueType.STRING, key.."#isDisabled", "Callback function, if the settings is disabled.") -- optional
	schema:register(XMLValueType.STRING, key.."#isVisible", "Callback function, if the settings is visible.") -- optional

	key = "Settings.SettingSubTitle(?).Setting(?)"
    schema:register(XMLValueType.STRING, key.."#name", "Setting name",nil,true)
    schema:register(XMLValueType.STRING, key.."#classType", "Setting class type",nil,true)
	schema:register(XMLValueType.STRING, key.."#title", "Setting tile") -- optional
    schema:register(XMLValueType.STRING, key.."#tooltip", "Setting tooltip") -- optional
	schema:register(XMLValueType.INT, key.."#default", "Setting default value") -- optional
	schema:register(XMLValueType.BOOL, key.."#defaultBool", "Setting default bool value") -- optional
	schema:register(XMLValueType.BOOL, key .. "#textInput", "Setting input text allowed.") --optional
	schema:register(XMLValueType.BOOL, key .. "#isUserSetting", "Setting will be saved in the gameSettings file.") --optional

	schema:register(XMLValueType.INT, key.."#min", "Setting min value")
	schema:register(XMLValueType.INT, key.."#max", "Setting max value")
	schema:register(XMLValueType.FLOAT, key.."#incremental", "Setting incremental",1) -- optional
	schema:register(XMLValueType.STRING, key.."#text", "Setting text") -- optional
	schema:register(XMLValueType.INT, key .. "#unit", "Setting value unit (km/h,m ...)") --optional

	schema:register(XMLValueType.STRING, key.."#vehicleConfiguration", "vehicleConfiguration that will be used to reset the setting.") --optional
	--- callbacks:
	schema:register(XMLValueType.STRING, key.."#onChangeCallback", "Setting callback on change") -- optional

	schema:register(XMLValueType.STRING, key.."#isDisabled", "Callback function, if the settings is disabled.") -- optional
	schema:register(XMLValueType.STRING, key.."#isVisible", "Callback function, if the settings is visible.") -- optional
	schema:register(XMLValueType.STRING, key.."#setDefault", "Callback function, to set the default value.") -- optional

	key = "Settings.SettingSubTitle(?).Setting(?).Values.Value(?)"
	schema:register(XMLValueType.INT, key, "Setting value", nil)
	schema:register(XMLValueType.STRING, key.."#name", "Setting value name", nil)
	schema:register(XMLValueType.STRING, key.."#isDisabled", "Setting value disabled", nil)

	key = "Settings.SettingSubTitle(?).Setting(?).Texts.Text(?)"
	schema:register(XMLValueType.STRING, key, "Setting value text", nil)
	schema:register(XMLValueType.BOOL, key.."#prefix", "Setting value text is a prefix", true)
end
CpSettingsUtil.init()

function CpSettingsUtil.getSettingFromParameters(parameters,...)
    return CpSettingsUtil.classTypes[parameters.classType](parameters,...)
end

function CpSettingsUtil.loadSettingsFromSetup(class, filePath)
    local xmlFile = XMLFile.load("settingSetupXml", filePath, CpSettingsUtil.setupXmlSchema)
    class.settings = {}
	class.settingsBySubTitle = {}
    local uniqueID = 0
	local autoUpdateGui = xmlFile:getValue("Settings#autoUpdateGui")
	local setupKey = xmlFile:getValue("Settings#prefixText")
	local pageTitle = xmlFile:getValue("Settings#title")
	if pageTitle then
		class.pageTitle =  g_i18n:getText(xmlFile:getValue("Settings#title"))
	else 
		class.pageTitle = g_i18n:getText(setupKey .. "title")
	end
	xmlFile:iterate("Settings.SettingSubTitle", function (i, masterKey)
		local subTitle = xmlFile:getValue(masterKey.."#title")
		--- This flag can by used to simplify the translation text. 
		local pre = xmlFile:getValue(masterKey.."#prefix",true)	
		if pre then 
			subTitle = g_i18n:getText(setupKey.."subTitle_"..subTitle)
		else 
			subTitle = g_i18n:getText(subTitle)
		end

		local isDisabledFunc = xmlFile:getValue(masterKey.."#isDisabled")
		local isVisibleFunc = xmlFile:getValue(masterKey.."#isVisible")

		local subTitleSettings = {
			title = subTitle,
			elements = {},
			isDisabledFunc = isDisabledFunc,
			isVisibleFunc = isVisibleFunc,
			class = class
		}
		xmlFile:iterate(masterKey..".Setting", function (i, baseKey)
			local settingParameters = {}
			settingParameters.autoUpdateGui = autoUpdateGui
			settingParameters.classType = xmlFile:getValue(baseKey.."#classType")
			settingParameters.name = xmlFile:getValue(baseKey.."#name")
			local title = xmlFile:getValue(baseKey.."#title")
			if title then
				settingParameters.title = g_i18n:getText(title)
			else 
				settingParameters.title = g_i18n:getText(setupKey..settingParameters.name.."_title")
			end
			local tooltip = xmlFile:getValue(baseKey.."#tooltip")
			if tooltip then
				settingParameters.tooltip = g_i18n:getText(tooltip)
			else 
				settingParameters.tooltip = g_i18n:getText(setupKey..settingParameters.name.."_tooltip")
			end
			settingParameters.default = xmlFile:getValue(baseKey.."#default")
			settingParameters.defaultBool = xmlFile:getValue(baseKey.."#defaultBool")
			settingParameters.textInputAllowed = xmlFile:getValue(baseKey.."#textInput",false)
			settingParameters.isUserSetting = xmlFile:getValue(baseKey.."#isUserSetting",false)

			settingParameters.min = xmlFile:getValue(baseKey.."#min")
			settingParameters.max = xmlFile:getValue(baseKey.."#max")
			settingParameters.incremental = MathUtil.round(xmlFile:getValue(baseKey.."#incremental"),3)
			settingParameters.textStr = xmlFile:getValue(baseKey.."#text")
			settingParameters.unit = xmlFile:getValue(baseKey.."#unit")

			settingParameters.vehicleConfiguration = xmlFile:getValue(baseKey.."#vehicleConfiguration")

			settingParameters.callbacks = {}
			settingParameters.callbacks.onChangeCallbackStr = xmlFile:getValue(baseKey.."#onChangeCallback")

			settingParameters.isDisabledFunc = xmlFile:getValue(baseKey.."#isDisabled")
			settingParameters.isVisibleFunc = xmlFile:getValue(baseKey.."#isVisible")
			settingParameters.setDefaultFunc = xmlFile:getValue(baseKey.."#setDefault")

			settingParameters.values = {}
			settingParameters.disabledValuesFuncs = {}
			xmlFile:iterate(baseKey..".Values.Value", function (i, key)
				local name = xmlFile:getValue(key.."#name")
				local value = xmlFile:getValue(key)
				table.insert(settingParameters.values,value)
				if name ~= nil and name ~= "" then
					class[name] = value
				end
				local isDisabled = xmlFile:getValue(key.."#isDisabled")
				settingParameters.disabledValuesFuncs[value] = isDisabled
			end)

			settingParameters.texts = {}
			xmlFile:iterate(baseKey..".Texts.Text", function (i, key)
				--- This flag can by used to simplify the translation text. 
				local prefix = xmlFile:getValue(key.."#prefix",true)
				local text = xmlFile:getValue(key)
				if prefix then
					text = g_i18n:getText(setupKey..settingParameters.name.."_"..text)
					table.insert(settingParameters.texts,text)
				else 
					table.insert(settingParameters.texts, g_i18n:getText(text))
				end
			end)

			settingParameters.uniqueID = uniqueID

			local setting = CpSettingsUtil.getSettingFromParameters(settingParameters,nil,class)
			class[settingParameters.name] = setting
			table.insert(class.settings,setting)
			table.insert(subTitleSettings.elements,setting)

			uniqueID = uniqueID + 1
		end)
		table.insert(class.settingsBySubTitle,subTitleSettings)
	end)
	xmlFile:delete()
end

--- Clones a settings table.
---@param class table 
---@param settings table
function CpSettingsUtil.cloneSettingsTable(class,settings,...)
	class.settings = {}
	for _,setting in ipairs(settings) do 
		local settingClone = setting:clone(...)
		table.insert(class.settings,settingClone)
		class[settingClone:getName()] = settingClone
	end
end

--- Copies settings values from a settings tables to another.
function CpSettingsUtil.copySettingsValues(settingsTable,settingsTableToCopy)
    for i,p in ipairs(settingsTable.settings) do 
        p:copy(settingsTableToCopy.settings[i])
    end
end

--- Clones for each setting and subtitle generic gui elements and applies basic setups.
---@param settingsBySubTitle table
---@param parentGuiElement GuiElement
---@param genericSettingElement GuiElement
---@param genericSubTitleElement GuiElement
function CpSettingsUtil.generateGuiElementsFromSettingsTable(settingsBySubTitle,parentGuiElement,genericSettingElement,genericSubTitleElement)
	for _,data in ipairs(settingsBySubTitle) do 
		local clonedSubTitleElement = genericSubTitleElement:clone(parentGuiElement)
		clonedSubTitleElement:setText(data.title)
		FocusManager:loadElementFromCustomValues(clonedSubTitleElement)
		for _,setting in ipairs(data.elements) do 
			local clonedSettingElement = genericSettingElement:clone(parentGuiElement)
			setting:setGenericGuiElementValues(clonedSettingElement)
			FocusManager:loadElementFromCustomValues(clonedSettingElement)
		end
	end
	parentGuiElement:invalidateLayout()
end

--- Clones for each setting gui elements and applies basic setups.
---@param settings table
---@param parentGuiElement GuiElement
---@param genericSettingElement GuiElement
function CpSettingsUtil.generateGuiElementsFromSettingsTableAlternating(settings,parentGuiElement,genericSettingElementTitle,genericSettingElement)
	for _,setting in ipairs(settings) do 

		local titleElement = genericSettingElementTitle:clone(parentGuiElement,true)
		titleElement:setText(setting.data.title)
		genericSettingElement:unlinkElement()
		CpUtil.debugFormat(CpDebug.DBG_HUD,"Bound setting %s",setting:getName())
		local clonedSettingElement = genericSettingElement:clone(parentGuiElement,true)
--			parentGuiElement:invalidateLayout()
		setting:setGenericGuiElementValues(clonedSettingElement)
	end
end


--- Links the gui elements to the correct settings.
---@param settings any
---@param layout any
function CpSettingsUtil.linkGuiElementsAndSettings(settings,layout,settingsBySubTitle,vehicle)
	local valid = true
	local i = 1
	local j = 1
	for _,element in ipairs(layout.elements) do 
		if element:isa(MultiTextOptionElement) then 
			if valid then
				CpUtil.debugFormat( CpUtil.DBG_HUD, "Link gui element with setting: %s",settings[i]:getName())
				settings[i]:setGuiElement(element)
			else 
				element:setVisible(false)
			end
			i = i + 1
		elseif settingsBySubTitle then  
			valid = true
			local isDisabledFunc = settingsBySubTitle[j].isDisabledFunc
			local isVisibleFunc = settingsBySubTitle[j].isVisibleFunc
			local class = settingsBySubTitle[j].class
			if vehicle then 
				if class[isVisibleFunc] then 
					valid = class[isVisibleFunc](vehicle)
				end
				if class[isDisabledFunc] then 
					element:setDisabled(class[isDisabledFunc](vehicle))
				end
			else 
				if class[isVisibleFunc] then 
					valid = class[isVisibleFunc](class)
				end
				if class[isDisabledFunc] then 
					element:setDisabled(class[isDisabledFunc](vehicle))
				end
			end
			element:setVisible(valid)
			j =  j + 1
		end
	end
end

--- Unlinks the gui elements to the correct settings.
---@param settings any
---@param layout any
function CpSettingsUtil.unlinkGuiElementsAndSettings(settings,layout)
	local i = 1
	for _,element in ipairs(layout.elements) do 
		if element:isa(MultiTextOptionElement) then 
			CpUtil.debugFormat( CpUtil.DBG_HUD, "Unlink gui element with setting: %s",settings[i]:getName())
			settings[i]:resetGuiElement()
			i = i + 1
		end
	end
end

--- Generates Gui button in the ai job menu from settings.
---@param settingsBySubTitle table
---@param class table
function CpSettingsUtil.generateAiJobGuiElementsFromSettingsTable(settingsBySubTitle,class,settings)
	for _,data in ipairs(settingsBySubTitle) do 
		local parameterGroup = AIParameterGroup.new(data.title)
		for _,setting in ipairs(data.elements) do 
			local s = settings[setting:getName()]
			parameterGroup:addParameter(s)
		end
		table.insert(class.groupedParameters, parameterGroup)
	end
end

function CpSettingsUtil.updateAiParameters(currentJobElements)
	for i,element in pairs(currentJobElements) do 
		if element.setDataSource then
			element:setDataSource(element.aiParameter)
			element:setDisabled(element.aiParameter:getIsDisabled())
		end
	end
end


--- Raises an event for all settings.
---@param settings table
---@param eventName string
function CpSettingsUtil.raiseEventForSettings(settings,eventName,...)
	for _,setting in ipairs(settings) do 
		if setting[eventName] then 
			setting[eventName](setting,...)
		end
	end
end