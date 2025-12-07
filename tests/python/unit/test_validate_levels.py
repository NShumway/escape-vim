"""Unit tests for tools/validate_levels.py."""

import pytest
import sys
from pathlib import Path
from tempfile import TemporaryDirectory

# Add tools to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent.parent / "tools"))

from validate_levels import (
    parse_vim_dict,
    measure_maze,
    get_char_at,
    validate_level,
    validate_spy,
    WALL_CHAR,
)


class TestParseVimDict:
    """Tests for Vim dictionary parsing."""

    def test_simple_dict(self):
        """Parse simple dict with string values."""
        vim_str = "{'key': 'value', 'num': 42}"
        result = parse_vim_dict(vim_str)
        assert result == {'key': 'value', 'num': 42}

    def test_nested_dict(self):
        """Parse nested dictionary."""
        vim_str = "{'outer': {'inner': 'value'}}"
        result = parse_vim_dict(vim_str)
        assert result['outer']['inner'] == 'value'

    def test_vnull(self):
        """v:null becomes None."""
        vim_str = "{'limit': v:null}"
        result = parse_vim_dict(vim_str)
        assert result['limit'] is None

    def test_vtrue(self):
        """v:true becomes True."""
        vim_str = "{'flag': v:true}"
        result = parse_vim_dict(vim_str)
        assert result['flag'] is True

    def test_vfalse(self):
        """v:false becomes False."""
        vim_str = "{'flag': v:false}"
        result = parse_vim_dict(vim_str)
        assert result['flag'] is False

    def test_list_value(self):
        """Parse list values."""
        vim_str = "{'items': [1, 2, 3]}"
        result = parse_vim_dict(vim_str)
        assert result['items'] == [1, 2, 3]

    def test_single_quoted_string(self):
        """Single-quoted strings work."""
        vim_str = "{'name': 'hello'}"
        result = parse_vim_dict(vim_str)
        assert result['name'] == 'hello'

    def test_escaped_single_quote(self):
        """Escaped single quote '' becomes '."""
        vim_str = "{'name': 'it''s'}"
        result = parse_vim_dict(vim_str)
        assert result['name'] == "it's"

    def test_double_quoted_string(self):
        """Double-quoted strings work."""
        vim_str = '{"name": "hello"}'
        result = parse_vim_dict(vim_str)
        assert result['name'] == 'hello'

    def test_comment_lines_ignored(self):
        """Comment lines starting with " are ignored."""
        vim_str = '''" This is a comment
{'key': 'value'}'''
        result = parse_vim_dict(vim_str)
        assert result == {'key': 'value'}

    def test_multiline_dict(self):
        """Multiline dictionaries are parsed."""
        vim_str = """{
  'key1': 'value1',
  'key2': 42
}"""
        result = parse_vim_dict(vim_str)
        assert result['key1'] == 'value1'
        assert result['key2'] == 42


class TestMeasureMaze:
    """Tests for maze dimension measurement."""

    def test_basic_measurement(self):
        """Measure simple maze dimensions."""
        with TemporaryDirectory() as tmpdir:
            maze_path = Path(tmpdir) / 'maze.txt'
            maze_path.write_text('█████\n█   █\n█████\n', encoding='utf-8')

            rows, cols = measure_maze(maze_path)
            assert rows == 3
            assert cols == 5

    def test_unicode_character_count(self):
        """Maze dimensions count characters, not bytes."""
        with TemporaryDirectory() as tmpdir:
            maze_path = Path(tmpdir) / 'maze.txt'
            # █ is 3 bytes but 1 character
            maze_path.write_text('████\n████\n', encoding='utf-8')

            rows, cols = measure_maze(maze_path)
            assert rows == 2
            assert cols == 4  # 4 characters, not 12 bytes

    def test_varying_line_lengths(self):
        """Max column is from longest line."""
        with TemporaryDirectory() as tmpdir:
            maze_path = Path(tmpdir) / 'maze.txt'
            maze_path.write_text('███\n██████\n████\n', encoding='utf-8')

            rows, cols = measure_maze(maze_path)
            assert rows == 3
            assert cols == 6  # Longest line


