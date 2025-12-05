#!/usr/bin/env python3
"""
Level Builder for Escape Vim
Generates maze.txt and spies.vim from a YAML level definition.

All positions in YAML are 1-indexed to match Vim conventions.
Row 1 is the first row, column 1 is the first column.

Usage:
    python3 tools/level_builder.py levels/level03/level.yaml

Output:
    levels/level03/maze.txt
    levels/level03/spies.vim (spy patrol data, loaded separately from meta.vim)
"""

import sys
import yaml
import json
from pathlib import Path
from typing import List, Tuple, Dict, Any

WALL_CHAR = '█'
FLOOR_CHAR = ' '


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
    if len(sys.argv) < 2:
        print("Usage: python3 tools/level_builder.py <level.yaml>")
        print("\nExample YAML format:")
        print("""
dimensions: [25, 80]
start: [2, 2]
exit: [23, 78]

walls:
  - type: rect
    rect: [5, 10, 8, 2]  # top, left, height, width
  - type: hline
    line: [10, 20, 40]   # row, col_start, col_end
  - type: vline
    line: [30, 5, 15]    # col, row_start, row_end

openings:
  - type: point
    pos: [10, 25]
  - type: hline
    line: [5, 30, 35]

spies:
  - id: guard1
    pattern: horizontal
    endpoints: [[5, 20], [5, 60]]
    speed: 1.0

  - id: patrol1
    pattern: loop
    waypoints: [[10, 10], [10, 30], [18, 30], [18, 10]]
    direction: cw
    speed: 0.8
""")
        sys.exit(1)

    yaml_path = Path(sys.argv[1])
    if not yaml_path.exists():
        print(f"Error: {yaml_path} not found")
        sys.exit(1)

    with open(yaml_path) as f:
        config = yaml.safe_load(f)

    # Generate maze
    maze = generate_maze(config)

    # Generate and validate spies
    spies_vim, errors = generate_spies_vim(config.get('spies', []), maze)

    if errors:
        print("VALIDATION ERRORS:")
        for err in errors:
            print(f"  - {err}")
        print()

    # Output paths
    level_dir = yaml_path.parent
    maze_path = level_dir / 'maze.txt'
    spies_path = level_dir / 'spies.vim'

    # Write maze
    with open(maze_path, 'w') as f:
        f.write('\n'.join(maze))
    print(f"Written: {maze_path}")

    # Write spies.vim if there are spies
    if config.get('spies'):
        with open(spies_path, 'w') as f:
            f.write(spies_vim)
        print(f"Written: {spies_path}")
    else:
        print(f"No spies defined, skipping {spies_path}")

    # Print summary
    print(f"=== Summary ===")
    print(f"Dimensions: {config['dimensions'][0]} rows x {config['dimensions'][1]} cols")
    print(f"Start: {config.get('start', 'not set')}")
    print(f"Exit: {config.get('exit', 'not set')}")
    print(f"Spies: {len(config.get('spies', []))}")

    if errors:
        print(f"\n⚠️  {len(errors)} validation error(s) found!")
        sys.exit(1)
    else:
        print(f"\n✓ All validations passed")

    # Show preview
    print_preview(maze, config)


if __name__ == '__main__':
    main()
