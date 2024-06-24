local Math = {}

local function normalizeAngle( a )
    return a >= 0 and a or 2 * math.pi + a
end

function Math.getDeltaAngle(a, b)
    -- convert the 0 - -180 range into 180 - 360
    if math.abs( a - b ) > math.pi then
        a = normalizeAngle( a )
        b = normalizeAngle( b )
    end
    -- calculate difference in this range
    return b - a
end

function Math.clamp(val, min, max)
    return math.min(math.max(val, min), max)
end

cg.Math = Math