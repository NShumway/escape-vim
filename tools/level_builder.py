#!/usr/bin/env python3
"""
Level Builder for Escape Vim
Generates maze.txt, meta.vim, and spies.vim from a YAML level definition + lore JSON.

All positions in YAML are 1-indexed to match Vim conventions.
Row 1 is the first row, column 1 is the first column.

Usage:
    python3 tools/level_builder.py levels/level03
    python3 tools/level_builder.py --all

Output:
    levels/level03/maze.txt
    levels/level03/meta.vim (level metadata, generated from YAML + lore JSON)
    levels/level03/spies.vim (spy patrol data, loaded separately from meta.vim)
    levels/manifest.vim (when using --all)
"""

import sys
import argparse
import yaml
import json
from pathlib import Path
from typing import List, Tuple, Dict, Any, Optional

WALL_CHAR = '█'
FLOOR_CHAR = ' '
DIVIDER_CHAR = '─'
EXIT_CHAR = '*'


def generate_maze(config: Dict[str, Any]) -> List[str]:
    """Generate the maze grid from config.

    All positions in config are 1-indexed. We convert to 0-indexed for grid access.
    """
    rows = config['dimensions'][0]
    cols = config['dimensions'][1]

    # Start with all floors
    grid = [[FLOOR_CHAR for _ in range(cols)] for _ in range(rows)]

    # Draw outer border (grid is 0-indexed internally)
    for c in range(cols):
        grid[0][c] = WALL_CHAR
        grid[rows-1][c] = WALL_CHAR
    for r in range(rows):
        grid[r][0] = WALL_CHAR
        grid[r][cols-1] = WALL_CHAR

    # Draw walls from config (convert 1-indexed to 0-indexed)
    for wall in config.get('walls', []):
        if wall['type'] == 'rect':
            # Rectangular room/wall - [top, left, height, width] all 1-indexed
            top, left, height, width = wall['rect']
            top -= 1  # Convert to 0-indexed
            left -= 1
            for r in range(top, top + height):
                for c in range(left, left + width):
                    if 0 <= r < rows and 0 <= c < cols:
                        grid[r][c] = WALL_CHAR

        elif wall['type'] == 'hline':
            # Horizontal line - [row, col_start, col_end] all 1-indexed
            row, col_start, col_end = wall['line']
            row -= 1  # Convert to 0-indexed
            col_start -= 1
            col_end -= 1
            for c in range(col_start, col_end + 1):
                if 0 <= row < rows and 0 <= c < cols:
                    grid[row][c] = WALL_CHAR

        elif wall['type'] == 'vline':
            # Vertical line - [col, row_start, row_end] all 1-indexed
            col, row_start, row_end = wall['line']
            col -= 1  # Convert to 0-indexed
            row_start -= 1
            row_end -= 1
            for r in range(row_start, row_end + 1):
                if 0 <= r < rows and 0 <= col < cols:
                    grid[r][col] = WALL_CHAR

    # Carve out openings/doors (convert 1-indexed to 0-indexed)
    for opening in config.get('openings', []):
        if opening['type'] == 'hline':
            row, col_start, col_end = opening['line']
            row -= 1
            col_start -= 1
            col_end -= 1
            for c in range(col_start, col_end + 1):
                if 0 <= row < rows and 0 <= c < cols:
                    grid[row][c] = FLOOR_CHAR
        elif opening['type'] == 'vline':
            col, row_start, row_end = opening['line']
            col -= 1
            row_start -= 1
            row_end -= 1
            for r in range(row_start, row_end + 1):
                if 0 <= r < rows and 0 <= col < cols:
                    grid[r][col] = FLOOR_CHAR
        elif opening['type'] == 'point':
            row, col = opening['pos']
            row -= 1
            col -= 1
            if 0 <= row < rows and 0 <= col < cols:
                grid[row][col] = FLOOR_CHAR

    # Place the exit marker (Q) in the maze (convert 1-indexed to 0-indexed)
    exit_pos = config.get('exit')
    if exit_pos:
        exit_row, exit_col = exit_pos
        exit_row -= 1
        exit_col -= 1
        if 0 <= exit_row < rows and 0 <= exit_col < cols:
            grid[exit_row][exit_col] = 'Q'

    return [''.join(row) for row in grid]


