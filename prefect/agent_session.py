"""Agent sessions as suspendable Prefect flow runs.

Design: notes/2026-08-26-prefect-session-orchestration-research.md.
Each turn runs the agent CLI headlessly and persists its result. The
flow suspends between turns; the resume form's answer becomes the
next turn's message.
"""

import json
import os
import subprocess


def parse_turn_stdout(stdout: str) -> dict:
    """Parse agent CLI stdout as NDJSON; return the last result doc.

    Tolerates non-JSON lines and extra documents (seen once in the
    wild from `claude -p`). Raises ValueError when no document has
    both `session_id` and `result`.
    """
    docs = []
    for line in stdout.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            docs.append(json.loads(line))
        except json.JSONDecodeError:
            docs.append({"unparsed": line[:200]})
    result = next(
        (
            d
            for d in reversed(docs)
            if isinstance(d, dict) and "session_id" in d and "result" in d
        ),
        None,
    )
    if result is None:
        raise ValueError(
            f"no result document in agent stdout ({len(docs)} documents)"
        )
    usage = result.get("usage") or {}
    return {
        "session_id": result["session_id"],
        "reply": result["result"],
        "tokens_in": usage.get("input_tokens"),
        "tokens_out": usage.get("output_tokens"),
        "cost_usd": result.get("total_cost_usd"),
        "doc_count": len(docs),
    }


def _write_turn_dumps(n: int, stdout: str, stderr: str, dump_dir: str) -> None:
    """Write raw turn output to dump files."""
    os.makedirs(dump_dir, exist_ok=True)
    with open(os.path.join(dump_dir, f"raw-turn-{n}.stdout"), "w") as f:
        f.write(stdout)
    with open(os.path.join(dump_dir, f"raw-turn-{n}.stderr"), "w") as f:
        f.write(stderr)


def execute_turn(
    n: int,
    message: str,
    session_id: str | None,
    workdir: str,
    agent_cmd: str,
    model: str | None,
    permission_mode: str | None,
    timeout_s: int,
    dump_dir: str,
) -> dict:
    """Run one agent turn headlessly and return its parsed record."""
    cmd = [agent_cmd, "-p", message, "--output-format", "stream-json", "--verbose"]
    if model:
        cmd += ["--model", model]
    if permission_mode:
        cmd += ["--permission-mode", permission_mode]
    if session_id:
        cmd += ["--resume", session_id]
    try:
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout_s,
            stdin=subprocess.DEVNULL,
            cwd=workdir,
        )
    except subprocess.TimeoutExpired as exc:
        # Coerce stdout/stderr: bytes become str, None becomes empty string
        stdout = exc.stdout.decode() if isinstance(exc.stdout, bytes) else (exc.stdout or "")
        stderr = exc.stderr.decode() if isinstance(exc.stderr, bytes) else (exc.stderr or "")
        _write_turn_dumps(n, stdout, stderr, dump_dir)
        raise RuntimeError(
            f"agent timed out after {timeout_s}s (partial output dumped)"
        ) from exc
    _write_turn_dumps(n, proc.stdout, proc.stderr, dump_dir)
    if proc.returncode != 0:
        raise RuntimeError(
            f"agent exited {proc.returncode}: {proc.stderr[-2000:]}"
        )
    record = parse_turn_stdout(proc.stdout)
    record["n"] = n
    record["message"] = message
    return record
