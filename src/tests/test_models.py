"""Model validation tests."""

from __future__ import annotations

from pathlib import Path

from migration_copilot.models import Assessment


def test_assessment_fixture_validates() -> None:
    assessment = Assessment.from_json_file(Path("tests/fixtures/assessment.json"))
    assert assessment.currency == "USD"
    assert assessment.sqlInstances[0].databases[0].name == "TailwindOLTP"
    assert assessment.total_monthly_cost_usd > 0
