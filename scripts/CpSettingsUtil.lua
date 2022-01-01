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
		
		- SettingSubTitle(?) :
			- prefix (bool): prefix used yes/no?, default = true
			- title (string): sub title text in the gui menu

			- Setting(?)
				- classType (string): class name
				- name (string): name of the setting 
				- title (string): title text in the gui menu (optional)
				- tooltip (string): tooltip text in the gui menu (optional)
				- default(int) : default value to be set. (optional)
				- defaultBool(bool) : default value to be set. (optional)
				
				- min (int): min value
				- max (int): max value
				- incremental (float): increment (optional), default "1"
				- text(string): string to format the setting value with in the gui element.
				- unit (int) : 1 == km/h, 2 == meters, 3 == ha (optional), 4 = percent (%)

				- onChangeCallback(string): callback function raised on setting value changed. 

				- neededSpecs(string): all specializations separated "," that are needed, default is enabled for every combo.
				- disabledSpecs(string): all specializations separated "," that are disallowed , default is every combo is allowed.

				- Values : 
					- Value(?) :
						- name (string): Global name, should be unique for all settings in this xml file.
						- value (int): value
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
	
	local key = "Settings.SettingSubTitle(?)"
	schema:register(XMLValueType.STRING, key .."#title", "Setting sub title",nil,true)
	schema:register(XMLValueType.BOOL, key .."#prefix", "Setting sub title is a prefix",true)

	key = "Settings.SettingSubTitle(?).Setting(?)"
    schema:register(XMLValueType.STRING, key.."#name", "Setting name",nil,true)
    schema:register(XMLValueType.STRING, key.."#classType", "Setting class type",nil,true)
	schema:register(XMLValueType.STRING, key.."#title", "Setting tile") -- optional
    schema:register(XMLValueType.STRING, key.."#tooltip", "Setting tooltip") -- optional
	schema:register(XMLValueType.INT, key.."#default", "Setting default value") -- optional
	schema:register(XMLValueType.BOOL, key.."#defaultBool", "Setting default bool value") -- optional

	schema:register(XMLValueType.INT, key.."#min", "Setting min value")
	schema:register(XMLValueType.INT, key.."#max", "Setting max value")
	schema:register(XMLValueType.FLOAT, key.."#incremental", "Setting incremental",1) -- optional
	schema:register(XMLValueType.STRING, key.."#text", "Setting text") -- optional
	schema:register(XMLValueType.INT, key .. "#unit", "Setting value unit (km/h,m ...)") --optional

	--- callbacks:
	schema:register(XMLValueType.STRING, key.."#onChangeCallback", "Setting callback on change") -- optional

	schema:register(XMLValueType.STRING, key.."#neededSpecs", "Specializations needed for this setting to be enabled.") -- optional
	schema:register(XMLValueType.STRING, key.."#disabledSpecs", "Specializations that disable this setting.") -- optional

	key = "Settings.SettingSubTitle(?).Setting(?).Values.Value(?)"
	schema:register(XMLValueType.INT, key, "Setting value", nil)
	schema:register(XMLValueType.STRING, key.."#name", "Setting value name", nil)
	
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
		local subTitleSettings = {
			title = subTitle,
			elements = {}
		}
		xmlFile:iterate(masterKey..".Setting", function (i, baseKey)
			local settingParameters = {}
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

			settingParameters.min = xmlFile:getValue(baseKey.."#min")
			settingParameters.max = xmlFile:getValue(baseKey.."#max")
			settingParameters.incremental = MathUtil.round(xmlFile:getValue(baseKey.."#incremental"),3)
			settingParameters.textStr = xmlFile:getValue(baseKey.."#text")
			settingParameters.unit = xmlFile:getValue(baseKey.."#unit")

			settingParameters.callbacks = {}
			settingParameters.callbacks.onChangeCallbackStr = xmlFile:getValue(baseKey.."#onChangeCallback")


			local neededSpecsStr = xmlFile:getValue(baseKey.."#neededSpecs")
			settingParameters.neededSpecs = CpSettingsUtil.getSpecsFromString(neededSpecsStr)

			local disabledSpecs = xmlFile:getValue(baseKey.."#disabledSpecs")
			settingParameters.disabledSpecs = CpSettingsUtil.getSpecsFromString(disabledSpecs)

			settingParameters.values = {}
			xmlFile:iterate(baseKey..".Values.Value", function (i, key)
				local name = xmlFile:getValue(key.."#name")
				local value = xmlFile:getValue(key)
				table.insert(settingParameters.values,value)
				if name ~= nil and name ~= "" then
					class[name] = value
				end
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


--- Gets Specializations form a string, where each is separated by a ",".
---@param str string
---@return table
function CpSettingsUtil.getSpecsFromString(str)
	if str then
		local substrings = str:split(",")
		local results = {}
		if substrings ~= nil then
			for i = 1, #substrings do
				results[i] = g_specializationManager:getSpecializationByName(substrings[i])
			end
		end
		return results
	end
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

--- Clones for each setting and subtitle generic gui elements and applies basic setups.
---@param settingsBySubTitle table
---@param parentGuiElement GuiElement
---@param genericSettingElement GuiElement
---@param genericSubTitleElement GuiElement
function CpSettingsUtil.generateGuiElementsFromSettingsTable(settingsBySubTitle,parentGuiElement,genericSettingElement,genericSubTitleElement)
	local subTitleElement = genericSubTitleElement:clone(genericSubTitleElement.parent,true)
	subTitleElement:unlinkElement()
	FocusManager:removeElement(subTitleElement)
	local settingElement = genericSettingElement:clone(genericSettingElement.parent,true)
	settingElement:unlinkElement()
	FocusManager:removeElement(settingElement)
	for _,data in ipairs(settingsBySubTitle) do 
		local clonedSubTitleElement = subTitleElement:clone(parentGuiElement,true)
		clonedSubTitleElement:setText(data.title)
		for _,setting in ipairs(data.elements) do 
			local clonedSettingElement = settingElement:clone(parentGuiElement,true)
			setting:setGenericGuiElementValues(clonedSettingElement)
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
function CpSettingsUtil.linkGuiElementsAndSettings(settings,layout)
	local i = 1
	for _,element in ipairs(layout.elements) do 
		if element:isa(MultiTextOptionElement) then 
			CpUtil.debugFormat( CpUtil.DBG_HUD, "Link gui element with setting: %s",settings[i]:getName())
			settings[i]:setGuiElement(element)
			i = i + 1
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