class TestGetCharAt:
    """Tests for character access at positions."""

    def test_get_ascii_char(self):
        """Get ASCII character at position."""
        lines = ['hello\n', 'world\n']
        assert get_char_at(lines, 1, 1) == 'h'
        assert get_char_at(lines, 1, 5) == 'o'
        assert get_char_at(lines, 2, 1) == 'w'

    def test_get_unicode_char(self):
        """Get unicode character at position."""
        lines = ['████\n']
        assert get_char_at(lines, 1, 1) == '█'
        assert get_char_at(lines, 1, 4) == '█'

    def test_out_of_bounds_line(self):
        """Out of bounds line returns empty string."""
        lines = ['test\n']
        assert get_char_at(lines, 0, 1) == ''
        assert get_char_at(lines, 5, 1) == ''

    def test_out_of_bounds_col(self):
        """Out of bounds column returns empty string."""
        lines = ['test\n']
        assert get_char_at(lines, 1, 0) == ''
        assert get_char_at(lines, 1, 10) == ''


class TestValidateLevel:
    """Tests for level validation."""

    def create_test_level(self, tmpdir, meta_content, maze_content):
        """Create a test level in tmpdir."""
        level_dir = Path(tmpdir) / 'level99'
        level_dir.mkdir()

        (level_dir / 'meta.vim').write_text(meta_content, encoding='utf-8')
        (level_dir / 'maze.txt').write_text(maze_content, encoding='utf-8')

        return level_dir

    def test_valid_level(self):
        """Valid level returns no errors."""
        with TemporaryDirectory() as tmpdir:
            meta = """{
  'title': 'Test',
  'start_cursor': [2, 2],
  'exit_cursor': [2, 4],
  'maze': {'lines': 3, 'cols': 6},
  'features': []
}"""
            maze = "██████\n█    █\n██████\n"
            level_dir = self.create_test_level(tmpdir, meta, maze)

            errors = validate_level(level_dir)
            assert errors == []

    def test_missing_meta(self):
        """Missing meta.vim is an error."""
        with TemporaryDirectory() as tmpdir:
            level_dir = Path(tmpdir) / 'level99'
            level_dir.mkdir()

            errors = validate_level(level_dir)
            assert any('meta.vim not found' in e for e in errors)

    def test_missing_maze(self):
        """Missing maze.txt is an error."""
        with TemporaryDirectory() as tmpdir:
            level_dir = Path(tmpdir) / 'level99'
            level_dir.mkdir()
            (level_dir / 'meta.vim').write_text("{}", encoding='utf-8')

            errors = validate_level(level_dir)
            assert any('maze.txt not found' in e for e in errors)

    def test_dimension_mismatch(self):
        """Dimension mismatch is detected."""
        with TemporaryDirectory() as tmpdir:
            meta = """{
  'title': 'Test',
  'start_cursor': [2, 2],
  'exit_cursor': [2, 4],
  'maze': {'lines': 10, 'cols': 20},
  'features': []
}"""
            maze = "██████\n█    █\n██████\n"  # Actually 3x6
            level_dir = self.create_test_level(tmpdir, meta, maze)

            errors = validate_level(level_dir)
            assert any('mismatch' in e for e in errors)

    def test_start_on_wall(self):
        """Start position on wall is detected."""
        with TemporaryDirectory() as tmpdir:
            meta = """{
  'title': 'Test',
  'start_cursor': [1, 1],
  'exit_cursor': [2, 4],
  'maze': {'lines': 3, 'cols': 6},
  'features': []
}"""
            maze = "██████\n█    █\n██████\n"
            level_dir = self.create_test_level(tmpdir, meta, maze)

            errors = validate_level(level_dir)
            assert any('wall' in e.lower() and 'start' in e.lower() for e in errors)

    def test_exit_on_wall(self):
        """Exit position on wall is detected."""
        with TemporaryDirectory() as tmpdir:
            meta = """{
  'title': 'Test',
  'start_cursor': [2, 2],
  'exit_cursor': [1, 1],
  'maze': {'lines': 3, 'cols': 6},
  'features': []
}"""
            maze = "██████\n█    █\n██████\n"
            level_dir = self.create_test_level(tmpdir, meta, maze)

            errors = validate_level(level_dir)
            assert any('wall' in e.lower() and 'exit' in e.lower() for e in errors)

    def test_start_out_of_bounds(self):
        """Start position out of bounds is detected."""
        with TemporaryDirectory() as tmpdir:
            meta = """{
  'title': 'Test',
  'start_cursor': [100, 100],
  'exit_cursor': [2, 4],
  'maze': {'lines': 3, 'cols': 6},
  'features': []
}"""
            maze = "██████\n█    █\n██████\n"
            level_dir = self.create_test_level(tmpdir, meta, maze)

            errors = validate_level(level_dir)
            assert any('out of bounds' in e.lower() for e in errors)


