
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

--- Shovel/shield calculation disabled for now.
--- Gets an automatic calculated work width or a pre configured in vehicle configurations.
---@param object table
---@param logPrefix string
function WorkWidthUtil.getAutomaticWorkWidth(object,logPrefix)
    logPrefix = logPrefix and logPrefix .. '  ' or ''
    WorkWidthUtil.debug(object, logPrefix, 'getting working width...')
    -- check if we have a manually configured working width
    local width = g_vehicleConfigurations:get(object, 'workingWidth')

    if not width then
        if object.getVariableWorkWidth then 
            --- Gets the variable work width to the left + to the right.
            local w1,_,isValid1 = object:getVariableWorkWidth(true) 
            local w2,_,isValid2 = object:getVariableWorkWidth()
            if isValid1 and isValid2 then 
                width = math.abs(w1) + math.abs(w2)
                WorkWidthUtil.debug(object, logPrefix, 'setting variable work width of %.1f.', width)
            end
        end
    end

    if not width then
        --- Gets the work width if the object is a shield.
     --   width = WorkWidthUtil.getShieldWorkWidth(object,logPrefix)
    end

    if not width then
        --- Gets the work width if the object is a shovel.
   --     width = WorkWidthUtil.getShovelWorkWidth(object,logPrefix)
    end

    if not width then
        -- no manual config, check AI markers
        width = WorkWidthUtil.getAIMarkerWidth(object, logPrefix)
    end

    if not width then
        -- no AI markers, check work areas
        width = WorkWidthUtil.getWorkAreaWidth(object, logPrefix)
    end

    local implements = object.getAttachedImplements and object:getAttachedImplements()
    if implements then
        -- get width of all implements
        for _, implement in ipairs(implements) do
            width = math.max( width, WorkWidthUtil.getAutomaticWorkWidth(implement.object, logPrefix))
        end
    end
    WorkWidthUtil.debug(object, logPrefix, 'working width is %.1f.',width)
    return width
end


---@param object table
---@param logPrefix string
function WorkWidthUtil.getWorkAreaWidth(object, logPrefix)
    logPrefix = logPrefix or ''
    -- TODO: check if there's a better way to find out if the implement has a work area
    local width = 0
    for i, wa in WorkWidthUtil.workAreaIterator(object) do
        -- work areas are defined by three nodes: start, width and height. These nodes
        -- define a rectangular work area which you can make visible with the
        -- gsVehicleDebugAttributes console command and then pressing F5
        local x, _, _ = localToLocal(wa.width, wa.start, 0, 0, 0)
        width = math.max(width, math.abs(x))
        local _, _, z = localToLocal(wa.height, wa.start, 0, 0, 0)
        WorkWidthUtil.debug(object, logPrefix, 'work area %d is %s, %.1f by %.1f m',
                i, g_workAreaTypeManager.workAreaTypes[wa.type].name, math.abs(x), math.abs(z)
        )
    end
    if width == 0 then
        WorkWidthUtil.debug(object, logPrefix, 'has NO work area.')
    end
    return width
end

---@param object table
---@param logPrefix string
function WorkWidthUtil.getAIMarkerWidth(object, logPrefix)
    logPrefix = logPrefix or ''
    if object.getAIMarkers then
        local aiLeftMarker, aiRightMarker = object:getAIMarkers()
        if aiLeftMarker and aiRightMarker then
            -- left/right is just for the log
            local left, _, _ = localToLocal(aiLeftMarker, object.rootNode, 0, 0, 0)
            local right, _, _ = localToLocal(aiRightMarker, object.rootNode, 0, 0, 0)
            local width = calcDistanceFrom(aiLeftMarker, aiRightMarker)
            WorkWidthUtil.debug(object, logPrefix, 'aiMarkers: left=%.2f, right=%.2f (width %.2f)', left, right, width)
            return width
        end
    end
end

--- Gets ai markers for an object.
---@param object table
---@param logPrefix string
function WorkWidthUtil.getAIMarkers(object, logPrefix, suppressLog)
    local aiLeftMarker, aiRightMarker, aiBackMarker = object:getAIMarkers()
    if not aiLeftMarker or not aiRightMarker or not aiBackMarker then
        -- use the root node if there are no AI markers
        if not suppressLog then
            WorkWidthUtil.debug(object, logPrefix, 'has no AI markers, try work areas')
        end
        aiLeftMarker, aiRightMarker, aiBackMarker = WorkWidthUtil.getAIMarkersFromWorkAreas(object)
        if not aiLeftMarker or not aiRightMarker or not aiLeftMarker then
            if not suppressLog then
                WorkWidthUtil.debug(object, logPrefix, 'has no work areas, giving up, will use front/back markers')
            end
            return Markers.getFrontMarkerNode(object), Markers.getFrontMarkerNode(object), Markers.getBackMarkerNode(object)
        else
            if not suppressLog then WorkWidthUtil.debug(object, logPrefix, 'AI markers from work area set') end
            return aiLeftMarker, aiRightMarker, aiBackMarker
        end
    else
        if not suppressLog then WorkWidthUtil.debug(object, logPrefix, 'AI markers set') end
        return aiLeftMarker, aiRightMarker, aiBackMarker
    end
end

--- Calculate the front and back marker nodes of a work area
---@param object table
function WorkWidthUtil.getAIMarkersFromWorkAreas(object)
    -- work areas are defined by three nodes: start, width and height. These nodes
    -- define a rectangular work area which you can make visible with the
    -- gsVehicleDebugAttributes console command and then pressing F5
    for _, area in WorkWidthUtil.workAreaIterator(object) do
        if WorkWidthUtil.isValidWorkArea(area) then
            -- for now, just use the first valid work area we find
            WorkWidthUtil.debug(object,nil,'Using %s work area markers as AIMarkers',
                    g_workAreaTypeManager.workAreaTypes[area.type].name)
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
---@param logPrefix string
function WorkWidthUtil.getShieldWorkWidth(object,logPrefix)
    if object.spec_leveler then
        local width = object.spec_leveler.nodes[1].maxDropWidth * 2
        WorkWidthUtil.debug(object, logPrefix, 'is a shield with work width: %.1f',width)
        return width
    end
end

---@param object table
---@param logPrefix string
function WorkWidthUtil.getShovelWorkWidth(object,logPrefix)
    if object.spec_shovel and object.spec_shovel.shovelNodes and object.spec_shovel.shovelNodes[1] then
        local width = object.spec_shovel.shovelNodes[1].width
        WorkWidthUtil.debug(object, logPrefix, 'is a shovel with work width: %.1f',width)
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
---@param logPrefix string
function WorkWidthUtil.debug(object, logPrefix, str,...)
    CpUtil.debugFormat(CpDebug.DBG_IMPLEMENTS,'%s%s: ' .. str, logPrefix or "", CpUtil.getName(object), ...)
end
