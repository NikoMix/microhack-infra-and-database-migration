---
title: Delivery guide
---

## Room setup

Run pairs of two. One person drives Azure and VS Code; the other records teaching notes and evidence. Rotate roles after lunch. Keep a trainer screen on Azure portal navigation and a second screen on the slide deck.

## Pacing model

Use strict time boxes. Each challenge has a minimum path, an AI-assisted path, and a trainer demo fallback. If 30 percent of the room is blocked, pause and reset together; if fewer pairs are blocked, assign a roaming coach.

## Long Azure operations

SQL Managed Instance provisioning and Azure-SSIS Integration Runtime setup can run for hours. Pre-provision `sqlmi-ttmh-*` and `adf-ttmh-*` demo resources, or use recorded outputs. Teach the decision and validation pattern even when the resource is shared.

## Recovering stuck attendees

1. Verify subscription, tenant, and selected resource group.
2. Compare resource names with the canonical `rg-ttmh-*` convention.
3. Rerun read-only validation commands before redeploying.
4. Pair the attendee with a working neighbor for observation.
5. Use trainer-provided evidence snapshots so they can continue while the resource catches up.

## Teach-the-teacher moments

After each challenge, ask: What would you explain to a customer? What would you watch for as a trainer? What evidence proves success? Capture answers for the final teach-back.
