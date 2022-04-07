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


CpInfoTextElement = CpObject()
function CpInfoTextElement:init(name,text,id)
	self.name = name
	self.text = text
	self.id = id
end

function CpInfoTextElement:__tostring()
	return string.format("name: %s, text: %s",self.name,self.text)
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
	self.xmlSchema:register(XMLValueType.STRING,self.baseXmlKey.."#prefix","Info text prefix.")
    self.xmlSchema:register(XMLValueType.STRING,self.xmlKey.."(?)#name","Info text name for the lua code.")
	self.xmlSchema:register(XMLValueType.STRING,self.xmlKey.."(?)#text","Info text displayed.")
end

--- Load the info text xml File.
function InfoTextManager:loadFromXml()
    self.xmlFileName = Utils.getFilename('config/InfoTexts.xml', Courseplay.BASE_DIRECTORY)
	
    local xmlFile = XMLFile.loadIfExists("InfoTextsXmlFile",self.xmlFileName,self.xmlSchema)
    if xmlFile then
		local name, text, id 
		local prefix = xmlFile:getValue(self.baseXmlKey.."#prefix","")
        xmlFile:iterate(self.xmlKey, function (ix, key)
            name = xmlFile:getValue(key .. "#name")
			text = xmlFile:getValue(key .. "#text")
			text = g_i18n:getText(prefix..text)
			id = bitShiftLeft(1, ix-1)
			InfoTextManager[name] = CpInfoTextElement(name, text, id)
			self.infoTextsById[id] = InfoTextManager[name]
			table.insert(self.infoTexts,InfoTextManager[name])
        end)
        xmlFile:delete()
    end
end

function InfoTextManager:registerVehicle(v,id)
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
	for _,infoText in ipairs(self.infoTexts) do 
		for _,vehicle in pairs(self.vehicles) do 
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
					table.insert(infos,info)
				end	
			end
		end
	end
	return infos
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