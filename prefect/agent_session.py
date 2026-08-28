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
    result_index = None
    for i, d in enumerate(reversed(docs)):
        if isinstance(d, dict) and "session_id" in d and "result" in d:
            result_index = len(docs) - 1 - i
            result = d
            break
    else:
        result = None
    if result is None:
        raise ValueError(
            f"no result document in agent stdout ({len(docs)} documents)"
        )
    trailing_docs = len(docs) - result_index - 1
    usage = result.get("usage") or {}
    return {
        "session_id": result["session_id"],
        "reply": result["result"],
        "tokens_in": usage.get("input_tokens"),
        "tokens_out": usage.get("output_tokens"),
        "cost_usd": result.get("total_cost_usd"),
        "doc_count": len(docs),
        "trailing_docs": trailing_docs,
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


from pathlib import Path

from prefect import flow, get_run_logger, task
from prefect.artifacts import create_markdown_artifact, create_table_artifact
from prefect.events import emit_event
from prefect.flow_runs import suspend_flow_run
from prefect.input import RunInput


class NextMessage(RunInput):
    message: str = ""
    end_session: bool = False


def form_description(reply: str, n: int) -> str:
    return (
        f"**Agent reply (turn {n}):**\n\n{reply}\n\n"
        "Type the next message and submit. "
        "Set end_session to finish the session."
    )


@task(persist_result=True, task_run_name="turn-{n}")
def run_turn(
    n: int,
    message: str,
    session_id: str | None,
    project: str,
    task_slug: str,
    workdir: str,
    agent_cmd: str,
    model: str | None,
    permission_mode: str | None,
    timeout_s: int,
) -> dict:
    logger = get_run_logger()
    logger.info("[human] %s", message)
    record = execute_turn(
        n=n,
        message=message,
        session_id=session_id,
        workdir=workdir,
        agent_cmd=agent_cmd,
        model=model,
        permission_mode=permission_mode,
        timeout_s=timeout_s,
        dump_dir=os.path.join(workdir, ".tmp", "agent-session-dumps"),
    )
    logger.info("[agent] %s", record["reply"])
    if record["trailing_docs"] > 0:
        logger.warning(
            "agent stdout had %d document(s) after the result; "
            "see raw-turn-%d.stdout",
            record["trailing_docs"],
            n,
        )
    emit_event(
        event="agent-turn.completed",
        resource={
            "prefect.resource.id": (
                f"agent-session.{record['session_id']}.turn.{n}"
            ),
            "project": project,
            "task": task_slug,
        },
        payload={
            k: record[k] for k in ("n", "tokens_in", "tokens_out", "cost_usd")
        },
    )
    return record


@task(persist_result=True)
def publish_turn_artifacts(
    project: str, task_slug: str, workdir: str, rows: list[dict]
) -> None:
    create_table_artifact(
        key="turn-tokens",
        table=[
            {
                k: r[k]
                for k in (
                    "n", "message", "reply", "tokens_in", "tokens_out",
                    "cost_usd",
                )
            }
            for r in rows
        ],
        description=f"Tokens and cost per turn ({project}/{task_slug})",
    )
    handoff = Path(workdir) / "handoffs" / f"{task_slug}.md"
    if handoff.is_file():
        create_markdown_artifact(
            key=f"handoff-{project}-{task_slug}",
            markdown=handoff.read_text(),
            description=f"Handoff for {project}/{task_slug}",
        )


@flow(name="agent-session", flow_run_name="{task}")
def agent_session(
    project: str,
    task: str,
    prompt: str,
    workdir: str | None = None,
    model: str | None = None,
    permission_mode: str | None = None,
    agent_cmd: str = "claude",
    max_turns: int = 50,
    turn_timeout_s: int = 3600,
) -> dict:
    """One agent session. Suspends between turns; resume to continue."""
    workdir = workdir or os.path.join("projects", project)
    message = prompt
    session_id = None
    rows: list[dict] = []
    for n in range(1, max_turns + 1):
        record = run_turn(
            n=n,
            message=message,
            session_id=session_id,
            project=project,
            task_slug=task,
            workdir=workdir,
            agent_cmd=agent_cmd,
            model=model,
            permission_mode=permission_mode,
            timeout_s=turn_timeout_s,
        )
        session_id = record["session_id"]
        rows.append(record)
        publish_turn_artifacts(project, task, workdir, rows)
        nxt = suspend_flow_run(
            wait_for_input=NextMessage.with_initial_data(
                description=form_description(record["reply"], n)
            ),
            key=f"turn-{n}",
        )
        if nxt.end_session:
            break
        message = nxt.message
    return {"session_id": session_id, "turns": len(rows)}
