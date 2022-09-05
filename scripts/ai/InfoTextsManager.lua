--[[
This file is part of Courseplay (https://github.com/Courseplay/courseplay)
Copyright (C) 2021 courseplay dev team

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

---@class CpInfoTextElement
CpInfoTextElement = CpObject()

CpInfoTextElement.aiMessageNameToClass = {
	AIMessageErrorOutOfFill = AIMessageErrorOutOfFill,
	AIMessageErrorIsFull = AIMessageErrorIsFull,
	AIMessageSuccessFinishedJob = AIMessageSuccessFinishedJob,
	AIMessageErrorOutOfFuel = AIMessageErrorOutOfFuel,
	AIMessageErrorVehicleBroken = AIMessageErrorVehicleBroken,
	AIMessageErrorOutOfMoney = AIMessageErrorOutOfMoney,
	AIMessageErrorBlockedByObject = AIMessageErrorBlockedByObject,
	AIMessageCpError = AIMessageCpError,
	AIMessageErrorWrongBaleWrapType = AIMessageErrorWrongBaleWrapType,
	AIMessageCpErrorNoPathFound = AIMessageCpErrorNoPathFound
}

--- Info text 
---@param name string name called by in the lua code.
---@param text string displayed text
---@param id number unique id for mp
---@param hasFinished boolean is true, when the driver finished.
---@param event string event called when the info text was activated.
---@param aiMessageClass string reference to a giants ai message.
function CpInfoTextElement:init(name, text, id, hasFinished, event, aiMessageClass)
	self.name = name
	self.text = text
	self.id = id
	self.hasFinished = hasFinished
	self.event = event
	if aiMessageClass then 
		self.aiMessageClass = CpInfoTextElement.aiMessageNameToClass[aiMessageClass]
	end
end

function CpInfoTextElement:__tostring()
	return string.format("name: %s, text: %s, hasFinished: %s, event: %s, hasClass: %s",
									 self.name, self.text, tostring(self.hasFinished), tostring(self.event), tostring(self.aiMessageClass))
end

--- Checks if the given message is assigned to this info text.
function CpInfoTextElement:isAssignedToAIMessage(message)
	return self.aiMessageClass and message:isa(self.aiMessageClass)
end

function CpInfoTextElement:getData()
	return self.hasFinished, self.event
end

function CpInfoTextElement:getText()
	return self.text
end

---Loads the possible info texts and combines the active ones from every vehicle here.
---@class InfoTextManager
InfoTextManager = CpObject()

InfoTextManager.xmlKey = "InfoTexts.InfoText"
InfoTextManager.baseXmlKey = "InfoTexts"

function InfoTextManager:init()
	self:registerXmlSchema()
	self.infoTexts = {}
	self.infoTextsById = {}
	self.vehicles = {}
	self:loadFromXml()
end

function InfoTextManager:registerXmlSchema()
    self.xmlSchema = XMLSchema.new("infoTexts")
	self.xmlSchema:register(XMLValueType.STRING, self.baseXmlKey.."#prefix", "Info text prefix.")
    self.xmlSchema:register(XMLValueType.STRING, self.xmlKey.."(?)#name", "Info text name for the lua code.")
	self.xmlSchema:register(XMLValueType.STRING, self.xmlKey.."(?)#text", "Info text displayed.")
	self.xmlSchema:register(XMLValueType.BOOL, self.xmlKey.."(?)#hasFinished", "Is folding of implements allowed?")
	self.xmlSchema:register(XMLValueType.STRING, self.xmlKey.."(?)#event", "Event to call with the message.")
	self.xmlSchema:register(XMLValueType.STRING, self.xmlKey.."(?)#class", "AI message class.")
end

--- Load the info text xml File.
function InfoTextManager:loadFromXml()
    self.xmlFileName = Utils.getFilename('config/InfoTexts.xml', Courseplay.BASE_DIRECTORY)
	
    local xmlFile = XMLFile.loadIfExists("InfoTextsXmlFile", self.xmlFileName, self.xmlSchema)
    if xmlFile then
		local name, text, id, aiMessageClass, event, hasFinished
		local prefix = xmlFile:getValue(self.baseXmlKey.."#prefix", "")
        xmlFile:iterate(self.xmlKey, function (ix, key)
            name = xmlFile:getValue(key .. "#name")
			text = xmlFile:getValue(key .. "#text")
			text = g_i18n:getText(prefix..text)
			id = bitShiftLeft(1, ix-1)

			hasFinished = xmlFile:getValue(key .. "#hasFinished", false)
			event = xmlFile:getValue(key .. "#event")
			aiMessageClass = xmlFile:getValue(key .. "#class")

			InfoTextManager[name] = CpInfoTextElement(name, text, id, 
													  hasFinished, event, aiMessageClass)
			self.infoTextsById[id] = InfoTextManager[name]		
			table.insert(self.infoTexts, InfoTextManager[name])
        end)
        xmlFile:delete()
    end
end

function InfoTextManager:registerVehicle(v, id)
	self.vehicles[id] = v
end


function InfoTextManager:unregisterVehicle(id)
	self.vehicles[id] = nil
end

--- Gets all info texts
function InfoTextManager:getInfoTexts()
	return self.infoTexts
end

--- Gets a info text by it's unique id.
function InfoTextManager:getInfoTextById(id)
	return self.infoTextsById[id]	
end

--- Gets all active info texts, for every vehicle combined.
function InfoTextManager:getActiveInfoTexts()
	local infos = {}
	local i = self.numActiveTexts
	local validInfoText
	for _, infoText in ipairs(self.infoTexts) do 
		for _, vehicle in pairs(self.vehicles) do 
			if g_currentMission.accessHandler:canPlayerAccess(vehicle) then
				--- dev functionally for testing.
				if self.numActiveTexts > 0 then 
					validInfoText = true 
					if i == 0 then 
						break
					end
					i = i - 1 
				else 
					validInfoText = vehicle:getIsCpInfoTextActive(infoText)
				end
			
				if validInfoText then 
					local info = {
						text = infoText.text,
						vehicle = vehicle
					}
					table.insert(infos, info)
				end	
			end
		end
	end
	return infos
end

function InfoTextManager:getInfoTextByAIMessage(message)
	for i, infoText in pairs(self.infoTexts) do 
		if infoText:isAssignedToAIMessage(message)then 
			return infoText
		end
	end
end

--- Gets the info text and the additional data by the ai message.
---@param message AIMessage
---@return CpInfoTextElement Info text
---@return boolean Has the driver finished?
---@return string Event to call with the info text.
function InfoTextManager:getInfoTextDataByAIMessage(message)
	local infoText = self:getInfoTextByAIMessage(message)
	if infoText then 
		local hasFinished, event = infoText:getData()
		return infoText, hasFinished, event
	end
end

--- Dev test function, to simulate the info texts.
InfoTextManager.numActiveTexts = -1
function InfoTextManager:changeNumActiveTexts()
	InfoTextManager.numActiveTexts = InfoTextManager.numActiveTexts + 1
	if InfoTextManager.numActiveTexts > 10 then 
		InfoTextManager.numActiveTexts = -1
	end
end

g_infoTextManager = InfoTextManager()