"""Typed assessment and migration artifact models."""

from __future__ import annotations

from datetime import datetime
from enum import StrEnum
from pathlib import Path

from pydantic import BaseModel, ConfigDict, Field, field_validator


class MigrationTarget(StrEnum):
    """Canonical migration targets used by the workstream."""

    AZURE_VM = "Azure Virtual Machines"
    AZURE_SQL_DB = "Azure SQL Database"
    AZURE_SQL_MI = "Azure SQL Managed Instance"
    POSTGRES_FLEX = "Azure Database for PostgreSQL Flexible Server"
    MYSQL_FLEX = "Azure Database for MySQL Flexible Server"
    AZURE_SSIS_IR = "Azure-SSIS IR in Azure Data Factory"
    ELASTIC_JOBS = "Azure SQL Elastic Jobs"
    MI_AGENT = "SQL Managed Instance Agent"


class ServerAssessment(BaseModel):
    """Azure Migrate-style server sizing recommendation."""

    model_config = ConfigDict(extra="forbid")

    name: str
    os: str
    cores: int = Field(gt=0)
    memoryGB: float = Field(gt=0)
    diskGB: float = Field(ge=0)
    cpuUtilizationPct: float = Field(ge=0, le=100)
    memoryUtilizationPct: float = Field(ge=0, le=100)
    role: str
    azureReadiness: str
    recommendedSize: str
    monthlyCostUsd: float = Field(ge=0)
    migrationStrategy: str


class SqlDatabaseAssessment(BaseModel):
    """Database-level Azure SQL readiness."""

    model_config = ConfigDict(extra="forbid")

    name: str
    sizeGB: float = Field(ge=0)
    compatLevel: int = Field(ge=80)
    azureSqlDbReadiness: str
    azureSqlMiReadiness: str
    blockers: list[str] = Field(default_factory=list)
    recommendedTarget: str


class SqlInstanceAssessment(BaseModel):
    """SQL Server instance assessment."""

    model_config = ConfigDict(extra="forbid")

    server: str
    instance: str
    version: str
    databases: list[SqlDatabaseAssessment]
    ssisPackages: list[str] = Field(default_factory=list)
    agentJobs: list[str] = Field(default_factory=list)


class OssDatabaseAssessment(BaseModel):
    """Open-source database assessment."""

    model_config = ConfigDict(extra="forbid")

    engine: str
    version: str
    server: str
    database: str
    sizeGB: float = Field(ge=0)
    extensions: list[str] = Field(default_factory=list)
    recommendedTarget: str
    monthlyCostUsd: float = Field(ge=0)


class Assessment(BaseModel):
    """Top-level synthetic assessment handshake contract."""

    model_config = ConfigDict(extra="forbid")

    assessmentName: str
    generatedOn: datetime
    currency: str = Field(min_length=3, max_length=3)
    azureLocation: str
    servers: list[ServerAssessment] = Field(default_factory=list)
    sqlInstances: list[SqlInstanceAssessment] = Field(default_factory=list)
    ossDatabases: list[OssDatabaseAssessment] = Field(default_factory=list)

    @field_validator("currency")
    @classmethod
    def uppercase_currency(cls, value: str) -> str:
        """Normalize currency codes for report rendering."""
        return value.upper()

    @property
    def total_monthly_cost_usd(self) -> float:
        """Return server plus OSS database monthly estimate."""
        return sum(server.monthlyCostUsd for server in self.servers) + sum(
            db.monthlyCostUsd for db in self.ossDatabases
        )

    @classmethod
    def from_json_file(cls, path: Path) -> Assessment:
        """Load and validate an assessment JSON file."""
        return cls.model_validate_json(path.read_text(encoding="utf-8"))


class Wave(BaseModel):
    """Migration wave recommendation."""

    name: str
    scope: list[str]
    rationale: str
    exit_criteria: list[str]
    dependencies: list[str] = Field(default_factory=list)


class MigrationDecision(BaseModel):
    """Structured platform decision with blockers and rationale."""

    workload: str
    source: str
    target: str
    rationale: str
    blockers: list[str] = Field(default_factory=list)
    actions: list[str] = Field(default_factory=list)


class CostLine(BaseModel):
    """Cost-estimate line item."""

    category: str
    item: str
    monthly_cost_usd: float = Field(ge=0)
    assumption: str


class EvidenceItem(BaseModel):
    """Evidence index item for Module B.4.1/B.4.2 audit packs."""

    control: str
    artifact: str
    description: str
    owner: str
    status: str = "draft"


class ApprovalRequest(BaseModel):
    """Human-in-the-loop approval payload before IaC emission."""

    project: str
    summary: str
    risks: list[str]
    requested_by: str = "iac-architect"


class ArtifactSet(BaseModel):
    """Paths produced by an agent run."""

    project: str
    output_dir: Path
    files: list[Path]
