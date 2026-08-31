import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from agent_session import NextMessage, form_description


def test_form_description_shows_reply_and_instructions():
    text = form_description("What branch should I use?", 3)
    assert "turn 3" in text
    assert "What branch should I use?" in text
    assert "end_session" in text


def test_next_message_defaults_allow_end_only_submit():
    m = NextMessage(end_session=True)
    assert m.message == ""
    assert m.end_session is True
