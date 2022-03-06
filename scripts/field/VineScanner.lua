--- This scanner is used to detect continues orchard fields.
--- Every line has to have the same direction.
--- This means all vine placements need to be placed with the a snapping angle.
--- The output is a field boundary of the vine nodes for the course generator.
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
	local left, right = self:separateIntoColumns(segments, closestNode)

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

	--- Makes sure the closest line is near the starting point, which should be lines[1].x1/z1
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


	return true
end

--- Invert's the lines from end(lines.x2/z2) -> start(lines.x1/z1)
---@param lines table
---@return table
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

--- Invert's the lines from right(#lines) -> left(lines[1])
---@param lines table
---@return table
function VineScanner:invertLinesTable(lines)
	local newLines = {}
	for i = #lines, 1, -1 do 
		table.insert(newLines, lines[i])
	end
	return newLines
end

--- Separate segments relative to the closest segment into left columns(0->x) and right columns(1->-x).
---@param lines table
---@param closestNode node
---@return table left lines 
---@return table right lines
function VineScanner:separateIntoColumns(lines, closestNode)
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
--- TODO: Is not working for field like these: 
--[[
	| | | |     | | | |
	| |		=>  | | | |
	| |			| | | |
	| |	|		| | | |
	| | | |		| | | |
]]			
---@param segments table all the line segments sorted into columns form left -> right.
---@return table lines from left -> right, but only complete lines.
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

--- Debug function to draw the vine segments.
function VineScanner:drawSegments(segments)
	if segments then 
		for i,segment in pairs(segments) do 
			local x1, x2, z1, z2 = segment.x1, segment.x2, segment.z1, segment.z2
			local y1, y2 = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x1, 0, z1), getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x2, 0, z2)
			drawDebugLine(x1, y1 + 2, z1, 1, 0, 0, x2, y2 + 2, z2, 0, 1, 0)
		end
	end
end

--- Creates a field boundary relative to the size of the vine field,
--- so the course generator can generate courses for these.
---@param vineOffset number should the driver driver beside or over the vines. (-1/0/1)
---@return table field boundary
---@return number gap between the vine nodes.
---@return number angle of the vine rows(degree)
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