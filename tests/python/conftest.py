"""Shared pytest fixtures for Escape Vim tests."""

import os
import sys
import pytest
from pathlib import Path

# Add tools directory to path for imports
REPO_ROOT = Path(__file__).parent.parent.parent
sys.path.insert(0, str(REPO_ROOT / "tools"))


@pytest.fixture
def repo_root():
    """Return the repository root path."""
    return REPO_ROOT


@pytest.fixture
def fixtures_dir():
    """Return the fixtures directory path."""
    return Path(__file__).parent / "fixtures"


@pytest.fixture
def levels_dir(repo_root):
    """Return the levels directory path."""
    return repo_root / "levels"


@pytest.fixture
def valid_level_yaml(fixtures_dir):
    """Load the minimal valid level YAML."""
    import yaml
    with open(fixtures_dir / "valid_level.yaml") as f:
        return yaml.safe_load(f)


@pytest.fixture
def valid_lore_json(fixtures_dir):
    """Load the minimal valid lore JSON."""
    import json
    with open(fixtures_dir / "valid_lore.json") as f:
        return json.load(f)


@pytest.fixture
def temp_level_dir(tmp_path):
    """Create a temporary level directory for testing."""
    level_dir = tmp_path / "level99"
    level_dir.mkdir()
    return level_dir
