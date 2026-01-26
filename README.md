# PostgreSQL Schema Migration Scripts

Automated scripts for migrating database schemas between PostgreSQL databases using SQLAlchemy and Alembic.

## Overview

This toolkit generates SQLAlchemy models from a source PostgreSQL database and creates Alembic migrations to replicate the schema in a target PostgreSQL database with a different schema naming convention.

**Key Features:**
- Automated model generation using sqlacodegen
- Alembic-based schema migrations
- Automatic detection of source schema changes
- Lowercase table/column/constraint names in target
- Foreign key relationships preserved and transformed
- Configurable table selection
- Incremental migrations (only changes are migrated)
- Rollback support

## Quick Start

```bash
# 1. Configure your databases
cp scripts/config.env.example scripts/config.env
vim scripts/config.env  # Edit with your settings

# 2. Run full migration
./scripts/migrate-all.sh

# 3. Rollback if needed
./scripts/05-rollback.sh
```

## Configuration

Edit `scripts/config.env`:

```bash
# Source Database (PostgreSQL)
SOURCE_PG_HOST=localhost
SOURCE_PG_PORT=5432
SOURCE_PG_USER=postgres
SOURCE_PG_PASSWORD=YourPassword
SOURCE_PG_DATABASE=SourceDB
SOURCE_PG_SCHEMA=dbo

# Target Database (PostgreSQL)
TARGET_PG_HOST=localhost
TARGET_PG_PORT=5432
TARGET_PG_USER=postgres
TARGET_PG_PASSWORD=YourPassword
TARGET_PG_DATABASE=TargetDB

# Tables to migrate (comma-separated or "all")
TABLES=Users,Posts,Comments
```

**Target Schema Naming:**
The target schema is automatically derived as: `dw__<source_database>__<source_schema>` (lowercase)

Example: Source `StackOverflow2010.dbo` becomes target schema `dw__stackoverflow2010__dbo`

## Scripts

| Script | Description |
|--------|-------------|
| `migrate-all.sh` | Runs the full migration pipeline |
| `01-generate-models.sh` | Generates SQLAlchemy models from source |
| `02-init-alembic.sh` | Initializes Alembic for target database |
| `03-create-migration.sh` | Creates Alembic migration |
| `04-apply-migration.sh` | Applies migration and generates DDL |
| `05-rollback.sh` | Rolls back migrations |

### Running Individual Scripts

```bash
# Generate models only
./scripts/01-generate-models.sh

# Initialize Alembic
./scripts/02-init-alembic.sh

# Create migration (review before applying)
./scripts/03-create-migration.sh

# Apply migration
./scripts/04-apply-migration.sh

# Rollback options
./scripts/05-rollback.sh              # Rollback all
./scripts/05-rollback.sh -1           # Rollback one revision
./scripts/05-rollback.sh base yes     # Rollback all and drop schema
```

## Generated Artifacts

After running the migration, the `migration_workspace/` directory contains:

```
migration_workspace/
├── venv/                    # Python virtual environment
├── models.py                # Generated SQLAlchemy models (timestamped header)
├── models_*.py.bak          # Backup of previous models
├── migration_*.sql          # Generated DDL (timestamped)
├── alembic.ini              # Alembic configuration
└── alembic/
    ├── env.py
    └── versions/            # Migration files
```

### models.py Header

Generated models include a header with generation metadata:

```python
# =============================================================================
# Auto-generated SQLAlchemy models
# Generated: 2026-01-26 17:34:43
# Source: StackOverflow2010.dbo
# Target: dw__stackoverflow2010__dbo
# Tables: Users,Posts
# =============================================================================
```

Previous versions are backed up as `models_<timestamp>.py.bak` before regeneration.

## Example Output

```
Tables migrated to dw__stackoverflow2010__dbo:
  - badges
  - comments
  - linktypes
  - postlinks
  - posts
  - posttypes
  - users
  - votes
  - votetypes
```

## Model Features

Generated models use SQLAlchemy 2.0+ syntax:
- `Mapped` type annotations
- `DeclarativeBase` pattern
- Identity columns properly mapped
- Optional fields using `Optional[]` type hints
- Foreign key constraints with proper schema references

Example:
```python
class Users(Base):
    __tablename__ = 'users'
    __table_args__ = {'schema': 'dw__stackoverflow2010__dbo'}

    Id: Mapped[int] = mapped_column('id', Integer, Identity(), primary_key=True)
    DisplayName: Mapped[str] = mapped_column('displayname', VARCHAR(40), nullable=False)
    Reputation: Mapped[int] = mapped_column('reputation', Integer, nullable=False)

class Posts(Base):
    __tablename__ = 'posts'
    __table_args__ = (
        ForeignKeyConstraint(['owneruserid'], ['dw__stackoverflow2010__dbo.users.id']),
        {'schema': 'dw__stackoverflow2010__dbo'}
    )
```

## Transformations

The model generation script automatically transforms identifiers for the target database:

| Source | Target |
|--------|--------|
| Schema `dbo` | Schema `dw__<database>__<schema>` |
| Table `Users` | Table `users` |
| Column `DisplayName` | Column `displayname` |
| Constraint `PK_Users` | Constraint `pk_users` |
| FK reference `dbo.Users.Id` | FK reference `dw__<db>__<schema>.users.id` |

Python attribute names are preserved as PascalCase for code readability while database identifiers use lowercase.

## Schema Change Detection

The pipeline automatically detects and handles source schema changes:

| Scenario | Behavior |
|----------|----------|
| **No changes** | Models regenerated, empty migration removed, "Already in sync" |
| **New table** | Migration creates the new table |
| **New column** | Migration adds the column |
| **Dropped column** | Migration removes the column |
| **Type change** | Migration alters the column type |

Models are always regenerated from source to ensure changes are captured. Alembic then compares models against the target database and creates incremental migrations.

```bash
# Example: Add column to source, then migrate
psql -d SourceDB -c "ALTER TABLE dbo.Users ADD COLUMN Email VARCHAR(100)"
./scripts/migrate-all.sh  # Automatically detects and migrates the new column
```

## Prerequisites

- Python 3.10+
- PostgreSQL with psql client
- Source and target PostgreSQL databases

## Docker Setup (for testing)

Quick setup using Docker for local testing:

```bash
# Start PostgreSQL container
docker run -d --name postgres-migration \
  -e POSTGRES_PASSWORD=PostgresPassword123 \
  -p 5433:5432 \
  postgres:15

# Wait for PostgreSQL to be ready
until pg_isready -h localhost -p 5433 -U postgres; do sleep 1; done

# Create source and target databases
PGPASSWORD=PostgresPassword123 psql -h localhost -p 5433 -U postgres <<EOF
CREATE DATABASE "SourceDB";
CREATE DATABASE "TargetDB";
EOF

# Create source schema and tables in SourceDB
PGPASSWORD=PostgresPassword123 psql -h localhost -p 5433 -U postgres -d SourceDB <<EOF
CREATE SCHEMA dbo;
CREATE TABLE dbo."Users" (
    "Id" SERIAL PRIMARY KEY,
    "DisplayName" VARCHAR(40) NOT NULL
);
EOF

# Update config.env with port 5433, then run migration
./scripts/migrate-all.sh

# Cleanup when done
docker stop postgres-migration && docker rm postgres-migration
```

## Verification

```bash
# Check migration status
cd scripts/migration_workspace
source venv/bin/activate
alembic current
alembic history --verbose

# List tables in target
psql -h localhost -p 5432 -U postgres -d TargetDB \
  -c "\dt dw__stackoverflow2010__dbo.*"
```
