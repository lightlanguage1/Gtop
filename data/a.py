import os
import fnmatch
import json

def find_and_modify_json_files(root_dir):
    keys_to_delete = ["data", "autoplayBgm", "autoplayBgs", "battleback1Name", "battleback2Name", "bgm", "bgs", "disableDashing", "encounterStep", "encounterList", "height", "parallaxLoopX", "parallaxLoopY", "parallaxShow", "parallaxName", "scrollType", "specifyBattleback", "width"]

    for dirpath, dirnames, filenames in os.walk(root_dir):
        for filename in fnmatch.filter(filenames, '*Map*.json'):
            file_path = os.path.join(dirpath, filename)
            with open(file_path, 'r') as f:
                try:
                    data = json.load(f)
                except json.JSONDecodeError:
                    continue

            modified = False
            for key in keys_to_delete:
                if key in data:
                    del data[key]
                    modified = True

            if modified:
                with open(file_path, 'w') as f:
                    json.dump(data, f, ensure_ascii=False)

                print(f'成功修改了文件：{file_path}')

find_and_modify_json_files('I:\\common')
