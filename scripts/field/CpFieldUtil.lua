CpFieldUtil = {}
-- force reload
CpFieldUtil.groundTypeModifier = nil

function CpFieldUtil.isNodeOnField(node)
    local x, y, z = getWorldTranslation(node)
    local isOnField, _ = FSDensityMapUtil.getFieldDataAtWorldPosition(x, y, z)
    return isOnField
end

function CpFieldUtil.isNodeOnFieldArea(node)
    local x, _, z = getWorldTranslation(node)
    return CpFieldUtil.isOnFieldArea(x, z)
end

--- Is the relative position dx/dz on the same field as node?
function CpFieldUtil.isOnSameField(node, dx, dy)

end

function CpFieldUtil.isOnField(x, z)
    local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 1, z);
    local isOnField, _ = FSDensityMapUtil.getFieldDataAtWorldPosition(x, y, z)
    return isOnField
end

function CpFieldUtil.initFieldMod()
    local groundTypeMapId, groundTypeFirstChannel, groundTypeNumChannels =
        g_currentMission.fieldGroundSystem:getDensityMapData(FieldDensityMap.GROUND_TYPE)
    CpFieldUtil.groundTypeModifier = DensityMapModifier.new(groundTypeMapId, groundTypeFirstChannel, groundTypeNumChannels,
            g_currentMission.terrainRootNode)
    CpFieldUtil.groundTypeFilter = DensityMapFilter.new(CpFieldUtil.groundTypeModifier)
end

function CpFieldUtil.isOnFieldArea(x, z)
    if CpFieldUtil.groundTypeModifier == nil then
        CpFieldUtil.initFieldMod()
    end
    local w, h = 1, 1
    CpFieldUtil.groundTypeModifier:setParallelogramWorldCoords(x - w / 2, z - h / 2, w, 0, 0, h, DensityCoordType.POINT_VECTOR_VECTOR)
    CpFieldUtil.groundTypeFilter:setValueCompareParams(DensityValueCompareType.GREATER, 0)
    local density, area, totalArea = CpFieldUtil.groundTypeModifier:executeGet(CpFieldUtil.groundTypeFilter)
    return area > 0, area, totalArea
end

--- Which field this node is on.
---@param node table Giants engine node
---@return number 0 if not on any field, otherwise the number of field, see note on getFieldItAtWorldPosition()
function CpFieldUtil.getFieldNumUnderNode(node)
    local x, _, z = getWorldTranslation(node)
    return CpFieldUtil.getFieldIdAtWorldPosition(x, z)
end

--- Which field this node is on. See above for more info
function CpFieldUtil.getFieldNumUnderVehicle(vehicle)
    return CpFieldUtil.getFieldNumUnderNode(vehicle.rootNode)
end

--- Returns the field ID (actually, land ID) for a position. The land is what you can buy in the game,
--- including the area around an actual field.
function CpFieldUtil.getFieldIdAtWorldPosition(posX, posZ)
    local farmland = g_farmlandManager:getFarmlandAtWorldPosition(posX, posZ)
    if farmland ~= nil then
        local fieldMapping = g_fieldManager.farmlandIdFieldMapping[farmland.id]
        if fieldMapping ~= nil and fieldMapping[1] ~= nil then
            return fieldMapping[1].fieldId
        end
    end
    return 0
end


function CpFieldUtil.saveAllFields()
    local fileName = string.format('%s/cpFields.xml', g_Courseplay.debugPrintDir)
    local xmlFile = createXMLFile("cpFields", fileName, "CPFields");
    if xmlFile and xmlFile ~= 0 then
        for _, field in pairs(g_fieldManager:getFields()) do
            local key = ("CPFields.field(%d)"):format(field.fieldId);
            setXMLInt(xmlFile, key .. '#fieldNum',	field.fieldId);
            local points = g_fieldScanner:findContour(field.posX, field.posZ)
            setXMLInt(xmlFile, key .. '#numPoints', #points);
            for i,point in ipairs(points) do
                setXMLString(xmlFile, key .. (".point%d#pos"):format(i), ("%.2f %.2f %.2f"):format(point.x, point.y, point.z))
            end;

        end
        saveXMLFile(xmlFile);
        delete(xmlFile);
        print(string.format('Saved all fields to %s', fileName))
    else
        print("Error: Courseplay's custom fields could not be saved to " .. CpManager.cpCoursesFolderPath);
    end;
end

function CpFieldUtil.initializeFieldMod()
    CpFieldUtil.fieldMod = {}
    CpFieldUtil.fieldMod.modifier = DensityMapModifier:new(g_currentMission.terrainDetailId, g_currentMission.terrainDetailTypeFirstChannel, g_currentMission.terrainDetailTypeNumChannels)
    CpFieldUtil.fieldMod.filter = DensityMapFilter:new(CpFieldUtil.fieldMod.modifier)
end

function CpFieldUtil.isField(x, z, widthX, widthZ)
    if not CpFieldUtil.fieldMod then
        CpFieldUtil.initializeFieldMod()
    end
    widthX = widthX or 0.5
    widthZ = widthZ or 0.5
    local startWorldX, startWorldZ   = x, z
    local widthWorldX, widthWorldZ   = x - widthX, z - widthZ
    local heightWorldX, heightWorldZ = x + widthX, z + widthZ

    CpFieldUtil.fieldMod.modifier:setParallelogramWorldCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, "ppp")
    CpFieldUtil.fieldMod.filter:setValueCompareParams("greater", 0)

    local _, area, totalArea = CpFieldUtil.fieldMod.modifier:executeGet(CpFieldUtil.fieldMod.filter)
    local isField = area > 0
    return isField, area, totalArea
end

