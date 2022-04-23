
---@class WorkWidthUtil
WorkWidthUtil = {}

--- Iterator for all work areas of an object
---@param object table
function WorkWidthUtil.workAreaIterator(object)
    local i = 0
    return function()
        i = i + 1
        local wa = WorkWidthUtil.hasValidWorkArea(object) and object:getWorkAreaByIndex(i)
        if wa then return i, wa end
    end
end

--- Gets work areas if possible.
---@param object table
function WorkWidthUtil.hasWorkAreas(object)
    return WorkWidthUtil.hasValidWorkArea(object) and object:getWorkAreaByIndex(1)
end

function WorkWidthUtil.hasValidWorkArea(object)
    return object and object.getWorkAreaByIndex and object.spec_workArea.workAreas
end

--- Gets the working width and offset calculated from all built-in and attached implements. If an implement has
--- a width or offset configured, it takes precedence over the calculated values.
---
--- Working width can be tricky if there are multiple implements attached. There is no guarantee that all work areas are
--- in the centerline of the vehicle, for instance mowers can be offset on one side. To get the true working width, we must
--- collect distance of the work area edges left and right for all implements and use the maximum left/right values to
--- calculate the width. This also results in an offset, which is the distance between the vehicle's centerline and the
--- middle of the work area.
---
---@param object table
---@param referenceNode number the node for calculating the work width, if not supplied, use the object's root node
---@param ignoreObject table ignore this object when calculating the width (as it is being detached, for instance)
function WorkWidthUtil.getAutomaticWorkWidthAndOffset(object, referenceNode, ignoreObject)
    -- when first called for the vehicle, referenceNode is empty, so use the vehicle root node
    referenceNode = referenceNode or object.rootNode
    WorkWidthUtil.debug(object, 'getting working width...')
    -- check if we have a manually configured working width
    local configuredWidth = g_vehicleConfigurations:get(object, 'workingWidth')
    local configuredOffset = g_vehicleConfigurations:get(object, 'toolOffsetX')

    local left, right = -math.huge, math.huge
    local width, offset

    if object.getVariableWorkWidth then
        --- Gets the variable work width to the left + to the right.
        local w1,_,isValid1 = object:getVariableWorkWidth(true)
        local w2,_,isValid2 = object:getVariableWorkWidth()
        if isValid1 and isValid2 then
            width = math.abs(w1) + math.abs(w2)
            WorkWidthUtil.debug(object, '%s: left = %.1f, right = %.1f, setting variable work width of %.1f.',
                    w1, w2, width)
        end
    end

    --- Work width for soil samplers.
    if not width and object.spec_soilSampler then 
        width = object.spec_soilSampler.samplingRadius and 2 * object.spec_soilSampler.samplingRadius/ math.sqrt(2)
    end

    -- if something is foldable, and is folded, we unfold before measuring the width. This makes sure
    -- implements which have the work area/AI markers folding with the implement have a correct width detected
    local wasFolded = false

    if not width then
        wasFolded = ImplementUtil.unfoldForGettingWidth(object)
        -- no manual config, check AI markers
        width, left, right = WorkWidthUtil.getAIMarkerWidth(object, referenceNode)
    end

    if not width then
        if WorkWidthUtil.hasWorkAreas(object) then
            wasFolded = ImplementUtil.unfoldForGettingWidth(object)
            -- no AI markers, check work areas
            width, left, right = WorkWidthUtil.getWorkAreaWidth(object, referenceNode)
        else
            WorkWidthUtil.debug(object, 'has NO work areas')
        end
    end

    local implements = object.getAttachedImplements and object:getAttachedImplements()
    if implements then
        -- get width of all implements
        for _, implement in ipairs(implements) do
            if implement.object ~= ignoreObject then
                local _, _, thisLeft, thisRight = WorkWidthUtil.getAutomaticWorkWidthAndOffset(implement.object)
                left = math.max(thisLeft or 0, left or -math.huge)
                right = math.min(thisRight or 0, right or math.huge)
            end
        end
    end

    -- tuck everything back nicely if we unfolded it
    if wasFolded then
        ImplementUtil.foldAfterGettingWidth(object)
    end

    if configuredWidth then
        width = configuredWidth
        WorkWidthUtil.debug(object, 'using configured working width of %.1f.', configuredWidth)
    elseif left and right then
        width = left - right
        WorkWidthUtil.debug(object, 'working width is %.1f, left %.1f, right %.1f.', width, left, right)
    else
        width = 0
        WorkWidthUtil.debug(object, 'could not determine working width')
    end

    if configuredOffset then
        offset = configuredOffset
        WorkWidthUtil.debug(object, 'using configured tool offset of %.1f.', configuredOffset)
    elseif left and right then
        offset = left - width / 2
        WorkWidthUtil.debug(object, 'calculated tool offset is %.1f.', offset)
    else
        offset = 0
        WorkWidthUtil.debug(object, 'could not determine offset, using 0')
    end

    --return math.floor(width * 10 + 0.5) / 10, math.floor(offset * 10 + 0.5) / 10, left, right
    return width, offset, left, right
