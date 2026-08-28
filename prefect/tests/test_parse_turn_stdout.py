import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from agent_session import parse_turn_stdout

RESULT = (
    '{"type":"result","subtype":"success","session_id":"abc-123",'
    '"result":"OK","usage":{"input_tokens":10,"output_tokens":56},'
    '"total_cost_usd":0.0033}'
)


def test_single_result_line():
    out = parse_turn_stdout(RESULT + "\n")
    assert out["session_id"] == "abc-123"
    assert out["reply"] == "OK"
    assert out["tokens_in"] == 10
    assert out["tokens_out"] == 56
    assert out["cost_usd"] == 0.0033
    assert out["doc_count"] == 1


def test_stream_json_with_init_and_garbage():
    stdout = (
        '{"type":"system","subtype":"init","session_id":"abc-123"}\n'
        "not json at all\n" + RESULT + "\n"
    )
    out = parse_turn_stdout(stdout)
    assert out["reply"] == "OK"
    assert out["doc_count"] == 3


def test_takes_last_result_document():
    older = RESULT.replace('"OK"', '"OLD"')
    out = parse_turn_stdout(older + "\n" + RESULT + "\n")
    assert out["reply"] == "OK"


def test_no_result_raises():
    with pytest.raises(ValueError):
        parse_turn_stdout('{"type":"system","subtype":"init"}\n')


def test_empty_stdout_raises():
    with pytest.raises(ValueError):
        parse_turn_stdout("")


def test_missing_usage_is_none():
    stdout = '{"type":"result","session_id":"abc","result":"hi"}\n'
    out = parse_turn_stdout(stdout)
    assert out["tokens_in"] is None
    assert out["cost_usd"] is None
