import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from agent_session import execute_turn

FAKE = str(Path(__file__).parent / "fake-claude")


def test_first_turn_new_session(tmp_path):
    rec = execute_turn(
        n=1, message="hello", session_id=None, workdir=str(tmp_path),
        agent_cmd=FAKE, model=None, permission_mode=None,
        timeout_s=30, dump_dir=str(tmp_path),
    )
    assert rec["n"] == 1
    assert rec["message"] == "hello"
    assert rec["session_id"].endswith("f4ce")
    assert rec["reply"] == f"echo({rec['session_id']}): hello"
    assert rec["tokens_in"] == 11
    assert rec["doc_count"] == 3
    assert (tmp_path / "raw-turn-1.stdout").exists()
    assert (tmp_path / "raw-turn-1.stderr").exists()


def test_resume_passes_session_id(tmp_path):
    rec = execute_turn(
        n=2, message="again", session_id="abc-123", workdir=str(tmp_path),
        agent_cmd=FAKE, model=None, permission_mode=None,
        timeout_s=30, dump_dir=str(tmp_path),
    )
    assert rec["session_id"] == "abc-123"
    assert rec["reply"] == "echo(abc-123): again"


def test_nonzero_exit_raises(tmp_path):
    with pytest.raises(RuntimeError):
        execute_turn(
            n=1, message="x", session_id=None, workdir=str(tmp_path),
            agent_cmd="false", model=None, permission_mode=None,
            timeout_s=30, dump_dir=str(tmp_path),
        )


def test_timeout_writes_dumps_and_raises(tmp_path):
    slow = tmp_path / "slow-agent"
    slow.write_text("#!/usr/bin/env bash\necho partial-out\nsleep 5\n")
    slow.chmod(0o755)
    with pytest.raises(RuntimeError, match="timed out"):
        execute_turn(
            n=1, message="x", session_id=None, workdir=str(tmp_path),
            agent_cmd=str(slow), model=None, permission_mode=None,
            timeout_s=1, dump_dir=str(tmp_path),
        )
    assert (tmp_path / "raw-turn-1.stdout").exists()
    assert (tmp_path / "raw-turn-1.stderr").exists()
