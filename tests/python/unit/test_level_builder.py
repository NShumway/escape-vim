"""Unit tests for tools/level_builder.py."""

import pytest
import sys
from pathlib import Path

# Add tools to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent.parent / "tools"))

from level_builder import (
    generate_maze,
    generate_patrol_route,
    get_spawn_pos,
    validate_route,
    generate_spies_vim,
    escape_vim_single_quoted,
    escape_vim_double_quoted,
    format_vim_value,
    generate_meta_vim,
    generate_manifest_vim,
    scan_levels,
    WALL_CHAR,
    FLOOR_CHAR,
)


class TestGenerateMaze:
    """Tests for maze generation from YAML config."""

    def test_basic_dimensions(self):
        """Maze has correct dimensions."""
        config = {
            'dimensions': [5, 10],
            'walls': [],
            'openings': [],
        }
        maze = generate_maze(config)
        assert len(maze) == 5
        assert all(len(row) == 10 for row in maze)

    def test_outer_border(self):
        """Maze has wall border."""
        config = {
            'dimensions': [5, 10],
            'walls': [],
            'openings': [],
        }
        maze = generate_maze(config)
        # Top and bottom rows are all walls
        assert maze[0] == WALL_CHAR * 10
        assert maze[4] == WALL_CHAR * 10
        # First and last columns are walls
        for row in maze:
            assert row[0] == WALL_CHAR
            assert row[-1] == WALL_CHAR

    def test_interior_is_floor(self):
        """Interior of maze is floor by default."""
        config = {
            'dimensions': [5, 10],
            'walls': [],
            'openings': [],
        }
        maze = generate_maze(config)
        # Interior should be floor
        for i in range(1, 4):
            for j in range(1, 9):
                assert maze[i][j] == FLOOR_CHAR, f"Position ({i},{j}) should be floor"

    def test_hline_wall(self):
        """Horizontal line wall is drawn correctly."""
        config = {
            'dimensions': [5, 10],
            'walls': [
                {'type': 'hline', 'line': [3, 2, 8]}  # 1-indexed: row 3, cols 2-8
            ],
            'openings': [],
        }
        maze = generate_maze(config)
        # Row 3 (0-indexed: 2), cols 2-8 (0-indexed: 1-7) should be walls
        for c in range(1, 8):
            assert maze[2][c] == WALL_CHAR, f"Position (2,{c}) should be wall"

    def test_vline_wall(self):
        """Vertical line wall is drawn correctly."""
        config = {
            'dimensions': [5, 10],
            'walls': [
                {'type': 'vline', 'line': [5, 2, 4]}  # 1-indexed: col 5, rows 2-4
            ],
            'openings': [],
        }
        maze = generate_maze(config)
        # Col 5 (0-indexed: 4), rows 2-4 (0-indexed: 1-3) should be walls
        for r in range(1, 4):
            assert maze[r][4] == WALL_CHAR, f"Position ({r},4) should be wall"

    def test_rect_wall(self):
        """Rectangular wall is drawn correctly."""
        config = {
            'dimensions': [10, 10],
            'walls': [
                {'type': 'rect', 'rect': [3, 3, 2, 3]}  # top=3, left=3, h=2, w=3
            ],
            'openings': [],
        }
        maze = generate_maze(config)
        # Rect at rows 3-4 (0-indexed: 2-3), cols 3-5 (0-indexed: 2-4)
        for r in range(2, 4):
            for c in range(2, 5):
                assert maze[r][c] == WALL_CHAR, f"Position ({r},{c}) should be wall"

    def test_point_opening(self):
        """Point opening carves through wall."""
        config = {
            'dimensions': [5, 10],
            'walls': [
                {'type': 'hline', 'line': [3, 1, 10]}  # Full wall on row 3
            ],
            'openings': [
                {'type': 'point', 'pos': [3, 5]}  # Opening at row 3, col 5
            ],
        }
        maze = generate_maze(config)
        # Row 3 (0-indexed: 2) should have wall except at col 5 (0-indexed: 4)
        assert maze[2][4] == FLOOR_CHAR, "Opening should create floor"
        assert maze[2][3] == WALL_CHAR, "Adjacent should still be wall"

    def test_exit_marker(self):
        """Exit position is marked with Q."""
        config = {
            'dimensions': [5, 10],
            'walls': [],
            'openings': [],
            'exit': [4, 8],  # 1-indexed
        }
        maze = generate_maze(config)
        # Exit at row 4 (0-indexed: 3), col 8 (0-indexed: 7)
        assert maze[3][7] == 'Q', "Exit should be marked with Q"


