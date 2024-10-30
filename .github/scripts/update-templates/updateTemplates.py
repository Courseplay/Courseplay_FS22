import yaml, os, pprint, json

dir_path = '/.github/ISSUE_TEMPLATE/'
config_path = os.path.dirname(__file__) + "/config.json"

# Gets the parent dict/list element for a given value.
def getDictWithValueRecursive(data, value : str) -> dict|list|None:
    if type(data) == dict:
        for k, d in data.items():
            if d == value:
                return data   
            ret = getDictWithValueRecursive(d, value)
            if ret:
                return ret
    elif type(data) == list:
        for d in data:
            if d == value:
                return data   
            ret = getDictWithValueRecursive(d, value)
            if ret:
                return ret

# Updates the possible cp and game versions
def updateTemplateFile(filname : str, config : dict) -> None:
    data = None
    with open(os.getcwd() + dir_path + filname, 'r') as file:
        data = yaml.safe_load(file)
    
    item = getDictWithValueRecursive(data, "mod-version")
    item["attributes"]["options"] = config["cp_versions"]
    item["attributes"]["default"] = len(config["cp_versions"]) - 1
    item = getDictWithValueRecursive(data, "game-version")
    if item:
        item["attributes"]["options"] = config["game_versions"]
        item["attributes"]["default"] = len(config["game_versions"]) - 1
        
    with open(os.getcwd() + dir_path + filname, 'w') as file:
        yaml.dump(data, file, indent=2, sort_keys=False, allow_unicode=True)

def main():
    with open(config_path, "r") as file:
        config = json.load(file)       
        for version in config["modhub_versions"]:
            if not version in config["cp_versions"]:
                config["cp_versions"].append(version)
        
        config["game_versions"].sort(key=lambda s: list(map(int, s.split('.'))))
        config["cp_versions"].sort(key=lambda s: list(map(int, s.split('.'))))
        for filename in os.listdir(os.getcwd() + dir_path):
            updateTemplateFile(filename, config)
    
if __name__ == "__main__":
    main()