def generate_editing_document(config: Dict[str, Any]) -> Tuple[List[str], Dict[str, Any]]:
    """Generate the document for an editing level.

    Returns tuple of (document_lines, region_info) where region_info contains
    editable_region bounds and other metadata for meta.vim.
    """
    target_text = config.get('target_text', '').rstrip('\n')
    initial_text = config.get('initial_text', '').rstrip('\n')

    target_lines = target_text.split('\n')
    initial_lines = initial_text.split('\n')

    # Ensure same number of lines
    max_lines = max(len(target_lines), len(initial_lines))
    while len(target_lines) < max_lines:
        target_lines.append('')
    while len(initial_lines) < max_lines:
        initial_lines.append('')

    # Calculate widths
    # Label prefix for target section
    label_prefix = "Target:  "
    label_width = len(label_prefix)

    # Find max width needed
    max_target_width = max(len(line) for line in target_lines) if target_lines else 0
    max_initial_width = max(len(line) for line in initial_lines) if initial_lines else 0
    content_width = max(max_target_width, max_initial_width)

    # Exit tile position config
    exit_config = config.get('exit', 'right')

    # Build document lines
    document = []

    # Target section (read-only reference)
    for i, line in enumerate(target_lines):
        if i == 0:
            # First line has "Target:  " prefix
            padded = line.ljust(content_width)
            document.append(f"{label_prefix}{padded}")
        else:
            # Subsequent lines align with first
            padded = line.ljust(content_width)
            document.append(f"{' ' * label_width}{padded}")

    # Divider line
    divider_width = label_width + content_width + 3  # +3 for exit tile area
    divider_line = DIVIDER_CHAR * divider_width
    document.append(divider_line)
    divider_line_num = len(document)  # 1-indexed

    # Editable section
    editable_start_line = len(document) + 1  # 1-indexed
    editable_start_col = label_width + 1  # 1-indexed, after the label-width padding

    for i, line in enumerate(initial_lines):
        # Pad to align with target section
        padded = line.ljust(content_width)

        # Add space for exit tile at end of last line (highlight shows the exit, not a character)
        if i == len(initial_lines) - 1:
            document.append(f"{' ' * label_width}{padded} ")
        else:
            document.append(f"{' ' * label_width}{padded}")

    editable_end_line = len(document)  # 1-indexed
    editable_end_col = label_width + content_width  # 1-indexed

    # Calculate exit position (1-indexed)
    exit_line = editable_end_line
    exit_col = label_width + content_width + 1  # Position of EXIT_CHAR

    # Region info for meta.vim
    region_info = {
        'editable_region': {
            'start_line': editable_start_line,
            'end_line': editable_end_line,
            'start_col': editable_start_col,
            'end_col': editable_end_col,
        },
        'divider_line': divider_line_num,
        'exit_cursor': [exit_line, exit_col],
        'dimensions': [len(document), divider_width],
    }

    return document, region_info


def generate_patrol_route(spy_config: Dict[str, Any]) -> List[Dict[str, Any]]:
    """Generate patrol route vectors from spy config."""
    pattern = spy_config['pattern']

    if pattern == 'horizontal':
        # Back-and-forth horizontal movement
        start = spy_config['endpoints'][0]
        end = spy_config['endpoints'][1]

        # Determine direction
        if end[1] > start[1]:
            return [
                {'end': list(end), 'dir': 'right'},
                {'end': list(start), 'dir': 'left'},
            ]
        else:
            return [
                {'end': list(end), 'dir': 'left'},
                {'end': list(start), 'dir': 'right'},
            ]

    elif pattern == 'vertical':
        # Back-and-forth vertical movement
        start = spy_config['endpoints'][0]
        end = spy_config['endpoints'][1]

        if end[0] > start[0]:
            return [
                {'end': list(end), 'dir': 'down'},
                {'end': list(start), 'dir': 'up'},
            ]
        else:
            return [
                {'end': list(end), 'dir': 'up'},
                {'end': list(start), 'dir': 'down'},
            ]

    elif pattern == 'loop':
        # Box/loop patrol
        waypoints = spy_config['waypoints']
        direction = spy_config.get('direction', 'cw')

        if direction == 'ccw':
            waypoints = list(reversed(waypoints))

        route = []
        for i in range(len(waypoints)):
            current = waypoints[i]
            next_wp = waypoints[(i + 1) % len(waypoints)]

            # Determine direction
            if next_wp[0] < current[0]:
                dir_name = 'up'
            elif next_wp[0] > current[0]:
                dir_name = 'down'
            elif next_wp[1] < current[1]:
                dir_name = 'left'
            else:
                dir_name = 'right'

            route.append({'end': list(next_wp), 'dir': dir_name})

        return route

    else:
        raise ValueError(f"Unknown pattern: {pattern}")


