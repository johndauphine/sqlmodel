"""Configuration loading and validation for SMT."""

from __future__ import annotations

import logging
import os
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Literal

import yaml
from sqlalchemy.engine import URL

logger = logging.getLogger(__name__)

DEFAULT_DRIVERS: dict[str, str] = {
    "postgresql": "psycopg2",
    "mssql": "pyodbc",
}

DEFAULT_PORTS: dict[str, int] = {
    "postgresql": 5432,
    "mssql": 1433,
}

IDENTIFIER_LENGTH_LIMITS: dict[str, int] = {
    "postgresql": 63,
    "mssql": 128,
}

SUPPORTED_DIALECTS = ("postgresql", "mssql")


class ConfigError(Exception):
    """Raised when configuration is invalid."""


@dataclass
class DatabaseConfig:
    dialect: str
    host: str
    port: int
    user: str
    password: str
    database: str
    schema: str | None = None
    driver: str | None = None

    def __post_init__(self):
        if self.dialect not in SUPPORTED_DIALECTS:
            raise ConfigError(
                f"Unsupported dialect '{self.dialect}'. "
                f"Supported: {', '.join(SUPPORTED_DIALECTS)}"
            )
        if self.driver is None:
            self.driver = DEFAULT_DRIVERS[self.dialect]

    def get_url(self) -> URL:
        """Build SQLAlchemy connection URL with proper password encoding."""
        backend = f"{self.dialect}+{self.driver}"
        query: dict[str, str] = {}

        if self.dialect == "mssql" and self.driver == "pyodbc":
            query["driver"] = "ODBC Driver 18 for SQL Server"
            query["TrustServerCertificate"] = "yes"
            query["Encrypt"] = "yes"

        return URL.create(
            drivername=backend,
            username=self.user,
            password=self.password,
            host=self.host,
            port=self.port,
            database=self.database,
            query=query,
        )

    def get_url_string(self) -> str:
        """Return the connection URL as a string with password visible."""
        return self.get_url().render_as_string(hide_password=False)


def _sanitize_identifier(value: str) -> str:
    """Lowercase, replace non-[A-Za-z0-9_] chars with `_`, and ensure a non-digit
    leading character so the result is a valid unquoted SQL identifier (PG/MSSQL
    require identifiers to start with a letter or underscore)."""
    cleaned = re.sub(r"[^A-Za-z0-9_]", "_", value).lower()
    if cleaned and cleaned[0].isdigit():
        cleaned = "_" + cleaned
    return cleaned


@dataclass
class SmtConfig:
    source: DatabaseConfig
    target: DatabaseConfig
    tables: list[str] | Literal["all"]
    workspace: Path
    target_schema: str | None = None

    def __post_init__(self):
        if self.target_schema is None:
            self.target_schema = (
                f"{_sanitize_identifier(self.source.host)}"
                f"__{self.source.database.lower()}"
                f"__{self.source.schema.lower()}"
            )
        else:
            # Normalize explicit overrides to lowercase so the value we pass to
            # schema DDL (unquoted) matches what SQLAlchemy/Alembic reflect back.
            # PG folds unquoted identifiers to lowercase; mixed case would cause
            # the create_schema DDL and metadata.schema to refer to different
            # schemas downstream.
            lowered = self.target_schema.lower()
            if lowered != self.target_schema:
                logger.warning(
                    "target_schema '%s' normalized to lowercase '%s'",
                    self.target_schema, lowered,
                )
                self.target_schema = lowered
        self._validate_schema_name_chars()
        self._validate_schema_name_length()

    def _validate_schema_name_chars(self):
        # SQL identifiers must start with a letter or underscore and contain only
        # alphanumerics or underscores thereafter.
        if not re.match(r"^[A-Za-z_][A-Za-z0-9_]*$", self.target_schema):
            raise ConfigError(
                f"Target schema '{self.target_schema}' is not a valid SQL identifier. "
                f"Must start with a letter or underscore and contain only alphanumeric "
                f"characters or underscores."
            )

    def _validate_schema_name_length(self):
        limit = IDENTIFIER_LENGTH_LIMITS.get(self.target.dialect)
        if limit and len(self.target_schema) > limit:
            raise ConfigError(
                f"Target schema '{self.target_schema}' is {len(self.target_schema)} chars, "
                f"exceeding {self.target.dialect} identifier limit of {limit}. "
                f"Set 'target_schema:' explicitly in the config to override the default."
            )


def _parse_db_config(data: dict, section: str) -> DatabaseConfig:
    """Parse a database config section from YAML data."""
    required = ("dialect", "host", "user", "password", "database")
    missing = [k for k in required if k not in data]
    if missing:
        raise ConfigError(f"{section}: missing required fields: {', '.join(missing)}")

    return DatabaseConfig(
        dialect=data["dialect"],
        host=data["host"],
        port=data.get("port", DEFAULT_PORTS.get(data["dialect"], 5432)),
        user=data["user"],
        password=data["password"],
        database=data["database"],
        schema=data.get("schema"),
        driver=data.get("driver"),
    )


def load_config(path: str | Path) -> SmtConfig:
    """Load and validate SMT configuration from a YAML file.

    Environment variable overrides:
    - SMT_SOURCE_PASSWORD overrides source.password
    - SMT_TARGET_PASSWORD overrides target.password
    """
    path = Path(path)
    if not path.exists():
        raise ConfigError(f"Config file not found: {path}")

    with open(path) as f:
        data = yaml.safe_load(f)

    if not isinstance(data, dict):
        raise ConfigError(f"Invalid config file: {path}")

    for section in ("source", "target"):
        if section not in data:
            raise ConfigError(f"Missing '{section}' section in config")

    # Parse database configs
    source = _parse_db_config(data["source"], "source")
    target = _parse_db_config(data["target"], "target")

    # Environment variable overrides for passwords
    env_source_pw = os.environ.get("SMT_SOURCE_PASSWORD")
    if env_source_pw:
        source.password = env_source_pw
        logger.debug("Using SMT_SOURCE_PASSWORD environment variable")

    env_target_pw = os.environ.get("SMT_TARGET_PASSWORD")
    if env_target_pw:
        target.password = env_target_pw
        logger.debug("Using SMT_TARGET_PASSWORD environment variable")

    # Validate source has a schema
    if not source.schema:
        raise ConfigError("source: 'schema' is required")

    # Parse tables
    tables_raw = data.get("tables", "all")
    if isinstance(tables_raw, str):
        if tables_raw.lower() == "all":
            tables: list[str] | Literal["all"] = "all"
        else:
            tables = [t.strip() for t in tables_raw.split(",") if t.strip()]
    elif isinstance(tables_raw, list):
        tables = tables_raw
    else:
        raise ConfigError(f"'tables' must be a list or 'all', got: {type(tables_raw).__name__}")

    # Parse workspace
    workspace = Path(data.get("workspace", "./migration_workspace"))

    # Optional explicit target_schema override
    target_schema = data.get("target_schema")
    if target_schema is not None and not isinstance(target_schema, str):
        raise ConfigError(
            f"'target_schema' must be a string, got: {type(target_schema).__name__}"
        )

    return SmtConfig(
        source=source,
        target=target,
        tables=tables,
        workspace=workspace,
        target_schema=target_schema,
    )
