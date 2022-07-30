---@class CpRemainingTime
CpRemainingTime = CpObject()
--- Starting error estimate, gets less influence once the progress since the start increases.
CpRemainingTime.initialError = 0.25 -- +25%
CpRemainingTime.turnError = 0.00 -- +0%
CpRemainingTime.timeSaveInterval = 60 -- 1min
CpRemainingTime.debugActive = true
CpRemainingTime.rootXmlKey = "Values"
CpRemainingTime.baseXmlKey = "Values.Value"

function CpRemainingTime.registerXmlSchema()
	CpRemainingTime.xmlSchema = XMLSchema.new("CpRemainingTime")
	CpRemainingTime.xmlSchema:register(XMLValueType.STRING, CpRemainingTime.rootXmlKey .. "#vehicleName", "Vehicle name")
	CpRemainingTime.xmlSchema:register(XMLValueType.STRING, CpRemainingTime.rootXmlKey .. "#courseName", "Course name")
	CpRemainingTime.xmlSchema:register(XMLValueType.FLOAT, CpRemainingTime.rootXmlKey .. "#courseLength", "Course length needed to travel")
	CpRemainingTime.xmlSchema:register(XMLValueType.FLOAT, CpRemainingTime.rootXmlKey .. "#distanceTraveled", "Vehicle distance traveled")
	CpRemainingTime.xmlSchema:register(XMLValueType.FLOAT, CpRemainingTime.rootXmlKey .. "#lastAverageSpeed", "Average speed")
	CpRemainingTime.xmlSchema:register(XMLValueType.FLOAT, CpRemainingTime.rootXmlKey .. "#timePassed", "Total time spend driving")
	CpRemainingTime.xmlSchema:register(XMLValueType.FLOAT, CpRemainingTime.rootXmlKey .. "#firstStartEstimate", "Fist start estimate")
	CpRemainingTime.xmlSchema:register(XMLValueType.INT, CpRemainingTime.rootXmlKey .. "#multiTools", "Number of multi tools")
	CpRemainingTime.xmlSchema:register(XMLValueType.INT, CpRemainingTime.rootXmlKey .. "#numTurns", "Number of turns")
	CpRemainingTime.xmlSchema:register(XMLValueType.INT, CpRemainingTime.rootXmlKey .. "#numHeadlands", "Number of headlands")

	
	local key = CpRemainingTime.baseXmlKey .. "(?)"
	CpRemainingTime.xmlSchema:register(XMLValueType.FLOAT, key .. "#timePassed", "Time passed driving")
	CpRemainingTime.xmlSchema:register(XMLValueType.FLOAT, key .. "#distanceTraveled", "Vehicle distance traveled")
	CpRemainingTime.xmlSchema:register(XMLValueType.FLOAT, key .. "#averageSpeed", "Average speed")
	CpRemainingTime.xmlSchema:register(XMLValueType.FLOAT, key .. "#estimate", "Current guess")
	CpRemainingTime.xmlSchema:register(XMLValueType.FLOAT, key .. "#estimateMovingAverage", "Current moving average guess")
	CpRemainingTime.xmlSchema:register(XMLValueType.FLOAT, key .. "#progressSinceStart", "Progress since start")

end
CpRemainingTime.registerXmlSchema()

function CpRemainingTime:init(vehicle, course, startIx)
	self.vehicle = vehicle
	self.startWpIx = startIx
	self.course = course
	self.length = course:getLength()
	self.numTurns = course:getNumberOfTurns()
	self.numHeadlands = course:getNumberOfHeadlands()
	self.multiTools = course:getMultiTools()
	self.timePassed = 0
	self.distanceTraveled = 0
	self.lastError = 0
	self.lastAverageSpeed = self:getOptimalSpeed()
	self.progress = 0
	self.firstEstimate = nil
	self.data = {}
	self.lastTimeSaved = -self.timeSaveInterval
	self.debugFolderDir = g_Courseplay.debugDir .. "/RemainingTime/"
	createFolder(self.debugFolderDir) 
end

function CpRemainingTime:delete()
	if self.course then
		local courseLengthTraveled = (self.course:getProgress(self.course:getLastPassedWaypointIx()) - self.course:getProgress(self.startWpIx)) * self.length / 1000
		self:debug("Time needed: %s, first time estimate: %s, course length since start wp: %.2fkm, distance traveled: %.2fkm, average speed: %.2fkm/h",
					CpGuiUtil.getFormatTimeText(self.timePassed), 
					CpGuiUtil.getFormatTimeText(self.firstEstimate),
					courseLengthTraveled,
					self.distanceTraveled / 1000,
					MathUtil.mpsToKmh(self.lastAverageSpeed)
			)
		if self.debugActive then
			self:save(courseLengthTraveled)
		end
	end
end