class TestPatrolRoute:
    """Tests for spy patrol route generation."""

    def test_horizontal_right_first(self):
        """Horizontal patrol going right first."""
        spy = {
            'pattern': 'horizontal',
            'endpoints': [[5, 10], [5, 20]],  # Left to right
        }
        route = generate_patrol_route(spy)
        assert len(route) == 2
        assert route[0]['dir'] == 'right'
        assert route[0]['end'] == [5, 20]
        assert route[1]['dir'] == 'left'
        assert route[1]['end'] == [5, 10]

    def test_horizontal_left_first(self):
        """Horizontal patrol going left first."""
        spy = {
            'pattern': 'horizontal',
            'endpoints': [[5, 20], [5, 10]],  # Right to left
        }
        route = generate_patrol_route(spy)
        assert len(route) == 2
        assert route[0]['dir'] == 'left'
        assert route[0]['end'] == [5, 10]
        assert route[1]['dir'] == 'right'
        assert route[1]['end'] == [5, 20]

    def test_vertical_down_first(self):
        """Vertical patrol going down first."""
        spy = {
            'pattern': 'vertical',
            'endpoints': [[5, 10], [15, 10]],  # Top to bottom
        }
        route = generate_patrol_route(spy)
        assert len(route) == 2
        assert route[0]['dir'] == 'down'
        assert route[0]['end'] == [15, 10]
        assert route[1]['dir'] == 'up'
        assert route[1]['end'] == [5, 10]

    def test_vertical_up_first(self):
        """Vertical patrol going up first."""
        spy = {
            'pattern': 'vertical',
            'endpoints': [[15, 10], [5, 10]],  # Bottom to top
        }
        route = generate_patrol_route(spy)
        assert len(route) == 2
        assert route[0]['dir'] == 'up'
        assert route[0]['end'] == [5, 10]
        assert route[1]['dir'] == 'down'
        assert route[1]['end'] == [15, 10]

    def test_loop_pattern_cw(self):
        """Loop pattern with clockwise direction."""
        spy = {
            'pattern': 'loop',
            'waypoints': [[5, 5], [5, 10], [10, 10], [10, 5]],
            'direction': 'cw',
        }
        route = generate_patrol_route(spy)
        assert len(route) == 4
        # Should go: right, down, left, up (back to start)
        assert route[0]['dir'] == 'right'
        assert route[1]['dir'] == 'down'
        assert route[2]['dir'] == 'left'
        assert route[3]['dir'] == 'up'

    def test_unknown_pattern_raises(self):
        """Unknown pattern raises ValueError."""
        spy = {'pattern': 'unknown'}
        with pytest.raises(ValueError, match="Unknown pattern"):
            generate_patrol_route(spy)


class TestGetSpawnPos:
    """Tests for spawn position extraction."""

    def test_explicit_spawn(self):
        """Explicit spawn position takes priority."""
        spy = {
            'spawn': [10, 20],
            'pattern': 'horizontal',
            'endpoints': [[5, 5], [5, 15]],
        }
        assert get_spawn_pos(spy) == [10, 20]

    def test_horizontal_spawn_from_endpoints(self):
        """Horizontal pattern uses first endpoint as spawn."""
        spy = {
            'pattern': 'horizontal',
            'endpoints': [[5, 10], [5, 20]],
        }
        assert get_spawn_pos(spy) == [5, 10]

    def test_vertical_spawn_from_endpoints(self):
        """Vertical pattern uses first endpoint as spawn."""
        spy = {
            'pattern': 'vertical',
            'endpoints': [[10, 5], [20, 5]],
        }
        assert get_spawn_pos(spy) == [10, 5]

    def test_loop_spawn_from_waypoints(self):
        """Loop pattern uses first waypoint as spawn."""
        spy = {
            'pattern': 'loop',
            'waypoints': [[5, 5], [5, 10], [10, 10], [10, 5]],
        }
        assert get_spawn_pos(spy) == [5, 5]