def get_spawn_pos(spy_config: Dict[str, Any]) -> List[int]:
    """Get spawn position for a spy."""
    if 'spawn' in spy_config:
        return list(spy_config['spawn'])

    pattern = spy_config['pattern']
    if pattern in ('horizontal', 'vertical'):
        return list(spy_config['endpoints'][0])
    elif pattern == 'loop':
        return list(spy_config['waypoints'][0])

    raise ValueError("Cannot determine spawn position")


def validate_route(maze: List[str], spawn: List[int], route: List[Dict], spy_id: str) -> List[str]:
    """Validate that a patrol route doesn't hit walls.

    spawn and route positions are 1-indexed. We convert to 0-indexed for maze access.
    """
    errors = []
    rows = len(maze)
    cols = len(maze[0]) if maze else 0

    # Convert 1-indexed spawn to 0-indexed for validation
    pos = [spawn[0] - 1, spawn[1] - 1]
    spawn_0 = list(pos)

    # Check spawn
    if not (0 <= pos[0] < rows and 0 <= pos[1] < cols):
        errors.append(f"{spy_id}: Spawn {spawn} out of bounds")
    elif maze[pos[0]][pos[1]] == WALL_CHAR:
        errors.append(f"{spy_id}: Spawn {spawn} is inside a wall")

    # Walk the route (convert 1-indexed targets to 0-indexed)
    for i, vector in enumerate(route):
        target = [vector['end'][0] - 1, vector['end'][1] - 1]
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

            if not (0 <= pos[0] < rows and 0 <= pos[1] < cols):
                errors.append(f"{spy_id}: Route goes out of bounds at [{pos[0]+1}, {pos[1]+1}]")
                break
            elif maze[pos[0]][pos[1]] == WALL_CHAR:
                errors.append(f"{spy_id}: Route hits wall at [{pos[0]+1}, {pos[1]+1}]")
                break

    # Check route loops back
    if pos != spawn_0:
        errors.append(f"{spy_id}: Route ends at [{pos[0]+1}, {pos[1]+1}], not spawn {spawn}")

    return errors


def generate_spies_vim(spies_config: List[Dict[str, Any]], maze: List[str]) -> Tuple[str, List[str]]:
    """Generate a standalone spies.vim file with spy patrol data."""
    all_errors = []
    spies_data = []

    for spy in spies_config:
        spy_id = spy['id']
        spawn = get_spawn_pos(spy)
        route = generate_patrol_route(spy)
        speed = spy.get('speed', 1.0)

        # Validate
        errors = validate_route(maze, spawn, route, spy_id)
        all_errors.extend(errors)

        spies_data.append({
            'id': spy_id,
            'spawn': spawn,
            'route': route,
            'speed': speed,
        })

    # Format as JSON-like structure that Vim can eval directly
    # Single line per spy for simplicity
    lines = [
        '" Spy patrol data for this level',
        '" Generated by tools/level_builder.py - do not edit manually',
        '" Format: Vim list - use eval(join(readfile(...), "")) to parse',
    ]

    # Build the list as a single evaluable expression with line continuations
    # Vim's eval() handles line continuations when the lines are joined
    list_parts = ['[']
    for i, spy in enumerate(spies_data):
        comma = ',' if i < len(spies_data) - 1 else ''
        # Format route vectors
        route_strs = []
        for vec in spy['route']:
            route_strs.append(f"{{'end': {vec['end']}, 'dir': '{vec['dir']}'}}")
        route_str = '[' + ', '.join(route_strs) + ']'

        spy_str = (f"{{'id': '{spy['id']}', "
                   f"'spawn': {spy['spawn']}, "
                   f"'route': {route_str}, "
                   f"'speed': {spy['speed']}}}{comma}")
        list_parts.append(spy_str)
    list_parts.append(']')

    # Join as single line for eval
    lines.append(''.join(list_parts))

    return '\n'.join(lines), all_errors


