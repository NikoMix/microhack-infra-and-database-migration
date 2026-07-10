"""Schema Converter agent for SQL Server, SSIS, SQL Agent, PostgreSQL, and MySQL."""

from __future__ import annotations

from pathlib import Path
from typing import Any

from migration_copilot.agents.common import (
    ARTIFACT_NAMES,
    advisory_text,
    output_dir,
    write_artifact,
)
from migration_copilot.models import (
    ArtifactSet,
    Assessment,
    CostLine,
    MigrationDecision,
    MigrationTarget,
)

INSTRUCTIONS = """You are Schema Converter for Tailwind Traders.
Analyze assessment metadata, flag SQL blockers, and map SQL Server/SSIS/SQL Agent/OSS DBs
to Azure SQL family, Azure-SSIS IR, Elastic Jobs or MI Agent, and Flexible Server."""


def _has_cross_db_blocker(blockers: list[str]) -> bool:
    return any("cross" in blocker.lower() and "db" in blocker.lower() for blocker in blockers)


def build_schema_decisions(assessment: Assessment) -> list[MigrationDecision]:
    """Create deterministic data-platform migration decisions."""
    decisions: list[MigrationDecision] = []
    for instance in assessment.sqlInstances:
        for database in instance.databases:
            target = (
                MigrationTarget.AZURE_SQL_MI.value
                if _has_cross_db_blocker(database.blockers)
                else database.recommendedTarget
            )
            actions = [
                "Run DMA/SqlPackage compatibility validation",
                "Script schema diff and test data sync",
            ]
            if target == MigrationTarget.AZURE_SQL_MI.value:
                actions.append("Keep cross-database query workload on Managed Instance")
            decisions.append(
                MigrationDecision(
                    workload=database.name,
                    source=f"{instance.server}\\{instance.instance}",
                    target=target,
                    rationale="Cross-database blockers require MI; otherwise use assessment target.",
                    blockers=database.blockers,
                    actions=actions,
                )
            )
        decisions.extend(
            MigrationDecision(
                workload=package,
                source=f"SSIS on {instance.server}",
                target=MigrationTarget.AZURE_SSIS_IR.value,
                rationale="SSIS packages map to Azure-SSIS Integration Runtime in ADF for lift-and-shift.",
                actions=[
                    "Inventory package parameters",
                    "Externalize secrets",
                    "Test package execution in ADF",
                ],
            )
            for package in instance.ssisPackages
        )
        uses_mi = any(
            db.recommendedTarget == MigrationTarget.AZURE_SQL_MI.value
            or _has_cross_db_blocker(db.blockers)
            for db in instance.databases
        )
        decisions.extend(
            MigrationDecision(
                workload=job,
                source=f"SQL Agent on {instance.server}",
                target=MigrationTarget.MI_AGENT.value
                if uses_mi
                else MigrationTarget.ELASTIC_JOBS.value,
                rationale="Managed Instance Agent fits MI estates; Elastic Jobs fits Azure SQL DB estates.",
                actions=["Extract schedule", "Convert operators/alerts", "Add runbook evidence"],
            )
            for job in instance.agentJobs
        )
    decisions.extend(
        MigrationDecision(
            workload=database.database,
            source=f"{database.engine} {database.version} on {database.server}",
            target=MigrationTarget.POSTGRES_FLEX.value
            if database.engine.lower() == "postgresql"
            else MigrationTarget.MYSQL_FLEX.value,
            rationale="OSS engines should modernize to Azure Flexible Server for managed HA and patching.",
            actions=["Validate extensions", "Plan DMS migration", "Confirm parameter parity"],
        )
        for database in assessment.ossDatabases
    )
    return decisions


def build_cost_contribution(assessment: Assessment) -> list[CostLine]:
    """Estimate data-platform cost contribution from assessment data."""
    sql_size = sum(
        database.sizeGB for instance in assessment.sqlInstances for database in instance.databases
    )
    lines = []
    if sql_size:
        lines.append(
            CostLine(
                category="Azure SQL family",
                item="Tailwind SQL estate",
                monthly_cost_usd=sql_size * 4.0,
                assumption="Training estimate: $4/GB-month placeholder until Azure pricing is applied.",
            )
        )
    lines.extend(
        CostLine(
            category=database.engine,
            item=database.database,
            monthly_cost_usd=database.monthlyCostUsd,
            assumption=f"Assessment provided {database.recommendedTarget} monthly estimate.",
        )
        for database in assessment.ossDatabases
    )
    return lines


def _cost_markdown(decisions: list[MigrationDecision], costs: list[CostLine], advisory: str) -> str:
    decision_rows = "\n".join(
        f"| {decision.workload} | {decision.source} | {decision.target} | "
        f"{', '.join(decision.blockers) or 'None'} | {'; '.join(decision.actions)} |"
        for decision in decisions
    )
    cost_rows = "\n".join(
        f"| {line.category} | {line.item} | ${line.monthly_cost_usd:,.2f} | {line.assumption} |"
        for line in costs
    )
    return f"""
# 03 Cost Estimate and Schema Conversion Decisions

## Conversion decisions

| Workload | Source | Target | Blockers | Actions |
| --- | --- | --- | --- | --- |
{decision_rows}

## Cost contribution

| Category | Item | Monthly estimate | Assumption |
| --- | --- | ---: | --- |
{cost_rows or "| _None_ | | $0.00 | |"}

## Agent advisory

{advisory}
"""


async def run_schema_converter(
    assessment: Assessment,
    *,
    project: str,
    base_output_dir: Path,
    chat_client: Any | None = None,
) -> ArtifactSet:
    """Generate schema conversion and cost-estimate contribution artifact."""
    directory = output_dir(base_output_dir, project)
    decisions = build_schema_decisions(assessment)
    costs = build_cost_contribution(assessment)
    advisory = await advisory_text(
        chat_client,
        name="SchemaConverter",
        instructions=INSTRUCTIONS,
        prompt=f"Review {len(decisions)} conversion decisions for {project}.",
    )
    files = [
        write_artifact(
            directory, ARTIFACT_NAMES["cost"], _cost_markdown(decisions, costs, advisory)
        )
    ]
    return ArtifactSet(project=project, output_dir=directory, files=files)
