-- all the Global Settings

---@class AutoFieldScanSetting : BooleanSetting
AutoFieldScanSetting = CpObject(BooleanSetting)
function AutoFieldScanSetting:init()
	BooleanSetting.init(self, 'autoFieldScan', 'COURSEPLAY_AUTO_FIELD_SCAN',
		'COURSEPLAY_YES_NO_FIELDSCAN', nil)
	-- set default while we are transitioning from the the old setting to this new one
	self:set(true)
end

---@class WorkerWagesSetting : SettingList
WorkerWagesSetting = CpObject(SettingList)
function WorkerWagesSetting:init()
	SettingList.init(self, 'workerWages', 'COURSEPLAY_WORKER_WAGES', 'COURSEPLAY_WORKER_WAGES_TOOLTIP', nil,
			{0,  50, 100, 250, 500, 1000},
			{'0%', '50%', '100%', '250%', '500%', '1000%'}
		)
	self:set(0)
end

---@class AutoRepairSetting : SettingList
AutoRepairSetting = CpObject(SettingList)
AutoRepairSetting.OFF = 0
function AutoRepairSetting:init()
	SettingList.init(self, 'autoRepair', 'COURSEPLAY_AUTOREPAIR', 'COURSEPLAY_AUTOREPAIR_TOOLTIP', nil,
			{AutoRepairSetting.OFF,  25, 70, 99},
			{'COURSEPLAY_AUTOREPAIR_OFF', '< 25%', '< 70%', 'COURSEPLAY_AUTOREPAIR_ALWAYS'}
		)
	self:set(0)
end

function AutoRepairSetting:isAutoRepairActive()
	return self:get() ~= AutoRepairSetting.OFF
end
--[[
function AutoRepairSetting:onUpdateTick(dt, isActive, isActiveForInput, isSelected)
	local rootVehicle = self:getRootVehicle()
	local isOwned = rootVehicle.propertyState ~= Vehicle.PROPERTY_STATE_MISSION
	if courseplay:isAIDriverActive(rootVehicle) and isOwned then 
		if courseplay.globalSettings.autoRepair:isAutoRepairActive() then 
			local repairStatus = (1 - self:getWearTotalAmount())*100
			if repairStatus < courseplay.globalSettings.autoRepair:get() then 
				self:repairVehicle()
			end		
		end
	end
end
Wearable.onUpdateTick = Utils.appendedFunction(Wearable.onUpdateTick, AutoRepairSetting.onUpdateTick)
]]--

---@class ShowMapHotspotSetting : SettingList
ShowMapHotspotSetting = CpObject(SettingList)
ShowMapHotspotSetting.DEACTIVATED = 0
ShowMapHotspotSetting.NAME_ONLY = 1
ShowMapHotspotSetting.NAME_AND_COURSE = 2

function ShowMapHotspotSetting:init()
	SettingList.init(self, 'showMapHotspot', 'COURSEPLAY_INGAMEMAP_ICONS_SHOWTEXT', 'COURSEPLAY_INGAMEMAP_ICONS_SHOWTEXT', nil,
		{ 
			ShowMapHotspotSetting.DEACTIVATED,
			ShowMapHotspotSetting.NAME_ONLY,
			ShowMapHotspotSetting.NAME_AND_COURSE
		},
		{ 	
			'COURSEPLAY_DEACTIVATED',
			'COURSEPLAY_NAME_ONLY',
			'COURSEPLAY_NAME_AND_COURSE'
		}
		)
	self:set(ShowMapHotspotSetting.NAME_ONLY)
end

---If the setting changes force update all mapHotSpot texts
function ShowMapHotspotSetting:onChange()
	self:updateHotSpotTexts()
end

function ShowMapHotspotSetting:updateHotSpotTexts()
--[[
	if CpManager.activeCoursePlayers then
		for _,vehicle in pairs(CpManager.activeCoursePlayers) do
			if vehicle.spec_aiVehicle.mapAIHotspot then
				vehicle.spec_aiVehicle.mapAIHotspot:setText(self:getMapHotspotText(vehicle))
			end
		end
	end
	]]--
end

function ShowMapHotspotSetting:getMapHotspotText(vehicle)
	local text = ''
	if self:is(ShowMapHotspotSetting.NAME_ONLY) then 
	--	text = string.format("%s%s\n",text,nameNum(vehicle, true))
	elseif self:is(ShowMapHotspotSetting.NAME_AND_COURSE) then
	--	text = string.format("%s%s\n%s",text,nameNum(vehicle, true),vehicle.cp.currentCourseName or courseplay:loc('COURSEPLAY_TEMP_COURSE'))
	end
	return text
end


--- This Setting handles all debug channels. 
--- For each debug channel is a code short cut created, 
--- for example: DebugChannelsSetting.DBG_MODE_3.
--- This is defined in the debug config xml file.
---@class DebugChannelsSetting : BooleanSetting 
DebugChannelsSetting = CpObject(BooleanSetting)
function DebugChannelsSetting:init(name,label,toolTip,value)
	BooleanSetting.init(self,name,label,toolTip)
	self:set(value)
end

function SettingsContainer.createGlobalSettings()
	local container = SettingsContainer("globalSettings","CP_globalSettings_header")
--	container:addSetting(AutoFieldScanSetting)
--	container:addSetting(WorkerWagesSetting)
--	container:addSetting(AutoRepairSetting)
--	container:addSetting(ShowMapHotspotSetting)
	return container
end

---@class DebugChannelSettingContainer : SettingsContainer
DebugChannelSettingContainer = CpObject(SettingsContainer)

function DebugChannelSettingContainer.create()
	local container = DebugChannelSettingContainer("debugChannels","CP_debugChannels_header")
	DebugChannelSettingContainer.loadFromXMLFile(container)
	return container	
end

function DebugChannelSettingContainer.loadFromXMLFile(container)

	DebugChannelSettingContainer.xmlSchema = XMLSchema.new("DebugChannels")
	local schema = DebugChannelSettingContainer.xmlSchema
	--- 			valueTypeId, 			path, 				description, defaultValue, isRequired
	schema:register(XMLValueType.STRING, "DebugChannels.DebugChannel(?)#codeIndex", "Debug channel code index")
	schema:register(XMLValueType.STRING, "DebugChannels.DebugChannel(?)#label", "Debug channel name")
	schema:register(XMLValueType.STRING, "DebugChannels.DebugChannel(?)#text", "Debug channel tooltip")
	schema:register(XMLValueType.BOOL, "DebugChannels.DebugChannel(?)#active", "Debug channel active at start",false)

	local xmlFilePath = Utils.getFilename('config/DebugChannels.xml', g_Courseplay.BASE_DIRECTORY)
	local xmlFile = XMLFile.load("debugChannelsXml", xmlFilePath, DebugChannelSettingContainer.xmlSchema)
	container.numChannels = 0
	xmlFile:iterate("DebugChannels.DebugChannel", function (i, key)
		local name = xmlFile:getValue( key.."#codeIndex")
		local text = xmlFile:getValue( key.."#text")
		local label = xmlFile:getValue( key.."#label")
		local active = xmlFile:getValue( key.."#active",false)
		container:addSetting(DebugChannelsSetting,tostring(i),label,text,active)
		container[name] = i
		container.numChannels = container.numChannels+1
	end)
	xmlFile:delete()
end

function DebugChannelSettingContainer:isDebugActive(channelIx)
	return self[channelIx]:get()
end