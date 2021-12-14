FieldUtil = {}

function FieldUtil.isNodeOnField(node)
    local x, y, z = getWorldTranslation(node)
    local isOnField, _ = FSDensityMapUtil.getFieldDataAtWorldPosition(x, y, z)
    return isOnField
end

--- Is the relative position dx/dz on the same field as node?
function FieldUtil.isOnSameField(node, dx, dy)

end

function FieldUtil.isOnField(x, z)
    local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 1, z);
    local isOnField, _ = FSDensityMapUtil.getFieldDataAtWorldPosition(x, y, z)
    return isOnField
end

--- Returns the field ID (actually, land ID) for a position. The land is what you can buy in the game,
--- including the area around an actual field.
function FieldUtil.getFieldIdAtWorldPosition(posX, posZ)
    local farmland = g_farmlandManager:getFarmlandAtWorldPosition(posX, posZ)
    if farmland ~= nil then
        local fieldMapping = g_fieldManager.farmlandIdFieldMapping[farmland.id]
        if fieldMapping ~= nil and fieldMapping[1] ~= nil then
            return fieldMapping[1].fieldId
        end
    end
    return 0
end

function FieldUtil.saveAllFields()
    local fileName = createXMLFile("cpFields", string.format('%s/cpFields.xml', g_Courseplay.cpDebugPrintXmlFolderPath), "CPFields");
    print(string.format('Saving fields to %s', fileName))
    if fileName and fileName ~= 0 then
        for _, field in pairs(g_fieldManager:getFields()) do
            local key = ("CPFields.field(%d)"):format(field.fieldId);
            setXMLInt(fileName, key .. '#fieldNum',	field.fieldId);
            local points = g_fieldScanner:findContour(field.posX, field.posZ)
            setXMLInt(fileName, key .. '#numPoints', #points);
            for i,point in ipairs(points) do
                setXMLString(fileName, key .. (".point%d#pos"):format(i), ("%.2f %.2f %.2f"):format(point.x, point.y, point.z))
            end;

        end
        saveXMLFile(fileName);
        delete(fileName);
    else
        print("Error: Courseplay's custom fields could not be saved to " .. CpManager.cpCoursesFolderPath);
    end;
end