def load_lore_json(level_dir: Path, level_id: int) -> Dict[str, Any]:
    """Load lore JSON for a level.

    Looks for levels/lore/levelXX.json where XX is zero-padded level ID.
    """
    # Find project root (parent of level dir's parent)
    levels_dir = level_dir.parent
    lore_path = levels_dir / 'lore' / f'level{level_id:02d}.json'

    if not lore_path.exists():
        print(f"Warning: Lore file not found: {lore_path}")
        return {}

    with open(lore_path) as f:
        return json.load(f)


def escape_vim_single_quoted(s: str) -> str:
    """Escape a string for use in a Vim single-quoted string.

    In Vim single-quoted strings, the only escape is '' for a literal '.
    """
    if s is None:
        return ''
    return s.replace("'", "''")


def escape_vim_double_quoted(s: str) -> str:
    """Escape a string for use in a Vim double-quoted string.

    Double-quoted strings support escape sequences like \n, \t, \\, \"
    """
    if s is None:
        return ''
    # Escape backslashes first, then quotes, then convert newlines
    s = s.replace('\\', '\\\\')
    s = s.replace('"', '\\"')
    s = s.replace('\n', '\\n')
    return s


def format_vim_value(value: Any, indent: int = 0) -> str:
    """Format a Python value as a Vim literal.

    Handles: None -> v:null, strings, numbers, lists, dicts
    Uses double-quoted strings for values with newlines (so \\n works).
    """
    if value is None:
        return 'v:null'
    elif isinstance(value, bool):
        return 'v:true' if value else 'v:false'
    elif isinstance(value, (int, float)):
        return str(value)
    elif isinstance(value, str):
        # Use double quotes if string contains newlines (so \n escape works)
        # Otherwise use single quotes (simpler, no escapes needed except '')
        if '\n' in value:
            return f'"{escape_vim_double_quoted(value)}"'
        else:
            return f"'{escape_vim_single_quoted(value)}'"
    elif isinstance(value, list):
        if not value:
            return '[]'
        # Format list items
        items = [format_vim_value(item, indent + 2) for item in value]
        # Check if all items are simple (no newlines needed)
        if all(isinstance(v, (int, float, bool)) or (isinstance(v, str) and len(v) < 40 and '\n' not in v) for v in value):
            return '[' + ', '.join(items) + ']'
        else:
            # Multi-line format
            inner_indent = ' ' * (indent + 2)
            formatted_items = [f"{inner_indent}{item}," for item in items]
            return '[\n' + '\n'.join(formatted_items) + '\n' + ' ' * indent + ']'
    elif isinstance(value, dict):
        if not value:
            return '{}'
        # Format dict items
        items = []
        for k, v in value.items():
            formatted_v = format_vim_value(v, indent + 2)
            items.append(f"'{k}': {formatted_v}")
        # Check if simple dict
        total_len = sum(len(item) for item in items)
        if total_len < 60 and all('\n' not in item for item in items):
            return '{' + ', '.join(items) + '}'
        else:
            inner_indent = ' ' * (indent + 2)
            formatted_items = [f"{inner_indent}{item}," for item in items]
            return '{\n' + '\n'.join(formatted_items) + '\n' + ' ' * indent + '}'
    else:
        raise ValueError(f"Cannot format value of type {type(value)}: {value}")


