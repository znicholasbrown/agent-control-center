#!/usr/bin/env bash
# Integration test for the agent-session driver.
# Starts an isolated Prefect server and serve daemon, runs a stub
# session through two suspend/resume cycles, and asserts on states,
# logs, artifacts, and events.
# Run: tests/prefect-session.test.sh   (takes ~60-90 s)
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$ROOT/.tmp/prefect-session-test.$$"
PORT=$(( 42000 + RANDOM % 1000 ))
export PREFECT_HOME="$TMP/home"
export PREFECT_API_URL="http://127.0.0.1:$PORT/api"
SERVER_PID="" SERVE_PID=""
trap '[ -n "$SERVE_PID" ] && kill "$SERVE_PID" 2>/dev/null;
      [ -n "$SERVER_PID" ] && kill "$SERVER_PID" 2>/dev/null;
      rm -rf "$TMP"' EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

# Sandbox center with one active project and a handoff file.
mkdir -p "$TMP/home" "$TMP/center/projects/demo/handoffs"
cat >"$TMP/center/projects/INDEX.md" <<'EOF'
# Project registry

| Slug | Status | Repos | Updated |
|---|---|---|---|
| [demo](demo/PROJECT.md) | active | demo-repo | 2026-08-28 |
EOF
printf '# demo-task handoff\n' >"$TMP/center/projects/demo/handoffs/demo-task.md"

uv run --quiet --with "prefect>=3.8.4" \
  prefect server start --host 127.0.0.1 --port "$PORT" \
  >"$TMP/server.log" 2>&1 &
SERVER_PID=$!
for _ in $(seq 1 90); do
  curl -sf -m 2 "$PREFECT_API_URL/health" >/dev/null 2>&1 && break
  sleep 1
done
curl -sf -m 2 "$PREFECT_API_URL/health" >/dev/null || fail "server not healthy"

CC_ROOT="$TMP/center" AGENT_SESSION_CMD="$ROOT/prefect/tests/fake-claude" \
  uv run --quiet "$ROOT/prefect/serve.py" >"$TMP/serve.log" 2>&1 &
SERVE_PID=$!
for _ in $(seq 1 60); do
  curl -sf -m 2 -X POST "$PREFECT_API_URL/deployments/filter" \
      -H 'Content-Type: application/json' -d '{}' | grep -q '"session"' \
    && break
  sleep 1
done

DRIVE="uv run --quiet --with prefect>=3.8.4 python"

FRID=$($DRIVE - <<'PY'
from prefect.deployments import run_deployment
fr = run_deployment(
    name="demo/session", timeout=0,
    parameters={"task": "demo-task", "prompt": "hello there"},
)
print(fr.id)
PY
) || fail "trigger"

wait_state() {  # $1 flow run id, $2 state name, $3 timeout s
  $DRIVE - "$1" "$2" "$3" <<'PY'
import asyncio, sys, time
from uuid import UUID
from prefect import get_client

async def main():
    frid, target, timeout = UUID(sys.argv[1]), sys.argv[2], float(sys.argv[3])
    deadline = time.monotonic() + timeout
    async with get_client() as client:
        while time.monotonic() < deadline:
            fr = await client.read_flow_run(frid)
            name = fr.state.name if fr.state else None
            if name == target:
                return
            if name in {"Failed", "Crashed"}:
                raise SystemExit(f"run ended in {name}: {fr.state.message}")
            await asyncio.sleep(2)
    raise SystemExit(f"timeout waiting for {target}, last {name}")

asyncio.run(main())
PY
}

resume() {  # $1 flow run id, $2 message, $3 end_session (true|false)
  $DRIVE - "$1" "$2" "$3" <<'PY'
import sys
from uuid import UUID
from prefect.flow_runs import resume_flow_run
resume_flow_run(
    UUID(sys.argv[1]),
    run_input={"message": sys.argv[2], "end_session": sys.argv[3] == "true"},
)
PY
}

wait_state "$FRID" Suspended 120 || fail "first suspend"
resume "$FRID" "second message" false || fail "first resume"
wait_state "$FRID" Suspended 120 || fail "second suspend"
resume "$FRID" "" true || fail "final resume"
wait_state "$FRID" Completed 120 || fail "completion"

$DRIVE - "$FRID" <<'PY' || fail "assertions"
import asyncio, json, sys
from uuid import UUID
from prefect import get_client
from prefect.client.schemas.filters import (
    ArtifactFilter, ArtifactFilterFlowRunId,
    FlowRunFilter, FlowRunFilterId,
    LogFilter, LogFilterFlowRunId,
)

async def main():
    fid = UUID(sys.argv[1])
    async with get_client() as client:
        trs = await client.read_task_runs(
            flow_run_filter=FlowRunFilter(id=FlowRunFilterId(any_=[fid]))
        )
        names = sorted(t.name for t in trs if t.name.startswith("turn-"))
        # 2 real turns; turn-1 replays once, so it appears at least twice.
        assert names.count("turn-1") >= 2, names
        assert "turn-2" in names, names
        assert any(
            t.state.name == "Cached" for t in trs if t.name == "turn-1"
        ), [(t.name, t.state.name) for t in trs]

        logs = await client.read_logs(
            log_filter=LogFilter(flow_run_id=LogFilterFlowRunId(any_=[fid])),
            limit=200,
        )
        msgs = [l.message for l in logs]
        human = [m for m in msgs if m.startswith("[human]")]
        agent = [m for m in msgs if m.startswith("[agent]")]
        assert "[human] hello there" in human, human
        assert "[human] second message" in human, human
        assert len(agent) == 2, agent
        sid = agent[0].split("echo(")[1].split(")")[0]
        assert f"echo({sid}): second message" in agent[1], (sid, agent)

        arts = await client.read_artifacts(
            artifact_filter=ArtifactFilter(
                flow_run_id=ArtifactFilterFlowRunId(any_=[fid])
            )
        )
        keys = {a.key for a in arts}
        assert "turn-tokens" in keys, keys
        assert "handoff-demo-demo-task" in keys, keys
        table = max(
            (a for a in arts if a.key == "turn-tokens"),
            key=lambda a: a.created,
        )
        rows = json.loads(table.data)
        assert [r["n"] for r in rows] == [1, 2], rows
        assert all(r["tokens_in"] == 11 for r in rows), rows

asyncio.run(main())
PY

EVENTS=$(curl -sf -X POST "$PREFECT_API_URL/events/filter" \
  -H 'Content-Type: application/json' \
  -d '{"filter":{"event":{"name":["agent-turn.completed"]}}}' \
  | grep -o 'agent-session\.' | wc -l | tr -d ' ')
[ "$EVENTS" -ge 2 ] || fail "expected >=2 turn events, got $EVENTS"

echo "PASS"