class TestValidateRoute:
    """Tests for route validation against maze."""

    def test_valid_route(self):
        """Valid route returns no errors."""
        maze = [
            '██████',
            '█    █',
            '█    █',
            '██████',
        ]
        spawn = [2, 2]  # 1-indexed
        route = [
            {'end': [2, 5], 'dir': 'right'},
            {'end': [2, 2], 'dir': 'left'},
        ]
        errors = validate_route(maze, spawn, route, 'test_spy')
        assert errors == []

    def test_spawn_on_wall(self):
        """Spawn on wall returns error."""
        maze = [
            '██████',
            '█    █',
            '██████',
        ]
        spawn = [1, 1]  # On wall (1-indexed)
        route = []
        errors = validate_route(maze, spawn, route, 'test_spy')
        assert any('wall' in e.lower() for e in errors)

    def test_spawn_out_of_bounds(self):
        """Spawn out of bounds returns error."""
        maze = [
            '██████',
            '█    █',
            '██████',
        ]
        spawn = [10, 10]  # Out of bounds
        route = []
        errors = validate_route(maze, spawn, route, 'test_spy')
        assert any('out of bounds' in e.lower() for e in errors)

    def test_route_hits_wall(self):
        """Route crossing wall returns error."""
        maze = [
            '██████',
            '█ █  █',  # Wall at column 3
            '██████',
        ]
        spawn = [2, 2]  # 1-indexed
        route = [
            {'end': [2, 5], 'dir': 'right'},  # Would hit wall at col 3
        ]
        errors = validate_route(maze, spawn, route, 'test_spy')
        assert any('wall' in e.lower() for e in errors)


class TestVimEscaping:
    """Tests for Vim string escaping functions."""

    def test_escape_single_quoted_simple(self):
        """Simple string needs no escaping."""
        assert escape_vim_single_quoted('hello') == 'hello'

    def test_escape_single_quoted_apostrophe(self):
        """Single quote becomes double single quote."""
        assert escape_vim_single_quoted("it's") == "it''s"

    def test_escape_single_quoted_multiple(self):
        """Multiple single quotes escaped."""
        assert escape_vim_single_quoted("'test'") == "''test''"

    def test_escape_single_quoted_none(self):
        """None returns empty string."""
        assert escape_vim_single_quoted(None) == ''

    def test_escape_double_quoted_simple(self):
        """Simple string needs no escaping."""
        assert escape_vim_double_quoted('hello') == 'hello'

    def test_escape_double_quoted_backslash(self):
        """Backslash is escaped."""
        assert escape_vim_double_quoted('a\\b') == 'a\\\\b'

    def test_escape_double_quoted_quote(self):
        """Double quote is escaped."""
        assert escape_vim_double_quoted('say "hi"') == 'say \\"hi\\"'

    def test_escape_double_quoted_newline(self):
        """Newline becomes \\n."""
        assert escape_vim_double_quoted('line1\nline2') == 'line1\\nline2'

    def test_escape_double_quoted_none(self):
        """None returns empty string."""
        assert escape_vim_double_quoted(None) == ''


class TestFormatVimValue:
    """Tests for Python to Vim value formatting."""

    def test_format_none(self):
        """None becomes v:null."""
        assert format_vim_value(None) == 'v:null'

    def test_format_true(self):
        """True becomes v:true."""
        assert format_vim_value(True) == 'v:true'

    def test_format_false(self):
        """False becomes v:false."""
        assert format_vim_value(False) == 'v:false'

    def test_format_int(self):
        """Integer formatted as string."""
        assert format_vim_value(42) == '42'

    def test_format_float(self):
        """Float formatted as string."""
        assert format_vim_value(3.14) == '3.14'

    def test_format_simple_string(self):
        """Simple string uses single quotes."""
        assert format_vim_value('hello') == "'hello'"

    def test_format_string_with_quote(self):
        """String with quote escapes properly."""
        assert format_vim_value("it's") == "'it''s'"

    def test_format_string_with_newline(self):
        """String with newline uses double quotes."""
        result = format_vim_value("line1\nline2")
        assert result.startswith('"')
        assert '\\n' in result

    def test_format_empty_list(self):
        """Empty list formats correctly."""
        assert format_vim_value([]) == '[]'

    def test_format_simple_list(self):
        """Simple list formats on one line."""
        assert format_vim_value([1, 2, 3]) == '[1, 2, 3]'

    def test_format_string_list(self):
        """List of strings formats correctly."""
        result = format_vim_value(['a', 'b'])
        assert "'a'" in result
        assert "'b'" in result

    def test_format_empty_dict(self):
        """Empty dict formats correctly."""
        assert format_vim_value({}) == '{}'

    def test_format_simple_dict(self):
        """Simple dict formats correctly."""
        result = format_vim_value({'key': 'value'})
        assert "'key'" in result
        assert "'value'" in result