def generate_meta_vim(config: Dict[str, Any], lore: Dict[str, Any], editing_info: Optional[Dict[str, Any]] = None) -> str:
    """Generate meta.vim content from YAML config and lore JSON.

    Merges:
    - From YAML: dimensions, start, exit, viewport, commands, blocked_categories, features
    - From lore JSON: title, description, objective, quote, victory_quote, lore
    - For editing levels: editable_region, target_text, divider_line from editing_info
    """
    # Build the meta dictionary
    meta = {}

    # Level type
    level_type = config.get('type', 'maze')
    meta['type'] = level_type

    # From lore JSON
    meta['title'] = lore.get('title', 'Untitled Level')
    meta['description'] = lore.get('description', '')
    meta['objective'] = lore.get('objective', '')

    # Commands from YAML
    commands = config.get('commands', [])
    meta['commands'] = commands

    # Quote from lore
    meta['quote'] = lore.get('quote', '')
    meta['victory_quote'] = lore.get('victory_quote', '')

    # For editing levels, use info from editing_info; for maze levels, use config
    if level_type == 'editing' and editing_info:
        # Cursor positions from editing document generator
        start = config.get('start', [editing_info['editable_region']['start_line'],
                                      editing_info['editable_region']['start_col']])
        meta['start_cursor'] = start
        meta['exit_cursor'] = editing_info['exit_cursor']

        # Document dimensions
        dims = editing_info['dimensions']
        meta['maze'] = {'lines': dims[0], 'cols': dims[1]}
        meta['viewport'] = {'lines': dims[0], 'cols': dims[1]}

        # Editing-specific metadata
        meta['editable_region'] = editing_info['editable_region']
        meta['divider_line'] = editing_info['divider_line']
        meta['target_text'] = config.get('target_text', '').rstrip('\n')
    else:
        # Cursor positions (convert from 1-indexed YAML to Vim 1-indexed format)
        # YAML uses [row, col], Vim expects [line, col] which is the same
        start = config.get('start', [1, 1])
        exit_pos = config.get('exit', [1, 1])
        meta['start_cursor'] = start
        meta['exit_cursor'] = exit_pos

        # Maze dimensions
        dims = config.get('dimensions', [25, 80])
        meta['maze'] = {'lines': dims[0], 'cols': dims[1]}

        # Viewport - defaults to maze dimensions if not specified
        viewport = config.get('viewport', dims)
        meta['viewport'] = {'lines': viewport[0], 'cols': viewport[1]}

    # Blocked categories
    meta['blocked_categories'] = config.get('blocked_categories', [])

    # Features
    meta['features'] = config.get('features', [])

    # Time/keystroke limits
    meta['time_limit_seconds'] = config.get('time_limit_seconds', None)
    meta['max_keystrokes'] = config.get('max_keystrokes', None)

    # Note: 'lore' is NOT included in meta.vim - it's read directly from lore JSON

    # Generate Vim script content
    # Note: No comment line - Vim's eval() can't parse comments
    lines = ['{']

    # Format each key in a consistent order
    # Note: 'lore' deliberately excluded - read from JSON by lore.vim
    key_order = [
        'type', 'title', 'description', 'objective', 'commands', 'quote', 'victory_quote',
        'start_cursor', 'exit_cursor', 'maze', 'viewport', 'blocked_categories',
        'features', 'time_limit_seconds', 'max_keystrokes',
        'editable_region', 'divider_line', 'target_text'
    ]

    # Build list of formatted items
    items = []
    for key in key_order:
        if key in meta:
            value = meta[key]
            formatted = format_vim_value(value, 2)
            items.append(f"  '{key}': {formatted}")

    # Join with commas (no trailing comma - Vim's eval() doesn't allow it)
    lines.extend([item + ',' for item in items[:-1]])
    if items:
        lines.append(items[-1])  # Last item without comma

    lines.append('}')

    return '\n'.join(lines)


def scan_levels(levels_dir: Path) -> List[Dict[str, Any]]:
    """Scan all levels and return manifest entries.

    Sources (in priority order):
    1. Levels with level.yaml - uses id from YAML, title from lore JSON
    2. Lore JSON files - extracts level id from filename, title from JSON
    """
    entries = {}

    # First, scan lore JSON files for levels without level.yaml
    lore_dir = levels_dir / 'lore'
    if lore_dir.exists():
        for lore_path in sorted(lore_dir.glob('level*.json')):
            # Extract level ID from filename (e.g., level01.json -> 1)
            try:
                level_id = int(lore_path.stem.replace('level', ''))
            except ValueError:
                continue

            # Check if level directory exists
            level_dir_name = f'level{level_id:02d}'
            level_dir = levels_dir / level_dir_name
            if not level_dir.exists():
                continue

            # Load lore for title
            with open(lore_path) as f:
                lore = json.load(f)

            entries[level_id] = {
                'id': level_id,
                'dir': level_dir_name,
                'title': lore.get('title', f'Level {level_id}'),
            }

    # Then, scan for levels with level.yaml (these take priority)
    for level_path in sorted(levels_dir.glob('level*/level.yaml')):
        level_dir = level_path.parent
        with open(level_path) as f:
            config = yaml.safe_load(f)

        level_id = config.get('id')
        if level_id is None:
            print(f"Warning: {level_path} missing 'id' field, skipping")
            continue

        # Get title from lore JSON
        lore = load_lore_json(level_dir, level_id)
        title = lore.get('title', f'Level {level_id}')

        # Update/add entry (overwrites lore-only entry if exists)
        entries[level_id] = {
            'id': level_id,
            'dir': level_dir.name,
            'title': title,
        }

    # Sort by ID and return as list
    return [entries[k] for k in sorted(entries.keys())]


