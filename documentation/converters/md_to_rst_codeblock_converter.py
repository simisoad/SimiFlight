import re
from pathlib import Path

def convert_code_blocks(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    new_lines = []
    inside_code_block = False
    language = ''

    for line in lines:
        match_start = re.match(r'^```(\w+)', line.strip())
        if match_start:
            language = match_start.group(1)
            new_lines.append(f".. code-block:: {language}\n\n")
            inside_code_block = True
            continue

        if line.strip() == '```' and inside_code_block:
            new_lines.append("\n")
            inside_code_block = False
            continue

        if inside_code_block:
            new_lines.append("   " + line)
        else:
            new_lines.append(line)

    with open(file_path, 'w', encoding='utf-8') as f:
        f.writelines(new_lines)

    print(f"✔ Codeblöcke konvertiert in: {file_path}")

def convert_directory(path):
    path = Path(path)
    for file in path.glob('**/*.rst'):
        convert_code_blocks(file)

# Beispiel:
convert_directory("../source")
