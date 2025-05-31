import re
from pathlib import Path

# Mapping of Markdown-like headers to reST underline styles
HEADER_STYLES = {
    '#': '=',
    '##': '-',
    '###': '^',
    '####': '~'
}

def convert_rst_headers(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    new_lines = []
    for line in lines:
        match = re.match(r'^(#{1,4})\s+(.*)', line)
        if match:
            level, title = match.groups()
            underline = HEADER_STYLES.get(level, '-') * len(title)
            new_lines.append(f'{title}\n{underline}\n\n')
        else:
            new_lines.append(line)

    with open(file_path, 'w', encoding='utf-8') as f:
        f.writelines(new_lines)

    print(f"Converted headers in {file_path}")

def convert_directory(path):
    path = Path(path)
    for file in path.glob('**/*.rst'):
        convert_rst_headers(file)

# Usage example:
# convert_directory("./source")