def generate_manifest_vim(entries: List[Dict[str, Any]]) -> str:
    """Generate manifest.vim content.

    Note: No comment lines - the file is eval'd directly by Vim.
    """
    lines = ['[']

    for entry in entries:
        lines.append(f"  {{'id': {entry['id']}, 'dir': '{entry['dir']}', 'title': '{escape_vim_single_quoted(entry['title'])}'}},")

    lines.append(']')
    return '\n'.join(lines)


def build_level(level_dir: Path) -> bool:
    """Build a single level. Returns True on success."""
    yaml_path = level_dir / 'level.yaml'

    if not yaml_path.exists():
        print(f"Error: {yaml_path} not found")
        return False

    with open(yaml_path) as f:
        config = yaml.safe_load(f)

    # Get level ID for lore lookup
    level_id = config.get('id')
    if level_id is None:
        print(f"Error: {yaml_path} missing 'id' field")
        return False

    # Load lore
    lore = load_lore_json(level_dir, level_id)

    # Determine level type
    level_type = config.get('type', 'maze')
    errors = []

    # Output paths
    maze_path = level_dir / 'maze.txt'
    meta_path = level_dir / 'meta.vim'
    spies_path = level_dir / 'spies.vim'

    if level_type == 'editing':
        # Generate editing document
        document, editing_info = generate_editing_document(config)

        # Generate meta.vim with editing info
        meta_vim = generate_meta_vim(config, lore, editing_info)

        # Write document as maze.txt (reusing the filename for consistency)
        with open(maze_path, 'w') as f:
            f.write('\n'.join(document))
        print(f"Written: {maze_path}")

        # Write meta.vim
        with open(meta_path, 'w') as f:
            f.write(meta_vim)
        print(f"Written: {meta_path}")

        # Generate spies if defined (for level 8)
        if config.get('spies'):
            spies_vim, spy_errors = generate_spies_vim(config.get('spies', []), document)
            errors.extend(spy_errors)
            with open(spies_path, 'w') as f:
                f.write(spies_vim)
            print(f"Written: {spies_path}")

        # Print summary
        print(f"\n=== Summary (Editing Level) ===")
        print(f"Level ID: {level_id}")
        print(f"Title: {lore.get('title', 'Unknown')}")
        print(f"Type: {level_type}")
        print(f"Dimensions: {editing_info['dimensions'][0]} rows x {editing_info['dimensions'][1]} cols")
        print(f"Editable region: lines {editing_info['editable_region']['start_line']}-{editing_info['editable_region']['end_line']}")
        print(f"Exit: {editing_info['exit_cursor']}")
        print(f"Features: {config.get('features', [])}")
        print(f"Spies: {len(config.get('spies', []))}")

        # Show document preview
        print("\n=== Document Preview ===\n")
        for line in document:
            print(line)
        print()

    else:
        # Standard maze level
        maze = generate_maze(config)

        # Generate meta.vim
        meta_vim = generate_meta_vim(config, lore)

        # Generate and validate spies
        spies_vim, spy_errors = generate_spies_vim(config.get('spies', []), maze)
        errors.extend(spy_errors)

        # Write maze
        with open(maze_path, 'w') as f:
            f.write('\n'.join(maze))
        print(f"Written: {maze_path}")

        # Write meta.vim
        with open(meta_path, 'w') as f:
            f.write(meta_vim)
        print(f"Written: {meta_path}")

        # Write spies.vim if there are spies
        if config.get('spies'):
            with open(spies_path, 'w') as f:
                f.write(spies_vim)
            print(f"Written: {spies_path}")
        else:
            print(f"No spies defined, skipping {spies_path}")

        # Print summary
        print(f"\n=== Summary ===")
        print(f"Level ID: {level_id}")
        print(f"Title: {lore.get('title', 'Unknown')}")
        print(f"Type: {level_type}")
        print(f"Dimensions: {config['dimensions'][0]} rows x {config['dimensions'][1]} cols")
        print(f"Start: {config.get('start', 'not set')}")
        print(f"Exit: {config.get('exit', 'not set')}")
        print(f"Features: {config.get('features', [])}")
        print(f"Spies: {len(config.get('spies', []))}")

        # Show preview
        print_preview(maze, config)

    if errors:
        print("VALIDATION ERRORS:")
        for err in errors:
            print(f"  - {err}")
        print(f"\n⚠️  {len(errors)} validation error(s) found!")
        return False
    else:
        print(f"\n✓ All validations passed")
        return True


