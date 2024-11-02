import re, pprint

TIME_PATTERN = r"\d{4}-\d{2}-\d{2} \d{2}:\d{2}\s*"
CP_TIME_PATTERN = TIME_PATTERN + r":\d{2}\s*"
CP_LOG_PATTERN = CP_TIME_PATTERN + r"\[\w+\s*lp\d*\]\s*"
VERSION_PATTERN = r"[\d\w]+\.[\d\w]+\.[\d\w]+\.[\d\w]+"
CP_VERSION_PATTERN = rf"Current mod name: [\w\d_]+, Current version: {VERSION_PATTERN},"

LOAD_MOD_PATTERN = r"(?<=Load mod:\s)[\w\d_]+"
MOD_VERSION_PATTERN = r"(?<=Version:\s)[\d.]+(?=\)\s*%s)"
MAP_NAME_PATTERN = r"(?<=Map loaded:\s).+(?=,)"
SAVEGAME_NAME_PATTERN = r"(?<=\sSavegame name:\s).+"
SAVEGAME_INDEX_PATTERN = r"(?<=\()\d+(?=\))"

def decodeLog(path):
    with open(path, "r") as f:
        data = f.read()
        found = re.search(r"\d{4}-\d{2}-\d{2} \d{2}:\d{2} ", data)
        sysInfos = "".join(data.splitlines(keepends=True)[3:found.start()])
        sysInfosLines = sysInfos.splitlines(keepends=True)
        fsVersionData = ""
        for i in range(0, len(sysInfosLines)):
            if sysInfosLines[i].startswith("Farming Simulator"):
                j = i + 1
                while True:
                    if not re.match(r"\s+", sysInfosLines[j]):
                        break
                    j += 1
                fsVersionData = "".join(sysInfosLines[i:j])
        fsVersion = re.findall(VERSION_PATTERN, fsVersionData)[0]
          
        for gameData in re.split("Loaded 'vehicle' specializations", data)[1:]:
            try:
                # Courseplay infos ...
                found = re.findall(CP_LOG_PATTERN + CP_VERSION_PATTERN, gameData)[0]
                print(found)
                cpVersion = re.findall(VERSION_PATTERN, found)[0]
                print(f"Game: {fsVersion}, CP: {cpVersion}, Map: ..")

                key = re.search(fr"{CP_LOG_PATTERN}.*{MAP_NAME_PATTERN}.*", gameData).group()
                mapName = re.search(MAP_NAME_PATTERN, key).group()
                savegameName = re.search(SAVEGAME_NAME_PATTERN, key).group()
                savegameIndex = re.search(SAVEGAME_INDEX_PATTERN, savegameName).group()
                print(savegameName, savegameIndex)
                
                found_mods = re.findall(LOAD_MOD_PATTERN, gameData)
                mods = []
                for mod in found_mods:
                    mods.append({
                        "name" : mod, 
                        "version" : re.findall(MOD_VERSION_PATTERN % mod, data)[0]})
                
                print(f"Found Mods: \n{pprint.pformat(mods)}")
            except:
                pass
        
if __name__ == "__main__":
    # TODO add parse input args ...
    # decodeLog()
    pass