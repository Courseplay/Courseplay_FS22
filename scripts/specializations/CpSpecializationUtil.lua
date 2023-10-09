--[[
This file is part of Courseplay (https://github.com/Courseplay/Courseplay_FS22)
Copyright (C) 2022 - 2023 Courseplay Dev Team

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

--- WIP!
---@class CpSpecializationUtil
CpSpecializationUtil = CpObject()

function CpSpecializationUtil.init(class, name, neededSpecializations)
	class.MOD_NAME = g_currentModName
	class.NAME = "." .. name
	class.SPEC_NAME = class.MOD_NAME .. class.NAME
	class.KEY = "." .. class.MOD_NAME .. class.NAME
	class.neededSpecializations = neededSpecializations
	class.prerequisitesPresent = function(specializations)
		for _, spec in pairs(class.neededSpecializations) do 
			if SpecializationUtil.hasSpecialization(spec, specializations) then 
				return false
			end
		end
		return true
	end
	class.register = function(typeManager, typeName, specializations)
		if class.prerequisitesPresent(specializations) then
			typeManager:addSpecialization(typeName, class.SPEC_NAME)
		end
	end
end

