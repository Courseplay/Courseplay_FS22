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

local filePath = Utils.getFilename("config/JobParameterSetup.xml", g_Courseplay.BASE_DIRECTORY)

function CpJobParameters:init()
    if not CpJobParameters.settings then
        -- initialize the class members first so the class can be used to access constants, etc.
        CpSettingsUtil.loadSettingsFromSetup(CpJobParameters, filePath)
    end
    CpSettingsUtil.loadSettingsFromSetup(self, filePath)
end