def print_preview(maze: List[str], config: Dict[str, Any]) -> None:
    """Print maze with S, Q, and spy positions marked."""
    # Copy maze for preview
    grid = [list(row) for row in maze]
    rows = len(grid)
    cols = len(grid[0]) if grid else 0

    # Mark start
    start = config.get('start', [0, 0])
    if 0 <= start[0] < rows and 0 <= start[1] < cols:
        grid[start[0]][start[1]] = 'S'

    # Mark exit
    exit_pos = config.get('exit', [0, 0])
    if 0 <= exit_pos[0] < rows and 0 <= exit_pos[1] < cols:
        grid[exit_pos[0]][exit_pos[1]] = 'Q'

    # Mark spy spawn positions
    for i, spy in enumerate(config.get('spies', [])):
        spawn = get_spawn_pos(spy)
        if 0 <= spawn[0] < rows and 0 <= spawn[1] < cols:
            # Use numbers 1-9, then letters
            marker = str(i + 1) if i < 9 else chr(ord('A') + i - 9)
            grid[spawn[0]][spawn[1]] = marker

    print("\n=== PREVIEW (S=start, Q=exit, 1-9=spy spawns) ===\n")
    for row in grid:
        print(''.join(row))
    print()


def main():
    parser = argparse.ArgumentParser(
        description='Level Builder for Escape Vim',
        epilog="""
Examples:
    python3 tools/level_builder.py levels/level03
    python3 tools/level_builder.py --all
    python3 tools/level_builder.py --all --manifest-only
        """
    )
    parser.add_argument('level_dir', nargs='?', help='Level directory (e.g., levels/level03)')
    parser.add_argument('--all', action='store_true', help='Build all levels and generate manifest')
    parser.add_argument('--manifest-only', action='store_true', help='Only generate manifest (use with --all)')

    args = parser.parse_args()

    if not args.level_dir and not args.all:
        parser.print_help()
        print("\nExample YAML format:")
        print("""
id: 3
features: ['spies']
dimensions: [25, 80]
start: [2, 2]
exit: [23, 78]
viewport: [25, 80]

commands:
  - key: 'h'
    desc: 'move left'

blocked_categories:
  - arrows
  - search

walls:
  - type: rect
    rect: [5, 10, 8, 2]  # top, left, height, width
  - type: hline
    line: [10, 20, 40]   # row, col_start, col_end

openings:
  - type: point
    pos: [10, 25]

spies:
  - id: guard1
    pattern: horizontal
    endpoints: [[5, 20], [5, 60]]
    speed: 1.0
""")
        sys.exit(1)

    # Determine levels directory
    if args.level_dir:
        level_dir = Path(args.level_dir)
        # Handle both "levels/level03" and "levels/level03/level.yaml"
        if level_dir.suffix == '.yaml':
            level_dir = level_dir.parent
        levels_dir = level_dir.parent
    else:
        # Find levels directory from cwd
        levels_dir = Path('levels')
        if not levels_dir.exists():
            print("Error: 'levels' directory not found")
            sys.exit(1)

    success = True

    if args.all:
        if not args.manifest_only:
            # Build all levels
            print("=== Building all levels ===\n")
            for level_path in sorted(levels_dir.glob('level*/level.yaml')):
                level_dir = level_path.parent
                print(f"--- Building {level_dir.name} ---")
                if not build_level(level_dir):
                    success = False
                print()

        # Generate manifest
        print("=== Generating manifest ===")
        entries = scan_levels(levels_dir)
        if entries:
            manifest_content = generate_manifest_vim(entries)
            manifest_path = levels_dir / 'manifest.vim'
            with open(manifest_path, 'w') as f:
                f.write(manifest_content)
            print(f"Written: {manifest_path}")
            print(f"Found {len(entries)} levels")
        else:
            print("No levels found with valid 'id' field")
            success = False
    else:
        # Build single level
        success = build_level(level_dir)

    sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()
