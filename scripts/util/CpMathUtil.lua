CpMathUtil = {}
function CpMathUtil.getIntersectionPoint(A1x, A1y, A2x, A2y, B1x, B1y, B2x, B2y) --@src: http://stackoverflow.com/questions/563198/how-do-you-detect-where-two-line-segments-intersect#comment19248344_1968345
	local s1_x, s1_y, s2_x, s2_y
	s1_x = A2x - A1x
	s1_y = A2y - A1y
	s2_x = B2x - B1x
	s2_y = B2y - B1y

	local s, t
	s = (-s1_y * (A1x - B1x) + s1_x * (A1y - B1y)) / (-s2_x * s1_y + s1_x * s2_y)
	t = ( s2_x * (A1y - B1y) - s2_y * (A1x - B1x)) / (-s2_x * s1_y + s1_x * s2_y)

	if (s >= 0 and s <= 1 and t >= 0 and t <= 1) then
		--Collision detected
		local x = A1x + (t * s1_x)
		local z = A1y + (t * s1_y)
		return { x = x, z = z }
	end

	--No collision
	return nil
end

function CpMathUtil.getPointDirection(cp, np)
	local dx, dz = np.x - cp.x, np.z - cp.z
	local vl = MathUtil.vector2Length(dx, dz)
	if vl and vl > 0.0001 then
		dx = dx / vl
		dz = dz / vl
	end
	return dx, dz, vl
end

function CpMathUtil.getNodeDirection(node)
	local lx, _, lz = localDirectionToWorld(node, 0, 0, 1)
	return math.atan2( lx, lz )
end

--- Returns true if node1 is pointing approximately in node2's direction
---@param thresholdDeg number defines what 'approximately' means, by default if the difference is less than 10 degrees
function CpMathUtil.isSameDirection(node1, node2, thresholdDeg)
	local lx, _, lz = localDirectionToLocal(node1, node2, 0, 0, 1)
	return math.abs(math.atan2(lx, lz)) < math.rad(thresholdDeg or 5)
end

--- Get a series of values, the first value is 'from', the last is 'to', and as many values as needed between the
--- two with a maximum of 'step' difference.
--- Always returns at least from and to
function CpMathUtil.getSeries(from, to, step)
	local nValues = math.max(1, math.floor(math.abs((from - to) / step)))
	local delta = (to - from) / nValues
	local value = from
	local series = {}
	for i = 0, nValues do
		table.insert(series, value + i * delta)
	end
	return series
end

-- POINT IN POLYGON (Jordan method) -- @src: http://de.wikipedia.org/wiki/Punkt-in-Polygon-Test_nach_Jordan
-- returns:
--	 1	point is inside of polygon
--	-1	point is outside of polygon
--	 0	point is directly on polygon
function CpMathUtil.isPointInPolygon(polygon, x, z)
	local function crossProductQuery(a, b, c)
		-- returns:
		--	-1	vector from A to right intersects BC (except at the bottom end point)
		--	 0	A is directly on BC
		--	 1	all else

		if a.z == b.z and b.z == c.z then
			if (b.x <= a.x and a.x <= c.x) or (c.x <= a.x and a.x <= b.x) then
				return 0
			else
				return 1
			end
		end

		if b.z > c.z then b, c = c, b end
		if a.z == b.z and a.x == b.x then return 0 end
		if a.z <= b.z or a.z > c.z then return 1 end

		local delta = (b.x - a.x) * (c.z - a.z) - (b.z - a.z) * (c.x - a.x)

		if delta > 0 then return -1 end
		if delta < 0 then return 1 end
		return 0
	end

	local cp, np, pp
	local pointInPolygon = -1

	for i = 1, #polygon do
		cp = polygon[i]
		np = i < #polygon and polygon[i + 1] or polygon[1]
		pp = i > 1 and polygon[i - 1] or polygon[#polygon]

		pointInPolygon = pointInPolygon * crossProductQuery({ x = x, z = z }, cp, np)
		if pointInPolygon == 0 then
			-- point directly on the edge is considered being in the polygon
			return true
		end
	end

	return pointInPolygon ~= -1
end

--- Get the area of polygon in square meters
---@param polygon [] array elements can be {x, z}, {x, y, z} or {x, y}
function CpMathUtil.getAreaOfPolygon(polygon)
	local area = 0
	for i = 1, #polygon - 1 do
		local x1, y1 = polygon[i].x, polygon[i].z and -polygon[i].z or polygon[i].y
		local x2, y2 = polygon[i + 1].x, polygon[i + 1].z and -polygon[i + 1].z or polygon[i + 1].y
		area = area + (x2 - x1) * (y1 + y2) / 2
	end
	return math.abs(area)
end

--- De-Casteljau algorithm for bezier curves.
--- https://en.wikipedia.org/wiki/De_Casteljau%27s_algorithm
function CpMathUtil.de_casteljau(t, points)
	for i = 1, #points do
		for j = 1, #points-i do
			points[j] = {
				points[j][1] * (1-t) + points[j+1][1] * t,
				points[j][2] * (1-t) + points[j+1][2] * t,
			}
		end
	end
	return points[1][1], points[1][2]
end