end


---@param object table
function WorkWidthUtil.getWorkAreaWidth(object, referenceNode)
    -- TODO: check if there's a better way to find out if the implement has a work area
    local maxLeft, minRight = -math.huge, math.huge
    for i, wa in WorkWidthUtil.workAreaIterator(object) do
        -- work areas are defined by three nodes: start, width and height. These nodes
        -- define a rectangular work area which you can make visible with the
        -- gsVehicleDebugAttributes console command and then pressing F5
        local left, _, _ = localToLocal(wa.start, referenceNode, 0, 0, 0)
        local right, _, _ = localToLocal(wa.width, referenceNode, 0, 0, 0)
        maxLeft = math.max(maxLeft, left)
        minRight = math.min(minRight, right)
        WorkWidthUtil.debug(object, 'work area %d is %s, left = %.1f, right %.1f m',
                i, g_workAreaTypeManager.workAreaTypes[wa.type].name, left, right)
    end
    return maxLeft - minRight, maxLeft, minRight
end

---@param object table
function WorkWidthUtil.getAIMarkerWidth(object, referenceNode)
    if object.getAIMarkers then
        local aiLeftMarker, aiRightMarker = object:getAIMarkers()
        if aiLeftMarker and aiRightMarker then
            -- left/right is just for the log
            local left, _, _ = localToLocal(aiLeftMarker, referenceNode, 0, 0, 0)
            local right, _, _ = localToLocal(aiRightMarker, referenceNode, 0, 0, 0)
            local width = calcDistanceFrom(aiLeftMarker, aiRightMarker)
            WorkWidthUtil.debug(object, 'aiMarkers: left=%.2f, right=%.2f (width %.2f)', left, right, width)
            return width, left, right
        end
    end
end

--- Gets ai markers for an object.
---@param object table
function WorkWidthUtil.getAIMarkers(object, suppressLog)
    local aiLeftMarker, aiRightMarker, aiBackMarker = object:getAIMarkers()
    if not aiLeftMarker or not aiRightMarker or not aiBackMarker then
        -- use the root node if there are no AI markers
        if not suppressLog then
            WorkWidthUtil.debug(object, 'has no AI markers, try work areas')
        end
        aiLeftMarker, aiRightMarker, aiBackMarker = WorkWidthUtil.getAIMarkersFromWorkAreas(object, suppressLog)
        if not aiLeftMarker or not aiRightMarker or not aiLeftMarker then
            if g_vehicleConfigurations:get(object, 'useVehicleSizeForMarkers') then
                if not suppressLog then
                    WorkWidthUtil.debug(object, 'has no work areas, configured to use front/back markers')
                end
                return Markers.getFrontMarkerNode(object), Markers.getFrontMarkerNode(object), Markers.getBackMarkerNode(object)
            else
                if not suppressLog then
                    WorkWidthUtil.debug(object, 'has no work areas, giving up')
                end
                return nil, nil, nil
            end
        else
            if not suppressLog then WorkWidthUtil.debug(object, 'AI markers from work area set') end
            return aiLeftMarker, aiRightMarker, aiBackMarker
        end
    else
        if not suppressLog then WorkWidthUtil.debug(object, 'AI markers set') end
        return aiLeftMarker, aiRightMarker, aiBackMarker
    end
end

