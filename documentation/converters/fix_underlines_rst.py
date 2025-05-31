import re
from pathlib import Path

def fix_rst_headers(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    new_lines = []
    i = 0
    changes_made = False

    while i < len(lines) - 1:
        title_line = lines[i].rstrip('\n')
        underline_line = lines[i + 1].rstrip('\n')

        if re.fullmatch(r'[=\-^~"+*#`:.><]{3,}', underline_line):
            if len(underline_line) < len(title_line):
                underline_char = underline_line[0]
                new_lines.append(f"{title_line}\n")
                new_lines.append(f"{underline_char * len(title_line)}\n")
                changes_made = True
                i += 2
                continue
        new_lines.append(lines[i])
        i += 1

    # Add last line if missed
    while i < len(lines):
        new_lines.append(lines[i])
        i += 1

    if changes_made:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.writelines(new_lines)
        print(f"✔ Gefixt: {file_path}")


def fix_directory(path):
    path = Path(path)
    for file in path.glob('**/*.rst'):
        fix_rst_headers(file)

# Beispiel:
fix_directory("../source")
