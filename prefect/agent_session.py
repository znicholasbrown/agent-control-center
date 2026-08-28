"""Agent sessions as suspendable Prefect flow runs.

Design: notes/2026-08-26-prefect-session-orchestration-research.md.
Each turn runs the agent CLI headlessly and persists its result. The
flow suspends between turns; the resume form's answer becomes the
next turn's message.
"""

import json


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
