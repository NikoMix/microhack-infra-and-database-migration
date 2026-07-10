"""Typer CLI for migration-copilot artifacts."""

from __future__ import annotations

import asyncio
from pathlib import Path
from typing import Annotated

import typer
from rich.console import Console

from migration_copilot.agents.common import (
    ARTIFACT_NAMES,
    assessment_summary,
    load_assessment,
    output_dir,
    write_artifact,
)
from migration_copilot.agents.engagement_copilot import run_engagement_copilot
from migration_copilot.agents.iac_architect import run_iac_architect
from migration_copilot.agents.schema_converter import run_schema_converter
from migration_copilot.models import ArtifactSet

app = typer.Typer(help="Tailwind Traders Azure migration microhack AI workstream CLI.")
console = Console()

AssessmentPath = Annotated[Path, typer.Option("--assessment", "-a", help="Path to assessment.json")]
ProjectName = Annotated[str, typer.Option("--project", "-p", help="Project output folder name")]
OutputBase = Annotated[Path, typer.Option("--output", "-o", help="Base output directory")]


def _print_result(result: ArtifactSet) -> None:
    console.print(f"[green]Wrote {len(result.files)} artifact(s) to {result.output_dir}[/green]")
    for file in result.files:
        console.print(f"- {file.name}")


@app.command()
def assess(
    assessment: AssessmentPath = Path("tests/fixtures/assessment.json"),
    project: ProjectName = "tailwind-traders",
    output: OutputBase = Path("agent-output"),
) -> None:
    """Write 01-assessment.md from assessment JSON."""
    parsed = load_assessment(assessment)
    directory = output_dir(output, project)
    path = write_artifact(
        directory, ARTIFACT_NAMES["assessment"], assessment_summary(parsed, project)
    )
    _print_result(ArtifactSet(project=project, output_dir=directory, files=[path]))


@app.command()
def architect(
    assessment: AssessmentPath = Path("tests/fixtures/assessment.json"),
    project: ProjectName = "tailwind-traders",
    output: OutputBase = Path("agent-output"),
    intent: Annotated[
        str, typer.Option("--intent", help="Architecture/IaC intent")
    ] = "Plan migration IaC.",
    approve: Annotated[
        bool, typer.Option("--approve", help="Simulate human approval gate")
    ] = False,
) -> None:
    """Write 01-assessment.md and 04-iac-plan.md."""
    parsed = load_assessment(assessment)
    callback = (lambda _request: True) if approve else None
    result = asyncio.run(
        run_iac_architect(
            parsed,
            project=project,
            base_output_dir=output,
            intent=intent,
            approval_callback=callback,
        )
    )
    _print_result(result)


@app.command()
def convert(
    assessment: AssessmentPath = Path("tests/fixtures/assessment.json"),
    project: ProjectName = "tailwind-traders",
    output: OutputBase = Path("agent-output"),
) -> None:
    """Write 03-cost-estimate.md with schema conversion decisions."""
    parsed = load_assessment(assessment)
    _print_result(
        asyncio.run(run_schema_converter(parsed, project=project, base_output_dir=output))
    )


@app.command()
def runbook(
    assessment: AssessmentPath = Path("tests/fixtures/assessment.json"),
    project: ProjectName = "tailwind-traders",
    output: OutputBase = Path("agent-output"),
) -> None:
    """Write 02-architecture.md, 05-runbook.md, and 06-evidence-index.md."""
    parsed = load_assessment(assessment)
    _print_result(
        asyncio.run(run_engagement_copilot(parsed, project=project, base_output_dir=output))
    )


@app.command()
def evidence(
    assessment: AssessmentPath = Path("tests/fixtures/assessment.json"),
    project: ProjectName = "tailwind-traders",
    output: OutputBase = Path("agent-output"),
) -> None:
    """Refresh the evidence index artifact."""
    parsed = load_assessment(assessment)
    result = asyncio.run(run_engagement_copilot(parsed, project=project, base_output_dir=output))
    evidence_files = [file for file in result.files if file.name == ARTIFACT_NAMES["evidence"]]
    _print_result(ArtifactSet(project=project, output_dir=result.output_dir, files=evidence_files))
