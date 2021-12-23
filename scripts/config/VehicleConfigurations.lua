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

--- A container for custom vehicle configurations.
---
--- Allows to customize vehicle data XML file(s). A standard configuration is installed with Courseplay,
--- custom user configs can be placed in <your save game folder>/modsSettings/Courseplay/vehicleConfigurations.xml
---
--- Custom configs are read last and override the standard config when exist.
---
--- You can use the cpReadVehicleConfigurations console command to reload these files in-game.
---
---@class VehicleConfigurations : CpObject
VehicleConfigurations = CpObject()
VehicleConfigurations.XML_KEY = "VehicleConfigurations.Vehicle"
VehicleConfigurations.MOD_NAME = g_currentModName

--- All attributes and the data type.
VehicleConfigurations.attributes = {
    toolOffsetX = XMLValueType.FLOAT,
    noReverse = XMLValueType.BOOL,
    turnRadius = XMLValueType.FLOAT,
    workingWidth = XMLValueType.FLOAT,
    balerUnloadDistance = XMLValueType.FLOAT,
    directionNodeOffsetZ = XMLValueType.FLOAT,
    implementWheelAlwaysOnGround = XMLValueType.BOOL,
    ignoreCollisionBoxesWhenFolded = XMLValueType.BOOL,
    baleCollectorOffset = XMLValueType.FLOAT,
}


function VehicleConfigurations:init()
    self.vehicleConfigurations = {}
    if g_currentMission then
        self:loadFromXml()
    end
end

function VehicleConfigurations:registerXmlSchema()
    self.xmlSchema = XMLSchema.new("vehicleConfigurations")
    self.xmlSchema:register(XMLValueType.STRING,self.XML_KEY.."(?)#name","Configuration name")
    
    for name,xmlType in pairs(VehicleConfigurations.attributes) do 
        self.xmlSchema:register(xmlType,self.XML_KEY.."(?)#"..name,"Configuration value")
    end
end

function VehicleConfigurations:loadFromXml()
    self:registerXmlSchema()
    self.xmlFileName = Utils.getFilename('config/VehicleConfigurations.xml', Courseplay.BASE_DIRECTORY)
    self.xmlFile = self:loadXmlFile(self.xmlFileName)
    self.userXmlFileName = getUserProfileAppPath() .. 'modSettings/'..VehicleConfigurations.MOD_NAME..'/vehicleConfigurations.xml'

    self.userXmlFile = self:loadXmlFile(self.userXmlFileName)
end

--- Saves the xml attributes under the vehicle name.
function VehicleConfigurations:addAttribute(vehicleConfiguration, xmlFile, vehicleElement, attributeName)
    local configValue = xmlFile:getValue(vehicleElement.."#"..attributeName) 
    if configValue then
        vehicleConfiguration[attributeName] = configValue
        local valueAsString = ''
        if type(configValue) == 'number' then
            valueAsString = string.format('%.1f', configValue)
        else
            valueAsString = string.format('%s', tostring(configValue))
        end
        CpUtil.info('\\__ %s = %s', attributeName, valueAsString)
    end
end

--- Reads all vehicle attributes from the xml file.
function VehicleConfigurations:readVehicle(xmlFile, vehicleElement)
    local vehicleConfiguration = {}
    local name = xmlFile:getValue(vehicleElement .. "#name")
    CpUtil.info('Reading configuration for %s', name)
    for attributeName, _ in pairs(self.attributes) do
        self:addAttribute(vehicleConfiguration, xmlFile, vehicleElement, attributeName)
    end
    self.vehicleConfigurations[name] = vehicleConfiguration
end

function VehicleConfigurations:loadXmlFile(fileName)
    CpUtil.info('Loading vehicle configuration from %s ...', fileName)
    local xmlFile = XMLFile.loadIfExists("vehicleConfigurationsXmlFile",fileName,self.xmlSchema)
    if xmlFile then 
        xmlFile:iterate(self.XML_KEY, function (ix, key)
            self:readVehicle(xmlFile, key)
        end)
        xmlFile:delete()
    else 
        CpUtil.info('Vehicle configuration file %s does not exist.', fileName)
    end
end

--- Get a custom configuration value for a single vehicle/implement
--- @param object table vehicle or implement object. This function uses the object's configFileName to uniquely
--- identify the vehicle/implement.
--- @param attribute string configuration attribute to get
--- @return any the value of the configuration attribute or nil if there's no custom config for it
function VehicleConfigurations:get(object, attribute)
    if not g_server then
        CpUtil.info("Error: VehicleConfigurations:get() %s",attribute)
        return
    end
    if object and object.configFileName then
        local vehicleXmlFileName = Utils.getFilenameFromPath(object.configFileName)
        if self.vehicleConfigurations[vehicleXmlFileName] then
            return self.vehicleConfigurations[vehicleXmlFileName][attribute]
        else
            return nil
        end
    end
end

--- Get a custom configuration value for an object and its attached implements.
--- First checks the vehicle itself, then all its attached implements until the attribute is found. If the same
--- attribute is defined on multiple implements, only the first is returned
--- @param object table vehicle
--- @param attribute string configuration attribute to get
--- @return any the value of the configuration attribute or nil if there's no custom config for it
function VehicleConfigurations:getRecursively(object, attribute)
    if not g_server then 
        CpUtil.info("Error: VehicleConfigurations:getRecursively() %s",attribute)
        return
    end
    local value = self:get(object, attribute)
    if value then
        return value
    end
    for _, implement in pairs(object:getAttachedImplements()) do
        value = self:getRecursively(implement.object, attribute)
        if value then
            return value
        end
    end
    return nil
end

g_vehicleConfigurations = VehicleConfigurations()
