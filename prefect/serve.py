# /// script
# requires-python = ">=3.11"
# dependencies = ["prefect>=3.8.4"]
# ///
"""Serve one agent-session deployment per active project.

Run from the control-center root (bin/prefect-serve does this).
Design: notes/2026-08-26-prefect-session-orchestration-research.md.
"""

import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from agent_session import agent_session

ROW = re.compile(r"^\|\s*\[([a-z0-9-]+)\]\([^)]*\)\s*\|\s*(\w+)\s*\|")


def active_projects(index_text: str) -> list[str]:
    """Parse projects/INDEX.md rows; return active slugs in order."""
    slugs = []
    for line in index_text.splitlines():
        m = ROW.match(line.strip())
        if m and m.group(2) == "active":
            slugs.append(m.group(1))
    return slugs


def main() -> None:
    from prefect import serve

    cc_root = Path(os.environ.get("CC_ROOT", os.getcwd()))
    agent_cmd = os.environ.get("AGENT_SESSION_CMD", "claude")
    index = cc_root / "projects" / "INDEX.md"
    slugs = active_projects(index.read_text())
    if not slugs:
        raise SystemExit(f"no active projects in {index}")
    deployments = [
        agent_session.with_options(name=slug).to_deployment(
            name="session",
            tags=["agent-session", slug],
            parameters={
                "project": slug,
                "agent_cmd": agent_cmd,
                "workdir": str(cc_root / "projects" / slug),
            },
        )
        for slug in slugs
    ]
    serve(*deployments, limit=10)


if __name__ == "__main__":
    main()
