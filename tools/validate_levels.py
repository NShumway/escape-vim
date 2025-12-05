#!/usr/bin/env python3
"""
Level Validation for Escape Vim
Validates level definitions at build time.

IMPORTANT: Maze dimensions are measured in CHARACTERS (Unicode code points),
not bytes. The wall character █ is 3 bytes in UTF-8 but counts as 1 character.
All position references (start_cursor, exit_cursor, spy positions) use
1-indexed character positions.

Usage:
    python3 tools/validate_levels.py [level_path...]

    # Validate all levels:
    python3 tools/validate_levels.py

    # Validate specific level:
    python3 tools/validate_levels.py levels/level01
"""

import sys
import re
from pathlib import Path
from typing import List, Dict, Any, Tuple

WALL_CHAR = '█'


def parse_vim_dict(content: str) -> Dict[str, Any]:
    """Parse a Vim dictionary literal into Python dict.

    Handles basic Vim syntax:
    - 'string' and "string" both valid
    - v:null -> None
    - v:true -> True
    - v:false -> False
    - Multiline strings with \n
    - Line continuation with \\ at start of line
    """
    # Join continuation lines (lines starting with \ after leading whitespace)
    lines = content.split('\n')
    joined_lines = []
    for line in lines:
        stripped = line.lstrip()
        if stripped.startswith('\\'):
            # Continuation line - append without the backslash
            if joined_lines:
                joined_lines[-1] += ' ' + stripped[1:].lstrip()
            else:
                joined_lines.append(stripped[1:].lstrip())
        else:
            joined_lines.append(line)
    content = '\n'.join(joined_lines)

    # Replace Vim-specific values
    content = content.replace("v:null", "None")
    content = content.replace("v:true", "True")
    content = content.replace("v:false", "False")

    # Convert Vim string literals to Python
    # Vim supports both 'single' and "double" quoted strings
    # Single quotes: '' is escaped quote, no other escapes
    # Double quotes: standard escapes like \n, \t, \"
    result = []
    i = 0
    while i < len(content):
        if content[i] == "'":
            # Vim single-quoted string: '' for literal quote, no other escapes
            j = i + 1
            inner_chars = []
            while j < len(content):
                if content[j] == "'":
                    if j + 1 < len(content) and content[j + 1] == "'":
                        inner_chars.append("'")
                        j += 2
                    else:
                        break
                else:
                    inner_chars.append(content[j])
                    j += 1
            inner = ''.join(inner_chars)
            # Escape for Python double-quoted string
            inner = inner.replace('\\', '\\\\')
            inner = inner.replace('"', '\\"')
            result.append('"' + inner + '"')
            i = j + 1
        elif content[i] == '"':
            # Vim double-quoted string: supports \n, \t, \", etc.
            # These are already valid Python escapes, so just pass through
            j = i + 1
            while j < len(content):
                if content[j] == '"' and content[j-1] != '\\':
                    break
                j += 1
            # Include the quotes
            result.append(content[i:j+1])
            i = j + 1
        else:
            result.append(content[i])
            i += 1

    content = ''.join(result)

    # Use eval to parse (safe for our controlled input)
    return eval(content)


