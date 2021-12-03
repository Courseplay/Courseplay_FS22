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