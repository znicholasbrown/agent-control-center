import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from serve import active_projects

INDEX = """# Project registry

| Slug | Status | Repos | Updated |
|---|---|---|---|
| [alpha](alpha/PROJECT.md) | active | repo-a | 2026-07-22 |
| [beta](beta/PROJECT.md) | done | repo-b | 2026-07-29 |
| [gamma](gamma/PROJECT.md) | paused | repo-c | 2026-07-22 |
| [delta](delta/PROJECT.md) | active | repo-d | 2026-08-10 |
"""


def test_only_active_slugs_in_order():
    assert active_projects(INDEX) == ["alpha", "delta"]


def test_empty_registry():
    assert active_projects("# Project registry\n\n| Slug |\n|---|\n") == []