class TestValidateSpy:
    """Tests for spy validation."""

    def test_valid_spy(self):
        """Valid spy returns no errors."""
        maze_lines = [
            '██████\n',
            '█    █\n',
            '██████\n',
        ]
        spy = {
            'id': 'guard1',
            'spawn': [2, 2],
            'route': [
                {'end': [2, 5], 'dir': 'right'},
                {'end': [2, 2], 'dir': 'left'},
            ],
        }
        errors = validate_spy('test', spy, maze_lines, 3, 6)
        assert errors == []

    def test_missing_spawn(self):
        """Missing spawn is an error."""
        maze_lines = ['██████\n', '█    █\n', '██████\n']
        spy = {
            'id': 'guard1',
            'route': [],
        }
        errors = validate_spy('test', spy, maze_lines, 3, 6)
        assert any('spawn' in e.lower() for e in errors)

    def test_spawn_on_wall(self):
        """Spawn on wall is an error."""
        maze_lines = ['██████\n', '█    █\n', '██████\n']
        spy = {
            'id': 'guard1',
            'spawn': [1, 1],  # On wall
            'route': [],
        }
        errors = validate_spy('test', spy, maze_lines, 3, 6)
        assert any('wall' in e.lower() for e in errors)

    def test_spawn_out_of_bounds(self):
        """Spawn out of bounds is an error."""
        maze_lines = ['██████\n', '█    █\n', '██████\n']
        spy = {
            'id': 'guard1',
            'spawn': [10, 10],  # Out of bounds
            'route': [],
        }
        errors = validate_spy('test', spy, maze_lines, 3, 6)
        assert any('out of bounds' in e.lower() for e in errors)

    def test_route_hits_wall(self):
        """Route crossing wall is an error."""
        maze_lines = [
            '██████\n',
            '█ █  █\n',  # Wall at column 3
            '██████\n',
        ]
        spy = {
            'id': 'guard1',
            'spawn': [2, 2],
            'route': [
                {'end': [2, 5], 'dir': 'right'},  # Would hit wall at col 3
            ],
        }
        errors = validate_spy('test', spy, maze_lines, 3, 6)
        assert any('wall' in e.lower() for e in errors)

    def test_route_doesnt_loop(self):
        """Route not returning to spawn is an error."""
        maze_lines = ['██████\n', '█    █\n', '██████\n']
        spy = {
            'id': 'guard1',
            'spawn': [2, 2],
            'route': [
                {'end': [2, 5], 'dir': 'right'},
                # Missing return to spawn
            ],
        }
        errors = validate_spy('test', spy, maze_lines, 3, 6)
        assert any('spawn' in e.lower() for e in errors)

    def test_empty_route(self):
        """Empty route is an error."""
        maze_lines = ['██████\n', '█    █\n', '██████\n']
        spy = {
            'id': 'guard1',
            'spawn': [2, 2],
            'route': [],
        }
        errors = validate_spy('test', spy, maze_lines, 3, 6)
        assert any('empty' in e.lower() for e in errors)

    def test_invalid_direction(self):
        """Invalid direction is an error."""
        maze_lines = ['██████\n', '█    █\n', '██████\n']
        spy = {
            'id': 'guard1',
            'spawn': [2, 2],
            'route': [
                {'end': [2, 5], 'dir': 'diagonal'},  # Invalid
            ],
        }
        errors = validate_spy('test', spy, maze_lines, 3, 6)
        assert any('direction' in e.lower() for e in errors)
