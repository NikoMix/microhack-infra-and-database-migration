"""Agent orchestration and artifact generation tests."""

from __future__ import annotations

from pathlib import Path

import pytest
from migration_copilot.agents.common import ARTIFACT_NAMES
from migration_copilot.agents.engagement_copilot import run_engagement_copilot
from migration_copilot.agents.iac_architect import run_iac_architect
from migration_copilot.agents.schema_converter import build_schema_decisions, run_schema_converter
from migration_copilot.models import Assessment

from tests.mock_chat import MockChatClient


@pytest.fixture
def assessment() -> Assessment:
    return Assessment.from_json_file(Path("tests/fixtures/assessment.json"))


@pytest.mark.asyncio
async def test_engagement_artifacts(tmp_path: Path, assessment: Assessment) -> None:
    result = await run_engagement_copilot(
        assessment,
        project="tailwind",
        base_output_dir=tmp_path,
        chat_client=MockChatClient(),
    )
    names = {path.name for path in result.files}
    assert {
        ARTIFACT_NAMES["architecture"],
        ARTIFACT_NAMES["runbook"],
        ARTIFACT_NAMES["evidence"],
    } <= names
    assert "Module B.4.1" in (tmp_path / "tailwind" / ARTIFACT_NAMES["architecture"]).read_text()


@pytest.mark.asyncio
async def test_iac_approval_gate_pending_and_artifacts(
    tmp_path: Path, assessment: Assessment
) -> None:
    result = await run_iac_architect(assessment, project="tailwind", base_output_dir=tmp_path)
    plan = (tmp_path / "tailwind" / ARTIFACT_NAMES["iac"]).read_text()
    assert "PENDING human approval" in plan
    assert "avm/res/sql/managed-instance" in plan
    assert len(result.files) == 2


@pytest.mark.asyncio
async def test_iac_approval_gate_approved(tmp_path: Path, assessment: Assessment) -> None:
    await run_iac_architect(
        assessment,
        project="tailwind",
        base_output_dir=tmp_path,
        approval_callback=lambda request: request.project == "tailwind",
    )
    plan = (tmp_path / "tailwind" / ARTIFACT_NAMES["iac"]).read_text()
    assert "APPROVED to emit deployable IaC" in plan


@pytest.mark.asyncio
async def test_schema_converter_outputs_cross_db_mi(tmp_path: Path, assessment: Assessment) -> None:
    decisions = build_schema_decisions(assessment)
    oltp = next(decision for decision in decisions if decision.workload == "TailwindOLTP")
    assert oltp.target == "Azure SQL Managed Instance"
    await run_schema_converter(
        assessment,
        project="tailwind",
        base_output_dir=tmp_path,
        chat_client=MockChatClient(),
    )
    cost = (tmp_path / "tailwind" / ARTIFACT_NAMES["cost"]).read_text()
    assert "Azure-SSIS IR" in cost
    assert "SQL Managed Instance" in cost
