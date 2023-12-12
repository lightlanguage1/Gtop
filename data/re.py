import csv
import json
import os

def load_mapping(file):
    with open(file, 'r') as f:
        reader = csv.reader(f)
        next(reader)  # Skip header
        mapping = {row[0]: (row[1], row[2].split('\n')) for row in reader if len(row) >= 3}
    return mapping

def translate_event(event, mapping):
    result = f"事件ID: {event['id']}\n"
    result += f"名称: {event['name'] if event['name'].strip() else '空'}\n"
    result += f"备注: {event['note'] if event['note'].strip() else '空'}\n"

    for i, page in enumerate(event['pages'], start=1):
        result += f"\n页面 {i}:\n"
        result += f"条件: {page['conditions']}\n"
        result += f"图像: {page['image']}\n"
        result += f"移动: {page['moveType']}\n"
        result += f"触发: {page['trigger']}\n"

        result += "\n事件内容:\n"
        for item in page['list']:
            code = str(item['code'])
            if code in mapping:
                name, param_descriptions = mapping[code]
                result += f"{name}: "
                for j, param in enumerate(item['parameters']):
                    param_description = param_descriptions[j]
                    # Check if the parameter description contains an array
                    if '(' in param_description and ')' in param_description:
                        # Extract the array from the parameter description
                        array_start = param_description.index('(')
                        array_end = param_description.index(')')
                        array = param_description[array_start+1:array_end].split(',')
                        # Use the last element of the array as the parameter description
                        param_description = array[-1].split(':')[-1].strip()
                    result += f"{param_description}:{param}, "
                result += "\n"
    return result


def translate_file(json_file, csv_file):
    mapping = load_mapping(csv_file)

    with open(json_file, 'r') as f:
        data = json.load(f)

    for event in data['events']:
        if event is not None:
            print(translate_event(event, mapping))

    with open(json_file, 'w') as f:
        json.dump(data, f)

# Specify the names of your files
json_file = 'Map002.json'
csv_file = 'mapping.csv'

# Specify the directory where your files are located
directory = r'i:/common/在00003/白花/白花/www/data'

# Generate the full paths to your files
json_path = os.path.join(directory, json_file)
csv_path = os.path.join(directory, csv_file)

# Call the function with the full paths to your files
translate_file(json_path, csv_path)

