
--- This scanner is used to detect continues orchard fields.
--- Every line has to have the same direction.
---
--- TODO: Add an explicit check if the lines are part of a continues field.


---@class VineScanner 
VineScanner = CpObject()
function VineScanner:init(maxStartDistance)
	self.maxStartDistance = maxStartDistance or 10
	self.debugChannel = CpDebug.DBG_COURSES
end

function VineScanner:setup()
	self.vineSystem = g_currentMission.vineSystem
end

function VineScanner:foundVines()
	return self.lines and next(self.lines) ~= nil
end

function VineScanner:findVineNodesInField(vertices, tx, tz)
	if vertices == nil or next(vertices) == nil then 
		self.lines = nil
		self.width = nil
		return false
	end
	local vineNodes = {}
	local vineSegments = {}
	local x, _, z
	local closestSegment, closestDist, dist = nil, math.huge, 0
	local segment, closestNode, closestPlaceable
	--- Finds the closest vine node on a field to the start point.
	for node, placeable in pairs(self.vineSystem.nodes) do 
		x, _, z = getWorldTranslation(node)
		if CpMathUtil.isPointInPolygon(vertices, x, z) then 
			segment = self:getVineSegmentIxForNode(node, placeable.spec_vine.vineSegments)
			table.insert(vineSegments, segment)
			dist = MathUtil.vector2Length(x-tx, z-tz)
			if dist < closestDist then 
				closestSegment = self:getVineSegmentIxForNode(node, placeable.spec_vine.vineSegments)
				closestPlaceable = placeable
				closestNode = node
				closestDist = dist
			end
		end
	end
	if not closestSegment then 
		self.lines = nil
		self.width = nil
		return false
	end
	--- Only use vine segments with the same directions, as the closest segment found.
	local dirX, dirZ = MathUtil.vector2Normalize(closestSegment.x2 - closestSegment.x1, closestSegment.z2 - closestSegment.z1)
	local xa, za, xb, zb, dx, dz
	local segments = {}
	for _, segment in pairs(vineSegments) do 
		xa, za = segment.x1, segment.z1
		xb, zb = segment.x2, segment.z2
		dx, dz = MathUtil.vector2Normalize(xb - xa, zb - za)
		if self:equalDirection(dx, dirX, dz, dirZ) then 
			table.insert(segments, segment)
		end
	end
	--- Separate the segments into lines.
	local left, right = self:separateIntoColumns(segments, closestNode, dirX, dirZ)

	local lines = {}
	--- Combine the found lines to the left and right into one table.
	for i = #left, 1, -1 do 
		table.insert(lines, left[i])
	end

	for _, s in pairs(right) do 
		table.insert(lines, s)
	end

	local newLines = {}
	for i, l in pairs(lines) do
		table.insert(newLines, self:getStartEndPointForLine(l))
	end

	--- Makes sure newLines[1].x1/z1 is the closest point relative to the field generation starting point.
	local dist1 = MathUtil.vector2Length(newLines[1].x1-tx, newLines[1].z1-tz)
	local dist2 = MathUtil.vector2Length(newLines[1].x2-tx, newLines[1].z2-tz)
	local dist3 = MathUtil.vector2Length(newLines[#newLines].x1-tx, newLines[#newLines].z1-tz)
	local dist4 = MathUtil.vector2Length(newLines[#newLines].x2-tx, newLines[#newLines].z2-tz)

	if dist2 < dist1 and dist2 < dist3 and dist2 < dist4 then 
		newLines = self:invertLinesStartAndEnd(newLines)
	elseif dist3 < dist1 and dist3 < dist2 and dist3 < dist4 then
		newLines = self:invertLinesTable(newLines)
	elseif dist4 < dist1 and dist4 < dist2 and dist4 < dist3 then
		newLines = self:invertLinesTable(newLines)
		newLines = self:invertLinesStartAndEnd(newLines)
	end
	self.lines = newLines
	self.width = closestPlaceable.spec_vine.width

--	self:drawSegments(newLines)

	return true
end

function VineScanner:invertLinesStartAndEnd(lines)
	local newLines = {}
	for i, l in pairs(lines) do 
		table.insert(newLines, {
			x1 = l.x2,
			z1 = l.z2,
			x2 = l.x1,
			z2 = l.z1,
		})
	end
	return newLines
end

function VineScanner:invertLinesTable(lines)
	local newLines = {}
	for i = #lines, 1, -1 do 
		table.insert(newLines, lines[i])
	end
	return newLines
end

--- Separate segments relative to the closest segment into left columns(0->x) and right columns(1->-x).
function VineScanner:separateIntoColumns(lines, closestNode, dirX, dirZ)
	local placeable = self.vineSystem.nodes[closestNode]
	local width = placeable.spec_vine.width
	local columnsLeft = {}
	local columnsRight = {}

	--- Left columns 
	local ix = 1
	while true do
		local nx = (ix-1)*width
		local x,_,z = localToWorld(closestNode,nx,0,0) 
		local foundVine = false
		for i, line in pairs(lines) do 
			if MathUtil.getCircleLineIntersection(x, z, 0.1,  line.x1, line.z1, line.x2, line.z2) then
				if columnsLeft[ix] == nil then 
					columnsLeft[ix] = {}
				end
				table.insert(columnsLeft[ix],line)
				foundVine = true
				self:debug("Found line at column %d.",ix)
			end
		end
		if not foundVine then 
			break
		end
		ix = ix + 1
	end
	self:debug("Found %d columns to the left.",#columnsLeft)
	--- Right columns 
	ix = 1
	while true do 	
		local nx = ix*(-width)
		local x,_,z = localToWorld(closestNode,nx,0,0) 	
		local foundVine = false
		for i, line in pairs(lines) do 
			if MathUtil.getCircleLineIntersection(x, z, 0.1,  line.x1, line.z1, line.x2, line.z2) then
				if columnsRight[ix] == nil then 
					columnsRight[ix] = {}
				end
				table.insert(columnsRight[ix],line)
				foundVine = true
				self:debug("Found line at column %d.",ix)
			end
		end
		if not foundVine then 
			break
		end
		ix = ix + 1
	end
	self:debug("Found %d columns to the right.",#columnsRight)
	return columnsLeft,columnsRight
end



--- Are the directions equal ?
function VineScanner:equalDirection(dx, nx, dz, nz)
	return MathUtil.equalEpsilon(nx, dx, 0.01) and MathUtil.equalEpsilon(nz, dz, 0.01) or MathUtil.equalEpsilon(nx, -dx, 0.01) and MathUtil.equalEpsilon(nz, -dz, 0.01)
end

--- Combines the segments on the same line and return a combined segment.
function VineScanner:getStartEndPointForLine(segments)
	local points = {}
	local xa, za, xb, zb
	for _, segment in pairs(segments) do 
		xa, za = segment.x1, segment.z1
		xb, zb = segment.x2, segment.z2	
		table.insert(points, {x = xa, z = za})
		table.insert(points, {x = xb, z = zb})
	end
	if #points > 0 then 
		table.sort(points, function (a, b)
			return a.x < b.x
		end)
		return {x1 = points[1].x, 
				x2 = points[#points].x, 
				z1 = points[1].z, 
				z2 = points[#points].z, 
				}
	end
end


function VineScanner:drawSegments(segments)
	if segments then 
		for i,segment in pairs(segments) do 
			local x1, x2, z1, z2 = segment.x1, segment.x2, segment.z1, segment.z2
			local y1, y2 = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x1, 0, z1), getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x2, 0, z2)
			drawDebugLine(x1, y1 + 2, z1, 1, 0, 0, x2, y2 + 2, z2, 0, 1, 0)
		end
	end
end

function VineScanner:getCourseGeneratorVertices(vineOffset)
	if not self.lines then 
		return
	end
	vineOffset = vineOffset * self.width/2
	self:debug("vineOffset: %f", vineOffset)
	local dirX, dirZ, lengthStart = CpMathUtil.getPointDirection({x = self.lines[1].x1, z = self.lines[1].z1}, {x = self.lines[1].x2, z = self.lines[1].z2})
	local ncx = dirX  * math.cos(math.pi/2) - dirZ  * math.sin(math.pi/2)
	local ncz = dirX  * math.sin(math.pi/2) + dirZ  * math.cos(math.pi/2)
	local yRot = 0	
	if dirX == dirX or dirZ == dirZ then
		yRot = MathUtil.getYRotationFromDirection(dirX, dirZ)
	end
	local lines = {}

	for i=0, lengthStart-4, 2 do 
		table.insert(lines,{
			x = self.lines[1].x1 + ncx * vineOffset + dirX * i,
			z = self.lines[1].z1 + ncz * vineOffset + dirZ * i
		})
	end
	for i=1, #self.lines do 
		table.insert(lines, {
			x = self.lines[i].x2 + ncx * vineOffset,
			z = self.lines[i].z2 + ncz * vineOffset,
		})
	end
	
	local dirXEnd, dirZEnd, lengthEnd = CpMathUtil.getPointDirection({x = self.lines[#self.lines].x2, z = self.lines[#self.lines].z2}, {x = self.lines[#self.lines].x1, z = self.lines[#self.lines].z1})
	for i=0, lengthEnd-4, 2 do 
		table.insert(lines,{
			x = self.lines[#self.lines].x2 + ncx * vineOffset + dirXEnd * i,
			z = self.lines[#self.lines].z2 + ncz * vineOffset + dirZEnd * i
		})
	end
	for i=#self.lines, 1, -1 do 
		table.insert(lines, {
			x = self.lines[i].x1 + ncx * vineOffset,
			z = self.lines[i].z1 + ncz * vineOffset,
		})
	end
	return lines, self.width, -math.deg(yRot)
end

--- Generates a simple course for the lines.
function VineScanner:generateCourse(vineOffset, multiTools, rowsToSkip)
	if not self.lines then 
		return
	end
	local node = createTransformGroup("vineScannerNode")
	link(g_currentMission.terrainRootNode, node)
	vineOffset = vineOffset * self.width/2
	self:debug("vineOffset: %f, rowsToSkip: %d, multiTools: %d", vineOffset, rowsToSkip, multiTools)
	local dirX, dirZ, length, ncx, ncz, x, z, dx, dz, diff, vOffset, _, yRot
	if #self.lines > 1 and multiTools % 2 == 0 then
		yRot = 0
		dirX, dirZ = CpMathUtil.getPointDirection({x = self.lines[1].x1, z = self.lines[1].z1}, {x = self.lines[2].x2, z = self.lines[2].z2})
		if dirX == dirX or dirZ == dirZ then
			yRot = MathUtil.getYRotationFromDirection(dirX, dirZ)
		end
		setWorldTranslation(node, self.lines[1].x1, 0, self.lines[2].z1)
		setWorldRotation(node, 0, yRot, 0)
		diff, _, _ = worldToLocal(node, self.lines[2].x1, 0, self.lines[2].z1)
		if diff > 0 then 
			vineOffset = vineOffset + (rowsToSkip+1) * self.width/2
		else 
			vineOffset = vineOffset - (rowsToSkip+1) * self.width/2
		end
	end
	local forward = true
	self.offset = 8
	self.spacing = 3
	self.waypoints = {}
	local relevantLines = {}
	local lastAddedIx
	local preLines = {}
	if rowsToSkip > 0 then 
		--- Removes every second line.
		for ix,l in ipairs(self.lines) do 
			if (ix-1) % 2 == 0 then 
				table.insert(preLines, l)
			end
		end
		if #self.lines % 2 > 0 then 
			table.insert(preLines, self.lines[#self.lines])
		end
	else 
		preLines = self.lines
	end
	for ix,l in ipairs(preLines) do 
		if multiTools > 1 then 
			--- Finds the center multi tool lane.
			if (ix + math.ceil(multiTools/2) - 1) % multiTools == 0 then
				table.insert(relevantLines,l)
				lastAddedIx = ix
			end
		else
			table.insert(relevantLines,l)
		end
	end
	--- Handles possible rest parts left over.
	if lastAddedIx then 
		local d = #preLines - lastAddedIx
		local diff = d % multiTools
		if diff ~= 0 then 
			table.insert(relevantLines, preLines[lastAddedIx+diff])
		end
	end
	--- Generates lines alternating
	for ix,l in ipairs(relevantLines) do 
		if forward then 
			dirX, dirZ, _ = CpMathUtil.getPointDirection({x = l.x1, z = l.z1}, {x = l.x2, z = l.z2})
			yRot = 0
			if dirX == dirX or dirZ == dirZ then
				yRot = MathUtil.getYRotationFromDirection(dirX, dirZ)
			end
			dirX = dirX or 0
			dirZ = dirZ or 1
			ncx = dirX  * math.cos(math.pi/2) - dirZ  * math.sin(math.pi/2)
			ncz = dirX  * math.sin(math.pi/2) + dirZ  * math.cos(math.pi/2)
			x = l.x1 - dirX * self.offset + ncx * vineOffset
			z = l.z1 - dirZ * self.offset + ncz * vineOffset
			if #self.waypoints > 0 then 
				setWorldTranslation(node, x, 0, z)
				setWorldRotation(node, 0, yRot, 0)
				_, _, diff = worldToLocal(node, self.waypoints[#self.waypoints].x, 0, self.waypoints[#self.waypoints].z)
				if diff < 0 then 
					x = x + dirX * diff
					z = z + dirZ * diff
				end
			end
			dx = l.x2 + dirX * self.offset + ncx * vineOffset
			dz = l.z2 + dirZ * self.offset + ncz * vineOffset
			if relevantLines[ix+1] then 
				setWorldTranslation(node, dx, 0, dz)
				setWorldRotation(node, 0, yRot, 0)
				_, _, diff = worldToLocal(node, relevantLines[ix+1].x2 + dirX * self.offset - ncx * vineOffset, 0, relevantLines[ix+1].z2 + dirZ * self.offset - ncz * vineOffset)
				if diff > 0 then 
					dx = dx + dirX * diff 
					dz = dz + dirZ * diff 
				end
			end

			length = MathUtil.vector2Length(dx - x, dz- z)
			self:addWaypointsInBetween(function (waypoints, i, nPoints, x, z)
				table.insert(waypoints, {
					x = x,
					z = z,
					turnEnd = i == 1,
					turnStart = i == nPoints,
					rowNumber = ix
				})
			end, length, x, z, dirX, dirZ, ncx, ncz, 0)
		else 
			dirX, dirZ, _ = CpMathUtil.getPointDirection({x = l.x2, z = l.z2}, {x = l.x1, z = l.z1})
			yRot = 0
			if dirX == dirX or dirZ == dirZ then
				yRot = MathUtil.getYRotationFromDirection(dirX, dirZ)
			end
			dirX = dirX or 0
			dirZ = dirZ or 1
			ncx = dirX  * math.cos(math.pi/2) - dirZ  * math.sin(math.pi/2)
			ncz = dirX  * math.sin(math.pi/2) + dirZ  * math.cos(math.pi/2)
			x = l.x2 - dirX * self.offset - ncx * vineOffset
			z = l.z2 - dirZ * self.offset - ncz * vineOffset
			if #self.waypoints > 0 then 
				setWorldTranslation(node, x, 0, z)
				setWorldRotation(node, 0, yRot, 0)
				_, _, diff = worldToLocal(node, self.waypoints[#self.waypoints].x, 0, self.waypoints[#self.waypoints].z)
				if diff < 0 then 
					x = x + dirX * diff 
					z = z + dirZ * diff
				end
			end
			dx = l.x1 + dirX * self.offset - ncx * vineOffset
			dz = l.z1 + dirZ * self.offset - ncz * vineOffset
			if relevantLines[ix+1] then 
				setWorldTranslation(node, dx, 0, dz)
				setWorldRotation(node, 0, yRot, 0)
				_, _, diff = worldToLocal(node, relevantLines[ix+1].x1 + dirX * self.offset + ncx * vineOffset, 0, relevantLines[ix+1].z1 + dirZ * self.offset + ncz * vineOffset)
				if diff > 0 then 
					dx = dx + dirX * diff
					dz = dz + dirZ * diff
				end
			end

			length = MathUtil.vector2Length(dx - x, dz- z)
			self:addWaypointsInBetween(function (waypoints, i, nPoints, x, z)
				table.insert(waypoints, {
					x = x,
					z = z,
					turnEnd = i == 1,
					turnStart = i == nPoints,
					rowNumber = ix
				})
			end, length, x, z, dirX, dirZ, ncx, ncz, 0)
		end

		forward = not forward
	end
	CpUtil.destroyNode(node)
	local c = Course(nil, self.waypoints)
	c.multiTools = multiTools 
	if multiTools > 1 and rowsToSkip > 0 then 
		c.workWidth = self.width * multiTools * 2
	else 
		c.workWidth = self.width * multiTools
	end
	return c
end

function VineScanner:addWaypointsInBetween(lambda, length, x, z, dirX, dirZ, ncx, ncz, vOffset)
	local nPoints = math.floor(length/ self.spacing) + 1
	local dBetweenPoints = (length) / nPoints
	local dx, dz = 0, 0
	for i = 1, nPoints do
		dx = x + dirX * dBetweenPoints * i + ncx * vOffset
		dz = z + dirZ * dBetweenPoints * i + ncz * vOffset
		lambda(self.waypoints, i, nPoints, dx, dz)
	end
end

--- Gets a segment for a vine node.
function VineScanner:getVineSegmentIxForNode(node, vineSegments)
	for segment, nodes in pairs(vineSegments) do 
		for i, data in pairs(nodes) do 
			if data.node == node then 
				return segment
			end
		end
	end
end

function VineScanner:debug(str,...)
	CpUtil.debugFormat(self.debugChannel,"VineScanner: "..str, ...)
end

function VineScanner:debugSparse(...)
	if g_updateLoopIndex % 100 == 0 then
        self:debug(...)
    end
end

g_vineScanner = VineScanner()