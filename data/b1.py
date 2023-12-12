import os
import fnmatch
import json

def remove_key_from_dict(dictionary, key_to_remove):
    if isinstance(dictionary, dict):
        if key_to_remove in dictionary:
            del dictionary[key_to_remove]
        for key, value in list(dictionary.items()):
            remove_key_from_dict(value, key_to_remove)
    elif isinstance(dictionary, list):
        for item in dictionary:
            remove_key_from_dict(item, key_to_remove)

def find_and_modify_json_files(root_dir, key_to_remove):
    for dirpath, dirnames, filenames in os.walk(root_dir):
        for filename in fnmatch.filter(filenames, '**.json'):
            file_path = os.path.join(dirpath, filename)
            with open(file_path, 'r') as f:
                try:
                    data = json.load(f)
                except json.JSONDecodeError:
                    continue

            remove_key_from_dict(data, key_to_remove)

            with open(file_path, 'w') as f:
                json.dump(data, f, ensure_ascii=False)

            print(f'成功修改了文件：{file_path}')

find_and_modify_json_files('I:\common\在00003', 'json_class')
