local CacheMap = CpObject()

--- A cached map to store key-value pairs
--- The map can be multi-dimensional, just make sure to pass in a key for each dimension.
function CacheMap:init(dimensions)
    self.logger = Logger('CacheMap')
    self.dimensions = dimensions or 1
    self.map = {}
end

--- Get the value at the given key
---@param k1[, k2[, k3]]] ... the keys
---@return any the value
function CacheMap:get(...)
    return self:_getMap(...)[select(self.dimensions, ...)]
end

--- Set the value at the given key
---@param k1[, k2[, k3 ...]]], value : the keys in the map, according to the dimension and a value
---@return any the value
function CacheMap:put(...)
    local lastKey = select(self.dimensions, ...)
    local value = select(self.dimensions + 1, ...)
    self:_getMap(...)[lastKey] = value
    return value
end

--- Get the value defined by the key, if not found, call func with the keys and set value to the result.
---@param k1[, k2[, k3]]] ... the keys
---@param lambda function the function to set the value
---@return any the value pointed to by keys. If it is not cached yet, call lambda and set the value to the value
--- returned by lambda
function CacheMap:getWithLambda(...)
    local nArgs = select('#', ...)
    if nArgs < self.dimensions + 1 then
        self.logger:error('getWithFunc() with %d dimension(s) needs %d key(s) and a func, got only %d argument(s)',
                self.dimensions, self.dimensions, nArgs)
        return
    end
    local map = self:_getMap(...)
    local lastKey = select(self.dimensions, ...)
    local entry = map[lastKey]
    if entry == nil then
        map[lastKey] = select(nArgs, ...)()
        return map[lastKey]
    else
        return entry
    end
end

function CacheMap:_getMap(...)
    local nArgs = select('#', ...)
    if nArgs < self.dimensions then
        self.logger:error('get() with %d dimension(s) needs %d key(s), got only %d argument(s)',
                self.dimensions, self.dimensions, nArgs)
        return
    end
    -- drill down to the entry in the map pointed to by the keys, creating non-existing dimensions
    -- on the way when needed
    local map = self.map
    for i = 1, self.dimensions - 1 do
        local key = select(i, ...)
        if not map[key] then
            map[key] = {}
        end
        map = map[key]
    end
    return map
end

---@class CourseGenerator.CacheMap
CourseGenerator.CacheMap = CacheMap