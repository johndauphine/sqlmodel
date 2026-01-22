# CLAUDE.md

This file provides guidance to Claude Code when working with this repository.

## Repository Purpose

PostgreSQL schema migration toolkit using SQLAlchemy and Alembic. Migrates schemas between PostgreSQL databases with automatic lowercase naming and derived schema names.

## Key Files

- **scripts/config.env.example** - Configuration template
- **scripts/migrate-all.sh** - Full migration pipeline
- **scripts/01-generate-models.sh** - Generate SQLAlchemy models
- **scripts/02-init-alembic.sh** - Initialize Alembic
- **scripts/03-create-migration.sh** - Create Alembic migration
- **scripts/04-apply-migration.sh** - Apply migration
- **scripts/05-rollback.sh** - Rollback migrations

## Common Commands

### Run Full Migration

```bash
cp scripts/config.env.example scripts/config.env
# Edit config.env with database credentials
./scripts/migrate-all.sh
```

### Run Individual Steps

```bash
./scripts/01-generate-models.sh   # Generate models from source
./scripts/02-init-alembic.sh      # Initialize Alembic
./scripts/03-create-migration.sh  # Create migration
./scripts/04-apply-migration.sh   # Apply migration
```

### Rollback

```bash
./scripts/05-rollback.sh              # Rollback all
./scripts/05-rollback.sh -1           # Rollback one revision
./scripts/05-rollback.sh base yes     # Rollback and drop schema
```

### Manual Alembic Commands

```bash
cd scripts/migration_workspace
source venv/bin/activate
alembic current           # Check status
alembic history --verbose # View history
alembic upgrade head      # Apply migrations
alembic downgrade -1      # Rollback one
```

## Configuration

### config.env Variables

```bash
# Source PostgreSQL
SOURCE_PG_HOST, SOURCE_PG_PORT, SOURCE_PG_USER
SOURCE_PG_PASSWORD, SOURCE_PG_DATABASE, SOURCE_PG_SCHEMA

# Target PostgreSQL
TARGET_PG_HOST, TARGET_PG_PORT, TARGET_PG_USER
TARGET_PG_PASSWORD, TARGET_PG_DATABASE

# Migration settings
TABLES=all                    # or comma-separated list
WORK_DIR=./migration_workspace
```

### Schema Naming

Target schema is derived as: `dw__<source_database>__<source_schema>` (lowercase)

Example: `StackOverflow2010.dbo` -> `dw__stackoverflow2010__dbo`

## Architecture

### Migration Pipeline

1. **01-generate-models.sh**: sqlacodegen generates SQLAlchemy models, transforms to lowercase
2. **02-init-alembic.sh**: Creates venv, installs packages, initializes Alembic, creates target schema
3. **03-create-migration.sh**: Runs alembic autogenerate, removes empty migrations
4. **04-apply-migration.sh**: Generates DDL, applies migration, verifies tables

### Idempotency

All scripts are idempotent:
- Skip if models.py exists
- Skip if already at head
- Remove empty migrations automatically

### Generated Artifacts

```
scripts/migration_workspace/
├── venv/           # Python virtual environment
├── models.py       # SQLAlchemy models
├── migration.sql   # Generated DDL
├── alembic.ini     # Alembic config
└── alembic/
    └── versions/   # Migration files
```

## Model Generation

Models use SQLAlchemy 2.0 syntax:
- `Mapped` type annotations
- `DeclarativeBase` pattern
- Lowercase database names, PascalCase Python names
- Identity columns properly mapped

## Testing

```bash
# Test idempotency
./scripts/migrate-all.sh  # Run once
./scripts/migrate-all.sh  # Run again - should skip

# Test rollback cycle
./scripts/05-rollback.sh base yes
./scripts/migrate-all.sh
```

## Troubleshooting

### Connection issues
```bash
psql -h $HOST -p $PORT -U $USER -d $DATABASE
```

### Check migration status
```bash
cd scripts/migration_workspace && source venv/bin/activate && alembic current
```

### Password encoding
URL-encode special characters: `@` -> `%40`, `#` -> `%23`