function CpRemainingTime:save(courseLengthTraveled)
	if next(self.data) ~= nil then 
		local name = tostring( getDate( "%Y-%m-%d_%H-%M-%S"))
		local xmlFile = XMLFile.create("timeRemaining", self.debugFolderDir .. name..".xml", self.rootXmlKey, self.xmlSchema)
		if xmlFile then 
			self:debug("Time remaining data saved successfully with %d measurements.", #self.data)
			xmlFile:setValue(self.rootXmlKey .. "#vehicleName", CpUtil.getName(self.vehicle))
			xmlFile:setValue(self.rootXmlKey .. "#courseName", self.course:getName())
			xmlFile:setValue(self.rootXmlKey .. "#courseLength", courseLengthTraveled)
			xmlFile:setValue(self.rootXmlKey .. "#distanceTraveled", self.distanceTraveled)
			xmlFile:setValue(self.rootXmlKey .. "#lastAverageSpeed", self.lastAverageSpeed)
			xmlFile:setValue(self.rootXmlKey .. "#timePassed", self.timePassed)
			xmlFile:setValue(self.rootXmlKey .. "#firstStartEstimate", self.firstStartEstimate)
			xmlFile:setValue(self.rootXmlKey .. "#multiTools", self.multiTools)
			xmlFile:setValue(self.rootXmlKey .. "#numTurns", self.numTurns)
			xmlFile:setValue(self.rootXmlKey .. "#numHeadlands",self.numHeadlands)

			local d, key
			for i = 0, #self.data -1 do 
				d = self.data[i+1]
				key = string.format("%s(%d)", self.baseXmlKey, i)
				xmlFile:setValue(key .. "#distanceTraveled", d.distance)
				xmlFile:setValue(key .. "#averageSpeed", d.averageSpeed)
				xmlFile:setValue(key .. "#timePassed", d.time)
				xmlFile:setValue(key .. "#estimate", d.estimate)
				xmlFile:setValue(key .. "#estimateMovingAverage", d.estimateMovingAverage)
				xmlFile:setValue(key .. "#progressSinceStart", d.progressSinceStart)
			end
			xmlFile:save()
			xmlFile:delete()
		end
	end
end

function CpRemainingTime:debug(...)
    CpUtil.debugVehicle(CpDebug.DBG_FIELDWORK, self.vehicle, ...)
end

function CpRemainingTime:debugSparse(...)
    if g_updateLoopIndex % 100 == 0 then
        self:debug(...)
    end
end

function CpRemainingTime:update(dt)
	local wpIx = self.course:getCurrentWaypointIx()
	if wpIx < self.startWpIx then 
		wpIx = self.startWpIx
	end
	
	--- Makes sure the start error gets applied more at the beginning and less near the end.
	local progressSinceStart = MathUtil.clamp(self.course:getProgress(wpIx) - self.course:getProgress(self.startWpIx), 0, 1)
	self.progress = progressSinceStart

	--- Makes sure the calculated error gets applied more towards the end.
	local invertedProgressSinceStart = 1 - progressSinceStart

	--- Updates global values
	if self.vehicle:getLastSpeed() > 1 then 
		--- Distance traveled since start in m.
		self.distanceTraveled = self.distanceTraveled + self.vehicle.lastMovedDistance
		--- Actual time passed since the start, excludes time where the driver is standing still.
		self.timePassed = self.timePassed + dt/1000
	end

	if self.vehicle:getLastSpeed() > 3 then	
		--- Average speed in m/s
		self.lastAverageSpeed = MathUtil.clamp(self.distanceTraveled /self.timePassed, MathUtil.kmhToMps(3), MathUtil.kmhToMps(50))
	end

	self.startEstimate = self:getPredicatedTimeRemaining(wpIx)
	self.movingAverageEstimate = self:getOptimalTimeRemaining(wpIx)

	self.lastEstimate = self.startEstimate * progressSinceStart + self.movingAverageEstimate * invertedProgressSinceStart 
	
	if not self.firstEstimate and self.lastEstimate > 100 then 
		self.firstEstimate = self.lastEstimate
		self.firstStartEstimate = self.startEstimate
	end

	if (self.timePassed - self.lastTimeSaved) > self.timeSaveInterval then 
		self.lastTimeSaved = self.timePassed
		table.insert(self.data,
			{
				time = self.timePassed,
				distance = self.distanceTraveled,
				averageSpeed = self.lastAverageSpeed,
				estimate = self.lastEstimate,
				estimateMovingAverage = self.movingAverageEstimate,
				progressSinceStart = progressSinceStart
			}
		)
	end

end

---------------------------------------------------------
--- Calculate the remaining course time left.
---------------------------------------------------------

function CpRemainingTime:getTimeRemaining()
	return self.lastEstimate
end

function CpRemainingTime:getRemainingCourseTime(ix, speed)
    local dx = self.course:getProgress(ix)
    return ((1-dx) * self.length) / speed -- in seconds
end

--- Gets the optimal time with a initial error applied 
--- and a turn error relative to the number of turns per course length.
function CpRemainingTime:getOptimalTimeRemaining(wpIx)
	local error = self.initialError + self.turnError * self.numTurns/self.length
    return self:getRemainingCourseTime(wpIx, self:getOptimalSpeed()) * (1 + error)
end

--- Gets the predicated time relative to the speed limit.
function CpRemainingTime:getPredicatedTimeRemaining(wpIx)
    
    --- Time remaining of the course.
    local timeRemaining = self:getRemainingCourseTime(wpIx, self.lastAverageSpeed)
    --- Course time since starting point.
    local courseTimeSinceStart = self:getRemainingCourseTime(self.startWpIx, self.lastAverageSpeed)

    local courseTimeTraveled = courseTimeSinceStart - timeRemaining

    --- Relative time error to the optimal course time traveled.
    self.lastError = MathUtil.clamp(courseTimeTraveled/timeRemaining, 0, 0.5)
    return timeRemaining * (1 + self.lastError)
end

function CpRemainingTime:getOptimalSpeed()
	return MathUtil.kmhToMps(MathUtil.clamp(self.vehicle:getSpeedLimit(true), 1, self.vehicle:getCpSettings().fieldWorkSpeed:getValue())) -- in m/s
end