--[[
This file is part of Courseplay (https://github.com/Courseplay/courseplay)
Copyright (C) 2021 Peter Vaiko

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


--- Parameters of a Courseplay job
---@class CpJobParameters
CpJobParameters = CpObject()
CpJobParameters.xmlKey = ".cpJobParameters"


function CpJobParameters:init(job)
    if not CpJobParameters.settings then
        -- initialize the class members first so the class can be used to access constants, etc.
        local filePath = Utils.getFilename("config/JobParameterSetup.xml", g_Courseplay.BASE_DIRECTORY)
        CpSettingsUtil.loadSettingsFromSetup(CpJobParameters, filePath)
    end
    CpSettingsUtil.cloneSettingsTable(self, CpJobParameters.settings, nil, self)
    self.job = job
end

function CpJobParameters.registerXmlSchema(schema, baseKey)
    CpSettingsUtil.registerXmlSchema(schema, baseKey..CpJobParameters.xmlKey.."(?)")
end

function CpJobParameters.getSettings(vehicle)
    return vehicle.spec_cpAIFieldWorker.cpJob:getCpJobParameters()
end

function CpJobParameters:validateSettings()
    for i, setting in ipairs(self.settings) do 
        setting:refresh()
    end
end

function CpJobParameters:writeStream(streamId, connection)
    for i, setting in ipairs(self.settings) do 
        setting:writeStream(streamId, connection)
    end
end

function CpJobParameters:readStream(streamId, connection)
    for i, setting in ipairs(self.settings) do 
        setting:readStream(streamId, connection)
    end
end

function CpJobParameters:saveToXMLFile(xmlFile, baseKey, usedModNames)
    CpSettingsUtil.saveToXmlFile(self.settings, xmlFile, 
        baseKey ..self.xmlKey, self.job:getVehicle(), nil)
end

function CpJobParameters:loadFromXMLFile(xmlFile, baseKey)
    CpSettingsUtil.loadFromXmlFile(self, xmlFile, baseKey .. self.xmlKey, self.job:getVehicle())
end



function CpJobParameters:getMultiTools()
    local vehicle = self.job:getVehicle()
    if vehicle then 
        local course = vehicle:getFieldWorkCourse()
        if course then 
            return course:getMultiTools() or 1
        else 
            return 1
        end
    end
    --- This needs to be 5, as the server otherwise has problems.
    return 5
end

function CpJobParameters:noMultiToolsCourseSelected()
    return self:getMultiTools() <= 1
end

function CpJobParameters:evenNumberOfMultiTools()
    return self:getMultiTools() %2 == 0
end

function CpJobParameters:lessThanThreeMultiTools()
    return self:getMultiTools() < 4
end

--- AI parameters for the bale finder job.
---@class CpBaleFinderJobParameters
CpBaleFinderJobParameters = CpObject(CpJobParameters)


function CpBaleFinderJobParameters:init(job)
    if not CpBaleFinderJobParameters.settings then
        -- initialize the class members first so the class can be used to access constants, etc.
        local filePath = Utils.getFilename("config/BaleFinderJobParameterSetup.xml", g_Courseplay.BASE_DIRECTORY)
        CpSettingsUtil.loadSettingsFromSetup(CpBaleFinderJobParameters, filePath)
    end
    CpSettingsUtil.cloneSettingsTable(self, CpBaleFinderJobParameters.settings, nil, self)
    self.job = job
end

function CpBaleFinderJobParameters.getSettings(vehicle)
    return vehicle.spec_cpAIBaleFinder.cpJob:getCpJobParameters()
end

function CpBaleFinderJobParameters:isBaleWrapSettingVisible()
    local vehicle = self.job:getVehicle()
    if vehicle then 
        return AIUtil.hasChildVehicleWithSpecialization(vehicle, BaleLoader)
    end
end

--- AI parameters for the bale finder job.
---@class CpCombineUnloaderJobParameters
CpCombineUnloaderJobParameters = CpObject(CpJobParameters)


function CpCombineUnloaderJobParameters:init(job)
    self.job = job
    if not CpCombineUnloaderJobParameters.settings then
    local filePath = Utils.getFilename("config/CombineUnloaderJobParameterSetup.xml", g_Courseplay.BASE_DIRECTORY)
        -- initialize the class members first so the class can be used to access constants, etc.
        CpSettingsUtil.loadSettingsFromSetup(CpCombineUnloaderJobParameters, filePath)
    end
    CpSettingsUtil.cloneSettingsTable(self, CpCombineUnloaderJobParameters.settings, nil, self)
end

function CpCombineUnloaderJobParameters.getSettings(vehicle)
    return vehicle.spec_cpAIBaleFinder.cpJob:getCpJobParameters()
end

function CpCombineUnloaderJobParameters:hasPipe()
    local vehicle = self.job:getVehicle()
    if vehicle then
        return AIUtil.hasChildVehicleWithSpecialization(vehicle, Pipe)
    end
end

--- Inserts the current available unloading stations into the setting values/texts.
function CpCombineUnloaderJobParameters:generateUnloadingStations(setting)
    local unloadingStationIds = {}
    local texts = {}
    if self.job then
        for i, unloadingStation in ipairs(self.job:getUnloadingStations()) do 
            local id = NetworkUtil.getObjectId(unloadingStation)
            table.insert(unloadingStationIds, id)
            table.insert(texts,  unloadingStation:getName() or "")
        end
    end
    if #unloadingStationIds <=0 then 
        table.insert(unloadingStationIds, -1)
        table.insert(texts, "")
    end
    return unloadingStationIds, texts
end