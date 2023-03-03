lu = require("luaunit")
package.path = package.path .. ";../?.lua;../ai/parameters/?.lua"
require('InterfaceTest')
require('mock-GiantsEngine')
require('mock-Courseplay')
require('CpObject')
require('CpUtil')
require('AIParameterSettingInterface')
require('AIParameterSettingList')
require('AIParameterBooleanSetting')
require('CpAIParameterPositionAngle')

InterfaceTests.compareToInterface(AIParameterSettingInterface(), AIParameterSettingList)