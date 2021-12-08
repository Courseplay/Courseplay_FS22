CpSettingsUtil = {}

--- Class reference name to Class.
CpSettingsUtil.classTypes = {
	["AIParameterSettingList"] = AIParameterSettingList.new,
	["AIParameterBooleanSetting"] = AIParameterBooleanSetting.new
}

--- All xml values used by the settings setup xml files.
function CpSettingsUtil.init()
    CpSettingsUtil.setupXmlSchema = XMLSchema.new("SettingsSetup")
    local schema = CpSettingsUtil.setupXmlSchema	
	local baseKey = "Settings.SettingSubTitle(?).Setting(?)"
	-- valueTypeId, path, description, defaultValue, isRequired
	schema:register(XMLValueType.STRING, "Settings#prefixText","Settings prefix text",nil,true)
	schema:register(XMLValueType.STRING, "Settings.SettingSubTitle(?)#title", "Setting sub title",nil,true)
	schema:register(XMLValueType.BOOL, "Settings.SettingSubTitle(?)#prefix", "Setting sub title is a prefix",true)
    schema:register(XMLValueType.STRING, baseKey.."#name", "Setting name",nil,true)
    schema:register(XMLValueType.STRING, baseKey.."#classType", "Setting class type",nil,true)
	schema:register(XMLValueType.STRING, baseKey.."#title", "Setting tile")
    schema:register(XMLValueType.STRING, baseKey.."#tooltip", "Setting tooltip")
	schema:register(XMLValueType.INT, baseKey.."#min", "Setting min value")
	schema:register(XMLValueType.INT, baseKey.."#max", "Setting max value")
	schema:register(XMLValueType.FLOAT, baseKey.."#incremental", "Setting incremental",1)

	schema:register(XMLValueType.STRING, baseKey..".Values.Value(?)#name", "Setting value name", nil)
	schema:register(XMLValueType.INT, baseKey..".Values.Value(?)", "Setting value", nil)

	schema:register(XMLValueType.STRING, baseKey..".Texts.Text(?)", "Setting value text", nil)
	schema:register(XMLValueType.BOOL, baseKey..".Texts.Text(?)#prefix", "Setting value text is a prefix", true)
end
CpSettingsUtil.init()

function CpSettingsUtil.getSettingFromParameters(parameters)
    return CpSettingsUtil.classTypes[parameters.classType](parameters)
end

function CpSettingsUtil.loadSettingsFromSetup(class,filePath)
    local xmlFile = XMLFile.load("settingSetupXml", filePath, CpSettingsUtil.setupXmlSchema)
    class.settings = {}
    class.settingsByName = {}
	class.settingsBySubTitle = {}
	class.globalNames = {}
    local uniqueID = 0
	local setupKey = xmlFile:getValue("Settings#prefixText")
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
			settingParameters.min = xmlFile:getValue(baseKey.."#min")
			settingParameters.max = xmlFile:getValue(baseKey.."#max")
			settingParameters.incremental = MathUtil.round(xmlFile:getValue(baseKey.."#incremental"),3)

			settingParameters.values = {}

			xmlFile:iterate(baseKey..".Values.Value", function (i, key)
				local name = xmlFile:getValue(key.."#name")
				local value = xmlFile:getValue(key)
				table.insert(settingParameters.values,value)
				if name ~= nil and name ~= "" then
					class.globalNames[name] = value
				end
			end)
			settingParameters.texts = {}
			xmlFile:iterate(baseKey..".Texts.Text", function (i, key)
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

			local setting = CpSettingsUtil.getSettingFromParameters(settingParameters)
			class.settingsByName[settingParameters.name] = setting
			table.insert(class.settings,setting)
			table.insert(subTitleSettings.elements,setting)

			uniqueID = uniqueID + 1
		end)
		table.insert(class.settingsBySubTitle,subTitleSettings)
	end)
	xmlFile:delete()
end

--- Clones a settings table.
---@param settings table
---@return table clonedSettings
---@return table clonedSettingsByNames
function CpSettingsUtil.cloneSettingsTable(settings)
	local clonedSettings = {}
	local clonedSettingsByNames = {}
	for _,setting in ipairs(settings) do 
		local settingClone = setting:clone()
		table.insert(clonedSettings,settingClone)
		clonedSettingsByNames[settingClone:getName()] = settingClone
	end
	return clonedSettings,clonedSettingsByNames
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
		for _,setting in ipairs(data.elements) do 
			local clonedSettingElement = genericSettingElement:clone(parentGuiElement)
			setting:setGenericGuiElementValues(clonedSettingElement)
		end
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
