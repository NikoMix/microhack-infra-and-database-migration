"""Shared helpers for deterministic artifact generation."""

from __future__ import annotations

from pathlib import Path
from typing import Any

from migration_copilot.models import Assessment

ARTIFACT_NAMES = {
    "assessment": "01-assessment.md",
    "architecture": "02-architecture.md",
    "cost": "03-cost-estimate.md",
    "iac": "04-iac-plan.md",
    "runbook": "05-runbook.md",
    "evidence": "06-evidence-index.md",
}


def output_dir(base_dir: Path, project: str) -> Path:
    """Create and return the canonical output directory for a project."""
    target = base_dir / project
    target.mkdir(parents=True, exist_ok=True)
    return target


def write_artifact(directory: Path, name: str, content: str) -> Path:
    """Write a UTF-8 markdown artifact and return its path."""
    path = directory / name
    path.write_text(content.rstrip() + "\n", encoding="utf-8")
    return path


def load_assessment(path: Path) -> Assessment:
    """Load a validated assessment from JSON."""
    return Assessment.from_json_file(path)


def canonical_rg(project: str) -> str:
    """Return a canonical resource-group prefix for a project."""
    slug = project.lower().replace("_", "-").replace(" ", "-")
    return f"rg-ttmh-{slug}"


async def advisory_text(
    chat_client: Any | None, *, name: str, instructions: str, prompt: str
) -> str:
    """Optionally call an Agent Framework-compatible client without making it mandatory."""
    if chat_client is None:
        return "Offline deterministic guidance used; no model endpoint was called."
    agent = chat_client.as_agent(name=name, instructions=instructions)
    result = await agent.run(prompt)
    text = getattr(result, "text", None)
    return str(text if text is not None else result)


def assessment_summary(assessment: Assessment, project: str) -> str:
    """Render the canonical assessment summary artifact."""
    server_rows = "\n".join(
        f"| {server.name} | {server.role} | {server.recommendedSize} | "
        f"{server.migrationStrategy} | ${server.monthlyCostUsd:,.2f} |"
        for server in assessment.servers
    )
    db_rows = []
    for instance in assessment.sqlInstances:
        for database in instance.databases:
            db_rows.append(
                f"| SQL | {database.name} | {instance.server} | {database.recommendedTarget} | "
                f"{', '.join(database.blockers) or 'None'} |"
            )
    db_rows.extend(
        f"| {db.engine} | {db.database} | {db.server} | {db.recommendedTarget} | None |"
        for db in assessment.ossDatabases
    )
    return f"""
# 01 Assessment Summary — {project}

Assessment: **{assessment.assessmentName}**
Generated: {assessment.generatedOn.isoformat()}
Azure location: **{assessment.azureLocation}**
Canonical resource groups: `{canonical_rg(project)}-*`

## Server estate

| Server | Role | Recommended size | Strategy | Monthly estimate |
| --- | --- | --- | --- | ---: |
{server_rows or "| _None_ | | | | |"}

## Data estate

| Engine | Database | Source server | Recommended target | Blockers |
| --- | --- | --- | --- | --- |
{chr(10).join(db_rows) if db_rows else "| _None_ | | | | |"}

## Initial estimate

Current assessment-provided monthly estimate: **${assessment.total_monthly_cost_usd:,.2f} {assessment.currency}**.
"""