def measure_maze(maze_path: Path) -> Tuple[int, int]:
    """Measure maze dimensions in characters.

    Returns (rows, max_cols) where cols is the maximum line width.
    """
    with open(maze_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    rows = len(lines)
    max_cols = max(len(line.rstrip('\n')) for line in lines) if lines else 0

    return rows, max_cols


def get_char_at(maze_lines: List[str], line: int, col: int) -> str:
    """Get character at 1-indexed position."""
    if line < 1 or line > len(maze_lines):
        return ''
    row = maze_lines[line - 1].rstrip('\n')
    if col < 1 or col > len(row):
        return ''
    return row[col - 1]


def validate_level(level_path: Path) -> List[str]:
    """Validate a single level.

    Returns list of error strings (empty = valid).
    """
    errors = []
    prefix = str(level_path)

    # Load metadata
    meta_path = level_path / 'meta.vim'
    if not meta_path.exists():
        errors.append(f"{prefix}: meta.vim not found")
        return errors

    try:
        meta = parse_vim_dict(meta_path.read_text(encoding='utf-8'))
    except Exception as e:
        errors.append(f"{prefix}: failed to parse meta.vim: {e}")
        return errors

    # Load maze
    maze_path = level_path / 'maze.txt'
    if not maze_path.exists():
        errors.append(f"{prefix}: maze.txt not found")
        return errors

    with open(maze_path, 'r', encoding='utf-8') as f:
        maze_lines = f.readlines()

    # Measure actual maze dimensions
    actual_rows, actual_cols = measure_maze(maze_path)

    # 1. Validate maze dimensions match metadata
    if 'maze' not in meta:
        errors.append(f"{prefix}: missing 'maze' in metadata")
    else:
        maze_meta = meta['maze']
        expected_rows = maze_meta.get('lines', 0)
        expected_cols = maze_meta.get('cols', 0)

        if expected_rows != actual_rows:
            errors.append(f"{prefix}: maze.lines mismatch - meta says {expected_rows}, actual is {actual_rows}")
        if expected_cols != actual_cols:
            errors.append(f"{prefix}: maze.cols mismatch - meta says {expected_cols}, actual is {actual_cols}")

    # 2. Validate bounds (start/exit inside maze and not on walls)
    if 'start_cursor' in meta:
        line, col = meta['start_cursor']
        if line < 1 or line > actual_rows:
            errors.append(f"{prefix}: start_cursor line {line} out of bounds (1-{actual_rows})")
        elif col < 1 or col > actual_cols:
            errors.append(f"{prefix}: start_cursor col {col} out of bounds (1-{actual_cols})")
        else:
            char = get_char_at(maze_lines, line, col)
            if char == WALL_CHAR:
                errors.append(f"{prefix}: start_cursor [{line}, {col}] is on a wall")
    else:
        errors.append(f"{prefix}: missing start_cursor")

    if 'exit_cursor' in meta:
        line, col = meta['exit_cursor']
        if line < 1 or line > actual_rows:
            errors.append(f"{prefix}: exit_cursor line {line} out of bounds (1-{actual_rows})")
        elif col < 1 or col > actual_cols:
            errors.append(f"{prefix}: exit_cursor col {col} out of bounds (1-{actual_cols})")
        else:
            char = get_char_at(maze_lines, line, col)
            if char == WALL_CHAR:
                errors.append(f"{prefix}: exit_cursor [{line}, {col}] is on a wall")
    else:
        errors.append(f"{prefix}: missing exit_cursor")

    # 3. Validate spies (if present)
    if 'spies' in meta:
        for spy in meta['spies']:
            spy_errors = validate_spy(prefix, spy, maze_lines, actual_rows, actual_cols)
            errors.extend(spy_errors)

    return errors


def validate_spy(prefix: str, spy: Dict[str, Any], maze_lines: List[str], rows: int, cols: int) -> List[str]:
    """Validate a spy definition."""
    errors = []
    spy_id = spy.get('id', 'unknown')
    spy_prefix = f"{prefix} spy '{spy_id}'"

    # Check spawn position
    if 'spawn' not in spy:
        errors.append(f"{spy_prefix}: missing spawn position")
        return errors

    spawn = spy['spawn']
    line, col = spawn

    if line < 1 or line > rows:
        errors.append(f"{spy_prefix}: spawn line {line} out of bounds (1-{rows})")
        return errors
    if col < 1 or col > cols:
        errors.append(f"{spy_prefix}: spawn col {col} out of bounds (1-{cols})")
        return errors

    char = get_char_at(maze_lines, line, col)
    if char == WALL_CHAR:
        errors.append(f"{spy_prefix}: spawn [{line}, {col}] is on a wall")

    # Check route
    if 'route' not in spy:
        errors.append(f"{spy_prefix}: missing route")
        return errors

    route = spy['route']
    if not route:
        errors.append(f"{spy_prefix}: empty route")
        return errors

    # Walk the route from spawn position
    pos = list(spawn)

    for i, vector in enumerate(route):
        target = vector['end']
        direction = vector['dir']

        # Walk step by step to target
        while pos != target:
            if direction == 'up':
                pos[0] -= 1
            elif direction == 'down':
                pos[0] += 1
            elif direction == 'left':
                pos[1] -= 1
            elif direction == 'right':
                pos[1] += 1
            else:
                errors.append(f"{spy_prefix}: invalid direction '{direction}'")
                return errors

            # Check bounds
            if pos[0] < 1 or pos[0] > rows or pos[1] < 1 or pos[1] > cols:
                errors.append(f"{spy_prefix}: route goes out of bounds at [{pos[0]}, {pos[1]}]")
                return errors

            # Check for wall
            char = get_char_at(maze_lines, pos[0], pos[1])
            if char == WALL_CHAR:
                errors.append(f"{spy_prefix}: route hits wall at [{pos[0]}, {pos[1]}]")
                return errors

    # Check route loops back to spawn
    if pos != list(spawn):
        errors.append(f"{spy_prefix}: route ends at [{pos[0]}, {pos[1]}] instead of spawn {spawn}")

    return errors


def validate_all() -> List[str]:
    """Validate all levels in the levels directory."""
    all_errors = []

    levels_dir = Path('levels')
    for level_dir in sorted(levels_dir.glob('level*')):
        if level_dir.is_dir():
            errors = validate_level(level_dir)
            all_errors.extend(errors)

    return all_errors


def main():
    if len(sys.argv) > 1:
        # Validate specific levels
        all_errors = []
        for path in sys.argv[1:]:
            level_path = Path(path)
            if level_path.exists():
                errors = validate_level(level_path)
                all_errors.extend(errors)
            else:
                all_errors.append(f"{path}: directory not found")
    else:
        # Validate all levels
        all_errors = validate_all()

    if all_errors:
        print("VALIDATION ERRORS:")
        for error in all_errors:
            print(f"  - {error}")
        sys.exit(1)
    else:
        print("✓ All levels valid")
        sys.exit(0)


if __name__ == '__main__':
    main()