class TestGenerateMetaVim:
    """Tests for meta.vim generation."""

    def test_basic_meta_structure(self):
        """Generated meta.vim has expected structure."""
        config = {
            'dimensions': [10, 20],
            'start': [2, 2],
            'exit': [9, 19],
            'commands': [{'key': 'h', 'desc': 'left'}],
            'blocked_categories': ['insert'],
            'features': [],
        }
        lore = {
            'title': 'Test Level',
            'description': 'A test',
            'objective': 'Win',
            'quote': 'Quote',
            'victory_quote': 'Victory!',
        }
        result = generate_meta_vim(config, lore)

        # Should start and end with braces
        assert result.startswith('{')
        assert result.rstrip().endswith('}')

        # Should contain key fields
        assert "'title'" in result
        assert "'Test Level'" in result
        assert "'start_cursor'" in result
        assert "'exit_cursor'" in result

    def test_meta_preserves_positions(self):
        """Positions from config are preserved."""
        config = {
            'dimensions': [25, 80],
            'start': [5, 10],
            'exit': [20, 70],
            'commands': [],
            'blocked_categories': [],
            'features': [],
        }
        lore = {'title': 'Test'}
        result = generate_meta_vim(config, lore)

        # Start and exit should appear in the output
        assert '[5, 10]' in result
        assert '[20, 70]' in result


class TestGenerateManifestVim:
    """Tests for manifest.vim generation."""

    def test_basic_manifest(self):
        """Manifest generates valid Vim list."""
        entries = [
            {'id': 1, 'dir': 'level01', 'title': 'First Level'},
            {'id': 2, 'dir': 'level02', 'title': 'Second Level'},
        ]
        result = generate_manifest_vim(entries)

        # Should be a list
        assert result.startswith('[')
        assert result.rstrip().endswith(']')

        # Should contain entries
        assert "'id': 1" in result
        assert "'level01'" in result
        assert "'First Level'" in result

    def test_manifest_escapes_quotes(self):
        """Manifest escapes quotes in titles."""
        entries = [
            {'id': 1, 'dir': 'level01', 'title': "It's a Test"},
        ]
        result = generate_manifest_vim(entries)

        # Single quote should be doubled
        assert "It''s a Test" in result


class TestGenerateSpiesVim:
    """Tests for spies.vim generation."""

    def test_basic_spy(self):
        """Single spy generates valid output."""
        spies = [{
            'id': 'guard1',
            'pattern': 'horizontal',
            'endpoints': [[2, 2], [2, 8]],
            'speed': 1.0,
        }]
        maze = [
            '██████████',
            '█        █',
            '█        █',
            '██████████',
        ]
        result, errors = generate_spies_vim(spies, maze)

        assert errors == []
        assert "'id': 'guard1'" in result
        assert "'spawn': [2, 2]" in result
        assert "'speed': 1.0" in result

    def test_spy_validation_error(self):
        """Invalid spy route returns errors."""
        spies = [{
            'id': 'bad_guard',
            'pattern': 'horizontal',
            'endpoints': [[1, 1], [1, 5]],  # On wall
            'speed': 1.0,
        }]
        maze = [
            '██████████',
            '█        █',
            '██████████',
        ]
        result, errors = generate_spies_vim(spies, maze)

        assert len(errors) > 0
        assert any('bad_guard' in e for e in errors)
