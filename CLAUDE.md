# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This is a documentation repository for SQLAlchemy model generation and database schema migration, specifically for the StackOverflow2010 database. It contains no executable code, only documentation and guides.

## Key Documentation Files

- **README.md** - Main documentation for SQLAlchemy model generation using sqlacodegen
- **ALEMBIC_QUICKSTART.md** - Step-by-step guide for setting up Alembic with generated models
- **MSSQL_TO_POSTGRESQL_MIGRATION.md** - Comprehensive guide for migrating schemas from MSSQL to PostgreSQL

## Common Commands

### Model Generation from MSSQL

Generate SQLAlchemy 2.0 models from MSSQL database:

```bash
# Using Docker (recommended)
docker run --rm --network host \
  -v "$(pwd)/sqlmodels:/output" \
  python:3.12-slim bash -c "
  pip install -q sqlacodegen pymssql &&
  sqlacodegen 'mssql+pymssql://sa:YourStrong%40Passw0rd@localhost:1433/StackOverflow2010' \
    --schemas dbo \
    --outfile /output/models.py
"

# Using local Python
pip install sqlacodegen pymssql
sqlacodegen 'mssql+pymssql://sa:password@localhost:1433/StackOverflow2010' \
  --schemas dbo \
  --outfile models.py
```

### Alembic Workflow

```bash
# Setup Python virtual environment (Ubuntu/Debian)
python3 -m venv venv
source venv/bin/activate
pip install alembic sqlalchemy pymssql psycopg2-binary

# Initialize Alembic
alembic init alembic

# Generate migration from models
alembic revision --autogenerate -m "Migration description"

# Apply migrations
alembic upgrade head

# Check migration status
alembic current
alembic history --verbose

# Rollback migrations
alembic downgrade -1
```

### PostgreSQL Migration Workflow

Complete workflow for migrating MSSQL schema to PostgreSQL:

```bash
# 1. Generate models from MSSQL
sqlacodegen 'mssql+pymssql://sa:password@localhost:1433/StackOverflow2010' \
  --schemas dbo --outfile models.py

# 2. Initialize Alembic
alembic init alembic

# 3. Create PostgreSQL schema
psql -U postgres -h localhost -p 5433 -d stackoverflow \
  -c "CREATE SCHEMA IF NOT EXISTS dbo;"

# 4. Generate migration
alembic revision --autogenerate -m "Initial schema from MSSQL"

# 5. Remove MSSQL-specific collations from migration
sed -i "s/, collation='SQL_Latin1_General_CP1_CI_AS'//g" alembic/versions/*.py
sed -i "s/sa.Unicode(collation='SQL_Latin1_General_CP1_CI_AS')/sa.Unicode()/g" alembic/versions/*.py

# 6. Apply migration to PostgreSQL
alembic upgrade head

# 7. Verify schema creation
psql -U postgres -h localhost -p 5433 -d stackoverflow -c "\dt dbo.*"
```

## Architecture & Key Concepts

### Two-Phase Migration Strategy

Schema migration is separated from data migration:

1. **Schema Migration** (Alembic): Creates table structure, constraints, indexes
2. **Data Migration** (External tool): Copies actual data between databases

The documentation references an external Rust data migration tool for bulk data transfer.

### Database Schema Structure

The StackOverflow2010 database contains 9 tables in the `dbo` schema:

- **Users** - User profiles
- **Posts** - Questions and answers
- **Comments** - Post comments
- **Badges** - User achievements
- **Votes** - Vote records
- **VoteTypes** - Vote type definitions
- **PostLinks** - Links between posts
- **PostTypes** - Post type definitions
- **LinkTypes** - Link type definitions

### SQLAlchemy Model Generation

Models are generated using sqlacodegen with these characteristics:
- SQLAlchemy 2.0+ syntax with `Mapped` type annotations
- `DeclarativeBase` pattern for type safety
- Identity columns properly mapped
- Unicode/String columns with MSSQL collations preserved (must be removed for PostgreSQL)
- Optional fields using `Optional[]` type hints

### Critical Migration Issues

When migrating MSSQL to PostgreSQL:

1. **Collations**: MSSQL collations like `SQL_Latin1_General_CP1_CI_AS` must be removed from Alembic migrations
2. **Schema Creation**: PostgreSQL requires `dbo` schema to be created before running migrations
3. **alembic.ini Escaping**: Use `%%` to escape `%` characters in INI file passwords
4. **Model Imports**: `alembic/env.py` must import models and set `target_metadata = Base.metadata`

### Alembic Configuration

Two key files must be configured:

1. **alembic.ini**: Database connection URL (use `%%` to escape `%` in passwords)
2. **alembic/env.py**: Add parent directory to path and import Base from models

### Password Encoding

- URL-encoding for connection strings: `@` → `%40`, `#` → `%23`
- INI file escaping: `%` → `%%`

## Virtual Environment Requirement

Ubuntu/Debian uses externally-managed Python, requiring virtual environments:

```bash
python3 -m venv venv
source venv/bin/activate
```

All Python package installations must occur within the virtual environment.

## Docker Alternative

For users who prefer not to install Python packages locally, all operations can be run via Docker containers using the `python:3.12-slim` image with `--network host` for database access.
