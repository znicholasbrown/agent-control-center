# /// script
# requires-python = ">=3.11"
# dependencies = ["prefect>=3.8.4"]
# ///
"""Create the Slack automation for suspended agent sessions.

Idempotent. Requires a SlackWebhook block named agent-session-slack;
prints a skip message when it is missing.
"""

from prefect.automations import Automation
from prefect.blocks.notifications import SlackWebhook
from prefect.events.actions import SendNotification
from prefect.events.schemas.automations import EventTrigger, Posture

AUTOMATION_NAME = "agent-session-suspended-slack"
BLOCK_NAME = "agent-session-slack"


def ensure_automation() -> str:
    try:
        block = SlackWebhook.load(BLOCK_NAME)
    except ValueError:
        return (
            f"skipped: no SlackWebhook block named {BLOCK_NAME}; "
            "create one, then rerun"
        )
    try:
        Automation.read(name=AUTOMATION_NAME)
        return "exists"
    except ValueError:
        pass
    Automation(
        name=AUTOMATION_NAME,
        trigger=EventTrigger(
            expect={"prefect.flow-run.Suspended"},
            match_related={
                "prefect.resource.role": "tag",
                "prefect.resource.id": "prefect.tag.agent-session",
            },
            posture=Posture.Reactive,
            threshold=1,
        ),
        actions=[
            SendNotification(
                block_document_id=block._block_document_id,
                subject="Agent session waiting",
                body=(
                    "Agent session {{ flow_run.name }} is suspended and "
                    "waits for input: {{ flow_run|ui_url }}"
                ),
            )
        ],
    ).create()
    return "created"


if __name__ == "__main__":
    print(ensure_automation())
