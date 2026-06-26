---
name: assessment-parser
description: Parse Tailwind Traders assessment JSON into concise migration facts.
---

# Assessment Parser

## When to use

Use before any agent writes architecture, IaC, cost, runbook, or evidence artifacts.

## Instructions

Validate the top-level arrays `servers`, `sqlInstances`, and `ossDatabases`. Extract readiness, blockers, target recommendations, monthly estimates, and canonical database names. Do not invent missing values; write assumptions clearly.
