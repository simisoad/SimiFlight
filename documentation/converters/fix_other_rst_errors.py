import re
from pathlib import Path

def fix_rst_formatting(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    fixed_lines = []
    i = 0
    inside_code_block = False
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()

        # Fix incorrectly embedded Markdown code block
        if stripped.startswith('```'):
            language = stripped[3:].strip() or 'text'
            fixed_lines.append(f".. code-block:: {language}\n\n")
            i += 1
            while i < len(lines) and not lines[i].strip().startswith('```'):
                fixed_lines.append("   " + lines[i])
                i += 1
            fixed_lines.append("\n")  # Ensure newline after code block
            i += 1
            continue

        # Fix indented list items without blank line before
        if re.match(r'\s{2,}[\*\-\+] ', line) or re.match(r'\s{2,}\d+\. ', line):
            if fixed_lines and fixed_lines[-1].strip():
                fixed_lines.append("\n")
            fixed_lines.append(line.lstrip())
        else:
            fixed_lines.append(line)

        i += 1

    with open(file_path, 'w', encoding='utf-8') as f:
        f.writelines(fixed_lines)

    print(f"✔ Bereinigt: {file_path}")

def fix_directory(path):
    path = Path(path)
    for file in path.glob('**/*.rst'):
        fix_rst_formatting(file)

# Beispiel:
fix_directory("../source")
