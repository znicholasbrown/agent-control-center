---
name: {{PROJECT_NAME}}
slug: {{PROJECT_SLUG}}
status: active
created: {{DATE}}
extends: null
# Replace the block with `tracker: none` if the user declines tracking.
tracker:
  type: {{TRACKER_TYPE}}       # linear, github, jira, ...
  project: {{TRACKER_PROJECT}} # url or id; add milestone:/parent: if given
repos:
  - name: {{REPO_NAME}}
    remote: {{REPO_REMOTE}}
    default_branch: main
---

# {{PROJECT_NAME}}

## Goal

<!-- One or two sentences: what does done look like? -->

## Links

<!-- Tickets, design docs, dashboards. -->

## Outcome

<!-- Filled by /finish-project: what shipped (PRs), key decisions,
     explicit loose ends. Empty while the project is active. -->
