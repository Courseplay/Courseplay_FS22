
require('CpObject')
------------------------------------------------------------------------------------------------------------------------
-- Mocks for the Giants engine/game functions
------------------------------------------------------------------------------------------------------------------------

g_time = 0

function getDate(formatString)
    return os.date('%H%M%S')
end

g_currentMission = {}
g_currentMission.mock = true
g_currentMission.missionInfo = {}
g_currentMission.missionInfo.mapId = 'MockMap'

g_currentMission.missionDynamicInfo = {}
g_currentMission.missionDynamicInfo.isMultiplayer = false

g_careerScreen = {}
g_careerScreen.currentSavegame = {savegameDirectory = 'savegame1'}

function getUserProfileAppPath()
    return './'
end

function createFolder(folder)
    os.execute('mkdir "' .. folder .. '"')
end

function getFiles(folder, callback, object)
    for dir in io.popen('dir "' .. folder .. '" /b /ad'):lines() do
        object[callback](object, dir, true)
    end
    for file in io.popen('dir "' .. folder .. '" /b /a-d'):lines() do
        object[callback](object, file, false)
    end
end

function getfenv()
    return _G
end

function deleteFile(fullPath)
    os.remove(fullPath)
    --os.execute('del "' .. fullPath .. '"')
end

function deleteFolder(fullPath)
    os.execute('del /s /q "' .. fullPath .. '\\*"')
    os.execute('for /d %i in ("' .. fullPath .. '\\*") do rd /s /q "%i"')
    os.remove(fullPath)
end

function fileExists(path)
    local file = io.open(path, 'rb')
    if file then
        file:close()
    end
    return file ~= nil
end

function copyFile(prevPath,newPath)
    local file, err = io.open(prevPath, 'rb')
    local content = file:read("*a")
    local newFile, err = io.open(newPath, "w")
    newFile:write(content)
    file:close()
    newFile:close()
end

XMLFile = CpObject()

function XMLFile.create(name,path,xmlRootName,xmlSchema)
    local xmlFile = XMLFile()
    xmlFile.path = path
    return xmlFile
end

function XMLFile:save()
    local file,err = io.open(self.path, 'w+')
    if err then
        print("Error xmlFile.save: "..err)
    end
    self.file = file
end

function XMLFile.load(name,path,xmlSchema)
    local xmlFile = XMLFile()
    local file,err = io.open(path, 'r')
    if err then
        print("Error xmlFile.load: "..err)
    end
    xmlFile.file = file
    xmlFile.path = path
    return xmlFile.file ~= nil and xmlFile
end

function XMLFile:delete()
    if self.file then
        self.file:close()
    end
end
