"""Engagement Copilot for Module B.4.1/B.4.2 migration deliverables."""

from __future__ import annotations

from pathlib import Path
from typing import Any

from migration_copilot.agents.common import (
    ARTIFACT_NAMES,
    advisory_text,
    canonical_rg,
    output_dir,
    write_artifact,
)
from migration_copilot.models import ArtifactSet, Assessment, EvidenceItem, Wave

INSTRUCTIONS = """You are Engagement Copilot for the Tailwind Traders Azure migration microhack.
Create concise Module B.4.1/B.4.2 onboarding, KT, hypercare, runbook, and audit artifacts.
Use only assessment facts and canonical rg-ttmh-* names."""


def build_waves(assessment: Assessment) -> list[Wave]:
    """Create deterministic migration waves from assessment roles and database targets."""
    app_scope = [server.name for server in assessment.servers if server.role.lower() != "sql"]
    data_scope = [database.name for item in assessment.sqlInstances for database in item.databases]
    oss_scope = [database.database for database in assessment.ossDatabases]
    return [
        Wave(
            name="Wave 0 - Foundation and landing zone readiness",
            scope=[canonical_rg("core"), "Azure Policy", "RBAC", "network connectivity"],
            rationale="Prepare governance, subscriptions, identity, and connectivity before workload moves.",
            exit_criteria=["RBAC assigned", "policy exemptions documented", "connectivity tested"],
        ),
        Wave(
            name="Wave 1 - Data platform modernization",
            scope=data_scope + oss_scope,
            rationale="Move stateful services first so application cutover has stable targets.",
            exit_criteria=[
                "Schema blockers resolved",
                "replication tested",
                "rollback point captured",
            ],
            dependencies=["Wave 0"],
        ),
        Wave(
            name="Wave 2 - IaaS rehost and application cutover",
            scope=app_scope or [server.name for server in assessment.servers],
            rationale="Rehost remaining servers after database endpoints and runbooks are ready.",
            exit_criteria=["Smoke tests passed", "DNS switched", "monitoring green for 24 hours"],
            dependencies=["Wave 1"],
        ),
    ]


def build_evidence(project: str) -> list[EvidenceItem]:
    """Build the audit evidence index for Advanced Specialization controls."""
    return [
        EvidenceItem(
            control="B.4.1",
            artifact="01-assessment.md",
            description="Assessment interpretation and migration scope",
            owner="Engagement Lead",
        ),
        EvidenceItem(
            control="B.4.1",
            artifact="02-architecture.md",
            description="High-level design, waves, and landing-zone assumptions",
            owner="Cloud Architect",
        ),
        EvidenceItem(
            control="B.4.1",
            artifact="04-iac-plan.md",
            description="IaC implementation plan with approval record",
            owner="IaC Architect",
        ),
        EvidenceItem(
            control="B.4.2",
            artifact="05-runbook.md",
            description=f"Cutover, KT, and hypercare plan for {project}",
            owner="Migration Lead",
        ),
        EvidenceItem(
            control="B.4.2",
            artifact="06-evidence-index.md",
            description="Audit pack index and artifact ownership",
            owner="PMO",
        ),
    ]


def _architecture_markdown(
    assessment: Assessment, project: str, waves: list[Wave], advisory: str
) -> str:
    wave_text = "\n".join(
        f"### {wave.name}\n- Scope: {', '.join(wave.scope)}\n- Rationale: {wave.rationale}\n"
        f"- Exit criteria: {'; '.join(wave.exit_criteria)}\n"
        f"- Dependencies: {', '.join(wave.dependencies) or 'None'}"
        for wave in waves
    )
    return f"""
# 02 Architecture — {project}

## Target-state overview

Tailwind Traders exits datacenter workloads into Azure using three pillars:
IaaS rehost, Azure SQL family modernization, and OSS DB PaaS. Resource groups follow
`{canonical_rg(project)}-*` in **{assessment.azureLocation}**.

## Migration waves

{wave_text}

## Knowledge transfer plan

- Daily trainer playback of decisions, blockers, and evidence updates.
- Pair partner consultants on assessment interpretation and IaC planning.
- Capture Module B.4.1/B.4.2 sign-off evidence in `06-evidence-index.md`.

## Agent advisory

{advisory}
"""


def _runbook_markdown(project: str, waves: list[Wave]) -> str:
    wave_checks = "\n".join(
        f"- {wave.name}: verify {', '.join(wave.exit_criteria).lower()}" for wave in waves
    )
    return f"""
# 05 Cutover Runbook — {project}

## Pre-cutover

- Freeze schema changes and capture rollback backups.
- Confirm DNS, firewall, private endpoint, and identity dependencies.
- Confirm human approval for IaC emission before deployment.

## Cutover sequence

{wave_checks}

## Rollback

- Re-point connection strings to source systems.
- Restore latest validated backup if replication validation fails.
- Log blocker, owner, decision, and evidence status.

## KT and hypercare

- KT: architecture walkthrough, runbook rehearsal, evidence-pack review.
- Hypercare: 5 business days of daily health checks, cost review, and open-risk triage.
"""


def _evidence_markdown(items: list[EvidenceItem]) -> str:
    rows = "\n".join(
        f"| {item.control} | {item.artifact} | {item.description} | {item.owner} | {item.status} |"
        for item in items
    )
    return f"""
# 06 Evidence Index

| Control | Artifact | Description | Owner | Status |
| --- | --- | --- | --- | --- |
{rows}
"""


async def run_engagement_copilot(
    assessment: Assessment,
    *,
    project: str,
    base_output_dir: Path,
    chat_client: Any | None = None,
) -> ArtifactSet:
    """Generate architecture, runbook, and evidence artifacts."""
    directory = output_dir(base_output_dir, project)
    waves = build_waves(assessment)
    advisory = await advisory_text(
        chat_client,
        name="EngagementCopilot",
        instructions=INSTRUCTIONS,
        prompt=f"Create engagement guidance for {project} using {assessment.assessmentName}.",
    )
    files = [
        write_artifact(
            directory,
            ARTIFACT_NAMES["architecture"],
            _architecture_markdown(assessment, project, waves, advisory),
        ),
        write_artifact(directory, ARTIFACT_NAMES["runbook"], _runbook_markdown(project, waves)),
        write_artifact(
            directory, ARTIFACT_NAMES["evidence"], _evidence_markdown(build_evidence(project))
        ),
    ]
    return ArtifactSet(project=project, output_dir=directory, files=files)
