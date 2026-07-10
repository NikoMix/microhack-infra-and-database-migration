"""IaC Architect agent with an explicit human-approval gate."""

from __future__ import annotations

from collections.abc import Callable
from pathlib import Path
from typing import Any

from migration_copilot.agents.common import (
    ARTIFACT_NAMES,
    advisory_text,
    assessment_summary,
    canonical_rg,
    output_dir,
    write_artifact,
)
from migration_copilot.models import ApprovalRequest, ArtifactSet, Assessment, CostLine

INSTRUCTIONS = """You are the IaC Architect for Tailwind Traders.
Translate migration intent into Azure Verified Module planning guidance. Include WAF, cost,
governance, and a human approval gate before emitting deployable IaC."""

ApprovalCallback = Callable[[ApprovalRequest], bool]


def suggest_avm_modules(assessment: Assessment) -> list[str]:
    """Suggest Bicep AVM modules from assessed workloads."""
    modules = [
        "avm/res/resources/resource-group",
        "avm/res/network/virtual-network",
        "avm/res/network/private-endpoint",
        "avm/res/authorization/role-assignment",
        "avm/res/insights/component",
    ]
    if assessment.servers:
        modules.extend(["avm/res/compute/virtual-machine", "avm/res/compute/availability-set"])
    if assessment.sqlInstances:
        modules.extend(
            ["avm/res/sql/managed-instance", "avm/res/sql/server", "avm/res/sql/server/database"]
        )
    if any(db.engine.lower() == "postgresql" for db in assessment.ossDatabases):
        modules.append("avm/res/db-for-postgre-sql/flexible-server")
    if any(db.engine.lower() == "mysql" for db in assessment.ossDatabases):
        modules.append("avm/res/db-for-my-sql/flexible-server")
    return sorted(set(modules))


def build_cost_lines(assessment: Assessment) -> list[CostLine]:
    """Build assessment-backed cost assumptions."""
    lines = [
        CostLine(
            category="IaaS",
            item=server.name,
            monthly_cost_usd=server.monthlyCostUsd,
            assumption=f"Azure Migrate recommended {server.recommendedSize} in {assessment.azureLocation}.",
        )
        for server in assessment.servers
    ]
    lines.extend(
        CostLine(
            category=db.engine,
            item=db.database,
            monthly_cost_usd=db.monthlyCostUsd,
            assumption=f"Assessment target: {db.recommendedTarget}.",
        )
        for db in assessment.ossDatabases
    )
    return lines


def require_human_approval(
    request: ApprovalRequest,
    approval_callback: ApprovalCallback | None = None,
) -> bool:
    """Return True only when a human-approved callback explicitly approves IaC emission."""
    if approval_callback is None:
        return False
    return approval_callback(request)


def _iac_plan_markdown(
    assessment: Assessment,
    project: str,
    intent: str,
    modules: list[str],
    costs: list[CostLine],
    approved: bool,
    advisory: str,
) -> str:
    module_text = "\n".join(f"- `{module}`" for module in modules)
    cost_text = "\n".join(
        f"| {line.category} | {line.item} | ${line.monthly_cost_usd:,.2f} | {line.assumption} |"
        for line in costs
    )
    status = (
        "APPROVED to emit deployable IaC" if approved else "PENDING human approval; do not emit IaC"
    )
    return f"""
# 04 IaC Plan — {project}

Intent: {intent}

## Approval gate

**Status:** {status}

Deployable Bicep must not be emitted until the trainer/customer approves the request.

## Requirements

- Resource groups: `{canonical_rg(project)}-network`, `{canonical_rg(project)}-data`, `{canonical_rg(project)}-compute`.
- Region: **{assessment.azureLocation}**.
- Database names: TailwindOLTP, TailwindRef, TailwindCatalog, TailwindSessions.
- Prefer private endpoints, managed identities, diagnostic settings, and tags.

## WAF, governance, and cost considerations

- Reliability: zone-aware platform services where supported and tested rollback points.
- Security: least-privilege RBAC, private ingress, no secrets in IaC, Key Vault references only.
- Cost: right-size from utilization and review after hypercare.
- Operational excellence: diagnostics, alerts, evidence index, and runbook ownership.
- Performance: validate DTU/vCore, storage IOPS, and VM SKU assumptions with load tests.

## Suggested Bicep AVM modules

{module_text}

## Cost estimate inputs

| Category | Item | Monthly estimate | Assumption |
| --- | --- | ---: | --- |
{cost_text or "| _None_ | | $0.00 | |"}

## Agent advisory

{advisory}
"""


async def run_iac_architect(
    assessment: Assessment,
    *,
    project: str,
    base_output_dir: Path,
    intent: str = "Plan Azure landing-zone and workload IaC for Tailwind Traders.",
    approval_callback: ApprovalCallback | None = None,
    chat_client: Any | None = None,
) -> ArtifactSet:
    """Generate assessment summary and IaC plan artifacts."""
    directory = output_dir(base_output_dir, project)
    approval_request = ApprovalRequest(
        project=project,
        summary=f"Emit IaC plan for {len(assessment.servers)} servers and data platforms.",
        risks=["Cost variance", "Policy non-compliance", "Database compatibility blockers"],
    )
    approved = require_human_approval(approval_request, approval_callback)
    advisory = await advisory_text(
        chat_client,
        name="IacArchitect",
        instructions=INSTRUCTIONS,
        prompt=f"Review IaC intent for {project}: {intent}",
    )
    files = [
        write_artifact(
            directory, ARTIFACT_NAMES["assessment"], assessment_summary(assessment, project)
        ),
        write_artifact(
            directory,
            ARTIFACT_NAMES["iac"],
            _iac_plan_markdown(
                assessment,
                project,
                intent,
                suggest_avm_modules(assessment),
                build_cost_lines(assessment),
                approved,
                advisory,
            ),
        ),
    ]
    return ArtifactSet(project=project, output_dir=directory, files=files)