--- Calculate the front and back marker nodes of a work area
---@param object table
function WorkWidthUtil.getAIMarkersFromWorkAreas(object, suppressLog)
    -- work areas are defined by three nodes: start, width and height. These nodes
    -- define a rectangular work area which you can make visible with the
    -- gsVehicleDebugAttributes console command and then pressing F5
    for _, area in WorkWidthUtil.workAreaIterator(object) do
        if WorkWidthUtil.isValidWorkArea(area) then
            -- for now, just use the first valid work area we find
            if not suppressLog then
                WorkWidthUtil.debug(object,'Using %s work area markers as AIMarkers',
                        g_workAreaTypeManager.workAreaTypes[area.type].name)
            end
            return area.start, area.width, area.height
        end
    end
end

---@param area table
function WorkWidthUtil.isValidWorkArea(area)
    return area.start and area.height and area.width and
            area.type ~= WorkAreaType.RIDGEMARKER and
            area.type ~= WorkAreaType.COMBINESWATH and
            area.type ~= WorkAreaType.COMBINECHOPPER
end

---@param object table
function WorkWidthUtil.getShieldWorkWidth(object)
    if object.spec_leveler then
        local width = object.spec_leveler.nodes[1].maxDropWidth * 2
        WorkWidthUtil.debug(object, 'is a shield with work width: %.1f',width)
        return width
    end
end

---@param object table
function WorkWidthUtil.getShovelWorkWidth(object)
    if object.spec_shovel and object.spec_shovel.shovelNodes and object.spec_shovel.shovelNodes[1] then
        local width = object.spec_shovel.shovelNodes[1].width
        WorkWidthUtil.debug(object, 'is a shovel with work width: %.1f',width)
        return width
    end
end

--- Shows the current work width selected with the tool offsets applied.
---@param vehicle table
---@param workWidth number
---@param offsX number
---@param offsZ number
function WorkWidthUtil.showWorkWidth(vehicle,workWidth,offsX,offsZ)
    local firstObject =  AIUtil.getFirstAttachedImplement(vehicle,true)
    local lastObject =  AIUtil.getLastAttachedImplement(vehicle,true)


    local function show(object,workWidth,offsX,offsZ)
        if object == nil then
            return
        end
        local f, b = 0,0
        local aiLeftMarker, _, aiBackMarker = object:getAIMarkers()
        if aiLeftMarker and aiBackMarker then
            _,_,b = localToLocal(aiBackMarker, object.rootNode, 0, 0, 0)
            _,_,f = localToLocal(aiLeftMarker, object.rootNode, 0, 0, 0)
        end

        local left =  (workWidth *  0.5) + offsX
        local right = (workWidth * -0.5) + offsX

        local p1x, p1y, p1z = localToWorld(object.rootNode, left,  1.6, b - offsZ)
        local p2x, p2y, p2z = localToWorld(object.rootNode, right, 1.6, b - offsZ)
        local p3x, p3y, p3z = localToWorld(object.rootNode, right, 1.6, f - offsZ)
        local p4x, p4y, p4z = localToWorld(object.rootNode, left,  1.6, f - offsZ)

     --   cpDebug:drawPoint(p1x, p1y, p1z, 1, 1, 0)
       -- cpDebug:drawPoint(p2x, p2y, p2z, 1, 1, 0)
       -- cpDebug:drawPoint(p3x, p3y, p3z, 1, 1, 0)
       -- cpDebug:drawPoint(p4x, p4y, p4z, 1, 1, 0)

  
        DebugUtil.drawDebugLine(p1x, p1y, p1z, p2x, p2y, p2z, 1, 0, 0)
        DebugUtil.drawDebugLine(p2x, p2y, p2z, p3x, p3y, p3z, 1, 0, 0)
        DebugUtil.drawDebugLine(p3x, p3y, p3z, p4x, p4y, p4z, 1, 0, 0)
        DebugUtil.drawDebugLine(p4x, p4y, p4z, p1x, p1y, p1z, 1, 0, 0)
    end
    show(firstObject,workWidth,offsX,offsZ)
    if firstObject ~= lastObject then
        show(lastObject,workWidth,offsX,offsZ)
    end
end


---@param object table
function WorkWidthUtil.debug(object, str,...)
    CpUtil.debugFormat(CpDebug.DBG_IMPLEMENTS,'%s: ' .. str, CpUtil.getName(object), ...)
end
