
--- Saves/loads the assigned courses for each vehicle in a separate xml file.
---@class AssignedCoursesManager
AssignedCoursesManager = CpObject()
AssignedCoursesManager.rootXmlKey = "AssignedCourses"
AssignedCoursesManager.baseXmlKey = AssignedCoursesManager.rootXmlKey..".Vehicle"
AssignedCoursesManager.xmlKey = AssignedCoursesManager.baseXmlKey.."(?).Course(?)"
AssignedCoursesManager.fileName = "CpAssignedCourses.xml"
function AssignedCoursesManager:init()
	self.vehicles = {}
	self.numVehiclesWithCourses = 0	
end

function AssignedCoursesManager:registerXmlSchema()
	g_messageCenter:subscribe(MessageType.LOADED_ALL_SAVEGAME_VEHICLES, self.finishedLoading, self)
	self.xmlSchema = XMLSchema.new("AssignedCourses")
	CpCourseManager.registerXmlSchemaValues(self.xmlSchema, self.xmlKey)
	self.xmlSchema:register(XMLValueType.STRING, self.baseXmlKey.."(?)" .. "#name", "Vehicle name")
end

--- Every valid vehicle will be added here, the id is needed to delete a sold vehicle form the table.
function AssignedCoursesManager:registerVehicle(vehicle,id)
	self.vehicles[id] = vehicle
end

--- Removes a sold vehicle from the table.
function AssignedCoursesManager:unregisterVehicle(vehicle,id)
	self.vehicles[id] = nil
end

function AssignedCoursesManager:getRegisteredVehicles()
	return self.vehicles
end

--- Gets all vehicles with a course, sorted by the distance to a reference vehicle.
--- Also excludes the reference vehicle.
function AssignedCoursesManager:getVehiclesWithCoursesByDistance(refVehicle)
	local vehiclesWithCourse = {}
	for i, v in pairs(self.vehicles) do 
		if v:hasCpCourse() and v ~= refVehicle then 
			table.insert(vehiclesWithCourse, v)
		end
	end
	table.sort(vehiclesWithCourse, function (a, b)
		return calcDistanceFrom(refVehicle.rootNode, a.rootNode) <  calcDistanceFrom(refVehicle.rootNode, b.rootNode)
	end)
	return vehiclesWithCourse
end

--- Saves all assigned vehicle courses in a single xml file under the savegame folder.
function AssignedCoursesManager:saveAssignedCourses(savegameDir)

	local xmlFile = XMLFile.create("assignedCoursesXmlFile", savegameDir..self.fileName, 
								self.rootXmlKey, self.xmlSchema)
	local ix = 0
	for _,vehicle in pairs(self.vehicles) do 
		--- Checks if the vehicle has courses.
		if vehicle:hasCpCourse() then
			local key = string.format("%s(%d)", self.baseXmlKey, ix)
			xmlFile:setValue(key.."#name", vehicle:getName())
			vehicle:saveAssignedCpCourses(xmlFile, key..".Course")
			--- Sets a unique ID to the vehicle, so the assigned courses can be loaded correctly into the vehicle.
			--- This ID is saved in the CpCourseManager Spec.
			vehicle:setCpAssignedCoursesID(ix)
			ix = ix + 1
		end
	end
	xmlFile:save()
	xmlFile:delete()
end

--- Gets the number of vehicles with assigned courses.
function AssignedCoursesManager:loadAssignedCourses(savegameDir)
	self.filePath = savegameDir..self.fileName
	self.xmlFile = XMLFile.loadIfExists("assignedCoursesXmlFile", self.filePath , self.xmlSchema)
	if self.xmlFile then
		self.xmlFile:iterate(self.baseXmlKey, function (ix,key)
			self.numVehiclesWithCourses = self.numVehiclesWithCourses + 1
		end)
	end
end

--- Makes sure the xml file handle gets delete after the courses are loaded into the vehicles.
function AssignedCoursesManager:finishedLoading()
	if self.xmlFile then
		self.xmlFile:delete()
	end
end

--- Loads courses by the id in which they were saved into the vehicle.
function AssignedCoursesManager:loadAssignedCoursesByVehicle(vehicle,id)
	CpUtil.debugVehicle(CpDebug.DBG_COURSES, vehicle, "Trying to load assigned courses: %s, numVehicles: %d", 
						tostring(id), self.numVehiclesWithCourses)
	if self.xmlFile~=nil and  id and id <= self.numVehiclesWithCourses then 
		local key = string.format("%s(%d).Course", self.baseXmlKey, id)
		vehicle:loadAssignedCpCourses(self.xmlFile, key, true)
	end
end


g_assignedCoursesManager = AssignedCoursesManager()