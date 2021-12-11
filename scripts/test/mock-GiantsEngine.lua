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
    os.execute('del "' .. fullPath .. '"')
end

function deleteFolder(fullPath)
    os.execute('del /s /q "' .. fullPath .. '\\*"')
    os.execute('for /d %i in ("' .. fullPath .. '\\*") do rd /s /q "%i"')
end

function fileExists(fullPath)
    for _ in io.popen('dir "' .. fullPath .. '" /b'):lines() do
        return true
    end
    return false
end